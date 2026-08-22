--[[
    KS_ExamineMenu.lua

    Puts "Examine" on an item, but only when the quest step wanting it examined
    is live AND the player is carrying whatever that step requires.

    No option is added when the requirement is unmet. See KS_Examine.lua: a
    greyed-out entry would announce that this object matters, which is precisely
    the information the note is there to supply.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

local function actualItems(items)
    if ISInventoryPane and ISInventoryPane.getActualItems then
        return ISInventoryPane.getActualItems(items)
    end
    return items
end

local function onExamine(player, item)
    KS.Examine.mark(item)

    -- No step advance here. The polled evaluator notices the flag within about
    -- half a second, which keeps every trigger advancing through the same path
    -- rather than giving this one a private route into world state.
    if HaloTextHelper then
        HaloTextHelper.addText(player, "You take a closer look.")
    end
end

local function onFillInventoryObjectContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end

    local candidates = actualItems(items)

    for i = 1, #candidates do
        local item = candidates[i]

        if KS.Examine.triggerFor(player, item) then
            context:addOption("Examine", player, onExamine, item)
            return
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
