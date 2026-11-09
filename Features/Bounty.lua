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
--   H~since~classFile~level                        hello: please send me your bounties (and chronicle news)
--   I~classFile~level                              reply to a hello: I run Forever Told too
--
-- Other features add their own kinds through ns.GuildHandlers and ns.GuildSend.

local _, ns = ...
local U = ns.U
local issecret, Short = U.issecret, U.Short

local PREFIX = "FTold1"
local EXPIRE = 21 * 86400       -- forget bounties nobody has updated for three weeks
local CLAIM_COOLDOWN = 60
local SYNC_LIMIT = 15

local SIGHT_COOLDOWN = 120      -- report the same player at most every two minutes
local SPOTTED_TOAST = 600       -- and tell me about my own nemesis at most every ten

local BURST, QUEUE_MAX = 8, 60  -- the game drops addon messages sent faster than about one a second
local GUILDIE_KEEP = 30 * 86400

local me
local claimed, sighted, spottedToast = {}, {}, {}

-- What /told guild reports: is the channel working, and who have we heard from.
local stats = { sent = 0, failed = 0, heard = 0 }
ns.GuildStats = stats

-- Sending ------------------------------------------------------------------------------
-- Messages go out through a small queue: a burst of a few, then one a second,
-- so a login reply with a dozen bounties and chronicle entries isn't dropped.

-- Older clients return true/false, newer ones a result code where 0 is success.
local function Succeeded(ok, result)
    return ok and (result == nil or result == true or result == 0)
end

local function RawSend(msg)
    local send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
    if not send then return end
    local ok, result = pcall(send, PREFIX, msg, "GUILD")
    if Succeeded(ok, result) then
        stats.sent = stats.sent + 1
    else
        stats.failed = stats.failed + 1
        stats.lastError = ok and tostring(result) or "error"
    end
end

local queue, tokens, lastRefill, waiting = {}, BURST, nil, false
local function Pump()
    local now = GetTime()
    if lastRefill then tokens = math.min(BURST, tokens + (now - lastRefill)) end
    lastRefill = now
    while #queue > 0 and tokens >= 1 do
        tokens = tokens - 1
        RawSend(table.remove(queue, 1))
    end
    if #queue > 0 and not waiting then
        waiting = true
        C_Timer.After(1, function()
            waiting = false
            tokens = math.max(tokens, 1)
            Pump()
        end)
    end
end

