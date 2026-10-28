-- Forever Told's own widget kit: flat, dark and modern, built from plain
-- textures and font strings instead of Blizzard's templates, so it looks
-- the same on WoW Forever and Classic Era.

local _, ns = ...

local S = {}
ns.Skin = S

S.colours = {
    bg = { 0.055, 0.06, 0.07, 0.97 },
    panel = { 0.085, 0.09, 0.105, 1 },
    raised = { 0.12, 0.125, 0.145, 1 },
    hover = { 1, 1, 1, 0.05 },
    line = { 1, 1, 1, 0.08 },
    accent = { 0.87, 0.70, 0.30, 1 },
    text = { 0.94, 0.93, 0.89, 1 },
    muted = { 0.60, 0.59, 0.55, 1 },
    danger = { 0.92, 0.36, 0.30, 1 },
}
local C = S.colours

-- Arial Narrow reads cleaner than the game font for body text, but only
-- Latin-alphabet clients ship it, so other locales keep the default.
local LATIN = { enUS = true, enGB = true, deDE = true, frFR = true, esES = true, esMX = true, itIT = true, ptBR = true }
S.BODY = LATIN[GetLocale and GetLocale() or "enUS"] and "Fonts\\ARIALN.TTF" or STANDARD_TEXT_FONT
S.TITLE = STANDARD_TEXT_FONT

function S.Fill(frame, colour, layer)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(unpack(colour))
    return t
end

-- A one-pixel border on all four sides.
function S.Border(frame, colour)
    colour = colour or C.line
    local edges = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(unpack(colour))
        if side == "TOP" or side == "BOTTOM" then
            t:SetHeight(1)
            t:SetPoint(side .. "LEFT")
            t:SetPoint(side .. "RIGHT")
        else
            t:SetWidth(1)
            t:SetPoint("TOP" .. side)
            t:SetPoint("BOTTOM" .. side)
        end
        edges[#edges + 1] = t
    end
    function frame:SetBorderColour(r, g, b, a)
        for _, t in ipairs(edges) do t:SetColorTexture(r, g, b, a) end
    end
    return edges
end

function S.Text(parent, size, colour, font, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or S.BODY, size or 13, flags or "")
    fs:SetTextColor(unpack(colour or C.text))
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    return fs
end

-- Buttons: "primary" (gold), "ghost" (outlined), "nav" (sidebar item).
function S.Button(parent, label, width, height, kind)
    kind = kind or "ghost"
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 100, height or 26)
    b.bg = S.Fill(b, kind == "primary" and C.accent or { 0, 0, 0, 0 })
    if kind == "ghost" then S.Border(b, { 1, 1, 1, 0.14 }) end
    b.label = S.Text(b, 12, kind == "primary" and { 0.1, 0.08, 0.03, 1 } or C.text)
    b.label:SetText(label)
    if kind == "nav" then
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(18, 18)
        b.icon:SetPoint("LEFT", 14, 0)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.label:SetPoint("LEFT", b.icon, "RIGHT", 10, 0)
        b.label:SetFont(S.BODY, 13, "")
        b.bar = b:CreateTexture(nil, "ARTWORK")
        b.bar:SetColorTexture(unpack(C.accent))
        b.bar:SetPoint("TOPLEFT")
        b.bar:SetPoint("BOTTOMLEFT")
        b.bar:SetWidth(3)
        b.bar:Hide()
        b.badge = S.Text(b, 11, C.muted)
        b.badge:SetPoint("RIGHT", -14, 0)
        b.badge:SetJustifyH("RIGHT")
    else
        b.label:SetPoint("CENTER")
        b.label:SetJustifyH("CENTER")
    end
    b:SetScript("OnEnter", function(self)
        if self.selected then return end
        if kind == "primary" then self.bg:SetColorTexture(0.95, 0.80, 0.42, 1)
        else self.bg:SetColorTexture(unpack(C.hover)) end
    end)
    b:SetScript("OnLeave", function(self)
        if self.selected then return end
        if kind == "primary" then self.bg:SetColorTexture(unpack(C.accent))
        else self.bg:SetColorTexture(0, 0, 0, 0) end
    end)
    function b:SetSelected(on)
        self.selected = on
        if kind == "nav" then
            self.bar:SetShown(on)
            self.bg:SetColorTexture(on and 1 or 0, on and 1 or 0, on and 1 or 0, on and 0.07 or 0)
            self.label:SetTextColor(unpack(on and C.text or C.muted))
        end
    end
    function b:SetLabel(text) self.label:SetText(text) end
    -- Nav only: a small count on the right, red when it needs attention.
    function b:SetBadge(text, alert)
        if not self.badge then return end
        self.badge:SetText(text or "")
        self.badge:SetTextColor(unpack(alert and C.danger or C.muted))
    end
    if kind == "nav" then b:SetSelected(false) end
    return b
