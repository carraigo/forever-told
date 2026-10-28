-- Forever Told bounty board: your open grudges are shared with guildies who
-- also run Forever Told. When one of them kills a player on the board, the
-- people who posted that bounty are avenged and the hunter collects it.
--
-- Messages (addon channel, GUILD only), fields split by "~":
--   P~name~kills~ours~classFile~class~level~zone~reward   post or update my bounty
--   W~name                                         withdraw my bounty (settled)
--   C~name                                         I killed this player
--   $~name~gold~hunter                             I paid the hunter the reward I promised
--   S~name~where                                   I just saw this wanted player here
--
--   H                                              hello: please send me your bounties

local _, ns = ...
local U = ns.U
local issecret, Short = U.issecret, U.Short

local PREFIX = "FTold1"
local EXPIRE = 21 * 86400       -- forget bounties nobody has updated for three weeks
local CLAIM_COOLDOWN = 60
local SYNC_LIMIT = 15

local SIGHT_COOLDOWN = 120      -- report the same player at most every two minutes
local SPOTTED_TOAST = 600       -- and tell me about my own nemesis at most every ten

local me
local claimed, sighted, spottedToast = {}, {}, {}

-- Sending ------------------------------------------------------------------------------

local function Send(msg)
    if not IsInGuild() then return end
    local send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
    if send then pcall(send, PREFIX, msg, "GUILD") end
end

-- The gold I've promised on my own wanted poster for this player.
function ns.MyReward(name)
    local poster = ns.DB.posters[name]
    return poster and not poster.done and poster.reward or 0
end

local function PostMessage(name, g)
    local ours, theirs = ns.GrudgeScore(g)
    return table.concat({ "P", name, theirs, ours, g.classFile or "", g.class or "", g.level or 0, g.zone or "", ns.MyReward(name) }, "~")
end

function ns.PostBounty(name)
    local DB = ns.DB
    local g = DB.grudges[name]
    if not g then return end
    if not ns.GrudgeOpen(g) and DB.posters[name] then DB.posters[name].done = true end
    if not DB.shareBounties then return end
    if ns.GrudgeOpen(g) then
        Send(PostMessage(name, g))
    else
        -- Settled: the poster comes down and any promised reward lapses.
        if DB.posters[name] then DB.posters[name].done = true end
        Send("W~" .. name)
    end
end

-- Send all my open bounties, spaced out so we never flood the channel.
local function SendAll()
    local DB = ns.DB
    if not DB.shareBounties then return end
    local n = 0
    for name, g in pairs(DB.grudges) do
        if ns.GrudgeOpen(g) and n < SYNC_LIMIT then
            n = n + 1
            local msg = PostMessage(name, g)
            C_Timer.After(n * 0.4, function() Send(msg) end)
        end
    end
end

-- The board ---------------------------------------------------------------------------

function ns.FindBounty(name)
    local B = ns.DB.bounties
    if B[name] then return B[name], name end
    for full, b in pairs(B) do if Short(full) == name then return b, full end end
end

function ns.BountyReward(b)
    local gold = 0
    for _, p in pairs(b.posters) do gold = gold + (p.reward or 0) end
    return gold
end

