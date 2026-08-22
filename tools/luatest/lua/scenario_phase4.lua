--------------------------------------------------------------------------------
-- Scenario 6: Phase 4 tooling.
--
-- Cell-load dressing, the in-game recorder that authors it, and the conditional
-- examine trigger.
--------------------------------------------------------------------------------

local check = CHECK

local KS = KnoxStories
local inv = PLAYER:getInventory()

local function clearInventory()
    local items = inv:getItems()
    while items:size() > 0 do inv:Remove(items:get(0)) end
end

local function tick()
    for i = 1, 35 do Events.OnPlayerUpdate.fire(PLAYER) end
end

local function where(id)
    local p = KS.State.get().quests[id]
    if not p then return "<no record>" end
    return p.status .. "/" .. tostring(p.step)
end

-- Dressing sets are registered before anything reads the registry, exactly as a
-- recorded file would be at load time.
table.insert(KS.DressingSets, {
    id = "test_house",
    objects = { { x = 50, y = 60, z = 0, sprite = "furniture_seating_indoor_01_20" } },
    items = { { x = 50, y = 60, z = 0, item = "Base.PillsBeta" } },
})
table.insert(KS.DressingSets, {
    id = "surface_test",
    objects = {},
    items = { { x = 70, y = 80, z = 0, item = "Base.Plate", ox = 0.4, oy = 0.6, oz = 0.5 } },
})
table.insert(KS.DressingSets, { objects = {}, items = {} })
table.insert(KS.DressingSets, { id = "empty_set", objects = {}, items = {} })
table.insert(KS.DressingSets, {
    id = "bad_coords", objects = { { x = 1, sprite = "a" } }, items = {},
})
table.insert(KS.DressingSets, {
    id = "no_sprite", objects = { { x = 1, y = 2, z = 0 } }, items = {},
})

Events.OnInitGlobalModData.fire(false)
Events.OnGameStart.fire()

print("\n[29] dressing set validation")
local validSets, invalidSets = KS.Dressing.ensureValidated()
-- Asserted against the sets this file registers, not a total count: real
-- recorded dressing files live in the mod too, and adding one must not break
-- the suite.
check("this file's two sets validated",
    KS.Dressing.forSquare(50, 60, 0) ~= nil and KS.Dressing.forSquare(70, 80, 0) ~= nil)
check("4 broken sets skipped", invalidSets == 4, invalidSets)
check("at least those two are valid", validSets >= 2, validSets)
check("a set placing nothing is rejected", KS.Dressing.forSquare(1, 2, 0) == nil)

print("\n[30] dressing a square as its cell loads")
local square = getCell():getGridSquare(50, 60, 0)
square:addVanilla("walls_exterior_house_01_0")
local before = square:getObjects():size()

Events.LoadGridsquare.fire(square)
check("the object was placed", square:getObjects():size() == before + 1,
    square:getObjects():size())
check("the item was dropped", square:getWorldObjects():size() == 1)
check("the vanilla wall is untouched", square:getObjects():get(0):getSprite():getName()
    == "walls_exterior_house_01_0")

-- The whole point of tracking dressed squares: loot the house, come back, and it
-- must not have restocked itself.
Events.LoadGridsquare.fire(square)
Events.LoadGridsquare.fire(square)
check("re-loading the cell does not dress it again",
    square:getObjects():size() == before + 1, square:getObjects():size())
check("and does not drop a second item", square:getWorldObjects():size() == 1)

local elsewhere = getCell():getGridSquare(999, 999, 0)
Events.LoadGridsquare.fire(elsewhere)
check("a square with no dressing is left alone", elsewhere:getObjects():size() == 0)

print("\n[31] the recorder captures additions only")
PLAYER.x, PLAYER.y, PLAYER.z = 200, 300, 0

-- Something the map already had. It must not end up in the export.
local target = getCell():getGridSquare(201, 301, 0)
target:addVanilla("walls_exterior_house_01_0")

check("recording starts", KS.Recorder.start(PLAYER, "test_set", 2) == true)
check("and says so", KS.Recorder.isRecording() == true)

