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
    zones = { ["Elwynn Forest"] = 100, ["The Deadmines"] = { t = 50, lvl = 18, instance = true },
        ["somewhere unknown"] = { t = 1, lvl = 1 }, ["Wailing Caverns"] = { t = 60, lvl = 20 } },
    zoneStats = { ["somewhere unknown"] = { time = 112 } },
    bosses = { [585] = { t = 61, name = "Lady Anacondra", zone = "Wailing Caverns" } },
    deathZones = { ["Elwynn Forest"] = 2 },
    grudges = { ["Gank-Testrealm"] = { kills = 1, revenge = 0 }, Real = { kills = 1, revenge = 0, first = 1 } },
    posters = { ["Gank-Testrealm"] = { reward = 5 } },
    bounties = { Vex = { posters = { ["Hild-Realm"] = { kills = 1, ours = 0 } }, t = os.time() - 100 } },
    debts = { { name = "Gank-Testrealm", to = "Bob" } },
}

LoadAddon()
-- Note which events the addon signs up for.
REGISTERED = {}
for _, f in ipairs(FRAMES) do f.RegisterEvent = function(_, e) REGISTERED[e] = true end end
FIRE("ADDON_LOADED", "ForeverTold")
FIRE("PLAYER_ENTERING_WORLD", true, false)
local DB = ForeverToldDB
print("Forever Told tests")

-- Upgrades -----------------------------------------------------------------------------

