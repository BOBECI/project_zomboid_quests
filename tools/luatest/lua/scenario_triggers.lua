--------------------------------------------------------------------------------
-- Scenario 5: the four trigger types.
--
-- Build plan Phase 3 is done when all four fire correctly from a data file
-- rather than from bespoke code, so these tests drive them entirely through
-- quest data and the generic evaluator.
--------------------------------------------------------------------------------

local check = CHECK

local KS = KnoxStories
local inv = PLAYER:getInventory()
local T = KS.Triggers.types

local function clearInventory()
    local items = inv:getItems()
    while items:size() > 0 do
        inv:Remove(items:get(0))
    end
end

local function at(x, y, z)
    PLAYER.x, PLAYER.y, PLAYER.z = x, y, z or 0
end

local function tick()
    for i = 1, 35 do Events.OnPlayerUpdate.fire(PLAYER) end
end

local function where(id)
    local p = KS.State.get().quests[id]
    if not p then return "<no record>" end
    return p.status .. "/" .. tostring(p.step)
end

local function countSpec(spec)
    local n = 0
    local items = inv:getItems()
    local matches = KS.Inventory.specMatcher(spec)
    for i = 0, items:size() - 1 do
        if matches(items:get(i)) then n = n + 1 end
    end
    return n
end

Events.OnInitGlobalModData.fire(false)
Events.OnGameStart.fire()

print("\n[22] all four types are registered")
check("enter_area", T.enter_area ~= nil)
check("acquire_item", T.acquire_item ~= nil)
check("read_note", T.read_note ~= nil)
check("deliver_item", T.deliver_item ~= nil)

print("\n[23] trigger parameters are validated, with readable reasons")
local function why(typeName, params)
    local ok, reason = T[typeName].validate(params)
    if ok then return nil end
    return reason
end

check("acquire_item with nothing named is rejected",
    why("acquire_item", {}) ~= nil, why("acquire_item", {}))
check("acquire_item naming both item and note is rejected",
    why("acquire_item", { item = "Base.Pen", note = "dummy_scrap" }) ~= nil)
check("acquire_item naming an unknown note is rejected",
    why("acquire_item", { note = "no_such_note" }) ~= nil)
check("acquire_item naming a real note is accepted",
    why("acquire_item", { note = "dummy_scrap" }) == nil)

check("read_note without a note is rejected", why("read_note", {}) ~= nil)
check("read_note pointed at a plain item is rejected",
    why("read_note", { item = "Base.Pen" }) ~= nil)

check("deliver_item without coordinates is rejected",
    why("deliver_item", { note = "dummy_scrap" }) ~= nil)
check("deliver_item with a zero range is rejected",
    why("deliver_item", { note = "dummy_scrap", x = 1, y = 1, range = 0 }) ~= nil)

local defaulted = { note = "dummy_scrap", x = 10, y = 20 }
check("deliver_item accepts a point", T.deliver_item.validate(defaulted) == true)
check("range defaults to 2", defaulted.range == 2, defaulted.range)
check("floor defaults to 0", defaulted.z == 0, defaulted.z)

print("\n[24] acquire_item")
clearInventory()
local spec = { type = "acquire_item", item = "Base.Screwdriver" }
check("does not fire on an empty inventory", T.acquire_item.test(spec, PLAYER) == false)

local bag = instanceItem("Base.Notepad")
bag._inventory = TestContainer.new()
inv:AddItem(bag)
bag:getInventory():AddItem("Base.Screwdriver")
check("finds an item inside a bag", T.acquire_item.test(spec, PLAYER) == true)

clearInventory()
local noteSpec = { type = "acquire_item", note = "dummy_scrap" }
check("does not fire before the note is held", T.acquire_item.test(noteSpec, PLAYER) == false)
KS.Notes.giveTo(PLAYER, "dummy_scrap")
check("fires once the note is held", T.acquire_item.test(noteSpec, PLAYER) == true)

print("\n[25] read_note")
clearInventory()
local scrap = KS.Notes.giveTo(PLAYER, "dummy_scrap")
local readSpec = { type = "read_note", note = "dummy_scrap" }
check("holding an unread note is not enough", T.read_note.test(readSpec, PLAYER) == false)
check("the note reports itself unread", KS.Notes.isRead(scrap) == false)

