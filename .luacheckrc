-- luacheck: catches stray globals, typos and unused code. Run from the repository root:  luacheck .
std = "lua51"
max_line_length = false
ignore = { "212" } -- unused arguments (event handlers get more than they use)
exclude_files = { "tests", ".release" }

-- Globals Forever Told defines.
globals = {
    "ForeverToldDB", "ForeverToldAccountDB", "ForeverSagaDB",
    "SLASH_FOREVERTOLD1", "SLASH_FOREVERTOLD2", "ForeverTold_OnAddonCompartmentClick",
    SlashCmdList = { fields = { "FOREVERTOLD" } },
    StaticPopupDialogs = { other_fields = true },
}

-- The game's API, as far as Forever Told uses it.
read_globals = {
    "C_AddOns", "C_ChatInfo", "C_GameRules", "C_Item", "C_Map", "C_QuestLog", "C_Seasons", "C_Timer", "Enum", "Settings",
    "BreakUpLargeNumbers", "CLASS_ICON_TCOORDS", "COMBATLOG_HONORGAIN", "COMBATLOG_OBJECT_REACTION_HOSTILE",
    "COMBATLOG_OBJECT_TYPE_PLAYER", "COMBATLOG_XPGAIN_FIRSTPERSON", "CombatLogGetCurrentEventInfo", "CreateColor",
    "CreateFrame", "GameTooltip", "GameTooltip_Hide", "GetAddOnMemoryUsage", "GetAddOnMetadata", "GetBuildInfo",
    "GetCoinTextureString", "GetCursorPosition", "GetGuildInfo", "GetInstanceInfo", "GetItemInfo", "GetLocale",
    "GetMoney", "GetNumGroupMembers", "GetNumSubgroupMembers", "GetPlayerInfoByGUID", "GetRealZoneText",
    "GetRealmName", "GetSubZoneText", "GetTime", "GetZoneText", "HideUIPanel", "InCombatLockdown",
    "InterfaceOptions_AddCategory", "IsFishingLoot", "IsInGroup", "IsInGuild", "IsInInstance", "IsInRaid",
    "IsMounted", "IsShiftKeyDown", "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "Minimap", "NO", "PlaySound",
    "RAID_CLASS_COLORS", "RegisterAddonMessagePrefix", "ReloadUI", "RequestTimePlayed", "SKILL_RANK_UP",
    "SOUNDKIT", "STANDARD_TEXT_FONT", "Screenshot", "SendAddonMessage", "StaticPopup_Show", "UIParent",
    "UISpecialFrames", "UNKNOWNOBJECT", "UnitCanAttack", "UnitClass", "UnitClassification", "UnitExists",
    "UnitGUID", "UnitInParty", "UnitInRaid", "UnitIsDead", "UnitIsInMyGuild", "UnitIsPlayer", "UnitIsUnit",
    "UnitLevel", "UnitName", "UnitOnTaxi", "UnitRace", "UnitXP", "UnitXPMax", "UpdateAddOnMemoryUsage",
    "WorldFrame", "YES", "bit", "date", "time", "debugprofilestop", "geterrorhandler", "issecretvalue",
    "tContains", "tinsert",
}
