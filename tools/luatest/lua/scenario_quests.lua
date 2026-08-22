--------------------------------------------------------------------------------
-- Scenario 1: fresh world. Walk the dummy quests, check notes are handed over
-- on the way, then probe the command boundary.
--------------------------------------------------------------------------------

FAILURES = 0

function CHECK(label, cond, detail)
    if cond then
        print("    PASS  " .. label)
    else
        FAILURES = FAILURES + 1
        print("    FAIL  " .. label .. (detail and ("  -> " .. tostring(detail)) or ""))
    end
end

local check = CHECK

local function walkTo(x, y, z)
    PLAYER.x, PLAYER.y, PLAYER.z = x, y, z or 0
    for i = 1, 35 do Events.OnPlayerUpdate.fire(PLAYER) end
end

local function where(id)
    local p = KnoxStories.State.get().quests[id]
    if not p then return "<no record>" end
    return p.status .. "/" .. tostring(p.step)
end

local function countNotes(noteId)
    local n = 0
    local items = PLAYER:getInventory():getItems()
    for i = 0, items:size() - 1 do
        if KnoxStories.Notes.idOf(items:get(i)) == noteId then n = n + 1 end
    end
    return n
end

-- Deliberately broken definitions, appended before anything reads the registry,
-- to prove a bad quest is skipped rather than fatal.
table.insert(KnoxStories.QuestDefs, { name = "no id at all", steps = {} })
table.insert(KnoxStories.QuestDefs, {
    id = "bad_trigger", firstStep = "s1",
    steps = { { id = "s1", trigger = { type = "read_minds" } } },
})
table.insert(KnoxStories.QuestDefs, {
    id = "bad_link", firstStep = "s1",
    steps = { { id = "s1", trigger = { type = "enter_area", x1=1,y1=1,x2=2,y2=2 }, unlocks = "nowhere" } },
})
table.insert(KnoxStories.QuestDefs, {
    id = "bad_gives", firstStep = "s1",
    steps = { { id = "s1", trigger = { type = "enter_area", x1=1,y1=1,x2=2,y2=2 }, gives = "no_such_note" } },
})

print("\n[1] boot")
Events.OnInitGlobalModData.fire(true)
Events.OnGameStart.fire()
local valid, invalid = KnoxStories.Quests.ensureValidated()
check("4 valid quests registered", valid == 4, valid)
check("4 broken quests skipped", invalid == 4, invalid)
check("a step giving an unknown note is rejected",
    KnoxStories.Quests.get("bad_gives") == nil)
check("dummy_a seeded active at first step", where("dummy_a") == "active/reach_rosewood", where("dummy_a"))
check("dummy_b seeded active at first step", where("dummy_b") == "active/reach_west", where("dummy_b"))
check("broken quests got no world record",
    KnoxStories.State.get().quests.bad_trigger == nil)

print("\n[2] inside the Rosewood box but on the second floor -- must not fire")
walkTo(8300, 11500, 1)
check("z guard holds", where("dummy_a") == "active/reach_rosewood", where("dummy_a"))
check("no note handed over", countNotes("dummy_letter") == 0)

print("\n[3] ground level, inside Rosewood, away from every landmark")
walkTo(8300, 11500, 0)
check("dummy_a advanced one step", where("dummy_a") == "active/reach_fire_station", where("dummy_a"))
check("dummy_b did not move", where("dummy_b") == "active/reach_west", where("dummy_b"))
check("the step handed over its note", countNotes("dummy_letter") == 1, countNotes("dummy_letter"))

print("\n[4] walk to the fire station spot")
walkTo(8040, 11790, 0)
check("dummy_a advanced again", where("dummy_a") == "active/reach_police_station", where("dummy_a"))
check("dummy_b still untouched", where("dummy_b") == "active/reach_west", where("dummy_b"))
check("a step with no 'gives' hands over nothing",
    countNotes("dummy_letter") == 1, countNotes("dummy_letter"))

print("\n[5] walk to the police station spot -- last step")
walkTo(8090, 11710, 0)
check("dummy_a complete", where("dummy_a") == "complete/nil", where("dummy_a"))

