-- Hangman's view: the word as tiles, a keyboard to click, the wrong guesses, the attempts left and a danger bar, a
-- hint, give up and new round, and the statistics and recent words on the right. Two ways to play: a random WoW word
-- (by category), or an own word that a friend types in (the computer is passed on).
local _, ARC = ...

local UI = ARC.UI
local Logic, Stats, Words = ARC.Hangman.Logic, ARC.Hangman.Stats, ARC.Hangman

local LEFT_W = 590
local KEY_W, KEY_H, KEY_GAP = 48, 40, 6
local KEY_ROWS = { "ABCDEFGHIJ", "KLMNOPQRS", "TUVWXYZ" }
local TILE_MAX_W, TILE_GAP, TILE_H = 52, 6, 52
local MAX_TILES = Logic.MAX_LENGTH

local function prefs()
	if not ARC.db then return { mode = "random", category = "all" } end
	ARC.db.hangmanPrefs = ARC.db.hangmanPrefs or { mode = "random", category = "all" }
	return ARC.db.hangmanPrefs
end

local function categoryOptions()
	local list = { { value = "all", label = "Anything" } }
	for _, c in ipairs(Words.Categories) do list[#list + 1] = { value = c.id, label = c.name } end
	return list
end

-- A small square with a letter in it (the word's tiles, the wrong guesses).
local function makeTile(parent)
	local t = CreateFrame("Frame", nil, parent)
	t.bg, t.border = UI.Surface(t, "window", 1, UI.radius.control)
	t.text = UI.Text(t, 26, "text")
	t.text:SetPoint("CENTER", 0, 1)
	t.text:SetJustifyH("CENTER")
	t.line = UI.Fill(t, "line", 1, "ARTWORK")
	t.line:SetPoint("BOTTOMLEFT", 10, 8)
	t.line:SetPoint("BOTTOMRIGHT", -10, 8)
	t.line:SetHeight(2)
	return t
end

local function stateText(game)
	if game.state == "won" then return "You solved it!", "accent" end
	if game.state == "lost" then return "Out of attempts. The word was " .. game.word .. ".", "bad" end
	if game.state == "gaveup" then return "You gave up. The word was " .. game.word .. ".", "warn" end
	return "", "textDim"
end

local function build(parent)
	local view = { frame = CreateFrame("Frame", nil, parent) }
	local f = view.frame
	local game              -- the round being played
	local recorded          -- whether the round has been written to the statistics
	local who = ARC.Who()
	local randomRound, openOwnBox, applyMode -- defined below; the controls need them

	-- ----- the controls: how to play, and which words ----------------------------------------------------------
	local mode = UI.Segment(f, { { value = "random", label = "Random word" }, { value = "own", label = "Own word" } }, function(value)
		prefs().mode = value
		applyMode()
		if value == "own" then openOwnBox() else randomRound() end
	end)
	mode:SetPoint("TOPLEFT", 20, -16)
	local category = UI.Choice(f, 240, categoryOptions, function(value)
		prefs().category = value
		randomRound()
	end)
	category:SetPoint("TOPLEFT", LEFT_W - 240 + 20, -14)
	local ownNote = UI.Text(f, 12, "textDim")
	ownNote:SetPoint("TOPLEFT", mode, "TOPRIGHT", 16, -9)
	ownNote:SetText("One types a word, the other guesses.")

	-- ----- the word --------------------------------------------------------------------------------------------
	local wordPanel = UI.Panel(f, "Guess the word")
	wordPanel:SetPoint("TOPLEFT", 20, -62)
	wordPanel:SetSize(LEFT_W, 128)
	local info = UI.Text(wordPanel, 11, "textDim")
	info:SetPoint("TOPRIGHT", -16, -17)
	info:SetJustifyH("RIGHT")
	local tiles = {}
	for i = 1, MAX_TILES do
		tiles[i] = makeTile(wordPanel)
		tiles[i]:Hide()
	end
	local message = UI.Text(wordPanel, 13, "text")
	message:SetPoint("BOTTOM", wordPanel, "BOTTOM", 0, 12)
	message:SetJustifyH("CENTER")

	-- ----- wrong guesses, attempts, danger --------------------------------------------------------------------------
	local wrongPanel = UI.Panel(f, "Wrong guesses")
	wrongPanel:SetPoint("TOPLEFT", 20, -200)
	wrongPanel:SetSize(LEFT_W / 2 - 5, 130)
	local wrongTiles = {}
	for i = 1, Logic.MAX_WRONG do
		local t = makeTile(wrongPanel)
		t:SetSize(34, 34)
		t.text:SetFont(UI.FontPath(), 15, "")
		t.line:Hide()
		t:SetPoint("TOPLEFT", 16 + (i - 1) * 40, -38)
		t:Hide()
		wrongTiles[i] = t
	end
	local attemptsLabel = UI.Text(wrongPanel, 12, "textDim")
	attemptsLabel:SetPoint("BOTTOMLEFT", 16, 42)
	attemptsLabel:SetText("Attempts left")
	local pips = {}
	for i = 1, Logic.MAX_WRONG do
		local p = CreateFrame("Frame", nil, wrongPanel)
		p:SetSize(24, 24)
		p:SetPoint("BOTTOMLEFT", 16 + (i - 1) * 32, 12)
		p.bg = UI.Fill(p, "line", 1)
		p.bg:SetAllPoints()
		UI.Round(p.bg, 12)
		pips[i] = p
	end

	local dangerPanel = UI.Panel(f, "Danger")
	dangerPanel:SetPoint("TOPLEFT", 20 + LEFT_W / 2 + 5, -200)
	dangerPanel:SetSize(LEFT_W / 2 - 5, 130)
	local segW = math.floor((LEFT_W / 2 - 5 - 32 - (Logic.MAX_WRONG - 1) * 4) / Logic.MAX_WRONG)
	local segments = {}
	for i = 1, Logic.MAX_WRONG do
		local s = dangerPanel:CreateTexture(nil, "ARTWORK")
		s:SetSize(segW, 18)
		s:SetPoint("TOPLEFT", 16 + (i - 1) * (segW + 4), -46)
		segments[i] = s
	end
	local percent = UI.Text(dangerPanel, 13, "warn")
	percent:SetPoint("TOPRIGHT", -16, -17)
	percent:SetJustifyH("RIGHT")
	local dangerNote = UI.Text(dangerPanel, 11, "textDim")
	dangerNote:SetPoint("BOTTOMLEFT", 16, 14)
	dangerNote:SetPoint("RIGHT", dangerPanel, "RIGHT", -16, 0)
	dangerNote:SetWordWrap(true)
	dangerNote:SetText("It grows with every wrong guess, and with a hint.")

	-- ----- the keyboard --------------------------------------------------------------------------------------------
	local keyboard = UI.Panel(f, "Choose a letter")
	keyboard:SetPoint("TOPLEFT", 20, -340)
	keyboard:SetSize(LEFT_W, 176)
	local keys = {}
	for r, row in ipairs(KEY_ROWS) do
		local n = #row
		local x0 = math.floor((LEFT_W - (n * KEY_W + (n - 1) * KEY_GAP)) / 2)
		for c = 1, n do
			local letter = row:sub(c, c)
			local k = CreateFrame("Button", nil, keyboard)
			k:SetSize(KEY_W, KEY_H)
			k:SetPoint("TOPLEFT", x0 + (c - 1) * (KEY_W + KEY_GAP), -(36 + (r - 1) * (KEY_H + KEY_GAP)))
			k.bg, k.border = UI.Surface(k, "field", 1, UI.radius.control)
			k.text = UI.Text(k, 16, "text")
			k.text:SetPoint("CENTER", 0, 0)
			k.text:SetJustifyH("CENTER")
			k.text:SetText(letter)
			k.letter = letter
			keys[letter] = k
		end
	end

	-- ----- the buttons under the keyboard ----------------------------------------------------------------------------
	local hint, giveUp, newRound
	hint = UI.Button(f, "Hint (1)", "plain", nil, 150)
	hint:SetPoint("TOPLEFT", 20, -526)
	giveUp = UI.Button(f, "Give up", "plain", nil, 150)
	giveUp:SetPoint("LEFT", hint, "RIGHT", 10, 0)
	newRound = UI.Button(f, "New round", "accent", nil, LEFT_W - 320)
	newRound:SetPoint("LEFT", giveUp, "RIGHT", 10, 0)

	-- ----- statistics and recent words on the right ----------------------------------------------------------------
	local statsPanel = UI.Panel(f, "Your stats")
	statsPanel:SetPoint("TOPLEFT", 20 + LEFT_W + 16, -16)
	statsPanel:SetSize(252, 188)
	local statRows = {}
	for i, label in ipairs({ "Played", "Won", "Win rate", "Streak", "Best streak" }) do
		local l = UI.Text(statsPanel, 12, "textDim")
		l:SetPoint("TOPLEFT", 16, -42 - (i - 1) * 27)
		l:SetText(label)
		local v = UI.Text(statsPanel, 13, "text")
		v:SetPoint("TOPRIGHT", -16, -42 - (i - 1) * 27)
		v:SetJustifyH("RIGHT")
		statRows[i] = v
	end
	local recentPanel = UI.Panel(f, "Recent words")
	recentPanel:SetPoint("TOPLEFT", 20 + LEFT_W + 16, -214)
	recentPanel:SetSize(252, 344)
	local recentRows = {}
	for i = 1, Stats.MAX_RECENT do
		local r = CreateFrame("Frame", nil, recentPanel)
		r:SetHeight(28)
		r:SetPoint("TOPLEFT", 12, -38 - (i - 1) * 29)
		r:SetPoint("TOPRIGHT", -12, -38 - (i - 1) * 29)
		r.mark = UI.Fill(r, "line", 1)
		r.mark:SetPoint("LEFT", 0, 0)
		r.mark:SetSize(22, 22)
		UI.Round(r.mark, 5)
		r.letter = UI.Text(r, 11, "window")
		r.letter:SetPoint("CENTER", r.mark, "CENTER", 0, 0)
		r.letter:SetJustifyH("CENTER")
		r.word = UI.Text(r, 12, "text")
		r.word:SetPoint("LEFT", r.mark, "RIGHT", 8, 0)
		r.word:SetPoint("RIGHT", r, "RIGHT", 0, 0)
		recentRows[i] = r
	end
	local recentEmpty = UI.Text(recentPanel, 12, "textFaint")
	recentEmpty:SetPoint("TOPLEFT", 16, -44)
	recentEmpty:SetText("No rounds played yet.")

	-- ----- an own word: a box on top of everything ---------------------------------------------------------------------
	local dim = CreateFrame("Frame", nil, f)
	dim:SetAllPoints(f)
	dim:SetFrameLevel(f:GetFrameLevel() + 20)
	dim:EnableMouse(true)
	local dimFill = dim:CreateTexture(nil, "BACKGROUND")
	dimFill:SetAllPoints()
	dimFill:SetColorTexture(0, 0, 0, 0.72)
	dim:Hide()
	local box = CreateFrame("Frame", nil, dim)
	box:SetSize(470, 290)
	box:SetPoint("CENTER", dim, "CENTER", 0, 10)
	box:SetFrameLevel(dim:GetFrameLevel() + 2)
	UI.Surface(box, "window", 1, UI.radius.panel)
	local boxTitle = UI.Text(box, 15, "text")
	boxTitle:SetPoint("TOPLEFT", 22, -20)
	boxTitle:SetText("A word for your friend")
	local boxText = UI.Text(box, 12, "textDim")
	boxText:SetPoint("TOPLEFT", 22, -50)
	boxText:SetPoint("RIGHT", box, "RIGHT", -22, 0)
	boxText:SetWordWrap(true)
	boxText:SetText("Type a word or a name, then hand over the computer. The letters are hidden while you type.")
	local wordBox = UI.EditBox(box, "The word", Logic.MAX_LENGTH, true)
	wordBox:SetPoint("TOPLEFT", 22, -100)
	wordBox:SetPoint("TOPRIGHT", -22, -100)
	local hintBox = UI.EditBox(box, "A hint to show (optional)", 40, false)
	hintBox:SetPoint("TOPLEFT", 22, -146)
	hintBox:SetPoint("TOPRIGHT", -22, -146)
	local boxError = UI.Text(box, 12, "bad")
	boxError:SetPoint("TOPLEFT", 22, -194)
	boxError:SetPoint("RIGHT", box, "RIGHT", -22, 0)
	local boxStart, boxCancel

	-- ------------------------------------------------------------------------------------------------------------------
	-- Drawing
	-- ------------------------------------------------------------------------------------------------------------------
	local function renderWord()
		local slots = game and game:Slots() or {}
		local n = #slots
		for _, t in ipairs(tiles) do t:Hide() end
		if n == 0 then return end
		local avail = LEFT_W - 40
		local w = math.min(TILE_MAX_W, math.floor((avail - TILE_GAP * (n - 1)) / n))
		w = math.max(w, 16)
		local widths, total = {}, 0
		for i, s in ipairs(slots) do
			widths[i] = s.fixed and math.max(10, math.floor(w * 0.45)) or w
			total = total + widths[i] + (i > 1 and TILE_GAP or 0)
		end
		local x = math.floor((LEFT_W - total) / 2)
		local size = w >= 40 and 26 or (w >= 28 and 20 or 15)
		for i, s in ipairs(slots) do
			local t = tiles[i]
			t:SetSize(widths[i], math.min(TILE_H, math.max(30, math.floor(w * 1.1))))
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", wordPanel, "TOPLEFT", x, -44)
			t.text:SetFont(UI.FontPath(), size, "")
			if s.fixed then
				t.bg:SetColorTexture(UI.Color("field"))
				t.line:Hide()
				t.text:SetText(s.char)
				t.text:SetTextColor(UI.Color("textDim"))
			else
				t.bg:SetColorTexture(UI.Color("window"))
				t.line:Show()
				if s.shown then
					t.text:SetText(s.char)
					if s.missed then
						t.text:SetTextColor(UI.Color("bad"))
						t.line:SetColorTexture(UI.Color("bad"))
					else
						t.text:SetTextColor(UI.Color("text"))
						t.line:SetColorTexture(UI.Color("accent"))
					end
				else
					t.text:SetText("")
					t.line:SetColorTexture(UI.Color("line"))
				end
			end
			t:Show()
			x = x + widths[i] + TILE_GAP
		end
	end

	local function renderKeys()
		for letter, k in pairs(keys) do
			local style = "plain"
			if game then
				if game.letters[letter] and game.guessed[letter] then style = "hit"
				elseif game.guessed[letter] then style = "miss" end
			end
			if style == "hit" then
				k.bg:SetColorTexture(UI.Color("accentDim"))
				k.border:SetColor(UI.Color("accent"))
				k.text:SetTextColor(UI.Color("accent"))
			elseif style == "miss" then
				k.bg:SetColorTexture(UI.Color("badDim"))
				k.border:SetColor(UI.Color("bad"))
				k.text:SetTextColor(UI.Color("bad"))
			else
				k.bg:SetColorTexture(UI.Color("field"))
				k.border:SetColor(UI.Color("line"))
				k.text:SetTextColor(UI.Color("text"))
			end
			k.used = style ~= "plain"
		end
	end

	local function renderStats()
		local s = Stats.Of(ARC.db or {}, who)
		statRows[1]:SetText(tostring(s.played))
		statRows[2]:SetText(tostring(s.won))
		statRows[3]:SetText(Stats.Rate(s) .. "%")
		statRows[4]:SetText(tostring(s.streak))
		statRows[5]:SetText(tostring(s.best))
		recentEmpty:SetShown(#s.recent == 0)
		for i, r in ipairs(recentRows) do
			local e = s.recent[i]
			if e then
				r.mark:SetColorTexture(UI.Color(e.won and "accent" or "bad"))
				r.letter:SetText(e.won and "W" or "L")
				r.word:SetText(e.word)
				r:Show()
			else
				r:Hide()
			end
		end
	end

	local function render()
		local over = game and game:IsOver()
		renderWord()
		renderKeys()
		-- the line above the tiles
		if game then
			local letters = 0
			for _ in game.word:gmatch("[A-Z]") do letters = letters + 1 end
			local text = letters .. " letters"
			if game.category then text = text .. "  |  " .. game.category end
			if game.hintText and game.hintText ~= "" then text = text .. "  |  Hint: " .. game.hintText end
			info:SetText(text)
			local msg, color = stateText(game)
			message:SetText(msg)
			message:SetTextColor(UI.Color(color))
		else
			info:SetText("")
			message:SetText("")
		end
		-- wrong letters
		for i, t in ipairs(wrongTiles) do
			local letter = game and game.wrong[i]
			if letter then
				t.text:SetText(letter)
				t.text:SetTextColor(UI.Color("bad"))
				t.bg:SetColorTexture(UI.Color("badDim"))
				t:Show()
			else
				t:Hide()
			end
		end
		-- attempts and danger
		local used = game and math.min(game:Used(), Logic.MAX_WRONG) or 0
		for i, p in ipairs(pips) do
			p.bg:SetColorTexture(UI.Color(i <= Logic.MAX_WRONG - used and "accent" or "line"))
		end
		for i, s in ipairs(segments) do
			if i <= used then
				local t = i / Logic.MAX_WRONG
				s:SetColorTexture(1 - 0.08 * (1 - t), 0.62 - 0.3 * t, 0.2 - 0.05 * t, 1) -- orange to red
			else
				s:SetColorTexture(UI.Color("line"))
			end
		end
		percent:SetText(math.floor(used / Logic.MAX_WRONG * 100 + 0.5) .. "%")
		-- the buttons
		local can = game and game:CanHint()
		hint:SetLabel("Hint (" .. (game and game.hintsLeft or 0) .. ")")
		hint:SetEnabled2(can and true or false)
		giveUp:SetEnabled2(game ~= nil and not over)
		renderStats()
	end

	-- ------------------------------------------------------------------------------------------------------------------
	-- Playing
	-- ------------------------------------------------------------------------------------------------------------------
	local function finishIfOver()
		if game and game:IsOver() and not recorded then
			recorded = true
			if ARC.db then Stats.Record(ARC.db, who, game, time and time() or 0) end
		end
	end

	local function startGame(newGame)
		game, recorded = newGame, false
		render()
	end

	randomRound = function()
		local avoid = ARC.db and Stats.RecentSet(ARC.db, who) or {}
		local word, name = Logic.Pick(prefs().category, nil, avoid)
		if not word then return end
		startGame(Logic.New(word, { category = name }))
	end

	openOwnBox = function()
		wordBox:SetText("")
		hintBox:SetText("")
		boxError:SetText("")
		dim:Show()
		wordBox:SetFocus()
	end

	local function startOwn()
		local word, why = Logic.Normalize(wordBox:GetText())
		if not word then
			boxError:SetText(why or "")
			return
		end
		local hintText = strtrim and strtrim(hintBox:GetText() or "") or (hintBox:GetText() or "")
		wordBox:SetText("") -- the word must not stay in the box
		dim:Hide()
		startGame(Logic.New(word, { hint = hintText ~= "" and hintText or nil, category = "Own word" }))
	end

	local function newRoundPressed()
		if prefs().mode == "own" then openOwnBox() else randomRound() end
	end

	local function press(letter)
		if not game or game:IsOver() then return end
		local ok = game:Guess(letter)
		if ok then
			finishIfOver()
			render()
		end
	end

	for letter, k in pairs(keys) do
		k:SetScript("OnClick", function() press(letter) end)
		k:SetScript("OnEnter", function(self) if not self.used and game and not game:IsOver() then self.border:SetColor(UI.Color("accent")) end end)
		k:SetScript("OnLeave", function(self) if not self.used then self.border:SetColor(UI.Color("line")) end end)
	end
	hint:SetScript("OnClick", function(self)
		if not self.enabled or not game then return end
		game:Hint()
		finishIfOver()
		render()
	end)
	hint:HookScript("OnEnter", function(self)
		UI.ShowTooltip(self, { "Hint", "Shows one letter you have not guessed and takes one attempt. One hint per round." })
	end)
	hint:HookScript("OnLeave", function() UI.HideTooltip() end)
	giveUp:SetScript("OnClick", function(self)
		if not self.enabled or not game then return end
		game:GiveUp()
		finishIfOver()
		render()
	end)
	newRound:SetScript("OnClick", newRoundPressed)

	boxStart = UI.Button(box, "Start", "accent", startOwn, 120)
	boxStart:SetPoint("BOTTOMRIGHT", -22, 22)
	boxCancel = UI.Button(box, "Cancel", "plain", function()
		wordBox:SetText("")
		dim:Hide()
	end, 110)
	boxCancel:SetPoint("RIGHT", boxStart, "LEFT", -10, 0)
	wordBox:SetScript("OnEnterPressed", startOwn)
	wordBox:SetScript("OnEscapePressed", function() wordBox:SetText("") dim:Hide() end)

	-- ------------------------------------------------------------------------------------------------------------------
	-- The choices at the top
	-- ------------------------------------------------------------------------------------------------------------------
	applyMode = function()
		local own = prefs().mode == "own"
		category:SetShown(not own)
		ownNote:SetShown(own)
	end

	-- ------------------------------------------------------------------------------------------------------------------
	function view.OnShow()
		local p = prefs()
		mode:Set(p.mode)
		category:SetChoice(p.category)
		applyMode()
		if not game then
			if p.mode == "own" then
				render()
				openOwnBox()
			else
				randomRound()
			end
		else
			render()
		end
	end

	function view.OnHide()
		UI.CloseMenu()
		dim:Hide()
		wordBox:SetText("")
	end

	-- for the tests
	view.keys, view.tiles, view.hint, view.giveUp, view.newRound = keys, tiles, hint, giveUp, newRound
	view.mode, view.category, view.dim, view.wordBox, view.hintBox, view.boxStart = mode, category, dim, wordBox, hintBox, boxStart
	view.Game = function() return game end
	view.Render = render
	view.statRows, view.recentRows, view.message = statRows, recentRows, message

	return view
end

ARC.RegisterGame({
	id = "hangman", name = "Hangman",
	blurb = "Guess the WoW word one letter at a time before you run out of attempts. Play with a random word, or let a friend type one for you.",
	tag = "1 player, or 2 on one computer",
	view = build,
})
ARC.RegisterGame({ id = "connect4", name = "Connect Four", blurb = "Classic strategy for two players.", soon = true })
ARC.RegisterGame({ id = "rps", name = "Rock Paper Scissors", blurb = "A timeless classic, best of three.", soon = true })
ARC.RegisterGame({ id = "ships", name = "Battleships", blurb = "Sink the enemy fleet.", soon = true })
