-- Forever Told backups: the whole story as one text code. Export copies it
-- out (keep it somewhere safe, or move it to another character); import
-- reads a code back in, replaces this character's journal and reloads.
--
-- The code is our own simple format, read by a strict parser, so a pasted
-- code can only ever become data, never run as code. A checksum catches
-- codes that got cut short when copying.

local _, ns = ...
local U, S = ns.U, ns.Skin
local C = S.colours
local Plural = U.Plural

local HEADER = "FTOLD1"
-- Window position and minimap button stay with this character.
local LOCAL_ONLY = { window = true, minimap = true }

-- Serialising ---------------------------------------------------------------------------

local function Finite(v) return v == v and v ~= math.huge and v ~= -math.huge end

local function Storable(v)
    local t = type(v)
    return t == "string" or t == "boolean" or t == "table" or (t == "number" and Finite(v))
end

local function Put(out, v)
    local t = type(v)
    if t == "number" then
        if v == math.floor(v) and v > -2 ^ 53 and v < 2 ^ 53 then
            out[#out + 1] = ("n%d;"):format(v)
        else
            out[#out + 1] = ("n%.17g;"):format(v)
        end
    elseif t == "string" then
        out[#out + 1] = "s" .. #v .. ":" .. v
    elseif t == "boolean" then
        out[#out + 1] = v and "t" or "f"
    elseif t == "table" then
        out[#out + 1] = "{"
        for k, x in pairs(v) do
            local tk = type(k)
            if (tk == "string" or (tk == "number" and Finite(k))) and Storable(x) then
                Put(out, k)
                Put(out, x)
            end
        end
        out[#out + 1] = "}"
    end
end

local function Serialise(v)
    local out = {}
    Put(out, v)
    return table.concat(out)
end

local MAX_DEPTH = 24

-- Returns the value, or nil if the text isn't exactly one well-formed value.
local function Parse(s)
    local pos, depth = 1, 0
    local Read
    function Read()
        local c = s:sub(pos, pos)
        if c == "n" then
            local e = s:find(";", pos, true)
            local n = e and tonumber(s:sub(pos + 1, e - 1))
            if not n then error("number") end
            pos = e + 1
            return n
        elseif c == "s" then
            local e = s:find(":", pos, true)
            local len = e and tonumber(s:sub(pos + 1, e - 1))
            if not len or len < 0 or len ~= math.floor(len) or e + len > #s then error("string") end
            pos = e + len + 1
            return s:sub(e + 1, e + len)
        elseif c == "t" or c == "f" then
            pos = pos + 1
            return c == "t"
        elseif c == "{" then
            depth = depth + 1
            if depth > MAX_DEPTH then error("depth") end
            pos = pos + 1
            local t = {}
            while true do
                if pos > #s then error("unfinished") end
                if s:sub(pos, pos) == "}" then pos = pos + 1 break end
                local k = Read()
                local v = Read()
                local tk = type(k)
                if tk ~= "string" and tk ~= "number" then error("key") end
                t[k] = v
            end
            depth = depth - 1
            return t
        end
        error("unknown")
    end
    local ok, v = pcall(Read)
    if ok and pos == #s + 1 then return v end
end

-- Base64, so the code survives chat boxes, forums and Discord -----------------------------

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_INDEX = {}
for i = 1, 64 do B64_INDEX[B64:byte(i)] = i - 1 end

local function Encode(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1, c2 = math.floor(n / 262144), math.floor(n / 4096) % 64
        local c3, c4 = math.floor(n / 64) % 64, n % 64
        out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
            .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

local function Decode(text)
    text = text:gsub("[^%w%+/]", "")
    local out = {}
    for i = 1, #text, 4 do
        local a, b, c, d = text:byte(i, i + 3)
        a, b = B64_INDEX[a], B64_INDEX[b]
        if not a or not b then break end
        c, d = c and B64_INDEX[c], d and B64_INDEX[d]
        local n = a * 262144 + b * 4096 + (c or 0) * 64 + (d or 0)
        local bytes = string.char(math.floor(n / 65536))
        if c then bytes = bytes .. string.char(math.floor(n / 256) % 256) end
        if d then bytes = bytes .. string.char(n % 256) end
        out[#out + 1] = bytes
    end
    return table.concat(out)
end

local function Checksum(s)
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + s:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end

-- Codes ---------------------------------------------------------------------------------

function ns.ExportCode()
    local DB, story = ns.DB, {}
    for k, v in pairs(DB) do if not LOCAL_ONLY[k] then story[k] = v end end
    local realm = GetRealmName and GetRealmName() or nil
    local payload = Serialise({
        v = 1, name = UnitName("player"), realm = realm, lvl = UnitLevel("player"),
        class = (UnitClass("player")), t = time(), db = story,
    })
    return ("%s:%08x:%s"):format(HEADER, Checksum(payload), Encode(payload))
end

-- Returns the backup table, or nil and a reason a person can act on.
function ns.ReadCode(code)
    code = (code or ""):gsub("%s", "")
    if code == "" then return nil end
    local header, sum, body = code:match("^(%w+):(%x+):(.+)$")
    if header ~= HEADER then return nil, "That isn't a Forever Told code." end
    local payload = Decode(body)
    if Checksum(payload) ~= tonumber(sum, 16) then
        return nil, "This code is incomplete. Copy the whole thing and try again."
    end
    local backup = Parse(payload)
    if type(backup) ~= "table" or type(backup.db) ~= "table" or type(backup.db.entries) ~= "table" then
        return nil, "This code is damaged and can't be read."
    end
    return backup
end

-- Swap in the imported story and reload, so every part of the addon starts
-- fresh from it. The saved data is written on the way out.
local function Restore(backup)
    local story = backup.db
    for k in pairs(LOCAL_ONLY) do story[k] = ns.DB[k] end
    ForeverToldDB = story
    ReloadUI()
end
ns.RestoreBackup = Restore

-- The dialog ----------------------------------------------------------------------------

local dialog

local function Describe(backup)
    local who = backup.name or "Someone"
    if backup.realm then who = who .. "-" .. backup.realm end
    return ("%s, level %d %s · %s · saved %s"):format(who, backup.lvl or 0, backup.class or "",
        Plural(#backup.db.entries, "entry", "entries"), date("%d %b %Y", backup.t or 0))
end

local function CreateDialog()
    local f = CreateFrame("Frame", "ForeverToldTransfer", UIParent)
    dialog = f
    f:SetSize(540, 420)
    f:SetPoint("CENTER", 0, 20)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ForeverToldTransfer")
    S.Fill(f, C.bg)
    S.Border(f, { 1, 1, 1, 0.12 })

    f.title = S.Text(f, 16, C.text, S.TITLE)
    f.title:SetPoint("TOPLEFT", 18, -16)
    f.hint = S.Text(f, 12, C.muted)
    f.hint:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)
    f.hint:SetWidth(500)
    f.hint:SetJustifyH("LEFT")

    local area = CreateFrame("Frame", nil, f)
    area:SetPoint("TOPLEFT", 18, -72)
    area:SetPoint("BOTTOMRIGHT", -18, 60)
    S.Fill(area, C.raised)
    S.Border(area, { 1, 1, 1, 0.10 })
    local scroll = CreateFrame("ScrollFrame", nil, area, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(0)
    edit:SetFont(S.BODY, 11, "")
    edit:SetTextColor(unpack(C.text))
    edit:SetWidth(460)
    scroll:SetScrollChild(edit)
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    area:EnableMouse(true)
    area:SetScript("OnMouseDown", function() edit:SetFocus() end)
    f.edit = edit

    f.status = S.Text(f, 12, C.muted)
    f.status:SetPoint("BOTTOMLEFT", 18, 24)
    f.status:SetWidth(300)
    f.status:SetJustifyH("LEFT")

    f.action = S.Button(f, "Replace my journal", 170, 26, "primary")
    f.action:SetPoint("BOTTOMRIGHT", -18, 16)
    f.close = S.Button(f, "Close", 80, 26)
    f.close:SetPoint("RIGHT", f.action, "LEFT", -8, 0)
    f.close:SetScript("OnClick", function() f:Hide() end)

    -- Import: check the code as it's pasted; the button asks twice.
    edit:SetScript("OnTextChanged", function(self, typed)
        if f.mode ~= "import" then return end
        f.backup, f.confirm = nil, false
        f.action:SetLabel("Replace my journal")
        local backup, err = ns.ReadCode(self:GetText())
        f.backup = backup
        f.action:SetShown(backup ~= nil)
        if backup then
            f.status:SetText("Ready: " .. Describe(backup))
            f.status:SetTextColor(unpack(C.text))
        else
            f.status:SetText(err or "Paste a code with Ctrl+V.")
            f.status:SetTextColor(unpack(err and C.danger or C.muted))
        end
    end)
    f.action:SetScript("OnClick", function()
        if not f.backup then return end
        if not f.confirm then
            f.confirm = true
            f.action:SetLabel("Click again to confirm")
            f.status:SetText("This replaces this character's whole journal, then reloads.")
            f.status:SetTextColor(unpack(C.danger))
            return
        end
        Restore(f.backup)
    end)
    f:Hide()
end

function ns.ShowTransfer(mode)
    if not dialog then CreateDialog() end
    local f = dialog
    f.mode = mode
    f.backup, f.confirm = nil, false
    f:Show()
    if mode == "export" then
        f.title:SetText("Export your story")
        f.hint:SetText("Press Ctrl+C to copy this code, then keep it somewhere safe. Import it to restore this journal, or to carry it over to another character.")
        f.action:Hide()
        local code = ns.ExportCode()
        f.edit:SetText(code)
        f.edit:SetFocus()
        f.edit:HighlightText()
        f.status:SetText(("%s · %s characters"):format(Plural(#ns.DB.entries, "entry", "entries"), #code))
        f.status:SetTextColor(unpack(C.muted))
    else
        f.title:SetText("Import a story")
        f.hint:SetText("Paste a Forever Told code with Ctrl+V. Importing replaces this character's journal, grudges and deeds, then reloads your interface.")
        f.action:Hide()
        f.edit:SetText("")
        f.edit:SetFocus()
        f.status:SetText("Paste a code with Ctrl+V.")
        f.status:SetTextColor(unpack(C.muted))
    end
end
