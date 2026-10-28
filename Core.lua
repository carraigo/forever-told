-- Forever Told: your story, forever told.
-- Keeps a per-character journal of the journey to 60. Nothing here touches
-- combat data, so the Midnight-era restrictions don't get in the way.
--
--   /told                 open the journal (or click the minimap button)
--   /told <page>          open a page: journal, fellowship, deeds, grudges,
--                         bounties, rivals, atlas, stats, settings
--   /told note <text>     add your own line to the journal
--   /told recent          print the last ten entries to chat
--   /told shots|banner|minimap|time|alerts|bounty|rare   flip a setting
--   /told export|import   back up your story, or bring one back
--   /told epitaph         the Hardcore memorial stone (or how it would read)

local ADDON, ns = ...
local U = ns.U

local PREFIX = "|cffc9a227Forever Told|r"
local QUEST_MILESTONE = 25
local GOLD = 10000 -- copper

function ns.Print(msg) print(PREFIX .. " " .. msg) end
local Print = ns.Print
local Pick, issecret = U.Pick, U.issecret

-- Several modules can listen to the same event.
ns.listeners = {}
function ns.On(event, fn)
    ns.listeners[event] = ns.listeners[event] or {}
    table.insert(ns.listeners[event], fn)
end

-- Per-chapter tallies for the chapter recap. Chapter 0 is levels 1-9.
function ns.ChapterOf(level) return math.min(6, math.floor((level or 1) / 10)) end
function ns.Bump(field, amount)
    local c = ns.ChapterOf(UnitLevel("player"))
    local stats = ns.DB.chapterStats[c]
    if not stats then
        stats = {}
        ns.DB.chapterStats[c] = stats
    end
    stats[field] = (stats[field] or 0) + (amount or 1)
end
local Bump = ns.Bump

function ns.Zone()
    local zone = GetRealZoneText and GetRealZoneText() or GetZoneText()
    return (zone and zone ~= "") and zone or "somewhere unknown"
end
local Zone = ns.Zone

-- Walk up the map tree to find the continent the player is on.
local function Continent()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local mapID = C_Map.GetBestMapForUnit("player")
    local continentType = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
    for _ = 1, 10 do
        if not mapID then return nil end
        local info = C_Map.GetMapInfo(mapID)
        if not info then return nil end
        if info.mapType == continentType then return info.name end
        mapID = info.parentMapID
    end
end

-- Time played --------------------------------------------------------------
-- One /played request at login gives a baseline; after that we count
-- session time ourselves, so we never spam chat again.

local played = { total = nil, at = nil }

local function PlayedNow()
    if not played.total then return nil end
    return played.total + (GetTime() - played.at)
end
ns.PlayedNow = PlayedNow

-- Entries --------------------------------------------------------------------

-- Grudges and posters live on the Grudges page, not in the story.
local OFF_JOURNAL = { pvp = true, revenge = true }

function ns.Add(kind, text, level)
    local DB = ns.DB
    if OFF_JOURNAL[kind] then
        if ns.CheckDeeds then ns.CheckDeeds() end
        if ns.Refresh then ns.Refresh() end
        return
    end
    local entry = { t = time(), lvl = level or UnitLevel("player"), zone = Zone(), kind = kind, text = text }
    table.insert(DB.entries, entry)
    if ns.CheckDeeds then ns.CheckDeeds() end
    if ns.Refresh then ns.Refresh() end
    return entry
end
local Add = ns.Add

local handlers = {}

local function CheckZone()
    local DB = ns.DB
    local zone = Zone()
    if DB.zones[zone] then return end
    local inInstance = IsInInstance()
    DB.zones[zone] = { t = time(), lvl = UnitLevel("player"), continent = Continent(), instance = inInstance and true or nil }
    if inInstance then
        Bump("dungeons")
        Add("dungeon", Pick(ns.FLAVOUR.dungeon):format(zone))
    else
        Bump("places")
        Add("zone", Pick(ns.FLAVOUR.zone):format(zone))
    end
end

handlers.PLAYER_ENTERING_WORLD = function(isLogin, isReload)
    local DB = ns.DB
    if #DB.entries == 0 then
        Add("start", ("The story of %s the %s begins in %s."):format(UnitName("player"), (UnitClass("player")), Zone()))
    end
    CheckZone()
    if (isLogin or isReload or isLogin == nil) and not played.total and DB.trackTime and RequestTimePlayed then
        RequestTimePlayed()
    end
end
handlers.ZONE_CHANGED_NEW_AREA = CheckZone

