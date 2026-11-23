-- What's new, and newer versions in the guild.
--
-- The first time a new version loads, one line in chat says so; /told new lists
-- the highlights (and the previous version's, if you skipped one). Keep NOTES up
-- to date with each release, newest first: a test checks the current version has
-- an entry.
--
-- Guildies running Forever Told send their version with their hello (1.3.0 on).
-- If one has a newer release than yours, you're told once per session.

local _, ns = ...
local Print = ns.Print

ns.NOTES = {
    { version = "1.3.0", lines = {
        "/told bug opens a bug report you can copy, with your version, memory use and the error log.",
        "/told perf times what Forever Told does, /told selftest checks it works on your client.",
        "Calls the game blocks are written to the error log too, and old errors clear themselves after two weeks.",
        "Smoother with the window open: a burst of guild news redraws the page once, not once per message.",
        "Guild messages the game holds back are sent again a moment later instead of being lost.",
        "You're told once when a guildie has a newer Forever Told, and the game's Options has a Forever Told page.",
    } },
    { version = "1.2.0", lines = {
        "Forever Told keeps its own error log: /told errors.",
        "Dungeon runs from before 1.1.5 move to the right dungeon.",
        "Fastest and slowest level count from level 10.",
    } },
}

-- "1.10.0" is newer than "1.9.2". Anything that isn't a version is never newer.
function ns.NewerVersion(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    local x, y = {}, {}
    for n in a:gmatch("%d+") do x[#x + 1] = tonumber(n) end
    for n in b:gmatch("%d+") do y[#y + 1] = tonumber(n) end
    if #x == 0 or #y == 0 then return false end
    for i = 1, math.max(#x, #y) do
        local p, q = x[i] or 0, y[i] or 0
        if p ~= q then return p > q end
    end
    return false
end

-- The notes for this version, and for the one before it if that was skipped too.
function ns.NewsSince(seen)
    local out, current = {}, ns.Version()
    for _, n in ipairs(ns.NOTES) do
        if not ns.NewerVersion(n.version, current) and (not seen or ns.NewerVersion(n.version, seen)) then
            out[#out + 1] = n
        end
        if #out == 2 then break end
    end
    return out
end

local function ShowNews(list)
    for _, n in ipairs(list) do
        Print("What's new in " .. n.version .. ":")
        for _, line in ipairs(n.lines) do print("  - " .. line) end
    end
end

ns.Commands.new = function() ShowNews(ns.NewsSince(nil)) end
ns.Commands.news = ns.Commands.new

ns.On("PLAYER_LOGIN", function()
    ForeverToldAccountDB = ForeverToldAccountDB or {}
    local ADB, current = ForeverToldAccountDB, ns.Version()
    local seen = ADB.seenVersion
    if seen ~= current then
        -- A first install has nothing to compare with: no news, just remember the version.
        if seen and #ns.NewsSince(seen) > 0 then
            Print(("updated to %s. Type /told new to see what's changed."):format(current))
        end
        ADB.seenVersion = current
    end
end)

local told
function ns.VersionSeen(version, sender)
    if told or not ns.NewerVersion(version, ns.Version()) then return end
    -- Test builds (with a dash, like 1.4.0-beta1) only count if you're on one too.
    if version:find("-", 1, true) and not ns.Version():find("-", 1, true) then return end
    told = true
    Print(("%s has Forever Told %s (you have %s). Get it from CurseForge or GitHub."):format(
        ns.U.Short(sender or "A guildie"), version, ns.Version()))
end
