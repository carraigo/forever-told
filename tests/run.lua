-- Forever Told tests. From the repository root:  lua tests/run.lua
-- Loads the addon the way the game does (files in .toc order, sharing one
-- namespace), plays fake events at it and checks what it saved and showed.

local ROOT = (arg and arg[0] or "tests/run.lua"):match("^(.-)tests[/\\]run%.lua$") or ""

dofile(ROOT .. "tests/stubs.lua")
unpack = unpack or table.unpack

-- Load -----------------------------------------------------------------------------------

NS = {}
local function LoadAddon()
    for raw in io.lines(ROOT .. "ForeverTold.toc") do
        local line = raw:gsub("\r", "")
        if line ~= "" and not line:match("^#") then
            local path = ROOT .. line:gsub("\\", "/")
            local f = assert(io.open(path, "rb"), "missing " .. path)
            local chunk = assert((loadstring or load)(f:read("*a"), "@" .. line))
            f:close()
            chunk("ForeverTold", NS)
        end
    end
end

function FIRE(event, ...)
    for _, f in ipairs(FRAMES) do
        local h = f.scripts and f.scripts.OnEvent
        if h then h(f, event, ...) end
    end
end
function TICK() for _, f in ipairs(TICKS) do f() end end

-- A tiny test runner -----------------------------------------------------------------------

local passed, failed = 0, {}
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        io.write("  ok    ", name, "\n")
    else
        failed[#failed + 1] = name
        io.write("  FAIL  ", name, "\n        ", tostring(err), "\n")
    end
end
local function eq(actual, expected, what)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(what or "value", tostring(expected), tostring(actual)), 2)
    end
end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local function kinds(kind)
    local n = 0
    for _, e in ipairs(ForeverToldDB.entries) do if e.kind == kind then n = n + 1 end end
    return n
end
local function DAY(n) return n * 86400 end

-- Saved data from an older version, to check the upgrades.
ForeverToldDB = {
    entries = {
        { t = 1, lvl = 5, kind = "note", text = "my own note" },
        { t = 2, lvl = 5, kind = "note", text = "a test-mode line", test = true },
        { t = 3, lvl = 6, kind = "pvp", text = "Ganked by Someone." },
        { t = 4, lvl = 6, kind = "note", text = "Paid Bob 5 gold for taking down Someone." },
    },
    zones = { ["Elwynn Forest"] = 100 },
    grudges = { ["Gank-Testrealm"] = { kills = 1, revenge = 0 }, Real = { kills = 1, revenge = 0, first = 1 } },
    posters = { ["Gank-Testrealm"] = { reward = 5 } },
    bounties = { Vex = { posters = { ["Hild-Realm"] = { kills = 1, ours = 0 } }, t = os.time() - 100 } },
    debts = { { name = "Gank-Testrealm", to = "Bob" } },
}

LoadAddon()
FIRE("ADDON_LOADED", "ForeverTold")
FIRE("PLAYER_ENTERING_WORLD", true, false)
local DB = ForeverToldDB
print("Forever Told tests")

-- Upgrades -----------------------------------------------------------------------------

