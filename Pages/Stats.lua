-- Stats page: tiles, deadliest foes and foes slain, the journey in numbers,
-- chapters and time per level.

local _, ns = ...
local U, S, K = ns.U, ns.Skin, ns.PageKit
local C = S.colours
local Count, Duration, Plural, Number = U.Count, U.Duration, U.Plural, U.Number
local RED, ChapterTitle, GrudgeTotals = K.RED, K.ChapterTitle, K.GrudgeTotals

local CLASSIFICATION = { elite = "elite", rareelite = "rare elite", rare = "rare", worldboss = "boss" }
local TOP = 5

local function FoeName(e)
    if e.f.player then return e.name .. " |cff8a8a8a(player)|r" end
    return e.name
end

-- Where a foe got us: "all in Westfall" or "most often in Duskwood".
local function WhereDied(f)
    local best, most, places = nil, 0, 0
    for zone, n in pairs(f.diedIn or {}) do
        places = places + 1
        if n > most then best, most = zone, n end
    end
    if not best then return nil end
    if places == 1 then return (f.deaths > 1 and "all in " or "in ") .. best end
    return "most often in " .. best
end

local function Foes(items, stat)
    local DB = ns.DB
    local deadly, slain = ns.DeadliestFoes(), ns.SlainFoes()
    if #deadly > 0 then
        items[#items + 1] = { type = "header", text = "Deadliest foes", right = "deaths" }
        local top = deadly[1].n
        for i = 1, math.min(TOP, #deadly) do
            local e = deadly[i]
            local lines = { ("Killed you %s"):format(Plural(e.n, "time")), WhereDied(e.f) }
            if e.f.kills > 0 then lines[#lines + 1] = ("You've slain %s of them"):format(Number(e.f.kills)) end
            if not e.f.exact and not e.f.env then lines[#lines + 1] = "Best guess: it was targeting you when you died" end
            items[#items + 1] = { type = "bar", label = FoeName(e), labelWidth = 170, valueWidth = 60, height = 24, colour = RED,
                fraction = e.n / top, value = tostring(e.n), tip = { title = e.name, lines = lines } }
        end
        -- A nemesis is a clear top killer, and something with a will of its own.
        local foes = {}
        for _, e in ipairs(deadly) do if not e.f.env then foes[#foes + 1] = e end end
        local n = foes[1]
        if n and n.n >= 2 and (not foes[2] or foes[2].n < n.n) then
            local sub = ("Killed you %s%s."):format(Plural(n.n, "time"), WhereDied(n.f) and (", " .. WhereDied(n.f)) or "")
            if n.f.kills > 0 then sub = sub .. (" You've slain %s of them."):format(Number(n.f.kills)) end
            items[#items + 1] = { type = "gap", size = 4 }
            items[#items + 1] = { text = (n.f.player and "Your nemesis: " or "Nemesis of the wilds: ") .. n.name, colour = RED, dot = RED, card = true, sub = sub }
        end
        items[#items + 1] = { type = "gap" }
    end
    if #slain > 0 then
        items[#items + 1] = { type = "header", text = "Foes slain the most", right = "kills" }
        local top = slain[1].n
        for i = 1, math.min(TOP, #slain) do
            local e = slain[i]
            local best, most = nil, 0
            for zone, k in pairs(e.f.zones) do if k > most then best, most = zone, k end end
            items[#items + 1] = { type = "bar", label = e.name, labelWidth = 170, valueWidth = 60, height = 24,
                fraction = e.n / top, value = Number(e.n),
                tip = { title = e.name, lines = { ("Slain %s"):format(Plural(e.n, "time")), best and ("Mostly in " .. best) or nil,
                    e.f.deaths > 0 and ("Killed you %s"):format(Plural(e.f.deaths, "time")) or nil } } }
        end
        items[#items + 1] = { type = "gap" }
        items[#items + 1] = { type = "header", text = "The hunt" }
        local kills, kinds = ns.FoeTotals()
        stat("Foes slain", Number(kills))
        stat("Different kinds", Number(kinds))
        local t = DB.toughest
        if t then
            stat("Toughest kill", ("%s, level %d%s"):format(t.name, t.level, t.class and (" " .. (CLASSIFICATION[t.class] or t.class)) or ""))
        end
        items[#items + 1] = { type = "gap" }
    end
end

ns.Pages.stats = {
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
                { label = "Foes slain", value = Number((ns.FoeTotals())) },
                { label = "Deaths", value = tostring(DB.deaths), colour = RED },
            } },
        }
        local function stat(label, value) items[#items + 1] = { type = "stat", label = label, value = tostring(value) } end
        Foes(items, stat)

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
