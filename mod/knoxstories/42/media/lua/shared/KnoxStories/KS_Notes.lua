--[[
    KS_Notes.lua

    Quest information as a physical object. This is the mechanic the whole design
    hangs on (overview section 3), so it gets built early and tested hard.

    A note is a vanilla item -- Base.Notepad, Base.GenericMail -- rewritten at
    spawn time. Nothing here is a custom item. The technique is the one the
    reference mod uses (architecture 4.5): set the name, allow writing, add the
    pages, then lock it so the player cannot overwrite the text.

    Everything a note "is" comes from a data record, and the item carries only
    the note's id in its ModData. That matters for copying: a duplicate is built
    from the definition, not scraped off the original, so a copy of a copy is
    still identical to the first one.

    The copy mechanic itself lives here rather than in the timed action, because
    a pure function taking (player, item) can be tested without the game running.
    The client file is a thin wrapper over performCopy().
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

KS.NoteDefs = KS.NoteDefs or {}
KS.Notes = KS.Notes or {}

-- Written into the item ModData so a note can be recognised after it has been
-- dropped, traded, saved, or looted off a corpse.
local MODDATA_KEY = "knoxStoriesNote"

-- Passed to setLockedBy so the player cannot overwrite quest text.
local LOCK_KEY = "knoxStories"

-- What counts as a writing implement and what counts as blank paper. If a type
-- name here is wrong for the current build the copy option simply never appears,
-- so these are deliberately lists rather than single items.
KS.Notes.PEN_TYPES = { "Base.Pen", "Base.Pencil", "Base.BluePen", "Base.RedPen" }
KS.Notes.PAPER_TYPES = { "Base.SheetPaper", "Base.Notepad" }

local index = nil
local validated = false
local validCount, invalidCount = 0, 0

--------------------------------------------------------------------------------
-- Validation, same shape and same plain-language errors as the quest registry.
--------------------------------------------------------------------------------

local function invalidate(def, reason)
    def.invalid = true
    KS.warn("note '" .. tostring(def.id or "<no id>") .. "' was skipped: " .. reason)
end

local function validateNote(def, seenIds)
    if type(def.id) ~= "string" or def.id == "" then
        invalidate(def, "it has no id")
        return
    end

    if seenIds[def.id] then
        invalidate(def, "another note already uses the id '" .. def.id .. "'")
        return
    end
    seenIds[def.id] = true

    if type(def.item) ~= "string" or def.item == "" then
        invalidate(def, "it does not say which item to use, for example 'Base.Notepad'")
        return
    end

    if type(def.title) ~= "string" or def.title == "" then
        invalidate(def, "it has no title")
        return
    end

    if type(def.pages) ~= "table" or #def.pages == 0 then
        invalidate(def, "it has no pages")
        return
    end

    for i = 1, #def.pages do
        if type(def.pages[i]) ~= "string" then
            invalidate(def, "page " .. i .. " is not text")
            return
        end
    end

    def.invalid = false
end

function KS.Notes.ensureValidated()
    if validated then
        return validCount, invalidCount
    end
    validated = true

    local seenIds = {}
    validCount = 0
    index = {}

    for i = 1, #KS.NoteDefs do
        local def = KS.NoteDefs[i]
        validateNote(def, seenIds)
        if not def.invalid then
            validCount = validCount + 1
            index[def.id] = def
        end
    end
    invalidCount = #KS.NoteDefs - validCount

    return validCount, invalidCount
end

function KS.Notes.all()
    KS.Notes.ensureValidated()
    return KS.NoteDefs
end

function KS.Notes.get(noteId)
    KS.Notes.ensureValidated()
    return index[noteId]
end

--------------------------------------------------------------------------------
-- Creating a note item
--------------------------------------------------------------------------------

-- <LINE> is the reference mod line-break token, and it survives a trip through a
-- translation file where a raw newline does not. Phase 5 emits it, so the
-- expansion belongs here.
local function expandTokens(text)
    local expanded = tostring(text):gsub("<LINE>", "\n")
    return expanded
end

-- Turns a plain item into this note. Split out from create() so a note can also
-- be written onto an item that already exists in the world.
function KS.Notes.write(item, def)
    item:setName(def.title)
    item:setCustomName(true)
    item:setCanBeWrite(true)
    item:setPageToWrite(#def.pages)

    for i = 1, #def.pages do
        item:addPage(i, expandTokens(def.pages[i]))
    end

    -- Locked last: the pages have to be written before writing is disallowed.
    item:setLockedBy(LOCK_KEY)

    item:getModData()[MODDATA_KEY] = def.id

    return item
end

function KS.Notes.create(noteId)
    local def = KS.Notes.get(noteId)
    if not def then
        KS.warn("cannot create note '" .. tostring(noteId) .. "': no note has that id")
        return nil
    end

    local item = instanceItem(def.item)
    if not item then
        KS.warn("cannot create note '" .. noteId .. "': the game has no item called '"
            .. def.item .. "'")
        return nil
    end

    return KS.Notes.write(item, def)
end

function KS.Notes.giveTo(player, noteId)
    local item = KS.Notes.create(noteId)
    if not item then
        return nil
    end

    player:getInventory():AddItem(item)
    KS.print("gave note '" .. noteId .. "' to the player")
    return item
end

-- nil unless this item is one of ours.
function KS.Notes.idOf(item)
    if not item then
        return nil
    end

    local modData = item:getModData()
    if not modData then
        return nil
    end

    local id = modData[MODDATA_KEY]
    if type(id) == "string" and id ~= "" then
        return id
    end

    return nil
end

--------------------------------------------------------------------------------
-- Copying: pen + paper + the original -> a second identical note
--
-- Build plan 3.3. Nothing in the reference mod does this, so there is no
-- implementation to work from. The trade-off it creates is the point: spend the
-- time copying before heading out, or risk carrying the only copy.
--------------------------------------------------------------------------------

local function isTypeIn(item, types)
    local fullType = item:getFullType()
    for i = 1, #types do
        if fullType == types[i] then
            return true
        end
    end
    return false
end

local function isPen(item)
    return isTypeIn(item, KS.Notes.PEN_TYPES)
end

local function isBlankPaper(item, original)
    if item == original then
        return false
    end
    if not isTypeIn(item, KS.Notes.PAPER_TYPES) then
        return false
    end
    -- Never cannibalise another quest note, or anything already written on.
    if KS.Notes.idOf(item) then
        return false
    end
    if item:getLockedBy() then
        return false
    end
    return true
end

-- Walks the player inventory, including anything inside bags.
local function findInContainer(container, predicate)
    local items = container:getItems()

    for i = 0, items:size() - 1 do
        local item = items:get(i)

        if predicate(item) then
            return item
        end

        if item:IsInventoryContainer() then
            local found = findInContainer(item:getInventory(), predicate)
            if found then
                return found
            end
        end
    end

    return nil
end

-- Returns pen, paper on success, or nil, nil, reason. The reason is written for
-- a player to read: it goes straight into the greyed-out menu tooltip.
function KS.Notes.findCopyMaterials(player, original)
    local inventory = player:getInventory()

    local pen = findInContainer(inventory, isPen)
    if not pen then
        return nil, nil, "You need a pen or pencil."
    end

    local paper = findInContainer(inventory, function(item)
        return isBlankPaper(item, original)
    end)
    if not paper then
        return nil, nil, "You need a blank sheet of paper."
    end

    return pen, paper
end

function KS.Notes.canCopy(player, original)
    if not KS.Notes.idOf(original) then
        return false, "That is not a quest note."
    end

    local pen, _, reason = KS.Notes.findCopyMaterials(player, original)
    if not pen then
        return false, reason
    end

    return true
end

-- Consumes the paper, uses up a little of the pen, and puts an identical note in
-- the player inventory. Returns true, or false plus a reason.
function KS.Notes.performCopy(player, original)
    local noteId = KS.Notes.idOf(original)
    if not noteId then
        return false, "That is not a quest note."
    end

    if not KS.Notes.get(noteId) then
        return false, "This note claims to be '" .. noteId
            .. "', which the mod no longer defines."
    end

    local pen, paper, reason = KS.Notes.findCopyMaterials(player, original)
    if not pen then
        return false, reason
    end

    -- Build the copy before consuming anything, so a failure costs nothing.
    local copy = KS.Notes.create(noteId)
    if not copy then
        return false, "The copy could not be created."
    end

    local container = paper:getContainer()
    if container then
        container:Remove(paper)
    end

    if pen:IsDrainable() then
        pen:Use()
    end

    player:getInventory():AddItem(copy)
    KS.print("copied note '" .. noteId .. "'")

    return true
end
