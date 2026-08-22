--[[
    KS_NPCSpawn.lua

    Deciding when and where an NPC should exist, as their cell streams in.

    This is the build plan's "read it, understand it, reimplement it" piece
    (section 2). The reference mod's CheckNPCSpawnPoint is hard-won knowledge
    about how PZ behaves when a square is blocked, and the shape below is that
    knowledge, written fresh:

      - try the NPC's own tile first, and only accept it if the engine agrees it
        is both a solid floor and free
      - failing that, widen to a small box and walk DOWN through the floors: a
        square that has lost its floor drops whatever stands on it, so the
        reachable ground is below, never above
      - failing that, retry for a while, because a cell that has only just begun
        streaming will report squares as neither solid nor free for a few ticks

    WHERE WE DELIBERATELY DIVERGE

    The reference mod ends with a last resort that deletes everything on the
    square and lays down a burnt floor tile to stand on. We do not do that by
    default, for two reasons:

      - it would happily delete the dressing we just placed on that square, and
        the dressing is the thing that makes the house look lived-in
      - they needed it because their NPC coordinates were authored blind. We have
        the coordinate readout and the dressing recorder, so we can stand on the
        tile and check it before writing it down

    It is still available per NPC via allowFloorFallback = true, for the case
    where a quest would otherwise be dead. It logs loudly when it fires.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

KS.NPCSpawn = KS.NPCSpawn or {}

-- How far to look around the nominal tile.
local SEARCH_RANGE = 3

-- How long to keep retrying a square that is not ready yet, in ticks.
local RETRY_TICKS = 120

-- Only one retry loop per NPC at a time.
local retrying = {}

--------------------------------------------------------------------------------
-- Finding somewhere to stand
--------------------------------------------------------------------------------

local function usable(square)
    return square ~= nil and square:isSolidFloor() and square:isFree(true)
end

-- Returns a square, or nil. Exposed for the tests.
function KS.NPCSpawn.findSpawnSquare(def, range)
    range = range or SEARCH_RANGE

    local cell = getCell()
    if not cell then
        return nil
    end

    local exact = cell:getGridSquare(def.x, def.y, def.z)
    if usable(exact) then
        return exact
    end

    if range <= 0 then
        return nil
    end

    -- Down through the floors, never up. Nearest ring first so an NPC does not
    -- teleport across a room when their own doorway is merely occupied.
    for z = def.z, 0, -1 do
        for radius = 1, range do
            for dx = -radius, radius do
                for dy = -radius, radius do
                    -- Only the edge of this ring; the inside was already tried.
                    if math.abs(dx) == radius or math.abs(dy) == radius then
                        local square = cell:getGridSquare(def.x + dx, def.y + dy, z)
                        if usable(square) then
                            return square
                        end
                    end
                end
            end
        end
    end

    return nil
end

--------------------------------------------------------------------------------
-- Asking for the spawn
--------------------------------------------------------------------------------

local function request(def, square)
    retrying[def.id] = nil

    return KS.Commands.send(KS.Commands.SPAWN_NPC, {
        npcId = def.id,
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
    })
end

-- Last resort, off unless the NPC asks for it. Clears the tile and lays a floor.
local function forceFloor(def)
    if not def.allowFloorFallback then
        KS.warn("npc '" .. def.id .. "' has nowhere to stand at "
            .. def.x .. "," .. def.y .. "," .. def.z
            .. ". Set allowFloorFallback on them, or move them to a clear tile.")
        return false
    end

    local cell = getCell()
    local square = cell and cell:getGridSquare(def.x, def.y, def.z)
    if not square then
        return false
    end

    KS.warn("npc '" .. def.id .. "': clearing " .. def.x .. "," .. def.y .. "," .. def.z
        .. " and laying a floor to stand on. Anything on that tile is gone, dressing included.")

    local objects = square:getObjects()
    for i = objects:size() - 1, 0, -1 do
        square:transmitRemoveItemFromSquare(objects:get(i))
    end

    square:AddSpecialObject(IsoObject.new(cell, square, "floors_burnt_01_0"))

    if usable(square) then
        return request(def, square)
    end

    return false
end

--------------------------------------------------------------------------------
-- The retry loop
--
-- A cell that has only just started streaming reports its squares as unusable
-- for a few ticks, so a single check on LoadGridsquare is not enough.
--------------------------------------------------------------------------------

local function beginRetry(def)
    if retrying[def.id] then
        return
    end

    local ticks = 0
    retrying[def.id] = true

    local function onTick()
        ticks = ticks + 1

        -- Someone else got there first, or the quest moved on.
        if KS.NPCServer and KS.NPCServer.isSpawned(def.id) then
            retrying[def.id] = nil
            Events.OnTick.Remove(onTick)
            return
        end

        local square = KS.NPCSpawn.findSpawnSquare(def)
        if square then
            Events.OnTick.Remove(onTick)
            request(def, square)
            return
        end

        if ticks >= RETRY_TICKS then
            Events.OnTick.Remove(onTick)
            retrying[def.id] = nil
            forceFloor(def)
        end
    end

    Events.OnTick.Add(onTick)
end

KS.NPCSpawn.beginRetry = beginRetry

--------------------------------------------------------------------------------
-- Entry point
--------------------------------------------------------------------------------

function KS.NPCSpawn.considerSquare(square)
    if not square then
        return
    end

    local def = KS.NPCs.atTile(square:getX(), square:getY())
    if not def then
        return
    end

    -- Phase 6: on a real client the server tree is absent and this becomes a
    -- question asked over the wire rather than answered locally.
    if not KS.NPCServer or KS.NPCServer.isSpawned(def.id) then
        return
    end

    local found = KS.NPCSpawn.findSpawnSquare(def)
    if found then
        request(def, found)
        return
    end

    KS.log("npc '" .. def.id .. "': no square ready yet, retrying")
    beginRetry(def)
end

Events.LoadGridsquare.Add(KS.NPCSpawn.considerSquare)
