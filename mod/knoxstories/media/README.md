Why this folder exists, given everything else lives under 42/

The engine appears to load animsets from <mod>/media/animsets, not from the
versioned <mod>/42/media/animsets. In play the animation variable read back as
true, all 113 node files were present under 42/, and the NPC still animated as a
zombie -- which is what it looks like when the nodes are never loaded.

The reference mod ships its 135 animset files in BOTH locations. ARCHITECTURE.md
section 1 describes the non-versioned copy as "a leftover duplicate"; that was an
inference, and duplicating 135 files by accident and then maintaining them is
less likely than doing it because one of the two is the one that works.

So both are shipped here too, and tools/luatest asserts they stay identical. If
it is ever confirmed that only one location is read, delete the other.