function ns.BountyPosters(b)
    local names = {}
    for poster in pairs(b.posters) do names[#names + 1] = Short(poster) end
    table.sort(names)
    return table.concat(names, ", ")
end

-- Everything that's wanted: guildies' bounties plus my own open grudges.
function ns.BountyBoard()
    local DB, list, index = ns.DB, {}, {}
    local function Row(name)
        if not index[name] then
            index[name] = { name = name, posters = {}, kills = 0 }
            list[#list + 1] = index[name]
        end
        return index[name]
    end
    for name, b in pairs(DB.bounties) do
        local r = Row(name)
        for poster, p in pairs(b.posters) do
            r.posters[poster] = p
            r.kills = r.kills + (p.kills - p.ours)
        end
        r.classFile, r.class, r.level, r.zone, r.t, r.claim, r.seen = b.classFile, b.class, b.level, b.zone, b.t, b.claim, b.seen
    end
    for name, g in pairs(DB.grudges) do
        if ns.GrudgeOpen(g) then
            local ours, theirs = ns.GrudgeScore(g)
            local r = Row(name)
            r.posters[me or "you"] = { kills = theirs, ours = ours, mine = true, reward = ns.MyReward(name) }
            r.kills = r.kills + (theirs - ours)
            r.mine = true
            r.classFile, r.class = r.classFile or g.classFile, r.class or g.class
            r.level, r.zone = r.level or g.level, r.zone or g.zone
            r.t = math.max(r.t or 0, g.last or 0)
            if g.seen and (not r.seen or g.seen.t > r.seen.t) then r.seen = g.seen end
        end
    end
    for _, r in ipairs(list) do r.reward = ns.BountyReward(r) end
    table.sort(list, function(a, b)
        if a.reward ~= b.reward then return a.reward > b.reward end
        if a.kills ~= b.kills then return a.kills > b.kills end
        return (a.t or 0) > (b.t or 0)
    end)
    return list
end

-- Claiming ----------------------------------------------------------------------------

function ns.ClaimBounty(name)
    local b, key = ns.FindBounty(name)
    if not b then return end
    if claimed[key] and GetTime() - claimed[key] < CLAIM_COOLDOWN then return end
    claimed[key] = GetTime()
    Send("C~" .. key)
    local DB = ns.DB
    DB.counters.bounties = (DB.counters.bounties or 0) + 1
    ns.Bump("bounties")
    b.claim = { by = me, t = time() }
    local who, gold = ns.BountyPosters(b), ns.BountyReward(b)
    if gold > 0 then
        ns.Add("revenge", ("Collected the wanted poster on %s for %s. %d gold reward."):format(Short(key), who, gold))
        ns.ShowToast("Bounty collected", Short(key) .. " is down", ("%s owe%s you %d gold"):format(who, U.Count(b.posters) > 1 and "" or "s", gold))
    else
        ns.Add("revenge", ("Collected the guild bounty on %s for %s."):format(Short(key), who))
        ns.ShowToast("Bounty collected", Short(key) .. " is down", "Wanted by " .. who)
    end
    ns.CheckDeeds()
end

-- Receiving ---------------------------------------------------------------------------

local function Split(msg)
    local t = {}
    for field in (msg .. "~"):gmatch("(.-)~") do t[#t + 1] = field end
    return t
end

local OnPaid -- defined below, with ns.MarkPaid

-- Witness reports ---------------------------------------------------------------------

local function Where()
    local zone, sub = ns.Zone(), GetSubZoneText and GetSubZoneText() or ""
    if sub ~= "" and sub ~= zone then return sub .. ", " .. zone end
    return zone
end

-- Store a sighting on my grudge and on the board, whoever made it.
function ns.OnSighting(name, where, by)
    local DB = ns.DB
    local seen = { where = where, by = by, t = time() }
    local key = ns.FindGrudge(name)
    local g = key and DB.grudges[key]
    if g then g.seen = seen end
    local b = ns.FindBounty(name)
    if b then b.seen = seen end
    if by and by ~= me and g and ns.GrudgeOpen(g) and DB.grudgeAlerts then
        if not spottedToast[key] or GetTime() - spottedToast[key] > SPOTTED_TOAST then
            spottedToast[key] = GetTime()
            ns.ShowToast("Spotted", Short(key), ("%s · seen by %s"):format(where, Short(by)))
        end
    end
    if ns.Refresh then ns.Refresh() end
end

function ns.ReportSighting(name)
    local key = ns.FindGrudge(name) or select(2, ns.FindBounty(name)) or name
    if sighted[key] and GetTime() - sighted[key] < SIGHT_COOLDOWN then return end
    sighted[key] = GetTime()
    local where = Where()
    ns.OnSighting(key, where, me)
    if ns.DB.shareBounties then Send(("S~%s~%s"):format(key, where)) end
end

-- The freshest "last seen" for a player: a witness report or the last fight.
function ns.LastSeen(record)
    if not record then return nil end
    local seen, fight = record.seen, record.last -- only grudges have a fight time
    if seen and (not fight or seen.t >= fight) then
        return seen.where, seen.t, seen.by
    end
    return record.zone, fight or record.t
end

local function OnMessage(prefix, msg, channel, sender)
    if prefix ~= PREFIX or channel ~= "GUILD" then return end
    if issecret(msg) or issecret(sender) or type(msg) ~= "string" or not sender then return end
    if Short(sender) == Short(me or "") then return end
    local DB = ns.DB
    local f = Split(msg)
    local kind, name = f[1], f[2]
    if kind == "H" then
        C_Timer.After(1 + math.random() * 4, SendAll)
    elseif kind == "P" and name and name ~= "" then
        local b = DB.bounties[name] or { posters = {} }
        DB.bounties[name] = b
        b.posters[sender] = { kills = tonumber(f[3]) or 1, ours = tonumber(f[4]) or 0, t = time() }
        b.classFile = f[5] ~= "" and f[5] or b.classFile
        b.class = f[6] ~= "" and f[6] or b.class
        b.level = tonumber(f[7]) ~= 0 and tonumber(f[7]) or b.level
        b.zone = f[8] ~= "" and f[8] or b.zone
        b.posters[sender].reward = tonumber(f[9]) or 0
        b.t = time()
        if ns.Refresh then ns.Refresh() end
    elseif kind == "W" and name then
        local b = DB.bounties[name]
        if b then
            b.posters[sender] = nil
            if not next(b.posters) then DB.bounties[name] = nil end
            if ns.Refresh then ns.Refresh() end
        end
    elseif kind == "C" and name then
        -- A guildie got them. If they were on my list, that's my revenge too,
        -- and if I'd promised gold on a poster, I now owe them.
        local gold = ns.MyReward(name)
        if gold > 0 then
            DB.posters[name].done = true
            table.insert(DB.debts, { to = sender, gold = gold, name = name, t = time() })
            ns.Add("revenge", ("%s collected your wanted poster on %s. You promised %d gold."):format(Short(sender), Short(name), gold))
            ns.ShowToast("Pay up", ("%d gold to %s"):format(gold, Short(sender)), "For " .. Short(name) .. ". Mark it paid on the bounty board.")
        end
        ns.Avenged(name, sender)
        local b = DB.bounties[name]
        if b then b.claim = { by = sender, t = time() } end
        if ns.Refresh then ns.Refresh() end
    elseif kind == "S" and name and f[3] and f[3] ~= "" then
        ns.OnSighting(name, f[3], sender)
    elseif kind == "$" and name and f[4] and Short(f[4]) == Short(me or "") then
        OnPaid(name, tonumber(f[3]) or 0, sender)
    end
end

-- The reward was handed over (by trade or mail). Tell the hunter too.
function ns.MarkPaid(index)
    local DB = ns.DB
    local debt = table.remove(DB.debts, index)
    if not debt then return end
    Send(("$~%s~%d~%s"):format(debt.name, debt.gold, debt.to))
    ns.Add("revenge", ("Paid %s %d gold for taking down %s."):format(Short(debt.to), debt.gold, Short(debt.name)))
end

function OnPaid(name, gold, sender)
    ns.Add("revenge", ("%s paid you %d gold for %s."):format(Short(sender), gold, Short(name)))
    ns.ShowToast("Reward paid", ("%d gold"):format(gold), ("From %s, for %s"):format(Short(sender), Short(name)))
end

local function Expire()
    local DB, now = ns.DB, time()
    for name, b in pairs(DB.bounties) do
        for poster, p in pairs(b.posters) do
            if now - (p.t or 0) > EXPIRE then b.posters[poster] = nil end
        end
        if not next(b.posters) then DB.bounties[name] = nil end
    end
end

local started
ns.On("PLAYER_ENTERING_WORLD", function()
    if started then return end
    started = true
    local name, realm = UnitName("player")
    me = (realm and realm ~= "") and (name .. "-" .. realm) or name
    local register = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
    if register then pcall(register, PREFIX) end
    Expire()
    -- Guild info can take a few seconds to arrive after login.
    C_Timer.After(10, function()
        Send("H")
        SendAll()
    end)
end)
ns.On("CHAT_MSG_ADDON", OnMessage)

