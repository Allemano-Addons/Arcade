-- Offline test of Hangman's rules, words and statistics. Run from the AllemanoArcade folder:  lua Tests/logic_test.lua
time = os.time
local failed = 0
local function check(name, ok)
	if not ok then
		failed = failed + 1
		print("FAIL: " .. name)
	end
end

local ARC = {}
for _, file in ipairs({ "Words", "Logic", "Stats" }) do assert(loadfile("Games/Hangman/" .. file .. ".lua"))("AllemanoArcade", ARC) end
local Logic, Stats, Words = ARC.Hangman.Logic, ARC.Hangman.Stats, ARC.Hangman

-- Normalize: what can be played
check("a word is turned into capitals", Logic.Normalize("Ragnaros") == "RAGNAROS")
check("spaces are trimmed and joined", Logic.Normalize("  Night   Elf ") == "NIGHT ELF")
check("apostrophes and hyphens are fine", Logic.Normalize("C'Thun") == "C'THUN" and Logic.Normalize("Mana-Tombs") == "MANA-TOMBS")
check("nothing is refused with a message", select(2, Logic.Normalize("")) ~= nil and select(2, Logic.Normalize("   ")) ~= nil)
check("not text is refused", Logic.Normalize(nil) == nil and Logic.Normalize(5) == nil)
check("digits and symbols are refused", Logic.Normalize("Mage123") == nil and Logic.Normalize("Frost!") == nil and Logic.Normalize("Mage?") == nil)
check("too few letters are refused", Logic.Normalize("ab") == nil and Logic.Normalize("a-b") == nil and Logic.Normalize("ab c") ~= nil)
check("too long is refused", Logic.Normalize(string.rep("A", 21)) == nil and Logic.Normalize(string.rep("A", 20)) ~= nil)

