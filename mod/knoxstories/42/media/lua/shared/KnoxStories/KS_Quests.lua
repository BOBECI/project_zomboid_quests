--[[
    KS_Quests.lua

    The quest registry. Quest definitions are plain data appended to
    KnoxStories.QuestDefs by files under shared/KnoxStories/quests/. Registration
    is a table.insert, not a function call, so it cannot break on load order.

    Definition shape (Phase 1 -- Phase 5's Markdown loader emits exactly this):

        {
            id        = "dummy_a",          unique, lowercase, used as a ModData key
            name      = "Dummy A",          developer-facing only; player-facing
                                            text arrives in Phase 5 as generated
                                            translation keys
            firstStep = "step_1",
            steps     = {
                {
                    id      = "step_1",
                    trigger = { type = "enter_area", ... },
                    gives   = "note_id",    optional; handed over when this step
                                            completes
                    unlocks = "step_2",     nil on the last step; quest completes
                },
                ...
            },
        }
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

KS.QuestDefs = KS.QuestDefs or {}
KS.Quests = KS.Quests or {}

-- questId -> { def = <definition>, steps = { stepId -> <step> } }
local index = nil

-- Validation runs exactly once, on whichever call needs the registry first.
-- OnInitGlobalModData can fire before OnGameStart, so this cannot hang off a
-- single boot event.
local validated = false
local validCount, invalidCount = 0, 0

local function buildIndex()
    index = {}
    for i = 1, #KS.QuestDefs do
        local def = KS.QuestDefs[i]
        -- Invalid definitions are skipped: they may have no id at all, and
        -- index[nil] is a hard error.
        if not def.invalid then
            local entry = { def = def, steps = {} }
            for j = 1, #def.steps do
                local step = def.steps[j]
                entry.steps[step.id] = step
            end
            index[def.id] = entry
        end
    end
end

--------------------------------------------------------------------------------
-- Validation
--
-- A malformed quest is marked invalid and skipped rather than crashing the mod,
-- and the reason is printed in language a writer could act on. Phase 5 reuses
-- these messages when the Markdown loader reports errors.
--------------------------------------------------------------------------------

local function invalidate(def, reason)
    def.invalid = true
    KS.warn("quest '" .. tostring(def.id or "<no id>") .. "' was skipped: " .. reason)
end

local function validateQuest(def, seenIds)
    if type(def.id) ~= "string" or def.id == "" then
        invalidate(def, "it has no id")
        return
    end

    if seenIds[def.id] then
        invalidate(def, "another quest already uses the id '" .. def.id .. "'")
        return
    end
    seenIds[def.id] = true

    if type(def.steps) ~= "table" or #def.steps == 0 then
        invalidate(def, "it has no steps")
        return
    end

    local stepIds = {}
    for i = 1, #def.steps do
        local step = def.steps[i]

        if type(step.id) ~= "string" or step.id == "" then
            invalidate(def, "step number " .. i .. " has no id")
            return
        end
        if stepIds[step.id] then
            invalidate(def, "two steps share the id '" .. step.id .. "'")
            return
        end
        stepIds[step.id] = true

        if type(step.trigger) ~= "table" or type(step.trigger.type) ~= "string" then
            invalidate(def, "step '" .. step.id .. "' has no trigger type")
            return
        end

        local triggerType = KS.Triggers.types[step.trigger.type]
        if not triggerType then
            invalidate(def, "step '" .. step.id .. "' uses an unknown trigger type '"
                .. step.trigger.type .. "'")
            return
        end

        local ok, reason = triggerType.validate(step.trigger)
        if not ok then
            invalidate(def, "step '" .. step.id .. "' has a bad trigger -- " .. tostring(reason))
            return
        end

        -- Phase 2: a step may hand over a note when it completes.
        if step.gives ~= nil then
            if type(step.gives) ~= "string" or step.gives == "" then
                invalidate(def, "step '" .. step.id .. "' has a 'gives' that is not a note id")
                return
            end
            if not KS.Notes.get(step.gives) then
                invalidate(def, "step '" .. step.id .. "' gives the note '" .. step.gives
                    .. "', but no note with that id exists")
                return
            end
        end
    end

    -- Links are checked after every step id is known, so forward references work.
    for i = 1, #def.steps do
        local step = def.steps[i]
        if step.unlocks ~= nil and not stepIds[step.unlocks] then
            invalidate(def, "step '" .. step.id .. "' unlocks '" .. tostring(step.unlocks)
                .. "', which is not a step in this quest")
            return
        end
    end

    if type(def.firstStep) ~= "string" or not stepIds[def.firstStep] then
        invalidate(def, "its first step '" .. tostring(def.firstStep)
            .. "' is not a step in this quest")
        return
    end

    def.invalid = false
end

function KS.Quests.ensureValidated()
    if validated then
        return validCount, invalidCount
    end
    validated = true

    local seenIds = {}
    validCount = 0

    for i = 1, #KS.QuestDefs do
        local def = KS.QuestDefs[i]
        validateQuest(def, seenIds)
        if not def.invalid then
            validCount = validCount + 1
        end
    end
    invalidCount = #KS.QuestDefs - validCount

    -- Definitions are normalised during validation, so index afterwards.
    buildIndex()

    return validCount, invalidCount
end

--------------------------------------------------------------------------------
-- Accessors. Each one makes sure the registry is validated and indexed first.
--------------------------------------------------------------------------------

function KS.Quests.all()
    KS.Quests.ensureValidated()
    return KS.QuestDefs
end

function KS.Quests.get(questId)
    KS.Quests.ensureValidated()
    local entry = index[questId]
    return entry and entry.def or nil
end

function KS.Quests.getStep(questId, stepId)
    KS.Quests.ensureValidated()
    local entry = index[questId]
    if not entry then
        return nil
    end
    return entry.steps[stepId]
end