test("upgrades run once and tidy old data", function()
    eq(DB.version, 7, "version")
    eq(DB.zones["somewhere unknown"], nil, "\"somewhere unknown\" isn't a place")
    eq(DB.zoneStats["somewhere unknown"], nil, "nor does it keep time")
    eq(DB.zones["Wailing Caverns"].instance, true, "a zone with a boss kill is a dungeon")
    eq(DB.chronicled["The Deadmines"], true, "old dungeon runs aren't chronicle news")
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

test("a flight path isn't your first mount", function()
    IsMounted = function() return true end
    UnitOnTaxi = function() return true end
    TICK()
    eq(DB.deeds.mount, nil, "Saddle Up from a flight")
    eq(DB.counters.flights, 1, "flight counted")
    UnitOnTaxi = function() return false end
    TICK()
    assert(DB.deeds.mount, "a real mount didn't count")
    IsMounted = function() return false end
    TICK()
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

-- Foes ----------------------------------------------------------------------------------

test("foes slain are counted from the experience message", function()
    local kills = NS.FoeTotals()
    FIRE("CHAT_MSG_COMBAT_XP_GAIN", "Defias Bandit dies, you gain 45 experience.")
    FIRE("CHAT_MSG_COMBAT_XP_GAIN", "Defias Bandit dies, you gain 45 experience. (+22 exp Rested bonus)")
    FIRE("CHAT_MSG_COMBAT_XP_GAIN", "You gain 120 experience.")
    eq(NS.FoeTotals(), kills + 2, "kills")
    eq(DB.foes["Defias Bandit"].kills, 2, "bandit kills")
    eq(DB.foes["Defias Bandit"].zones["Elwynn Forest"], 2, "kills by zone")
    eq(DB.zoneStats["Elwynn Forest"].kills, 2, "zone story kills")
end)

test("the toughest kill is the highest level elite", function()
    TARGETNAME = "Mor'Ladim"
    UnitClassification = function(u) return u == "target" and "elite" or "normal" end
    FIRE("CHAT_MSG_COMBAT_XP_GAIN", "Mor'Ladim dies, you gain 300 experience.")
    eq(DB.toughest and DB.toughest.name, "Mor'Ladim", "toughest")
    eq(DB.toughest.class, "elite", "elite")
    TARGETNAME = "Young Wolf"
    UnitClassification = function() return "normal" end
    FIRE("CHAT_MSG_COMBAT_XP_GAIN", "Young Wolf dies, you gain 300 experience.")
    eq(DB.toughest.name, "Mor'Ladim", "a normal wolf isn't tougher")
    TARGETNAME = "Stabby"
end)

test("deadliest foes come from every death", function()
    local deadly = NS.DeadliestFoes()
    eq(deadly[1].name, "Stitches", "top killer")
    eq(deadly[1].n, 2, "Stitches' kills")
    eq(DB.foes.Stabby and DB.foes.Stabby.player, true, "a player killer is marked")
    eq(DB.foes["a long fall"] and DB.foes["a long fall"].env, true, "falling counts")
end)

local function Rows(id)
    local found = {}
    for _, item in ipairs(NS.Pages[id].items()) do
        found[#found + 1] = item
        for _, t in ipairs(item.tiles or {}) do found[#found + 1] = { text = t.value, label = t.label } end
    end
    return found
end
local function Find(rows, pattern)
    for _, r in ipairs(rows) do
        for _, k in ipairs({ "text", "label", "value", "right", "sub" }) do
            if type(r[k]) == "string" and r[k]:find(pattern) then return r end
        end
    end
end

test("the stats page shows the foes", function()
    local rows = Rows("stats")
    assert(Find(rows, "^Deadliest foes$"), "no deadliest foes")
    assert(Find(rows, "^Foes slain the most$"), "no foes slain")
    assert(Find(rows, "^Nemesis of the wilds: Stitches$"), "no nemesis card")
    assert(Find(rows, "Mor'Ladim, level 30 elite"), "no toughest kill")
    assert(Find(rows, "^Foes slain$"), "no foes slain tile")
    assert(Find(rows, "Stabby .*player"), "player not marked")
end)

-- Atlas ---------------------------------------------------------------------------------

test("the atlas tracks each continent and tells each zone's story", function()
    C_Map.GetMapInfo = function(id)
        if id == 13 then return { name = "Eastern Kingdoms", mapType = 2 } end
        return { name = "Duskwood", mapType = 3, parentMapID = 13 }
    end
    C_Map.GetMapChildrenInfo = function(id)
        if id ~= 13 then return {} end
        return { { name = "Duskwood" }, { name = "Elwynn Forest" }, { name = "Westfall" }, { name = "Redridge Mountains" }, { name = "Westfall" } }
    end
    GetRealZoneText = function() return "Duskwood" end
    FIRE("ZONE_CHANGED_NEW_AREA")
    eq(DB.continents[13], "Eastern Kingdoms", "continent remembered")
    FIRE("QUEST_TURNED_IN", 2)
    NOWT = NOWT + 3600
    GetRealZoneText = function() return "Elwynn Forest" end
    FIRE("ZONE_CHANGED_NEW_AREA")
    eq(DB.zoneStats.Duskwood.quests, 1, "quests in Duskwood")
    eq(DB.zoneStats.Duskwood.time, 3600, "time in Duskwood")
    local rows = Rows("atlas")
    assert(Find(rows, "^2 of 4 zones$"), "no completion")
    local unseen = Find(rows, "^Still to explore$")
    assert(unseen and unseen.sub:find("Westfall") and unseen.sub:find("Redridge"), "unvisited zones missing")
    local dusk
    for _, r in ipairs(rows) do if r.text == "Duskwood" and r.tip then dusk = r end end
    assert(dusk and dusk.tip, "no story")
    assert(table.concat(dusk.tip.lines, "\n"):find("1 quest"), "story has no quests")
    assert(Find(rows, "Favourite · 1h"), "no favourite place")
    local deadly = Find(rows, "^Deadliest")
    eq(deadly and deadly.text, "Elwynn Forest", "deadliest zone")
end)

-- Guild chronicle ------------------------------------------------------------------------

local function Sent(pattern)
    for _, m in ipairs(ADDONMSG) do if m:find(pattern) then return m end end
end

test("a guildie's milestone reaches the chronicle once", function()
    local before = #DB.chronicle
    local t = time() - 3600
    FIRE("CHAT_MSG_ADDON", "FTold1", ("M~Hild-Realm~%d~level~PALADIN~40~40~Stranglethorn Vale~"):format(t), "GUILD", "Hild-Realm")
    FIRE("CHAT_MSG_ADDON", "FTold1", ("M~Hild-Realm~%d~level~PALADIN~40~40~Stranglethorn Vale~"):format(t), "GUILD", "Bob-Realm")
    eq(#DB.chronicle, before + 1, "stored once")
    FIRE("CHAT_MSG_ADDON", "FTold1", ("M~Old~%d~level~MAGE~20~20~Duskwood~"):format(time() - DAY(40)), "GUILD", "Old")
    eq(#DB.chronicle, before + 1, "too old to keep")
end)

test("my own milestones are shared", function()
    ADDONMSG = {}
    FIRE("PLAYER_LEVEL_UP", 30)
    FIRE("PLAYER_LEVEL_UP", 31)
    assert(Sent("^M~Craig~%d+~level~WARRIOR~24~30~"), "level 30 not shared")
    assert(not Sent("~31~"), "level 31 shared")
    FIRE("CHAT_MSG_LOOT", "You receive loot: |cffa335ee|Hitem:1:|h[Gut Ripper]|h|r.")
    assert(Sent("~loot~.*Gut Ripper"), "epic not shared")
end)

test("a first dungeon run is told on the way out", function()
    ADDONMSG = {}
    GetRealZoneText = function() return "Shadowfang Keep" end
    IsInInstance = function() return true end
    local name = UnitName
    UnitName = function(u) if u == "party1" then return "Bob" end return name(u) end
    FIRE("ZONE_CHANGED_NEW_AREA")
    FIRE("ENCOUNTER_END", 77, "Arugal", 1, 5, 1)
    assert(not Sent("~dungeon~"), "told before leaving")
    IsInInstance = function() return false end
    GetRealZoneText = function() return "Silverpine Forest" end
    FIRE("ZONE_CHANGED_NEW_AREA")
    assert(Sent("~dungeon~[^~]*~[^~]*~Shadowfang Keep~1~Bob$"), "first run not told: " .. table.concat(ADDONMSG, " / "))
    UnitName = name
    local n = #ADDONMSG
    GetRealZoneText = function() return "Shadowfang Keep" end
    IsInInstance = function() return true end
    FIRE("ZONE_CHANGED_NEW_AREA")
    NOWT = NOWT + 60
    FIRE("ENCOUNTER_END", 78, "Rethilgore", 1, 5, 1)
    IsInInstance = function() return false end
    GetRealZoneText = function() return "Elwynn Forest" end
    FIRE("ZONE_CHANGED_NEW_AREA")
    eq(#ADDONMSG, n, "second run told again")
end)

test("a guildie logging in gets the news", function()
    ADDONMSG = {}
    NOWT = NOWT + 60
    FIRE("CHAT_MSG_ADDON", "FTold1", "H~0", "GUILD", "Grim-Realm")
    assert(Sent("^M~Craig~.*~level~"), "own news not sent")
    assert(Sent("^M~Hild%-Realm~"), "guildie's news not relayed")
end)

test("a guildie with no milestones yet still shows up", function()
    ADDONMSG = {}
    FIRE("CHAT_MSG_ADDON", "FTold1", "H~0~PRIEST~7", "GUILD", "Mira-Realm")
    local found
    for _, g in ipairs(NS.Guildies()) do if g.name == "Mira" then found = g end end
    assert(found and found.level == 7 and found.classFile == "PRIEST", "hello didn't add Mira")
    assert(Sent("^I~WARRIOR~24$"), "didn't answer the hello: " .. table.concat(ADDONMSG, " / "))
    FIRE("CHAT_MSG_ADDON", "FTold1", "I~SHAMAN~5", "GUILD", "Tok-Realm")
    -- Both were heard in the same second, so either may come first.
    local rows = Rows("chronicle")
    assert(Find(rows, "Also keeping a journal: .*Tok") and Find(rows, "Also keeping a journal: .*Mira"), "keepers not listed")
end)

test("a hello asks for news since I was last online, not since my newest entry", function()
    DB.lastOnline = nil
    eq(NS.ChronicleSince(), 0, "first login asks for everything")
    FIRE("PLAYER_LOGOUT")
    assert(DB.lastOnline and NS.ChronicleSince() == DB.lastOnline - 3600, "logout time not used")
end)

test("a burst of messages is paced, not dropped", function()
    ADDONMSG = {}
    for i = 1, 20 do NS.GuildSend("X~" .. i) end
    eq(#ADDONMSG, 20, "all sent in the end")
    eq(ADDONMSG[20], "X~20", "kept in order")
end)

test("/told guild reports the channel", function()
    local out = {}
    local p = print
    print = function(m) out[#out + 1] = m end
    SlashCmdList.FOREVERTOLD("guild")
    print = p
    local all = table.concat(out, "\n")
    assert(all:find("Guild channel: open"), all)
    assert(all:find("Mira %(7%)"), all)
end)

test("sharing can be turned off", function()
    DB.shareChronicle = false
    ADDONMSG = {}
    FIRE("PLAYER_LEVEL_UP", 40)
    FIRE("CHAT_MSG_ADDON", "FTold1", "H~0", "GUILD", "Grim-Realm")
    assert(not Sent("^M~"), "shared while off")
    assert(Find(Rows("chronicle"), "You|r reached level 40"), "not kept locally")
    DB.shareChronicle = true
end)

test("the chronicle page reads like a story", function()
    local rows = Rows("chronicle")
    assert(Find(rows, "^Today$"), "no day heading")
    eq(NS.Pages.chronicle.title, "Guild Chronicles", "menu name")
    assert(Find(rows, "Hild|r reached level 40 in Stranglethorn Vale%."), "guildie's level")
    assert(Find(rows, "ran Shadowfang Keep for the first time, with Bob%."), "dungeon run")
    assert(Find(rows, "looted .*Gut Ripper"), "loot")
    eq(NS.Pages.chronicle.badge(), "1", "badge counts guildies' news")
    NS.PageView.chronicle = "loot"
    rows = Rows("chronicle")
    assert(not Find(rows, "reached level"), "levels under loot")
    NS.PageView.chronicle = "all"
end)

-- Hall of Heroes ----------------------------------------------------------------------

test("each character writes its line in the hall", function()
    local h = ForeverToldAccountDB.heroes["Craig-Stormrage"]
    assert(h, "no hall entry")
    eq(h.level, 24, "level")
    eq(h.classFile, "WARRIOR", "class")
    ForeverToldAccountDB.heroes["Frostbyte-Stormrage"] = { name = "Frostbyte", realm = "Stormrage", level = 47, class = "Mage",
        classFile = "MAGE", race = "Gnome", quests = 512, deeds = 21, t = time() - DAY(2), played = 3600 * 30 }
    ForeverToldAccountDB.heroes["Brunhild-Stormrage"] = { name = "Brunhild", realm = "Stormrage", level = 34, t = time() - DAY(9),
        epitaph = { name = "Brunhild", lvl = 34, race = "Dwarf", class = "Paladin", zone = "Desolace", cause = "Hulking Gritjaw", t = time() - DAY(9) } }
    local rows = Rows("heroes")
    assert(Find(rows, "^Still on the road$"), "no living section")
    -- Craig fell on Hardcore earlier in these tests, so he's a stone now.
    assert(Find(rows, "^Frostbyte$"), "other character missing")
    local stones
    for _, r in ipairs(rows) do if r.type == "stones" then stones = r.stones end end
    eq(stones and #stones, 2, "stones")
    local brunhild
    for _, st in ipairs(stones) do if st.name == "BRUNHILD" then brunhild = st end end
    assert(brunhild and brunhild.fell:find("Desolace"), "Brunhild's stone")
    brunhild.onClick()
    eq(ForeverToldEpitaph.name.text, "BRUNHILD", "full stone opens")
    eq(ForeverToldEpitaph.kicker.text, "HERE LIES", "a real epitaph, not a preview")
    eq(Find(rows, "^Characters$").text, "3", "character count")
end)

test("a character can be removed from the hall, but not yourself", function()
    IsShiftKeyDown = function() return true end
    Find(Rows("heroes"), "^Frostbyte$").onClick()
    eq(ForeverToldAccountDB.heroes["Frostbyte-Stormrage"], nil, "not removed")
    NS.ForgetHero("Craig-Stormrage")
    assert(ForeverToldAccountDB.heroes["Craig-Stormrage"], "removed yourself")
    IsShiftKeyDown = function() return false end
end)

-- New deeds -----------------------------------------------------------------------------

test("the new deeds read what 1.0 keeps", function()
    eq(#NS.DEEDS, 45, "deed count")
    assert(DB.deeds.giant, "Mor'Ladim was an elite 6 levels up")
    assert(not DB.deeds.slain1000, "1,000 kills too early")
    DB.foes["Defias Bandit"].kills = 1000
    NS.CheckDeeds()
    assert(DB.deeds.slain1000, "Thousand Cuts")
    local ek
    for _, d in ipairs(NS.DEEDS) do if d[1] == "ekexplorer" then ek = d end end
    local value, goal = NS.DeedProgress(ek)
    eq(goal, 4, "zones on the map")
    eq(value, 2, "zones explored")
    DB.zones.Westfall = { t = time() }
    DB.zones["Redridge Mountains"] = { t = time() }
    NS.CheckDeeds()
    assert(DB.deeds.ekexplorer, "Eastern Kingdoms Explorer")
    eq(DB.deeds.kalexplorer, nil, "Kalimdor isn't on the map, so it can't be earned")
    assert((DB.counters.chronicled or 0) >= 3, "chronicle appearances counted")
    eq(DB.deeds.heroes, nil, "only 2 heroes left")
end)

-- Events ----------------------------------------------------------------------------------

test("the combat log isn't requested on WoW Forever", function()
    assert(REGISTERED.PLAYER_DEAD, "normal events not registered")
    eq(REGISTERED.COMBAT_LOG_EVENT_UNFILTERED, nil, "combat log registered on WoW Forever")
end)

-- WoW Forever in a dungeon: the game keeps some answers secret, and testing one
-- with "if" is an error. A secret must count as "don't know", never as yes.
test("secret answers in a dungeon are skipped, not tested", function()
    local saved = {}
    for _, k in ipairs({ "UnitIsUnit", "UnitCanAttack", "UnitIsPlayer", "UnitExists", "UnitName", "UnitIsDead", "UnitLevel" }) do saved[k] = _G[k] end
    local function secret() return SECRET end
    NOWT = NOWT + 100 -- earlier attackers are forgotten
    local grudges = count(DB.grudges)
    -- A monster is targeting us, but the game won't say so.
    UnitIsPlayer = function(u) return u == "player" end
    UnitIsUnit = secret
    TICK()
    eq(NS.RecentFoe(), nil, "a secret 'targeting me' counted as yes")
    -- Nothing about any other unit can be read.
    UnitExists, UnitIsPlayer, UnitCanAttack, UnitIsDead = secret, secret, secret, secret
    UnitName = function(u) if u == "player" then return "Craig" end return SECRET end
    UnitLevel = function(u) if u == "player" then return 24 end return SECRET end
    TICK()
    FIRE("PLAYER_TARGET_CHANGED")
    FIRE("NAME_PLATE_UNIT_ADDED", "nameplate1")
    FIRE("UPDATE_MOUSEOVER_UNIT")
    FIRE("LOOT_READY")
    FIRE("CHAT_MSG_COMBAT_XP_GAIN", "Stabby dies, you gain 300 experience.")
    FIRE("ENCOUNTER_END", 99, "Edwin VanCleef", 1, 5, SECRET)
    eq(NS.RecentFoe(), nil, "a secret unit counted as a foe")
    eq(count(DB.grudges), grudges, "grudges")
    eq(DB.bosses[99], nil, "a secret boss result counted as a kill")
    for k, v in pairs(saved) do _G[k] = v end
end)

-- WoW Forever names and zones --------------------------------------------------------------

test("on WoW Forever my own guild messages aren't a guildie", function()
    ADDONMSG = {}
    FIRE("CHAT_MSG_ADDON", "FTold1", "H~0~WARRIOR~24", "GUILD", "Craig Joseph")
    for _, g in ipairs(NS.Guildies()) do assert(g.name ~= "Craig" and g.name ~= "Craig Joseph", "listed myself") end
    assert(not Sent("^I~"), "answered my own hello")
    FIRE("CHAT_MSG_ADDON", "FTold1", "I~PRIEST~21", "GUILD", "Vatic Cane")
    local found
    for _, g in ipairs(NS.Guildies()) do if g.name == "Vatic" then found = g end end
    assert(found and found.level == 21, "Vatic Cane not heard as Vatic")
end)

test("old \"Name Surname\" guildies and posters are tidied", function()
    DB.guildies["Craig Joseph"] = { t = time(), level = 20 }
    DB.guildies["Rhozak Warbreaker"] = { t = time(), level = 19, classFile = "WARRIOR" }
    DB.bounties.Dotty = { posters = { ["Vatic Cane"] = { kills = 1, ours = 0, t = time() } }, since = time(), t = time() }
    NS.TidyNames()
    eq(DB.guildies["Craig Joseph"], nil, "myself still a guildie")
    eq(DB.guildies.Craig, nil, "myself still a guildie")
    eq(DB.guildies.Rhozak and DB.guildies.Rhozak.level, 19, "guildie re-filed")
    eq(DB.guildies["Rhozak Warbreaker"], nil, "old guildie key left")
    assert(DB.bounties.Dotty.posters["Vatic-Cane"] and not DB.bounties.Dotty.posters["Vatic Cane"], "poster not re-filed")
    DB.bounties.Dotty = nil
end)

test("a dungeon is named by the dungeon, not the zone outside", function()
    local saved = { GetRealZoneText = GetRealZoneText, IsInInstance = IsInInstance, GetInstanceInfo = GetInstanceInfo }
    GetRealZoneText = function() return "Orgrimmar" end
    IsInInstance = function() return true, "party" end
    GetInstanceInfo = function() return "Ragefire Chasm", "party" end
    local runs = DB.counters.runs or 0
    FIRE("PLAYER_ENTERING_WORLD")
    eq(DB.zones["Ragefire Chasm"] and DB.zones["Ragefire Chasm"].instance, true, "dungeon not noted as one")
    eq((DB.counters.runZones or {})["Ragefire Chasm"], 1, "run not filed under the dungeon")
    eq((DB.counters.runZones or {}).Orgrimmar, nil, "run filed under the city outside")
    eq(DB.counters.runs, runs + 1, "run counted")
    FIRE("CHAT_MSG_COMBAT_XP_GAIN", "Ragefire Trogg dies, you gain 90 experience.")
    eq(DB.foes["Ragefire Trogg"].zones["Ragefire Chasm"], 1, "kill filed under the dungeon")
    GetRealZoneText, IsInInstance, GetInstanceInfo = saved.GetRealZoneText, saved.IsInInstance, saved.GetInstanceInfo
    FIRE("ZONE_CHANGED_NEW_AREA")
end)

test("a dungeon first seen as a plain zone is marked once we're inside", function()
    local saved = { GetRealZoneText = GetRealZoneText, IsInInstance = IsInInstance }
    GetRealZoneText = function() return "Blackfathom Deeps" end
    FIRE("ZONE_CHANGED_NEW_AREA")
    eq(DB.zones["Blackfathom Deeps"].instance, nil, "outside")
    IsInInstance = function() return true, "party" end
    FIRE("PLAYER_ENTERING_WORLD")
    eq(DB.zones["Blackfathom Deeps"].instance, true, "not marked as a dungeon")
    for k, v in pairs(saved) do _G[k] = v end
    FIRE("ZONE_CHANGED_NEW_AREA")
end)

test("no zone text yet is no place", function()
    local saved = GetRealZoneText
    GetRealZoneText = function() return "" end
    FIRE("ZONE_CHANGED_NEW_AREA")
    eq(DB.zones["somewhere unknown"], nil, "\"somewhere unknown\" saved as a place")
    GetRealZoneText = saved
    FIRE("ZONE_CHANGED_NEW_AREA")
end)

-- Friends who turn on you, and forgiving ----------------------------------------------------

test("a party member who turns on me isn't a grudge", function()
    UnitInParty = function(u) return u == "nameplate1" end
    TARGETNAME = "Cursed"
    TICK()
    NOWT = NOWT + 5
    FIRE("PLAYER_DEAD")
    eq(DB.grudges.Cursed, nil, "grudge on a party member")
    UnitInParty = nil
    TARGETNAME = "Stabby"
end)

test("a guildie who turns on me isn't a grudge either", function()
    DB.guildies.Turncoat = { t = time() }
    TARGETNAME = "Turncoat"
    TICK()
    NOWT = NOWT + 5
    FIRE("PLAYER_DEAD")
    eq(DB.grudges.Turncoat, nil, "grudge on a guildie")
    DB.guildies.Turncoat = nil
    TARGETNAME = "Stabby"
end)

test("forgiving drops the grudge and takes the poster down", function()
    DB.grudges["Rose-Go"] = { kills = 1, revenge = 0, first = time(), zone = "Hillsbrad Foothills" }
    DB.posters["Rose-Go"] = { reward = 0, t = time() }
    ADDONMSG = {}
    eq(NS.Forgive("Rose"), "Rose-Go", "found by short name")
    eq(DB.grudges["Rose-Go"], nil, "grudge kept")
    eq(DB.posters["Rose-Go"].done, true, "poster still up")
    assert(Sent("^W~Rose%-Go$"), "guild not told: " .. table.concat(ADDONMSG, " / "))
    eq(NS.Forgive("Nobody"), nil, "forgave a stranger")
    PRINTED = {}
    SlashCmdList.FOREVERTOLD("forgive Nobody")
    assert(table.concat(PRINTED, " "):find("Usage: /told forgive"), "no usage hint")
end)

test("right-clicking a grudge forgives it", function()
    DB.grudges.Clicky = { kills = 1, revenge = 0, first = time(), zone = "Duskwood", class = "Rogue", classFile = "ROGUE" }
    local row = Find(Rows("grudges"), "^Clicky$")
    assert(row and row.onClick, "no Clicky row")
    row.onClick("LeftButton")
    assert(DB.grudges.Clicky, "a left click forgave")
    row.onClick("RightButton")
    eq(DB.grudges.Clicky, nil, "right click didn't forgive")
end)

test("old grudges on guildies are forgiven", function()
    DB.grudges["Vatic-Cane"] = { kills = 1, revenge = 0, first = time(), zone = "Shadowfang Keep" }
    DB.guildies.Vatic = { t = time(), level = 25 }
    NS.ForgiveGuildies()
    eq(DB.grudges["Vatic-Cane"], nil, "grudge on a guildie kept")
    DB.guildies.Vatic = nil
end)

test("my own echoed posters leave the board", function()
    DB.bounties["Vatic-Cane"] = { posters = { ["Craig"] = { kills = 1, ours = 0, t = time() } }, since = time(), t = time() }
    NS.TidyNames()
    eq(DB.bounties["Vatic-Cane"], nil, "my own echo still on the board")
end)

test("the hall keeps my last real zone while logging out", function()
    local h = ForeverToldAccountDB.heroes["Craig-Stormrage"]
    h.zone = "Elwynn Forest"
    local saved = GetRealZoneText
    GetRealZoneText = function() return "" end
    NS.SaveHero()
    eq(h.zone, "Elwynn Forest", "zone in the hall")
    GetRealZoneText = saved
end)

-- 1.2.0: run repair, error log, fastest level ------------------------------------------------

test("old runs filed under a dungeon's door move to the dungeon", function()
    local fake = {
        zones = { ["Ragefire Chasm"] = { instance = true }, ["Wailing Caverns"] = { instance = true },
            ["Razorfen Kraul"] = { instance = true }, Orgrimmar = {}, ["The Barrens"] = {}, ["The Wailing Caverns"] = {} },
        counters = { runZones = { Orgrimmar = 2, ["Ragefire Chasm"] = 2, ["The Wailing Caverns"] = 2,
            ["Silverpine Forest"] = 1, ["The Barrens"] = 1 } },
    }
    eq(NS.RepairRuns(fake), 4, "runs moved")
    local runs = fake.counters.runZones
    eq(runs["Ragefire Chasm"], 4, "Orgrimmar's runs")
    eq(runs.Orgrimmar, nil, "Orgrimmar still has runs")
    eq(runs["Wailing Caverns"], 2, "the cave's runs")
    eq(runs["Silverpine Forest"], 1, "moved to a dungeon never visited")
    eq(runs["The Barrens"], 1, "guessed between two dungeons")
end)

test("errors are written down, and the rest still runs", function()
    local handler = geterrorhandler
    geterrorhandler = nil
    ForeverToldAccountDB.errors = {}
    local after = 0
    NS.On("FT_TEST_EVENT", function() error("Pages/Fake.lua:12: boom") end)
    NS.On("FT_TEST_EVENT", function() after = after + 1 end)
    PRINTED = {}
    FIRE("FT_TEST_EVENT")
    FIRE("FT_TEST_EVENT")
    geterrorhandler = handler
    eq(after, 2, "later handlers skipped")
    local list = ForeverToldAccountDB.errors
    eq(#list, 1, "one distinct error")
    eq(list[1].count, 2, "count")
    eq(list[1].where, "FT_TEST_EVENT", "where")
    assert(list[1].text:find("boom"), "text")
    local warned = 0
    for _, line in ipairs(PRINTED) do if line:find("/told errors") then warned = warned + 1 end end
    eq(warned, 1, "warned once")
    PRINTED = {}
    SlashCmdList.FOREVERTOLD("errors")
    assert(table.concat(PRINTED, "\n"):find("x2.*boom"), "not listed: " .. table.concat(PRINTED, " / "))
    SlashCmdList.FOREVERTOLD("errors clear")
    eq(#ForeverToldAccountDB.errors, 0, "not cleared")
    NS.listeners.FT_TEST_EVENT = nil
end)

test("an error still reaches the game's error handler", function()
    NS.On("FT_TEST_EVENT", function() error("still loud") end)
    local ok, err = pcall(FIRE, "FT_TEST_EVENT")
    assert(not ok and tostring(err):find("still loud"), "error hidden")
    NS.listeners.FT_TEST_EVENT = nil
    ForeverToldAccountDB.errors = {}
end)

test("fastest and slowest level skip the first few minutes-long levels", function()
    local saved = DB.levelTimes
    DB.levelTimes = { [2] = 60, [10] = 3000, [11] = 2000, [12] = 9000 }
    local rows = Rows("stats")
    local fast, slow = Find(rows, "^Fastest level"), Find(rows, "^Slowest level")
    assert(fast and fast.value:find("^11 to 12"), "fastest: " .. tostring(fast and fast.value))
    assert(slow and slow.value:find("^12 to 13"), "slowest: " .. tostring(slow and slow.value))
    eq(fast.label, "Fastest level (from level 10)", "label")
    DB.levelTimes = { [2] = 60, [3] = 300 }
    fast = Find(Rows("stats"), "^Fastest level")
    assert(fast and fast.label == "Fastest level" and fast.value:find("^2 to 3"), "early levels only")
    DB.levelTimes = saved
end)

-- Pages ---------------------------------------------------------------------------------

test("every page opens", function()
    for _, id in ipairs({ "journal", "fellowship", "deeds", "grudges", "bounties", "rivals", "wanted", "chronicle", "guild", "atlas", "stats", "heroes", "hall", "settings" }) do
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
