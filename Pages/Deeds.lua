-- Deeds page: badges earned and still to earn.

local _, ns = ...
local U, S, K = ns.U, ns.Skin, ns.PageKit
local C = S.colours
local Count, Hex = U.Count, U.Hex

ns.Pages.deeds = {
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
