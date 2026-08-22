--[[
    KS_NoteCopyAction.lua

    The timed action behind copying a note. It is deliberately thin: all the
    logic is KnoxStories.Notes.performCopy, which is a pure function over
    (player, item) and is covered by tools/luatest. This file only supplies the
    progress bar, the animation, and the "still valid?" check that cancels the
    action if the player drops the pen halfway through.
]]

require "TimedActions/ISBaseTimedAction"

KS_CopyNoteAction = ISBaseTimedAction:derive("KS_CopyNoteAction")

-- Roughly three seconds a page at normal speed. Copying is meant to be a real
-- cost -- the decision to spend the time is the mechanic (overview section 3).
local TICKS_PER_PAGE = 180

-- isValid runs every tick for the whole length of the action. It used to call
-- canCopy, which walks the entire inventory including every bag -- so a
-- six-second copy meant hundreds of full inventory scans, and while isWritable
-- was calling canBeWrite() on non-literature items that also meant hundreds of
-- engine stack traces.
--
-- The materials are found once, when the action is queued. Checking they are
-- still in a container is O(1) and answers the only question that matters: did
-- the player drop the pen or the paper part-way through.
function KS_CopyNoteAction:isValid()
    if not self.note or not KnoxStories.Notes.idOf(self.note) then
        return false
    end

    if not self.pen or not self.paper then
        return false
    end

    return self.pen:getContainer() ~= nil and self.paper:getContainer() ~= nil
end

function KS_CopyNoteAction:start()
    self:setActionAnim("Loot")
end

function KS_CopyNoteAction:update()
    self.character:faceLocation(self.character:getX(), self.character:getY())
end

function KS_CopyNoteAction:stop()
    ISBaseTimedAction.stop(self)
end

function KS_CopyNoteAction:perform()
    local ok, reason = KnoxStories.Notes.performCopy(self.character, self.note)

    if not ok then
        KnoxStories.warn("copy failed: " .. tostring(reason))
    end

    ISBaseTimedAction.perform(self)
end

function KS_CopyNoteAction:new(character, note)
    local o = ISBaseTimedAction.new(self, character)

    o.note = note
    o.stopOnWalk = true
    o.stopOnRun = true

    -- Found once here rather than on every tick of isValid. performCopy looks
    -- them up again when it actually runs, so if one of these is swapped out
    -- mid-action the copy still uses whatever is genuinely there.
    o.pen, o.paper = KnoxStories.Notes.findCopyMaterials(character, note)

    local def = KnoxStories.Notes.get(KnoxStories.Notes.idOf(note))
    local pages = (def and #def.pages) or 1
    o.maxTime = TICKS_PER_PAGE * pages

    return o
end
