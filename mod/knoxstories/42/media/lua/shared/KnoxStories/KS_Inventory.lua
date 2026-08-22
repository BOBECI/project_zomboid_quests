--[[
    KS_Inventory.lua

    Searching a player's inventory, and the small data vocabulary that quest data
    uses to name a thing the player might be carrying.

    An "item spec" is the shape three of the four trigger types share:

        { item = "Base.Screwdriver" }    a vanilla item, by full type
        { note = "dummy_letter" }        one of our notes, by note id

    Exactly one of the two. Keeping this in one place means acquire_item,
    read_note and deliver_item cannot drift apart in how they match, or in what
    they call things when they report an error.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

KS.Inventory = KS.Inventory or {}

--------------------------------------------------------------------------------
-- Searching
--
-- Recursive, because "in your inventory" includes anything inside a bag.
--------------------------------------------------------------------------------

function KS.Inventory.find(container, predicate)
    local items = container:getItems()

    for i = 0, items:size() - 1 do
        local item = items:get(i)

        if predicate(item) then
            return item
        end

        if item:IsInventoryContainer() then
            local found = KS.Inventory.find(item:getInventory(), predicate)
            if found then
                return found
            end
        end
    end

    return nil
end

function KS.Inventory.findInPlayer(player, predicate)
    return KS.Inventory.find(player:getInventory(), predicate)
end

--------------------------------------------------------------------------------
-- Item specs
--------------------------------------------------------------------------------

-- Returns true, or false plus a plain-language reason. Called at boot by the
-- quest registry, so the message ends up in front of whoever wrote the quest.
function KS.Inventory.validateSpec(spec, whatFor)
    local hasItem = type(spec.item) == "string" and spec.item ~= ""
    local hasNote = type(spec.note) == "string" and spec.note ~= ""

    if hasItem and hasNote then
        return false, whatFor .. " names both an item and a note; it needs exactly one"
    end

    if not hasItem and not hasNote then
        return false, whatFor .. " does not say what item or note it means"
    end

    if hasNote and not KS.Notes.get(spec.note) then
        return false, whatFor .. " refers to the note '" .. spec.note
            .. "', but no note with that id exists"
    end

    return true
end

-- A predicate for KS.Inventory.find.
function KS.Inventory.specMatcher(spec)
    if spec.note then
        return function(item)
            return KS.Notes.idOf(item) == spec.note
        end
    end

    return function(item)
        return item:getFullType() == spec.item
    end
end

function KS.Inventory.findBySpec(player, spec)
    return KS.Inventory.findInPlayer(player, KS.Inventory.specMatcher(spec))
end

-- For log lines and error messages.
function KS.Inventory.describeSpec(spec)
    if spec.note then
        local def = KS.Notes.get(spec.note)
        return "note '" .. spec.note .. "'" .. (def and (" (" .. def.title .. ")") or "")
    end
    return "item '" .. tostring(spec.item) .. "'"
end
