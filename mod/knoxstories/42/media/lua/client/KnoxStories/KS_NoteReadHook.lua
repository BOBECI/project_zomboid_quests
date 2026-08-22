--[[
    KS_NoteReadHook.lua

    Notices when the player opens one of our notes, so the read_note trigger has
    something to test.

    WHY THIS IS A WRAPPER AND NOT AN EVENT

    There is no "player read something" event. The obvious alternative was to
    poll item:getAlreadyReadPages() against getNumberOfPages(), which is how the
    game greys out books you have finished -- but that counter is maintained by
    ISReadABook, and a writable item never goes through ISReadABook. Reading a
    notepad goes through ISInventoryPaneContextMenu.onWriteSomething, which opens
    ISUIWriteJournal directly. So the counter stays at zero no matter how
    carefully the player reads, and polling it would never fire.

    That leaves wrapping the function the game itself calls. It is a small,
    well-defined seam: we record, then call straight through, and we take no
    decisions of our own. Signature confirmed in the B42 install:

        ISInventoryPaneContextMenu.onWriteSomething(notebook, editable, player)

    where 'player' is the player number, not the object.

    The risk of wrapping a vanilla function is another mod wrapping the same one.
    Because we always call through and never swallow the call, the worst case if
    two mods chain here is that both run, which is correct.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

-- Guard against this file being loaded twice, which would chain the wrapper onto
-- itself. Harmless, but it would show up as a doubled log line.
if KS.noteReadHookInstalled then
    return
end
KS.noteReadHookInstalled = true

local originalOnWriteSomething = ISInventoryPaneContextMenu.onWriteSomething

ISInventoryPaneContextMenu.onWriteSomething = function(notebook, editable, player)
    -- Marking happens before the window opens. If the player shuts it instantly
    -- it still counts: see the note on read_note in KS_Triggers.lua about why
    -- "opened" is the honest definition here.
    KS.Notes.markRead(notebook)

    return originalOnWriteSomething(notebook, editable, player)
end