test("upgrades run once and tidy old data", function()
    eq(DB.version, 4, "version")
    eq(type(DB.zones["Elwynn Forest"]), "table", "old zone record upgraded")
    eq(DB.entries[1].text, "my own note", "own notes kept")
    eq(kinds("pvp"), 0, "old grudge lines removed")
    for _, e in ipairs(DB.entries) do assert(not e.test, "test-mode line left behind") end
    eq(DB.grudges["Gank-Testrealm"], nil, "test grudge removed")
    assert(DB.grudges.Real, "real grudge kept")
    eq(#DB.debts, 0, "test debt removed")
    eq(DB.bounties.Vex and DB.bounties.Vex.since, DB.bounties.Vex and DB.bounties.Vex.t, "bounty since filled in")
end)

-- The journal ----------------------------------------------------------------------------

test("level-ups and quests are written down", function()
    local before = #DB.entries
    FIRE("PLAYER_LEVEL_UP", 25)
    FIRE("QUEST_TURNED_IN", 1)
    assert(#DB.entries > before, "no new entries")
    assert(kinds("level") > 0, "no level entry")
end)

-- Grudges --------------------------------------------------------------------------------

test("a player kill makes a grudge, not a journal line", function()
    TARGETNAME = "Stabby"
    TICK()
    NOWT = NOWT + 5
    FIRE("PLAYER_DEAD")
    eq(DB.grudges.Stabby and DB.grudges.Stabby.kills, 1, "Stabby's kills")
    eq(kinds("pvp"), 0, "pvp lines in the journal")
end)

test("revenge from the honour message", function()
    NOWT = NOWT + 400
    FIRE("CHAT_MSG_COMBAT_HONOR_GAIN", "Stabby dies, honorable kill Rank: Scout (Estimated Honor Points: 12)")
    eq(DB.grudges.Stabby.revenge, 1, "revenge")
    eq(kinds("revenge"), 0, "revenge lines in the journal")
end)

-- Bounties and posters ----------------------------------------------------------------------

test("a guildie's bounty reaches the board", function()
    FIRE("CHAT_MSG_ADDON", "FTold1", "P~Grimtooth~4~0~ORC~Warrior~33~Ashenvale~10", "GUILD", "Bob-Realm")
    local b = DB.bounties.Grimtooth
    assert(b, "no bounty")
    assert(b.since, "bounty has no since")
    local found
    for _, r in ipairs(NS.BountyBoard()) do if r.name == "Grimtooth" then found = r end end
    eq(found and found.reward, 10, "reward on the board")
end)

test("a custom reward can be typed straight in", function()
    DB.grudges.Newbie = { kills = 2, revenge = 0, class = "Rogue", classFile = "ROGUE", level = 30, zone = "Duskwood", first = time() }
    NS.ShowPoster("Newbie")
    local c = ForeverToldPoster.controls
    assert(c.custom:IsShown(), "custom box hidden")
    c.custom:SetText("37")
    c.custom.scripts.OnTextChanged(c.custom, true)
    eq(ForeverToldPoster.reward.text, "37 GOLD", "poster preview")
    c.custom.scripts.OnEnterPressed(c.custom)
    eq(DB.posters.Newbie and DB.posters.Newbie.reward, 37, "pinned reward")
end)

test("posters wear with age", function()
    eq(NS.WearStage(time()), 0, "new poster")
    eq(NS.WearStage(time() - DAY(10)), 1, "ten days")
    eq(NS.WearStage(time() - DAY(30)), 2, "a month")
    DB.grudges.Newbie.first = time() - DAY(30)
    NS.ShowPoster("Newbie")
    eq(ForeverToldPoster.wear.stage, 2, "big poster stage")
    DB.grudges.Newbie.first = time() - DAY(10)
    NS.ShowPoster("Newbie")
    eq(ForeverToldPoster.wear.stage, 1, "big poster after refresh")
    NS.Open("wanted")
end)

-- Backups ------------------------------------------------------------------------------

test("export and import round trip", function()
    DB.entries[#DB.entries + 1] = { t = 5, lvl = 25, kind = "loot", text = "|cffa335ee|Hitem:1:|h[Edge: \"quotes\" ; } {]|h|r" }
    local code = NS.ExportCode()
    assert(code:match("^FTOLD1:%x+:[%w%+/=]+$"), "code has odd characters")
    local backup, err = NS.ReadCode(code)
    assert(backup, err)
    eq(#backup.db.entries, #DB.entries, "entries")
    eq(backup.db.entries[#DB.entries].text, DB.entries[#DB.entries].text, "awkward text survives")
    eq(backup.db.window, nil, "window position left out")
    eq(backup.name, "Craig", "name")
    -- Pasted with line breaks and spaces is fine.
    assert(NS.ReadCode(code:sub(1, 40) .. "\n  " .. code:sub(41)), "whitespace broke it")
end)

test("bad codes are refused", function()
    local code = NS.ExportCode()
    local ok, err = NS.ReadCode(code:sub(1, #code - 30))
    assert(not ok and err:find("incomplete"), "cut-short code accepted")
    ok, err = NS.ReadCode("hello there")
    assert(not ok and err, "nonsense accepted")
    eq((NS.ReadCode("")), nil, "empty")
    -- Valid checksum, but not our data shape.
    local payload = "s5:hello"
    local a, b = 1, 0
    for i = 1, #payload do a = (a + payload:byte(i)) % 65521 b = (b + a) % 65521 end
    local enc = "czU6aGVsbG8="
    ok, err = NS.ReadCode(("FTOLD1:%08x:%s"):format(b * 65536 + a, enc))
    assert(not ok and err:find("damaged"), "wrong shape accepted")
end)

test("import replaces the journal and reloads", function()
    local backup = assert(NS.ReadCode(NS.ExportCode()))
    backup.db.quests = 999
    DB.window.scale = 1.25
    NS.RestoreBackup(backup)
    assert(RELOADED, "no reload")
    eq(ForeverToldDB.quests, 999, "imported data")
    eq(ForeverToldDB.window.scale, 1.25, "window kept")
    ForeverToldDB = DB
end)

test("export and import dialogs open", function()
    SlashCmdList.FOREVERTOLD("export")
    assert(ForeverToldTransfer:IsShown(), "export not shown")
    assert(#(ForeverToldTransfer.edit:GetText() or "") > 20, "no code in the box")
    SlashCmdList.FOREVERTOLD("import")
    ForeverToldTransfer.edit:SetText(NS.ExportCode())
    assert(ForeverToldTransfer.action:IsShown(), "import button hidden for a good code")
    ForeverToldTransfer.edit:SetText("junk")
    assert(not ForeverToldTransfer.action:IsShown(), "import button shown for junk")
end)

-- Hardcore epitaph -----------------------------------------------------------------------

local function HitBy(name, env)
    CombatLogGetCurrentEventInfo = function()
        if env then return 0, "ENVIRONMENTAL_DAMAGE", false, nil, nil, 0, 0, "me", "Craig", 0, 0, env end
        return 0, "SWING_DAMAGE", false, "npc", name, 0, 0, "me", "Craig", 0, 0
    end
    FIRE("COMBAT_LOG_EVENT_UNFILTERED")
end

test("no epitaph off Hardcore", function()
    NOWT = NOWT + 100
    HitBy("Stitches")
    FIRE("PLAYER_DEAD")
    eq(DB.epitaph, nil, "epitaph on a normal character")
end)

test("a Hardcore death closes the book", function()
    C_GameRules = { IsHardcoreActive = function() return true end }
    NOWT = NOWT + 100
    HitBy("Stitches")
    FIRE("PLAYER_DEAD")
    local e = DB.epitaph
    assert(e, "no epitaph")
    eq(e.cause, "Stitches", "cause")
    eq(e.lvl, 24, "level")
    eq(kinds("epitaph"), 1, "final journal line")
    assert(ForeverToldEpitaph:IsShown(), "stone not shown")
    assert(ForeverToldEpitaph.fell.text:find("Stitches"), "stone doesn't say who")
    eq(ForeverToldEpitaph.kicker.text, "HERE LIES", "heading")
    local before = e.t
    NOWT = NOWT + 100
    HitBy(nil, "Falling")
    FIRE("PLAYER_DEAD")
    eq(DB.epitaph.t, before, "second death rewrote the epitaph")
    eq(kinds("epitaph"), 1, "second final line")
end)

test("falling is named on the stone", function()
    DB.epitaph = nil
    NOWT = NOWT + 100
    HitBy(nil, "Falling")
    FIRE("PLAYER_DEAD")
    eq(DB.epitaph.cause, "a long fall", "cause")
end)

test("the preview reads as a preview", function()
    local saved = DB.epitaph
    DB.epitaph = nil
    SlashCmdList.FOREVERTOLD("epitaph")
    eq(ForeverToldEpitaph.kicker.text, "IF YOU FELL TODAY", "heading")
    DB.epitaph = saved
end)

-- Pages ---------------------------------------------------------------------------------

test("every page opens", function()
    for _, id in ipairs({ "journal", "fellowship", "deeds", "grudges", "bounties", "rivals", "wanted", "atlas", "stats", "settings" }) do
        NS.Open(id)
        assert(ForeverToldFrame.title.text and ForeverToldFrame.title.text ~= "", "no title on " .. id)
    end
end)

test("the journal shows the memorial card", function()
    NS.Open("journal")
    local found
    for _, o in ipairs(ALLOBJ) do
        if o.kind == "fs" and o.shown and o.text == "In memoriam" then found = true end
    end
    assert(found, "no In memoriam row")
end)

print(("%d passed, %d failed"):format(passed, #failed))
if #failed > 0 then os.exit(1) end
