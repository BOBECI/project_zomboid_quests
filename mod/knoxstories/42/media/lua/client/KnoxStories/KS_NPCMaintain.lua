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

-- uid -> how many updates we have seen for that zombie. Deliberately not
-- persisted: after a reload every tagged zombie must be treated as brand new,
-- which is exactly what an empty table gives us.
local seen = {}

local function uidOf(zombie)
    local ok, uid = pcall(function() return zombie:getUID() end)
    return ok and uid or nil
end

function KS.NPCMaintain.forget()
    seen = {}
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
-- Registration
--
-- OnZombieUpdate is fired by the engine, not by the game's Lua -- it appears
-- nowhere in media/, and neither does any other zombie event name, so its
-- existence cannot be confirmed by reading the install. The only positive
-- evidence is that the reference mod uses it and works.
--
-- If that turns out to be wrong, Events.OnZombieUpdate is nil and calling .Add
-- on it throws while this file is loading. The whole file would then be absent
-- with nothing obviously wrong in the console, and Diane would silently keep
-- coming back as a zombie -- which is a failure that looks exactly like the bug
-- this file exists to fix. Guarded so it says so instead.
--------------------------------------------------------------------------------

if Events.OnZombieUpdate then
    Events.OnZombieUpdate.Add(onZombieUpdate)
else
    KS.warn("this build has no OnZombieUpdate event, so the NPC disguise cannot be "
        .. "re-applied after a reload. Diane will come back as a plain zombie. "
        .. "Tell me and I will move the maintenance onto a polled sweep instead.")
end
