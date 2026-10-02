-- Hangman's rules as plain functions (no frames, no game API), so everything can be tested outside the game.
--
-- A word is stored in capitals. The letters A-Z are guessed; spaces, apostrophes and hyphens are shown for free.
-- A round has MAX_WRONG attempts: each wrong letter takes one, and so does the hint (which shows one letter you did
-- not guess). Every letter found wins; no attempts left loses; giving up loses too.
local _, ARC = ...

ARC.Hangman = ARC.Hangman or {}
local Logic = {}
ARC.Hangman.Logic = Logic

Logic.MAX_WRONG = 6
Logic.MIN_LETTERS, Logic.MAX_LENGTH = 3, 20

local strupper, strmatch, strfind = string.upper, string.match, string.find

-- A word the way it is played: capitals, trimmed, single spaces. Returns the word, or nil and why not.
function Logic.Normalize(text)
	if type(text) ~= "string" then return nil, "Type a word." end
	text = strupper((text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")))
	if text == "" then return nil, "Type a word." end
	if #text > Logic.MAX_LENGTH then return nil, "That is too long (at most " .. Logic.MAX_LENGTH .. " characters)." end
	if strfind(text, "[^A-Z '%-]") then return nil, "Use only the letters A to Z (spaces, ' and - are fine)." end
	local letters = text:gsub("[^A-Z]", "")
	if #letters < Logic.MIN_LETTERS then return nil, "Use at least " .. Logic.MIN_LETTERS .. " letters." end
	return text
end

-- A new round on a normalized word. `opts`: category (a name shown to the player), hint (a text for an own word),
-- rng (for the tests: function(n) -> 1..n).
function Logic.New(word, opts)
	opts = opts or {}
	local game = {
		word = word, category = opts.category, hintText = opts.hint,
		guessed = {}, wrong = {}, hintsUsed = 0, hintsLeft = 1, state = "playing",
		rng = opts.rng or function(n) return math.random(n) end,
	}
	game.letters = {}
	for ch in word:gmatch("[A-Z]") do game.letters[ch] = true end
	local count = 0
	for _ in pairs(game.letters) do count = count + 1 end
	game.letterCount = count
	return setmetatable(game, { __index = Logic })
end

-- How many wrong guesses and hints have been used / are left.
function Logic:Used() return #self.wrong + self.hintsUsed end
function Logic:Left() return Logic.MAX_WRONG - self:Used() end
function Logic:IsOver() return self.state ~= "playing" end

local function foundCount(game)
	local n = 0
	for ch in pairs(game.letters) do
		if game.guessed[ch] then n = n + 1 end
	end
	return n
end

local function check(game)
	if game.state ~= "playing" then return end
	if foundCount(game) == game.letterCount then
		game.state = "won"
	elseif game:Left() <= 0 then
		game.state = "lost"
	end
end

-- A letter A-Z. Returns true, hit (the word has it); or false and a reason (already guessed, round over, not a letter).
function Logic:Guess(letter)
	if self.state ~= "playing" then return false, "The round is over." end
	letter = type(letter) == "string" and strupper(letter) or ""
	if not strmatch(letter, "^[A-Z]$") then return false, "That is not a letter." end
	if self.guessed[letter] then return false, "Already guessed." end
	self.guessed[letter] = true
	local hit = self.letters[letter] == true
	if not hit then self.wrong[#self.wrong + 1] = letter end
	check(self)
	return true, hit
end

-- Whether a hint can be used now: one per round, and never the last attempt.
function Logic:CanHint()
	return self.state == "playing" and self.hintsLeft > 0 and self:Left() > 1 and foundCount(self) < self.letterCount - 1
end

-- Shows one letter you have not guessed, and takes one attempt. Returns true and the letter, or false and a reason.
function Logic:Hint()
	if not self:CanHint() then return false, "No hint now." end
	local open = {}
	for ch in pairs(self.letters) do
		if not self.guessed[ch] then open[#open + 1] = ch end
	end
	table.sort(open) -- so the rng alone decides, not the order pairs() gives
	local letter = open[self.rng(#open)]
	self.guessed[letter] = true
	self.hintsUsed = self.hintsUsed + 1
	self.hintsLeft = self.hintsLeft - 1
	self.hinted = self.hinted or {}
	self.hinted[letter] = true
	check(self)
	return true, letter
end

-- Gives up: the round is lost and the word is shown.
function Logic:GiveUp()
	if self.state ~= "playing" then return false end
	self.state = "gaveup"
	return true
end

-- Whether the round counts as a win.
function Logic:Won() return self.state == "won" end

-- The word as tiles: { { char, shown = true|false, fixed = true|false } ... }. A lost round shows everything.
function Logic:Slots()
	local slots = {}
	local reveal = self.state == "lost" or self.state == "gaveup"
	for ch in self.word:gmatch(".") do
		if strmatch(ch, "[A-Z]") then
			slots[#slots + 1] = { char = ch, shown = self.guessed[ch] == true or reveal, fixed = false, missed = reveal and not self.guessed[ch] }
		else
			slots[#slots + 1] = { char = ch, shown = true, fixed = true }
		end
	end
	return slots
end

-- ---------------------------------------------------------------------------
-- Picking a word
-- ---------------------------------------------------------------------------

-- A random word from a category id, or from all of them ("all"). `avoid` is a set of words not to pick (the
-- recent ones) while there are others to pick. Returns the normalized word and the name of its category.
function Logic.Pick(categoryId, rng, avoid)
	rng = rng or function(n) return math.random(n) end
	avoid = avoid or {}
	local pool = {}
	for _, cat in ipairs(ARC.Hangman.Categories) do
		if categoryId == nil or categoryId == "all" or cat.id == categoryId then
			for _, w in ipairs(cat.words) do pool[#pool + 1] = { word = w, category = cat.name } end
		end
	end
	if #pool == 0 then return nil end
	local fresh = {}
	for _, entry in ipairs(pool) do
		if not avoid[strupper(entry.word)] then fresh[#fresh + 1] = entry end
	end
	if #fresh == 0 then fresh = pool end
	local chosen = fresh[rng(#fresh)]
	return (Logic.Normalize(chosen.word)), chosen.category
end
