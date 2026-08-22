--[[
    KS_Evaluator.lua

    The polled loop. Build plan 3.2 keeps the reference mod's shape -- scan the
    active steps every N player updates and evaluate each -- but evaluates data
    through KS.Triggers instead of calling a closure per quest.

    This lives in client/ because deciding that a trigger has fired needs the
    player, which is a client-side thing. It does not write state. When a trigger
    fires it sends a command and the server decides whether anything happened.
    That split is what stops us inheriting the reference mod's
    client-authoritative progress bug.

    Cost: the scan is O(active quests), runs about twice a second, and each
    enter_area test is a handful of comparisons. Fifty quests is nothing.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

KS.Evaluator = KS.Evaluator or {}

-- OnPlayerUpdate fires every frame per player. Scan on every 30th, so roughly
-- twice a second at 60fps -- fast enough that walking into a room registers
-- immediately, slow enough to be free.
local TICKS_PER_SCAN = 30

-- With DEBUG on, print the player's position every this many scans (~5s).
local SCANS_PER_POSITION_LOG = 10

local tickCounter = 0
local scanCounter = 0
local lastLoggedPos = nil

local function logPosition(player)
    if not KS.DEBUG then
        return
    end

    scanCounter = scanCounter + 1
    if scanCounter < SCANS_PER_POSITION_LOG then
        return
    end
    scanCounter = 0

    local pos = math.floor(player:getX()) .. ", " .. math.floor(player:getY())
        .. ", " .. math.floor(player:getZ())

    -- Standing still should not fill console.txt.
    if pos ~= lastLoggedPos then
        lastLoggedPos = pos
        KS.log("position: " .. pos)
    end
end

function KS.Evaluator.scan(player)
    if not player then
        return
    end

    -- Phase 6: on a real multiplayer client the server tree is not loaded, so
    -- this is nil and the evaluator needs a synced read-only copy of world
    -- state instead. In single-player both trees share a process.
    if not KS.State then
        return
    end

    local world = KS.State.get()
    if not world then
        return
    end

    local defs = KS.Quests.all()
    for i = 1, #defs do
        local def = defs[i]

        if not def.invalid then
            local progress = world.quests[def.id]

            if progress and progress.status == KS.STATUS.ACTIVE then
                local step = KS.Quests.getStep(def.id, progress.step)

                if step then
                    local triggerType = KS.Triggers.types[step.trigger.type]

                    if triggerType and triggerType.test(step.trigger, player) then
                        KS.log("trigger fired: " .. def.id .. " / " .. step.id)
                        KS.Commands.send(KS.Commands.ADVANCE_STEP, {
                            questId = def.id,
                            stepId = step.id,
                        })
                    end
                end
            end
        end
    end
end

local function onPlayerUpdate(player)
    tickCounter = tickCounter + 1
    if tickCounter < TICKS_PER_SCAN then
        return
    end
    tickCounter = 0

    logPosition(player)
    KS.Evaluator.scan(player)
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