handlers.TIME_PLAYED_MSG = function(total, thisLevel)
    local DB = ns.DB
    if issecret(total) then return end
    played.total, played.at = total, GetTime()
    DB.lastPlayed = total
    -- When this level started, in total-played seconds.
    DB.levelStartedAt = total - (thisLevel or 0)
end

handlers.PLAYER_LEVEL_UP = function(level)
    local DB = ns.DB
    local now = PlayedNow()
    if now and DB.levelStartedAt then
        DB.levelTimes[level - 1] = math.floor(now - DB.levelStartedAt)
        DB.levelStartedAt = now
    end
    -- A new chapter: close the old one with a recap first.
    if level % 10 == 0 and ns.WriteRecap then ns.WriteRecap(ns.ChapterOf(level - 1), level - 1) end
    Add("level", Pick(ns.FLAVOUR.level):format(level, Zone()), level)
    if ns.MILESTONE_LEVELS[level] then Add("level", ns.MILESTONE_LEVELS[level], level) end
    if ns.ShowBanner and DB.banner then ns.ShowBanner(level) end
    if DB.screenshots then
        -- Wait a moment so the level-up glow (and our banner) are on screen.
        C_Timer.After(1.5, function()
            Screenshot()
            DB.shots = DB.shots + 1
        end)
    end
end

handlers.QUEST_TURNED_IN = function(questID)
    local DB = ns.DB
    DB.quests = DB.quests + 1
    Bump("quests")
    local title
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        title = C_QuestLog.GetTitleForQuestID(questID)
    elseif C_QuestLog and C_QuestLog.GetQuestInfo then -- Classic Era
        title = C_QuestLog.GetQuestInfo(questID)
    end
    if DB.quests == 1 then
        Add("quest", ("First quest done: %s."):format(title or "a humble errand"))
    elseif DB.quests % QUEST_MILESTONE == 0 then
        Add("quest", ("%d quests completed. The latest: %s."):format(DB.quests, title or "another job well done"))
    end
end

handlers.PLAYER_DEAD = function()
    local DB = ns.DB
    local zone = Zone()
    DB.deaths = DB.deaths + 1
    DB.deathZones[zone] = (DB.deathZones[zone] or 0) + 1
    Bump("deaths")
    -- Killed by a player: Grudges.lua already wrote a better line.
    if ns.pvpDeath then ns.pvpDeath = nil return end
    Add("death", Pick(ns.FLAVOUR.death):format(zone))
end

handlers.PLAYER_MONEY = function()
    local DB = ns.DB
    local money = GetMoney()
    if money > DB.goldPeak then DB.goldPeak = money end
    for _, goal in ipairs({ 1, 10, 100, 1000 }) do
        if money >= goal * GOLD and not DB.goldMarks[goal] then
            DB.goldMarks[goal] = true
            Add("gold", goal == 1 and "First gold coin in the purse." or ("%d gold saved up."):format(goal))
        end
    end
end

-- First boss kills. ENCOUNTER_END covers dungeons and raids on both clients;
-- BOSS_KILL is a fallback. Each boss is written down once.
local lastKill = {}
local function BossKilled(id, name)
    local DB = ns.DB
    if not id or issecret(id) or issecret(name) then return end
    -- ENCOUNTER_END and BOSS_KILL can both fire for one kill.
    if lastKill[id] and GetTime() - lastKill[id] < 10 then return end
    lastKill[id] = GetTime()
    if ns.OnBossKill then ns.OnBossKill(id, name) end
    if DB.bosses[id] then return end
    DB.bosses[id] = { t = time(), name = name, zone = Zone() }
    Bump("bosses")
    Add("boss", Pick(ns.FLAVOUR.boss):format(name or "a mighty foe"))
end
handlers.ENCOUNTER_END = function(id, name, _, _, success)
    if success == 1 or success == true then BossKilled(id, name) end
end
handlers.BOSS_KILL = function(id, name) BossKilled(id, name) end

-- Chat-based trackers: loot and skill-ups ------------------------------------------

local function Pattern(fmt)
    local p = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end
local LOOT_SELF = LOOT_ITEM_SELF and Pattern(LOOT_ITEM_SELF)
local LOOT_SELF_MULTI = LOOT_ITEM_SELF_MULTIPLE and Pattern(LOOT_ITEM_SELF_MULTIPLE)
local SKILL_UP = Pattern(SKILL_RANK_UP or "Your skill in %s has increased to %d.")

