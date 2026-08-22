--[[
    KS_Triggers.lua

    The trigger vocabulary. Build plan 3.2: steps are data, not closures, so a
    step names a trigger type and supplies parameters, and one generic evaluator
    runs all of them. Adding a quest must never mean writing Lua.

    Each type provides two functions:

      validate(params)        -> true | false, plainLanguageReason
                                 Called once at boot. May normalise params in
                                 place (clamping, defaults) before returning.

      test(params, player)    -> boolean
                                 Called from the polled loop. Must be cheap and
                                 must not mutate anything.

    Phase 1 defines one type. Phase 3 adds acquire item, read note, and deliver
    item to NPC.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

KS.Triggers = KS.Triggers or {}
KS.Triggers.types = KS.Triggers.types or {}

--------------------------------------------------------------------------------
-- enter_area
--
--   { type = "enter_area", x1 = 8030, y1 = 11780, x2 = 8060, y2 = 11810, z = 0 }
--
-- Fires while the player stands anywhere inside the rectangle, inclusive, on
-- floor z. Corners may be given in any order.
--------------------------------------------------------------------------------

local function isNumber(v)
    return type(v) == "number"
end

KS.Triggers.types.enter_area = {

    validate = function(params)
        local required = { "x1", "y1", "x2", "y2" }
        for i = 1, #required do
            local key = required[i]
            if not isNumber(params[key]) then
                return false, "the area is missing a number for '" .. key .. "'"
            end
        end

        if params.z == nil then
            params.z = 0
        elseif not isNumber(params.z) then
            return false, "'z' must be a number (0 is ground level)"
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
        local z = math.floor(player:getZ())
        if z ~= params.z then
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
