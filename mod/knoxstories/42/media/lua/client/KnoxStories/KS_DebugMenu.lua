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

-- Dummy D's examine step wants something small and personal to look closely at.
--
-- Not an inhaler: Build 42 has an "asthmatic" character trait but no inhaler
-- item, so beta blockers stand in. Any item works; the trigger does not care.
local function onSpawnExamineTarget(player)
    player:getInventory():AddItem("Base.PillsBeta")
    KS.print("spawned a packet of beta blockers")
end

--------------------------------------------------------------------------------
-- Dressing recorder
--
-- The set id is derived from where you are standing rather than typed. A text
-- prompt mid-dressing is friction, and a coordinate-derived name is unique and
-- tells you later where the recording was made. Rename it when you copy the file
-- into the mod.
--------------------------------------------------------------------------------

local function onStartRecording(player)
    local setId = string.format("house_%d_%d",
        math.floor(player:getX()), math.floor(player:getY()))
    KS.Recorder.start(player, setId)
end

local function onFinishRecording()
    KS.Recorder.finish()
end

local function onCancelRecording()
    KS.Recorder.cancel()
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
    submenu:addOption("Spawn examine target (pills)", player, onSpawnExamineTarget)

    -- Dressing recorder. Only the relevant half of the pair is offered, so the
    -- menu itself tells you whether a recording is running.
    if KS.Recorder.isRecording() then
        submenu:addOption("Finish recording and export", nil, onFinishRecording)
        submenu:addOption("Discard recording", nil, onCancelRecording)
    else
        submenu:addOption("Start recording dressing here", player, onStartRecording)
    end

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
