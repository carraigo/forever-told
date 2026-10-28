-- Forever Told wanted posters: a parchment poster for anyone on your grudge
-- list or the guild bounty board, with an optional gold reward, a share
-- screenshot, and a wall of mini posters for the guild's bounties.
--
-- The reward is a promise. Addons can't hold or move gold, so the poster
-- records who pledged what, the hunter is told, and whoever pledged marks
-- it paid once they've traded or mailed the gold.

local _, ns = ...
local U, S = ns.U, ns.Skin
local C = S.colours
local Short, Plural = U.Short, U.Plural

local MAX_REWARD = 9999
local PRESETS = { 0, 1, 5, 10 }

-- Parchment and ink.
local PAPER = { 0.91, 0.84, 0.68, 1 }
local INK = { 0.23, 0.15, 0.08, 1 }
local INK_SOFT = { 0.23, 0.15, 0.08, 0.55 }
local RED_INK = { 0.48, 0.10, 0.07, 1 }
local LATIN = { enUS = true, enGB = true, deDE = true, frFR = true, esES = true, esMX = true, itIT = true, ptBR = true }
local POSTER_FONT = LATIN[GetLocale and GetLocale() or "enUS"] and "Fonts\\MORPHEUS.TTF" or STANDARD_TEXT_FONT

local TAGLINES = { "dead, preferably", "dead or alive", "on sight", "for crimes against good folk", "no questions asked" }

