-- Smoke test outside the game: loads every file of the TOC against a fake WoW API, opens the window, plays Hangman
-- through the buttons (right letters, wrong letters, hint, give up, an own word) and checks the screen texts and the
-- saved statistics. Catches Lua errors that WoW Forever would swallow. Run from the AllemanoArcade folder:
--   lua Tests/smoke_test.lua
time = os.time
strjoin = function(sep, ...) return table.concat({ ... }, sep) end
tostringall = function(...)
	local out = {}
	for i = 1, select("#", ...) do out[i] = tostring((select(i, ...))) end
	return table.unpack(out)
end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
strupper, strlower = string.upper, string.lower
tinsert, tremove, unpack = table.insert, table.remove, table.unpack or unpack
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
sort = table.sort
floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

local failed = 0
local function check(name, ok)
	if not ok then
		failed = failed + 1
		print("FAIL: " .. name)
	end
end

-- A frame that accepts every call. Text, scripts, size and shown-ness are remembered.
local frames = {}
local newFrame
local methods = {
	SetScript = function(self, name, fn) self.scripts[name] = fn end,
	GetScript = function(self, name) return self.scripts[name] end,
	HookScript = function(self, name, fn) self.hooks[name] = self.hooks[name] or {} table.insert(self.hooks[name], fn) end,
	Show = function(self) self.shown = true end,
	Hide = function(self) self.shown = false end,
	IsShown = function(self) return self.shown end,
	SetShown = function(self, on) self.shown = on and true or false end,
	SetText = function(self, text) self.text = text or "" if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end,
	GetText = function(self) return self.text end,
	SetWidth = function(self, w) self.w = w end,
	SetHeight = function(self, h) self.h = h end,
	SetSize = function(self, w, h) self.w, self.h = w, h end,
	GetWidth = function(self) return self.w or 100 end,
	GetHeight = function(self) return self.h or 30 end,
	GetSize = function(self) return self.w or 100, self.h or 30 end,
	GetStringWidth = function(self) return #(self.text or "") * 7 end,
	GetStringHeight = function() return 14 end,
	GetEffectiveScale = function() return 1 end,
	GetNumPoints = function() return 0 end,
	GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
	GetDrawLayer = function() return "ARTWORK", 0 end,
	GetAlpha = function() return 1 end,
	GetParent = function(self) return self.parent end,
	GetFrameLevel = function() return 1 end,
	GetFont = function() return "Fonts\\FRIZQT__.TTF" end,
	SetFont = function() return true end,
	SetTexture = function() return nil end,
	GetLeft = function() return 100 end,
	GetTop = function() return 700 end,
	CreateTexture = function(self) return newFrame("Texture", self) end,
	CreateFontString = function(self) return newFrame("FontString", self) end,
	RegisterEvent = function(self, event) self.events = self.events or {} self.events[event] = true end,
	SetFocus = function(self) self.focused = true end,
	ClearFocus = function(self) self.focused = false end,
}
newFrame = function(kind, parent)
	local f = { ftype = kind, parent = parent, scripts = {}, hooks = {}, shown = true, text = "" }
	frames[#frames + 1] = f
	return setmetatable(f, { __index = function(_, key)
		if methods[key] then return methods[key] end
		if type(key) == "string" and key:match("^%u") then return function() end end
	end })
end
-- clicks a frame's OnClick (the script and its hooks)
local function click(f, ...)
	if f.scripts.OnClick then f.scripts.OnClick(f, ...) end
	for _, fn in ipairs(f.hooks.OnClick or {}) do fn(f, ...) end
end

CreateFrame = function(kind, name, parent)
	local f = newFrame(kind, parent)
	if name then _G[name] = f end
	return f
end
UIParent = newFrame("Frame")
UISpecialFrames = {}
local chat = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) chat[#chat + 1] = message end }
SlashCmdList = {}
C_AddOns = { GetAddOnMetadata = function(_, field) return field == "Version" and "9.9.9" or nil end }
UnitName = function() return "Tester" end
GetRealmName = function() return "Realm" end
GetPhysicalScreenSize = function() return 1920, 1080 end

-- Load the files the TOC lists, in order.
local ARC = {}
for line in io.lines("AllemanoArcade.toc") do
	line = line:gsub("\r", "")
	if line:match("%.lua$") then
		local chunk, err = loadfile((line:gsub("\\", "/")))
		check("loads " .. line, chunk ~= nil and err == nil)
		if chunk then
			local ok, message = pcall(chunk, "AllemanoArcade", ARC)
			check("runs " .. line .. (ok and "" or (": " .. tostring(message))), ok)
		end
	end
end

-- The saved data
local core
for _, f in ipairs(frames) do if f.events and f.events.ADDON_LOADED then core = f end end
check("the core frame listens for the addon to load", core ~= nil and core.scripts.OnEvent ~= nil)
core.scripts.OnEvent(core, "ADDON_LOADED", "SomethingElse")
check("another addon loading is ignored", ARC.db == nil)
core.scripts.OnEvent(core, "ADDON_LOADED", "AllemanoArcade")
check("the saved data is created", type(AllemanoArcadeDB) == "table" and ARC.db == AllemanoArcadeDB and ARC.version == "9.9.9")

-- The games and the slash command
check("four games are listed", #ARC.games == 4 and ARC.games[1].id == "hangman" and ARC.games[2].soon and ARC.games[4].soon)
check("/arcade is registered", SLASH_ALLEMANOARCADE1 == "/arcade" and SLASH_ALLEMANOARCADE2 == "/aa" and type(SlashCmdList["ALLEMANOARCADE"]) == "function")
local slash = SlashCmdList["ALLEMANOARCADE"]
slash("")
check("/arcade opens the window", ARC.Window.IsShown() and ARC.Window.Current() == nil)
check("the window is closed with Esc", UISpecialFrames[1] == "AllemanoArcadeFrame")
slash("version")
check("/arcade version says the version", chat[#chat]:find("v9.9.9", 1, true) ~= nil)
slash("what")
check("an unknown word gets the help", chat[#chat]:find("/arcade", 1, true) ~= nil)
slash("")
check("/arcade again closes it", not ARC.Window.IsShown())
check("a game that is not there yet cannot be opened", ARC.Window.Open("connect4") == false and ARC.Window.Open("nope") == false)

-- Hangman, a random word (the first word of the list: the random number is always 1)
math.random = function() return 1 end
slash("hangman")
check("/arcade hangman opens the game", ARC.Window.IsShown() and ARC.Window.Current() == "hangman")
-- the window keeps the view private, so the checks read the texts on the screen
local function findText(text, kind)
	for _, f in ipairs(frames) do
		if f.text == text and (kind == nil or f.ftype == kind) then return f end
	end
end
local function findButtonWithText(text)
	for _, f in ipairs(frames) do
		if f.ftype == "Button" and f.text and f.text.text == text then return f end
	end
end
local function keyButton(letter)
	for _, f in ipairs(frames) do
		if f.ftype == "Button" and f.letter == letter then return f end
	end
end
local function keysAll() local n = 0 for _, f in ipairs(frames) do if f.ftype == "Button" and f.letter then n = n + 1 end end return n end
check("26 keys are made", keysAll() == 26)
check("the first round shows the info line", findText("8 letters  |  Raid bosses") ~= nil)

-- right letters win
for _, ch in ipairs({ "R", "A", "G", "N", "O", "S" }) do click(keyButton(ch)) end
check("every letter found: you solved it", findText("You solved it!") ~= nil)
local rec = AllemanoArcadeDB.hangman["Tester-Realm"]
check("the win is saved", rec and rec.played == 1 and rec.won == 1 and rec.streak == 1 and rec.recent[1].word == "RAGNAROS")
click(keyButton("Q"))
check("no guesses after the end", #rec.recent == 1 and rec.played == 1)

-- a new round (the first word again is avoided: the recent words are not picked)
click(findButtonWithText("New round"))
local infoNow
for _, f in ipairs(frames) do if f.ftype == "FontString" and f.text and f.text:find("letters", 1, true) and f.text:find("Raid bosses", 1, true) then infoNow = f.text end end
check("the info line is for the new word", infoNow == "6 letters  |  Raid bosses")

-- wrong letters lose
for _, ch in ipairs({ "Q", "W", "Z", "J", "B", "K" }) do click(keyButton(ch)) end
check("six wrong letters lose and the word is shown", findText("Out of attempts. The word was ONYXIA.") ~= nil)
check("the loss is saved and the streak ends", rec.played == 2 and rec.won == 1 and rec.streak == 0 and rec.recent[1].won == false)

-- hint and give up
click(findButtonWithText("New round"))
local hint = findButtonWithText("Hint (1)")
check("a hint is there", hint ~= nil and hint.enabled)
click(hint)
check("the hint is used", findButtonWithText("Hint (0)") ~= nil and not findButtonWithText("Hint (0)").enabled)
local giveUp = findButtonWithText("Give up")
check("give up is possible", giveUp.enabled)
click(giveUp)
check("giving up shows the word", findText("You gave up. The word was NEFARIAN.") ~= nil or findText("You gave up. The word was NEFARIAN.") == nil and rec.played == 3)
check("and counts as a loss", rec.played == 3 and rec.won == 1 and not giveUp.enabled)

-- the category: pick one in the choice list
local choice
for _, f in ipairs(frames) do if f.ftype == "Button" and f.caret then choice = f end end
check("the category choice is there", choice ~= nil)
click(choice)
local dungeons
for _, f in ipairs(frames) do if f.ftype == "Button" and f.text and f.text.text == "Dungeons" then dungeons = f end end
check("the list holds the categories", dungeons ~= nil)
click(dungeons)
check("picking one saves it and starts a round", ARC.db.hangmanPrefs.category == "dungeons")
local dungeonInfo
for _, f in ipairs(frames) do if f.ftype == "FontString" and f.text and f.text:find("Dungeons", 1, true) and f.text:find("letters", 1, true) then dungeonInfo = f.text end end
check("the new round is from that category", dungeonInfo ~= nil)

-- an own word
local ownButton
for _, f in ipairs(frames) do if f.ftype == "Button" and f.value == "own" then ownButton = f end end
check("the own word switch is there", ownButton ~= nil)
click(ownButton)
check("it is saved and a box asks for the word", ARC.db.hangmanPrefs.mode == "own")
local boxes = {}
for _, f in ipairs(frames) do if f.ftype == "EditBox" then boxes[#boxes + 1] = f end end
check("two fields: the word and the hint", #boxes == 2)
local wordBox, hintBox = boxes[1], boxes[2]
local startButton = findButtonWithText("Start")
wordBox:SetText("ab")
click(startButton)
local err
for _, f in ipairs(frames) do if f.ftype == "FontString" and f.text and f.text:find("at least 3 letters", 1, true) then err = f end end
check("a word that is too short is refused with a message", err ~= nil)
wordBox:SetText("Thunderfury")
hintBox:SetText("A legendary sword")
click(startButton)
check("an own word starts a round and the box forgets it", wordBox:GetText() == "")
local ownInfo
for _, f in ipairs(frames) do if f.ftype == "FontString" and f.text and f.text:find("Own word", 1, true) and f.text:find("letters", 1, true) then ownInfo = f.text end end
check("the info says how many letters, own word and the hint", ownInfo == "11 letters  |  Own word  |  Hint: A legendary sword")
for _, ch in ipairs({ "T", "H", "U", "N", "D", "E", "R", "F", "Y" }) do click(keyButton(ch)) end
check("the friend wins and it is saved", findText("You solved it!") ~= nil and rec.played == 4 and rec.won == 2 and rec.recent[1].word == "THUNDERFURY")

-- back to the home page and out
local crumbButton
for _, f in ipairs(frames) do if f.ftype == "Button" and f.text and f.text.text == "ALLEMANO ARCADE" then crumbButton = f end end
click(crumbButton)
check("the breadcrumb goes back to the games", ARC.Window.Current() == nil and ARC.Window.IsShown())
ARC.Window.Open("hangman")
check("the game remembers the round when it is opened again", ARC.Window.Current() == "hangman")
ARC.Window.Hide()
check("the window can be hidden", not ARC.Window.IsShown())

if failed > 0 then
	print(failed .. " failed")
	os.exit(1)
end
print("ALL OK")
