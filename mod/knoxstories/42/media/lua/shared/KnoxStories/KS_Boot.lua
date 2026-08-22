--[[
    KS_Boot.lua

    Boot banner. Prints what loaded and, more usefully during development, what
    the world already remembers -- so a save/reload test is just a matter of
    reading a few lines in console.txt and checking the steps match where you
    left off.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

local function onGameStart()
    local validQuests, invalidQuests = KS.Quests.ensureValidated()
    local validNotes, invalidNotes = KS.Notes.ensureValidated()
    local validNPCs, invalidNPCs = KS.NPCs.ensureValidated()

    KS.print("v" .. KS.VERSION .. " loaded - "
        .. validQuests .. " quest(s)"
        .. (invalidQuests > 0 and (" (" .. invalidQuests .. " skipped)") or "")
        .. ", " .. validNotes .. " note(s)"
        .. (invalidNotes > 0 and (" (" .. invalidNotes .. " skipped)") or "")
        .. ", " .. validNPCs .. " npc(s)"
        .. (invalidNPCs > 0 and (" (" .. invalidNPCs .. " skipped)") or ""))

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
