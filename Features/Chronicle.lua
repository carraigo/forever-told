-- Forever Told guild chronicle: guildies running Forever Told share their big
-- moments, and everyone sees one feed. Every 10th level, epic loot, the first
-- run of each dungeon, deeds, and Hardcore deaths with their epitaph.
--
-- Message (same guild channel as the bounty board), fields split by "~":
--   M~who~t~kind~classFile~level~a~b~c
--     level    a = level, b = zone, c = "played,quests,places" at 60
--     loot     a = item link, b = zone
--     dungeon  a = dungeon, b = bosses felled, c = companions (comma-separated)
--     deed     a = deed name, b = what it's for
--     epitaph  a = level, b = zone, c = what killed them
--
-- On "H~since" (a guildie logging in), everyone sends their own news since
-- then, and relays a few of the others' unless someone else got there first.

local _, ns = ...
local U = ns.U
local Short = U.Short

local KEEP = 30 * 86400
local LIMIT = 300
local REPLY_AGE = 7 * 86400
local REPLY_LIMIT = 10

local me, myClass
local heard = {} -- key -> GetTime() we last heard it on the channel

local function Key(e) return ("%s|%d|%s|%s"):format(Short(e.who), e.t, e.kind, U.Plain(tostring(e.a or ""))) end
local function Clean(v) return (tostring(v or ""):gsub("~", "-")) end

local function Prune()
    local list, now = ns.DB.chronicle, time()
    for i = #list, 1, -1 do
        if now - list[i].t > KEEP then table.remove(list, i) end
    end
    while #list > LIMIT do table.remove(list, 1) end
end

-- Store an entry once, oldest first.
local function Store(e)
    local list = ns.DB.chronicle
    local key = Key(e)
    for _, old in ipairs(list) do if Key(old) == key then return false end end
    local at = #list + 1
    while at > 1 and list[at - 1].t > e.t do at = at - 1 end
    table.insert(list, at, e)
    Prune()
    if ns.Refresh then ns.Refresh() end
    return true
end

local function Encode(e)
    local msg = table.concat({ "M", Clean(e.who), e.t, e.kind, Clean(e.classFile), e.lvl or 0, Clean(e.a), Clean(e.b), Clean(e.c) }, "~")
    if #msg > 250 and e.kind == "loot" then
        -- Long item links don't fit in one message; send the plain name instead.
        local copy = {}
        for k, v in pairs(e) do copy[k] = v end
        copy.a = U.Plain(e.a)
        return Encode(copy)
    end
    return #msg <= 255 and msg or nil
end

local function Share(e)
    if not ns.DB.shareChronicle then return end
    local msg = Encode(e)
    if msg then ns.GuildSend(msg) end
end

-- One of my own milestones: keep it, and tell the guild.
local function Mine(kind, a, b, c)
    local e = { who = me or UnitName("player"), t = time(), kind = kind, classFile = myClass, lvl = UnitLevel("player"), a = a, b = b, c = c }
    Store(e)
    ns.DB.counters.chronicled = (ns.DB.counters.chronicled or 0) + 1
    if IsInGuild() then Share(e) end
end
ns.ChronicleMine = Mine

ns.GuildHandlers.M = function(f)
    local t = tonumber(f[3])
    if not f[2] or f[2] == "" or not t or not f[4] then return end
    local now = time()
    if now - t > KEEP or t - now > 86400 then return end
    local e = { who = f[2], t = t, kind = f[4], classFile = f[5] ~= "" and f[5] or nil, lvl = tonumber(f[6]),
        a = f[7], b = f[8] ~= "" and f[8] or nil, c = f[9] ~= "" and f[9] or nil }
    heard[Key(e)] = GetTime()
    Store(e)
end

-- The newest thing I know about, so guildies only send what I missed.
function ns.ChronicleSince()
    local list = ns.DB.chronicle
    return list[#list] and list[#list].t or 0
end

ns.GuildHandlers.H = function(f)
    if not ns.DB.shareChronicle then return end
    local since = math.max(tonumber(f[2]) or 0, time() - REPLY_AGE)
    local mine, others = {}, {}
    local list = ns.DB.chronicle
    for i = #list, 1, -1 do
        local e = list[i]
        if e.t <= since then break end
        local own = Short(e.who) == Short(me or "")
        local bucket = own and mine or others
        if #bucket < REPLY_LIMIT then bucket[#bucket + 1] = e end
    end
    for i, e in ipairs(mine) do
        C_Timer.After(2 + i * 0.5, function() Share(e) end)
    end
    -- Relays wait a random while, and skip anything someone else already sent.
    local asked = GetTime()
    for i, e in ipairs(others) do
        C_Timer.After(4 + math.random() * 8 + i * 0.5, function()
            local key = Key(e)
            if heard[key] and heard[key] >= asked then return end
            heard[key] = GetTime()
            Share(e)
        end)
    end
end

-- What gets shared ------------------------------------------------------------------

local run -- the dungeon we're in: { zone, bosses, with }

local function Group()
    local names = {}
    for i = 1, 4 do
        local name = UnitName("party" .. i)
        if name and not U.issecret(name) and name ~= UnitName("player") then names[#names + 1] = name end
    end
    return names
end

ns.Listen("level", function(level)
    if level % 10 ~= 0 then return end
    local c
    if level == 60 then
        local DB = ns.DB
        c = ("%d,%d,%d"):format(ns.PlayedNow() or DB.lastPlayed or 0, DB.quests, U.Count(DB.zones))
    end
    Mine("level", level, ns.Zone(), c)
end)

ns.Listen("loot", function(link, quality)
    if quality >= 4 then Mine("loot", link, ns.Zone()) end
end)

ns.Listen("boss", function()
    if not IsInInstance() then return end
    local zone = ns.Zone()
    if not run or run.zone ~= zone then run = { zone = zone, bosses = 0, with = {} } end
    run.bosses = run.bosses + 1
    for _, name in ipairs(Group()) do run.with[name] = true end
end)

ns.Listen("deed", function(name, what) Mine("deed", name, what) end)

ns.Listen("epitaph", function(e) Mine("epitaph", e.lvl, e.zone, e.cause) end)

-- A first dungeon run is told once we walk out.
local function CheckRun()
    if not run or (IsInInstance() and ns.Zone() == run.zone) then return end
    local done = run
    run = nil
    if done.bosses == 0 or ns.DB.chronicled[done.zone] then return end
    ns.DB.chronicled[done.zone] = true
    local with = {}
    for name in pairs(done.with) do with[#with + 1] = name end
    table.sort(with)
    Mine("dungeon", done.zone, done.bosses, table.concat(with, ","))
end

ns.On("PLAYER_ENTERING_WORLD", function()
    local name, realm = UnitName("player")
    me = (realm and realm ~= "") and (name .. "-" .. realm) or name
    myClass = select(2, UnitClass("player"))
    Prune()
    CheckRun()
end)
ns.On("ZONE_CHANGED_NEW_AREA", CheckRun)
