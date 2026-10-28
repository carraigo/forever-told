-- Atlas page: places by continent, dungeons and bosses.

local _, ns = ...
local U, S, K = ns.U, ns.Skin, ns.PageKit
local C = S.colours
local Count, Plural, Hex = U.Count, U.Plural, U.Hex
local Empty = K.Empty

ns.Pages.atlas = {
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
