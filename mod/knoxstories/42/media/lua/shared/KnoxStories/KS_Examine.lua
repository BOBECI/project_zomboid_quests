--[[
    KS_Examine.lua

    Looking closely at something, and only being able to once you know what you
    are looking for.

    THE MECHANIC

    An inhaler in a bathroom cabinet is scenery. An inhaler in a bathroom cabinet
    when you are carrying a note describing whose it was is evidence. Same object,
    same square -- the difference is entirely what the player knows.

    So the Examine option does not appear at all until the required note is in
    someone's hands. Not greyed out with a hint: absent. A greyed-out option would
    tell the player there is something here to find, which gives away the thing
    the note is supposed to give away.

    This is the item-borne intel idea from overview section 3 taken one step
    further. Sharing the note does not just pass on an objective, it changes what
    the world affords. Hand the note to a friend and the inhaler becomes
    examinable for them too.

    The examined flag lives on the item, like the read flag, for the same reason:
    the object carries the fact, so it survives being picked up, traded and saved.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

KS.Examine = KS.Examine or {}

local EXAMINED_KEY = "knoxStoriesExamined"

function KS.Examine.mark(item)
    if not item then
        return false
    end

    local modData = item:getModData()
    if modData[EXAMINED_KEY] then
        return false
    end

    modData[EXAMINED_KEY] = true
    KS.log("examined " .. tostring(item:getFullType()))
    return true
end

function KS.Examine.isExamined(item)
    if not item then
        return false
    end
    return item:getModData()[EXAMINED_KEY] == true
end

-- Does the player hold what this trigger requires before the thing can be
-- examined at all? A trigger with no 'requires' is always satisfied.
function KS.Examine.requirementMet(player, trigger)
    if not trigger.requires then
        return true
    end
    return KS.Inventory.findBySpec(player, { note = trigger.requires }) ~= nil
end

--------------------------------------------------------------------------------
-- Finding the live examine steps
--
-- The context menu needs to answer "is this particular item examinable right
-- now", which means checking it against the current step of every active quest.
-- Cheap: it runs on right-click, not per frame, and the list of active quests is
-- short.
--------------------------------------------------------------------------------

-- Returns the trigger of the first active step that wants this item examined and
-- whose requirement the player meets, or nil.
function KS.Examine.triggerFor(player, item)
    if not KS.State then
        return nil
    end

    local world = KS.State.get()
    if not world then
        return nil
    end

    local defs = KS.Quests.all()

    for i = 1, #defs do
        local def = defs[i]

        if not def.invalid then
            local progress = world.quests[def.id]

            if progress and progress.status == KS.STATUS.ACTIVE then
                local step = KS.Quests.getStep(def.id, progress.step)

                if step and step.trigger.type == "examine" then
                    local trigger = step.trigger

                    if KS.Inventory.specMatcher(trigger)(item)
                        and KS.Examine.requirementMet(player, trigger) then
                        return trigger, def.id, step.id
                    end
                end
            end
        end
    end

    return nil
end