print("\n[6] standing still on a completed quest must not loop")
walkTo(8090, 11710, 0)
check("no further state writes", where("dummy_a") == "complete/nil", where("dummy_a"))
check("no duplicate note", countNotes("dummy_letter") == 1, countNotes("dummy_letter"))

print("\n[7] dummy_b, both landmarks")
walkTo(7960, 11860, 0)
check("dummy_b advanced", where("dummy_b") == "active/reach_east", where("dummy_b"))
check("dummy_b handed over its note", countNotes("dummy_envelope") == 1, countNotes("dummy_envelope"))
walkTo(8160, 11650, 0)
check("dummy_b complete", where("dummy_b") == "complete/nil", where("dummy_b"))

print("\n[8] command boundary -- every one of these must be refused")
local C = KnoxStories.Commands
check("nil payload refused",         C.send(C.ADVANCE_STEP, nil) == false)
check("payload not a table refused", C.send(C.ADVANCE_STEP, "dummy_a") == false)
check("missing stepId refused",      C.send(C.ADVANCE_STEP, { questId = "dummy_a" }) == false)
check("unknown quest refused",       C.send(C.ADVANCE_STEP, { questId = "ghost", stepId = "s" }) == false)
check("unknown step refused",        C.send(C.ADVANCE_STEP, { questId = "dummy_a", stepId = "ghost" }) == false)
check("unknown command refused",     C.send("NoSuchCommand", {}) == false)
check("completed quest refused",     C.send(C.ADVANCE_STEP, { questId = "dummy_a", stepId = "reach_rosewood" }) == false)

print("\n[9] stale claim against a live quest, and leave it mid-progress")
KnoxStories.State.get().quests.dummy_b.status = "active"
KnoxStories.State.get().quests.dummy_b.step = "reach_west"
check("stale step refused", C.send(C.ADVANCE_STEP, { questId = "dummy_b", stepId = "reach_east" }) == false)
check("state unchanged by stale claim", where("dummy_b") == "active/reach_west", where("dummy_b"))
check("matching step accepted", C.send(C.ADVANCE_STEP, { questId = "dummy_b", stepId = "reach_west" }) == true)
check("dummy_b now mid-quest", where("dummy_b") == "active/reach_east", where("dummy_b"))

print("\n[10] every vanilla item the mod names must actually exist")
-- This is the check that would have caught Base.SheetPaper, which does not exist
-- in B42 -- the sheet of paper is SheetPaper2. A wrong name here is invisible
-- until the game refuses to spawn the item, so it is worth asserting directly.
-- KNOWN_ITEMS in stubs.lua is kept in sync with the game's own item scripts.
local referenced = {}
local noteDefs = KnoxStories.Notes.all()
for i = 1, #noteDefs do
    if not noteDefs[i].invalid then referenced[noteDefs[i].item] = "note '" .. noteDefs[i].id .. "'" end
end
for i = 1, #KnoxStories.Notes.PEN_TYPES do
    referenced[KnoxStories.Notes.PEN_TYPES[i]] = "PEN_TYPES"
end
for i = 1, #KnoxStories.Notes.PAPER_TYPES do
    referenced[KnoxStories.Notes.PAPER_TYPES[i]] = "PAPER_TYPES"
end

-- Trigger specs name items too: acquire_item and deliver_item can carry an
-- item = "Base.X".
local questDefs = KnoxStories.Quests.all()
for i = 1, #questDefs do
    local qd = questDefs[i]
    if not qd.invalid then
        for j = 1, #qd.steps do
            local spec = qd.steps[j].trigger
            if spec.item then
                referenced[spec.item] = "quest '" .. qd.id .. "', step '" .. qd.steps[j].id .. "'"
            end
        end
    end
end

for fullType, usedBy in pairs(referenced) do
    check(fullType .. " exists (" .. usedBy .. ")", instanceItem(fullType) ~= nil)
end

-- Park the player somewhere no trigger covers, so the reload test starts clean.
PLAYER.x, PLAYER.y, PLAYER.z = 100, 100, 0
