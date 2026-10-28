-- Stats page: tiles, the journey in numbers, chapters and time per level.

local _, ns = ...
local U, S, K = ns.U, ns.Skin, ns.PageKit
local C = S.colours
local Count, Duration = U.Count, U.Duration
local RED, ChapterTitle, GrudgeTotals = K.RED, K.ChapterTitle, K.GrudgeTotals

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
