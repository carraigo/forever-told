-- Forever Told pages. Each page gives the window a title, a subtitle, an
-- optional badge for the sidebar, controls (build) and list rows (items).
-- The window itself lives in UI\Window.lua; each page has its own file here.
-- This file holds what the pages share.

local _, ns = ...

local PAGES = {}
ns.Pages = PAGES
ns.PAGE_ORDER = { "journal", "fellowship", "deeds", "grudges", "atlas", "stats", "settings" }
-- Extra slash names that open a page on a particular view.
ns.PAGE_ALIASES = { bounties = { "grudges", "bounties" }, bounty = { "grudges", "bounties" }, rivals = { "grudges", "rivals" },
    wanted = { "grudges", "wall" }, posters = { "grudges", "wall" } }

function ns.HasPage(name) return PAGES[name] ~= nil or ns.PAGE_ALIASES[name] ~= nil end

local K = {}
ns.PageKit = K

K.view = { filter = "all", newestFirst = true, grudges = "mine" }
ns.PageView = K.view

K.RED = { 0.92, 0.36, 0.30, 1 }

function K.Chapter(level)
    local c = ns.ChapterOf(level or 1)
    return c, ns.CHAPTERS[c]
end

function K.ChapterTitle(c)
    if c >= 6 then return "Chapter 7 · " .. ns.CHAPTERS[6], "level 60" end
    return ("Chapter %d · %s"):format(c + 1, ns.CHAPTERS[c]), ("levels %d to %d"):format(math.max(1, c * 10), c * 10 + 9)
end
ns.ChapterTitle = K.ChapterTitle

function K.Empty(text) return { { type = "empty", text = text } } end

function K.GrudgeTotals()
    local kills, ours = 0, 0
    for _, g in pairs(ns.DB.grudges) do
        local o, t = ns.GrudgeScore(g)
        kills, ours = kills + t, ours + o
    end
    return kills, ours
end

function K.OpenGrudges()
    local n = 0
    for _, g in pairs(ns.DB.grudges) do if ns.GrudgeOpen(g) then n = n + 1 end end
    return n
end
