-- Allemano Arcade: small games for WoW Forever. This file is the namespace, the saved data, the list of games and
-- the slash command. Each game is a module that registers itself with ARC.RegisterGame and builds its own view; the
-- window around them is Window.lua.
local addonName, ARC = ...

ARC.name = addonName

local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

ARC.games = {} -- in the order they were registered

-- A game: { id, name, blurb, tag (a short line on its card), view = function(parent) -> { frame, OnShow, OnHide },
-- soon = true for a card that is shown but cannot be opened yet }.
function ARC.RegisterGame(def)
	ARC.games[#ARC.games + 1] = def
	return def
end

function ARC:Print(...)
	DEFAULT_CHAT_FRAME:AddMessage("|cffa3e635Allemano Arcade|r " .. strjoin(" ", tostringall(...)))
end

-- The name the statistics are kept under: this character.
function ARC.Who()
	local name = UnitName and UnitName("player")
	local realm = GetRealmName and GetRealmName()
	return (name or "Player") .. (realm and ("-" .. realm) or "")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, name)
	if name ~= addonName then return end
	if type(AllemanoArcadeDB) ~= "table" then AllemanoArcadeDB = {} end
	ARC.db = AllemanoArcadeDB
	ARC.version = getMetadata and getMetadata(addonName, "Version") or "?"
end)

SLASH_ALLEMANOARCADE1 = "/arcade"
SLASH_ALLEMANOARCADE2 = "/aa"
SlashCmdList["ALLEMANOARCADE"] = function(text)
	local word = strlower((text or ""):match("^%s*(%S*)") or "")
	if word == "" or word == "open" then
		ARC.Window.Toggle()
	elseif word == "hangman" then
		ARC.Window.Open("hangman")
	elseif word == "version" then
		ARC:Print("v" .. tostring(ARC.version))
	else
		ARC:Print("/arcade opens the games. /arcade hangman goes straight to Hangman.")
	end
end
