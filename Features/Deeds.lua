-- Forever Told deeds: home-made, vanilla-flavoured badges. Each deed has a
-- check that reads the journal's own records, so no combat data is needed.

local _, ns = ...

local Count = ns.U.Count

local function Norm(s) return (s:lower():gsub("^the ", ""):gsub("[^%a]", "")) end

-- Dungeon names as the zone text shows them, with common variants.
local EK_DUNGEONS = {
    { "The Deadmines", "Deadmines" }, { "The Stockade", "Stormwind Stockade" }, { "Gnomeregan" },
    { "Shadowfang Keep" }, { "Scarlet Monastery" }, { "Uldaman" },
    { "The Temple of Atal'Hakkar", "Sunken Temple" }, { "Blackrock Depths" },
    { "Blackrock Spire", "Lower Blackrock Spire", "Upper Blackrock Spire" },
    { "Scholomance" }, { "Stratholme" },
}
local KALIMDOR_DUNGEONS = {
    { "Ragefire Chasm" }, { "Wailing Caverns" }, { "Blackfathom Deeps" }, { "Razorfen Kraul" },
    { "Razorfen Downs" }, { "Zul'Farrak" }, { "Maraudon" }, { "Dire Maul" },
}

local function DungeonsDone(list)
    local visited = {}
    for zone, info in pairs(ns.DB.zones) do
        if info.instance then visited[Norm(zone)] = true end
    end
    local done = 0
    for _, names in ipairs(list) do
        for _, n in ipairs(names) do
            if visited[Norm(n)] then done = done + 1 break end
        end
    end
    return done
end

local function NoteCount()
    local n = 0
    for _, e in ipairs(ns.DB.entries) do if e.kind == "note" then n = n + 1 end end
    return n
end

local function BestFriendRuns()
    local best = 0
    for _, f in pairs(ns.DB.fellows) do if f.dungeons > best then best = f.dungeons end end
    return best
end

local function TopSkill()
    local best = 0
    for key in pairs(ns.DB.skills) do
        local rank = tonumber(key:match(":(%d+)$"))
        if rank and rank > best then best = rank end
    end
    return best
end

local function GrudgeSum(field)
    local n = 0
    for _, g in pairs(ns.DB.grudges or {}) do n = n + (g[field] or 0) end
    return n
end

local function Settled()
    local n = 0
    for _, g in pairs(ns.DB.grudges or {}) do if g.kills > 0 and not ns.GrudgeOpen(g) then n = n + 1 end end
    return n
end

local function WorstGrudge()
    local n = 0
    for _, g in pairs(ns.DB.grudges or {}) do if g.kills > n then n = g.kills end end
    return n
end

local function C(name) return ns.DB.counters[name] or 0 end
local function Killed(name) return ns.DB.counters.kills and ns.DB.counters.kills[name] and 1 or 0 end

