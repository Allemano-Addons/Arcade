-- Hangman's words: WoW names in categories. Only A-Z, spaces, apostrophes and hyphens (the others are shown for
-- free). Mostly Classic and The Burning Crusade, since that is what WoW Forever plays. Add words freely: the tests
-- check that every one is playable.
local _, ARC = ...

ARC.Hangman = ARC.Hangman or {}

ARC.Hangman.Categories = {
	{ id = "bosses", name = "Raid bosses", words = {
		"Ragnaros", "Onyxia", "Nefarian", "Razorgore", "Vaelastrasz", "Chromaggus", "Firemaw", "Ebonroc", "Flamegor",
		"Lucifron", "Magmadar", "Gehennas", "Garr", "Baron Geddon", "Shazzrah", "Golemagg", "Majordomo Executus",
		"Moam", "Ossirian", "Ayamiss", "Buru", "Kurinnaz", "Rajaxx", "C'Thun", "Viscidus", "Huhuran", "Skeram",
		"Fankriss", "Sartura", "Ouro", "Thekal", "Hakkar", "Jindo", "Mandokir", "Venoxis", "Arlokk", "Gahzranka",
		"Anub'Rekhan", "Faerlina", "Maexxna", "Noth", "Heigan", "Loatheb", "Patchwerk", "Grobbulus", "Gluth",
		"Thaddius", "Razuvious", "Gothik", "Sapphiron", "Kel'Thuzad", "Attumen", "Moroes", "Curator", "Netherspite",
		"Nightbane", "Malchezaar", "Illhoof", "Maulgar", "Gruul", "Magtheridon", "Hydross", "Leotheras", "Karathress",
		"Morogrim", "Vashj", "Void Reaver", "Solarian", "Kael'thas", "Al'ar", "Rage Winterchill", "Anetheron",
		"Kaz'rogal", "Azgalor", "Archimonde", "Najentus", "Supremus", "Akama", "Gorefiend", "Gurtogg", "Shahraz",
		"Illidan", "Akil'zon", "Nalorakk", "Jan'alai", "Halazzi", "Malacrass", "Zul'jin", "Kalecgos", "Brutallus",
		"Felmyst", "M'uru", "Entropius", "Kil'jaeden", "Sacrolash",
	} },
	{ id = "dungeons", name = "Dungeons", words = {
		"Deadmines", "Wailing Caverns", "Shadowfang Keep", "Blackfathom Deeps", "Stockade", "Gnomeregan",
		"Razorfen Kraul", "Razorfen Downs", "Scarlet Monastery", "Uldaman", "Zul'Farrak", "Maraudon", "Sunken Temple",
		"Blackrock Depths", "Blackrock Spire", "Dire Maul", "Stratholme", "Scholomance", "Ragefire Chasm",
		"Hellfire Ramparts", "Blood Furnace", "Shattered Halls", "Slave Pens", "Underbog", "Steamvault", "Mana-Tombs",
		"Auchenai Crypts", "Sethekk Halls", "Shadow Labyrinth", "Old Hillsbrad", "Black Morass", "Mechanar", "Botanica",
		"Arcatraz", "Magisters' Terrace", "Karazhan", "Molten Core", "Blackwing Lair", "Zul'Gurub", "Naxxramas",
		"Gruul's Lair", "Serpentshrine Cavern", "Tempest Keep", "Black Temple", "Zul'Aman", "Sunwell Plateau",
		"Onyxia's Lair", "Temple of Ahn'Qiraj", "Ruins of Ahn'Qiraj",
	} },
	{ id = "zones", name = "Zones & cities", words = {
		"Elwynn Forest", "Westfall", "Duskwood", "Redridge Mountains", "Stranglethorn Vale", "Stormwind", "Ironforge",
		"Darnassus", "Orgrimmar", "Thunder Bluff", "Undercity", "Silvermoon City", "Exodar", "Shattrath City",
		"Dun Morogh", "Teldrassil", "Mulgore", "Durotar", "Barrens", "Tanaris", "Un'Goro Crater", "Silithus",
		"Winterspring", "Felwood", "Ashenvale", "Stonetalon Mountains", "Desolace", "Feralas", "Thousand Needles",
		"Dustwallow Marsh", "Searing Gorge", "Burning Steppes", "Blasted Lands", "Swamp of Sorrows", "Badlands",
		"Arathi Highlands", "Hillsbrad Foothills", "Alterac Mountains", "Western Plaguelands", "Eastern Plaguelands",
		"Tirisfal Glades", "Silverpine Forest", "Hinterlands", "Azshara", "Moonglade", "Loch Modan", "Wetlands",
		"Deadwind Pass", "Hellfire Peninsula", "Zangarmarsh", "Terokkar Forest", "Nagrand", "Blade's Edge",
		"Netherstorm", "Shadowmoon Valley", "Eversong Woods", "Ghostlands", "Azuremyst Isle", "Bloodmyst Isle",
		"Quel'Danas",
	} },
	{ id = "classes", name = "Classes & specs", words = {
		"Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid", "Arms", "Fury",
		"Protection", "Holy", "Retribution", "Beast Mastery", "Marksmanship", "Survival", "Assassination", "Combat",
		"Subtlety", "Discipline", "Shadow", "Elemental", "Enhancement", "Restoration", "Arcane", "Fire", "Frost",
		"Affliction", "Demonology", "Destruction", "Balance", "Feral Combat", "Tank", "Healer", "Aggro", "Cooldown",
		"Mana", "Rage", "Energy", "Combo Points", "Totem", "Aura", "Stance", "Pet",
	} },
	{ id = "races", name = "Races & factions", words = {
		"Human", "Dwarf", "Night Elf", "Gnome", "Draenei", "Orc", "Undead", "Tauren", "Troll", "Blood Elf",
		"Alliance", "Horde", "Scarlet Crusade", "Argent Dawn", "Cenarion Circle", "Timbermaw Hold",
		"Thorium Brotherhood", "Hydraxian Waterlords", "Aldor", "Scryers", "Sha'tar", "Lower City", "Kurenai",
		"Mag'har", "Honor Hold", "Thrallmar", "Cenarion Expedition", "Keepers of Time", "Consortium", "Netherwing",
		"Ogri'la", "Sporeggar", "Violet Eye", "Ashtongue Deathsworn", "Booty Bay", "Gadgetzan",
		"Ratchet", "Everlook", "Light's Hope", "Stormpike Guard", "Frostwolf Clan", "Silverwing Sentinels",
		"Warsong Outriders", "Defilers", "League of Arathor",
	} },
	{ id = "professions", name = "Professions", words = {
		"Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Herbalism", "Leatherworking", "Mining", "Skinning",
		"Tailoring", "Jewelcrafting", "Cooking", "First Aid", "Fishing", "Lockpicking", "Poisons", "Riding",
		"Disenchant", "Prospecting", "Smelting", "Transmute", "Gem", "Recipe", "Pattern", "Schematic", "Reagent",
	} },
	{ id = "items", name = "Items & gear", words = {
		"Thunderfury", "Sulfuras", "Atiesh", "Ashbringer", "Warglaive", "Dragonspine Trophy", "Arcanite Reaper",
		"Hearthstone", "Healthstone", "Soulstone", "Mana Potion", "Healing Potion", "Supreme Power",
		"Mongoose Elixir", "Black Lotus", "Arcane Crystal", "Thorium Bar", "Mithril Bar", "Felsteel Bar",
		"Primal Fire", "Primal Mana", "Netherweave", "Frostweave", "Runecloth", "Linen Bandage", "Heavy Netherweave",
		"Staff of Jordan", "Eye of Sulfuras", "Windseeker", "Tempest Key", "Karazhan Key",
		"Shadowmoon Key", "Skeleton Key", "Mojo", "Libram", "Totem of Wrath", "Idol of the Moon", "Ogre Hammer",
		"Qiraji Crystal", "Spectral Tiger", "Swift Zulian Tiger", "Raven Lord", "Netherdrake",
	} },
	{ id = "lore", name = "Lore & NPCs", words = {
		"Thrall", "Jaina Proudmoore", "Sylvanas", "Arthas", "Illidan Stormrage", "Tyrande", "Malfurion", "Cairne",
		"Varian Wrynn", "Anduin", "Bolvar Fordragon", "Uther", "Kael'thas Sunstrider", "Velen", "Khadgar",
		"Medivh", "Gul'dan", "Ner'zhul", "Deathwing", "Ysera", "Alexstrasza", "Nozdormu", "Malygos", "Rend Blackhand",
		"Kazzak", "Doomwalker", "Kruul", "Vol'jin", "Garrosh", "Grom Hellscream", "Cenarius",
		"Magni Bronzebeard", "Muradin", "Moira", "Rexxar", "Brann", "Lothar", "Maiev", "Sargeras",
		"Burning Legion", "Scourge", "Lich King", "Dark Portal", "Outland", "Azeroth", "Draenor", "Quel'Thalas",
		"Lordaeron", "Kalimdor",
	} },
}

-- A category by id, or nil.
function ARC.Hangman.Category(id)
	for _, c in ipairs(ARC.Hangman.Categories) do
		if c.id == id then return c end
	end
end