local function ItemQuality(link)
    if C_Item and C_Item.GetItemQualityByID then
        local q = C_Item.GetItemQualityByID(link)
        if q then return q end
    end
    if GetItemInfo then return select(3, GetItemInfo(link)) end
end

handlers.CHAT_MSG_LOOT = function(msg)
    local DB = ns.DB
    if issecret(msg) or type(msg) ~= "string" then return end
    local link = (LOOT_SELF_MULTI and msg:match(LOOT_SELF_MULTI)) or (LOOT_SELF and msg:match(LOOT_SELF))
    if not link then return end
    local quality = ItemQuality(link)
    if quality and quality >= DB.lootQuality then
        DB.epics = DB.epics + 1
        Bump("loot")
        Add("loot", ("Found %s in %s."):format(link, Zone()))
    end
end

handlers.CHAT_MSG_SKILL = function(msg)
    local DB = ns.DB
    if issecret(msg) or type(msg) ~= "string" then return end
    local skill, rank = msg:match(SKILL_UP)
    rank = tonumber(rank)
    if not skill or not ns.SKILL_MILESTONES[rank] then return end
    local key = skill .. ":" .. rank
    if DB.skills[key] then return end
    DB.skills[key] = time()
    Add("skill", ("%s reached %d. %s %s!"):format(skill, rank, ns.SKILL_MILESTONES[rank], skill:lower()))
end

-- Saved data -------------------------------------------------------------------------

local TABLES = { "entries", "zones", "goldMarks", "bosses", "skills", "levelTimes", "deathZones", "fellows",
    "deeds", "counters", "recaps", "grudges", "bounties", "gankHours", "window", "posters", "debts" }
local VALUES = { quests = 0, deaths = 0, shots = 0, epics = 0, goldPeak = 0, lootQuality = 4 }

-- Upgrades to saved data. DB.version counts how many have run, so each one
-- runs once per character. Add new ones to the end; never reorder them.
local function IsTest(name) return type(name) == "string" and name:find("-Testrealm", 1, true) ~= nil end

local MIGRATIONS = {
    -- 1. Version 0.1 stored a bare timestamp per zone.
    function(DB)
        for zone, v in pairs(DB.zones) do
            if type(v) == "number" then DB.zones[zone] = { t = v } end
        end
    end,
    -- 2. Version 0.4 only kept each killer's latest zone; seed the rivalry map from that.
    function(DB)
        if DB.gankZones then return end
        DB.gankZones = {}
        for _, g in pairs(DB.grudges) do
            local z = g.zone or "somewhere unknown"
            DB.gankZones[z] = DB.gankZones[z] or { kills = 0, revenge = 0 }
            DB.gankZones[z].kills = DB.gankZones[z].kills + g.kills
        end
    end,
    -- 3. Version 0.8.3: test mode is gone, and grudges left the journal.
    function(DB)
        for i = #DB.entries, 1, -1 do
            local e = DB.entries[i]
            if e.test or OFF_JOURNAL[e.kind] or (e.kind == "note" and type(e.text) == "string" and e.text:find("^Paid .+ gold for taking down")) then
                table.remove(DB.entries, i)
            end
        end
        for _, key in ipairs({ "grudges", "bounties", "posters" }) do
            for name in pairs(DB[key]) do if IsTest(name) then DB[key][name] = nil end end
        end
        for name, b in pairs(DB.bounties) do
            for poster in pairs(b.posters or {}) do if IsTest(poster) then b.posters[poster] = nil end end
            if not next(b.posters or {}) then DB.bounties[name] = nil end
        end
        for i = #DB.debts, 1, -1 do
            if IsTest(DB.debts[i].name) or IsTest(DB.debts[i].to) then table.remove(DB.debts, i) end
        end
        if DB.testSnapshot then
            for key, saved in pairs(DB.testSnapshot) do DB[key] = saved end
            DB.testSnapshot = nil
        end
    end,
    -- 4. Version 0.9: bounties remember when they first went up, for poster wear.
    function(DB)
        for _, b in pairs(DB.bounties) do b.since = b.since or b.t end
    end,
}

