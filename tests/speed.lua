-- Speed test: a long journal (5,000 entries), a busy guild (300 chronicle entries,
-- 200 bounties from 20 guildies) and a big grudge list. Fails when a page redraw,
-- a login burst of guild messages or the bug report takes longer than its limit.
-- From the repository root:  luajit tests/speed.lua   (or lua5.1 tests/speed.lua)
-- The limits are several times what these take on a GitHub runner, so only a real
-- slowdown (something that would make the game hitch) fails the run.

local ROOT = (arg and arg[0] or "tests/speed.lua"):match("^(.-)tests[/\\]speed%.lua$") or ""
dofile(ROOT .. "tests/stubs.lua")
unpack = unpack or table.unpack
print = function() end -- keep the addon's chat lines out of the results
local out = io.write

local LIMITS = { -- ms per run, on Lua 5.1 (the game's Lua); several times what a GitHub runner takes
    ["journal page (5,000 entries)"] = 60,
    ["stats page"] = 10,
    ["grudges page (300 grudges)"] = 25,
    ["chronicle page (300 entries)"] = 15,
    ["atlas page (200 zones)"] = 20,
    ["new journal entry (with deed check)"] = 2,
    ["login burst: 200 chronicle messages"] = 30,
    ["login burst: 200 bounty posts"] = 15,
    ["bug report"] = 35,
}

local clock = os.clock
local function Time(runs, fn)
    fn() -- warm up
    local start = clock()
    for _ = 1, runs do fn() end
    return (clock() - start) * 1000 / runs
end

-- A long-played character ------------------------------------------------------------------

local now = os.time()
local entries, zones, grudges = {}, {}, {}
local KINDS = { "zone", "level", "quest", "loot", "boss", "death", "deed", "note" }
for i = 1, 5000 do
    entries[i] = { t = now - (5000 - i) * 600, lvl = 1 + math.floor(i / 85), zone = "Zone " .. (i % 200),
        kind = KINDS[i % #KINDS + 1], text = ("Something memorable happened, number %d, in Zone %d."):format(i, i % 200) }
end
for i = 1, 200 do zones["Zone " .. i] = { t = now - i * 3600, lvl = 1 + i % 60, instance = i % 10 == 0 or nil } end
for i = 1, 300 do
    grudges["Ganker" .. i] = { kills = 1 + i % 5, revenge = i % 3, t = now - i * 900, last = now - i * 600,
        zone = "Zone " .. (i % 200), classFile = "ROGUE", class = "Rogue", level = 20 + i % 40 }
end
ForeverToldDB = { entries = entries, zones = zones, grudges = grudges }

local ns = {}
for raw in io.lines(ROOT .. "ForeverTold.toc") do
    local line = raw:gsub("\r", "")
    if line ~= "" and not line:match("^#") then
        local f = assert(io.open(ROOT .. line:gsub("\\", "/"), "rb"))
        local chunk = assert((loadstring or load)(f:read("*a"), "@" .. line))
        f:close()
        chunk("ForeverTold", ns)
    end
end
local function FIRE(event, ...)
    for _, f in ipairs(FRAMES) do
        local h = f.scripts and f.scripts.OnEvent
        if h then h(f, event, ...) end
    end
end
FIRE("ADDON_LOADED", "ForeverTold")
FIRE("PLAYER_ENTERING_WORLD", true, false)

-- Runs ----------------------------------------------------------------------------------------

local results = {}
local function Measure(name, runs, fn) results[#results + 1] = { name = name, ms = Time(runs, fn) } end
local function Items(id) return function() ns.Pages[id].items() end end

Measure("journal page (5,000 entries)", 10, Items("journal"))
Measure("stats page", 10, Items("stats"))
Measure("grudges page (300 grudges)", 10, Items("grudges"))
Measure("atlas page (200 zones)", 10, Items("atlas"))
Measure("new journal entry (with deed check)", 200, function() ns.Add("note", "a note") end)

local function Chronicle(base)
    return function()
        for i = 1, 200 do
            local who = "Guildie" .. (i % 20) .. "-Realm"
            FIRE("CHAT_MSG_ADDON", "FTold1", ("M~%s~%d~level~MAGE~%d~%d~Zone %d~"):format(who, now - (base + i) * 60, 10 + i % 50, 10 + i % 50, i % 200),
                "GUILD", who)
        end
    end
end
local round = 0
Measure("login burst: 200 chronicle messages", 3, function() round = round + 1 Chronicle(round * 1000)() end)
Measure("login burst: 200 bounty posts", 5, function()
    for i = 1, 200 do
        local who = "Guildie" .. (i % 20) .. "-Realm"
        FIRE("CHAT_MSG_ADDON", "FTold1", ("P~Wanted%d~2~0~ROGUE~Rogue~40~Zone %d~10"):format(i, i % 200), "GUILD", who)
    end
end)
Measure("chronicle page (300 entries)", 10, Items("chronicle"))
Measure("bug report", 5, function() ns.Diag.Report() end)

local failed = 0
for _, r in ipairs(results) do
    local limit = LIMITS[r.name]
    local ok = r.ms <= limit
    if not ok then failed = failed + 1 end
    out(("%-4s %-40s %8.2f ms  (limit %d)\n"):format(ok and "ok" or "SLOW", r.name, r.ms, limit))
end
out(failed == 0 and "all within limits\n" or (failed .. " over the limit\n"))
if failed > 0 then os.exit(1) end
