--[[
    KS_Examine.lua

    Looking closely at something, and only being able to once you know what you
    are looking for.

    THE MECHANIC

    A packet of pills in a bathroom cabinet is scenery. The same packet when you
    are carrying a note describing whose it was is evidence. Same object, same
    square -- the difference is entirely what the player knows.

    So the Examine option does not appear at all until the required note is in
    someone's hands. Not greyed out with a hint: absent. A greyed-out option would
    tell the player there is something here to find, which gives away the thing
    the note is supposed to give away.

    WHY THERE IS NO FLAG ON THE ITEM

    The first version marked the item examined and let the polled evaluator
    notice. Two things were wrong with that, both found in play:

      - the trigger looked at the first matching item in the inventory, so an
        older packet that had already been examined fired the step the moment a
        new one was picked up. Examining stopped being something the player did
        and became something that happened to them.
      - the flag outlived a quest reset, so re-running the sequence with the same
        packet silently did nothing.

    Under the surface both are the same mistake: "has been examined" is not a
    property of a packet of pills. Two identical packets should not behave
    differently. What actually changed is that the GROUP now recognises what the
    object means -- and that is quest state, which already lives in the world and
    already resets cleanly.

    So examine is an ACTION trigger. It has no test(): nothing polls it, and the
    only thing that can advance the step is the player choosing Examine from the
    menu. Looking closer is a deliberate act, which is the whole point of the
    mechanic -- the player decides to check, and the world answers.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

KS.Examine = KS.Examine or {}

-- Does the player hold what this trigger requires before the thing can be
-- examined at all? A trigger with no 'requires' is always satisfied.
function KS.Examine.requirementMet(player, trigger)
    if not trigger.requires then
        return true
    end
    return KS.Inventory.findBySpec(player, { note = trigger.requires }) ~= nil
end

--------------------------------------------------------------------------------
-- Finding the live examine step
--
-- The context menu needs to answer "is this particular item examinable right
-- now", which means checking it against the current step of every active quest.
-- Cheap: it runs on right-click, not per frame, and the list of active quests is
-- short.
--------------------------------------------------------------------------------

-- Returns questId, stepId, trigger for the first active step that wants this
-- item examined and whose requirement the player meets. Otherwise nil.
function KS.Examine.stepFor(player, item)
    if not KS.State or not item then
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
                        return def.id, step.id, trigger
                    end
                end
            end
        end
    end

    return nil
end

-- The whole of examining: advance the step, through the same command boundary
-- every other write goes through. Nothing is written onto the item.
function KS.Examine.perform(player, item)
    local questId, stepId = KS.Examine.stepFor(player, item)

    if not questId then
        return false
    end

    return KS.Commands.send(KS.Commands.ADVANCE_STEP, {
        questId = questId,
        stepId = stepId,
    })
end
