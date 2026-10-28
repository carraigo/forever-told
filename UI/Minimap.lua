-- Forever Told minimap button (drag it around the minimap edge) and the
-- addon compartment entry on clients that have one.

local _, ns = ...

local button

local function Position()
    local angle = math.rad(ns.DB.minimap.angle or 200)
    local radius = (Minimap:GetWidth() / 2) + 6
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function DragUpdate()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / scale, cy / scale
    ns.DB.minimap.angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
    Position()
end

local function Tooltip(self)
    local DB, U = ns.DB, ns.U
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Forever Told")
    GameTooltip:AddLine(("%d entries · %d places · %d quests"):format(#DB.entries, U.Count(DB.zones), DB.quests), 1, 1, 1)
    local open = 0
    for _, g in pairs(DB.grudges) do if ns.GrudgeOpen(g) then open = open + 1 end end
    if open > 0 then GameTooltip:AddLine(("%s unsettled"):format(U.Plural(open, "grudge")), 0.92, 0.36, 0.30) end
    local last = DB.entries[#DB.entries]
    if last then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Latest:", 0.79, 0.64, 0.15)
        GameTooltip:AddLine(U.Plain(last.text), 0.9, 0.9, 0.9, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: open your journal", 0.6, 0.8, 1)
    GameTooltip:AddLine("Right-click: your stats", 0.6, 0.8, 1)
    GameTooltip:AddLine("Drag: move this button", 0.6, 0.8, 1)
    GameTooltip:Show()
end

function ns.UpdateMinimapButton()
    if not button then return end
    if ns.DB.minimap.hidden then button:Hide() else button:Show() Position() end
end

function ns.CreateMinimapButton()
    if button or not Minimap then return end
    button = CreateFrame("Button", "ForeverToldMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexture(ns.ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then ns.Toggle("stats") else ns.Toggle("journal") end
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", DragUpdate)
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", Tooltip)
    button:SetScript("OnLeave", GameTooltip_Hide)

    ns.UpdateMinimapButton()
end

-- Named in the .toc as AddonCompartmentFunc (WoW Forever's addon menu by the minimap).
function ForeverTold_OnAddonCompartmentClick(_, mouse)
    if mouse == "RightButton" then ns.Toggle("stats") else ns.Toggle("journal") end
end
