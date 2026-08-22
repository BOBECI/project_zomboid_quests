--[[
    KS_NPCDialogue.lua

    "Talk to Diane", and the window that opens.

    The window is deliberately the stock ISModalRichText rather than a bespoke
    panel. It already handles centring, joypad focus, scrolling and closing, and
    a hand-rolled panel would be a lot of untestable UI code to write for a
    feature whose content is not designed yet. Phase 5 replaces the raw strings
    with generated translation keys; if a custom window is wanted, that is the
    moment to build it, against real dialogue.

    Pages advance one at a time. The NPC's name heads each page so it reads as
    someone speaking rather than as narration.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

KS.Dialogue = KS.Dialogue or {}

local WIDTH = 420
local HEIGHT = 220

-- Shows one page and, on close, the next -- so a multi-page conversation reads
-- as a conversation rather than a wall of text.
local function showPage(player, def, pageNumber)
    local page = def.dialogue[pageNumber]
    if not page then
        return
    end

    local isLast = pageNumber >= #def.dialogue

    local text = " <H1> " .. def.name .. " <LINE> <LINE> " .. page

    local modal = ISModalRichText:new(
        0, 0, WIDTH, HEIGHT,
        text,
        false,      -- no yes/no, just a close button
        nil, nil,
        player:getPlayerNum()
    )

    modal:initialise()

    if not isLast then
        -- Chain to the next page when this one is dismissed.
        local originalDestroy = modal.destroy
        modal.destroy = function(self)
            originalDestroy(self)
            showPage(player, def, pageNumber + 1)
        end
    end

    modal:addToUIManager()
end

function KS.Dialogue.talkTo(player, def)
    if not def or def.invalid then
        return false
    end

    KS.log("talking to '" .. def.id .. "'")
    showPage(player, def, 1)
    return true
end

--------------------------------------------------------------------------------
-- The context menu on the NPC themselves
--------------------------------------------------------------------------------

local function onTalk(player, npcId)
    KS.Dialogue.talkTo(player, KS.NPCs.get(npcId))
end

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end

    -- Right-clicking a square gives us the objects on it, not the zombies, so
    -- the NPC has to be found by looking at what is standing there.
    for i = 1, #worldobjects do
        local square = worldobjects[i]:getSquare()

        if square then
            local movingObjects = square:getMovingObjects()

            for j = 0, movingObjects:size() - 1 do
                local def = KS.NPCs.defOf(movingObjects:get(j))

                if def then
                    if test then
                        return true
                    end
                    context:addOption("Talk to " .. def.name, player, onTalk, def.id)
                    return
                end
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
