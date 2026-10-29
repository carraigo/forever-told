-- Forever Told shared helpers, used by every other file.

local _, ns = ...

local U = {}
ns.U = U

U.issecret = issecretvalue or function() return false end

function U.Count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

function U.Plural(n, one, many)
    return ("%d %s"):format(n, n == 1 and one or (many or one .. "s"))
end

function U.Pick(list) return list[math.random(#list)] end

-- "Name-Realm" -> "Name"
function U.Short(name) return (name:gsub("%-.*$", "")) end

-- Strip links and colour codes, for plain-text output and searching.
function U.Plain(s)
    return (s:gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

function U.Hex(hex)
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, 1 }
end

function U.ClassColour(classFile, fallback)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then return { c.r, c.g, c.b, 1 } end
    return fallback or { 0.94, 0.93, 0.89, 1 }
end

-- 3412 -> "3,412"
function U.Number(n)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

function U.Duration(sec)
    if not sec then return "unknown" end
    sec = math.floor(sec)
    local d, h, m = math.floor(sec / 86400), math.floor(sec % 86400 / 3600), math.floor(sec % 3600 / 60)
    if d > 0 then return ("%dd %dh"):format(d, h) end
    if h > 0 then return ("%dh %02dm"):format(h, m) end
    return ("%dm"):format(math.max(1, m))
end

function U.Ago(t)
    local s = time() - (t or 0)
    if s < 90 then return "just now" end
    if s < 3600 then return U.Plural(math.floor(s / 60), "minute") .. " ago" end
    if s < 86400 then return U.Plural(math.floor(s / 3600), "hour") .. " ago" end
    return U.Plural(math.floor(s / 86400), "day") .. " ago"
end

function U.Money(copper)
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    return ("%dg"):format(math.floor(copper / 10000))
end