end

-- A flat text box with a placeholder.
function S.Input(parent, width, placeholder)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(width, 26)
    box:SetAutoFocus(false)
    box:EnableMouse(true)
    box:SetFont(S.BODY, 12, "")
    box:SetTextColor(unpack(C.text))
    box:SetTextInsets(8, 8, 0, 0)
    S.Fill(box, C.raised)
    S.Border(box, { 1, 1, 1, 0.10 })
    local hint = S.Text(box, 12, C.muted)
    hint:SetPoint("LEFT", 8, 0)
    hint:SetText(placeholder or "")
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnEditFocusGained", function(self) self:SetBorderColour(unpack(C.accent)) end)
    box:SetScript("OnEditFocusLost", function(self) self:SetBorderColour(1, 1, 1, 0.10) end)
    box:HookScript("OnTextChanged", function(self) hint:SetShown((self:GetText() or "") == "") end)
    return box
end

-- An on/off switch with a label.
function S.Toggle(parent, label, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(380, 28)
    local track = CreateFrame("Frame", nil, b)
    track:SetSize(34, 18)
    track:SetPoint("LEFT")
    local trackBg = S.Fill(track, C.raised, "ARTWORK")
    local knob = track:CreateTexture(nil, "OVERLAY")
    knob:SetSize(14, 14)
    knob:SetColorTexture(unpack(C.text))
    local text = S.Text(b, 13, C.text)
    text:SetPoint("LEFT", track, "RIGHT", 12, 0)
    text:SetText(label)
    function b:Sync()
        local on = get()
        knob:ClearAllPoints()
        knob:SetPoint(on and "RIGHT" or "LEFT", on and -2 or 2, 0)
        trackBg:SetColorTexture(unpack(on and C.accent or C.raised))
    end
    b:SetScript("OnClick", function(self) set(not get()) self:Sync() end)
    b:Sync()
    return b
end

-- A scroll area with mouse-wheel scrolling and a thin scroll indicator.
function S.Scroll(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(10, 10)
    sf:SetScrollChild(child)
    local thumb = sf:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(1, 1, 1, 0.18)
    thumb:SetWidth(3)
    local function UpdateThumb()
        local range = sf:GetVerticalScrollRange() or 0
        local h = sf:GetHeight() or 1
        if range <= 0 then thumb:Hide() return end
        thumb:Show()
        local size = math.max(24, h * h / (h + range))
        thumb:SetHeight(size)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, -((sf:GetVerticalScroll() or 0) / range) * (h - size))
    end
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        local v = math.max(0, math.min(range, (self:GetVerticalScroll() or 0) - delta * 48))
        self:SetVerticalScroll(v)
        UpdateThumb()
    end)
    sf:SetScript("OnSizeChanged", function(self, w)
        child:SetWidth(w or self:GetWidth())
        UpdateThumb()
    end)
    function sf:SetContentHeight(h)
        child:SetHeight(math.max(1, h))
        if (self:GetVerticalScroll() or 0) > (self:GetVerticalScrollRange() or 0) then self:SetVerticalScroll(0) end
        UpdateThumb()
    end
    sf.child = child
    return sf
end

