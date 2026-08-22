--[[
    KS_NPCServer.lua

    Creating the zombie that is pretending to be a person, and keeping the
    world's record of which ones exist.

    Architecture 6.2 puts world mutation on the server and the decision of *when*
    on the client. That split is kept: KS_NPCSpawn decides a square is ready and
    asks; this file does the spawning. In single-player both trees share a
    process, so the ask is a direct call through KS.Commands.

    WHAT MAKES A ZOMBIE READ AS A PERSON

    Confirmed against the reference mod's own suppression routine. Each of these
    is doing a specific job and dropping any one of them breaks the illusion:

        setCanWalk(false)       stands still instead of shambling toward you
        setVariable(anim, true) picks the human animation nodes we lifted
        setInvulnerable(true)   cannot be killed by accident, or by the horde
        setNoTeeth(true)        cannot infect anyone who walks past
        setUseless(true)        the AI stops treating it as a threat actor
        voice prefix cleared    no groaning
        emitter stopped         no lingering zombie noise
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

KS.NPCServer = KS.NPCServer or {}

--------------------------------------------------------------------------------
-- World record of who is spawned
--
-- Lives alongside quest state, so it saves and reloads with everything else.
-- 'spawned' is not durable truth -- zombies do not survive a cell unloading --
-- so it is cleared on load rather than trusted across sessions.
--------------------------------------------------------------------------------

local function npcState()
    local world = KS.State.get()
    world.npcs = world.npcs or {}
    return world.npcs
end

function KS.NPCServer.isSpawned(npcId)
    local record = npcState()[npcId]
    return record ~= nil and record.spawned == true
end

-- Live references to the zombies we are pretending are people.
--
-- Held directly rather than looked up, because every route to finding them again
-- goes through something unverifiable: ModData that the engine recycles between
-- zombies, or an event that may not exist in this build. A reference we were
-- handed at creation is the one thing we can be sure of.
KS.NPCServer.live = KS.NPCServer.live or {}

function KS.NPCServer.recordSpawned(npcId, zombie)
    KS.NPCServer.live[npcId] = zombie
    npcState()[npcId] = {
        spawned = true,
        x = math.floor(zombie:getX()),
        y = math.floor(zombie:getY()),
        z = math.floor(zombie:getZ()),
    }
end

function KS.NPCServer.clearSpawnRecords()
    local npcs = npcState()
    local cleared = 0

    for id, record in pairs(npcs) do
        if record.spawned then
            record.spawned = false
            cleared = cleared + 1
        end
    end

    KS.NPCServer.live = {}

    if cleared > 0 then
        KS.log("cleared " .. cleared .. " stale npc spawn record(s)")
    end
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Spawning
--------------------------------------------------------------------------------

-- Is this NPC already standing on the square? Only the tile is checked, which
-- is where a persisted one would be -- a broader sweep would mean walking the
-- whole cell on every spawn attempt.
function KS.NPCServer.findExistingAt(npcId, x, y, z)
    local cell = getCell()
    local square = cell and cell:getGridSquare(x, y, z)
    if not square then
        return nil
    end

    local movingObjects = square:getMovingObjects()
    for i = 0, movingObjects:size() - 1 do
        local candidate = movingObjects:get(i)
        if KS.NPCs.idOf(candidate) == npcId then
            return candidate
        end
    end

    return nil
end

-- payload: { npcId = "diane", x = , y = , z = }
-- x/y/z is the square the client found, which may not be the NPC's nominal tile
-- if that one was blocked.
local function spawnNPC(payload)
    local ok, reason = KS.Commands.validators[KS.Commands.SPAWN_NPC](payload)
    if not ok then
        KS.warn("rejected SpawnNPC: " .. tostring(reason))
        return false
    end

    local def = KS.NPCs.get(payload.npcId)

    if KS.NPCServer.isSpawned(def.id) then
        -- Two clients can ask at once as a cell loads for both of them.
        KS.log("ignored SpawnNPC for '" .. def.id .. "': already spawned")
        return false
    end

    -- She may already be standing there. A zombie persists in its chunk, so
    -- after a reload the original is still present -- tagged, but with the
    -- disguise lapsed. Adopting her is the difference between one Diane and two.
    local existing = KS.NPCServer.findExistingAt(def.id, payload.x, payload.y, payload.z)
    if existing then
        KS.NPCs.applyDisguise(existing, def)
        KS.NPCServer.recordSpawned(def.id, existing)
        KS.print("npc '" .. def.id .. "' was already there; re-dressed rather than duplicated")
        return true
    end

    local zombies = addZombiesInOutfit(
        payload.x, payload.y, payload.z,
        1,                          -- one of them
        def.outfit,
        def.female and 100 or 0,    -- femaleChance
        false,                      -- crawler
        false,                      -- fall on front
        false,                      -- fake dead
        false,                      -- knocked down
        true,                       -- invulnerable
        false,                      -- sitting
        1                           -- health
    )

    local zombie = zombies and zombies:get(0)
    if not zombie then
        KS.warn("the game refused to create a zombie for npc '" .. def.id .. "'")
        return false
    end

    -- Centre of the tile, so they do not stand in a wall.
    zombie:setPosition(payload.x + 0.5, payload.y + 0.5, payload.z)

    KS.NPCs.applyDisguise(zombie, def)

    -- Through recordSpawned, not by writing the table directly. Writing it here
    -- set the world record but never the live reference, so the sweep had
    -- nothing to maintain: she was dressed once at spawn and then left alone.
    -- The first visit survived only because OnZombieUpdate happened to see her
    -- and register her itself; on a second visit nothing did.
    KS.NPCServer.recordSpawned(def.id, zombie)

    -- Read back at the spawn site, unconditionally. The maintenance sweep also
    -- logs, but only if it ever sees her -- and on a second visit it did not,
    -- which was invisible because the only evidence was a line that did not
    -- appear. One line per spawn, always, from the code that did the dressing.
    local readOk, report = pcall(KS.NPCs.readBack, zombie, def)

    KS.print("npc '" .. def.id .. "' (" .. def.name .. ") spawned at "
        .. payload.x .. "," .. payload.y .. "," .. payload.z
        .. " -- " .. (readOk and report or "read-back failed"))

    return true
end

--------------------------------------------------------------------------------
-- Liveness
--
-- A zombie does not survive its cell unloading, so the spawn record goes stale
-- the moment the player walks away. Rather than sweeping the world looking for
-- them, the record is cleared whenever the NPC's tile is no longer loaded --
-- which is also exactly when it becomes eligible to spawn again.
--------------------------------------------------------------------------------

local function forgetUnloadedNPCs()
    local npcs = npcState()

    for id, record in pairs(npcs) do
        if record.spawned then
            local square = getCell() and getCell():getGridSquare(record.x, record.y, record.z)

            if not square then
                record.spawned = false
                KS.NPCServer.live[id] = nil

                if KS.NPCMaintain then
                    KS.NPCMaintain.forgetNPC(id)
                end

                KS.log("npc '" .. id .. "' unloaded with its cell; it may spawn again")
            end
        end
    end
end

local function registerHandlers()
    KS.Commands.handlers[KS.Commands.SPAWN_NPC] = spawnNPC
end

Events.OnInitGlobalModData.Add(function()
    registerHandlers()
    KS.State.ensure()
    KS.NPCServer.clearSpawnRecords()
end)

Events.OnGameStart.Add(registerHandlers)
Events.EveryOneMinute.Add(forgetUnloadedNPCs)
