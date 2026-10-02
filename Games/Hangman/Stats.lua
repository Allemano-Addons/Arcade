-- Hangman's statistics and the last words played, kept in the saved data. Plain functions on a table, so they can be
-- tested outside the game. Stats are per character: they live in the account-wide saved data under the character's
-- name (the way the other Allemano addons do it), so one player's wins are not another's.
local _, ARC = ...

ARC.Hangman = ARC.Hangman or {}
local Stats = {}
ARC.Hangman.Stats = Stats

Stats.MAX_RECENT = 10

-- The record of one character inside `db` (made when it is missing).
function Stats.Of(db, who)
	db.hangman = db.hangman or {}
	local all = db.hangman
	all[who] = all[who] or { played = 0, won = 0, streak = 0, best = 0, recent = {} }
	local s = all[who]
	s.recent = s.recent or {}
	return s
end

-- Records a finished round (state "won", "lost" or "gaveup"). `now` is a time (for the list of recent words).
function Stats.Record(db, who, game, now)
	if not game or not game:IsOver() then return false end
	local s = Stats.Of(db, who)
	s.played = s.played + 1
	local won = game:Won()
	if won then
		s.won = s.won + 1
		s.streak = s.streak + 1
		if s.streak > s.best then s.best = s.streak end
	else
		s.streak = 0
	end
	table.insert(s.recent, 1, { word = game.word, won = won, t = now or 0, wrong = #game.wrong, category = game.category })
	while #s.recent > Stats.MAX_RECENT do table.remove(s.recent) end
	return true
end

-- The percentage of rounds won (0 when none was played).
function Stats.Rate(s)
	if not s or s.played == 0 then return 0 end
	return math.floor(s.won / s.played * 100 + 0.5)
end

-- The words of the last rounds, as a set (so a new random word is not one you just had).
function Stats.RecentSet(db, who)
	local set = {}
	for _, r in ipairs(Stats.Of(db, who).recent) do set[r.word] = true end
	return set
end

function Stats.Reset(db, who)
	if db.hangman then db.hangman[who] = nil end
end
