-- Grudges page: my grudges, the guild bounty board, the poster wall and the rivalry map.

local _, ns = ...
local U, S, K = ns.U, ns.Skin, ns.PageKit
local C = S.colours
local Plural, Short, ClassColour = U.Plural, U.Short, U.ClassColour
local view, RED, Empty, GrudgeTotals, OpenGrudges = K.view, K.RED, K.Empty, K.GrudgeTotals, K.OpenGrudges

local function Who(level, class, guild)
    local bits = {}
    if level and level > 0 then bits[#bits + 1] = "level " .. level end
    if class and class ~= "" then bits[#bits + 1] = class end
    if guild then bits[#bits + 1] = "<" .. guild .. ">" end
    return table.concat(bits, " ")
end

-- "last seen in Tarren Mill, 5 minutes ago (Bob)" from a grudge or bounty record.
local function SeenText(record)
    local where, t, by = ns.LastSeen(record)
    if not where then return nil end
    local when = t and (time() - t < 86400 and U.Ago(t) or date("%d %b", t)) or ""
    local who = by and by ~= "" and Short(by) ~= UnitName("player") and (" by " .. Short(by)) or ""
    return ("last seen in %s, %s%s"):format(where, when, who), by ~= nil and t ~= nil and time() - t < 1800
end

local function MyGrudges()
    local list = ns.SortedGrudges()
    if #list == 0 then return Empty("Nobody's ganked you yet. When they do, they'll be written down here.") end
    local open, settled = {}, {}
    for _, item in ipairs(list) do
        local g = item.g
        local ours, theirs = ns.GrudgeScore(g)
        local who = Who(g.level, g.class, g.guild)
        local isOpen = ns.GrudgeOpen(g)
        local reward = ns.MyReward(item.name)
        if reward > 0 then who = who .. (who ~= "" and " · " or "") .. ("|cffdeb24d%dg reward|r"):format(reward) end
        local row = {
            text = Short(item.name), colour = isOpen and ClassColour(g.classFile) or C.muted, dot = ClassColour(g.classFile),
            sub = ("%s%s%s%s"):format(who, who ~= "" and " · " or "", (SeenText(g) or "never seen since"),
                g.exact and "" or " · best guess"),
            right = ("%d – %d"):format(ours, theirs), card = isOpen or nil,
            onClick = function() ns.ShowPoster(item.name) end,
            tip = { title = Short(item.name), lines = {
                who ~= "" and who or nil,
                ("Killed you %s, first on %s"):format(Plural(g.kills, "time"), date("%d %B", g.first)),
                ("Your revenge: %d%s"):format(g.revenge, (g.avenged or 0) > 0 and (" · avenged by your guild: %d"):format(g.avenged) or ""),
                g.exact and "Seen in the combat log" or "Best guess: they were targeting you when you died",
                isOpen and "Click to make a wanted poster" or "Click to see their poster",
            } },
        }
        table.insert(isOpen and open or settled, row)
    end
    local items = { { type = "header", text = "Unfinished business", right = "you – them" } }
    for _, row in ipairs(open) do items[#items + 1] = row end
    if #open == 0 then items[#items + 1] = { type = "empty", text = "All scores settled. For now." } end
    if #settled > 0 then
        items[#items + 1] = { type = "gap", size = 8 }
        items[#items + 1] = { type = "header", text = "Settled", right = "you – them" }
        for _, row in ipairs(settled) do items[#items + 1] = row end
    end
    return items
end

local function Bounties()
    local board = ns.BountyBoard()
    if not IsInGuild() then return Empty("Join a guild to share a bounty board. Guildies running Forever Told see each other's grudges.") end
    if #board == 0 and #ns.DB.debts == 0 then return Empty("The board is empty. When you or a guildie get ganked, the killer is posted here.") end
    local items = {}
    local debts = ns.DB.debts
    if #debts > 0 then
        items[#items + 1] = { type = "header", text = "Rewards you owe", right = "click when paid" }
        for i, d in ipairs(debts) do
            items[#items + 1] = { text = ("%d gold to %s"):format(d.gold, Short(d.to)), colour = C.accent, dot = C.accent, card = true,
                sub = ("for taking down %s, %s"):format(Short(d.name), U.Ago(d.t)), right = "mark paid",
                onClick = function() ns.MarkPaid(i) ns.Refresh() end,
                tip = { title = "Pay the hunter", lines = { "Trade or mail the gold, then click here.", ("%s gets a thank-you in their journal."):format(Short(d.to)) } } }
        end
        items[#items + 1] = { type = "gap", size = 8 }
    end
    items[#items + 1] = { type = "header", text = "Wanted by your guild", right = "kills · reward" }
    for _, b in ipairs(board) do
        local posters = {}
        for poster, p in pairs(b.posters) do posters[#posters + 1] = p.mine and "you" or Short(poster) end
        table.sort(posters)
        local claim = b.claim and ("last taken down by %s %s"):format(Short(b.claim.by or "?"), U.Ago(b.claim.t)) or nil
        local who = Who(b.level, b.class)
        local seen, fresh = SeenText(b)
        if seen and fresh then seen = "|cffeb5c4d" .. seen .. "|r" end
        items[#items + 1] = {
            text = Short(b.name), colour = ClassColour(b.classFile), dot = ClassColour(b.classFile), card = true,
            sub = ("Wanted by %s%s%s"):format(table.concat(posters, ", "), who ~= "" and (" · " .. who) or "",
                seen and (" · " .. seen) or ""),
            right = b.reward > 0 and ("%d · %dg"):format(b.kills, b.reward) or tostring(b.kills),
            onClick = function() ns.ShowPoster(b.name) end,
            tip = { title = Short(b.name), lines = { who ~= "" and who or nil,
                "Posted by " .. table.concat(posters, ", "), claim,
                b.reward > 0 and ("Reward: %d gold"):format(b.reward) or nil,
                "Kill them and everyone who posted gets their revenge.", "Click to open the poster" } },
        }
    end
    items[#items + 1] = { type = "gap", size = 6 }
    items[#items + 1] = { type = "empty", text = ns.DB.shareBounties and "Your open grudges are shared with your guild. Turn this off in Settings."
        or "You're not sharing your grudges. Turn it on in Settings." }
    return items
end

local function Rivals()
    local DB = ns.DB
    local zones, most = {}, 1
    for zone, z in pairs(DB.gankZones) do
        if z.kills + z.revenge > 0 then
            zones[#zones + 1] = { zone = zone, kills = z.kills, revenge = z.revenge }
            most = math.max(most, z.kills, z.revenge)
        end
    end
    if #zones == 0 then return Empty("No PvP yet. Once the fighting starts, this shows where and when it happens.") end
    table.sort(zones, function(a, b) return a.kills > b.kills end)
    local kills, ours = GrudgeTotals()
    local worst = zones[1]
    local items = {
        { type = "tiles", tiles = {
            { label = "Ganked", value = tostring(kills), colour = RED },
            { label = "Revenge (with guild)", value = tostring(ours), colour = C.accent },
            { label = "Deadliest zone", value = worst.zone },
        } },
        { type = "header", text = "Where you get ganked", right = "ganked · revenge" },
    }
    for _, z in ipairs(zones) do
        items[#items + 1] = { type = "bar", label = z.zone, labelWidth = 150, valueWidth = 80, height = 24, colour = RED,
            fraction = z.kills / most, value = ("%d · %d"):format(z.kills, z.revenge),
            tip = { title = z.zone, lines = { ("Ganked here %s"):format(Plural(z.kills, "time")), ("Revenge taken here %s"):format(Plural(z.revenge, "time")) } } }
    end
    -- When: three-hour blocks of the day.
    local blocks, top = {}, 0
    for b = 0, 7 do
        local n = 0
        for h = b * 3, b * 3 + 2 do n = n + (DB.gankHours[h] or 0) end
        blocks[b] = n
        top = math.max(top, n)
    end
    if top > 0 then
        items[#items + 1] = { type = "gap" }
        items[#items + 1] = { type = "header", text = "When it happens", right = "your local time" }
        for b = 0, 7 do
            items[#items + 1] = { type = "bar", label = ("%02d:00–%02d:00"):format(b * 3, b * 3 + 3), labelWidth = 150, valueWidth = 80,
                fraction = blocks[b] / top, value = Plural(blocks[b], "gank"), colour = blocks[b] == top and RED or { 1, 1, 1, 0.35 } }
        end
    end
    return items
end

ns.Pages.grudges = {
    title = "Grudges", icon = "Interface\\Icons\\Ability_Rogue_Ambush",
    subtitle = function()
        local kills, ours = GrudgeTotals()
        return ("Killed %s by other players · %d avenged"):format(Plural(kills, "time"), ours)
    end,
    badge = function() local n = OpenGrudges() return n > 0 and tostring(n) or nil, true end,
    build = function(p)
        p.segments = S.Segments(p, {
            { id = "mine", label = "My grudges" }, { id = "bounties", label = "Guild bounties" },
            { id = "wall", label = "Poster wall" }, { id = "rivals", label = "Rivalry map" },
        }, function() return view.grudges end, function(id) view.grudges = id ns.Refresh() end, 110)
        p.segments:SetPoint("TOPLEFT", 0, 0)
        p.list:ClearAllPoints()
        p.list:SetPoint("TOPLEFT", 0, -38)
        p.list:SetPoint("BOTTOMRIGHT")
        p.wall = ns.CreatePosterWall(p)
        p.wall:SetPoint("TOPLEFT", 0, -38)
        p.wall:SetPoint("BOTTOMRIGHT")
        p.wall:Hide()
    end,
    open = function(p, sub) if sub then view.grudges = sub end p.segments:Sync() end,
    -- The poster wall replaces the list; everything else is list rows.
    update = function(p)
        local onWall = view.grudges == "wall"
        p.wall:SetShown(onWall)
        p.list:SetShown(not onWall)
        if onWall then p.wall:Update() return true end
    end,
    items = function()
        if view.grudges == "bounties" then return Bounties() end
        if view.grudges == "rivals" then return Rivals() end
        return MyGrudges()
    end,
}