-- Our own flat tooltip, so hovering matches the rest of the window.
local tip
function S.ShowTip(owner, title, lines)
    if not tip then
        tip = CreateFrame("Frame", "ForeverToldTip", UIParent)
        tip:SetFrameStrata("TOOLTIP")
        S.Fill(tip, { 0.07, 0.075, 0.09, 0.98 })
        S.Border(tip, { 1, 1, 1, 0.14 })
        tip.title = S.Text(tip, 13, C.text, S.TITLE)
        tip.title:SetPoint("TOPLEFT", 10, -9)
        tip.body = S.Text(tip, 12, C.muted)
        tip.body:SetPoint("TOPLEFT", tip.title, "BOTTOMLEFT", 0, -5)
        tip.body:SetWidth(240)
        tip.body:SetSpacing(2)
    end
    tip.title:SetText(title or "")
    -- Lines may have gaps (nil for "nothing to say"), so collect them in order.
    local keys, text = {}, {}
    for i in pairs(lines or {}) do keys[#keys + 1] = i end
    table.sort(keys)
    for _, i in ipairs(keys) do text[#text + 1] = lines[i] end
    tip.body:SetText(table.concat(text, "\n"))
    tip:SetSize(260, (tip.title:GetStringHeight() or 14) + (tip.body:GetStringHeight() or 14) + 24)
    tip:ClearAllPoints()
    tip:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", 8, -12)
    tip:Show()
end
function S.HideTip() if tip then tip:Hide() end end

-- A button that opens a flat menu of choices.
function S.Dropdown(parent, width, options, get, set)
    local b = S.Button(parent, "", width, 26)
    b.label:ClearAllPoints()
    b.label:SetPoint("LEFT", 10, 0)
    b.label:SetJustifyH("LEFT")
    -- A small chevron drawn from two rotated lines.
    for i, angle in ipairs({ 45, -45 }) do
        local line = b:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(unpack(C.muted))
        line:SetSize(6, 1.5)
        line:SetPoint("RIGHT", i == 1 and -15 or -11, 0)
        if line.SetRotation then line:SetRotation(math.rad(angle)) end
    end
    local menu = CreateFrame("Frame", nil, b)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -2)
    menu:SetSize(width, #options * 24 + 8)
    S.Fill(menu, { 0.09, 0.095, 0.11, 0.99 })
    S.Border(menu, { 1, 1, 1, 0.14 })
    menu:Hide()
    menu.items = {}
    for i, o in ipairs(options) do
        local item = CreateFrame("Button", nil, menu)
        item:SetSize(width - 8, 24)
        item:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 24)
        item.bg = S.Fill(item, { 0, 0, 0, 0 })
        item.text = S.Text(item, 12, C.text)
        item.text:SetPoint("LEFT", 8, 0)
        item.text:SetText(o.label)
        item:SetScript("OnEnter", function(self) self.bg:SetColorTexture(unpack(C.hover)) end)
        item:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0, 0, 0, 0) end)
        item:SetScript("OnClick", function()
            menu:Hide()
            set(o.id)
            b:Sync()
        end)
        menu.items[i] = item
    end
    function b:Sync()
        local current = get()
        for i, o in ipairs(options) do
            menu.items[i].text:SetTextColor(unpack(o.id == current and C.accent or C.text))
            if o.id == current then self:SetLabel(o.label) end
        end
    end
    b:SetScript("OnClick", function() menu:SetShown(not menu:IsShown()) end)
    b:SetScript("OnHide", function() menu:Hide() end)
    b.menu = menu
    b:Sync()
    return b
end

