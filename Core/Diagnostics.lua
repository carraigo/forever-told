-- Forever Told diagnostics: what you need when something goes wrong in game.
--
--   /told bug        a copyable bug report: version, client, memory, load times,
--                    saved data sizes, the guild channel and the error log
--   /told perf       the profiler. "on" times every event and guild message
--                    handler, "off" stops (the default, and then it costs nothing),
--                    "reset" clears it, and on its own it prints the slowest.
--   /told selftest   checks the game gives Forever Told what it needs
--   /told version    the version you're running
--
-- The game reports a call it blocked (ADDON_ACTION_BLOCKED) as an event, not an
-- error, so those are caught here and written to the error log too.

local ADDON, ns = ...
local U = ns.U
local Print = ns.Print

local Diag = {}
ns.Diag = Diag

-- Profiler ------------------------------------------------------------------------------

Diag.stats = {} -- where -> { calls, total ms, max ms }

function ns.Charge(where, ms)
    local s = Diag.stats[where]
    if not s then
        s = { calls = 0, total = 0, max = 0 }
        Diag.stats[where] = s
    end
    s.calls = s.calls + 1
    s.total = s.total + ms
    if ms > s.max then s.max = ms end
end

function Diag.SetProfiling(on)
    ns.profiling = on and true or nil
    ForeverToldAccountDB = ForeverToldAccountDB or {}
    ForeverToldAccountDB.profiling = ns.profiling
end

