--[[
    KS_NPCMaintain.lua

    Keeping the disguise on.

    WHY THIS FILE EXISTS

    Found in play: walk away until the cell unloads, come back, and Diane is a
    plain zombie in a long dress -- shambling, groaning, hostile.

    The cause is a split between two kinds of state. Her id lives in ModData,
    which the game saves with the zombie and its chunk. Everything that makes her
    a person -- setCanWalk(false), the animation variable, invulnerability, the
    cleared voice prefix -- is runtime state on the object, and none of it
    survives. So she comes back correctly identified as Diane and behaving
    exactly like what she really is.

    Nothing was going to notice that on its own. The spawner only runs when it
    thinks nobody is there, and she was there.

    So: watch tagged zombies, and re-apply the disguise to any that have lost it.
    Once per zombie per session, tracked by UID, so this costs one table lookup
    per zombie update in the steady state.

    Blood is the other half. She is invulnerable, but being struck still marks
    her clothing and skin, and a woman standing calmly in her kitchen covered in
    spatter reads as a zombie however still she is. That cannot be done once, so
    it is done on a throttle.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

KS.NPCMaintain = KS.NPCMaintain or {}

-- Re-assert every tick for this many updates after first sight, which covers the
-- window in which the engine is still building the zombie and overwriting us.
local SETTLE_UPDATES = 10

-- After that, roughly twice a second forever. This is also what keeps blood off
-- her: applying the disguise cleans it, and being struck is not a one-off event.
local REASSERT_EVERY = 30

-- How often the polled sweep runs, in player updates. Four times a second: fast
-- enough that the engine never wins the race for long, cheap enough to ignore
-- when there is one NPC in the world.

local TICKS_PER_SWEEP = 15

-- uid -> how many updates we have seen for that zombie. Deliberately not
-- persisted: after a reload every tagged zombie must be treated as brand new,
-- which is exactly what an empty table gives us.
local seen = {}
local sweepTicks = 0

local function uidOf(zombie)
    local ok, uid = pcall(function() return zombie:getUID() end)
    return ok and uid or nil
end

function KS.NPCMaintain.forget()
    seen = {}
    sweepTicks = 0
end

local function onZombieUpdate(zombie)
    local def = KS.NPCs.defOf(zombie)
    if not def then
        return
    end

    local uid = uidOf(zombie)
    if not uid then
        return
    end

    local updates = (seen[uid] or 0) + 1
    seen[uid] = updates

    -- Applying the disguise once is not enough, and this was the bug: she spawned
    -- correctly and was a plain zombie a moment later.
    --
    -- The engine is still assembling a freshly created zombie for the first few
    -- ticks -- descriptor, visuals, AI state -- and overwrites whatever was set
    -- before it finished. The reference mod works around the same thing by
    -- refusing to touch a new zombie for its first two updates.
    --
    -- Waiting a fixed number of ticks is a guess about engine timing, so instead
    -- this re-asserts every tick until it has clearly settled, then keeps
    -- checking periodically for the rest of her life. Applying is a handful of
    -- setters; there is one of her.
    local settling = updates <= SETTLE_UPDATES
    local periodic = (updates % REASSERT_EVERY) == 0

    if settling or periodic then
        KS.NPCs.applyDisguise(zombie, def)

        if updates == 1 then
            KS.log("dressing '" .. def.id .. "' -- will re-assert while the engine settles")
        end

        -- The world record is what stops a second copy of her being spawned on
        -- top of this one. She exists; say so.
        if KS.NPCServer then
            KS.NPCServer.recordSpawned(def.id, zombie)
        end
    end
end

--------------------------------------------------------------------------------
-- The sweep
--
-- This, not OnZombieUpdate, is what actually keeps the disguise on.
--
-- The first version hung everything on OnZombieUpdate. It exists nowhere in the
-- game's own files, so it could not be confirmed by reading the install; the
-- only evidence was that the reference mod uses it. In play the spawn line
-- appeared, the engine's own "Spawning new Female Zed, Dressed in DressLong"
-- appeared, and she was still a zombie with a zombie's skin -- which is what it
-- looks like when nothing re-asserts.
--
-- So the mechanism is now a poll over references we were handed at creation.
-- OnPlayerUpdate is a plain vanilla event the evaluator already relies on, and a
-- direct reference avoids the other unverifiable route: zombie ModData, which
-- the engine recycles between zombies -- the reference mod carries explicit code
-- to detect exactly that.
--
-- OnZombieUpdate is still used if it happens to exist, because it reacts a frame
-- sooner. It is no longer load-bearing.
--------------------------------------------------------------------------------

local function sweep()
    local live = KS.NPCServer and KS.NPCServer.live
    if not live then
        return
    end

    for npcId, zombie in pairs(live) do
        local def = KS.NPCs.get(npcId)

        if not def or not zombie then
            -- An NPC that has been taken out of the registry, or an entry that
            -- was never filled in. Nothing will ever dress it, so holding the
            -- reference only keeps a zombie alive in memory.
            live[npcId] = nil
        else
            -- A zombie whose cell has gone takes its object with it, so calling
            -- into a stale reference can fail. Dropping it is correct: the
            -- spawner will make a new one when the cell comes back.
            local ok = pcall(KS.NPCs.applyDisguise, zombie, def)

            if not ok then
                live[npcId] = nil
                KS.log("lost the reference to '" .. npcId .. "'; it will respawn")
            end
        end
    end
end

local function onPlayerUpdate()
    sweepTicks = sweepTicks + 1

    if sweepTicks < TICKS_PER_SWEEP then
        return
    end
    sweepTicks = 0

    sweep()
end

KS.NPCMaintain.sweep = sweep

Events.OnPlayerUpdate.Add(onPlayerUpdate)

if Events.OnZombieUpdate then
    Events.OnZombieUpdate.Add(onZombieUpdate)
else
    KS.log("no OnZombieUpdate event in this build; the polled sweep covers it")
end
