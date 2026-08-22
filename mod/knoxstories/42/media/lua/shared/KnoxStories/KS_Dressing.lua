--[[
    KS_Dressing.lua

    Cell-load dressing: the barricades, broken furniture and empty tins that make
    an NPC's house look survived-in. Overview section 5 -- the player never sees
    it happen, they only find the result.

    THE POINT OF THE DATA FORMAT

    A dressing set records only what a person ADDED to a location, never the
    building itself. That is what makes it survive a map update: if The Indie
    Stone move a wall in Rosewood, our data still says "a tin can at 8041,11792"
    and that is still true. Recording the whole building would break on every
    patch.

    Format, as written by the in-game recorder:

        {
            id   = "ruth_house",
            area = { x1 = , y1 = , x2 = , y2 = , z1 = , z2 = },
            objects = { { x = , y = , z = , sprite = "..." }, ... },
            items   = { { x = , y = , z = , item = "Base.TinCan" }, ... },
        }

    'area' is only used by the recorder, to know what to re-scan. Applying uses
    the object and item lists alone.

    APPLYING ONCE

    A square is dressed the first time it loads and never again, tracked in world
    ModData. Without that, looting a dressed house and coming back would find the
    tins restored, which would read as a game mechanic rather than a place
    someone lived.

    The tracking is one entry per dressed square per set. For the pilot that is a
    few hundred entries; for the full 60-80 quests it would be a few thousand,
    which ModData carries comfortably. If that ever stops being true, the fix is
    to record a dressed-square count per set rather than the squares themselves.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

KS.DressingSets = KS.DressingSets or {}
KS.Dressing = KS.Dressing or {}

-- "x,y,z" -> { objects = {...}, items = {...}, setId = "..." }
local index = nil
local validated = false
local validCount, invalidCount = 0, 0

local function key(x, y, z)
    return x .. "," .. y .. "," .. z
end

KS.Dressing.key = key

--------------------------------------------------------------------------------
-- Validation
--------------------------------------------------------------------------------

local function invalidate(def, reason)
    def.invalid = true
    KS.warn("dressing set '" .. tostring(def.id or "<no id>") .. "' was skipped: " .. reason)
end

local function validatePlacements(def, list, what, field)
    for i = 1, #list do
        local p = list[i]
        if type(p.x) ~= "number" or type(p.y) ~= "number" or type(p.z) ~= "number" then
            invalidate(def, what .. " number " .. i .. " has no x, y and z")
            return false
        end
        if type(p[field]) ~= "string" or p[field] == "" then
            invalidate(def, what .. " number " .. i .. " has no '" .. field .. "'")
            return false
        end
    end
    return true
end

local function validateSet(def, seenIds)
    if type(def.id) ~= "string" or def.id == "" then
        invalidate(def, "it has no id")
        return
    end
    if seenIds[def.id] then
        invalidate(def, "another dressing set already uses the id '" .. def.id .. "'")
        return
    end
    seenIds[def.id] = true

    def.objects = def.objects or {}
    def.items = def.items or {}

    if #def.objects == 0 and #def.items == 0 then
        invalidate(def, "it places nothing")
        return
    end

    if not validatePlacements(def, def.objects, "object", "sprite") then return end
    if not validatePlacements(def, def.items, "item", "item") then return end

    def.invalid = false
end

function KS.Dressing.ensureValidated()
    if validated then
        return validCount, invalidCount
    end
    validated = true

    local seenIds = {}
    validCount = 0
    index = {}

    for i = 1, #KS.DressingSets do
        local def = KS.DressingSets[i]
        validateSet(def, seenIds)

        if not def.invalid then
            validCount = validCount + 1

            for j = 1, #def.objects do
                local p = def.objects[j]
                local k = key(p.x, p.y, p.z)
                index[k] = index[k] or { objects = {}, items = {}, setId = def.id }
                table.insert(index[k].objects, p)
            end

            for j = 1, #def.items do
                local p = def.items[j]
                local k = key(p.x, p.y, p.z)
                index[k] = index[k] or { objects = {}, items = {}, setId = def.id }
                table.insert(index[k].items, p)
            end
        end
    end

    invalidCount = #KS.DressingSets - validCount
    return validCount, invalidCount
end

function KS.Dressing.all()
    KS.Dressing.ensureValidated()
    return KS.DressingSets
end

function KS.Dressing.forSquare(x, y, z)
    KS.Dressing.ensureValidated()
    return index[key(x, y, z)]
end

--------------------------------------------------------------------------------
-- Applying
--
-- Split from the event hook so it can be driven directly by a test.
--------------------------------------------------------------------------------

-- Has this square already been dressed by this set?
local function alreadyDressed(setId, k)
    local world = KS.State and KS.State.get()
    if not world then
        return false
    end

    world.dressed = world.dressed or {}
    return world.dressed[setId] ~= nil and world.dressed[setId][k] == true
end

local function markDressed(setId, k)
    local world = KS.State and KS.State.get()
    if not world then
        return
    end

    world.dressed = world.dressed or {}
    world.dressed[setId] = world.dressed[setId] or {}
    world.dressed[setId][k] = true
end

-- square is an IsoGridSquare. Returns the number of things placed.
function KS.Dressing.applyToSquare(square)
    if not square then
        return 0
    end

    local x, y, z = square:getX(), square:getY(), square:getZ()
    local entry = KS.Dressing.forSquare(x, y, z)
    if not entry then
        return 0
    end

    local k = key(x, y, z)
    if alreadyDressed(entry.setId, k) then
        return 0
    end

    local placed = 0

    for i = 1, #entry.objects do
        local object = IsoObject.new(square:getCell(), square, entry.objects[i].sprite)
        square:AddSpecialObject(object)
        placed = placed + 1
    end

    for i = 1, #entry.items do
        square:AddWorldInventoryItem(entry.items[i].item, 0.0, 0.0, 0.0)
        placed = placed + 1
    end

    markDressed(entry.setId, k)

    if placed > 0 then
        KS.log("dressed " .. k .. " with " .. placed .. " thing(s) from '" .. entry.setId .. "'")
    end

    return placed
end