-- Go through the real hook rather than calling markRead directly, so the wrapper
-- itself is under test.
ISInventoryPaneContextMenu.onWriteSomething(scrap, false, 0)
check("opening the note marks it read", KS.Notes.isRead(scrap) == true)
check("read_note now fires", T.read_note.test(readSpec, PLAYER) == true)
check("the wrapper still called the vanilla function",
    #ISInventoryPaneContextMenu.opened == 1, #ISInventoryPaneContextMenu.opened)
check("and passed its arguments through unchanged",
    ISInventoryPaneContextMenu.opened[1].notebook == scrap
        and ISInventoryPaneContextMenu.opened[1].editable == false
        and ISInventoryPaneContextMenu.opened[1].player == 0)

-- A fresh copy is a fresh piece of paper: nobody has read it.
inv:AddItem("Base.Pen")
inv:AddItem("Base.SheetPaper2")
KS.Notes.performCopy(PLAYER, scrap)
local copy = nil
local items = inv:getItems()
for i = 0, items:size() - 1 do
    local it = items:get(i)
    if KS.Notes.idOf(it) == "dummy_scrap" and it ~= scrap then copy = it end
end
check("a copy starts unread", KS.Notes.isRead(copy) == false)

check("opening a plain item marks nothing",
    KS.Notes.markRead(instanceItem("Base.SheetPaper2")) == false)

print("\n[26] deliver_item")
clearInventory()
local deliverSpec = { type = "deliver_item", note = "dummy_scrap", x = 100, y = 200, z = 0, range = 3 }
KS.Notes.giveTo(PLAYER, "dummy_scrap")

at(500, 500, 0)
check("carrying it but far away does not fire", T.deliver_item.test(deliverSpec, PLAYER) == false)

at(101, 201, 0)
check("in range and carrying it fires", T.deliver_item.test(deliverSpec, PLAYER) == true)

at(101, 201, 1)
check("the right spot on the wrong floor does not fire",
    T.deliver_item.test(deliverSpec, PLAYER) == false)

at(101, 201, 0)
clearInventory()
check("in range without the item does not fire", T.deliver_item.test(deliverSpec, PLAYER) == false)

-- Consuming takes exactly one, and only the right one.
KS.Notes.giveTo(PLAYER, "dummy_scrap")
KS.Notes.giveTo(PLAYER, "dummy_scrap")
local bystander = KS.Notes.giveTo(PLAYER, "dummy_letter")
T.deliver_item.consume(deliverSpec, PLAYER)
check("exactly one was taken", countSpec(deliverSpec) == 1, countSpec(deliverSpec))
check("an unrelated note was left alone", inv:contains(bystander))

clearInventory()
check("consuming nothing is survivable", pcall(T.deliver_item.consume, deliverSpec, PLAYER) == true)

print("\n[27] dummy_c end to end, driven only by data")
clearInventory()
KS.State.get().quests.dummy_c = { status = KS.STATUS.ACTIVE, step = "arrive" }

at(8300, 11500, 0)
tick()
check("1. enter_area advanced the step", where("dummy_c") == "active/read_the_letter", where("dummy_c"))
check("   and the step handed over its note", countSpec({ note = "dummy_scrap" }) == 1)

tick()
check("read_note holds until the note is opened",
    where("dummy_c") == "active/read_the_letter", where("dummy_c"))

local held = KS.Inventory.findBySpec(PLAYER, { note = "dummy_scrap" })
ISInventoryPaneContextMenu.onWriteSomething(held, false, 0)
tick()
check("2. read_note advanced the step", where("dummy_c") == "active/find_a_screwdriver", where("dummy_c"))

tick()
check("acquire_item holds until the item is held",
    where("dummy_c") == "active/find_a_screwdriver", where("dummy_c"))

inv:AddItem("Base.Screwdriver")
tick()
check("3. acquire_item advanced the step", where("dummy_c") == "active/hand_it_over", where("dummy_c"))

tick()
check("deliver_item holds until the player is at the drop point",
    where("dummy_c") == "active/hand_it_over", where("dummy_c"))

at(8040, 11790, 0)
tick()
check("4. deliver_item completed the quest", where("dummy_c") == "complete/nil", where("dummy_c"))
check("   and the delivered note was taken", countSpec({ note = "dummy_scrap" }) == 0,
    countSpec({ note = "dummy_scrap" }))
check("   but the screwdriver was not", countSpec({ item = "Base.Screwdriver" }) == 1)

print("\n[28] the debug reset, so a trigger chain can be walked twice")
check("resetting an unknown quest is refused", KS.State.debugResetQuest("ghost") == false)
check("reset puts dummy_c back to its first step",
    KS.State.debugResetQuest("dummy_c") == true and where("dummy_c") == "active/arrive",
    where("dummy_c"))
KS.DEBUG = false
check("reset does nothing with DEBUG off", KS.State.debugResetQuest("dummy_a") == false)
KS.DEBUG = true