local function Tagline(name)
    local n = 0
    for i = 1, #name do n = n + name:byte(i) end
    return TAGLINES[n % #TAGLINES + 1]
end

local function Ink(parent, size, colour, font)
    local fs = S.Text(parent, size, colour or INK, font or POSTER_FONT)
    fs:SetJustifyH("CENTER")
    return fs
end

local function ListNames(names)
    if #names <= 1 then return names[1] or "" end
    return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
end

-- Brown edges that fade towards the middle, so the paper looks aged.
local function Age(frame, depth, strength)
    strength = strength or 0.45
    local edges = {}
    local function Edge(p1, p2, horizontal, flip)
        local t = frame:CreateTexture(nil, "BORDER")
        edges[#edges + 1] = t
        t:SetColorTexture(1, 1, 1, 1)
        t:SetPoint(p1)
        t:SetPoint(p2)
        if horizontal then t:SetHeight(depth) else t:SetWidth(depth) end
        local dark, clear = { 0.45, 0.28, 0.10, strength }, { 0.45, 0.28, 0.10, 0 }
        if flip then dark, clear = clear, dark end
        local ok = t.SetGradient and CreateColor and pcall(t.SetGradient, t, horizontal and "VERTICAL" or "HORIZONTAL",
            CreateColor(unpack(dark)), CreateColor(unpack(clear)))
        if not ok then t:SetColorTexture(0.45, 0.28, 0.10, strength / 4) end
    end
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", true, false)
    Edge("TOPLEFT", "TOPRIGHT", true, true)
    Edge("TOPLEFT", "BOTTOMLEFT", false, false)
    Edge("TOPRIGHT", "BOTTOMRIGHT", false, true)
    return edges
end

-- Poster wear ---------------------------------------------------------------------------
-- A poster yellows and picks up stains the longer it hangs: fresh for its
-- first week, worn up to three weeks, weathered after that, with darker
-- edges, a torn pin hole and a curled corner.

local WEEK = 7 * 86400
local ROUND = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function WearStage(since)
    if not since then return 0 end
    local age = time() - since
    if age < WEEK then return 0 end
    if age < 3 * WEEK then return 1 end
    return 2
end
ns.WearStage = WearStage

local function Blot(frame, layer, sublevel)
    local t = frame:CreateTexture(nil, layer, nil, sublevel)
    t:SetTexture(ROUND)
    return t
end

-- Builds the wear layers on a sheet of paper (hidden until SetWear).
-- size scales the details: 1 for the big poster, smaller for the wall.
local function AddWear(frame, size)
    local w = { size = size }
    w.tint = frame:CreateTexture(nil, "BORDER", nil, 1)
    w.tint:SetAllPoints()
    w.edges = Age(frame, 70 * size, 0.55)
    w.stains = {}
    for i = 1, 3 do
        w.stains[i] = Blot(frame, "BORDER", 2)
        w.stains[i]:SetVertexColor(0.45, 0.28, 0.10, 0.16)
    end
    -- The pin hole and a small tear running down from it.
    w.hole = Blot(frame, "OVERLAY", 1)
    w.hole:SetVertexColor(0.16, 0.10, 0.05, 0.85)
    w.hole:SetSize(7 * size + 2, 7 * size + 2)
    w.hole:SetPoint("TOP", 0, -8 * size)
    w.tear = frame:CreateTexture(nil, "OVERLAY", nil, 1)
    w.tear:SetColorTexture(0.16, 0.10, 0.05, 0.6)
    w.tear:SetSize(1, 14 * size)
    w.tear:SetPoint("TOP", w.hole, "BOTTOM", 2, 1)
    if w.tear.SetRotation then w.tear:SetRotation(math.rad(-14)) end
    -- A dog-eared bottom-right corner: a square turned 45 degrees, clipped
    -- by the paper so only a triangle shows.
    if frame.SetClipsChildren then
        local clip = CreateFrame("Frame", nil, frame)
        clip:SetAllPoints()
        clip:SetClipsChildren(true)
        clip:SetFrameLevel(frame:GetFrameLevel() + 2)
        local fold = clip:CreateTexture(nil, "OVERLAY")
        fold:SetColorTexture(0.74, 0.63, 0.45, 1)
        fold:SetSize(44 * size, 44 * size)
        fold:SetPoint("CENTER", clip, "BOTTOMRIGHT", 0, 0)
        if fold.SetRotation then fold:SetRotation(math.rad(45)) end
        local shade = clip:CreateTexture(nil, "ARTWORK")
        shade:SetColorTexture(0.30, 0.18, 0.07, 0.35)
        shade:SetSize(50 * size, 50 * size)
        shade:SetPoint("CENTER", clip, "BOTTOMRIGHT", 0, 0)
        if shade.SetRotation then shade:SetRotation(math.rad(45)) end
        w.curl = clip
    end
    frame.wear = w
    return w
end

-- Show a stage (0 fresh, 1 worn, 2 weathered). seed keeps each poster's
-- stains in the same places every time it's drawn.
local function SetWear(frame, stage, seed)
    local w = frame.wear
    if not w then return end
    w.stage = stage
    w.tint:SetColorTexture(0.55, 0.38, 0.12, stage == 2 and 0.24 or stage == 1 and 0.13 or 0)
    for _, t in ipairs(w.edges) do t:SetShown(stage == 2) end
    local width, height = frame:GetWidth() or 300, frame:GetHeight() or 400
    local n = 0
    for i = 1, #(seed or "") do n = (n * 31 + seed:byte(i)) % 100003 end
    for i, t in ipairs(w.stains) do
        local show = (stage == 1 and i == 1) or stage == 2
        t:SetShown(show)
        if show then
            n = (n * 7919 + 104729) % 100003
            local d = (36 + n % 40) * w.size + 8
            t:SetSize(d, d)
            t:ClearAllPoints()
            t:SetPoint("CENTER", frame, "BOTTOMLEFT", 20 + n % math.max(1, math.floor(width - 40)),
                20 + math.floor(n / 7) % math.max(1, math.floor(height - 40)))
        end
    end
    w.hole:SetShown(stage == 2)
    w.tear:SetShown(stage == 2)
    if w.curl then w.curl:SetShown(stage == 2) end
end

local function Paper(frame, inset)
    S.Fill(frame, PAPER)
    Age(frame, inset * 3)
    local rule = CreateFrame("Frame", nil, frame)
    rule:SetPoint("TOPLEFT", inset, -inset)
    rule:SetPoint("BOTTOMRIGHT", -inset, inset)
    S.Border(rule, INK_SOFT)
    return rule
end

local function ClassIcon(tex, classFile)
    local coords = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
    if coords then
        tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        tex:SetTexCoord(unpack(coords))
    else
        tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    -- Sepia, like an old woodcut.
    if tex.SetDesaturated then tex:SetDesaturated(true) end
    tex:SetVertexColor(0.62, 0.45, 0.28)
end

-- Everything a poster needs to know about one player.
local function PosterInfo(name)
    local DB = ns.DB
    local key = ns.FindGrudge(name)
    local g = key and DB.grudges[key]
    local b, bkey = ns.FindBounty(name)
    if not g and not b then return nil end
    local info = { name = key or bkey, victims = {}, pledgers = {}, reward = 0, kills = 0 }
    local src = g or b
    info.classFile, info.class, info.level, info.guild = src.classFile, src.class, src.level, g and g.guild
    -- The freshest sighting wins, from either record.
    info.zone, info.t, info.seenBy = ns.LastSeen(src)
    if g and b then
        local bz, bt, bby = ns.LastSeen(b)
        if bt and (not info.t or bt > info.t) then info.zone, info.t, info.seenBy = bz, bt, bby end
    end
    if g and ns.GrudgeOpen(g) then
        local ours, theirs = ns.GrudgeScore(g)
        info.mine = true
        info.kills = theirs - ours
        info.victims[#info.victims + 1] = UnitName("player")
        local mine = ns.MyReward(info.name)
        if mine > 0 then
            info.reward = mine
            info.pledgers[#info.pledgers + 1] = UnitName("player")
        end
    elseif g then
        info.mine, info.settled = true, true
        info.victims[#info.victims + 1] = UnitName("player")
        info.kills = g.kills
    end
    -- How long they've been wanted, for the poster's wear.
    info.since = g and g.first
    local posted = b and (b.since or b.t)
    if posted and (not info.since or posted < info.since) then info.since = posted end
    if b then
        for poster, p in pairs(b.posters) do
            info.victims[#info.victims + 1] = Short(poster)
            info.kills = info.kills + math.max(0, (p.kills or 1) - (p.ours or 0))
            if (p.reward or 0) > 0 then
                info.reward = info.reward + p.reward
                info.pledgers[#info.pledgers + 1] = Short(poster)
            end
        end
        info.claim = b.claim
    end
    return info
end
ns.PosterInfo = PosterInfo

-- The full poster ---------------------------------------------------------------------

local poster
local draft = { name = nil, reward = 0, custom = false }

local function RewardText(gold)
    if gold > 0 then return ("%d GOLD"):format(gold) end
    return "ETERNAL GRATITUDE"
end

local function FillPoster(info, reward)
    local p = poster
    p.tagline:SetText(Tagline(info.name))
    SetWear(p, info.settled and 0 or WearStage(info.since), info.name)
    ClassIcon(p.portrait, info.classFile)
    p.caption:SetText(info.class and ("a %s"):format(info.class:lower()) or "a stranger")
    p.who:SetText(Short(info.name):upper())
    local bits = {}
    if info.level then bits[#bits + 1] = "Level " .. info.level end
    if info.class then bits[#bits + 1] = info.class end
    local line = table.concat(bits, " ")
    if info.guild then line = line .. " of <" .. info.guild .. ">" end
    p.detail:SetText(line)
    local crimes = ("For ganking %s %s."):format(ListNames(info.victims), Plural(math.max(1, info.kills), "time"))
    if info.zone then
        local when = info.t and (time() - info.t < 86400 and U.Ago(info.t) or date("%d %b", info.t))
        local by = info.seenBy and Short(info.seenBy) ~= UnitName("player") and (", reported by " .. Short(info.seenBy)) or ""
        crimes = crimes .. ("\nLast seen in %s%s%s."):format(info.zone, when and (", " .. when) or "", by)
    end
    p.crimes:SetText(crimes)
    p.reward:SetText(RewardText(reward))
    p.coin:SetShown(reward > 0)
    local pledgers = {}
    for _, n in ipairs(info.pledgers) do pledgers[#pledgers + 1] = n end
    if info.mine and reward > 0 and not tContains(pledgers, UnitName("player")) then table.insert(pledgers, 1, UnitName("player")) end
    p.pledged:SetText(#pledgers > 0 and ("pledged by " .. ListNames(pledgers)) or "no gold pledged, just glory")
    local stamp = info.settled and "SETTLED" or (info.claim and time() - (info.claim.t or 0) < 86400 and "AVENGED")
    p.stamp:SetShown(stamp and true or false)
    p.stamp.text:SetText(stamp or "")
end

local function Preview()
    local info = PosterInfo(draft.name)
    if not info then poster:Hide() return end
    -- On my own poster the reward is mine to set; guildies' pledges are added on top.
    local reward = info.reward
    if info.mine and not info.settled then reward = reward - ns.MyReward(info.name) + draft.reward end
    FillPoster(info, reward)
    poster.controls.mine:SetShown(info.mine and not info.settled)
    poster.controls.theirs:SetShown(not info.mine or info.settled)
    poster.controls.segments:Sync()
    local pinned = ns.DB.posters[info.name] and not ns.DB.posters[info.name].done
    poster.controls.pin:SetLabel(pinned and "Update poster" or "Pin poster")
    poster.controls.remove:SetShown(pinned and true or false)
end

local function Pin()
    local name = draft.name
    ns.DB.posters[name] = { reward = draft.reward, t = time() }
    ns.PostBounty(name)
    local where = ns.DB.shareBounties and IsInGuild() and "on your guild's bounty board" or "on your grudge list (sharing is off)"
    ns.Add("pvp", ("Pinned a wanted poster for %s%s."):format(Short(name), draft.reward > 0 and (", %d gold reward"):format(draft.reward) or ""))
    ns.ShowToast("Poster pinned", Short(name), "Now " .. where)
    Preview()
end

local function TakeDown()
    local name = draft.name
    ns.DB.posters[name] = nil
    draft.reward, draft.custom = 0, false
    ns.PostBounty(name)
    Preview()
    ns.Refresh()
end

local function Share()
    S.Snapshot(poster, { poster.controls, poster.close }, "Poster saved to your Screenshots folder. Drop it in Discord!")
end

local function CreatePoster()
    local p = CreateFrame("Frame", "ForeverToldPoster", UIParent)
    poster = p
    p:SetSize(340, 500)
    p:SetPoint("CENTER", 0, 40)
    p:SetFrameStrata("DIALOG")
    p:SetToplevel(true)
    p:SetMovable(true)
    p:SetClampedToScreen(true)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", p.StartMoving)
    p:SetScript("OnDragStop", p.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ForeverToldPoster")
    Paper(p, 12)
    AddWear(p, 1)

    p.title = Ink(p, 52, { 0.29, 0.16, 0.07, 1 })
    p.title:SetPoint("TOP", 0, -28)
    p.title:SetText("WANTED")
    p.tagline = Ink(p, 15)
    p.tagline:SetPoint("TOP", p.title, "BOTTOM", 0, -2)

    local frameBox = CreateFrame("Frame", nil, p)
    frameBox:SetSize(150, 120)
    frameBox:SetPoint("TOP", p.tagline, "BOTTOM", 0, -12)
    S.Fill(frameBox, { 0.29, 0.16, 0.07, 0.10 })
    S.Border(frameBox, INK)
    local inner = CreateFrame("Frame", nil, frameBox)
    inner:SetPoint("TOPLEFT", 4, -4)
    inner:SetPoint("BOTTOMRIGHT", -4, 4)
    S.Border(inner, INK_SOFT)
    p.portrait = frameBox:CreateTexture(nil, "ARTWORK")
    p.portrait:SetSize(78, 78)
    p.portrait:SetPoint("CENTER", 0, 4)
    p.caption = Ink(frameBox, 11)
    p.caption:SetPoint("BOTTOM", 0, 8)

    p.who = Ink(p, 34, INK)
    p.who:SetPoint("TOP", frameBox, "BOTTOM", 0, -14)
    p.detail = Ink(p, 13, INK, STANDARD_TEXT_FONT)
    p.detail:SetPoint("TOP", p.who, "BOTTOM", 0, -4)
    local rule = p:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(unpack(INK_SOFT))
    rule:SetSize(240, 1)
    rule:SetPoint("TOP", p.detail, "BOTTOM", 0, -10)
    p.crimes = Ink(p, 13, INK, STANDARD_TEXT_FONT)
    p.crimes:SetPoint("TOP", rule, "BOTTOM", 0, -10)
    p.crimes:SetWidth(280)
    p.crimes:SetSpacing(3)

    p.pledged = Ink(p, 11, INK, STANDARD_TEXT_FONT)
    p.pledged:SetPoint("BOTTOM", 0, 26)
    p.reward = Ink(p, 26, RED_INK)
    p.reward:SetPoint("BOTTOM", p.pledged, "TOP", 8, 4)
    p.coin = p:CreateTexture(nil, "ARTWORK")
    p.coin:SetSize(18, 18)
    p.coin:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    p.coin:SetPoint("RIGHT", p.reward, "LEFT", -6, 0)
    local label = Ink(p, 13)
    label:SetPoint("BOTTOM", p.reward, "TOP", -8, 2)
    label:SetText("REWARD")

    -- A stamp across the portrait once someone's collected.
    p.stamp = CreateFrame("Frame", nil, p)
    p.stamp:SetSize(150, 40)
    p.stamp:SetPoint("CENTER", frameBox, "CENTER", 0, -4)
    p.stamp:SetFrameLevel(p:GetFrameLevel() + 5)
    S.Fill(p.stamp, { 0.91, 0.84, 0.68, 0.65 })
    S.Border(p.stamp, { 0.70, 0.15, 0.12, 1 })
    p.stamp.text = Ink(p.stamp, 24, { 0.70, 0.15, 0.12, 1 })
    p.stamp.text:SetPoint("CENTER")

    -- Controls underneath, in the journal's own dark style.
    local c = CreateFrame("Frame", nil, p)
    p.controls = c
    c:SetPoint("TOPLEFT", p, "BOTTOMLEFT", 0, -6)
    c:SetPoint("TOPRIGHT", p, "BOTTOMRIGHT", 0, -6)
    c:SetHeight(84)
    S.Fill(c, C.bg)
    S.Border(c, { 1, 1, 1, 0.10 })

    c.mine = CreateFrame("Frame", nil, c)
    c.mine:SetAllPoints()
    local rewardLabel = S.Text(c.mine, 12, C.muted)
    rewardLabel:SetPoint("TOPLEFT", 10, -16)
    rewardLabel:SetText("Reward")
    local options = {}
    for _, gold in ipairs(PRESETS) do options[#options + 1] = { id = gold, label = gold == 0 and "none" or (gold .. "g") } end
    options[#options + 1] = { id = "custom", label = "custom" }
    c.segments = S.Segments(c.mine, options,
        function() return draft.custom and "custom" or draft.reward end,
        function(id)
            if id == "custom" then
                draft.custom = true
                c.custom:SetText(draft.reward > 0 and tostring(draft.reward) or "")
                c.custom:SetFocus()
            else
                draft.custom, draft.reward = false, id
                c.custom:SetText("")
                c.custom:ClearFocus()
            end
            Preview()
        end, 42)
    c.segments:SetPoint("TOPLEFT", 56, -10)
    c.custom = S.Input(c.mine, 52, "gold")
    c.custom:SetPoint("TOPRIGHT", -10, -10)
    c.custom:SetNumeric(true)
    c.custom:SetMaxLetters(4)
    -- The box is always there: typing in it picks "custom" by itself.
    c.custom:HookScript("OnTextChanged", function(self, typed)
        if not typed then return end
        draft.custom = true
        draft.reward = math.min(MAX_REWARD, tonumber(self:GetText()) or 0)
        Preview()
    end)
    c.custom:HookScript("OnEditFocusGained", function()
        if not draft.custom then draft.custom = true Preview() end
    end)
    -- Enter pins (or updates) the poster with the amount typed.
    c.custom:SetScript("OnEnterPressed", function(self) self:ClearFocus() Pin() end)
    c.pin = S.Button(c.mine, "Pin poster", 104, 26, "primary")
    c.pin:SetPoint("BOTTOMRIGHT", -10, 12)
    c.pin:SetScript("OnClick", Pin)
    c.remove = S.Button(c.mine, "Take down", 90, 26)
    c.remove:SetPoint("RIGHT", c.pin, "LEFT", -6, 0)
    c.remove:SetScript("OnClick", TakeDown)

    c.theirs = CreateFrame("Frame", nil, c)
    c.theirs:SetAllPoints()
    local note = S.Text(c.theirs, 12, C.muted)
    note:SetPoint("TOPLEFT", 12, -14)
    note:SetWidth(300)
    note:SetText("Posted by your guild. Take them down to collect.")

    local share = S.Button(c, "Share", 76, 26)
    share:SetPoint("BOTTOMLEFT", 10, 12)
    share:SetScript("OnClick", Share)

    -- Close sits on the parchment itself, out of the way of the buttons.
    local close = CreateFrame("Button", nil, p)
    close:SetSize(26, 26)
    close:SetPoint("TOPRIGHT", -16, -16)
    local x = Ink(close, 20, INK_SOFT, STANDARD_TEXT_FONT)
    x:SetPoint("CENTER")
    x:SetText("×")
    close:SetScript("OnEnter", function() x:SetTextColor(unpack(INK)) end)
    close:SetScript("OnLeave", function() x:SetTextColor(unpack(INK_SOFT)) end)
    close:SetScript("OnClick", function() p:Hide() end)
    p.close = close
    p:SetScript("OnHide", function() if c.custom then c.custom:ClearFocus() end end)
    p:Hide()
end

function ns.ShowPoster(name)
    if not PosterInfo(name) then return end
    if not poster then CreatePoster() end
    local key = ns.FindGrudge(name) or select(2, ns.FindBounty(name)) or name
    draft.name = key
    draft.reward = ns.MyReward(key)
    local preset = false
    for _, gold in ipairs(PRESETS) do if gold == draft.reward then preset = true end end
    draft.custom = not preset
    poster.controls.custom:SetText(draft.custom and tostring(draft.reward) or "")
    poster:Show()
    Preview()
end

-- The poster wall -------------------------------------------------------------------------

local CARD_W, CARD_H, GAP = 124, 172, 14

local function CreateMini(parent)
    local m = CreateFrame("Button", nil, parent)
    m:SetSize(CARD_W, CARD_H)
    Paper(m, 6)
    AddWear(m, 0.4)
    m.title = Ink(m, 20, { 0.29, 0.16, 0.07, 1 })
    m.title:SetPoint("TOP", 0, -12)
    m.title:SetText("WANTED")
    local box = CreateFrame("Frame", nil, m)
    box:SetSize(54, 50)
    box:SetPoint("TOP", m.title, "BOTTOM", 0, -6)
    S.Fill(box, { 0.29, 0.16, 0.07, 0.10 })
    S.Border(box, INK)
    m.icon = box:CreateTexture(nil, "ARTWORK")
    m.icon:SetSize(38, 38)
    m.icon:SetPoint("CENTER")
    m.who = Ink(m, 14, INK)
    m.who:SetPoint("TOP", box, "BOTTOM", 0, -8)
    m.who:SetWidth(CARD_W - 14)
    m.who:SetWordWrap(false)
    m.detail = Ink(m, 9, INK, STANDARD_TEXT_FONT)
    m.detail:SetPoint("TOP", m.who, "BOTTOM", 0, -3)
    m.detail:SetWidth(CARD_W - 14)
    m.detail:SetWordWrap(false)
    m.reward = Ink(m, 13, RED_INK)
    m.reward:SetPoint("BOTTOM", 0, 14)
    m.spotted = Ink(m, 9, RED_INK, STANDARD_TEXT_FONT)
    m.spotted:SetPoint("BOTTOM", m.reward, "TOP", 0, 4)
    m.spotted:SetWidth(CARD_W - 14)
    m.spotted:SetWordWrap(false)
    m.stamp = CreateFrame("Frame", nil, m)
    m.stamp:SetSize(96, 26)
    m.stamp:SetPoint("CENTER", box, "CENTER", 0, -6)
    m.stamp:SetFrameLevel(m:GetFrameLevel() + 3)
    S.Fill(m.stamp, { 0.91, 0.84, 0.68, 0.7 })
    S.Border(m.stamp, { 0.70, 0.15, 0.12, 1 })
    m.stamp.text = Ink(m.stamp, 15, { 0.70, 0.15, 0.12, 1 })
    m.stamp.text:SetPoint("CENTER")
    m.stamp.text:SetText("AVENGED")
    m.glow = m:CreateTexture(nil, "OVERLAY")
    m.glow:SetAllPoints()
    m.glow:SetColorTexture(1, 1, 1, 0.08)
    m.glow:Hide()
    m:SetScript("OnEnter", function(self)
        self.glow:Show()
        local info = self.info
        if not info then return end
        local lines = { ("Wanted by %s"):format(ListNames(info.victims)), Plural(info.kills, "unpaid kill") }
        if info.reward > 0 then lines[#lines + 1] = ("%d gold from %s"):format(info.reward, ListNames(info.pledgers)) end
        lines[#lines + 1] = "Click to open the poster"
        S.ShowTip(self, Short(info.name), lines)
    end)
    m:SetScript("OnLeave", function(self) self.glow:Hide() S.HideTip() end)
    m:SetScript("OnClick", function(self) if self.info then ns.ShowPoster(self.info.name) end end)
    return m
end

-- A wood-panel area showing every bounty as a little poster.
function ns.CreatePosterWall(parent)
    local wall = CreateFrame("Frame", nil, parent)
    S.Fill(wall, { 0.22, 0.15, 0.09, 1 })
    S.Border(wall, { 0.12, 0.08, 0.05, 1 })
    wall.planks = {}
    local scroll = S.Scroll(wall)
    scroll:SetPoint("TOPLEFT", 12, -12)
    scroll:SetPoint("BOTTOMRIGHT", -12, 12)
    local minis = {}
    wall.empty = S.Text(wall, 13, { 0.85, 0.78, 0.62, 1 })
    wall.empty:SetPoint("CENTER")
    wall.empty:SetWidth(360)
    wall.empty:SetJustifyH("CENTER")

    function wall:Update()
        local width = (self:GetWidth() or 560)
        -- Vertical plank lines.
        for i = 1, math.floor(width / 70) do
            local t = self.planks[i]
            if not t then
                t = self:CreateTexture(nil, "BORDER")
                t:SetColorTexture(0, 0, 0, 0.22)
                t:SetWidth(2)
                self.planks[i] = t
            end
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", i * 70, 0)
            t:SetPoint("BOTTOMLEFT", i * 70, 0)
        end
        local board = ns.BountyBoard()
        local cols = math.max(1, math.floor((width - 24 + GAP) / (CARD_W + GAP)))
        local offset = math.floor(((width - 24) - (cols * CARD_W + (cols - 1) * GAP)) / 2)
        for i, b in ipairs(board) do
            local m = minis[i] or CreateMini(scroll.child)
            minis[i] = m
            local info = PosterInfo(b.name)
            m.info = info
            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            m:ClearAllPoints()
            -- A slight up-and-down stagger so it looks pinned by hand.
            m:SetPoint("TOPLEFT", offset + col * (CARD_W + GAP), -(row * (CARD_H + GAP) + ((i % 3 == 0) and 8 or (i % 2) * 4)))
            ClassIcon(m.icon, info and info.classFile)
            SetWear(m, WearStage(info and info.since), b.name)
            m.who:SetText(Short(b.name):upper())
            m.detail:SetText(("%s%s"):format(b.level and (b.level .. " ") or "", b.class or "") .. (b.zone and b.zone ~= "" and (" · " .. b.zone) or ""))
            m.reward:SetText(b.reward > 0 and ("%d GOLD"):format(b.reward) or "for glory")
            -- Seen in the last half hour: say where, in red.
            local where, t = ns.LastSeen(b)
            m.spotted:SetText(b.seen and t and time() - t < 1800 and ("seen %s · %s"):format(U.Ago(t), where) or "")
            m.stamp:SetShown(b.claim and time() - (b.claim.t or 0) < 86400 or false)
            m:Show()
        end
        for i = #board + 1, #minis do minis[i]:Hide() end
        local rows = math.ceil(#board / cols)
        scroll:SetContentHeight(rows * (CARD_H + GAP) + 10)
        self.empty:SetShown(#board == 0)
        self.empty:SetText(IsInGuild() and "No wanted posters yet. Click one of your grudges to make one."
            or "Join a guild to share a poster wall. Click one of your grudges to make a poster.")
    end
    return wall
end