-- The slowest handlers, by total time.
function Diag.PerfLines(limit)
    local list = {}
    for where, s in pairs(Diag.stats) do list[#list + 1] = { where = where, s = s } end
    table.sort(list, function(a, b) return a.s.total > b.s.total end)
    local out = {}
    for i = 1, math.min(limit or 10, #list) do
        local e = list[i]
        out[i] = ("%s: %d calls, %.1f ms total, %.2f ms average, %.2f ms at most"):format(
            e.where, e.s.calls, e.s.total, e.s.total / e.s.calls, e.s.max)
    end
    return out
end

ns.Commands.perf = function(rest)
    rest = (rest or ""):lower()
    if rest == "on" or rest == "off" then
        Diag.SetProfiling(rest == "on")
        Print("Profiler " .. rest .. (rest == "on" and ". /told perf shows what it has timed." or "."))
    elseif rest == "reset" then
        Diag.stats = {}
        Print("Profiler reset.")
    else
        local lines = Diag.PerfLines(10)
        if #lines == 0 then
            Print(ns.profiling and "Nothing timed yet." or "The profiler is off. /told perf on to start it.")
            return
        end
        Print("Slowest handlers" .. (ns.profiling and "" or " (profiler now off)") .. ":")
        for _, line in ipairs(lines) do print("  " .. line) end
    end
end

-- Blocked calls -------------------------------------------------------------------------

local BLOCKED = { ADDON_ACTION_BLOCKED = true, ADDON_ACTION_FORBIDDEN = true }
local blocked = CreateFrame("Frame")
for event in pairs(BLOCKED) do pcall(blocked.RegisterEvent, blocked, event) end
blocked:SetScript("OnEvent", function(_, event, addon, func)
    if not BLOCKED[event] or addon ~= ADDON then return end
    ns.LogError(event, ("the game blocked %s()"):format((tostring(func):gsub("%(%)$", ""))))
end)

-- Bug report ----------------------------------------------------------------------------

function Diag.MemoryKB()
    local update = UpdateAddOnMemoryUsage
    local get = GetAddOnMemoryUsage or (C_AddOns and C_AddOns.GetAddOnMemoryUsage)
    if not get then return nil end
    if update then pcall(update) end
    local ok, kb = pcall(get, ADDON)
    return ok and type(kb) == "number" and kb or nil
end

-- A rough size of saved data, in bytes: the strings it holds plus a little per entry.
local function Size(v, seen)
    local t = type(v)
    if t == "string" then return #v + 8 end
    if t ~= "table" then return 8 end
    if seen[v] then return 0 end
    seen[v] = true
    local n = 16
    for k, x in pairs(v) do n = n + Size(k, seen) + Size(x, seen) end
    return n
end

-- The biggest parts of this character's saved data: "entries 41 KB, zones 6 KB, ..."
function Diag.SizesText()
    local list = {}
    for key, v in pairs(ns.DB or {}) do
        if type(v) == "table" then list[#list + 1] = { key = key, bytes = Size(v, {}) } end
    end
    table.sort(list, function(a, b) return a.bytes > b.bytes end)
    local out = {}
    for i = 1, math.min(6, #list) do
        out[i] = ("%s %d KB"):format(list[i].key, math.floor(list[i].bytes / 1024 + 0.5))
    end
    return table.concat(out, ", ")
end

local function Client()
    if not GetBuildInfo then return "?" end
    local version, build, _, interface = GetBuildInfo()
    return ("%s (build %s, interface %s)"):format(tostring(version), tostring(build), tostring(interface))
end

function Diag.Report()
    local DB, lines = ns.DB or {}, {}
    local function add(s) lines[#lines + 1] = s end
    local kb = Diag.MemoryKB()
    add("Forever Told " .. ns.Version())
    add("Client: " .. Client() .. ", " .. tostring(GetLocale and GetLocale() or "?"))
    add(("Memory: %s"):format(kb and ("%d KB"):format(kb) or "unknown"))
    add(("Load: saved data %.1f ms, first world load %.1f ms"):format(ns.startup.load or 0, ns.startup.world or 0))
    add(("Journal: %s, level %s, saved data v%s"):format(U.Plural(#(DB.entries or {}), "entry", "entries"),
        tostring(UnitLevel and UnitLevel("player") or "?"), tostring(DB.version)))
    add("Saved data: " .. Diag.SizesText())
    local g = ns.GuildStats
    if g then
        add(("Guild channel: registered %s, sent %d, failed %d, waited %d, heard %d%s"):format(
            tostring(g.registered), g.sent or 0, g.failed or 0, g.throttled or 0, g.heard or 0,
            g.lastError and (", last error " .. g.lastError) or ""))
    end
    local errors = ForeverToldAccountDB and ForeverToldAccountDB.errors or {}
    add(("Errors: %d"):format(#errors))
    for _, e in ipairs(errors) do
        add(("  x%d %s v%s (%s): %s"):format(e.count, date("%d %b %H:%M", e.last), e.version or "?", e.where or "?", e.text))
    end
    local perf = Diag.PerfLines(5)
    if #perf > 0 then
        add("Profiler:")
        for _, line in ipairs(perf) do add("  " .. line) end
    end
    return table.concat(lines, "\n")
end

ns.Commands.bug = function()
    local text = Diag.Report()
    if ns.ShowCopy then
        ns.ShowCopy("Bug report", "Press Ctrl+C to copy this, then paste it into a GitHub issue or a message to the author.", text)
    else
        for line in text:gmatch("[^\n]+") do print(line) end
    end
end

ns.Commands.version = function() Print("version " .. ns.Version() .. ".") end

-- Self-test -----------------------------------------------------------------------------
-- Checks the game hands Forever Told what it needs. Each line is ok, or a warning
-- that names the feature that won't work.

local CHECKS = {
    { "C_Timer", function() return C_Timer and C_Timer.After and C_Timer.NewTicker end, "timers (everything)" },
    { "addon messages", function() return (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage end, "bounty board, guild chronicle" },
    { "time played", function() return RequestTimePlayed end, "time per level" },
    { "zone names", function() return GetRealZoneText or GetZoneText end, "places, atlas" },
    { "map", function() return C_Map and C_Map.GetBestMapForUnit end, "continents on the atlas" },
    { "quest titles", function() return C_QuestLog and (C_QuestLog.GetTitleForQuestID or C_QuestLog.GetQuestInfo) end, "quest milestones" },
    { "item quality", function() return (C_Item and C_Item.GetItemQualityByID) or GetItemInfo end, "loot" },
    { "screenshots", function() return Screenshot end, "level-up screenshots" },
}

function Diag.SelfTest()
    local results, failed = {}, 0
    for _, c in ipairs(CHECKS) do
        local ok, got = pcall(c[2])
        local pass = ok and got and true or false
        if not pass then failed = failed + 1 end
        results[#results + 1] = { name = c[1], ok = pass, needs = c[3] }
    end
    local DB = ns.DB or {}
    local saved = type(DB.entries) == "table" and type(DB.version) == "number"
    if not saved then failed = failed + 1 end
    results[#results + 1] = { name = "saved data", ok = saved, needs = "everything" }
    local pagesOk = true
    for id in pairs(ns.Pages or {}) do
        local def = ns.Pages[id]
        if def.items then
            local ok = pcall(def.items, {})
            if not ok then pagesOk = false end
        end
    end
    if not pagesOk then failed = failed + 1 end
    results[#results + 1] = { name = "pages", ok = pagesOk, needs = "the window" }
    return results, failed
end

ns.Commands.selftest = function()
    local results, failed = Diag.SelfTest()
    for _, r in ipairs(results) do
        print(("  %s %s%s"):format(r.ok and "|cff5fd35fok|r  " or "|cffff5555FAIL|r", r.name, r.ok and "" or (" (needed for " .. r.needs .. ")")))
    end
    Print(failed == 0 and "Self-test passed." or ("Self-test: %d problem%s. /told bug has the details."):format(failed, failed == 1 and "" or "s"))
end

-- The profiler stays on across reloads until you turn it off.
ns.On("PLAYER_LOGIN", function()
    if ForeverToldAccountDB and ForeverToldAccountDB.profiling then ns.profiling = true end
end)
