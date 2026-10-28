-- Forever Told window: a flat, dark, resizable window with a sidebar, a
-- header with search, and one page at a time. The pages are in Pages\.

local _, ns = ...
local U, S = ns.U, ns.Skin
local C = S.colours

local WIDTH, HEIGHT, SIDEBAR = 820, 580, 188
local MIN_W, MIN_H, MAX_W, MAX_H = 700, 460, 1200, 900

local window
local pages, nav = {}, {}
local current = "journal"
local search = {}            -- search text per page
local needsRefresh = false

-- Search -----------------------------------------------------------------------------
-- Every list page can be searched: rows that don't match are hidden, and so
-- are headers left with nothing under them.

local function Matches(item, needle)
    local hay = table.concat({ item.text or "", item.sub or "", item.meta or "", item.right or "",
        item.search or "", item.label or "", item.value or "" }, " ")
    return U.Plain(hay):lower():find(needle, 1, true) ~= nil
end

local function Filter(items, needle)
    if needle == "" then return items end
    local out, header = {}, nil
    for _, item in ipairs(items) do
        if item.type == "header" then
            header = item
        elseif item.type == nil or item.type == "stat" or item.type == "bar" then
            if Matches(item, needle) then
                if header then
                    if #out > 0 then out[#out + 1] = { type = "gap", size = 6 } end
                    out[#out + 1] = header
                    header = nil
                end
                out[#out + 1] = item
            end
        end
    end
    if #out == 0 then out[1] = { type = "empty", text = ("Nothing matches \"%s\"."):format(needle) } end
    return out
end

-- Window -----------------------------------------------------------------------------

local function SavePosition()
    local point, _, rel, x, y = window:GetPoint()
    local w = ns.DB.window
    w.point, w.rel, w.x, w.y = point, rel, x, y
    w.w, w.h = window:GetWidth(), window:GetHeight()
end

function ns.SetWindowScale(v)
    ns.DB.window.scale = v
    if window then window:SetScale(v) end
end

local function Select(id)
    current = id
    for pid, page in pairs(pages) do page:SetShown(pid == id) end
    for pid, b in pairs(nav) do b:SetSelected(pid == id) end
    local def = ns.Pages[id]
    window.search:SetShown(not def.noSearch)
    window.search:SetText(search[id] or "")
    ns.Refresh()
end

local function CreateSidebar(f)
    local side = CreateFrame("Frame", nil, f)
    side:SetPoint("TOPLEFT")
    side:SetPoint("BOTTOMLEFT")
    side:SetWidth(SIDEBAR)
    S.Fill(side, C.panel)
    local divider = side:CreateTexture(nil, "BORDER")
    divider:SetColorTexture(unpack(C.line))
    divider:SetWidth(1)
    divider:SetPoint("TOPRIGHT")
    divider:SetPoint("BOTTOMRIGHT")

    local icon = side:CreateTexture(nil, "ARTWORK")
    icon:SetSize(34, 34)
    icon:SetPoint("TOPLEFT", 16, -18)
    icon:SetTexture(ns.ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local brand = S.Text(side, 15, C.accent, S.TITLE)
    brand:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -1)
    brand:SetText("Forever Told")
    f.who = S.Text(side, 11, C.muted)
    f.who:SetPoint("TOPLEFT", brand, "BOTTOMLEFT", 0, -3)
    f.who:SetWidth(SIDEBAR - 70)
    f.who:SetWordWrap(false)

    local prev
    for _, id in ipairs(ns.PAGE_ORDER) do
        local def = ns.Pages[id]
        local b = S.Button(side, def.title, SIDEBAR - 1, 32, "nav")
        b.icon:SetTexture(def.icon)
        if id == "settings" then
            b:SetPoint("BOTTOMLEFT", 0, 12)
        else
            if prev then b:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2) else b:SetPoint("TOPLEFT", 0, -76) end
            prev = b
        end
        b:SetScript("OnClick", function() Select(id) end)
        nav[id] = b
    end

    -- Chapter progress, just above Settings.
    local prog = CreateFrame("Frame", nil, side)
    prog:SetPoint("BOTTOMLEFT", 16, 58)
    prog:SetPoint("BOTTOMRIGHT", -16, 58)
    prog:SetHeight(34)
    prog.label = S.Text(prog, 11, C.muted)
    prog.label:SetPoint("TOPLEFT")
    prog.label:SetWidth(SIDEBAR - 32)
    prog.label:SetWordWrap(false)
    prog.track = prog:CreateTexture(nil, "ARTWORK")
    prog.track:SetColorTexture(1, 1, 1, 0.08)
    prog.track:SetHeight(4)
    prog.track:SetPoint("BOTTOMLEFT", 0, 6)
    prog.track:SetPoint("BOTTOMRIGHT", 0, 6)
    prog.fill = prog:CreateTexture(nil, "OVERLAY")
    prog.fill:SetColorTexture(unpack(C.accent))
    prog.fill:SetHeight(4)
    prog.fill:SetPoint("BOTTOMLEFT", 0, 6)
    f.progress = prog
end

local function UpdateSidebar()
    local level = UnitLevel("player")
    local c = ns.ChapterOf(level)
    window.who:SetText(("%s · level %d"):format(UnitName("player"), level))
    local prog = window.progress
    if c >= 6 then
        prog.label:SetText("Chapter 7 · " .. ns.CHAPTERS[6])
        prog.fill:SetWidth(SIDEBAR - 32)
    else
        local xp, maxXP = UnitXP and UnitXP("player") or 0, UnitXPMax and UnitXPMax("player") or 1
        local start = math.max(1, c * 10)
        local done = (level - start + (maxXP > 0 and xp / maxXP or 0)) / (c * 10 + 10 - start)
        prog.label:SetText(("Chapter %d · %d to go"):format(c + 1, c * 10 + 10 - level))
        prog.fill:SetWidth(math.max(1, (SIDEBAR - 32) * math.min(1, done)))
    end
    for id, b in pairs(nav) do
        local def = ns.Pages[id]
        if def.badge then b:SetBadge(def.badge()) else b:SetBadge(nil) end
    end
end

local function CreateHeader(f)
    f.title = S.Text(f, 20, C.text, S.TITLE)
    f.title:SetPoint("TOPLEFT", SIDEBAR + 24, -20)
    f.subtitle = S.Text(f, 12, C.muted)
    f.subtitle:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)

    local close = CreateFrame("Button", nil, f)
    close:SetSize(28, 28)
    close:SetPoint("TOPRIGHT", -10, -10)
    local x = S.Text(close, 18, C.muted)
    x:SetPoint("CENTER")
    x:SetText("×")
    close:SetScript("OnEnter", function() x:SetTextColor(unpack(C.text)) end)
    close:SetScript("OnLeave", function() x:SetTextColor(unpack(C.muted)) end)
    close:SetScript("OnClick", function() f:Hide() end)

    f.search = S.Input(f, 190, "Search")
    f.search:SetPoint("TOPRIGHT", -46, -22)
    f.search:HookScript("OnTextChanged", function(self)
        search[current] = self:GetText() or ""
        needsRefresh = true
    end)