-- The words: every one is playable, no word twice, no empty category
local seen, count = {}, 0
for _, cat in ipairs(Words.Categories) do
	check("a category has an id, a name and words: " .. cat.id, cat.id and cat.name and #cat.words >= 20)
	for _, w in ipairs(cat.words) do
		count = count + 1
		local norm, why = Logic.Normalize(w)
		check("playable: " .. w .. (why and (" (" .. why .. ")") or ""), norm ~= nil)
		check("not twice: " .. w, not seen[(norm or w)])
		seen[norm or w] = true
	end
end
check("there are plenty of words", count >= 300)
check("a category is found by id", Words.Category("bosses").name == "Raid bosses" and Words.Category("nope") == nil)

-- A round
local g = Logic.New("MAGE", { category = "Classes", rng = function() return 1 end })
check("a round starts playing, with all attempts", g.state == "playing" and g:Left() == Logic.MAX_WRONG and not g:IsOver())
local ok, hit = g:Guess("a")
check("a right letter is a hit (any case)", ok == true and hit == true and g.guessed.A)
ok, hit = g:Guess("Z")
check("a wrong letter takes an attempt", ok == true and hit == false and g:Left() == Logic.MAX_WRONG - 1 and g.wrong[1] == "Z")
check("a letter twice is refused", select(1, g:Guess("A")) == false and select(1, g:Guess("z")) == false and g:Left() == Logic.MAX_WRONG - 1)
check("not a letter is refused", select(1, g:Guess("1")) == false and select(1, g:Guess("AB")) == false and select(1, g:Guess("")) == false and select(1, g:Guess(nil)) == false)
g:Guess("M") g:Guess("G")
check("not won until every letter is found", g.state == "playing")
g:Guess("E")
check("every letter found wins", g.state == "won" and g:Won() and g:IsOver())
check("no guesses after the end", select(1, g:Guess("Q")) == false)

-- Losing
local l = Logic.New("FIRE", {})
for _, ch in ipairs({ "Q", "W", "X", "Y", "Z", "J" }) do l:Guess(ch) end
check("running out of attempts loses", l.state == "lost" and not l:Won() and l:Left() == 0 and #l.wrong == 6)
local slots = l:Slots()
check("a lost round shows the word, the missed letters marked", #slots == 4 and slots[1].shown and slots[1].missed and slots[1].char == "F")

-- Slots
local s = Logic.New("NIGHT ELF", {})
s:Guess("N") s:Guess("E")
local sl = s:Slots()
check("one tile per character", #sl == 9)
check("guessed letters are shown, the others not", sl[1].shown and not sl[2].shown and sl[7].shown)
check("a space is shown for free", sl[6].fixed and sl[6].shown and sl[6].char == " ")
local ap = Logic.New("C'THUN", {}):Slots()
check("an apostrophe is shown for free", ap[2].fixed and ap[2].shown and not ap[1].shown)
check("a word of only the free characters is not possible", Logic.Normalize("'''") == nil)

-- A hint: shows a letter you did not guess, takes an attempt, once, never the last one
local h = Logic.New("WARLOCK", { rng = function(n) return n end }) -- the last of the sorted open letters
check("a hint is possible at the start", h:CanHint())
local hok, letter = h:Hint()
check("a hint shows a letter you did not guess", hok == true and letter == "W" and h.guessed.W and h.hinted.W)
check("and takes an attempt", h:Left() == Logic.MAX_WRONG - 1 and h.hintsUsed == 1 and #h.wrong == 0)
check("only one hint per round", h:CanHint() == false and select(1, h:Hint()) == false)
local h2 = Logic.New("WARLOCK", { rng = function() return 1 end })
h2:Hint()
check("the rng picks among the sorted letters", h2.guessed.A == true)
local h3 = Logic.New("ABC", {})
for _, ch in ipairs({ "Q", "W", "X", "Y", "Z" }) do h3:Guess(ch) end
check("never the last attempt", h3:Left() == 1 and h3:CanHint() == false)
local h4 = Logic.New("ABC", {})
h4:Guess("A")
check("not when one letter is left to find", h4:CanHint() and (function() h4:Guess("B") return h4:CanHint() end)() == false)
local h5 = Logic.New("ABCD", { rng = function() return 1 end })
h5:Guess("A") h5:Guess("B")
local okH, lH = h5:Hint()
check("a hint can complete all but one", okH == true and lH == "C" and h5.state == "playing")

-- Giving up
local u = Logic.New("DRUID", {})
check("giving up ends the round", u:GiveUp() == true and u.state == "gaveup" and u:IsOver() and not u:Won())
check("and shows the word", u:Slots()[1].shown and u:Slots()[1].missed)
check("only once", u:GiveUp() == false)

-- Picking a word
local first = function() return 1 end
local w1, c1 = Logic.Pick("bosses", first)
check("a word comes from the category", w1 == "RAGNAROS" and c1 == "Raid bosses")
local wAll, cAll = Logic.Pick("all", function(n) return n end)
check("any category: the last word of the last list", wAll == "KALIMDOR" and cAll == "Lore & NPCs")
check("an unknown category picks from all of them", Logic.Pick(nil, first) == Logic.Pick("all", first))
check("a category that does not exist gives nothing", Logic.Pick("nope", first) == nil)
local avoidFirst = Logic.Pick("bosses", first, { RAGNAROS = true })
check("recent words are avoided", avoidFirst == "ONYXIA")
local everything = {}
for _, w in ipairs(Words.Category("classes").words) do everything[Logic.Normalize(w)] = true end
check("when everything is recent, a word is still picked", Logic.Pick("classes", first, everything) ~= nil)
local realRandom = math.random
math.random = function(n) return n end
local bossWords = Words.Category("bosses").words
check("without an rng it uses math.random", Logic.Pick("bosses") == Logic.Normalize(bossWords[#bossWords]))
math.random = realRandom

-- Statistics
local db = {}
check("a new character has an empty record", Stats.Of(db, "Me").played == 0 and Stats.Rate(Stats.Of(db, "Me")) == 0)
check("an unfinished round is not recorded", Stats.Record(db, "Me", Logic.New("MAGE", {}), 1) == false)
local won = Logic.New("MAGE", {})
for _, ch in ipairs({ "M", "A", "G", "E" }) do won:Guess(ch) end
local lost = Logic.New("MAGE", {})
for _, ch in ipairs({ "Q", "W", "X", "Y", "Z", "J" }) do lost:Guess(ch) end
check("a win is recorded", Stats.Record(db, "Me", won, 100) == true)
local rec = Stats.Of(db, "Me")
check("with a streak", rec.played == 1 and rec.won == 1 and rec.streak == 1 and rec.best == 1)
Stats.Record(db, "Me", won, 101)
check("the streak grows, the best too", rec.streak == 2 and rec.best == 2)
Stats.Record(db, "Me", lost, 102)
check("a loss ends the streak, the best stays", rec.streak == 0 and rec.best == 2 and rec.played == 3 and rec.won == 2)
check("the win rate is rounded", Stats.Rate(rec) == 67)
check("the last words, the newest first", rec.recent[1].word == "MAGE" and rec.recent[1].won == false and rec.recent[1].wrong == 6 and rec.recent[3].t == 100)
local gaveup = Logic.New("DRUID", {})
gaveup:GiveUp()
Stats.Record(db, "Me", gaveup, 103)
check("giving up counts as a loss", rec.streak == 0 and rec.played == 4 and rec.recent[1].won == false)
for i = 1, 20 do Stats.Record(db, "Me", won, 200 + i) end
check("only the last ten words are kept", #rec.recent == Stats.MAX_RECENT)
check("the recent set holds those words", Stats.RecentSet(db, "Me").MAGE == true and Stats.RecentSet(db, "Nobody").MAGE == nil)
check("characters are kept apart", Stats.Of(db, "Other").played == 0)
Stats.Reset(db, "Me")
check("a record can be reset", Stats.Of(db, "Me").played == 0)

if failed > 0 then
	print(failed .. " failed")
	os.exit(1)
end
print("ALL OK")
