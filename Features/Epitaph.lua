-- Forever Told epitaph: on a Classic Era Hardcore character, death is the
-- end of the story. The journal closes with a final line and a memorial
-- stone that sums up the whole journey. /told epitaph shows the stone; on a
-- character that's still standing it shows how it would read today.

local _, ns = ...
local U, S = ns.U, ns.Skin
local Count, Plural = U.Count, U.Plural

local STONE = { 0.33, 0.33, 0.35, 1 }
local CARVED = { 0.86, 0.84, 0.78, 1 }
local CARVED_SOFT = { 0.86, 0.84, 0.78, 0.6 }
local LATIN = { enUS = true, enGB = true, deDE = true, frFR = true, esES = true, esMX = true, itIT = true, ptBR = true }
local FONT = LATIN[GetLocale and GetLocale() or "enUS"] and "Fonts\\MORPHEUS.TTF" or STANDARD_TEXT_FONT

local CLOSINGS = {
    "Their story is told.",
    "Gone, but forever told.",
    "The road ends here. The tale does not.",
    "May the next one go further.",
}

function ns.IsHardcore()
    if C_GameRules and C_GameRules.IsHardcoreActive then
        local ok, on = pcall(C_GameRules.IsHardcoreActive)
        if ok and on then return true end
    end
    if C_Seasons and C_Seasons.GetActiveSeason and Enum and Enum.SeasonID and Enum.SeasonID.Hardcore then
        local ok, season = pcall(C_Seasons.GetActiveSeason)
        if ok and season == Enum.SeasonID.Hardcore then return true end
    end
    return false
end

-- What killed us comes from the foe tracker, which has already run for this death.
local function Cause() return ns.lastFoe end

-- Everything the stone says, from the journal as it stands.
local function Summary(cause)
    local DB = ns.DB
    local dungeons = 0
    for _, z in pairs(DB.zones) do if z.instance then dungeons = dungeons + 1 end end
    return {
        t = time(), name = UnitName("player"), lvl = UnitLevel("player"),
        race = UnitRace and UnitRace("player") or nil, class = (UnitClass("player")),
        zone = ns.Zone(), cause = cause, played = ns.PlayedNow() or DB.lastPlayed,
        began = DB.entries[1] and DB.entries[1].t,
        quests = DB.quests, places = Count(DB.zones), dungeons = dungeons, bosses = Count(DB.bosses),
        friends = Count(DB.fellows), deeds = Count(DB.deeds),
    }
end

-- The stone -----------------------------------------------------------------------------

local stone

local function Carve(parent, size, colour, font)
    local fs = S.Text(parent, size, colour or CARVED, font or FONT)
    fs:SetJustifyH("CENTER")
    if fs.SetShadowColor then
        fs:SetShadowColor(0, 0, 0, 0.9)
        fs:SetShadowOffset(1, -1)
    end
    return fs
end

