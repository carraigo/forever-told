-- Forever Told pages. Each page gives the window a title, a subtitle, an
-- optional badge for the sidebar, controls (build) and list rows (items).
-- The window itself lives in UI.lua.

local _, ns = ...
local U, S = ns.U, ns.Skin
local C = S.colours
local Count, Plural, Short, Hex, ClassColour, Duration = U.Count, U.Plural, U.Short, U.Hex, U.ClassColour, U.Duration

local PAGES = {}
ns.Pages = PAGES
ns.PAGE_ORDER = { "journal", "fellowship", "deeds", "grudges", "atlas", "stats", "settings" }
-- Extra slash names that open a page on a particular view.
ns.PAGE_ALIASES = { bounties = { "grudges", "bounties" }, bounty = { "grudges", "bounties" }, rivals = { "grudges", "rivals" },
    wanted = { "grudges", "wall" }, posters = { "grudges", "wall" } }

local view = { filter = "all", newestFirst = true, grudges = "mine" }
ns.PageView = view

local RED = { 0.92, 0.36, 0.30, 1 }

local function Chapter(level)
    local c = ns.ChapterOf(level or 1)
    return c, ns.CHAPTERS[c]
end

local function ChapterTitle(c)
    if c >= 6 then return "Chapter 7 · " .. ns.CHAPTERS[6], "level 60" end
    return ("Chapter %d · %s"):format(c + 1, ns.CHAPTERS[c]), ("levels %d to %d"):format(math.max(1, c * 10), c * 10 + 9)
end
ns.ChapterTitle = ChapterTitle

local function Empty(text) return { { type = "empty", text = text } } end

local function GrudgeTotals()
    local kills, ours = 0, 0
    for _, g in pairs(ns.DB.grudges) do
        local o, t = ns.GrudgeScore(g)
        kills, ours = kills + t, ours + o
    end
    return kills, ours
end

local function OpenGrudges()
    local n = 0
    for _, g in pairs(ns.DB.grudges) do if ns.GrudgeOpen(g) then n = n + 1 end end
    return n
end

-- Journal ------------------------------------------------------------------------------

