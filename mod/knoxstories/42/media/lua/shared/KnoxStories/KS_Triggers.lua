--[[
    KS_Triggers.lua

    The trigger vocabulary. Build plan 3.2: steps are data, not closures, so a
    step names a trigger type and supplies parameters, and one generic evaluator
    runs all of them. Adding a quest must never mean writing Lua.

    Each type provides:

      validate(params)        -> true | false, plainLanguageReason
                                 Called once at boot. May normalise params in
                                 place (clamping, defaults) before returning.

      test(params, player)    -> boolean
                                 Called from the polled loop, about twice a
                                 second. Must be cheap, and must NOT mutate
                                 anything -- a trigger can be tested many times
                                 before the step actually advances.

      test may be ABSENT. A trigger with no test is an action trigger: nothing
      polls it, and something else -- a menu option, a player choice -- advances
      the step directly through KS.Commands. examine is the only one so far.

      consume(params, player) -> optional
                                 Called once, server-side, after the step has
                                 actually advanced. This is where a trigger is
                                 allowed to have side effects. Only deliver_item
                                 implements it.

    Phase 3 completes the four types the Rosewood pilot needs.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

KS.Triggers = KS.Triggers or {}
KS.Triggers.types = KS.Triggers.types or {}

local function isNumber(v)
    return type(v) == "number"
end

--------------------------------------------------------------------------------
-- Shared: a place in the world
--
-- enter_area uses a rectangle; deliver_item uses a point and a radius. Both
-- ignore anything on a different floor, which is what stops a trigger firing
-- through a ceiling.
--------------------------------------------------------------------------------

local function validateFloor(params)
    if params.z == nil then
        params.z = 0
    elseif not isNumber(params.z) then
        return false, "'z' must be a number (0 is ground level)"
    end
    return true
end

local function onSameFloor(params, player)
    return math.floor(player:getZ()) == params.z
end

--------------------------------------------------------------------------------
-- enter_area
--
--   { type = "enter_area", x1 = 8030, y1 = 11780, x2 = 8060, y2 = 11810, z = 0 }
--
-- Fires while the player stands anywhere inside the rectangle, inclusive.
-- Corners may be given in any order.
--------------------------------------------------------------------------------

KS.Triggers.types.enter_area = {

    validate = function(params)
        local required = { "x1", "y1", "x2", "y2" }
        for i = 1, #required do
            local key = required[i]
            if not isNumber(params[key]) then
                return false, "the area is missing a number for '" .. key .. "'"
            end
        end

        local ok, reason = validateFloor(params)
        if not ok then
            return false, reason
        end

        -- Accept corners in any order.
        if params.x1 > params.x2 then
            params.x1, params.x2 = params.x2, params.x1
        end
        if params.y1 > params.y2 then
            params.y1, params.y2 = params.y2, params.y1
        end

        return true
    end,

    test = function(params, player)
        if not onSameFloor(params, player) then
            return false
        end

        local x = math.floor(player:getX())
        if x < params.x1 or x > params.x2 then
            return false
        end

        local y = math.floor(player:getY())
        if y < params.y1 or y > params.y2 then
            return false
        end

        return true
    end,
}

--------------------------------------------------------------------------------
-- acquire_item
--
--   { type = "acquire_item", item = "Base.Screwdriver" }
--   { type = "acquire_item", note = "dummy_letter" }
--
-- Fires while the thing is anywhere in the player's inventory, including inside
-- a bag. It does not care how it got there, so looting it, being handed it, or
-- taking it off a corpse all count.
--------------------------------------------------------------------------------

KS.Triggers.types.acquire_item = {

    validate = function(params)
        return KS.Inventory.validateSpec(params, "the trigger")
    end,

    test = function(params, player)
        return KS.Inventory.findBySpec(player, params) ~= nil
    end,
}

--------------------------------------------------------------------------------
-- read_note
--
--   { type = "read_note", note = "dummy_letter" }
--
-- Fires once the player has actually opened the note, not merely picked it up.
--
-- "Opened" is the honest description. The flag is set by the hook in
-- client/KS_NoteReadHook.lua, which fires when the game opens the note window.
-- A player who opens a note and shuts it immediately counts as having read it;
-- there is no signal for "and understood it", and holding out for one would mean
-- polling page counters that the notebook UI owns.
--------------------------------------------------------------------------------

KS.Triggers.types.read_note = {

    validate = function(params)
        if type(params.note) ~= "string" or params.note == "" then
            return false, "read_note needs a note id"
        end
        if params.item then
            return false, "read_note works on notes, not on plain items"
        end
        return KS.Inventory.validateSpec(params, "the trigger")
    end,

    test = function(params, player)
        local note = KS.Inventory.findBySpec(player, params)
        return note ~= nil and KS.Notes.isRead(note)
    end,
}

--------------------------------------------------------------------------------
-- deliver_item
--
--   { type = "deliver_item", note = "dummy_letter",
--     x = 8040, y = 11790, z = 0, range = 2 }
--
-- Fires when the player is carrying the thing AND standing within range of the
-- destination. The item is then taken off them -- that is what makes it a
-- delivery rather than a fetch.
--
-- Phase 4 note: the pilot's real deliveries are to an NPC, which does not exist
-- yet. The destination is therefore a point on the map for now. When NPCs land,
-- this gains an optional npc = "diane" that replaces the coordinates; the item
-- half of the trigger does not change.
--------------------------------------------------------------------------------

local DEFAULT_RANGE = 2

KS.Triggers.types.deliver_item = {

    validate = function(params)
        local ok, reason = KS.Inventory.validateSpec(params, "the trigger")
        if not ok then
            return false, reason
        end

        -- Deliver to a person if one is named, otherwise to a point. Naming an
        -- NPC copies their coordinates in, so a quest that moves its NPC does
        -- not also have to remember to move the delivery.
        if params.npc ~= nil then
            local npc = KS.NPCs.get(params.npc)
            if not npc then
                return false, "it delivers to the npc '" .. tostring(params.npc)
                    .. "', but no npc with that id exists"
            end

            params.x, params.y, params.z = npc.x, npc.y, npc.z
        end

        if not isNumber(params.x) or not isNumber(params.y) then
            return false, "deliver_item needs an 'x' and a 'y', or an 'npc', to deliver to"
        end

        ok, reason = validateFloor(params)
        if not ok then
            return false, reason
        end

        if params.range == nil then
            params.range = DEFAULT_RANGE
        elseif not isNumber(params.range) or params.range <= 0 then
            return false, "'range' must be a number of tiles greater than zero"
        end

        return true
    end,

    test = function(params, player)
        if not onSameFloor(params, player) then
            return false
        end

        -- Squared distance: no square root needed for a threshold test.
        local dx = player:getX() - params.x
        local dy = player:getY() - params.y
        if (dx * dx + dy * dy) > (params.range * params.range) then
            return false
        end

        return KS.Inventory.findBySpec(player, params) ~= nil
    end,

    -- Server-side, after the step has advanced. Takes exactly one.
    consume = function(params, player)
        local item = KS.Inventory.findBySpec(player, params)
        if not item then
            -- The player dropped it between the trigger firing and this running.
            -- The step has already advanced; taking the quest back off them would
            -- be worse than letting a stray copy exist.
            KS.warn("delivered " .. KS.Inventory.describeSpec(params)
                .. " was gone before it could be taken")
            return
        end

        local container = item:getContainer()
        if container then
            container:Remove(item)
        end

        KS.log("took " .. KS.Inventory.describeSpec(params) .. " on delivery")
    end,
}

--------------------------------------------------------------------------------
-- examine
--
--   { type = "examine", item = "Base.Inhaler", requires = "diane_description" }
--
-- An ACTION trigger: it has no test(), so nothing polls it and the only thing
-- that can advance the step is the player choosing Examine from the menu.
-- KS_Examine.lua explains why -- in short, "has been examined" is not a property
-- of a packet of pills, and treating it as one made examining fire on pickup.
--
-- The Examine option is hidden entirely until 'requires' is satisfied, so the
-- world gives nothing away before the player has the intel.
--
-- 'requires' is optional. Without it the thing is examinable as soon as the step
-- is active, which is the ordinary case; the conditional form is the interesting
-- one.
--------------------------------------------------------------------------------

KS.Triggers.types.examine = {

    validate = function(params)
        local ok, reason = KS.Inventory.validateSpec(params, "the trigger")
        if not ok then
            return false, reason
        end

        if params.requires ~= nil then
            if type(params.requires) ~= "string" or params.requires == "" then
                return false, "'requires' must be the id of the note the player needs first"
            end
            if not KS.Notes.get(params.requires) then
                return false, "'requires' names the note '" .. params.requires
                    .. "', but no note with that id exists"
            end
        end

        return true
    end,

    -- No test. See above.
}
