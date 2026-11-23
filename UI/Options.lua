-- A page in the game's own Options (Esc, Options, AddOns), as players expect from an
-- addon. It points to Forever Told's own window, where its settings live.
-- Uses the Settings API where the client has it, and the older Interface Options otherwise.

local _, ns = ...

local function CloseGameMenus()
    for _, name in ipairs({ "SettingsPanel", "InterfaceOptionsFrame", "GameMenuFrame" }) do
        local f = _G[name]
        if f and f.IsShown and f:IsShown() and HideUIPanel then pcall(HideUIPanel, f) end
    end
end

local function Build()
    local panel = CreateFrame("Frame")
    panel.name = "Forever Told"
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Forever Told")
    local version = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    version:SetPoint("LEFT", title, "RIGHT", 8, -1)
    version:SetText(ns.Version())
    local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    text:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    text:SetJustifyH("LEFT")
    text:SetText("Your story, forever told. The journal, grudges, bounty board and guild chronicle "
        .. "are in Forever Told's own window, and so are its settings. Type /told, or click the book on your minimap.")
    local function Button(label, x, fn)
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(170, 24)
        b:SetPoint("TOPLEFT", text, "BOTTOMLEFT", x, -16)
        b:SetText(label)
        b:SetScript("OnClick", function() CloseGameMenus() fn() end)
        return b
    end
    Button("Open the journal", 0, function() ns.Open("journal") end)
    Button("Open settings", 180, function() ns.Open("settings") end)
    Button("What's new", 360, function() ns.Commands.new() end)
    return panel
end

function ns.RegisterOptions()
    local panel = Build()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, panel.name))
        ns.optionsHow = "Settings"
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        ns.optionsHow = "InterfaceOptions"
    end
    return panel
end

ns.On("PLAYER_LOGIN", ns.RegisterOptions)
