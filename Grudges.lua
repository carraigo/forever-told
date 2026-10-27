-- Forever Told grudges: players who killed you, and your revenge.
--
-- Classic Era still gives addons the combat log, so there the killer is
-- exact. WoW Forever closes it, so there we remember which hostile players
-- were targeting you in the seconds before you died and blame the most
-- recent one. Revenge comes from the honorable-kill message (both clients),
-- the combat log (Era), or seeing a grudge target die while you fight them.

local _, ns = ...
local U = ns.U
local issecret, Short = U.issecret, U.Short

local BLAME_WINDOW = 15      -- seconds before death an attacker still counts
local ALERT_COOLDOWN = 300   -- one "nemesis nearby" alert per player per 5 min
local REVENGE_COOLDOWN = 60

local attackers = {}         -- name -> { t, class, classFile, level, guild, exact }
local alerted, revenged = {}, {}
local band = bit and bit.band
local PlayerKilled, Wanted -- defined further down

local function Hostile(unit)
    return UnitExists(unit) and UnitIsPlayer(unit) and UnitCanAttack("player", unit)
end

local function UnitInfo(unit)
    local name, realm = UnitName(unit)
    if not name or issecret(name) then return nil end
    if realm and realm ~= "" then name = name .. "-" .. realm end
    local className, classFile = UnitClass(unit)
    local level = UnitLevel(unit)
    local guild = GetGuildInfo and GetGuildInfo(unit)
    return name, { class = className, classFile = classFile, level = (level and level > 0) and level or nil, guild = guild }
end

local function Remember(name, info, exact)
    local a = attackers[name] or {}
    for k, v in pairs(info or {}) do a[k] = v end
    a.t = GetTime()
    a.exact = exact or a.exact
    attackers[name] = a
end

