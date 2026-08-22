--[[
    KS_DummyQuests.lua

    Phase 1 test content. Two quests, one trigger type, no story text -- these
    exist only to prove the state store, the registry and the polled evaluator
    work, and they get deleted the moment Phase 5's loader can emit the real
    thing from Markdown.

    Note this file contains no logic at all. It appends data to a table. That is
    the whole point of build plan 3.2: adding a quest is never writing Lua.

    Phase 2 adds 'gives' to two steps, so walking the dummy quests hands you the
    dummy notes and the copy recipe has something to work on.

    ---------------------------------------------------------------------------
    COORDINATES -- read this before testing

    The four small areas below are best-effort Rosewood landmarks and are very
    likely a little off. Retuning them is the only edit this file should need:

      1. KS.DEBUG is true (see KS_Core.lua), so the evaluator prints your
         position to console.txt every few seconds as you walk.
      2. Stand where you want a step to fire, read the coordinates.
      3. Paste them in below.

    ROSEWOOD_WIDE is deliberately enormous. It should fire the instant you spawn
    anywhere in Rosewood, which is the fastest possible confirmation that the
    loop is actually running.
    ---------------------------------------------------------------------------
]]

KnoxStories = KnoxStories or {}
KnoxStories.QuestDefs = KnoxStories.QuestDefs or {}

local ROSEWOOD_WIDE = { type = "enter_area", x1 = 7800, y1 = 11100, x2 = 8600, y2 = 12000, z = 0 }

-- Near the Rosewood fire station.
local SPOT_1 = { type = "enter_area", x1 = 8030, y1 = 11780, x2 = 8050, y2 = 11800, z = 0 }

-- Near the Rosewood police station.
local SPOT_2 = { type = "enter_area", x1 = 8080, y1 = 11700, x2 = 8100, y2 = 11720, z = 0 }

-- West side of town.
local SPOT_3 = { type = "enter_area", x1 = 7950, y1 = 11850, x2 = 7970, y2 = 11870, z = 0 }

-- East side of town.
local SPOT_4 = { type = "enter_area", x1 = 8150, y1 = 11640, x2 = 8170, y2 = 11660, z = 0 }

--------------------------------------------------------------------------------
-- Dummy A -- three steps. Step one fires on arrival in Rosewood, so this quest
-- answers "is the evaluator running at all", and hands over the multi-page note
-- so there is something to copy without walking anywhere.
--------------------------------------------------------------------------------

table.insert(KnoxStories.QuestDefs, {
    id = "dummy_a",
    name = "Dummy A (arrival, then two landmarks)",
    firstStep = "reach_rosewood",
    steps = {
        {
            id = "reach_rosewood",
            trigger = ROSEWOOD_WIDE,
            gives = "dummy_letter",
            unlocks = "reach_fire_station",
        },
        { id = "reach_fire_station", trigger = SPOT_1, unlocks = "reach_police_station" },
        { id = "reach_police_station", trigger = SPOT_2, unlocks = nil },
    },
})

--------------------------------------------------------------------------------
-- Dummy B -- two steps, both narrow. This one should sit untouched while Dummy A
-- advances, which is what proves the two quests are tracked independently and
-- that the evaluator is not firing on everything it sees.
--------------------------------------------------------------------------------

table.insert(KnoxStories.QuestDefs, {
    id = "dummy_b",
    name = "Dummy B (two landmarks, no arrival step)",
    firstStep = "reach_west",
    steps = {
        {
            id = "reach_west",
            trigger = SPOT_3,
            gives = "dummy_envelope",
            unlocks = "reach_east",
        },
        { id = "reach_east", trigger = SPOT_4, unlocks = nil },
    },
})

--------------------------------------------------------------------------------
-- Dummy C -- Phase 3. One step per trigger type, in order, so walking this quest
-- exercises the whole vocabulary the Rosewood pilot needs.
--
--   1. enter_area    arrive in Rosewood, and be handed the letter
--   2. read_note     actually open the letter
--   3. acquire_item  get hold of a screwdriver
--   4. deliver_item  carry the letter to the fire station, where it is taken
--
-- Step 4 deliberately delivers the note the quest gave you in step 1, so the
-- consume path is visible: the scrap leaves your inventory.
--------------------------------------------------------------------------------

table.insert(KnoxStories.QuestDefs, {
    id = "dummy_c",
    name = "Dummy C (one step per trigger type)",
    firstStep = "arrive",
    steps = {
        {
            id = "arrive",
            trigger = ROSEWOOD_WIDE,
            gives = "dummy_scrap",
            unlocks = "read_the_letter",
        },
        {
            id = "read_the_letter",
            trigger = { type = "read_note", note = "dummy_scrap" },
            unlocks = "find_a_screwdriver",
        },
        {
            id = "find_a_screwdriver",
            trigger = { type = "acquire_item", item = "Base.Screwdriver" },
            unlocks = "hand_it_over",
        },
        {
            id = "hand_it_over",
            trigger = {
                type = "deliver_item",
                note = "dummy_scrap",
                x = 8040, y = 11790, z = 0, range = 3,
            },
            unlocks = nil,
        },
    },
})

--------------------------------------------------------------------------------
-- Dummy D -- the conditional examine, in one step so the condition is the only
-- thing gating it.
--
-- Deliberately NOT "step 1 get the note, step 2 examine the thing". That would
-- prove nothing: the option would be hidden simply because the step was not
-- active yet. With a single step, active from the start, the only reason Examine
-- does not appear is that the player is not carrying the note -- which is the
-- behaviour worth testing.
--
-- Base.PillsBeta rather than an inhaler: B42 has an asthmatic trait but no
-- inhaler item. The trigger does not care what the object is.
--------------------------------------------------------------------------------

table.insert(KnoxStories.QuestDefs, {
    id = "dummy_d",
    name = "Dummy D (examine, gated on carrying a note)",
    firstStep = "examine_the_pills",
    steps = {
        {
            id = "examine_the_pills",
            trigger = {
                type = "examine",
                item = "Base.PillsBeta",
                requires = "dummy_envelope",
            },
            unlocks = nil,
        },
    },
})

--------------------------------------------------------------------------------
-- Dummy E -- delivering to a person rather than to a patch of ground.
--
-- Phase 3's deliver_item worked against coordinates because there was nobody to
-- deliver to. Naming an npc copies their coordinates in at load, so moving Diane
-- moves the delivery with her.
--------------------------------------------------------------------------------

table.insert(KnoxStories.QuestDefs, {
    id = "dummy_e",
    name = "Dummy E (deliver to Diane)",
    firstStep = "take_it_to_diane",
    steps = {
        {
            id = "take_it_to_diane",
            trigger = { type = "deliver_item", note = "dummy_letter", npc = "diane", range = 3 },
            unlocks = nil,
        },
    },
})