local function InitDB()
    -- Adopt saved data from the addon's earlier name, once.
    if not ForeverToldDB and ForeverSagaDB then ForeverToldDB = ForeverSagaDB end
    ForeverSagaDB = nil
    ForeverToldDB = ForeverToldDB or {}
    local DB = ForeverToldDB
    ns.DB = DB
    for _, key in ipairs(TABLES) do DB[key] = DB[key] or {} end
    for key, value in pairs(VALUES) do if DB[key] == nil then DB[key] = value end end
    DB.minimap = DB.minimap or { angle = 200, hidden = false }
    for _, s in ipairs(ns.SETTINGS) do
        if s.key and DB[s.key] == nil then DB[s.key] = s.default end
    end
    if not DB.chapterStats then
        DB.chapterStats = {}
        -- Upgrading mid-chapter: this chapter's tallies only start now.
        if #DB.entries > 0 then DB.chapterStats[ns.ChapterOf(UnitLevel("player"))] = { partial = true } end
    end
    if DB.startLevel == nil then
        DB.startLevel = (#DB.entries > 0 and DB.entries[1].lvl) or UnitLevel("player")
    end
    -- Run each upgrade this character hasn't had yet, once, in order.
    for i = (DB.version or 0) + 1, #MIGRATIONS do MIGRATIONS[i](DB) end
    DB.version = #MIGRATIONS
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        InitDB()
        for name, fn in pairs(handlers) do ns.On(name, fn) end
        for name in pairs(ns.listeners) do pcall(self.RegisterEvent, self, name) end
        if ns.CreateMinimapButton then ns.CreateMinimapButton() end
        self:UnregisterEvent("ADDON_LOADED")
        return
    end
    local list = ns.listeners[event]
    if list then
        for _, fn in ipairs(list) do fn(...) end
    end
end)

-- Settings ----------------------------------------------------------------------------
-- One list drives the Settings page and the slash commands.

ns.SETTINGS = {
    { section = "Journal" },
    { key = "screenshots", default = true, slash = "shots", label = "Take a screenshot on every level-up", chat = "Screenshots on level-up" },
    { key = "banner", default = true, slash = "banner", label = "Show the level-up banner and chapter recap card", chat = "Level-up banner" },
    { key = "trackTime", default = true, slash = "time", label = "Track time per level (asks for /played once per login)", chat = "Time-per-level tracking" },
    { slash = "rare", label = "Also record rare (blue) loot, not just epics", chat = "Recording rare loot",
      get = function() return ns.DB.lootQuality == 3 end, set = function(v) ns.DB.lootQuality = v and 3 or 4 end },
    { section = "PvP" },
    { key = "grudgeAlerts", default = true, slash = "alerts", label = "Warn me when a nemesis or guild bounty is nearby", chat = "Nearby warnings" },
    { key = "shareBounties", default = true, slash = "bounty", label = "Post my grudges on my guild's bounty board", chat = "Bounty board sharing" },
    { section = "Interface" },
    { slash = "minimap", label = "Show the minimap button", chat = "Minimap button",
      get = function() return not ns.DB.minimap.hidden end,
      set = function(v)
          ns.DB.minimap.hidden = not v
          if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
      end },
}

function ns.GetSetting(s)
    if s.get then return s.get() end
    return ns.DB[s.key] and true or false
end

function ns.SetSetting(s, value)
    if s.set then s.set(value) else ns.DB[s.key] = value end
    if ns.Refresh then ns.Refresh() end
end

-- Slash commands -----------------------------------------------------------------------

SLASH_FOREVERTOLD1 = "/told"
SLASH_FOREVERTOLD2 = "/forevertold"
SlashCmdList.FOREVERTOLD = function(msg)
    local DB = ns.DB
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "recent" then
        for i = math.max(1, #DB.entries - 9), #DB.entries do
            local e = DB.entries[i]
            Print(("[%d] %s"):format(e.lvl or 0, e.text))
        end
        return
    elseif cmd == "note" and rest ~= "" then
        Add("note", rest)
        Print("Added to your story.")
        return
    elseif cmd == "epitaph" and ns.ShowEpitaph then
        ns.ShowEpitaph()
        return
    elseif (cmd == "export" or cmd == "import") and ns.ShowTransfer then
        ns.ShowTransfer(cmd)
        return
    elseif cmd == "loot" then -- older spelling of /told rare
        for _, s in ipairs(ns.SETTINGS) do
            if s.slash == "rare" then ns.SetSetting(s, rest:lower() == "rare") end
        end
        Print("Writing down " .. (DB.lootQuality == 3 and "rare (blue) and better" or "epic (purple)") .. " loot.")
        return
    end
    for _, s in ipairs(ns.SETTINGS) do
        if s.slash == cmd then
            ns.SetSetting(s, not ns.GetSetting(s))
            Print(s.chat .. (ns.GetSetting(s) and " on." or " off."))
            return
        end
    end
    if cmd ~= "" and ns.HasPage and ns.HasPage(cmd) then ns.Open(cmd) else ns.Toggle() end
end