end

local function CreateResizeGrip(f)
    if not f.SetResizable then return end
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
    elseif f.SetMinResize then f:SetMinResize(MIN_W, MIN_H) f:SetMaxResize(MAX_W, MAX_H) end
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    -- Three short diagonal lines, drawn rather than borrowed from Blizzard art.
    for i = 1, 3 do
        local line = grip:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(1, 1, 1, 0.25)
        line:SetSize(i * 4 + 2, 1)
        line:SetPoint("BOTTOMRIGHT", -1, i * 3 - 1)
        if line.SetRotation then line:SetRotation(math.rad(45)) end
    end
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        SavePosition()
    end)
end

local function CreateWindow()
    local f = CreateFrame("Frame", "ForeverToldFrame", UIParent)
    window = f
    local saved = ns.DB.window
    f:SetSize(saved.w or WIDTH, saved.h or HEIGHT)
    if saved.point then f:SetPoint(saved.point, UIParent, saved.rel or saved.point, saved.x or 0, saved.y or 0) else f:SetPoint("CENTER") end
    f:SetScale(saved.scale or 1)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    S.Fill(f, C.bg)
    S.Border(f, { 1, 1, 1, 0.10 })
    tinsert(UISpecialFrames, "ForeverToldFrame") -- Escape closes it

    CreateSidebar(f)
    CreateHeader(f)
    CreateResizeGrip(f)

    for _, id in ipairs(ns.PAGE_ORDER) do
        local def = ns.Pages[id]
        local p = CreateFrame("Frame", nil, f)
        p:SetPoint("TOPLEFT", SIDEBAR + 24, -74)
        p:SetPoint("BOTTOMRIGHT", -20, 18)
        if not def.noList then
            p.list = S.List(p)
            p.list:SetPoint("TOPLEFT")
            p.list:SetPoint("BOTTOMRIGHT")
        end
        if def.build then def.build(p) end
        if def.items then
            p.Update = function()
                if def.update and def.update(p) then return end
                p.list:SetItems(Filter(def.items(p), (search[id] or ""):lower()))
            end
        end
        p:Hide()
        pages[id] = p
    end

    -- Refresh at most once a frame, after typing or resizing.
    f:SetScript("OnSizeChanged", function() needsRefresh = true end)
    f:SetScript("OnUpdate", function(self, elapsed)
        if self.fade and self.fade < 1 then
            self.fade = math.min(1, self.fade + (elapsed or 0.016) * 7)
            self:SetAlpha(self.fade)
        end
        if needsRefresh then
            needsRefresh = false
            ns.Refresh()
        end
    end)
    f:SetScript("OnShow", function(self)
        self.fade = 0
        self:SetAlpha(0)
        ns.Refresh()
    end)
    f:SetScript("OnHide", S.HideTip)
    f:Hide()
end

function ns.Refresh()
    if not window or not window:IsShown() then return end
    UpdateSidebar()
    local def = ns.Pages[current]
    window.title:SetText(def.title)
    window.subtitle:SetText(def.subtitle and def.subtitle() or "")
    local page = pages[current]
    if page and page.Update then page.Update() end
end

-- tab: a page id or an alias such as "bounties"; sub: a view inside the page.
function ns.Open(tab, sub)
    if not window then CreateWindow() end
    local alias = tab and ns.PAGE_ALIASES[tab]
    if alias then tab, sub = alias[1], alias[2] end
    if tab and not ns.Pages[tab] then tab = nil end
    tab = tab or current
    window:Show()
    if ns.Pages[tab].open then ns.Pages[tab].open(pages[tab], sub) end
    Select(tab)
end

function ns.Toggle(tab)
    if window and window:IsShown() and (not tab or tab == current) then
        window:Hide()
    else
        ns.Open(tab)
    end
end
