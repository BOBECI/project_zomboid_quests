--[[
    KS_DummyNPCs.lua

    Phase 4 test content. Data only, like the quests and notes.

    COORDINATES

    These are a guess at a Rosewood house and almost certainly need moving. The
    tooling from the first half of Phase 4 is how you fix them: stand where you
    want her, read the on-screen coordinate readout, paste the numbers in.

    Pick a tile she can actually stand on -- a clear bit of floor, not a doorway
    and not under a table. The spawner searches a small area around the tile and
    downward through floors, but it deliberately will NOT bulldoze the square to
    make room. See KS_NPCSpawn for why.
]]

KnoxStories = KnoxStories or {}
KnoxStories.NPCDefs = KnoxStories.NPCDefs or {}

table.insert(KnoxStories.NPCDefs, {
    id = "diane",
    name = "Diane",
    x = 8003, y = 11743, z = 0,
    -- A vanilla outfit name from media/clothing/clothing.xml. "Naked" is a real
    -- one and is what the reference mod uses in its example call; it is not what
    -- you want a woman standing in her own kitchen to be wearing.
    outfit = "DressLong",
    female = true,
    dialogue = {
        "You're the first person through that door in a while. "
            .. "I'd offer you something but there's not much left.",
        "Casey's things are still upstairs. I haven't moved them. "
            .. "I keep thinking she'll want them where she left them.",
        "If you're going out that way anyway -- have a look. That's all I'm asking.",
    },
})
