--[[
    KS_DummyNotes.lua

    Phase 2 test content. Like the dummy quests, this file contains no logic --
    it appends data records. Phase 5's Markdown loader emits exactly this shape,
    and these get deleted once it can.

    <LINE> is a line break. Writers will never type it; the loader inserts it
    when it turns their paragraphs into pages.

    The two notes differ deliberately: one is a multi-page notepad, one is a
    single-page card, so the page handling and two different vanilla base items
    both get exercised.

    ---------------------------------------------------------------------------
    CHOOSING A BASE ITEM

    It must have CanBeWrite = true in the game's own item scripts, and its
    PageToWrite is the most pages it can hold. Verified in B42:

        Base.Notepad        5 pages
        Base.Journal        20 pages
        Base.Notebook       10 pages
        Base.Diary1/2       40 pages
        Base.SheetPaper2    1 page      (this is the sheet of paper; there is
                                         no Base.SheetPaper)
        Base.IndexCard      1 page
        Base.GraphPaper     1 page
        Base.Card_*         1 page      (greeting cards)

    Base.GenericMail is NOT writable and has an OnCreate that generates its own
    text, so it cannot carry quest pages -- despite the reference mod appearing
    to use it.

    Nothing yet stops a note declaring more pages than its item can hold; the
    extra pages would just be lost. Phase 5's loader is where that check belongs.
    ---------------------------------------------------------------------------
]]

KnoxStories = KnoxStories or {}
KnoxStories.NoteDefs = KnoxStories.NoteDefs or {}

table.insert(KnoxStories.NoteDefs, {
    id = "dummy_letter",
    item = "Base.Notepad",
    title = "Water-stained letter",
    pages = {
        "If you are reading this I am already gone west.<LINE>"
            .. "<LINE>The pumps at the station still run on the tank, not the mains. "
            .. "Whoever holds the station holds the water.",
        "Second page. This exists to prove multi-page notes survive being written, "
            .. "locked, copied and saved.<LINE><LINE>-- R.",
    },
})

table.insert(KnoxStories.NoteDefs, {
    id = "dummy_envelope",
    item = "Base.IndexCard",
    title = "Scrawled index card",
    pages = {
        "A single page, on a different base item, to check the copy recipe does "
            .. "not assume everything is a notepad.",
    },
})

-- Dummy C's note. Its own, so that quest can be walked without touching the
-- notes the other two hand out.
table.insert(KnoxStories.NoteDefs, {
    id = "dummy_scrap",
    item = "Base.GraphPaper",
    title = "Torn scrap of graph paper",
    pages = {
        "Used by the Phase 3 trigger quest: this scrap gets read, then carried "
            .. "to the fire station and handed over.",
    },
})
