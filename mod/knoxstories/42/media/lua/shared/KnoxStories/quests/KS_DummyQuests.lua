--[[
    KS_DummyQuests.lua

    Phase 1 test content. Two quests, one trigger type, no story text -- these
    exist only to prove the state store, the registry and the polled evaluator
    work, and they get deleted the moment Phase 5's loader can emit the real
    thing from Markdown.

    Note this file contains no logic at all. It appends data to a table. That is
    the whole point of build plan 3.2: adding a quest is never writing Lua.

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
-- answers "is the evaluator running at all".
--------------------------------------------------------------------------------

table.insert(KnoxStories.QuestDefs, {
    id = "dummy_a",
    name = "Dummy A (arrival, then two landmarks)",
    firstStep = "reach_rosewood",
    steps = {
        { id = "reach_rosewood", trigger = ROSEWOOD_WIDE, unlocks = "reach_fire_station" },
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
        { id = "reach_west", trigger = SPOT_3, unlocks = "reach_east" },
        { id = "reach_east", trigger = SPOT_4, unlocks = nil },
    },
})