local function Send(msg)
    if not IsInGuild() then return end
    if #queue >= QUEUE_MAX then return end
    queue[#queue + 1] = msg
    Pump()
end
ns.GuildSend = Send
ns.GuildHandlers = {}

-- Guildies running Forever Told ----------------------------------------------------------

local function SawGuildie(sender, classFile, level)
    local DB = ns.DB
    DB.guildies = DB.guildies or {}
    local name = Short(sender)
    local g = DB.guildies[name] or {}
    DB.guildies[name] = g
    g.t = time()
    if classFile and classFile ~= "" then g.classFile = classFile end
    if tonumber(level) and tonumber(level) > 0 then g.level = tonumber(level) end
end

-- Guildies heard from in the last 30 days, most recent first.
function ns.Guildies()
    local list, now = {}, time()
    for name, g in pairs(ns.DB.guildies or {}) do
        if now - (g.t or 0) <= GUILDIE_KEEP then
            list[#list + 1] = { name = name, classFile = g.classFile, level = g.level, t = g.t }
        end
    end
    table.sort(list, function(a, b) return a.t > b.t end)
    return list
end

local function Hello()
    local _, classFile = UnitClass("player")
    stats.helloAt = time()
    Send(("H~%d~%s~%d"):format(ns.ChronicleSince and ns.ChronicleSince() or 0, classFile or "", UnitLevel("player") or 0))
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

-- Take my poster down from the guild's boards.
function ns.WithdrawBounty(name)
    if not IsInGuild() then return end
    Send("W~" .. name)
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
    if issecret(msg) or issecret(sender) or type(msg) ~= "string" or type(sender) ~= "string" then return end
    -- WoW Forever sends "Name Surname"; we call ourselves "Name-Surname". Character
    -- names have no spaces, so make them one shape, or our own echo looks like a guildie.
    sender = sender:gsub(" ", "-")
    if Short(sender) == Short(me or "") then return end
    local DB = ns.DB
    local f = Split(msg)
    local kind, name = f[1], f[2]
    stats.heard = stats.heard + 1
    stats.lastSender = sender
    if kind == "H" then SawGuildie(sender, f[3], f[4])
    elseif kind == "I" then SawGuildie(sender, f[2], f[3])
    else SawGuildie(sender) end
    if ns.GuildHandlers[kind] then ns.GuildHandlers[kind](f, sender) end
    if kind == "H" then
        C_Timer.After(1 + math.random() * 4, function()
            local _, classFile = UnitClass("player")
            Send(("I~%s~%d"):format(classFile or "", UnitLevel("player") or 0))
            SendAll()
        end)
        if ns.Refresh then ns.Refresh() end
    elseif kind == "I" then
        if ns.Refresh then ns.Refresh() end
    elseif kind == "P" and name and name ~= "" then
        local b = DB.bounties[name] or { posters = {}, since = time() }
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
    for name, g in pairs(DB.guildies or {}) do
        if now - (g.t or 0) > GUILDIE_KEEP then DB.guildies[name] = nil end
    end
end

-- 1.1.4 and older kept WoW Forever's "Name Surname" senders as they came: our own
-- echo turned up as a guildie, and guildies could be listed twice. Put them right.
local function TidyNames()
    local DB = ns.DB
    local function Refile(t, rename)
        local spaced = {}
        for key, v in pairs(t) do
            if key:find(" ", 1, true) then spaced[key] = v end
        end
        for key, v in pairs(spaced) do
            t[key] = nil
            local new = rename((key:gsub(" ", "-")))
            local kept = t[new]
            if not kept or (kept.t or 0) < (v.t or 0) then t[new] = v end
        end
    end
    DB.guildies = DB.guildies or {}
    Refile(DB.guildies, Short)
    DB.guildies[Short(me)] = nil
    for name, b in pairs(DB.bounties) do
        if b.posters then
            Refile(b.posters, function(n) return n end)
            -- Our own posters came back as an echo too; ours live with the grudges.
            for poster in pairs(b.posters) do
                if Short(poster) == Short(me) then b.posters[poster] = nil end
            end
            if not next(b.posters) then DB.bounties[name] = nil end
        end
    end
end
ns.TidyNames = TidyNames

local started
ns.On("PLAYER_ENTERING_WORLD", function()
    if started then return end
    started = true
    local name, realm = UnitName("player")
    me = (realm and realm ~= "") and (name .. "-" .. realm) or name
    TidyNames()
    local register = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
    if register then
        local ok, result = pcall(register, PREFIX)
        -- 1 is "already registered", which is fine too.
        stats.registered = Succeeded(ok, result) or result == 1
        stats.registerResult = ok and tostring(result) or "error"
    end
    Expire()
    -- Guild info can take a while to arrive after login: try again if we
    -- don't look guilded yet, rather than staying silent all session.
    local function Greet(tries)
        if IsInGuild() then
            if ns.ForgiveGuildies then ns.ForgiveGuildies() end
            Hello()
            SendAll()
        elseif tries > 0 then
            C_Timer.After(20, function() Greet(tries - 1) end)
        end
    end
    C_Timer.After(10, function() Greet(3) end)
end)
ns.On("CHAT_MSG_ADDON", OnMessage)

-- /told guild: say hello again and show whether the guild channel is working.
function ns.GuildReport()
    local Print = ns.Print
    if not IsInGuild() then
        Print("You're not in a guild (or the game hasn't told us yet), so nothing is shared.")
        return
    end
    Hello()
    Print(("Guild channel: %s. Sent %d message%s, %d failed%s. Heard %d from guildies%s."):format(
        stats.registered == false and ("|cffff6b5bnot registered (" .. tostring(stats.registerResult) .. ")|r") or "open",
        stats.sent, stats.sent == 1 and "" or "s", stats.failed,
        stats.lastError and (" (last code " .. stats.lastError .. ")") or "",
        stats.heard, stats.lastSender and (", last from " .. stats.lastSender) or ""))
    local names = {}
    for _, g in ipairs(ns.Guildies()) do
        names[#names + 1] = g.level and ("%s (%d)"):format(g.name, g.level) or g.name
    end
    if #names > 0 then
        Print("Guildies running Forever Told: " .. table.concat(names, ", ") .. ".")
    else
        Print("No guildies running Forever Told heard from yet. Said hello; anyone online with it will answer in a few seconds. Try /told guild again then.")
    end
end