local function CreateStone()
    local f = CreateFrame("Frame", "ForeverToldEpitaph", UIParent)
    stone = f
    f:SetSize(340, 470)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ForeverToldEpitaph")
    S.Fill(f, STONE)
    S.Border(f, { 0.18, 0.18, 0.19, 1 })
    local inner = CreateFrame("Frame", nil, f)
    inner:SetPoint("TOPLEFT", 12, -12)
    inner:SetPoint("BOTTOMRIGHT", -12, 12)
    S.Border(inner, { 0.55, 0.55, 0.57, 0.6 })

    f.kicker = Carve(f, 20)
    f.kicker:SetPoint("TOP", 0, -34)
    f.skull = f:CreateTexture(nil, "ARTWORK")
    f.skull:SetSize(28, 28)
    f.skull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    f.skull:SetVertexColor(0.86, 0.84, 0.78)
    f.skull:SetPoint("TOP", f.kicker, "BOTTOM", 0, -10)
    f.name = Carve(f, 36)
    f.name:SetPoint("TOP", f.skull, "BOTTOM", 0, -10)
    f.who = Carve(f, 13, CARVED, STANDARD_TEXT_FONT)
    f.who:SetPoint("TOP", f.name, "BOTTOM", 0, -6)
    f.fell = Carve(f, 15)
    f.fell:SetPoint("TOP", f.who, "BOTTOM", 0, -18)
    f.fell:SetWidth(280)
    f.fell:SetSpacing(3)
    f.date = Carve(f, 12, CARVED_SOFT, STANDARD_TEXT_FONT)
    f.date:SetPoint("TOP", f.fell, "BOTTOM", 0, -8)
    local rule = f:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(0.86, 0.84, 0.78, 0.35)
    rule:SetSize(220, 1)
    rule:SetPoint("TOP", f.date, "BOTTOM", 0, -16)
    f.life = Carve(f, 12, CARVED, STANDARD_TEXT_FONT)
    f.life:SetPoint("TOP", rule, "BOTTOM", 0, -14)
    f.life:SetWidth(280)
    f.life:SetSpacing(4)
    f.closing = Carve(f, 16)
    f.closing:SetPoint("BOTTOM", 0, 34)
    f.closing:SetWidth(280)

    local close = CreateFrame("Button", nil, f)
    close:SetSize(26, 26)
    close:SetPoint("TOPRIGHT", -16, -16)
    local x = Carve(close, 20, CARVED_SOFT, STANDARD_TEXT_FONT)
    x:SetPoint("CENTER")
    x:SetText("×")
    close:SetScript("OnEnter", function() x:SetTextColor(unpack(CARVED)) end)
    close:SetScript("OnLeave", function() x:SetTextColor(unpack(CARVED_SOFT)) end)
    close:SetScript("OnClick", function() f:Hide() end)
    f:Hide()
end

local function Fill(e, preview)
    local f = stone
    f.kicker:SetText(preview and "IF YOU FELL TODAY" or "HERE LIES")
    f.name:SetText((e.name or "?"):upper())
    local who = ("Level %d %s%s"):format(e.lvl or 0, e.race and (e.race .. " ") or "", e.class or "")
    f.who:SetText(who)
    f.fell:SetText(("Fell in %s%s"):format(e.zone or "somewhere unknown", e.cause and ("\nto " .. e.cause) or ""))
    f.date:SetText(date("%d %B %Y", e.t))
    local lines = {}
    if e.played then lines[#lines + 1] = "Adventured for " .. U.Duration(e.played) end
    if e.began then lines[#lines + 1] = "Set out on " .. date("%d %B %Y", e.began) end
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("%s · %s · %s"):format(Plural(e.quests or 0, "quest"), Plural(e.places or 0, "place"), Plural(e.friends or 0, "friend"))
    lines[#lines + 1] = ("%s · %s · %s"):format(Plural(e.dungeons or 0, "dungeon"), Plural(e.bosses or 0, "boss", "bosses"), Plural(e.deeds or 0, "deed"))
    f.life:SetText(table.concat(lines, "\n"))
    local n = 0
    for i = 1, #(e.name or "") do n = n + e.name:byte(i) end
    f.closing:SetText(CLOSINGS[n % #CLOSINGS + 1])
end

function ns.ShowEpitaph()
    if not stone then CreateStone() end
    local e = ns.DB.epitaph
    Fill(e or Summary(nil), not e)
    stone:Show()
end

-- The end -------------------------------------------------------------------------------

ns.On("PLAYER_DEAD", function()
    if ns.DB.epitaph or not ns.IsHardcore() then return end
    local cause = Cause()
    -- Let the other death handlers write first, so the tallies are complete.
    C_Timer.After(0.5, function()
        if ns.DB.epitaph then return end
        local e = Summary(cause)
        ns.DB.epitaph = e
        ns.Add("epitaph", ("The end. %s fell at level %d in %s%s."):format(e.name, e.lvl, e.zone, cause and (", to " .. cause) or ""))
        ns.Emit("epitaph", e)
        ns.ShowEpitaph()
    end)
end)
