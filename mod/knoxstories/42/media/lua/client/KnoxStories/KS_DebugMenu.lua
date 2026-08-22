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

    local defs = KS.Notes.all()
    for i = 1, #defs do
        local def = defs[i]
        if not def.invalid then
            submenu:addOption("Spawn note: " .. def.id, player, onSpawnNote, def.id)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