-- { id, name, description, progress function, goal }
ns.DEEDS = {
    { "firstquest", "First Steps", "Complete your first quest.", function() return ns.DB.quests end, 1 },
    { "quests100", "Errand Runner", "Complete 100 quests.", function() return ns.DB.quests end, 100 },
    { "quests500", "Hero for Hire", "Complete 500 quests.", function() return ns.DB.quests end, 500 },
    { "places25", "Wanderer", "Discover 25 places.", function() return Count(ns.DB.zones) end, 25 },
    { "places75", "Cartographer", "Discover 75 places.", function() return Count(ns.DB.zones) end, 75 },
    { "dungeons5", "Deep Delver", "Enter 5 different dungeons.", function()
        local n = 0 for _, z in pairs(ns.DB.zones) do if z.instance then n = n + 1 end end return n end, 5 },
    { "ekdungeons", "Eastern Kingdoms Delver", "Enter every Eastern Kingdoms dungeon.", function() return DungeonsDone(EK_DUNGEONS) end, #EK_DUNGEONS },
    { "kaldungeons", "Kalimdor Delver", "Enter every Kalimdor dungeon.", function() return DungeonsDone(KALIMDOR_DUNGEONS) end, #KALIMDOR_DUNGEONS },
    { "bosses10", "Boss Slayer", "Defeat 10 different bosses.", function() return Count(ns.DB.bosses) end, 10 },
    { "bosses50", "Dungeon Legend", "Defeat 50 different bosses.", function() return Count(ns.DB.bosses) end, 50 },
    { "fellows10", "Fellowship", "Group with 10 different adventurers.", function() return Count(ns.DB.fellows) end, 10 },
    { "fellows50", "Well Known", "Group with 50 different adventurers.", function() return Count(ns.DB.fellows) end, 50 },
    { "oldfriends", "Old Friends", "Run 10 dungeons with the same person.", BestFriendRuns, 10 },
    { "fish100", "Angler", "Catch 100 fish.", function() return C("fish") end, 100 },
    { "fish500", "Master Angler", "Catch 500 fish.", function() return C("fish") end, 500 },
    { "mount", "Saddle Up", "Ride a mount for the first time.", function() return C("mounted") end, 1 },
    { "flight", "Frequent Flyer", "Take 25 flights.", function() return C("flights") end, 25 },
    { "hogger", "Hogger Hunter", "Slay Hogger, terror of Elwynn.", function() return Killed("Hogger") end, 1 },
    { "morladim", "Grave Matters", "Slay Mor'Ladim in Duskwood.", function() return Killed("Mor'Ladim") end, 1 },
    { "stitches", "Unstitched", "Slay Stitches on the road to Darkshire.", function() return Killed("Stitches") end, 1 },
    { "gold100", "Heavy Purse", "Hold 100 gold at once.", function() return math.floor(ns.DB.goldPeak / 10000) end, 100 },
    { "artisan", "Artisan", "Reach 225 in any skill.", TopSkill, 225 },
    { "master", "Master Crafter", "Reach 300 in any skill.", TopSkill, 300 },
    { "level30", "Halfway to Legend", "Reach level 30.", function() return UnitLevel("player") end, 30 },
    { "level60", "Legend", "Reach level 60.", function() return UnitLevel("player") end, 60 },
    { "survivor", "Survivor", "Reach level 20 without dying once.", function()
        if ns.DB.startLevel > 1 then return 0 end
        return (ns.DB.deaths == 0 and UnitLevel("player") >= 20) and 1 or 0 end, 1 },
    { "phoenix", "Phoenix", "Die 25 times. Get up 25 times.", function() return ns.DB.deaths end, 25 },
    { "scribe", "Scribe", "Write 10 notes in your story.", NoteCount, 10 },
    { "revenge1", "Sweet Revenge", "Take revenge on someone who ganked you.", function() return GrudgeSum("revenge") end, 1 },
    { "revenge10", "Vendetta", "Take revenge 10 times.", function() return GrudgeSum("revenge") end, 10 },
    { "settled", "Even Steven", "Get even with 5 different gankers.", Settled, 5 },
    { "nemesis", "Nemesis", "Be killed 5 times by the same player.", WorstGrudge, 5 },
    { "avenged", "Not Alone", "Have a guildie avenge you through the bounty board.", function() return GrudgeSum("avenged") end, 1 },
    { "hunter1", "Bounty Hunter", "Collect a guild bounty.", function() return C("bounties") end, 1 },
    { "hunter10", "Guild Enforcer", "Collect 10 guild bounties.", function() return C("bounties") end, 10 },
}

function ns.DeedProgress(deed)
    local ok, value = pcall(deed[4])
    value = ok and tonumber(value) or 0
    return math.min(value, deed[5]), deed[5]
end

local checking = false
-- silent: grant without announcing (used once, for deeds a character had
-- already earned before this version was installed).
function ns.CheckDeeds(silent)
    local DB = ns.DB
    if checking or not DB then return end
    checking = true
    for _, deed in ipairs(ns.DEEDS) do
        local id = deed[1]
        if not DB.deeds[id] then
            local value, goal = ns.DeedProgress(deed)
            if value >= goal then
                DB.deeds[id] = { t = time(), lvl = UnitLevel("player"), earlier = silent or nil }
                if not silent then
                    ns.Bump("deeds")
                    ns.Add("deed", ("Deed earned: %s. %s"):format(deed[2], deed[3]))
                    ns.Emit("deed", deed[2], deed[3])
                    if ns.ShowToast then ns.ShowToast("Deed earned", deed[2], deed[3]) end
                end
            end
        end
    end
    checking = false
end

-- Counters the deeds need -----------------------------------------------------

local function Inc(name) ns.DB.counters[name] = (ns.DB.counters[name] or 0) + 1 end

local FAMOUS = { ["Hogger"] = true, ["Mor'Ladim"] = true, ["Stitches"] = true }
local lastLoot = 0
ns.On("LOOT_READY", function()
    if GetTime() - lastLoot < 1 then return end -- LOOT_READY can fire twice
    lastLoot = GetTime()
    if IsFishingLoot and IsFishingLoot() then
        Inc("fish")
        ns.CheckDeeds()
        return
    end
    -- Famous named mobs: looting their corpse counts as the kill.
    if UnitExists("target") and UnitIsDead("target") then
        local name = UnitName("target")
        if name and not ns.U.issecret(name) and FAMOUS[name] then
            ns.DB.counters.kills = ns.DB.counters.kills or {}
            ns.DB.counters.kills[name] = true
            ns.CheckDeeds()
        end
    end
end)

-- Mounts and flights, checked every few seconds (cheap and works on both clients).
local wasMounted, wasOnTaxi = false, false
local ticker
ns.On("PLAYER_ENTERING_WORLD", function()
    if ticker then return end
    ticker = C_Timer.NewTicker(3, function()
        local mounted = IsMounted and IsMounted() or false
        if mounted and not wasMounted and C("mounted") == 0 then
            Inc("mounted")
            ns.CheckDeeds()
        end
        wasMounted = mounted
        local onTaxi = UnitOnTaxi and UnitOnTaxi("player") or false
        if onTaxi and not wasOnTaxi then
            Inc("flights")
            ns.CheckDeeds()
        end
        wasOnTaxi = onTaxi
    end)
    ns.CheckDeeds(not ns.DB.deedsSeeded)
    ns.DB.deedsSeeded = true
end)
