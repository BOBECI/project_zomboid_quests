--[[
    KS_State.lua

    World state. Build plan 3.1: quest progress belongs to the world, not to a
    player. There is exactly one copy, it lives in the global ModData table, and
    the server owns every write. No per-player mirror exists, so there is nothing
    to keep in sync and no branch to reconcile.

    This file is in server/, which loads on a dedicated server and also in
    single-player, where it shares a process with the client tree.

    Shape stored in ModData:

        {
            schema = 1,
            quests = {
                ["dummy_a"] = { status = "active", step = "step_2" },
                ["dummy_b"] = { status = "complete", step = nil },
            },
        }

    Only strings, numbers, booleans and plain tables -- ModData will not carry
    anything else across a save.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

KS.State = KS.State or {}

local MODDATA_KEY = "KnoxStories"
local SCHEMA_VERSION = 1

local world = nil

--------------------------------------------------------------------------------
-- Initialisation
--
-- Seeding is additive: a quest absent from saved state gets an entry, and a
-- quest already present is left exactly as it was. That means adding quests to
-- an existing save works, and a reload never resets progress.
--------------------------------------------------------------------------------

local function seedMissingQuests()
    local added = 0

    local defs = KS.Quests.all()
    for i = 1, #defs do
        local def = defs[i]
        if not def.invalid and world.quests[def.id] == nil then
            world.quests[def.id] = {
                status = KS.STATUS.ACTIVE,
                step = def.firstStep,
            }
            added = added + 1
        end
    end

    return added
end

function KS.State.ensure()
    if world then
        return world
    end

    world = ModData.getOrCreate(MODDATA_KEY)

    if world.schema == nil then
        world.schema = SCHEMA_VERSION
    end
    if type(world.quests) ~= "table" then
        world.quests = {}
    end

    local added = seedMissingQuests()
    KS.log("world state ready (schema " .. tostring(world.schema)
        .. ", " .. added .. " quest(s) seeded this load)")

    return world
end

function KS.State.get()
    return KS.State.ensure()
end

function KS.State.getQuest(questId)
    return KS.State.ensure().quests[questId]
end

--------------------------------------------------------------------------------
-- The authoritative write
--
-- Everything a client can ask for arrives here, already validated for shape by
-- KS.Commands. This function re-validates shape and then checks the claim
-- against world state, which is the part that actually matters: a step only
-- advances if the world agrees that step is the one currently active.
--------------------------------------------------------------------------------

-- Everything a completed step does to the player's inventory: what the trigger
-- takes away (deliver_item) and what the step hands over (gives).
--
-- Order matters. Consume first, then give: a step that takes one note and hands
-- back another must not have the new one picked up by its own consume.
--
-- Phase 6 seam. Items live in a player's inventory, which is per-player data,
-- not world state -- so in multiplayer this has to be routed to the player whose
-- command it was, rather than to whoever happens to be local. In single-player
-- there is exactly one player and getPlayer() is that player.
local function applyStepEffects(step)
    if not step.gives and not KS.Triggers.types[step.trigger.type].consume then
        return
    end

    if isServer() then
        KS.log("step '" .. step.id .. "' has inventory effects, deferred: "
            .. "no local player on a dedicated server")
        return
    end

    local player = getPlayer()
    if not player then
        return
    end

    local triggerType = KS.Triggers.types[step.trigger.type]
    if triggerType.consume then
        triggerType.consume(step.trigger, player)
    end

    if step.gives then
        KS.Notes.giveTo(player, step.gives)
    end
end

local function advanceStep(payload)
    local ok, reason = KS.Commands.validators[KS.Commands.ADVANCE_STEP](payload)
    if not ok then
        KS.warn("rejected AdvanceStep: " .. tostring(reason))
        return false
    end

    local questId = payload.questId
    local progress = KS.State.ensure().quests[questId]

    if not progress then
        KS.warn("rejected AdvanceStep: the world has no record of quest '" .. questId .. "'")
        return false
    end

    if progress.status ~= KS.STATUS.ACTIVE then
        -- Not an error. Two players can trip the same trigger in the same tick.
        KS.log("ignored AdvanceStep for '" .. questId .. "': quest is " .. tostring(progress.status))
        return false
    end

    if progress.step ~= payload.stepId then
        -- A stale claim. Harmless, and this is exactly why stepId is in the payload.
        KS.log("ignored AdvanceStep for '" .. questId .. "': world is on step '"
            .. tostring(progress.step) .. "', claim was for '" .. payload.stepId .. "'")
        return false
    end

    local step = KS.Quests.getStep(questId, progress.step)
    local from = progress.step

    if step.unlocks then
        progress.step = step.unlocks
        KS.print("quest '" .. questId .. "': step '" .. from .. "' -> '" .. progress.step .. "'")
    else
        progress.status = KS.STATUS.COMPLETE
        progress.step = nil
        KS.print("quest '" .. questId .. "': step '" .. from .. "' was the last one -- COMPLETE")
    end

    applyStepEffects(step)

    -- Phase 1 only. Real feedback is Phase 5's job; this exists so the state
    -- change is visible in game while there is no content to show.
    -- Guarded because a dedicated server has no local player.
    if not isServer() and HaloTextHelper then
        local player = getPlayer()
        if player then
            HaloTextHelper.addText(player, "Quest step: " .. questId .. " / " .. from)
        end
    end

    return true
end

-- Registered from an event rather than at file scope. PZ loads shared/ before
-- server/, so doing it inline would work -- but it would mean this file silently
-- depends on load order, and the command name lives in KS_Commands. Deferring
-- costs nothing and keeps the whole tree order-proof. Idempotent, so registering
-- from two events is fine.
local function registerHandlers()
    KS.Commands.handlers[KS.Commands.ADVANCE_STEP] = advanceStep
end

--------------------------------------------------------------------------------
-- Global ModData is created here. Mutating the table afterwards is enough --
-- the engine writes it out with the save.
--------------------------------------------------------------------------------

Events.OnInitGlobalModData.Add(function(isNewGame)
    KS.log("OnInitGlobalModData (new game: " .. tostring(isNewGame) .. ")")
    registerHandlers()
    KS.State.ensure()
end)

Events.OnGameStart.Add(registerHandlers)
