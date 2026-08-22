--[[
    KS_NoteCopyMenu.lua

    Right-click a quest note in your inventory -> "Copy this note".

    Build plan 3.3 calls this a recipe. It is implemented as a context menu and a
    timed action rather than a scripts/*.txt craftRecipe, for two reasons:

      - The copy has to be built from one specific item instance, because that is
        where the note id lives. A recipe callback makes getting at the exact
        input item awkward; a context menu hands it to us directly.
      - B42 reworked the crafting format, and none of that syntax can be verified
        outside the game. This path is pure Lua and is covered by tools/luatest.

    It also reads better in the fiction: you act on the letter itself rather than
    finding an entry in a crafting menu.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

-- The inventory context menu passes either items or stacks depending on where
-- the click came from.
local function actualItems(items)
    if ISInventoryPane and ISInventoryPane.getActualItems then
        return ISInventoryPane.getActualItems(items)
    end
    return items
end

local function onCopyNote(player, note)
    ISTimedActionQueue.add(KS_CopyNoteAction:new(player, note))
end

local function onFillInventoryObjectContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end

    local candidates = actualItems(items)

    for i = 1, #candidates do
        local item = candidates[i]

        if KS.Notes.idOf(item) then
            local option = context:addOption("Copy this note", player, onCopyNote, item)

            local canCopy, reason = KS.Notes.canCopy(player, item)
            if not canCopy then
                option.notAvailable = true

                -- Say which material is missing rather than just greying out.
                if ISWorldObjectContextMenu and ISWorldObjectContextMenu.addToolTip then
                    local tooltip = ISWorldObjectContextMenu.addToolTip()
                    tooltip.description = reason
                    option.toolTip = tooltip
                end
            end

            -- One option per menu, even if several notes were selected.
            return
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
