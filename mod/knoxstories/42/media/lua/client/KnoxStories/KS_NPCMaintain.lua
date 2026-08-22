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

-- Roughly twice a second per NPC, which is often enough that a hit is cleaned
-- before the player has really registered it.
local UPDATES_PER_BLOOD_CLEAN = 30

-- uid -> true for zombies disguised during this session. Deliberately not
-- persisted: after a reload every tagged zombie must be treated as lapsed,
-- which is exactly what an empty table gives us.
local disguised = {}
local sinceClean = {}

local function uidOf(zombie)
    local ok, uid = pcall(function() return zombie:getUID() end)
    return ok and uid or nil
end

function KS.NPCMaintain.forget()
    disguised = {}
    sinceClean = {}
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

    if not disguised[uid] then
        disguised[uid] = true
        sinceClean[uid] = 0

        KS.NPCs.applyDisguise(zombie, def)
        KS.log("re-applied the disguise to '" .. def.id .. "' after a reload")

        -- The world record is what stops a second copy of her being spawned on
        -- top of this one. She exists; say so.
        if KS.NPCServer then
            KS.NPCServer.recordSpawned(def.id, zombie)
        end

        return
    end

    local count = (sinceClean[uid] or 0) + 1

    if count >= UPDATES_PER_BLOOD_CLEAN then
        sinceClean[uid] = 0
        KS.NPCs.cleanBlood(zombie)
    else
        sinceClean[uid] = count
    end
end

Events.OnZombieUpdate.Add(onZombieUpdate)
