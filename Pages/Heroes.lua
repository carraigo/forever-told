-- Hall of Heroes page: every character on this account with a story, and
-- the stones of the Hardcore characters who fell.

local _, ns = ...
local U, K = ns.U, ns.PageKit
local Plural, ClassColour, Duration = U.Plural, U.ClassColour, U.Duration
local RED, ChapterTitle = K.RED, K.ChapterTitle

local PER_ROW = 3

local function Played(list)
    local total = 0
    for _, e in ipairs(list) do total = total + (e.h.played or 0) end
    return total
end

local function LastPlayed(h, me)
    if me then return "now" end
    local age = time() - (h.t or 0)
    if age < 86400 then return "today" end
    if age < 2 * 86400 then return "yesterday" end
    if age < 14 * 86400 then return math.floor(age / 86400) .. " days ago" end
    if age < 60 * 86400 then return math.floor(age / (7 * 86400)) .. " weeks ago" end
    return date("%d %b %Y", h.t)
end

local function Living(e, me)
    local h = e.h
    local colour = ClassColour(h.classFile)
    local chapter = ChapterTitle(ns.ChapterOf(h.level or 1)):gsub("^Chapter (%d+) · ", "Chapter %1, ")
    local bits = { ("%s %s"):format(h.race or "", h.class or ""):gsub("^ ", ""), chapter, h.zone,
        ("%s, %s"):format(Plural(h.quests or 0, "quest"), Plural(h.deeds or 0, "deed")) }
    local realm = h.realm and h.realm ~= GetRealmName() and (" · " .. h.realm) or ""
    return {
        text = (h.name or "?") .. (me and " |cff8a8a8a(you)|r" or ""), colour = colour, dot = colour, card = me or nil,
        sub = table.concat(bits, " · ") .. realm,
        right = ("%d · %s"):format(h.level or 0, LastPlayed(h, me)),
        search = h.name,
        onClick = not me and function()
            if IsShiftKeyDown() then
                ns.ForgetHero(e.key)
                ns.Refresh()
            end
        end or nil,
        tip = { title = h.name, lines = {
            ("Level %d %s"):format(h.level or 0, h.class or ""),
            h.played and ("Played for " .. Duration(h.played)) or nil,
            h.began and ("Set out on " .. date("%d %B %Y", h.began)) or nil,
            Plural(h.places or 0, "place") .. " discovered",
            not me and "Shift-click to remove from the hall" or nil,
        } },
    }
end

local function Stone(e)
    local h, ep = e.h, e.h.epitaph
    return {
        name = (ep.name or h.name or "?"):upper(),
        who = ("Level %d %s%s"):format(ep.lvl or 0, ep.race and (ep.race .. " ") or "", ep.class or ""),
        fell = ("Fell in %s%s"):format(ep.zone or "somewhere unknown", ep.cause and ("\nto " .. ep.cause) or ""),
        date = date("%d %B %Y", ep.t or 0),
        onClick = function() ns.ShowEpitaph(ep) end,
        tip = { title = h.name, lines = { "Click to read the full stone" } },
    }
end

ns.Pages.heroes = {
    title = "Hall of Heroes", icon = "Interface\\Icons\\Ability_Warrior_RallyingCry",
    subtitle = function() return "Every character you've written a story for" end,
    badge = function() local n = #ns.Heroes() return n > 1 and tostring(n) or nil end,
    items = function()
        ns.SaveHero()
        local list = ns.Heroes()
        local me = ns.HeroKey()
        local living, fallen, levels = {}, {}, 0
        for _, e in ipairs(list) do
            levels = levels + math.max(0, (e.h.level or 1) - 1)
            if e.h.epitaph then fallen[#fallen + 1] = e else living[#living + 1] = e end
        end
        local played = Played(list)
        local items = { { type = "tiles", tiles = {
            { label = "Characters", value = tostring(#list) },
            { label = "Levels gained", value = tostring(levels) },
            { label = "Played, all together", value = played > 0 and Duration(played) or "–" },
            { label = "Fallen", value = tostring(#fallen), colour = #fallen > 0 and RED or nil },
        } } }
        if #living > 0 then
            items[#items + 1] = { type = "header", text = "Still on the road", right = "level · last played" }
            for _, e in ipairs(living) do items[#items + 1] = Living(e, e.key == me) end
        end
        if #fallen > 0 then
            items[#items + 1] = { type = "gap" }
            items[#items + 1] = { type = "header", text = "The fallen", right = "click a stone for the full epitaph" }
            for i = 1, #fallen, PER_ROW do
                local row = {}
                for j = i, math.min(i + PER_ROW - 1, #fallen) do row[#row + 1] = Stone(fallen[j]) end
                items[#items + 1] = { type = "stones", stones = row }
            end
        end
        if #list == 1 then
            items[#items + 1] = { type = "gap", size = 6 }
            items[#items + 1] = { type = "empty", text = "Your other characters join the hall the next time you log in on them." }
        end
        return items
    end,
}
