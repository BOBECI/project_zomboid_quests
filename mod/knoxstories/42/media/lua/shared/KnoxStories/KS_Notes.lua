--[[
    KS_Notes.lua

    Quest information as a physical object. This is the mechanic the whole design
    hangs on (overview section 3), so it gets built early and tested hard.

    A note is a vanilla item -- Base.Notepad, Base.IndexCard -- rewritten at
    spawn time. Nothing here is a custom item. The technique is the one the
    reference mod uses (architecture 4.5): set the name, allow writing, add the
    pages, then lock it so the player cannot overwrite the text.

    The base item must have CanBeWrite = true in the game's own item scripts.
    Base.GenericMail does not, despite the reference mod appearing to use it for
    exactly this -- see the list in notes/KS_DummyNotes.lua.

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

-- Set on the item once the player has opened it. Feeds the read_note trigger.
local READ_KEY = "knoxStoriesRead"

-- Passed to setLockedBy so the player cannot overwrite quest text.
--
-- Confirmed against the game's own code: ISInventoryPaneContextMenu treats an
-- item whose getLockedBy() is set and does not equal the player's username as
-- not editable, and offers "Read Note" instead of "Write Note". So the text is
-- protected and still readable, which is exactly what a quest note needs.
local LOCK_KEY = "knoxStories"

-- What counts as a writing implement and what counts as blank paper.
--
-- Both now ask the game rather than consulting a list of names, because paper is
-- scarce in B42 and a narrow list turns copying into a treasure hunt.
--
--   Writing implements: the game's own "can I write on this note" check is
--   playerInv:containsTagRecurse(ItemTag.WRITE) plus the per-colour pen tags.
--   Matching that exactly means our Copy option is offered under precisely the
--   conditions the vanilla Write option is, including for modded pens.
--
--   Paper: anything the game says CanBeWrite that has no pages written on it.
--   That covers SheetPaper2, GraphPaper, IndexCard, Notepad, Journal, Notebook,
--   the greeting cards, and anything a mod adds, without naming any of them.
--
-- The type lists survive as a fallback for when the tag API is not available,
-- and as the answer to "what does a pen mean" in the tests.
KS.Notes.PEN_TYPES = { "Base.Pen", "Base.Pencil", "Base.BluePen", "Base.RedPen" }
KS.Notes.PEN_TAGS = { "WRITE", "PEN", "PENCIL", "BLUE_PEN", "RED_PEN", "GREEN_PEN" }

-- Only consulted if canBeWrite() cannot be called on an item.
KS.Notes.PAPER_TYPES = { "Base.SheetPaper2", "Base.Notepad", "Base.GraphPaper", "Base.IndexCard" }

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
-- Has it been read?
--
-- The flag lives on the item, not on the player, for the same reason quest state
-- lives in the world: the note is the thing that carries the information. Hand a
-- read note to someone else and it stays read, which is the point -- the group
-- learns what the group has learned.
--
-- Set by the hook in client/KS_NoteReadHook.lua when the note window opens. A
-- copy starts unread even if the original was read; it is a fresh piece of paper
-- and nobody has looked at it yet.
--------------------------------------------------------------------------------

function KS.Notes.markRead(item)
    local noteId = KS.Notes.idOf(item)
    if not noteId then
        return false
    end

    local modData = item:getModData()
    if modData[READ_KEY] then
        return false
    end

    modData[READ_KEY] = true
    KS.log("note '" .. noteId .. "' was opened for the first time")
    return true
end

function KS.Notes.isRead(item)
    if not KS.Notes.idOf(item) then
        return false
    end
    return item:getModData()[READ_KEY] == true
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
    -- Tags first, so a modded pen the game would accept works here too.
    for i = 1, #KS.Notes.PEN_TAGS do
        local ok, tagged = pcall(function() return item:hasTag(ItemTag[KS.Notes.PEN_TAGS[i]]) end)
        if ok and tagged then
            return true
        end
    end

    return isTypeIn(item, KS.Notes.PEN_TYPES)
end

-- Is this something you could write a copy onto?
local function isWritable(item)
    local ok, writable = pcall(function() return item:canBeWrite() end)

    if ok and type(writable) == "boolean" then
        return writable
    end

    return isTypeIn(item, KS.Notes.PAPER_TYPES)
end

-- Does it already have something written on it? Copying onto someone's diary
-- would destroy it, and the engine tracks this for us.
local function hasWriting(item)
    local ok, empty = pcall(function() return item:isEmptyPages() end)

    if ok and type(empty) == "boolean" then
        return not empty
    end

    return false
end

local function isBlankPaper(item, original)
    if item == original then
        return false
    end
    if not isWritable(item) then
        return false
    end
    -- Never cannibalise another quest note, or anything already written on --
    -- someone's own journal included.
    if KS.Notes.idOf(item) then
        return false
    end
    if item:getLockedBy() then
        return false
    end
    if hasWriting(item) then
        return false
    end
    return true
end

-- Returns pen, paper on success, or nil, nil, reason. The reason is written for
-- a player to read: it goes straight into the greyed-out menu tooltip.
function KS.Notes.findCopyMaterials(player, original)
    local inventory = player:getInventory()

    local pen = KS.Inventory.find(inventory, isPen)
    if not pen then
        return nil, nil, "You need a pen or pencil."
    end

    local paper = KS.Inventory.find(inventory, function(item)
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
