-- Journal page: every entry, chapter by chapter.

local _, ns = ...
local U, S, K = ns.U, ns.Skin, ns.PageKit
local C = S.colours
local Plural, Hex = U.Plural, U.Hex
local view, Chapter, ChapterTitle, Empty = K.view, K.Chapter, K.ChapterTitle, K.Empty

ns.Pages.journal = {
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
        local e = DB.epitaph
        if e then
            items[#items + 1] = { text = "In memoriam", colour = { 0.86, 0.84, 0.78, 1 }, dot = { 0.72, 0.72, 0.75, 1 }, card = true,
                sub = ("Fell at level %d in %s, %s"):format(e.lvl or 0, e.zone or "?", date("%d %B %Y", e.t)),
                right = "view stone", onClick = function() ns.ShowEpitaph() end }
            items[#items + 1] = { type = "gap", size = 8 }
        end
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
