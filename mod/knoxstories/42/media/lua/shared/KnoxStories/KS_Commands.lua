--[[
    KS_Commands.lua

    The one boundary between "a client thinks a step is done" and "the world
    records that a step is done". Build plan section 4 lists three bugs in the
    reference mod that all trace back to not having this:

      - loose positional arguments compared against an undefined global, so every
        message fell through to the wrong handler
      - two command shapes, only one of which was ever mirrored to the server
      - no validation, so the client was effectively authoritative

    So: one named command, one payload shape, one validator, and the validator
    runs twice -- once on the sending side to fail fast with a readable reason,
    and once inside the server handler, which trusts nothing.

    Phase 1 is single-player, where client and server load in the same process
    and send() can call the handler directly. Phase 6 adds the network transport
    at the marked seam. Nothing above this file changes when it does.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

KS.Commands = KS.Commands or {}
KS.Commands.MODULE = "KnoxStories"

-- Command names.
KS.Commands.ADVANCE_STEP = "AdvanceStep"

-- name -> function(payload) -> true | false, plainLanguageReason
KS.Commands.validators = KS.Commands.validators or {}

-- name -> function(payload) -> boolean, filled in by the server tree.
KS.Commands.handlers = KS.Commands.handlers or {}

--------------------------------------------------------------------------------
-- AdvanceStep
--
--   { questId = "dummy_a", stepId = "step_1" }
--
-- stepId is the step the sender believes is currently active. The server checks
-- it against world state and rejects the command if it disagrees, which is what
-- makes a stale or duplicated claim harmless.
--------------------------------------------------------------------------------

KS.Commands.validators[KS.Commands.ADVANCE_STEP] = function(payload)
    if type(payload) ~= "table" then
        return false, "the payload is not a table"
    end

    if type(payload.questId) ~= "string" or payload.questId == "" then
        return false, "questId is missing or not a string"
    end

    if type(payload.stepId) ~= "string" or payload.stepId == "" then
        return false, "stepId is missing or not a string"
    end

    local def = KS.Quests.get(payload.questId)
    if not def then
        return false, "there is no quest with the id '" .. payload.questId .. "'"
    end

    if not KS.Quests.getStep(payload.questId, payload.stepId) then
        return false, "quest '" .. payload.questId .. "' has no step '" .. payload.stepId .. "'"
    end

    return true
end

--------------------------------------------------------------------------------
-- Dispatch
--------------------------------------------------------------------------------

function KS.Commands.send(name, payload)
    local validator = KS.Commands.validators[name]
    if not validator then
        KS.warn("refused to send unknown command '" .. tostring(name) .. "'")
        return false
    end

    local ok, reason = validator(payload)
    if not ok then
        KS.warn("refused to send '" .. name .. "': " .. tostring(reason))
        return false
    end

    -- Phase 6 seam. On a real client this becomes:
    --     if isClient() then
    --         sendClientCommand(getPlayer(), KS.Commands.MODULE, name, payload)
    --         return true
    --     end
    -- The server then receives it in OnClientCommand and calls the same handler
    -- below, through the same validator. One shape, both ways.

    local handler = KS.Commands.handlers[name]
    if not handler then
        KS.warn("command '" .. name .. "' has no handler -- is the server tree loaded?")
        return false
    end

    return handler(payload)
end
