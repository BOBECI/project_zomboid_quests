--------------------------------------------------------------------------------
-- Scenario 4: notes. Definition validation, writing text onto a vanilla item,
-- locking, and the pen + paper + original copy recipe.
--
-- Runs on a freshly reloaded mod, so the note registry has not been validated
-- yet and broken definitions can still be appended.
--------------------------------------------------------------------------------

local check = CHECK

local KS = KnoxStories
local inv = PLAYER:getInventory()

-- The ModData key a note item carries. Hard-coded on purpose: it is a
-- persisted, on-disk key, so a change to it is a save-breaking change and this
-- test should fail loudly if it moves.
local NOTE_KEY = "knoxStoriesNote"

local function clearInventory()
    local items = inv:getItems()
    while items:size() > 0 do
        inv:Remove(items:get(0))
    end
end

local function countType(fullType)
    local n = 0
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        if items:get(i):getFullType() == fullType then n = n + 1 end
    end
    return n
end

local function firstNoteItem(noteId)
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        if KS.Notes.idOf(items:get(i)) == noteId then return items:get(i) end
    end
    return nil
end

-- Broken definitions, appended before anything reads the note registry.
table.insert(KS.NoteDefs, { item = "Base.Notepad", title = "no id", pages = { "x" } })
table.insert(KS.NoteDefs, { id = "no_pages", item = "Base.Notepad", title = "t", pages = {} })
table.insert(KS.NoteDefs, { id = "no_item", title = "t", pages = { "x" } })
table.insert(KS.NoteDefs, { id = "bad_page", item = "Base.Notepad", title = "t", pages = { 42 } })
table.insert(KS.NoteDefs, { id = "dummy_letter", item = "Base.Notepad", title = "dupe", pages = { "x" } })

-- Valid definition naming an item the game does not have. This is the case that
-- proves a failed copy costs the player nothing.
table.insert(KS.NoteDefs, {
    id = "broken_item", item = "Base.DoesNotExist", title = "Ghost note", pages = { "x" },
})

print("\n[13] note definition validation")
Events.OnInitGlobalModData.fire(false)
Events.OnGameStart.fire()
local validNotes, invalidNotes = KS.Notes.ensureValidated()
check("3 valid notes registered", validNotes == 3, validNotes)
check("5 broken notes skipped", invalidNotes == 5, invalidNotes)
check("a note with no id is unreachable", KS.Notes.get(nil) == nil)
check("a duplicate id does not replace the original",
    KS.Notes.get("dummy_letter").title == "Water-stained letter",
    KS.Notes.get("dummy_letter").title)

