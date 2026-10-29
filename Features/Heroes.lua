-- Forever Told Hall of Heroes: every character you've written a story for.
-- Each character keeps its own journal; this account-wide list holds a short
-- summary of each one, written as you play, and the epitaph stone of any
-- Hardcore character that has fallen.

local _, ns = ...
local U = ns.U

local function Hall()
    ForeverToldAccountDB = ForeverToldAccountDB or {}
    local ADB = ForeverToldAccountDB
    ADB.heroes = ADB.heroes or {}
    return ADB.heroes
end

local function Key()
    local name = UnitName("player")
    local realm = GetRealmName and GetRealmName() or ""
    return realm ~= "" and (name .. "-" .. realm) or name, name, realm
end
ns.HeroKey = Key

-- Write this character's line in the hall.
function ns.SaveHero()
    local DB = ns.DB
    if not DB then return end
    local key, name, realm = Key()
    local hall = Hall()
    local h = hall[key] or {}
    hall[key] = h
    local className, classFile = UnitClass("player")
    h.name, h.realm = name, realm
    h.class, h.classFile = className, classFile
    h.race = UnitRace and UnitRace("player") or h.race
    h.level = UnitLevel("player")
    h.zone = ns.Zone()
    h.quests = DB.quests
    h.deeds = U.Count(DB.deeds)
    h.places = U.Count(DB.zones)
    h.played = ns.PlayedNow() or DB.lastPlayed or h.played
    h.began = h.began or (DB.entries[1] and DB.entries[1].t) or time()
    h.t = time()
    h.hardcore = ns.IsHardcore and ns.IsHardcore() or nil
    if DB.epitaph then h.epitaph = DB.epitaph end
end

-- Everyone in the hall, most recently played first.
function ns.Heroes()
    local list = {}
    for key, h in pairs(Hall()) do list[#list + 1] = { key = key, h = h } end
    table.sort(list, function(a, b) return (a.h.t or 0) > (b.h.t or 0) end)
    return list
end

function ns.ForgetHero(key)
    if key == Key() then return end -- you can't forget the character you're playing
    Hall()[key] = nil
end

ns.On("PLAYER_ENTERING_WORLD", function()
    ns.SaveHero()
    if ns.CheckDeeds then ns.CheckDeeds() end
end)
ns.On("PLAYER_LEVEL_UP", function() C_Timer.After(1, ns.SaveHero) end)
ns.On("PLAYER_LOGOUT", ns.SaveHero)
ns.Listen("epitaph", function() ns.SaveHero() end)
