-- Atlas page: favourite places, how much of each continent you've explored,
-- a story for every zone, then dungeons and bosses.

local _, ns = ...
local U, K = ns.U, ns.PageKit
local Count, Plural, Hex, Duration = U.Count, U.Plural, U.Hex, U.Duration
local RED, Empty = K.RED, K.Empty

local DUNGEONS = "Dungeons and raids"
local VISITED, DUNGEON, BOSS = Hex("8fd18f"), Hex("7fb2ff"), Hex("ff9a62")
local UNSEEN = { 1, 1, 1, 0.3 }

-- Continents the game can list zones for. Classic Era's two, then WoW Forever's.
local KNOWN_CONTINENTS = { 1414, 1415, 12, 13, 101, 113, 424, 572, 619, 875, 876, 905, 1550, 1978, 2274 }

-- Every zone on each continent, by continent name. Asked once per session.
local continentZones
local function ContinentZones()
    if continentZones then return continentZones end
    continentZones = {}
    if not (C_Map and C_Map.GetMapInfo and C_Map.GetMapChildrenInfo) then return continentZones end
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
    return continentZones
end

-- The zone's story, for its hover card.
local function StoryLines(zone, info)
    local s = ns.ZoneStory(zone)
    local lines = {}
    if info.lvl and (info.t or 0) > 0 then
        lines[#lines + 1] = ("Arrived at level %d on %s"):format(info.lvl, date("%d %B %Y", info.t))
    elseif (info.t or 0) > 0 then
        lines[#lines + 1] = "First visited on " .. date("%d %B %Y", info.t)
    end
    if s.time >= 60 then lines[#lines + 1] = "Time spent here: " .. Duration(s.time) end
    lines[#lines + 1] = ("%s · %s slain"):format(Plural(s.quests, "quest"), Plural(s.kills, "foe"))
    if s.deaths > 0 or s.ganks > 0 then
        lines[#lines + 1] = ("|cffeb5c4d%s%s|r"):format(Plural(s.deaths, "death"), s.ganks > 0 and (" · ganked " .. Plural(s.ganks, "time")) or "")
    end
    return lines
end

local function ZoneRow(zone, info, dot)
    local gank = ns.DB.gankZones[zone]
    local danger = gank and gank.kills > 0 and ("|cffeb5c4dganked %d×|r · "):format(gank.kills) or ""
    return { text = zone, dot = dot,
        right = danger .. (info.lvl and ("Lv %d · "):format(info.lvl) or "") .. ((info.t or 0) > 0 and date("%d %b", info.t) or ""),
        tip = { title = zone, lines = StoryLines(zone, info) } }
end

local function Favourites()
    local most, spent = ns.TopZone("time")
    local quests, q = ns.TopZone("quests")
    local deadly, d = ns.TopZone("deaths")
    return { type = "tiles", tiles = {
        { label = "Places discovered", value = tostring(Count(ns.DB.zones)) },
        { label = most and ("Favourite · " .. Duration(spent)) or "Favourite place", value = most or "–" },
        { label = quests and ("Most quests · " .. q) or "Most quests", value = quests or "–" },
        { label = deadly and ("Deadliest · " .. Plural(d, "death")) or "Deadliest zone", value = deadly or "–", colour = deadly and RED or nil },
    } }
end

ns.Pages.atlas = {
    title = "Atlas", icon = "Interface\\Icons\\INV_Misc_Map_01",
    subtitle = function() return Plural(Count(ns.DB.zones), "place") .. " discovered" end,
    badge = function() local n = Count(ns.DB.zones) return n > 0 and tostring(n) or nil end,
    items = function()
        local DB = ns.DB
        if Count(DB.zones) == 0 then return Empty("Nowhere yet. Step outside!") end
        local all = ContinentZones()
        -- Places from before continents were recorded go wherever the map puts them.
        local home = {}
        for continent, zones in pairs(all) do
            for _, name in ipairs(zones) do home[name] = home[name] or continent end
        end
        local groups, order = {}, {}
        for zone, info in pairs(DB.zones) do
            local key = info.instance and DUNGEONS or (info.continent or home[zone] or "Elsewhere")
            if not groups[key] then groups[key] = {} order[#order + 1] = key end
            table.insert(groups[key], { zone = zone, info = info })
        end
        table.sort(order, function(a, b)
            if a == DUNGEONS then return false end
            if b == DUNGEONS then return true end
            return a < b
        end)
        local items = { Favourites() }
        for _, key in ipairs(order) do
            local list = groups[key]
            table.sort(list, function(a, b) return (a.info.t or 0) < (b.info.t or 0) end)
            local zones = key ~= DUNGEONS and all[key]
            if zones then
                local found = 0
                for _, name in ipairs(zones) do if DB.zones[name] then found = found + 1 end end
                items[#items + 1] = { type = "header", text = key, right = ("%d of %d zones"):format(found, #zones) }
                items[#items + 1] = { type = "bar", label = ("%d%%"):format(math.floor(found / #zones * 100 + 0.5)), labelWidth = 40,
                    valueWidth = 10, fraction = found / #zones, colour = VISITED }
            else
                items[#items + 1] = { type = "header", text = key, right = tostring(#list) }
            end
            for _, z in ipairs(list) do
                items[#items + 1] = ZoneRow(z.zone, z.info, key == DUNGEONS and DUNGEON or VISITED)
            end
            if zones then
                local unseen = {}
                for _, name in ipairs(zones) do if not DB.zones[name] then unseen[#unseen + 1] = name end end
                if #unseen > 0 then
                    items[#items + 1] = { text = "Still to explore", colour = UNSEEN, dot = UNSEEN,
                        sub = "|cff6b6b6b" .. table.concat(unseen, ", ") .. "|r", right = tostring(#unseen) }
                end
            end
            items[#items + 1] = { type = "gap", size = 8 }
        end
        if Count(DB.bosses) > 0 then
            local bosses = {}
            for _, b in pairs(DB.bosses) do bosses[#bosses + 1] = b end
            table.sort(bosses, function(a, b) return (a.t or 0) < (b.t or 0) end)
            items[#items + 1] = { type = "header", text = "Bosses defeated", right = tostring(#bosses) }
            for _, b in ipairs(bosses) do
                items[#items + 1] = { text = b.name or "?", colour = BOSS, dot = BOSS,
                    right = ("%s · %s"):format(b.zone or "", date("%d %b", b.t or 0)) }
            end
        end
        return items
    end,
}
