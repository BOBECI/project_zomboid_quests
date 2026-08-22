--------------------------------------------------------------------------------
-- Scenario 7: NPCs.
--
-- The zombie-as-NPC disguise, the spawn handshake and its retry, and the
-- dialogue window.
--------------------------------------------------------------------------------

local check = CHECK

local KS = KnoxStories

local function loadSquare(x, y, z, solid, free)
    local square = getCell():getGridSquare(x, y, z)
    square:setStandable(solid, free)
    return square
end

table.insert(KS.NPCDefs, { name = "no id", x = 1, y = 1, dialogue = { "hi" } })
table.insert(KS.NPCDefs, { id = "no_name", x = 1, y = 1, dialogue = { "hi" } })
table.insert(KS.NPCDefs, { id = "no_place", name = "Nowhere", dialogue = { "hi" } })
table.insert(KS.NPCDefs, { id = "silent", name = "Silent", x = 1, y = 1, dialogue = {} })

Events.OnInitGlobalModData.fire(false)
Events.OnGameStart.fire()

print("\n[40] npc registry")
local validNPCs, invalidNPCs = KS.NPCs.ensureValidated()
check("diane registered", KS.NPCs.get("diane") ~= nil)
check("4 broken npcs skipped", invalidNPCs == 4, invalidNPCs)
check("an npc with nothing to say is rejected", KS.NPCs.get("silent") == nil)
check("defaults applied", KS.NPCs.get("diane").z == 0 and KS.NPCs.get("diane").outfit ~= nil)

local diane = KS.NPCs.get("diane")
check("found by tile", KS.NPCs.atTile(diane.x, diane.y) == diane)
check("not found on a tile nobody stands on", KS.NPCs.atTile(1, 1) == nil)

print("\n[41] finding somewhere to stand")
-- Nothing loaded at all.
LOADED_SQUARES = {}
check("no square, no spawn point", KS.NPCSpawn.findSpawnSquare(diane) == nil)

-- The tile exists but is blocked -- the case the retry loop exists for.
LOADED_SQUARES = nil
loadSquare(diane.x, diane.y, 0, false, false)
check("a blocked tile is refused", KS.NPCSpawn.findSpawnSquare(diane) == nil)

-- A neighbour is clear.
loadSquare(diane.x + 1, diane.y, 0, true, true)
local found = KS.NPCSpawn.findSpawnSquare(diane)
check("falls back to a neighbouring tile", found ~= nil)
check("and it is the near one", found and found:getX() == diane.x + 1, found and found:getX())

-- The NPC's own tile wins when it is usable.
loadSquare(diane.x, diane.y, 0, true, true)
found = KS.NPCSpawn.findSpawnSquare(diane)
check("their own tile is preferred", found:getX() == diane.x and found:getY() == diane.y)

-- Solid but occupied is not good enough: two people cannot share a tile.
loadSquare(diane.x, diane.y, 0, true, false)
found = KS.NPCSpawn.findSpawnSquare(diane)
check("solid but occupied is refused", found:getX() ~= diane.x or found:getY() ~= diane.y)

print("\n[42] spawning, and the disguise")
loadSquare(diane.x, diane.y, 0, true, true)
SPAWNED_ZOMBIES = {}

