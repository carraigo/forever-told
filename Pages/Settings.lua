-- Settings page: built from ns.SETTINGS, plus window size and backups.

local _, ns = ...
local U, S, K = ns.U, ns.Skin, ns.PageKit
local C = S.colours

ns.Pages.settings = {
    title = "Settings", icon = "Interface\\Icons\\INV_Misc_Gear_01", noList = true, noSearch = true,
    subtitle = function() return "Choose what Forever Told does for you." end,
    build = function(p)
        local scroll = S.Scroll(p)
        scroll:SetAllPoints()
        local body = scroll.child
        local y = 0
        local controls = {}
        local function Header(text)
            local h = S.Text(body, 13, C.accent, S.TITLE)
            h:SetPoint("TOPLEFT", 0, -(y + (y > 0 and 14 or 0)))
            h:SetText(text)
            local line = body:CreateTexture(nil, "ARTWORK")
            line:SetColorTexture(unpack(C.line))
            line:SetHeight(1)
            line:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
            line:SetWidth(520)
            y = y + (y > 0 and 14 or 0) + 30
        end
        for _, s in ipairs(ns.SETTINGS) do
            if s.section then
                Header(s.section)
            else
                local t = S.Toggle(body, s.label, function() return ns.GetSetting(s) end, function(v) ns.SetSetting(s, v) end)
                t:SetPoint("TOPLEFT", 0, -y)
                controls[#controls + 1] = t
                y = y + 34
            end
        end
        Header("Backup")
        local export = S.Button(body, "Export my story", 140, 26, "primary")
        export:SetPoint("TOPLEFT", 0, -y)
        export:SetScript("OnClick", function() ns.ShowTransfer("export") end)
        local import = S.Button(body, "Import a story", 130, 26)
        import:SetPoint("LEFT", export, "RIGHT", 8, 0)
        import:SetScript("OnClick", function() ns.ShowTransfer("import") end)
        y = y + 34
        local backupTip = S.Text(body, 11, C.muted)
        backupTip:SetPoint("TOPLEFT", 0, -y)
        backupTip:SetWidth(520)
        backupTip:SetText("A text code holding your whole journal. Keep a copy somewhere safe, or import it on another character.")
        y = y + 30
        Header("Window")
        local scale = S.Segments(body, {
            { id = 0.9, label = "90%" }, { id = 1, label = "100%" }, { id = 1.1, label = "110%" }, { id = 1.25, label = "125%" },
        }, function() return ns.DB.window.scale or 1 end, function(v) ns.SetWindowScale(v) end, 64)
        scale:SetPoint("TOPLEFT", 0, -y)
        controls[#controls + 1] = scale
        local label = S.Text(body, 13, C.text)
        label:SetPoint("LEFT", scale, "RIGHT", 12, 0)
        label:SetText("Window size")
        y = y + 40
        local tip = S.Text(body, 11, C.muted)
        tip:SetPoint("TOPLEFT", 0, -y)
        tip:SetWidth(520)
        tip:SetText("Drag the window by its title, and resize it from the bottom-right corner. Drag the book on your minimap to move it; right-click it to jump to your stats.")
        y = y + 40
        local credit = S.Text(body, 11, C.muted)
        credit:SetPoint("TOPLEFT", 0, -y)
        credit:SetText("Forever Told · Author: SMUGDUCK")
        y = y + 24
        p.Update = function()
            scroll:SetContentHeight(y)
            for _, c in ipairs(controls) do c:Sync() end
        end
    end,
}
