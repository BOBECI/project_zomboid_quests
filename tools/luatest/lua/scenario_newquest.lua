--------------------------------------------------------------------------------
-- Scenario 3: a quest added to the mod after players already have a save.
-- Seeding must be additive -- new quest appears, existing progress untouched.
--------------------------------------------------------------------------------
local function check(label, cond, detail)
    if cond then
        print("    PASS  " .. label)
    else
        FAILURES = FAILURES + 1
        print("    FAIL  " .. label .. (detail and ("  -> " .. tostring(detail)) or ""))
    end
end

local function where(id)
    local p = KnoxStories.State.get().quests[id]
    if not p then return "<no record>" end
    return p.status .. "/" .. tostring(p.step)
end

table.insert(KnoxStories.QuestDefs, {
    id = "dummy_added_later", firstStep = "s1",
    steps = { { id = "s1", trigger = { type = "enter_area", x1 = 1, y1 = 1, x2 = 2, y2 = 2 } } },
})

print("\n[12] new quest shipped to an existing save")
Events.OnInitGlobalModData.fire(false)
Events.OnGameStart.fire()
check("dummy_added_later seeded on load", where("dummy_added_later") == "active/s1", where("dummy_added_later"))
check("dummy_a progress preserved", where("dummy_a") == "complete/nil", where("dummy_a"))
check("dummy_b progress preserved", where("dummy_b") == "complete/nil", where("dummy_b"))
