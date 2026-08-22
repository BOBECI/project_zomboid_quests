--------------------------------------------------------------------------------
-- Scenario 2: the save/reload. Every mod global was wiped and the files were
-- re-executed; only the ModData store survived, exactly as across a
-- quit-to-menu and reload.
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

print("\n[10] state survives the reload")
Events.OnInitGlobalModData.fire(false)
Events.OnGameStart.fire()
check("dummy_a restored complete", where("dummy_a") == "complete/nil", where("dummy_a"))
check("dummy_b restored mid-quest", where("dummy_b") == "active/reach_east", where("dummy_b"))

print("\n[11] the loop still runs after a reload, on restored progress")
PLAYER.x, PLAYER.y, PLAYER.z = 7960, 11860, 0   -- reach_west's spot, already passed
for i = 1, 35 do Events.OnPlayerUpdate.fire(PLAYER) end
check("old step does not re-fire", where("dummy_b") == "active/reach_east", where("dummy_b"))

PLAYER.x, PLAYER.y, PLAYER.z = 8160, 11650, 0   -- reach_east's spot
for i = 1, 35 do Events.OnPlayerUpdate.fire(PLAYER) end
check("restored quest completes", where("dummy_b") == "complete/nil", where("dummy_b"))
