-- Guild Chronicle page: the guild's big moments in one feed, grouped by day.

local _, ns = ...
local U, S, K = ns.U, ns.Skin, ns.PageKit
local C = S.colours
local Plural, Short, ClassColour, Duration = U.Plural, U.Short, U.ClassColour, U.Duration
local view, RED, Empty = K.view, K.RED, K.Empty

local WEEK = 7 * 86400
local SEGMENTS = {
    { id = "all", label = "Everything" }, { id = "level", label = "Levels" }, { id = "loot", label = "Loot" },
    { id = "dungeon", label = "Dungeons" }, { id = "deed", label = "Deeds" },
}
view.chronicle = "all"

local function IsMe(name) return Short(name or "") == UnitName("player") end

-- "Bob and you", "Bob, Hilda and Grim"
local function People(csv)
    local names = {}
    for name in (csv or ""):gmatch("[^,]+") do
        names[#names + 1] = IsMe(name) and "you" or Short(name)
    end
    table.sort(names, function(a, b)
        if a == "you" or b == "you" then return b == "you" and a ~= "you" end
        return a < b
    end)
    if #names <= 1 then return names[1] end
    return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
end

-- What happened, as the rest of a sentence after the name.
local function Told(e)
    if e.kind == "level" then
        local level = tonumber(e.a) or e.lvl or 0
        if level >= 60 then
            local played, quests, places = (e.c or ""):match("^(%d+),(%d+),(%d+)$")
            local sub = played and ("%s played · %s · %s"):format(Duration(tonumber(played)), Plural(tonumber(quests), "quest"),
                Plural(tonumber(places), "place")) or nil
            return "reached level 60! The journey is complete.", sub
        end
        return ("reached level %d%s."):format(level, e.b and (" in " .. e.b) or "")
    elseif e.kind == "loot" then
        return ("looted %s%s."):format(e.a or "something shiny", e.b and (" in " .. e.b) or "")
    elseif e.kind == "dungeon" then
        local with = People(e.c)
        local bosses = tonumber(e.b) or 0
        return ("ran %s for the first time%s."):format(e.a or "a dungeon", with and (", with " .. with) or ""),
            bosses > 0 and Plural(bosses, "boss", "bosses") .. " felled" or nil
    elseif e.kind == "deed" then
        return ("earned the deed |cffdeb24d%s|r%s"):format(e.a or "?", e.b and (": " .. e.b:gsub("^%u", string.lower)) or ".")
    elseif e.kind == "epitaph" then
        return ("fell at level %s in %s. Rest well."):format(e.a or "?", e.b or "somewhere unknown"),
            "Hardcore" .. (e.c and (" · to " .. e.c) or "")
    end
end

local function When(t)
    local age = time() - t
    if age < 86400 and date("%x", t) == date("%x") then return U.Ago(t) end
    if date("%x", t) == date("%x", time() - 86400) then return "yesterday" end
    return date("%H:%M", t)
end

local function DayTitle(t)
    if date("%x", t) == date("%x") then return "Today" end
    if date("%x", t) == date("%x", time() - 86400) then return "Yesterday" end
    return date("%A", t)
end

local function Tiles(list)
    local authors, sixty, week = {}, {}, 0
    for _, e in ipairs(list) do
        local who = Short(e.who)
        authors[who] = true
        if (e.lvl or 0) >= 60 or (e.kind == "level" and tonumber(e.a) == 60) then sixty[who] = true end
        if time() - e.t < WEEK then week = week + 1 end
    end
    return { type = "tiles", tiles = {
        { label = "Guildies keeping a journal", value = tostring(U.Count(authors)) },
        { label = "At level 60", value = tostring(U.Count(sixty)), colour = C.accent },
        { label = "Milestones this week", value = tostring(week) },
    } }
end

ns.Pages.chronicle = {
    title = "Chronicle", icon = "Interface\\Icons\\INV_Scroll_03",
    subtitle = function()
        local guild = IsInGuild() and GetGuildInfo("player")
        return guild and ("<%s> · the guild's story so far"):format(guild) or "The guild's story so far"
    end,
    badge = function()
        local n = 0
        for _, e in ipairs(ns.DB.chronicle) do
            if time() - e.t < 86400 and not IsMe(e.who) then n = n + 1 end
        end
        return n > 0 and tostring(n) or nil
    end,
    build = function(p)
        p.segments = S.Segments(p, SEGMENTS, function() return view.chronicle end,
            function(id) view.chronicle = id ns.Refresh() end, 92)
        p.segments:SetPoint("TOPLEFT", 0, 0)
        p.list:ClearAllPoints()
        p.list:SetPoint("TOPLEFT", 0, -38)
        p.list:SetPoint("BOTTOMRIGHT")
    end,
    open = function(p) p.segments:Sync() end,
    items = function()
        local list = ns.DB.chronicle
        if not IsInGuild() and #list == 0 then
            return Empty("Join a guild to read its chronicle. Guildies running Forever Told share their big moments here: every 10th level, epic loot, first dungeon runs, deeds and Hardcore deaths.")
        end
        local items = { Tiles(list) }
        local day, shown = nil, 0
        for i = #list, 1, -1 do
            local e = list[i]
            local kind = e.kind == "epitaph" and "level" or e.kind
            if view.chronicle == "all" or view.chronicle == kind then
                local text, sub = Told(e)
                if text then
                    local d = date("%x", e.t)
                    if d ~= day then
                        day = d
                        if shown > 0 then items[#items + 1] = { type = "gap", size = 6 } end
                        items[#items + 1] = { type = "header", text = DayTitle(e.t), right = date("%a %d %b", e.t) }
                    end
                    local me = IsMe(e.who)
                    local colour = ClassColour(e.classFile)
                    local name = me and "You" or Short(e.who)
                    items[#items + 1] = {
                        text = ("|cff%02x%02x%02x%s|r %s"):format(math.floor(colour[1] * 255), math.floor(colour[2] * 255), math.floor(colour[3] * 255), name, text),
                        sub = sub, right = When(e.t), dot = e.kind == "epitaph" and RED or colour,
                        card = (e.kind == "epitaph" or (e.kind == "level" and tonumber(e.a) == 60)) or nil,
                        search = name,
                    }
                    shown = shown + 1
                end
            end
        end
        if shown == 0 then
            items[#items + 1] = { type = "empty", text = view.chronicle == "all"
                and "Nothing yet. When a guildie running Forever Told levels up, finds an epic or runs a new dungeon, it shows up here."
                or "Nothing of this kind in the last 30 days." }
        end
        items[#items + 1] = { type = "gap", size = 6 }
        items[#items + 1] = { type = "empty", text = ns.DB.shareChronicle and "Your milestones are shared with your guild. Turn this off in Settings."
            or "You're not sharing your milestones. Turn it on in Settings." }
        return items
    end,
}