-- A row of joined buttons where one is selected (like tabs inside a page).
function S.Segments(parent, options, get, set, width)
    local f = CreateFrame("Frame", nil, parent)
    width = width or 110
    f:SetSize(width * #options, 26)
    S.Border(f, { 1, 1, 1, 0.14 })
    f.buttons = {}
    for i, o in ipairs(options) do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(width, 26)
        b:SetPoint("LEFT", (i - 1) * width, 0)
        b.bg = S.Fill(b, { 0, 0, 0, 0 })
        b.text = S.Text(b, 12, C.muted)
        b.text:SetPoint("CENTER")
        b.text:SetJustifyH("CENTER")
        b.text:SetText(o.label)
        if i > 1 then
            local sep = b:CreateTexture(nil, "BORDER")
            sep:SetColorTexture(1, 1, 1, 0.14)
            sep:SetWidth(1)
            sep:SetPoint("TOPLEFT")
            sep:SetPoint("BOTTOMLEFT")
        end
        b:SetScript("OnClick", function() set(o.id) f:Sync() end)
        f.buttons[i] = b
    end
    function f:Sync()
        local current = get()
        for i, o in ipairs(options) do
            local on = o.id == current
            self.buttons[i].bg:SetColorTexture(1, 1, 1, on and 0.09 or 0)
            self.buttons[i].text:SetTextColor(unpack(on and C.text or C.muted))
        end
    end
    f:Sync()
    return f
end

-- A list of rows: headers, entries, stats and bars, laid out top to bottom.
-- Rows are pooled and reused, so long journals stay light.
function S.List(parent)
    local sf = S.Scroll(parent)
    local pool, used = {}, 0

    local function Row()
        used = used + 1
        local r = pool[used]
        if r then r:Show() return r end
        r = CreateFrame("Frame", nil, sf.child)
        r.bg = S.Fill(r, { 0, 0, 0, 0 })
        r.dot = r:CreateTexture(nil, "ARTWORK")
        r.dot:SetSize(6, 6)
        r.meta = S.Text(r, 11, C.muted)
        r.text = S.Text(r, 13, C.text)
        r.sub = S.Text(r, 11, C.muted)
        r.right = S.Text(r, 11, C.muted)
        r.right:SetJustifyH("RIGHT")
        r.line = r:CreateTexture(nil, "ARTWORK")
        r.line:SetColorTexture(unpack(C.line))
        r.line:SetHeight(1)
        r.barBg = r:CreateTexture(nil, "ARTWORK")
        r.barBg:SetColorTexture(1, 1, 1, 0.06)
        r.bar = r:CreateTexture(nil, "OVERLAY")
        r.bar:SetColorTexture(unpack(C.accent))
        r.tiles = {}
        r:SetScript("OnEnter", function(self)
            local item = self.item
            if not item then return end
            self.bg:SetColorTexture(1, 1, 1, item.card and 0.07 or 0.04)
            if item.tip then S.ShowTip(self, item.tip.title or item.text, item.tip.lines) end
        end)
        r:SetScript("OnLeave", function(self)
            local item = self.item
            self.bg:SetColorTexture(1, 1, 1, item and item.card and 0.03 or 0)
            S.HideTip()
        end)
        r:SetScript("OnMouseUp", function(self) if self.item and self.item.onClick then self.item.onClick() end end)
        pool[used] = r
        return r
    end

    local function Reset(r)
        for _, k in ipairs({ "dot", "meta", "text", "sub", "right", "line", "barBg", "bar" }) do
            r[k]:Hide()
            r[k]:ClearAllPoints()
        end
        r.bg:SetColorTexture(0, 0, 0, 0)
        for _, t in ipairs(r.tiles) do t:Hide() end
        r.item = nil
        r:EnableMouse(false)
    end

    -- Stat tiles: a row of small cards with a big number and a label.
    local function Tiles(r, tiles, width)
        local gap = 8
        local w = (width - gap * (#tiles - 1)) / #tiles
        for i, info in ipairs(tiles) do
            local t = r.tiles[i]
            if not t then
                t = CreateFrame("Frame", nil, r)
                S.Fill(t, { 1, 1, 1, 0.035 })
                t.value = S.Text(t, 20, C.text, S.TITLE)
                t.value:SetPoint("TOPLEFT", 12, -12)
                t.label = S.Text(t, 11, C.muted)
                t.label:SetPoint("BOTTOMLEFT", 12, 10)
                r.tiles[i] = t
            end
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", (i - 1) * (w + gap), 0)
            t:SetSize(w, 62)
            t.value:SetText(info.value)
            t.value:SetTextColor(unpack(info.colour or C.text))
            t.label:SetText(info.label)
            t:Show()
        end
    end

    function sf:SetItems(items)
        used = 0
        local width = math.max(200, (sf:GetWidth() or 560) - 12)
        local y = 0
        for i, item in ipairs(items) do
            local r = Row()
            Reset(r)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetWidth(width)
            local h
            r.item = item
            if item.type == "gap" then
                h = item.size or 10
            elseif item.type == "empty" then
                r.text:SetFont(S.BODY, 13, "")
                r.text:SetTextColor(unpack(C.muted))
                r.text:SetPoint("TOPLEFT", 10, -12)
                r.text:SetWidth(width - 20)
                r.text:SetText(item.text)
                r.text:Show()
                h = math.max(40, (r.text:GetStringHeight() or 14) + 24)
            elseif item.type == "tiles" then
                Tiles(r, item.tiles, width)
                h = 70
            elseif item.type == "header" then
                r.text:SetFont(S.TITLE, 13, "")
                r.text:SetTextColor(unpack(C.accent))
                r.text:SetPoint("BOTTOMLEFT", 2, 8)
                r.text:SetWidth(width - 120)
                r.text:SetText(item.text)
                r.text:Show()
                if item.right then
                    r.right:SetPoint("BOTTOMRIGHT", -2, 8)
                    r.right:SetText(item.right)
                    r.right:Show()
                end
                r.line:SetPoint("BOTTOMLEFT")
                r.line:SetPoint("BOTTOMRIGHT")
                r.line:Show()
                h = 34
            elseif item.type == "stat" then
                r.meta:SetFont(S.BODY, 12, "")
                r.meta:SetPoint("LEFT", 10, 0)
                r.meta:SetWidth(190)
                r.meta:SetText(item.label)
                r.meta:Show()
                r.text:SetFont(S.BODY, 13, "")
                r.text:SetTextColor(unpack(C.text))
                r.text:SetPoint("LEFT", 210, 0)
                r.text:SetWidth(width - 220)
                r.text:SetText(item.value)
                r.text:Show()
                if i % 2 == 0 then r.bg:SetColorTexture(1, 1, 1, 0.025) end
                h = 26
            elseif item.type == "bar" then
                r.meta:SetFont(S.BODY, 12, "")
                r.meta:SetPoint("LEFT", 10, 0)
                local labelW = item.labelWidth or 60
                r.meta:SetWidth(labelW)
                r.meta:SetWordWrap(false)
                r.meta:SetText(item.label)
                r.meta:Show()
                local left = labelW + 14
                local barW = width - left - (item.valueWidth or 96)
                r.barBg:SetPoint("LEFT", left, 0)
                r.barBg:SetSize(barW, 8)
                r.barBg:Show()
                r.bar:SetPoint("LEFT", left, 0)
                r.bar:SetSize(math.max(2, barW * math.min(1, item.fraction or 0)), 8)
                r.bar:SetColorTexture(unpack(item.colour or C.accent))
                r.bar:Show()
                r.right:SetPoint("RIGHT", -6, 0)
                r.right:SetText(item.value)
                r.right:Show()
                h = item.height or 20
                if item.tip then r:EnableMouse(true) end
            else -- an entry row
                local textLeft = item.meta and 122 or 18
                if item.dot then
                    r.dot:SetColorTexture(unpack(item.dot))
                    r.dot:SetPoint("TOPLEFT", 6, -11)
                    r.dot:Show()
                end
                if item.meta then
                    r.meta:SetFont(S.BODY, 11, "")
                    r.meta:SetPoint("TOPLEFT", 18, -8)
                    r.meta:SetWidth(100)
                    r.meta:SetText(item.meta)
                    r.meta:Show()
                end
                r.text:SetFont(S.BODY, 13, "")
                r.text:SetTextColor(unpack(item.colour or C.text))
                r.text:SetPoint("TOPLEFT", textLeft, -7)
                r.text:SetWidth(width - textLeft - (item.right and 110 or 10))
                r.text:SetText(item.text)
                r.text:Show()
                local textH = r.text:GetStringHeight() or 14
                local subH = 0
                if item.sub then
                    r.sub:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -3)
                    r.sub:SetWidth(width - textLeft - 10)
                    r.sub:SetText(item.sub)
                    r.sub:Show()
                    subH = (r.sub:GetStringHeight() or 11) + 3
                end
                if item.right then
                    r.right:SetPoint("TOPRIGHT", -8, -8)
                    r.right:SetText(item.right)
                    r.right:Show()
                end
                h = math.max(28, textH + subH + 14)
                if item.card then r.bg:SetColorTexture(1, 1, 1, 0.03) end
                if item.tip or item.onClick then r:EnableMouse(true) end
            end
            r:SetHeight(h)
            y = y + h + (item.card and 4 or 0)
        end
        for j = used + 1, #pool do pool[j]:Hide() end
        sf:SetContentHeight(y + 8)
    end

    return sf
end
