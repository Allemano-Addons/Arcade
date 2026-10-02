std = "lua51"
max_line_length = false
exclude_files = { "Tests/" } -- the tests replace the game API on purpose
ignore = { "212/self", "212/_.*", "211", "311", "411", "421", "431" } -- style warnings: unused locals, shadowing

globals = { "AllemanoArcadeDB", "SLASH_ALLEMANOARCADE1", "SLASH_ALLEMANOARCADE2", "SlashCmdList" }

read_globals = {
	"C_AddOns", "C_Timer", "GetAddOnMetadata", "CreateFrame", "DEFAULT_CHAT_FRAME", "strjoin", "tostringall", "time", "date",
	"UIParent", "UISpecialFrames", "GameTooltip", "LibStub", "GetPhysicalScreenSize", "STANDARD_TEXT_FONT",
	"UnitName", "GetRealmName", "strtrim", "floor", "ceil", "max", "min", "strupper", "strlower", "tinsert", "tremove", "wipe", "sort", "unpack",
}
