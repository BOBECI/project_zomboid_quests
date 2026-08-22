--[[
    KS_DummyNotes.lua

    Phase 2 test content. Like the dummy quests, this file contains no logic --
    it appends data records. Phase 5's Markdown loader emits exactly this shape,
    and these get deleted once it can.

    <LINE> is a line break. Writers will never type it; the loader inserts it
    when it turns their paragraphs into pages.

    The two notes differ deliberately: one is a multi-page notepad, one is a
    single-page piece of mail, so the page handling and two different vanilla
    base items both get exercised.
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
    item = "Base.GenericMail",
    title = "Unopened envelope",
    pages = {
        "A single page, on a different base item, to check the copy recipe does "
            .. "not assume everything is a notepad.",
    },
})
