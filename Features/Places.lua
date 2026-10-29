-- Forever Told places: a little story for every zone in the atlas. Arrival
-- level and date come from the journal; here we add the time spent, quests
-- done and foes slain there. Deaths and ganks already have their own tallies.

local _, ns = ...

local here, since -- the zone we're in, and when we got here (GetTime)

function ns.ZoneStats(zone)
    local DB = ns.DB
    DB.zoneStats[zone] = DB.zoneStats[zone] or {}
    return DB.zoneStats[zone]
end

local function Flush()
    if here and since then
        local z = ns.ZoneStats(here)
        z.time = (z.time or 0) + math.floor(GetTime() - since)
    end
    here, since = nil, nil
end

local function Arrive()
    Flush()
    here, since = ns.Zone(), GetTime()
end

ns.Listen("quest", function()
    local z = ns.ZoneStats(ns.Zone())
    z.quests = (z.quests or 0) + 1
end)

ns.On("PLAYER_ENTERING_WORLD", Arrive)
ns.On("ZONE_CHANGED_NEW_AREA", Arrive)
ns.On("PLAYER_LEAVING_WORLD", Flush)
ns.On("PLAYER_LOGOUT", Flush)

-- Everything the atlas says about one zone.
function ns.ZoneStory(zone)
    local DB = ns.DB
    local z = DB.zoneStats[zone] or {}
    local gank = DB.gankZones[zone]
    local time = z.time or 0
    if here == zone and since then time = time + (GetTime() - since) end
    return {
        quests = z.quests or 0, kills = z.kills or 0, time = time,
        deaths = DB.deathZones[zone] or 0, ganks = gank and gank.kills or 0,
    }
end

-- The zone with the most of something, for the atlas tiles.
function ns.TopZone(field)
    local best, most = nil, 0
    for zone in pairs(ns.DB.zones) do
        local n = ns.ZoneStory(zone)[field]
        if n > most then best, most = zone, n end
    end
    return best, most
end

-- Continents the game can list zones for. Classic Era's two, then WoW Forever's.
local KNOWN_CONTINENTS = { 1414, 1415, 12, 13, 101, 113, 424, 572, 619, 875, 876, 905, 1550, 1978, 2274 }

-- Every zone on each continent, by continent name. Asked once per session.
local continentZones
function ns.ContinentZones()
    if continentZones then return continentZones end
    if not (C_Map and C_Map.GetMapInfo and C_Map.GetMapChildrenInfo) then return {} end
    continentZones = {}
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
    local continentType = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
    local ids, seen = {}, {}
    for id in pairs(ns.DB.continents) do ids[#ids + 1] = id end
    for _, id in ipairs(KNOWN_CONTINENTS) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do
        local info = not seen[id] and C_Map.GetMapInfo(id)
        seen[id] = true
        if info and info.mapType == continentType and not continentZones[info.name] then
            local names, set = {}, {}
            for _, child in ipairs(C_Map.GetMapChildrenInfo(id, zoneType, false) or {}) do
                if child.name and not set[child.name] then
                    set[child.name] = true
                    names[#names + 1] = child.name
                end
            end
            if #names > 0 then
                table.sort(names)
                continentZones[info.name] = names
            end
        end
    end
    -- The map may not be ready this early; ask again next time.
    local zones = continentZones
    if not next(zones) then continentZones = nil end
    return zones
end

-- How much of one continent you've explored: zones found, zones on the map.
function ns.ContinentProgress(name)
    local zones = ns.ContinentZones()[name]
    if not zones then return 0, 0 end
    local found = 0
    for _, zone in ipairs(zones) do if ns.DB.zones[zone] then found = found + 1 end end
    return found, #zones
end
