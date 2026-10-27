-- Forever Told pop-ups: the level-up banner, the chapter recap card and
-- toasts (deeds, revenge, nemesis warnings).

local _, ns = ...
local S = ns.Skin
local C = S.colours
local Duration = ns.U.Duration

local function Chapter(level)
    local c = ns.ChapterOf(level or 1)
    return c, ns.CHAPTERS[c]
end


local function Popup(name, w, h, y)
    local p = CreateFrame("Frame", name, UIParent)
    p:SetSize(w, h)
    p:SetPoint("TOP", 0, y)
    p:SetFrameStrata("HIGH")
    S.Fill(p, { 0.055, 0.06, 0.07, 0.92 })
    S.Border(p, { 1, 1, 1, 0.10 })
    p.accent = p:CreateTexture(nil, "ARTWORK")
    p.accent:SetColorTexture(unpack(C.accent))
    p.accent:SetHeight(2)
    p.accent:SetPoint("TOPLEFT")
    p.accent:SetPoint("TOPRIGHT")
    p:Hide()
    return p
end

-- Fade in after delay, hold, then fade out over a second.
local function Fader(p, delay, hold)
    p:SetScript("OnUpdate", function(self)
        local age = GetTime() - self.born
        if age < delay then self:SetAlpha(0)
        elseif age < delay + 0.4 then self:SetAlpha((age - delay) / 0.4)
        elseif age < delay + hold then self:SetAlpha(1)
        elseif age < delay + hold + 1 then self:SetAlpha(delay + hold + 1 - age)
        else self:Hide() end
    end)
end

-- In combat the banner and recap card wait until combat ends, so a ding
-- mid-fight never covers what's going on.
local queued = {}
local function WhenCalm(fn)
    if InCombatLockdown and InCombatLockdown() then queued[#queued + 1] = fn return end
    fn()
end
ns.On("PLAYER_REGEN_ENABLED", function()
    local list = queued
    queued = {}
    for i, fn in ipairs(list) do C_Timer.After(0.5 + (i - 1) * 0.2, fn) end
end)

-- A slim strip near the top of the screen.
local banner
local function ShowBanner(level)
    if not banner then
        banner = Popup("ForeverToldBanner", 280, 44, -110)
        banner.kicker = S.Text(banner, 9, C.accent)
        banner.kicker:SetPoint("TOP", 0, -8)
        banner.title = S.Text(banner, 15, C.text, S.TITLE)
        banner.title:SetPoint("BOTTOM", 0, 7)
        Fader(banner, 0, 3)
    end
    local c, title = Chapter(level)
    if level % 10 == 0 then
        banner.kicker:SetText(("NEW CHAPTER · LEVEL %d"):format(level))
        banner.title:SetText(("Chapter %d: %s"):format(c + 1, title))
    else
        banner.kicker:SetText(("CHAPTER %d · %s"):format(c + 1, title:upper()))
        banner.title:SetText(("Level %d"):format(level))
    end
    banner:SetWidth(math.max(220, (banner.title:GetStringWidth() or 200) + 48))
    banner.born = GetTime()
    banner:SetAlpha(0)
    banner:Show()
end
function ns.ShowBanner(level) WhenCalm(function() ShowBanner(level) end) end

-- The recap card sits just under the banner and is about half its old size.
local card
local function ShowRecapCard(c, parts, sec)
    if not card then
        card = Popup("ForeverToldRecapCard", 320, 80, -160)
        card.title = S.Text(card, 11, C.accent, S.TITLE)
        card.title:SetPoint("TOP", 0, -9)
        card.body = S.Text(card, 11, C.text)
        card.body:SetPoint("TOP", card.title, "BOTTOM", 0, -5)
        card.body:SetWidth(296)
        card.body:SetJustifyH("CENTER")
        card.body:SetSpacing(2)
        Fader(card, 1, 7)
    end
    card.title:SetText(("Chapter %d recap · %s"):format(c + 1, ns.CHAPTERS[c] or ""))
    local text = table.concat(parts, " · ")
    if sec then text = text .. (" · |cffdeb24d%s played|r"):format(Duration(sec)) end
    card.body:SetText(text)
    card:SetHeight((card.body:GetStringHeight() or 30) + 34)
    card.born = GetTime()
    card:SetAlpha(0)
    card:Show()
end
function ns.ShowRecapCard(c, parts, sec) WhenCalm(function() ShowRecapCard(c, parts, sec) end) end

local toast
function ns.ShowToast(kicker, title, sub, danger)
    if not toast then
        toast = Popup("ForeverToldToast", 340, 62, -88)
        toast.icon = toast:CreateTexture(nil, "ARTWORK")
        toast.icon:SetSize(38, 38)
        toast.icon:SetPoint("LEFT", 12, 0)
        toast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        toast.kicker = S.Text(toast, 10, C.accent)
        toast.kicker:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 12, 0)
        toast.title = S.Text(toast, 15, C.text, S.TITLE)
        toast.title:SetPoint("LEFT", toast.icon, "RIGHT", 12, -1)
        toast.sub = S.Text(toast, 11, C.muted)
        toast.sub:SetPoint("BOTTOMLEFT", toast.icon, "BOTTOMRIGHT", 12, 0)
        Fader(toast, 0, 5)
    end
    local colour = danger and C.danger or C.accent
    toast.icon:SetTexture(danger and "Interface\\Icons\\Ability_Rogue_Ambush" or ns.ICON)
    toast.accent:SetColorTexture(unpack(colour))
    toast.kicker:SetTextColor(unpack(colour))
    toast.kicker:SetText(kicker:upper())
    toast.title:SetText(title)
    toast.sub:SetText(sub or "")
    toast.born = GetTime()
    toast:SetAlpha(0)
    toast:Show()
    if not danger and PlaySound and SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST then pcall(PlaySound, SOUNDKIT.UI_EPICLOOT_TOAST) end
end