-- Forever: who is targeting me right now?
local SCAN = { "target", "focus", "mouseover" }
for i = 1, 40 do SCAN[#SCAN + 1] = "nameplate" .. i end

local function Scan()
    if not InCombatLockdown() then return end
    for _, unit in ipairs(SCAN) do
        local ok, hostile = pcall(Hostile, unit)
        if ok and hostile then
            local okT, onMe = pcall(UnitIsUnit, unit .. "target", "player")
            if okT and onMe then
                local name, info = UnitInfo(unit)
                if name then Remember(name, info) end
            end
        end
    end
end

-- Era: the combat log names whoever actually hit us.
local DAMAGE = { SWING_DAMAGE = true, SPELL_DAMAGE = true, RANGE_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true }
local function OnCombatLog()
    if not CombatLogGetCurrentEventInfo or not band then return end
    local _, sub, _, srcGUID, srcName, srcFlags, _, dstGUID, dstName = CombatLogGetCurrentEventInfo()
    if issecret(sub) then return end
    local me = UnitGUID("player")
    if DAMAGE[sub] and dstGUID == me and srcName and srcFlags
        and band(srcFlags, COMBATLOG_OBJECT_TYPE_PLAYER or 0x400) > 0
        and band(srcFlags, COMBATLOG_OBJECT_REACTION_HOSTILE or 0x40) > 0 then
        local info = attackers[srcName] or {}
        if GetPlayerInfoByGUID then
            local className, classFile = GetPlayerInfoByGUID(srcGUID)
            info.class, info.classFile = className or info.class, classFile or info.classFile
        end
        Remember(srcName, info, true)
    elseif sub == "PARTY_KILL" and srcGUID == me and dstName then
        PlayerKilled(dstName)
    end
end

-- Your revenge plus your guild's, against their kills.
function ns.GrudgeScore(g) return g.revenge + (g.avenged or 0), g.kills end
function ns.GrudgeOpen(g)
    local ours, theirs = ns.GrudgeScore(g)
    return ours < theirs
end
function ns.ScoreText(g)
    local ours, theirs = ns.GrudgeScore(g)
    local text = ("Score: %d to %d"):format(ours, theirs)
    if (g.avenged or 0) > 0 then text = text .. (" (%d from your guild)"):format(g.avenged) end
    return text .. "."
end

-- Rivalry map: where and when the fights happen.
local function Tally(field)
    local DB, zone = ns.DB, ns.Zone()
    DB.gankZones[zone] = DB.gankZones[zone] or { kills = 0, revenge = 0 }
    DB.gankZones[zone][field] = DB.gankZones[zone][field] + 1
    if field == "kills" then
        local hour = tonumber(date("%H"))
        DB.gankHours[hour] = (DB.gankHours[hour] or 0) + 1
    end
end

local function Describe(g)
    local bits = {}
    if g.level then bits[#bits + 1] = ("level %d"):format(g.level) end
    if g.class then bits[#bits + 1] = g.class end
    local who = table.concat(bits, " ")
    if g.guild then who = who .. (" of <%s>"):format(g.guild) end
    return who
end

local function OnDeath()
    local DB = ns.DB
    local now, killer, best = GetTime(), nil, nil
    for name, a in pairs(attackers) do
        if now - a.t <= BLAME_WINDOW then
            -- An exact combat-log attacker beats a guess; otherwise the most recent.
            local score = a.t + (a.exact and 1000 or 0)
            if not best or score > best then killer, best = name, score end
        end
    end
    local a = killer and attackers[killer]
    attackers = {}
    if not killer then return end

    local g = DB.grudges[killer]
    if not g then
        g = { first = time(), kills = 0, revenge = 0 }
        DB.grudges[killer] = g
    end
    for _, k in ipairs({ "class", "classFile", "level", "guild" }) do
        if a[k] then g[k] = a[k] end
    end
    g.kills = g.kills + 1
    g.last = time()
    g.zone = ns.Zone()
    g.exact = a.exact or nil
    ns.Bump("ganks")
    Tally("kills")
    ns.pvpDeath = true
    local who = Describe(g)
    local line
    if g.kills == 1 then
        line = ("Ganked by %s%s in %s. This isn't over."):format(Short(killer), who ~= "" and (" (" .. who .. ")") or "", g.zone)
    else
        line = ("Killed by %s again in %s. That's %d times now. %s"):format(Short(killer), g.zone, g.kills, ns.ScoreText(g))
    end
    ns.Add("pvp", line)
    if ns.PostBounty then ns.PostBounty(killer) end
end

local function FindGrudge(name)
    local DB = ns.DB
    if DB.grudges[name] then return name end
    -- The honor message may leave the realm off.
    for full in pairs(DB.grudges) do if Short(full) == name then return full end end
end
ns.FindGrudge = FindGrudge

function ns.Revenge(name)
    local DB = ns.DB
    local key = FindGrudge(name)
    if not key then return end
    if revenged[key] and GetTime() - revenged[key] < REVENGE_COOLDOWN then return end
    revenged[key] = GetTime()
    local g = DB.grudges[key]
    g.revenge = g.revenge + 1
    g.lastRevenge = time()
    ns.Bump("revenge")
    Tally("revenge")
    local score = ns.ScoreText(g)
    ns.Add("revenge", ("Sweet revenge on %s! %s"):format(Short(key), score))
    if ns.ShowToast then ns.ShowToast("Revenge", Short(key), score) end
    if ns.PostBounty then ns.PostBounty(key) end
    if ns.CheckDeeds then ns.CheckDeeds() end
end

-- A guildie took them down through the bounty board.
function ns.Avenged(name, by)
    local key = FindGrudge(name)
    local g = key and ns.DB.grudges[key]
    if not g or not ns.GrudgeOpen(g) then return end
    g.avenged = (g.avenged or 0) + 1
    g.lastRevenge = time()
    local score = ns.ScoreText(g)
    ns.Add("revenge", ("%s avenged you: %s is down. %s"):format(Short(by), Short(key), score))
    if ns.ShowToast then ns.ShowToast("Avenged by " .. Short(by), Short(key), score) end
    if ns.PostBounty then ns.PostBounty(key) end
    if ns.CheckDeeds then ns.CheckDeeds() end
end

-- Every player kill goes through here: your own grudges and guild bounties.
function PlayerKilled(name)
    if not name or issecret(name) then return end
    ns.Revenge(name)
    if ns.ClaimBounty then ns.ClaimBounty(name) end
end

function Wanted(name)
    return FindGrudge(name) or (ns.FindBounty and ns.FindBounty(name))
end

-- Honorable kill message: "<name> dies, honorable kill Rank: ..."
local HONOR
if COMBATLOG_HONORGAIN then
    local p = COMBATLOG_HONORGAIN:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%s", "(.-)", 1):gsub("%%s", ".-"):gsub("%%d", "%%d+")
    HONOR = "^" .. p
end
local function OnHonor(msg)
    if not HONOR or issecret(msg) or type(msg) ~= "string" then return end
    local name = msg:match(HONOR)
    if name then PlayerKilled(name) end
end

-- Seeing a grudge target die while we're fighting them also counts.
local targetAlive = {}
local function WatchTarget()
    if not UnitExists("target") or not UnitIsPlayer("target") then return end
    local name = UnitInfo("target")
    if not name or not Wanted(name) then return end
    local dead = UnitIsDead("target")
    if dead and targetAlive[name] and InCombatLockdown() then PlayerKilled(name) end
    targetAlive[name] = not dead
end

-- Nemesis nearby -------------------------------------------------------------------

local function CheckNearby(unit)
    local DB = ns.DB
    if not unit then return end
    local ok, hostile = pcall(Hostile, unit)
    if not ok or not hostile then return end
    local name = UnitInfo(unit)
    if not name then return end
    -- Anyone wanted gets reported to the guild, alerts on or off.
    if Wanted(name) and ns.ReportSighting then ns.ReportSighting(name) end
    if not DB.grudgeAlerts then return end
    local key = FindGrudge(name)
    local g = key and DB.grudges[key]
    local bounty = not (g and ns.GrudgeOpen(g)) and ns.FindBounty and ns.FindBounty(name)
    if not g and not bounty then return end
    if alerted[name] and GetTime() - alerted[name] < ALERT_COOLDOWN then return end
    alerted[name] = GetTime()
    if bounty then
        local gold = ns.BountyReward(bounty)
        if gold > 0 then
            ns.ShowToast("Wanted man nearby", ("%s · %d gold"):format(Short(name), gold), "Posted by " .. ns.BountyPosters(bounty), true)
        else
            ns.ShowToast("Guild bounty nearby", Short(name), "Wanted by " .. ns.BountyPosters(bounty), true)
        end
    else
        local ours, theirs = ns.GrudgeScore(g)
        ns.ShowToast("Nemesis nearby", Short(name), ("Killed you %s · score %d to %d"):format(U.Plural(theirs, "time"), ours, theirs), true)
    end
    if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then pcall(PlaySound, SOUNDKIT.RAID_WARNING) end
end

-- Wiring ------------------------------------------------------------------------------

local ticker
ns.On("PLAYER_ENTERING_WORLD", function()
    if ticker then return end
    ticker = C_Timer.NewTicker(0.5, function()
        Scan()
        WatchTarget()
    end)
end)
ns.On("PLAYER_DEAD", OnDeath)
ns.On("COMBAT_LOG_EVENT_UNFILTERED", OnCombatLog)
ns.On("CHAT_MSG_COMBAT_HONOR_GAIN", OnHonor)
ns.On("NAME_PLATE_UNIT_ADDED", CheckNearby)
ns.On("PLAYER_TARGET_CHANGED", function() CheckNearby("target") end)
ns.On("UPDATE_MOUSEOVER_UNIT", function() CheckNearby("mouseover") end)

function ns.SortedGrudges()
    local list = {}
    for name, g in pairs(ns.DB.grudges) do list[#list + 1] = { name = name, g = g } end
    table.sort(list, function(a, b)
        local oa, ta = ns.GrudgeScore(a.g)
        local ob, tb = ns.GrudgeScore(b.g)
        local da, db = ta - oa, tb - ob
        if da ~= db then return da > db end
        return (a.g.last or 0) > (b.g.last or 0)
    end)
    return list
end
