-- Forever Told foes: what you've slain, and what slew you.
--
-- Kills come from the "<name> dies, you gain experience" message, which both
-- clients still send, so grey enemies that give no experience don't count.
-- For deaths, Classic Era's combat log says exactly what hit us last. WoW
-- Forever closes it, so there we blame the hostile enemy that was targeting
-- us most recently. Player killers come from the grudge tracker.

local _, ns = ...
local U = ns.U
local issecret, Short = U.issecret, U.Short

local BLAME_WINDOW = 15

local ENVIRONMENT = {
    Falling = "a long fall", Drowning = "the deep water", Fatigue = "exhaustion",
    Fire = "the flames", Lava = "molten lava", Slime = "toxic slime",
}

local hits = {} -- name -> { t, exact, env }
local band = bit and bit.band

local function Foe(name)
    local DB = ns.DB
    local f = DB.foes[name]
    if not f then
        f = { kills = 0, deaths = 0, zones = {} }
        DB.foes[name] = f
    end
    return f
end

local function Hit(name, exact, env)
    local h = hits[name] or {}
    h.t, h.exact, h.env = GetTime(), exact or h.exact, env
    hits[name] = h
end

-- Whatever hit us most recently in the last few seconds; the combat log beats a guess.
function ns.RecentFoe(window)
    local now, best, bestScore = GetTime(), nil, nil
    for name, h in pairs(hits) do
        if now - h.t <= (window or BLAME_WINDOW) then
            local score = h.t + (h.exact and 1000 or 0)
            if not bestScore or score > bestScore then best, bestScore = name, score end
        end
    end
    return best, best and hits[best]
end

-- Era: the combat log names whatever hit us, monster or the ground itself.
local DAMAGE = { SWING_DAMAGE = true, SPELL_DAMAGE = true, RANGE_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true }
local function OnCombatLog()
    if not CombatLogGetCurrentEventInfo then return end
    local _, sub, _, _, srcName, srcFlags, _, dstGUID, _, _, _, envType = CombatLogGetCurrentEventInfo()
    if issecret(sub) or issecret(dstGUID) or dstGUID ~= UnitGUID("player") then return end
    if sub == "ENVIRONMENTAL_DAMAGE" then
        Hit(ENVIRONMENT[envType] or "the world itself", true, true)
    elseif DAMAGE[sub] and srcName and not issecret(srcName) then
        -- Players are the grudge tracker's business.
        local player = band and srcFlags and band(srcFlags, COMBATLOG_OBJECT_TYPE_PLAYER or 0x400) > 0
        if not player then Hit(Short(srcName), true) end
    end
end

-- Forever: which hostile enemy is targeting me right now?
local SCAN = { "target", "focus", "mouseover" }
for i = 1, 40 do SCAN[#SCAN + 1] = "nameplate" .. i end

local function OnMe(unit)
    return UnitExists(unit) and not UnitIsPlayer(unit) and UnitCanAttack("player", unit)
        and UnitIsUnit(unit .. "target", "player")
end

local function Scan()
    if not InCombatLockdown() then return end
    for _, unit in ipairs(SCAN) do
        local ok, yes = pcall(OnMe, unit)
        if ok and yes then
            local name = UnitName(unit)
            if name and not issecret(name) then Hit(name) end
        end
    end
end

-- Kills ---------------------------------------------------------------------------------

local XP_KILL
do
    local fmt = COMBATLOG_XPGAIN_FIRSTPERSON or "%s dies, you gain %d experience."
    local p = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%s", "(.-)", 1):gsub("%%s", ".-"):gsub("%%d", "%%d+")
    XP_KILL = "^" .. p
end

local TOUGH = { elite = 3, rareelite = 4, rare = 1, worldboss = 10 }

-- How hard was it? Only known if we had it targeted.
local function Toughness(name)
    if not UnitExists("target") or UnitName("target") ~= name then return nil end
    local level = UnitLevel("target")
    local class = UnitClassification and UnitClassification("target") or "normal"
    if issecret(level) or issecret(class) then return nil end
    if not level or level < 1 then level = UnitLevel("player") + 10 end
    return level + (TOUGH[class] or 0), level, class
end

function ns.FoeSlain(name)
    local DB = ns.DB
    if not name or name == "" then return end
    local zone = ns.Zone()
    local f = Foe(name)
    f.kills = f.kills + 1
    f.zones[zone] = (f.zones[zone] or 0) + 1
    local z = ns.ZoneStats(zone)
    z.kills = (z.kills or 0) + 1
    ns.Bump("kills")
    local score, level, class = Toughness(name)
    if class and class ~= "normal" and class ~= "rare" and level >= UnitLevel("player") + 3 then
        DB.counters.giants = (DB.counters.giants or 0) + 1
    end
    if score and (not DB.toughest or score > (DB.toughest.score or 0)) then
        DB.toughest = { name = name, level = level, class = class ~= "normal" and class or nil, score = score, t = time(), zone = zone }
    end
    if ns.CheckDeeds then ns.CheckDeeds() end
end

local function OnXP(msg)
    if issecret(msg) or type(msg) ~= "string" then return end
    local name = msg:match(XP_KILL)
    if name then ns.FoeSlain(name) end
end

-- Deaths --------------------------------------------------------------------------------

-- Runs after the grudge tracker, so a player killer is already known.
local function OnDeath()
    local name, h, player
    if ns.pvpDeath and ns.lastKiller then
        name, player = Short(ns.lastKiller), true
    else
        name, h = ns.RecentFoe(BLAME_WINDOW)
    end
    hits = {}
    ns.lastFoe = name
    if not name then return end
    local zone = ns.Zone()
    local f = Foe(name)
    f.deaths = f.deaths + 1
    f.diedIn = f.diedIn or {}
    f.diedIn[zone] = (f.diedIn[zone] or 0) + 1
    f.player = player or nil
    f.env = h and h.env or nil
    f.exact = (player and (ns.DB.grudges[ns.lastKiller] or {}).exact) or (h and h.exact) or nil
end

-- Lists for the Stats page ---------------------------------------------------------------

local function Sorted(field)
    local list = {}
    for name, f in pairs(ns.DB.foes) do
        if (f[field] or 0) > 0 then list[#list + 1] = { name = name, f = f, n = f[field] } end
    end
    table.sort(list, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.name < b.name
    end)
    return list
end
function ns.DeadliestFoes() return Sorted("deaths") end
function ns.SlainFoes() return Sorted("kills") end

function ns.FoeTotals()
    local kills, kinds = 0, 0
    for _, f in pairs(ns.DB.foes) do
        if (f.kills or 0) > 0 then kills, kinds = kills + f.kills, kinds + 1 end
    end
    return kills, kinds
end

-- Wiring --------------------------------------------------------------------------------

local ticker
ns.On("PLAYER_ENTERING_WORLD", function()
    if ticker then return end
    ticker = C_Timer.NewTicker(1, Scan)
end)
ns.On("PLAYER_REGEN_DISABLED", Scan)
ns.On("COMBAT_LOG_EVENT_UNFILTERED", OnCombatLog)
ns.On("CHAT_MSG_COMBAT_XP_GAIN", OnXP)
ns.On("PLAYER_DEAD", OnDeath)
