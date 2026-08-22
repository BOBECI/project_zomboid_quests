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
check("1 valid dressing set", validSets == 1, validSets)
check("4 broken sets skipped", invalidSets == 4, invalidSets)
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

local set = KS.Recorder.finish()
check("recording stops", KS.Recorder.isRecording() == false)
check("two objects captured", #set.objects == 2, #set.objects)
check("one item captured", #set.items == 1, #set.items)
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

local written = WRITTEN_FILES["KnoxStories_dressing_test_set.lua"]
check("a file was written", written ~= nil and #written > 0)
check("it registers a dressing set", written:find("KnoxStories.DressingSets") ~= nil)
check("it contains the placed sprite", written:find("furniture_tables_01_1") ~= nil)
check("it does not contain the vanilla wall",
    written:find("walls_exterior_house_01_0") == nil)

check("finishing with nothing recording returns nothing", KS.Recorder.finish() == nil)
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
check("no trigger offered without the note", KS.Examine.triggerFor(PLAYER, pills) == nil)

local menu = TestMenu.new()
Events.OnFillInventoryObjectContextMenu.fire(0, menu, { pills })
check("and no Examine option in the menu", menu:find("Examine") == nil)

KS.Notes.giveTo(PLAYER, "dummy_envelope")
check("carrying the note makes it examinable", KS.Examine.triggerFor(PLAYER, pills) ~= nil)

menu = TestMenu.new()
Events.OnFillInventoryObjectContextMenu.fire(0, menu, { pills })
local option = menu:find("Examine")
check("the Examine option appears", option ~= nil)

print("\n[34] examining advances the step through the normal evaluator")
check("still unexamined", KS.Examine.isExamined(pills) == false)
tick()
check("holding both is not enough on its own",
    where("dummy_d") == "active/examine_the_pills", where("dummy_d"))

option.onSelect(option.target, option.args[1])
check("the menu option marked it examined", KS.Examine.isExamined(pills) == true)
tick()
check("dummy_d completed", where("dummy_d") == "complete/nil", where("dummy_d"))
check("examining twice is a no-op", KS.Examine.mark(pills) == false)

print("\n[35] the coordinate readout")
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