Events.LoadGridsquare.fire(getCell():getGridSquare(diane.x, diane.y, 0))
check("one zombie was created", #SPAWNED_ZOMBIES == 1, #SPAWNED_ZOMBIES)

local npc = SPAWNED_ZOMBIES[1]
check("it is recorded as spawned", KS.NPCServer.isSpawned("diane") == true)
check("it knows which npc it is", KS.NPCs.idOf(npc) == "diane")
check("and resolves back to the definition", KS.NPCs.defOf(npc) == diane)

-- The disguise, item by item. Any one of these missing breaks the illusion.
check("it cannot walk", npc._canWalk == false)
check("it is useless to the zombie AI", npc._useless == true)
check("it cannot be killed", npc._invulnerable == true)
check("it cannot infect anyone", npc._noTeeth == true)
check("the human animation variable is set",
    npc:getVariable(KS.NPCs.ANIM_VARIABLE) == true)
check("it does not groan", npc._descriptor.voice == "")
check("its emitter was silenced", npc._emitter.playing == false)
check("it stands in the middle of the tile",
    npc:getX() == diane.x + 0.5 and npc:getY() == diane.y + 0.5)

print("\n[43] it does not spawn twice")
SPAWNED_ZOMBIES = {}
Events.LoadGridsquare.fire(getCell():getGridSquare(diane.x, diane.y, 0))
Events.LoadGridsquare.fire(getCell():getGridSquare(diane.x, diane.y, 0))
check("re-loading the cell creates nobody new", #SPAWNED_ZOMBIES == 0, #SPAWNED_ZOMBIES)

local C = KS.Commands
check("a direct duplicate request is refused",
    C.send(C.SPAWN_NPC, { npcId = "diane", x = diane.x, y = diane.y, z = 0 }) == false)

print("\n[44] the spawn command validates its payload")
KS.NPCServer.clearSpawnRecords()
check("unknown npc refused", C.send(C.SPAWN_NPC, { npcId = "ghost", x = 1, y = 1, z = 0 }) == false)
check("missing coordinates refused", C.send(C.SPAWN_NPC, { npcId = "diane" }) == false)
check("not a table refused", C.send(C.SPAWN_NPC, "diane") == false)

SPAWNED_ZOMBIES = {}
ADD_ZOMBIES_FAILS = true
check("a refusal from the engine is survived",
    C.send(C.SPAWN_NPC, { npcId = "diane", x = diane.x, y = diane.y, z = 0 }) == false)
check("and nothing is recorded as spawned", KS.NPCServer.isSpawned("diane") == false)
ADD_ZOMBIES_FAILS = false

print("\n[45] unloading lets them come back")
check("spawns once the cell is loaded again",
    C.send(C.SPAWN_NPC, { npcId = "diane", x = diane.x, y = diane.y, z = 0 }) == true)
check("recorded", KS.NPCServer.isSpawned("diane") == true)

LOADED_SQUARES = {}
Events.EveryOneMinute.fire()
check("walking away forgets them", KS.NPCServer.isSpawned("diane") == false)
LOADED_SQUARES = nil

print("\n[46] talking to them")
DIALOGUE_SHOWN = {}
loadSquare(diane.x, diane.y, 0, true, true)
KS.NPCServer.clearSpawnRecords()
SPAWNED_ZOMBIES = {}
Events.LoadGridsquare.fire(getCell():getGridSquare(diane.x, diane.y, 0))

local square = getCell():getGridSquare(diane.x, diane.y, 0)
square:addMovingObject(SPAWNED_ZOMBIES[1])

local menu = TestMenu.new()
Events.OnFillWorldObjectContextMenu.fire(0, menu, { square:makeObject("floors_x") }, false)
local option = menu:find("Talk to Diane")
check("the talk option names them", option ~= nil)

option.onSelect(option.target, option.args[1])
check("a window opened", #DIALOGUE_SHOWN == 1, #DIALOGUE_SHOWN)
check("it says who is speaking", DIALOGUE_SHOWN[1]:find("Diane") ~= nil)
check("it shows the first line",
    DIALOGUE_SHOWN[1]:find("first person through that door") ~= nil)

-- An ordinary zombie standing on a square offers nothing.
local plainSquare = loadSquare(500, 500, 0, true, true)
plainSquare:addMovingObject(TestZombie.new(500, 500, 0, "Naked", false))
menu = TestMenu.new()
Events.OnFillWorldObjectContextMenu.fire(0, menu, { plainSquare:makeObject("floors_x") }, false)
check("a real zombie offers no conversation", menu:find("Talk to Diane") == nil)

print("\n[47] deliver_item can name a person instead of a point")
local T = KS.Triggers.types
local spec = { type = "deliver_item", note = "dummy_letter", npc = "diane" }
check("it validates", T.deliver_item.validate(spec) == true)
check("and takes their coordinates",
    spec.x == diane.x and spec.y == diane.y and spec.z == diane.z)

local badSpec = { type = "deliver_item", note = "dummy_letter", npc = "ghost" }
local ok, reason = T.deliver_item.validate(badSpec)
check("naming an npc who does not exist is rejected", ok == false, reason)

print("")
if FAILURES == 0 then
    print("ALL CHECKS PASSED")
else
    print(FAILURES .. " CHECK(S) FAILED")
end
