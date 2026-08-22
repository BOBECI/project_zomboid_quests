--[[
    KS_DebugMenu.lua

    Right-click the ground -> "[KnoxStories] Spawn note" -> pick one.

    Testing scaffolding, and gated on KnoxStories.DEBUG so it disappears the
    moment the flag ships false. It exists because Phase 2 has no NPC to hand you
    a note yet, and because it makes the copy recipe testable on a save that has
    already walked past the quest steps that give notes out.

    The world context menu is used rather than the inventory one so this still
    works with an empty inventory.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

local function onSpawnNote(player, noteId)
    KS.Notes.giveTo(player, noteId)
end

local function onSpawnMaterials(player)
    local inventory = player:getInventory()
    inventory:AddItem("Base.Pen")
    inventory:AddItem("Base.SheetPaper2")
    inventory:AddItem("Base.SheetPaper2")
    KS.print("spawned a pen and two sheets of paper")
end

-- Dummy C's acquire_item step wants a screwdriver, and hunting one down is not
-- what that test is about.
local function onSpawnTriggerItems(player)
    player:getInventory():AddItem("Base.Screwdriver")
    KS.print("spawned a screwdriver")
end

-- KS.State only exists where the server tree is loaded, which in single-player
-- is the same process. Phase 6 gives this a command of its own.
local function onResetQuest(_, questId)
    if KS.State then
        KS.State.debugResetQuest(questId)
    end
end

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    if not KS.DEBUG then
        return
    end

    if test then
        return true
    end

    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end

    local parent = context:addOption("[KnoxStories] Debug", nil, nil)
    local submenu = ISContextMenu:getNew(context)
    context:addSubMenu(parent, submenu)

    submenu:addOption("Spawn pen + paper", player, onSpawnMaterials)
    submenu:addOption("Spawn screwdriver", player, onSpawnTriggerItems)

    local notes = KS.Notes.all()
    for i = 1, #notes do
        local def = notes[i]
        if not def.invalid then
            submenu:addOption("Spawn note: " .. def.id, player, onSpawnNote, def.id)
        end
    end

    -- Walking a trigger chain twice needs a way back to the start that does not
    -- involve a new save.
    local quests = KS.Quests.all()
    for i = 1, #quests do
        local def = quests[i]
        if not def.invalid then
            submenu:addOption("Reset quest: " .. def.id, nil, onResetQuest, def.id)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
