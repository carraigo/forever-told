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