PAGES.journal = {
    title = "Journal", icon = "Interface\\Icons\\INV_Misc_Book_09",
    subtitle = function() return ("%s, chapter by chapter."):format(Plural(#ns.DB.entries, "entry", "entries")) end,
    build = function(p)
        local options = {}
        for _, f in ipairs(ns.FILTERS) do options[#options + 1] = { id = f.id, label = f.label } end
        local filter = S.Dropdown(p, 140, options, function() return view.filter end, function(id)
            view.filter = id
            ns.Refresh()
        end)
        filter:SetPoint("TOPLEFT", 0, 0)
        local order = S.Segments(p, { { id = true, label = "Newest" }, { id = false, label = "Oldest" } },
            function() return view.newestFirst end,
            function(v) view.newestFirst = v ns.Refresh() end, 70)
        order:SetPoint("LEFT", filter, "RIGHT", 8, 0)

        p.list:ClearAllPoints()
        p.list:SetPoint("TOPLEFT", 0, -38)
        p.list:SetPoint("BOTTOMRIGHT", 0, 40)

        local note = S.Input(p, 10, "Write a note: what happened today?")
        note:SetPoint("BOTTOMLEFT", 0, 4)
        note:SetPoint("BOTTOMRIGHT", -112, 4)
        local add = S.Button(p, "Add note", 104, 26, "primary")
        add:SetPoint("BOTTOMRIGHT", 0, 4)
        local function Commit()
            local text = note:GetText()
            if text and text:match("%S") then
                ns.Add("note", text)
                note:SetText("")
                note:ClearFocus()
            end
        end
        add:SetScript("OnClick", Commit)
        note:SetScript("OnEnterPressed", Commit)
    end,
    items = function()
        local DB = ns.DB
        local shown = {}
        for _, e in ipairs(DB.entries) do
            local kind = ns.KINDS[e.kind]
            if view.filter == "all" or (kind and kind.filter == view.filter) then shown[#shown + 1] = e end
        end
        if #shown == 0 then
            return Empty(#DB.entries == 0 and "Your story hasn't started yet. Go and explore!" or "Nothing here yet for this filter.")
        end
        local items, chapter = {}, nil
        local first, last, step = 1, #shown, 1
        if view.newestFirst then first, last, step = #shown, 1, -1 end
        for i = first, last, step do
            local e = shown[i]
            local c = Chapter(e.lvl)
            if c ~= chapter then
                chapter = c
                if #items > 0 then items[#items + 1] = { type = "gap", size = 6 } end
                local title, range = ChapterTitle(c)
                items[#items + 1] = { type = "header", text = title, right = range }
            end
            local kind = ns.KINDS[e.kind]
            local colour = Hex(kind and kind.colour or "ffffff")
            local special = e.kind == "recap" or e.kind == "deed" or e.kind == "revenge" or e.kind == "pvp"
            items[#items + 1] = {
                meta = ("%s · Lv %d"):format(date("%d %b", e.t), e.lvl or 0),
                text = e.text, dot = colour, search = e.zone,
                colour = special and colour or nil,
                card = (e.kind == "recap" or e.kind == "revenge") or nil,
            }
        end
        return items
    end,
}

-- Fellowship ---------------------------------------------------------------------------

local function FellowTip(name, f)
    return { title = Short(name), lines = {
        ("%s · first met %s"):format(f.class or "Adventurer", date("%d %B %Y", f.first)),
        ("At your level %d, in %s"):format(f.firstLvl or 0, f.firstZone or "?"),
        ("%s · %s · %s"):format(Plural(f.groups, "group"), Plural(f.dungeons, "dungeon run"), Plural(f.bosses, "boss", "bosses")),
        f.last and ("Last grouped %s"):format(U.Ago(f.last)) or nil,
    } }
end

PAGES.fellowship = {
    title = "Fellowship", icon = "Interface\\Icons\\Spell_Holy_PrayerOfFortitude",
    subtitle = function()
        return ("%s · %s together"):format(Plural(Count(ns.DB.fellows), "adventurer"), Plural(ns.DB.counters.runs or 0, "dungeon run"))
    end,
    badge = function() local n = Count(ns.DB.fellows) return n > 0 and tostring(n) or nil end,
    items = function()
        local list = ns.SortedFellows()
        if #list == 0 then return Empty("No companions yet. Group up with someone and they'll be remembered here.") end
        local items = {}
        local best = list[1]
        if ns.FellowScore(best.f) > 1 then
            local f = best.f
            items[#items + 1] = { type = "header", text = "Closest companion" }
            items[#items + 1] = { text = Short(best.name), colour = ClassColour(f.classFile), dot = ClassColour(f.classFile), card = true,
                sub = ("%s · met %s · %s, %s, %s"):format(f.class or "", date("%d %b %Y", f.first),
                    Plural(f.groups, "group"), Plural(f.dungeons, "dungeon"), Plural(f.bosses, "boss", "bosses")),
                tip = FellowTip(best.name, f) }
            items[#items + 1] = { type = "gap", size = 8 }
        end
        items[#items + 1] = { type = "header", text = "Everyone you've grouped with", right = Plural(#list, "person", "people") }
        for i, item in ipairs(list) do
            if i > 300 then break end
            local f = item.f
            local bits = { Plural(f.groups, "group") }
            if f.dungeons > 0 then bits[#bits + 1] = Plural(f.dungeons, "dungeon") end
            if f.bosses > 0 then bits[#bits + 1] = Plural(f.bosses, "boss", "bosses") end
            items[#items + 1] = {
                text = Short(item.name), colour = ClassColour(f.classFile), dot = ClassColour(f.classFile),
                sub = ("%s · met at level %d in %s"):format(f.class or "", f.firstLvl or 0, f.firstZone or "?"),
                right = table.concat(bits, " · "), tip = FellowTip(item.name, f),
            }
        end
        return items
    end,
}

-- Deeds --------------------------------------------------------------------------------

PAGES.deeds = {
    title = "Deeds", icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
    subtitle = function() return ("%d of %d earned"):format(Count(ns.DB.deeds), #ns.DEEDS) end,
    badge = function() return ("%d/%d"):format(Count(ns.DB.deeds), #ns.DEEDS) end,
    items = function()
        local DB = ns.DB
        local earned, waiting = {}, {}
        for _, deed in ipairs(ns.DEEDS) do
            if DB.deeds[deed[1]] then earned[#earned + 1] = deed else waiting[#waiting + 1] = deed end
        end
        local items = { { type = "bar", label = "Progress", labelWidth = 70, height = 26,
            value = ("%d%%"):format(math.floor(#earned / #ns.DEEDS * 100)), fraction = #earned / #ns.DEEDS } }
        if #earned > 0 then
            items[#items + 1] = { type = "header", text = "Earned", right = tostring(#earned) }
            for _, deed in ipairs(earned) do
                local d = DB.deeds[deed[1]]
                items[#items + 1] = { text = deed[2], sub = deed[3], colour = Hex("ff9d2e"), dot = Hex("ff9d2e"), card = true,
                    right = d.earlier and "earned earlier" or ("%s · Lv %d"):format(date("%d %b %Y", d.t), d.lvl or 0) }
            end
            items[#items + 1] = { type = "gap", size = 8 }
        end
        items[#items + 1] = { type = "header", text = "Still to earn", right = tostring(#waiting) }
        -- Closest to done first.
        table.sort(waiting, function(a, b)
            local va, ga = ns.DeedProgress(a)
            local vb, gb = ns.DeedProgress(b)
            return va / ga > vb / gb
        end)
        for _, deed in ipairs(waiting) do
            local value, goal = ns.DeedProgress(deed)
            items[#items + 1] = { text = deed[2], sub = deed[3], colour = C.muted, dot = { 1, 1, 1, 0.2 },
                right = goal > 1 and ("%d / %d"):format(value, goal) or nil }
        end
        return items
    end,
}

-- Grudges: my grudges, the guild bounty board and the rivalry map ----------------------------

local function Who(level, class, guild)
    local bits = {}
    if level and level > 0 then bits[#bits + 1] = "level " .. level end
    if class and class ~= "" then bits[#bits + 1] = class end
    if guild then bits[#bits + 1] = "<" .. guild .. ">" end
    return table.concat(bits, " ")
end

-- "last seen in Tarren Mill, 5 minutes ago (Bob)" from a grudge or bounty record.
local function SeenText(record)
    local where, t, by = ns.LastSeen(record)
    if not where then return nil end
    local when = t and (time() - t < 86400 and U.Ago(t) or date("%d %b", t)) or ""
    local who = by and by ~= "" and Short(by) ~= UnitName("player") and (" by " .. Short(by)) or ""
    return ("last seen in %s, %s%s"):format(where, when, who), by ~= nil and t ~= nil and time() - t < 1800
end

local function MyGrudges()
    local list = ns.SortedGrudges()
    if #list == 0 then return Empty("Nobody's ganked you yet. When they do, they'll be written down here.") end
    local open, settled = {}, {}
    for _, item in ipairs(list) do
        local g = item.g
        local ours, theirs = ns.GrudgeScore(g)
        local who = Who(g.level, g.class, g.guild)
        local isOpen = ns.GrudgeOpen(g)
        local reward = ns.MyReward(item.name)
        if reward > 0 then who = who .. (who ~= "" and " · " or "") .. ("|cffdeb24d%dg reward|r"):format(reward) end
        local row = {
            text = Short(item.name), colour = isOpen and ClassColour(g.classFile) or C.muted, dot = ClassColour(g.classFile),
            sub = ("%s%s%s%s"):format(who, who ~= "" and " · " or "", (SeenText(g) or "never seen since"),
                g.exact and "" or " · best guess"),
            right = ("%d – %d"):format(ours, theirs), card = isOpen or nil,
            onClick = function() ns.ShowPoster(item.name) end,
            tip = { title = Short(item.name), lines = {
                who ~= "" and who or nil,
                ("Killed you %s, first on %s"):format(Plural(g.kills, "time"), date("%d %B", g.first)),
                ("Your revenge: %d%s"):format(g.revenge, (g.avenged or 0) > 0 and (" · avenged by your guild: %d"):format(g.avenged) or ""),
                g.exact and "Seen in the combat log" or "Best guess: they were targeting you when you died",
                isOpen and "Click to make a wanted poster" or "Click to see their poster",
            } },
        }
        table.insert(isOpen and open or settled, row)
    end
    local items = { { type = "header", text = "Unfinished business", right = "you – them" } }
    for _, row in ipairs(open) do items[#items + 1] = row end
    if #open == 0 then items[#items + 1] = { type = "empty", text = "All scores settled. For now." } end
    if #settled > 0 then
        items[#items + 1] = { type = "gap", size = 8 }
        items[#items + 1] = { type = "header", text = "Settled", right = "you – them" }
        for _, row in ipairs(settled) do items[#items + 1] = row end
    end
    return items
end

local function Bounties()
    local board = ns.BountyBoard()
    if not IsInGuild() then return Empty("Join a guild to share a bounty board. Guildies running Forever Told see each other's grudges.") end
    if #board == 0 and #ns.DB.debts == 0 then return Empty("The board is empty. When you or a guildie get ganked, the killer is posted here.") end
    local items = {}
    local debts = ns.DB.debts
    if #debts > 0 then
        items[#items + 1] = { type = "header", text = "Rewards you owe", right = "click when paid" }
        for i, d in ipairs(debts) do
            items[#items + 1] = { text = ("%d gold to %s"):format(d.gold, Short(d.to)), colour = C.accent, dot = C.accent, card = true,
                sub = ("for taking down %s, %s"):format(Short(d.name), U.Ago(d.t)), right = "mark paid",
                onClick = function() ns.MarkPaid(i) ns.Refresh() end,
                tip = { title = "Pay the hunter", lines = { "Trade or mail the gold, then click here.", ("%s gets a thank-you in their journal."):format(Short(d.to)) } } }
        end
        items[#items + 1] = { type = "gap", size = 8 }
    end
    items[#items + 1] = { type = "header", text = "Wanted by your guild", right = "kills · reward" }
    for _, b in ipairs(board) do
        local posters = {}
        for poster, p in pairs(b.posters) do posters[#posters + 1] = p.mine and "you" or Short(poster) end
        table.sort(posters)
        local claim = b.claim and ("last taken down by %s %s"):format(Short(b.claim.by or "?"), U.Ago(b.claim.t)) or nil
        local who = Who(b.level, b.class)
        local seen, fresh = SeenText(b)
        if seen and fresh then seen = "|cffeb5c4d" .. seen .. "|r" end
        items[#items + 1] = {
            text = Short(b.name), colour = ClassColour(b.classFile), dot = ClassColour(b.classFile), card = true,
            sub = ("Wanted by %s%s%s"):format(table.concat(posters, ", "), who ~= "" and (" · " .. who) or "",
                seen and (" · " .. seen) or ""),
            right = b.reward > 0 and ("%d · %dg"):format(b.kills, b.reward) or tostring(b.kills),
            onClick = function() ns.ShowPoster(b.name) end,
            tip = { title = Short(b.name), lines = { who ~= "" and who or nil,
                "Posted by " .. table.concat(posters, ", "), claim,
                b.reward > 0 and ("Reward: %d gold"):format(b.reward) or nil,
                "Kill them and everyone who posted gets their revenge.", "Click to open the poster" } },
        }
    end
    items[#items + 1] = { type = "gap", size = 6 }
    items[#items + 1] = { type = "empty", text = ns.DB.shareBounties and "Your open grudges are shared with your guild. Turn this off in Settings."
        or "You're not sharing your grudges. Turn it on in Settings." }
    return items
end

local function Rivals()
    local DB = ns.DB
    local zones, most = {}, 1
    for zone, z in pairs(DB.gankZones) do
        if z.kills + z.revenge > 0 then
            zones[#zones + 1] = { zone = zone, kills = z.kills, revenge = z.revenge }
            most = math.max(most, z.kills, z.revenge)
        end
    end
    if #zones == 0 then return Empty("No PvP yet. Once the fighting starts, this shows where and when it happens.") end
    table.sort(zones, function(a, b) return a.kills > b.kills end)
    local kills, ours = GrudgeTotals()
    local worst = zones[1]
    local items = {
        { type = "tiles", tiles = {
            { label = "Ganked", value = tostring(kills), colour = RED },
            { label = "Revenge (with guild)", value = tostring(ours), colour = C.accent },
            { label = "Deadliest zone", value = worst.zone },
        } },
        { type = "header", text = "Where you get ganked", right = "ganked · revenge" },
    }
    for _, z in ipairs(zones) do
        items[#items + 1] = { type = "bar", label = z.zone, labelWidth = 150, valueWidth = 80, height = 24, colour = RED,
            fraction = z.kills / most, value = ("%d · %d"):format(z.kills, z.revenge),
            tip = { title = z.zone, lines = { ("Ganked here %s"):format(Plural(z.kills, "time")), ("Revenge taken here %s"):format(Plural(z.revenge, "time")) } } }
    end
    -- When: three-hour blocks of the day.
    local blocks, top = {}, 0
    for b = 0, 7 do
        local n = 0
        for h = b * 3, b * 3 + 2 do n = n + (DB.gankHours[h] or 0) end
        blocks[b] = n
        top = math.max(top, n)
    end
    if top > 0 then
        items[#items + 1] = { type = "gap" }
        items[#items + 1] = { type = "header", text = "When it happens", right = "your local time" }
        for b = 0, 7 do
            items[#items + 1] = { type = "bar", label = ("%02d:00–%02d:00"):format(b * 3, b * 3 + 3), labelWidth = 150, valueWidth = 80,
                fraction = blocks[b] / top, value = Plural(blocks[b], "gank"), colour = blocks[b] == top and RED or { 1, 1, 1, 0.35 } }
        end
    end
    return items
end

PAGES.grudges = {
    title = "Grudges", icon = "Interface\\Icons\\Ability_Rogue_Ambush",
    subtitle = function()
        local kills, ours = GrudgeTotals()
        return ("Killed %s by other players · %d avenged"):format(Plural(kills, "time"), ours)
    end,
    badge = function() local n = OpenGrudges() return n > 0 and tostring(n) or nil, true end,
    build = function(p)
        p.segments = S.Segments(p, {
            { id = "mine", label = "My grudges" }, { id = "bounties", label = "Guild bounties" },
            { id = "wall", label = "Poster wall" }, { id = "rivals", label = "Rivalry map" },
        }, function() return view.grudges end, function(id) view.grudges = id ns.Refresh() end, 110)
        p.segments:SetPoint("TOPLEFT", 0, 0)
        p.list:ClearAllPoints()
        p.list:SetPoint("TOPLEFT", 0, -38)
        p.list:SetPoint("BOTTOMRIGHT")
        p.wall = ns.CreatePosterWall(p)
        p.wall:SetPoint("TOPLEFT", 0, -38)
        p.wall:SetPoint("BOTTOMRIGHT")
        p.wall:Hide()
    end,
    open = function(p, sub) if sub then view.grudges = sub end p.segments:Sync() end,
    -- The poster wall replaces the list; everything else is list rows.
    update = function(p)
        local onWall = view.grudges == "wall"
        p.wall:SetShown(onWall)
        p.list:SetShown(not onWall)
        if onWall then p.wall:Update() return true end
    end,
    items = function()
        if view.grudges == "bounties" then return Bounties() end
        if view.grudges == "rivals" then return Rivals() end
        return MyGrudges()
    end,
}

-- Atlas --------------------------------------------------------------------------------

PAGES.atlas = {
    title = "Atlas", icon = "Interface\\Icons\\INV_Misc_Map_01",
    subtitle = function() return Plural(Count(ns.DB.zones), "place") .. " discovered" end,
    badge = function() local n = Count(ns.DB.zones) return n > 0 and tostring(n) or nil end,
    items = function()
        local DB = ns.DB
        local groups, order = {}, {}
        for zone, info in pairs(DB.zones) do
            local key = info.instance and "Dungeons and raids" or (info.continent or "Elsewhere")
            if not groups[key] then groups[key] = {} order[#order + 1] = key end
            table.insert(groups[key], { zone = zone, t = info.t or 0, lvl = info.lvl })
        end
        table.sort(order, function(a, b)
            if a == "Dungeons and raids" then return false end
            if b == "Dungeons and raids" then return true end
            return a < b
        end)
        local items = {}
        for _, key in ipairs(order) do
            local list = groups[key]
            table.sort(list, function(a, b) return a.t < b.t end)
            items[#items + 1] = { type = "header", text = key, right = tostring(#list) }
            for _, z in ipairs(list) do
                local gank = DB.gankZones[z.zone]
                local danger = gank and gank.kills > 0 and ("|cffeb5c4dganked %d×|r · "):format(gank.kills) or ""
                items[#items + 1] = { text = z.zone, dot = key == "Dungeons and raids" and Hex("7fb2ff") or Hex("8fd18f"),
                    right = danger .. (z.lvl and ("Lv %d · "):format(z.lvl) or "") .. (z.t > 0 and date("%d %b", z.t) or "") }
            end
            items[#items + 1] = { type = "gap", size = 8 }
        end
        if Count(DB.bosses) > 0 then
            local bosses = {}
            for _, b in pairs(DB.bosses) do bosses[#bosses + 1] = b end
            table.sort(bosses, function(a, b) return (a.t or 0) < (b.t or 0) end)
            items[#items + 1] = { type = "header", text = "Bosses defeated", right = tostring(#bosses) }
            for _, b in ipairs(bosses) do
                items[#items + 1] = { text = b.name or "?", colour = Hex("ff9a62"), dot = Hex("ff9a62"),
                    right = ("%s · %s"):format(b.zone or "", date("%d %b", b.t or 0)) }
            end
        end
        if #items == 0 then return Empty("Nowhere yet. Step outside!") end
        return items
    end,
}

-- Stats --------------------------------------------------------------------------------

PAGES.stats = {
    title = "Stats", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    subtitle = function()
        local start = ns.DB.entries[1] and ns.DB.entries[1].t
        return start and ("On the road since %s"):format(date("%d %B %Y", start)) or ""
    end,
    items = function()
        local DB = ns.DB
        local played = ns.PlayedNow() or DB.lastPlayed
        local items = {
            { type = "tiles", tiles = {
                { label = "Time played", value = played and Duration(played) or "–" },
                { label = "Quests", value = tostring(DB.quests) },
                { label = "Places", value = tostring(Count(DB.zones)) },
                { label = "Deaths", value = tostring(DB.deaths), colour = RED },
            } },
        }
        local function stat(label, value) items[#items + 1] = { type = "stat", label = label, value = tostring(value) } end

        items[#items + 1] = { type = "header", text = "The adventurer" }
        local race = UnitRace and UnitRace("player") or ""
        stat("Character", ("%s, level %d %s %s"):format(UnitName("player"), UnitLevel("player"), race, (UnitClass("player"))))
        local total, n, fastest, slowest = 0, 0, nil, nil
        for lvl, sec in pairs(DB.levelTimes) do
            total, n = total + sec, n + 1
            if not fastest or sec < DB.levelTimes[fastest] then fastest = lvl end
            if not slowest or sec > DB.levelTimes[slowest] then slowest = lvl end
        end
        if n > 0 then
            stat("Average level", Duration(total / n))
            stat("Fastest level", ("%d to %d in %s"):format(fastest, fastest + 1, Duration(DB.levelTimes[fastest])))
            stat("Slowest level", ("%d to %d in %s"):format(slowest, slowest + 1, Duration(DB.levelTimes[slowest])))
        elseif not played then
            stat("Time per level", "log in again to start measuring")
        end

        items[#items + 1] = { type = "gap" }
        items[#items + 1] = { type = "header", text = "The journey" }
        local dungeons = 0
        for _, z in pairs(DB.zones) do if z.instance then dungeons = dungeons + 1 end end
        stat("Dungeons and raids", dungeons)
        stat("Bosses defeated", Count(DB.bosses))
        stat("Friends made", Count(DB.fellows))
        stat("Deeds earned", ("%d of %d"):format(Count(DB.deeds), #ns.DEEDS))
        stat("Profession milestones", Count(DB.skills))
        stat(DB.lootQuality == 3 and "Rare and epic finds" or "Epic finds", DB.epics)
        stat("Most gold held", U.Money(DB.goldPeak))
        local worst, worstN = nil, 0
        for zone, c in pairs(DB.deathZones) do if c > worstN then worst, worstN = zone, c end end
        if worst then stat("Deadliest zone", ("%s (%d deaths)"):format(worst, worstN)) end
        local kills, ours = GrudgeTotals()
        stat("Ganked / avenged", ("%d / %d"):format(kills, ours))
        stat("Bounties collected", DB.counters.bounties or 0)
        stat("Screenshots taken", DB.shots)

        items[#items + 1] = { type = "gap" }
        items[#items + 1] = { type = "header", text = "Chapters" }
        local currentC = ns.ChapterOf(UnitLevel("player"))
        for c = 0, currentC do
            local parts, sec, partial = ns.RecapParts(c)
            local right = c == currentC and "so far" or (sec and Duration(sec) or "")
            if partial then right = right .. " · partly recorded" end
            items[#items + 1] = { text = (ChapterTitle(c)), colour = C.accent, card = true, right = right,
                sub = DB.chapterStats[c] and table.concat(parts, ", ") or "not recorded (before version 0.3)" }
        end

        if n > 0 then
            items[#items + 1] = { type = "gap" }
            items[#items + 1] = { type = "header", text = "Time per level" }
            local levels, longest = {}, 1
            for lvl, sec in pairs(DB.levelTimes) do levels[#levels + 1] = lvl if sec > longest then longest = sec end end
            table.sort(levels)
            for _, lvl in ipairs(levels) do
                local sec = DB.levelTimes[lvl]
                items[#items + 1] = { type = "bar", label = "Lv " .. lvl, value = Duration(sec), fraction = sec / longest }
            end
        end
        return items
    end,
}

-- Settings -----------------------------------------------------------------------------

PAGES.settings = {
    title = "Settings", icon = "Interface\\Icons\\INV_Misc_Gear_01", noList = true, noSearch = true,
    subtitle = function() return "Choose what Forever Told does for you." end,
    build = function(p)
        local scroll = S.Scroll(p)
        scroll:SetAllPoints()
        local body = scroll.child
        local y = 0
        local controls = {}
        local function Header(text)
            local h = S.Text(body, 13, C.accent, S.TITLE)
            h:SetPoint("TOPLEFT", 0, -(y + (y > 0 and 14 or 0)))
            h:SetText(text)
            local line = body:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(unpack(C.line))
            line:SetHeight(1)
            line:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
            line:SetWidth(520)
            y = y + (y > 0 and 14 or 0) + 30
        end
        for _, s in ipairs(ns.SETTINGS) do
            if s.section then
                Header(s.section)
            else
                local t = S.Toggle(body, s.label, function() return ns.GetSetting(s) end, function(v) ns.SetSetting(s, v) end)
                t:SetPoint("TOPLEFT", 0, -y)
                controls[#controls + 1] = t
                y = y + 34
            end
        end
        Header("Window")
        local scale = S.Segments(body, {
            { id = 0.9, label = "90%" }, { id = 1, label = "100%" }, { id = 1.1, label = "110%" }, { id = 1.25, label = "125%" },
        }, function() return ns.DB.window.scale or 1 end, function(v) ns.SetWindowScale(v) end, 64)
        scale:SetPoint("TOPLEFT", 0, -y)
        controls[#controls + 1] = scale
        local label = S.Text(body, 13, C.text)
        label:SetPoint("LEFT", scale, "RIGHT", 12, 0)
        label:SetText("Window size")
        y = y + 40
        local tip = S.Text(body, 11, C.muted)
        tip:SetPoint("TOPLEFT", 0, -y)
        tip:SetWidth(520)
        tip:SetText("Drag the window by its title, and resize it from the bottom-right corner. Drag the book on your minimap to move it; right-click it to jump to your stats.")
        y = y + 40
        local credit = S.Text(body, 11, C.muted)
        credit:SetPoint("TOPLEFT", 0, -y)
        credit:SetText("Forever Told · Author: SMUGDUCK")
        y = y + 24
        p.Update = function()
            scroll:SetContentHeight(y)
            for _, c in ipairs(controls) do c:Sync() end
        end
    end,
}

function ns.HasPage(name) return PAGES[name] ~= nil or ns.PAGE_ALIASES[name] ~= nil end
