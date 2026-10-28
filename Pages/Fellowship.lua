-- Fellowship page: everyone you have grouped with.

local _, ns = ...
local U, S, K = ns.U, ns.Skin, ns.PageKit
local C = S.colours
local Count, Plural, Short, ClassColour = U.Count, U.Plural, U.Short, U.ClassColour
local Empty = K.Empty

local function FellowTip(name, f)
    return { title = Short(name), lines = {
        ("%s · first met %s"):format(f.class or "Adventurer", date("%d %B %Y", f.first)),
        ("At your level %d, in %s"):format(f.firstLvl or 0, f.firstZone or "?"),
        ("%s · %s · %s"):format(Plural(f.groups, "group"), Plural(f.dungeons, "dungeon run"), Plural(f.bosses, "boss", "bosses")),
        f.last and ("Last grouped %s"):format(U.Ago(f.last)) or nil,
    } }
end

ns.Pages.fellowship = {
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
