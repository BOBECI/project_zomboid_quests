--[[
    KS_Boot.lua

    Boot banner. Prints what loaded and, more usefully for Phase 1, what the
    world already remembers -- so a save/reload test is just a matter of reading
    two lines in console.txt and checking the steps match where you left off.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

local function onGameStart()
    local valid, invalid = KS.Quests.ensureValidated()

    KS.print("v" .. KS.VERSION .. " loaded - " .. valid .. " quest(s) registered"
        .. (invalid > 0 and (", " .. invalid .. " skipped as invalid") or ""))

    -- Absent on a multiplayer client until Phase 6 syncs a copy down.
    if not KS.State then
        return
    end

    local world = KS.State.get()
    local defs = KS.Quests.all()

    for i = 1, #defs do
        local def = defs[i]
        local progress = world.quests[def.id]

        if progress then
            KS.print("  " .. def.id .. ": " .. progress.status
                .. " (step: " .. tostring(progress.step) .. ")")
        end
    end
end

Events.OnGameStart.Add(onGameStart)
