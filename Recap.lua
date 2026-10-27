-- Forever Told chapter recaps: when you reach level 10, 20, 30 and so on,
-- the chapter you just finished is summed up in one line and on a card.

local _, ns = ...

local Plural = ns.U.Plural

-- Seconds spent on the levels inside chapter c, from the time-per-level log.
local function ChapterTime(c)
    local total, known = 0, 0
    for lvl = math.max(1, c * 10), c * 10 + 9 do
        local sec = ns.DB.levelTimes[lvl]
        if sec then total, known = total + sec, known + 1 end
    end
    return known > 0 and total or nil
end

function ns.RecapParts(c)
    local s = ns.DB.chapterStats[c] or {}
    local parts = {}
    local function add(n, one, many) if (n or 0) > 0 then parts[#parts + 1] = Plural(n, one, many) end end
    add(s.places, "new place", "new places")
    add(s.quests, "quest", "quests")
    add(s.runs, "dungeon run", "dungeon runs")
    add(s.bosses, "new boss", "new bosses")
    add(s.loot, "epic", "epics")
    add(s.fellows, "new friend", "new friends")
    add(s.deeds, "deed", "deeds")
    parts[#parts + 1] = (s.deaths or 0) == 0 and "no deaths" or Plural(s.deaths, "death", "deaths")
    return parts, ChapterTime(c), s.partial
end

function ns.WriteRecap(c, level)
    local DB = ns.DB
    if DB.recaps[c] then return end
    local parts, sec, partial = ns.RecapParts(c)
    local title = ns.CHAPTERS[c] or ""
    local text = ("Chapter %d recap, %s: %s"):format(c + 1, title, table.concat(parts, ", "))
    if sec then text = text .. (", %s played"):format(ns.U.Duration(sec)) end
    text = text .. "."
    if partial then text = text .. " (Counted from when you installed version 0.3.)" end
    DB.recaps[c] = { t = time(), text = text }
    ns.Add("recap", text, level)
    if ns.ShowRecapCard and DB.banner then ns.ShowRecapCard(c, parts, sec) end
end
