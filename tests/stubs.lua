-- Stand-ins for the WoW API, just enough to load Forever Told outside the
-- game and drive it with fake events. Not a full emulation: frames record
-- what they're told (text, shown state, scripts) and everything else is a
-- no-op, so the tests check behaviour and data, not pixels.

-- Basic globals ---------------------------------------------------------------
local noop = function() end
local frameMT = {}
frameMT.__index = function(t, k)
  return function(self, ...) 
    if k == "CreateFontString" or k == "CreateTexture" then return setmetatable({}, frameMT) end
    if k == "GetAttribute" then return nil end
    if k == "SetScript" then rawset(self, "_" .. tostring(select(1, ...)), select(2, ...)) end
    if k == "GetText" then return "" end
    return nil end
end
FRAMES = {}
function CreateFrame() local f = setmetatable({}, frameMT) FRAMES[#FRAMES+1] = f return f end
UIParent = CreateFrame()
SlashCmdList = {}
PRINTED = {}
print = function(...) local t = {} for i=1,select('#',...) do t[#t+1]=tostring(select(i,...)) end PRINTED[#PRINTED+1]=table.concat(t," ") io.write(table.concat(t," "), "\n") end
C_Timer = { After = function(_, f) f() end, NewTicker = function() return { Cancel = noop } end }
UnitName = function() return "Craig" end
Ambiguate = function(n) return n end
GetZoneText = function() return "Elwynn Forest" end
GetSubZoneText = function() return "Goldshire" end
GetRealZoneText = GetZoneText
IsResting = function() return true end
IsInInstance = function() return false end
IsInGuild = function() return true end
UnitLevel = function() return 12 end
UnitClass = function() return "Warrior", "WARRIOR" end
GetUnitSpeed = function() return 0 end
GetTime = function() return os.time() end
Screenshot = noop
IsFishingLoot = function() return true end
GetNumLootItems = function() return 1 end
C_ChatInfo = { RegisterAddonMessagePrefix = noop, SendAddonMessage = noop }
SENT = {}
SendChatMessage = function(msg, chan) SENT[#SENT+1] = chan .. ": " .. msg end
C_ChatInfo.SendChatMessage = SendChatMessage
RandomRoll = noop
DoEmote = noop
RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
UIPanelScrollFrameTemplate = true
date = os.date
time = os.time

-- UI objects ------------------------------------------------------------------
local Obj = {}
Obj.__index = function(t, k)
  local m = rawget(Obj, k)
  if m then return m end
  return function() return nil end
end
local function new(kind) local o = setmetatable({ kind = kind, shown = true, scripts = {} }, Obj) ALLOBJ[#ALLOBJ+1] = o return o end
ALLOBJ = {}
function Obj:Show() self.shown = true if self.scripts.OnShow then self.scripts.OnShow(self) end end
function Obj:Hide() self.shown = false end
function Obj:IsShown() return self.shown end
function Obj:SetShown(v) if v then self:Show() else self:Hide() end end
function Obj:SetText(t) self.text = t if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
function Obj:GetText() return self.text end
function Obj:GetStringHeight() return 100 end
function Obj:GetWidth() return 140 end
function Obj:GetCenter() return 0, 0 end
function Obj:GetEffectiveScale() return 1 end
function Obj:GetFrameLevel() return 1 end
function Obj:GetText() return self.text end
function Obj:CreateFontString() return new("fs") end
function Obj:CreateTexture() return new("tex") end
function Obj:SetScript(name, f) self.scripts[name] = f end
function Obj:HookScript(name, f) local old = self.scripts[name] self.scripts[name] = function(...) if old then old(...) end f(...) end end
function Obj:Click(btn) if self.scripts.OnClick then self.scripts.OnClick(self, btn or "LeftButton") end end
FRAMES = {}
function CreateFrame(kind, name, parent, template)
  if template == "BasicFrameTemplateWithInset" and NO_BASIC then error("no template") end
  local o = new(kind) o.name = name o.template = template
  if name then _G[name] = o end
  FRAMES[#FRAMES+1] = o
  return o
end
UIParent = new("ui"); Minimap = new("minimap"); GameTooltip = new("tt")
function GameTooltip:AddLine(t) TT = (TT or "") .. tostring(t) .. "\n" end
GameTooltip_Hide = function() end
ChatFontNormal = {}
STANDARD_TEXT_FONT = "x"
GetCursorPosition = function() return 10, 10 end
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

-- The test world: a level 24 Human Warrior called Craig, in a guild, with a
-- hostile rogue (TARGETNAME) who can be made to target us. Time only moves
-- when a test moves NOWT.
unpack=table.unpack; IsInGroup=function() return false end; RequestTimePlayed=function() end; C_Map={GetBestMapForUnit=function() return 1 end, GetMapInfo=function() return {name="Duskwood", parentMapID=2, mapType=3} end}; IsInRaid=function() return false end; GetNumGroupMembers=function() return 0 end; IsMounted=function() return false end; UnitOnTaxi=function() return false end; issecretvalue=function() return false end; UnitGUID=function() return "me" end
ADDONMSG={}; C_ChatInfo = { RegisterAddonMessagePrefix=function() end, SendAddonMessage=function(p,m,c) ADDONMSG[#ADDONMSG+1]=m end }
tContains=function(t,v) for _,x in ipairs(t) do if x==v then return true end end return false end; CLASS_ICON_TCOORDS={ROGUE={0,0.25,0.5,0.75}}; WorldFrame=UIParent; CreateColor=function(...) return {...} end
UISpecialFrames = {}; tinsert = table.insert; GetMoney = function() return 123456 end
C_Item = {GetItemQualityByID = function(l) return 4 end}
C_QuestLog = {GetTitleForQuestID = function() return "The Fargodeep Mine" end}
RAID_CLASS_COLORS = { ROGUE = {r=1,g=0.96,b=0.41}, WARRIOR={r=0.78,g=0.61,b=0.43} }
UnitRace = function() return "Human" end
InCombatLockdown = function() return true end
UnitIsPlayer = function(u) return u ~= "player" end
UnitCanAttack = function(a,u) return u == "target" or u == "nameplate1" end
UnitIsUnit = function(a,b) return a == "nameplate1target" end
UnitExists = function(u) return u=="target" or u=="nameplate1" end
TARGETNAME = "Stabby"
UnitName = function(u) if u=="target" or u=="nameplate1" then return TARGETNAME, "" end return "Craig" end
UnitClass = function(u) if u=="player" then return "Warrior","WARRIOR" end return "Rogue","ROGUE" end
UnitLevel = function(u) if u=="player" then return 24 end return 30 end
GetGuildInfo = function(u) if u ~= "player" then return "Red Shirts" end end
UnitIsDead = function() return TDEAD end
COMBATLOG_HONORGAIN = "%s dies, honorable kill Rank: %s (Estimated Honor Points: %d)"
SOUNDKIT = {RAID_WARNING=1, UI_EPICLOOT_TOAST=2}; PlaySound = function() SOUNDS=(SOUNDS or 0)+1 end
NOWT = 1000; GetTime = function() return NOWT end
TICKS = {}
C_Timer = { After = function(_, f) f() end, NewTicker = function(_, f) TICKS[#TICKS+1]=f return {Cancel=function() end} end }

ReloadUI = function() RELOADED = true end
GetRealmName = function() return "Stormrage" end