-- Dress: two objects on one square, one item on another.
target:AddSpecialObject(IsoObject.new(nil, target, "furniture_tables_01_1"))
target:AddSpecialObject(IsoObject.new(nil, target, "furniture_tables_01_1"))
getCell():getGridSquare(199, 299, 0):AddWorldInventoryItem("Base.TinCanEmpty", 0, 0, 0)

-- On a table, not the floor. Found in play: the first version stored only the
-- tile, so everything came back on the ground -- which for two place settings on
-- a dining table reads as looting rather than as a room left mid-use.
getCell():getGridSquare(199, 299, 0):AddWorldInventoryItem("Base.Plate", 0.4, 0.6, 0.5)

local set = KS.Recorder.finish()
check("recording stops", KS.Recorder.isRecording() == false)
check("two objects captured", #set.objects == 2, #set.objects)
check("two items captured", #set.items == 2, #set.items)
check("the vanilla wall was not captured", (function()
    for i = 1, #set.objects do
        if set.objects[i].sprite == "walls_exterior_house_01_0" then return false end
    end
    return true
end)())
check("captured objects carry their coordinates",
    set.objects[1].x == 201 and set.objects[1].y == 301 and set.objects[1].z == 0)
check("captured item carries its type", set.items[1].item == "Base.TinCanEmpty",
    set.items[1].item)

-- The engine will not open a .lua file for writing, so the exporter falls back
-- through a list of extensions. .txt is the first it should land on.
check("nothing was written as .lua", WRITTEN_FILES["KnoxStories_test_set.lua"] == nil)
local written = WRITTEN_FILES["KnoxStories_test_set.txt"]
check("a file was written as .txt instead", written ~= nil and #written > 0)
check("and it says to rename it", written and written:find("RENAME THIS FILE") ~= nil)
check("it registers a dressing set", written:find("KnoxStories.DressingSets") ~= nil)
check("it contains the placed sprite", written:find("furniture_tables_01_1") ~= nil)
check("it does not contain the vanilla wall",
    written:find("walls_exterior_house_01_0") == nil)

-- Defect 2: the height offset has to survive the round trip, or a plate
-- recorded on a table comes back on the floor.
local plate = nil
for i = 1, #set.items do
    if set.items[i].item == "Base.Plate" then plate = set.items[i] end
end
check("the plate on the table was captured", plate ~= nil)
check("its height offset was captured", plate and math.abs(plate.oz - 0.5) < 0.001, plate and plate.oz)
check("and its position across the tile", plate
    and math.abs(plate.ox - 0.4) < 0.001 and math.abs(plate.oy - 0.6) < 0.001)
check("the export writes the offsets", written:find("oz = 0.500") ~= nil)

-- And back out again. The set itself is registered at the top of this file,
-- before anything validates the registry.
local surfaceSquare = getCell():getGridSquare(70, 80, 0)
KS.Dressing.applyToSquare(surfaceSquare)
local restored = surfaceSquare:getWorldObjects():get(0)
check("something was restored", restored ~= nil)
check("restored onto the surface, not the floor",
    restored and math.abs(restored:getWorldPosZ() - 0.5) < 0.001,
    restored and restored:getWorldPosZ())
check("and at the right spot across the tile",
    restored and math.abs(restored:getWorldPosX() - 70.4) < 0.001,
    restored and restored:getWorldPosX())

check("finishing with nothing recording returns nothing", KS.Recorder.finish() == nil)

-- A failed export must not throw the recording away: re-dressing a house because
-- a file would not open is the worst possible outcome here.
FILE_WRITER_BLOCKED = { [".txt"] = true, [".ini"] = true, [".log"] = true,
                        [".cfg"] = true, [".lua"] = true }
KS.Recorder.start(PLAYER, "doomed", 1)
check("an export that cannot write returns nothing", KS.Recorder.finish() == nil)
check("but keeps the recording so it can be retried", KS.Recorder.isRecording() == true)
FILE_WRITER_BLOCKED = { [".lua"] = true }
check("and retrying then works", KS.Recorder.finish() ~= nil)
check("recording obeys the debug flag", (function()
    KS.DEBUG = false
    local started = KS.Recorder.start(PLAYER, "nope", 1)
    KS.DEBUG = true
    return started == false
end)())

print("\n[32] examine trigger validation")
local function why(params)
    local ok, reason = KS.Triggers.types.examine.validate(params)
    if ok then return nil end
    return reason
end
check("examine with nothing named is rejected", why({}) ~= nil)
check("requires naming an unknown note is rejected",
    why({ item = "Base.PillsBeta", requires = "no_such_note" }) ~= nil)
check("requires naming a real note is accepted",
    why({ item = "Base.PillsBeta", requires = "dummy_envelope" }) == nil)
check("examine without requires is accepted", why({ item = "Base.PillsBeta" }) == nil)

print("\n[33] the option is absent until the note is carried")
clearInventory()
local pills = inv:AddItem("Base.PillsBeta")
check("dummy_d is waiting on the examine step",
    where("dummy_d") == "active/examine_the_pills", where("dummy_d"))
check("no step offered without the note", KS.Examine.stepFor(PLAYER, pills) == nil)

local menu = TestMenu.new()
Events.OnFillInventoryObjectContextMenu.fire(0, menu, { pills })
check("and no Examine option in the menu", menu:find("Examine") == nil)

KS.Notes.giveTo(PLAYER, "dummy_envelope")
check("carrying the note makes it examinable", KS.Examine.stepFor(PLAYER, pills) ~= nil)

menu = TestMenu.new()
Events.OnFillInventoryObjectContextMenu.fire(0, menu, { pills })
local option = menu:find("Examine")
check("the Examine option appears", option ~= nil)

print("\n[34] examining is an act, not something that happens to you")
-- Found in play: with the note already in hand, the step fired the moment the
-- pills were picked up, so the option had already been used by the time the
-- player right-clicked. Nothing except the menu may advance an examine step.
for _ = 1, 5 do tick() end
check("carrying both, indefinitely, advances nothing",
    where("dummy_d") == "active/examine_the_pills", where("dummy_d"))
check("the trigger is not polled at all", KS.Triggers.types.examine.test == nil)

option.onSelect(option.target, option.args[1])
check("choosing Examine completes the quest",
    where("dummy_d") == "complete/nil", where("dummy_d"))

menu = TestMenu.new()
Events.OnFillInventoryObjectContextMenu.fire(0, menu, { pills })
check("and the option is gone once the step is done", menu:find("Examine") == nil)

print("\n[35] a quest reset is a real reset, on the same objects")
-- Found in play: the examined flag lived on the item and outlived the reset, so
-- re-running with the same packet silently did nothing. Nothing is written onto
-- the item now, so the same packet has to work again.
check("reset", KS.State.debugResetQuest("dummy_d") == true)
check("the same pills and the same card are examinable again",
    KS.Examine.stepFor(PLAYER, pills) ~= nil)

menu = TestMenu.new()
Events.OnFillInventoryObjectContextMenu.fire(0, menu, { pills })
option = menu:find("Examine")
check("the option is back on the very same item", option ~= nil)
option.onSelect(option.target, option.args[1])
check("and completes again", where("dummy_d") == "complete/nil", where("dummy_d"))

-- Two identical packets must behave identically.
KS.State.debugResetQuest("dummy_d")
local secondPacket = inv:AddItem("Base.PillsBeta")
check("a second identical packet behaves the same as the first",
    (KS.Examine.stepFor(PLAYER, pills) ~= nil)
        == (KS.Examine.stepFor(PLAYER, secondPacket) ~= nil))

print("\n[36] copying accepts anything the game says is writable")
clearInventory()
local original = KS.Notes.giveTo(PLAYER, "dummy_letter")
inv:AddItem("Base.Pencil")

for _, paper in ipairs({ "Base.GraphPaper", "Base.IndexCard", "Base.Journal", "Base.Notebook" }) do
    clearInventory()
    original = KS.Notes.giveTo(PLAYER, "dummy_letter")
    inv:AddItem("Base.Pencil")
    inv:AddItem(paper)
    check(paper .. " counts as blank paper", KS.Notes.canCopy(PLAYER, original) == true)
end

-- A pencil is a writing implement by tag, not because it is on a list.
clearInventory()
original = KS.Notes.giveTo(PLAYER, "dummy_letter")
inv:AddItem("Base.SheetPaper2")
local moddedPen = inv:AddItem("Base.Screwdriver")
moddedPen._tags = { write = true }
check("anything tagged as a writing implement works",
    KS.Notes.canCopy(PLAYER, original) == true)

-- But a journal someone has written in is not scrap paper.
clearInventory()
original = KS.Notes.giveTo(PLAYER, "dummy_letter")
inv:AddItem("Base.Pen")
local usedJournal = inv:AddItem("Base.Journal")
usedJournal:addPage(1, "someone's diary")
local ok2, reason2 = KS.Notes.canCopy(PLAYER, original)
check("a journal with writing in it is not blank paper", ok2 == false, reason2)

print("\n[37] scanning for paper must not touch non-literature items")
-- Found in play: isWritable called canBeWrite() on everything in the inventory.
-- That method is literature-only, so a screwdriver raised an engine error -- and
-- because the copy walks the whole inventory, and the timed action re-walked it
-- every tick, the console filled with stack traces during a copy.
--
-- The stubs now throw exactly as the engine does, so forgetting the guard fails
-- here instead of quietly spamming the player.
clearInventory()
local letter = KS.Notes.giveTo(PLAYER, "dummy_letter")
inv:AddItem("Base.Pen")
inv:AddItem("Base.SheetPaper2")

-- A pile of things that are emphatically not literature, including one inside a
-- bag, because the scan recurses.
inv:AddItem("Base.Screwdriver")
inv:AddItem("Base.PillsBeta")
local toolbag = instanceItem("Base.Notepad")
toolbag._inventory = TestContainer.new()
toolbag._category = "Container"
inv:AddItem(toolbag)
toolbag:getInventory():AddItem("Base.Screwdriver")

ENGINE_ERRORS = {}
local scanOk, scanResult = pcall(KS.Notes.canCopy, PLAYER, letter)
check("scanning a mixed inventory does not error", scanOk == true, not scanOk and scanResult)
check("and still finds the paper", scanOk and scanResult == true)

local mixedCopied, mixedWhy = KS.Notes.performCopy(PLAYER, letter)
check("the copy itself survives a mixed inventory", mixedCopied == true, mixedWhy)
check("the engine was never asked about a non-literature item",
    #ENGINE_ERRORS == 0, ENGINE_ERRORS[1])

print("\n[38] the copy action does not rescan the inventory every tick")
clearInventory()
letter = KS.Notes.giveTo(PLAYER, "dummy_letter")
local actionPen = inv:AddItem("Base.Pen")
local actionPaper = inv:AddItem("Base.SheetPaper2")
inv:AddItem("Base.Screwdriver")

ENGINE_ERRORS = {}
local action = KS_CopyNoteAction:new(PLAYER, letter)
check("materials are captured once, when the action is queued",
    action.pen == actionPen and action.paper == actionPaper)
check("valid while they are held", action:isValid() == true)

local quiet = true
for _ = 1, 200 do
    quiet = quiet and pcall(function() return action:isValid() end)
end
check("200 ticks of isValid raise nothing", quiet == true)
check("and never provoke the engine", #ENGINE_ERRORS == 0, ENGINE_ERRORS[1])

inv:Remove(actionPaper)
check("dropping the paper invalidates the action", action:isValid() == false)

print("\n[39] the coordinate readout")
DRAWN_STRINGS = {}
PLAYER.x, PLAYER.y, PLAYER.z = 8041, 11792, 0
Events.OnPostUIDraw.fire()
check("it draws the position", DRAWN_STRINGS[1] == "8041, 11792, 0", DRAWN_STRINGS[1])

DRAWN_STRINGS = {}
KS.DEBUG = false
Events.OnPostUIDraw.fire()
check("and draws nothing with the debug flag off", #DRAWN_STRINGS == 0, #DRAWN_STRINGS)
KS.DEBUG = true

print("")
if FAILURES == 0 then
    print("ALL CHECKS PASSED")
else
    print(FAILURES .. " CHECK(S) FAILED")
end
