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

function KS.NPCServer.clearSpawnRecords()
    local npcs = npcState()
    local cleared = 0

    for id, record in pairs(npcs) do
        if record.spawned then
            record.spawned = false
            cleared = cleared + 1
        end
    end

    if cleared > 0 then
        KS.log("cleared " .. cleared .. " stale npc spawn record(s)")
    end
end

--------------------------------------------------------------------------------
-- The disguise
--------------------------------------------------------------------------------

local function disguise(zombie, def)
    zombie:setCanWalk(false)
    zombie:setUseless(true)
    zombie:setInvulnerable(true)
    zombie:setNoTeeth(true)

    -- The lifted animation nodes are gated on this. Without it the model still
    -- plays the zombie shamble no matter what else is set.
    zombie:setVariable(KS.NPCs.ANIM_VARIABLE, true)

    -- Silence. A groaning NPC is a zombie however it stands.
    local descriptor = zombie:getDescriptor()
    if descriptor then
        descriptor:setVoicePrefix("")
    end

    local emitter = zombie:getEmitter()
    if emitter then
        emitter:stopAll()
    end

    zombie:clearAttachedItems()
    zombie:resetEquippedHandsModels()

    KS.NPCs.markAs(zombie, def.id)
end

KS.NPCServer.disguise = disguise

--------------------------------------------------------------------------------
-- Spawning
--------------------------------------------------------------------------------

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

    disguise(zombie, def)

    npcState()[def.id] = {
        spawned = true,
        x = payload.x, y = payload.y, z = payload.z,
    }

    KS.print("npc '" .. def.id .. "' (" .. def.name .. ") spawned at "
        .. payload.x .. "," .. payload.y .. "," .. payload.z)

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
