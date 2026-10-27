-- Forever Told fellowship: remembers everyone you group with, when you first
-- met, and how many dungeons and boss kills you've shared.

local _, ns = ...
local ShortName = ns.U.Short

local RUN_GAP = 30 * 60 -- re-entering the same dungeon within 30 min is the same run

local inGroup = {}      -- names in the current group
local currentRun        -- { zone, at }

local function GroupUnits()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
    end
    return units
end

local function FullName(unit)
    local name, realm = UnitName(unit)
    if not name or ns.U.issecret(name) or name == UNKNOWNOBJECT or name == "Unknown" then return nil end
    if realm and realm ~= "" then return name .. "-" .. realm end
    return name
end

local function OnRoster()
    local DB = ns.DB
    local now, seen, newFaces = time(), {}, {}
    local raid = IsInRaid()
    for _, unit in ipairs(GroupUnits()) do
        local name = FullName(unit)
        if name and not UnitIsUnit(unit, "player") then
            seen[name] = true
            local f = DB.fellows[name]
            if not f then
                local className, classFile = UnitClass(unit)
                f = { first = now, firstLvl = UnitLevel("player"), firstZone = ns.Zone(),
                      class = className, classFile = classFile, groups = 0, dungeons = 0, bosses = 0 }
                DB.fellows[name] = f
                newFaces[#newFaces + 1] = name
                ns.Bump("fellows")
            end
            if not inGroup[name] then
                f.groups = f.groups + 1
                f.last = now
            end
        end
    end
    inGroup = seen

    -- In a party, each new friend gets a line. In a raid, one line for everyone.
    if #newFaces > 0 then
        if raid and #newFaces > 3 then
            ns.Add("fellow", ("Joined a raid with %d new faces."):format(#newFaces))
        else
            for _, name in ipairs(newFaces) do
                local f = DB.fellows[name]
                ns.Add("fellow", ("Met %s the %s in %s."):format(ShortName(name), f.class or "adventurer", ns.Zone()))
            end
        end
    end
end

-- Each fresh visit to a dungeon counts as a run shared with the group.
local function OnZone()
    local inInstance, kind = IsInInstance()
    if not inInstance or (kind ~= "party" and kind ~= "raid") then return end
    local zone, now = ns.Zone(), time()
    if currentRun and currentRun.zone == zone and now - currentRun.at < RUN_GAP then
        currentRun.at = now
        return
    end
    currentRun = { zone = zone, at = now }
    local DB = ns.DB
    DB.counters.runs = (DB.counters.runs or 0) + 1
    DB.counters.runZones = DB.counters.runZones or {}
    DB.counters.runZones[zone] = (DB.counters.runZones[zone] or 0) + 1
    ns.Bump("runs")
    for name in pairs(inGroup) do
        local f = DB.fellows[name]
        if f then f.dungeons = f.dungeons + 1 end
    end
end

function ns.OnBossKill()
    for name in pairs(inGroup) do
        local f = ns.DB.fellows[name]
        if f then f.bosses = f.bosses + 1 end
    end
end

ns.On("GROUP_ROSTER_UPDATE", OnRoster)
ns.On("PLAYER_ENTERING_WORLD", function()
    OnRoster()
    OnZone()
end)
ns.On("ZONE_CHANGED_NEW_AREA", OnZone)

-- A friendship score: dungeons and bosses together count most.
function ns.FellowScore(f) return f.groups + f.dungeons * 3 + f.bosses end

function ns.SortedFellows()
    local list = {}
    for name, f in pairs(ns.DB.fellows) do list[#list + 1] = { name = name, f = f } end
    table.sort(list, function(a, b)
        local sa, sb = ns.FellowScore(a.f), ns.FellowScore(b.f)
        if sa ~= sb then return sa > sb end
        return a.f.first < b.f.first
    end)
    return list
end