print("\n[14] writing a note onto a vanilla item")
clearInventory()
local letter = KS.Notes.create("dummy_letter")
local def = KS.Notes.get("dummy_letter")
check("item is the vanilla type from the data", letter:getFullType() == "Base.Notepad")
check("name comes from the data", letter:getName() == "Water-stained letter", letter:getName())
check("marked as a custom name", letter._customName == true)
check("writing enabled before pages are added", letter._canBeWrite == true)
check("page count matches the data", letter._pageToWrite == #def.pages, letter._pageToWrite)
check("every page was written", letter:getNumberOfPages() == #def.pages)
check("<LINE> expanded to a newline", letter:getPage(1):find("\n") ~= nil)
check("<LINE> token itself is gone", letter:getPage(1):find("<LINE>") == nil)
check("locked so the player cannot overwrite it", letter:getLockedBy() == "knoxStories")
check("carries its id in ModData", letter:getModData()[NOTE_KEY] == "dummy_letter")

check("unknown note id creates nothing", KS.Notes.create("nope") == nil)
check("a note naming a missing item creates nothing", KS.Notes.create("broken_item") == nil)
check("idOf is nil for a plain item", KS.Notes.idOf(instanceItem("Base.SheetPaper2")) == nil)
check("idOf finds our note", KS.Notes.idOf(letter) == "dummy_letter")

print("\n[15] copy materials")
clearInventory()
local original = KS.Notes.giveTo(PLAYER, "dummy_letter")
local ok, reason = KS.Notes.canCopy(PLAYER, original)
check("no pen, no copy", ok == false)
check("and it says which material is missing", reason == "You need a pen or pencil.", reason)

local pen = inv:AddItem("Base.Pen")
ok, reason = KS.Notes.canCopy(PLAYER, original)
check("pen but no paper, no copy", ok == false)
check("and it names the paper", reason == "You need a blank sheet of paper.", reason)

check("the original is never treated as its own blank paper",
    countType("Base.Notepad") == 1 and ok == false)

local otherNote = KS.Notes.giveTo(PLAYER, "dummy_envelope")
ok = KS.Notes.canCopy(PLAYER, original)
check("another quest note is not blank paper", ok == false)

local writtenPad = inv:AddItem("Base.Notepad")
writtenPad:setLockedBy("someoneElse")
ok = KS.Notes.canCopy(PLAYER, original)
check("a locked notepad is not blank paper", ok == false)

inv:AddItem("Base.SheetPaper2")
ok = KS.Notes.canCopy(PLAYER, original)
check("pen plus paper, copy allowed", ok == true)

print("\n[16] the copy itself")
local penBefore = pen:getUsedDelta()
local paperBefore = countType("Base.SheetPaper2")
local copied, why = KS.Notes.performCopy(PLAYER, original)
check("copy succeeded", copied == true, why)
check("exactly one sheet of paper consumed",
    countType("Base.SheetPaper2") == paperBefore - 1, countType("Base.SheetPaper2"))
-- Vanilla pens are base:weapon, not drainable, so copying must neither wear
-- them out nor destroy them.
check("the pen survives the copy", inv:contains(pen))
check("a vanilla pen does not wear out", pen:getUsedDelta() == penBefore)
check("the locked notepad was not consumed", inv:contains(writtenPad))
check("the other quest note was not consumed", inv:contains(otherNote))
check("the original is still there", inv:contains(original))

local copies = 0
local items = inv:getItems()
for i = 0, items:size() - 1 do
    if KS.Notes.idOf(items:get(i)) == "dummy_letter" then copies = copies + 1 end
end
check("there are now two of this note", copies == 2, copies)

local duplicate = nil
for i = 0, items:size() - 1 do
    local it = items:get(i)
    if KS.Notes.idOf(it) == "dummy_letter" and it ~= original then duplicate = it end
end
check("the copy has the same name", duplicate:getName() == original:getName())
check("the copy has the same first page", duplicate:getPage(1) == original:getPage(1))
check("the copy has the same second page", duplicate:getPage(2) == original:getPage(2))
check("the copy is locked too", duplicate:getLockedBy() == "knoxStories")
check("the copy carries the same id", duplicate:getModData()[NOTE_KEY] == "dummy_letter")

print("\n[17] a copy of a copy is still identical")
inv:AddItem("Base.SheetPaper2")
check("copying the duplicate works", KS.Notes.performCopy(PLAYER, duplicate) == true)
local third = nil
for i = 0, items:size() - 1 do
    local it = items:get(i)
    if KS.Notes.idOf(it) == "dummy_letter" and it ~= original and it ~= duplicate then third = it end
end
check("third copy exists", third ~= nil)
check("third copy matches the original text", third:getPage(1) == original:getPage(1))

print("\n[18] a failed copy costs nothing")
clearInventory()
local ghost = instanceItem("Base.Notepad")
ghost:getModData()[NOTE_KEY] = "broken_item"
inv:AddItem(ghost)
inv:AddItem("Base.Pen")
inv:AddItem("Base.SheetPaper2")
local failedOk, failedWhy = KS.Notes.performCopy(PLAYER, ghost)
check("copy failed", failedOk == false, failedWhy)
check("paper was not consumed", countType("Base.SheetPaper2") == 1, countType("Base.SheetPaper2"))

clearInventory()
local plain = inv:AddItem("Base.SheetPaper2")
check("a plain item cannot be copied", KS.Notes.performCopy(PLAYER, plain) == false)

-- A modded pen that is drainable should still be used up a little.
clearInventory()
local drainNote = KS.Notes.giveTo(PLAYER, "dummy_letter")
local drainPen = inv:AddItem("Base.Pen")
drainPen._drainable = true
inv:AddItem("Base.SheetPaper2")
local drainBefore = drainPen:getUsedDelta()
check("copy with a drainable pen works", KS.Notes.performCopy(PLAYER, drainNote) == true)
check("a drainable pen is used up a little", drainPen:getUsedDelta() < drainBefore)

print("\n[19] the context menu a player actually sees")
clearInventory()
local note = KS.Notes.giveTo(PLAYER, "dummy_letter")

local menu = TestMenu.new()
Events.OnFillInventoryObjectContextMenu.fire(0, menu, { note })
local option = menu:find("Copy this note")
check("the option appears on a quest note", option ~= nil)
check("it is greyed out with no materials", option.notAvailable == true)
check("the tooltip says why", option.toolTip.description == "You need a pen or pencil.",
    option.toolTip and option.toolTip.description)

inv:AddItem("Base.Pen")
inv:AddItem("Base.SheetPaper2")
menu = TestMenu.new()
Events.OnFillInventoryObjectContextMenu.fire(0, menu, { note })
option = menu:find("Copy this note")
check("it is enabled once you have the materials", option.notAvailable == nil)

menu = TestMenu.new()
Events.OnFillInventoryObjectContextMenu.fire(0, menu, { instanceItem("Base.SheetPaper2") })
check("no option on a plain item", menu:find("Copy this note") == nil)

print("\n[20] the timed action")
local action = KS_CopyNoteAction:new(PLAYER, note)
check("length scales with page count", action.maxTime == 180 * #def.pages, action.maxTime)
check("valid while the materials are there", action:isValid() == true)
action:perform()
check("performing it produced a copy", countType("Base.Notepad") == 2, countType("Base.Notepad"))

clearInventory()
inv:AddItem(note)
check("no longer valid once the pen is gone", action:isValid() == false)

print("")
if FAILURES == 0 then
    print("ALL CHECKS PASSED")
else
    print(FAILURES .. " CHECK(S) FAILED")
end
