# Phase 4, part two — Diane: spawning, standing still, and talking

Read this with the game open. Each test says what to do, what you should see, and
what it means if you see something else.

```
C:\Users\malib\Zomboid\console.txt
```

---

## What you're testing

There is no NPC entity in Project Zomboid. Diane is a zombie wearing a disguise
made of three things, and this document is really about whether the disguise
holds:

| Part | If it fails |
|---|---|
| Human animations (113 lifted XML nodes) | she shambles like a zombie |
| Suppressed behaviour | she walks at you, bites, groans, or dies |
| An outfit | she looks like a zombie in a dress |

Plus the spawn handshake — finding her somewhere to stand as the cell loads —
and the dialogue window.

### Read this before you start

**Diane's coordinates are a guess.** She's set to `8003, 11743` — the house you
recorded the dressing in. There is a good chance that tile is a wall, a doorway,
or under a table, in which case she will not appear and **that is not a bug**,
it's Test 2. Fixing it is a two-number edit and this document walks you through
it.

**Copy the mod across first.** `Zomboid\mods\knoxstories` is a real directory
copy, not a junction, and this build adds a whole `animsets` folder as well as
new Lua. If the animations are missing, Diane shambles.

---

## Before you start

```
[KnoxStories] v0.6.1 loaded - 5 quest(s), 3 note(s), 1 npc(s)
```

The banner now reports NPCs too.

**If it says `0 npc(s)`** — Diane was rejected. A `WARN` line will say why, in
plain language.

**If it says `4 quest(s)`** — `dummy_e` (the delivery to Diane) was rejected,
almost certainly because Diane herself was.

---

## Test 1 — Does she appear at all

### Do this

Walk to `8003, 11743`. Use the coordinate readout in the top-left rather than
guessing — it's the tool from part one and this is what it's for.

### You should see

A woman in a long dress, standing still. In the console:

```
[KnoxStories] npc 'diane' (Diane) spawned at 8003,11743,0
```

If that line appears, skip to Test 3.

### If nothing appears — go to Test 2

That's the expected outcome the first time, and it's a configuration problem
rather than a failure.

---

## Test 2 — Giving her somewhere to stand

The spawner refuses any tile the engine doesn't report as **both a solid floor
and free**. It will look around a little and downward through floors, but it
deliberately will **not** bulldoze the square to make room — that would delete
the dressing you recorded there.

### What the console tells you

**`npc 'diane': no square ready yet, retrying`** — it's trying. This is normal
for a second or two while the cell streams in.

**`WARN: npc 'diane' has nowhere to stand at 8003,11743,0.`** — it gave up.
That's your cue.

### Fix it

1. Walk to a clear patch of floor inside the house — somewhere you could stand
   yourself. Not a doorway, not under a table, not on the stairs.
2. Read the three numbers from the readout.
3. Open `mod\knoxstories\42\media\lua\shared\KnoxStories\npcs\KS_DummyNPCs.lua`
   and edit:

   ```lua
   x = 8003, y = 11743, z = 0,
   ```

4. Re-copy the mod, restart, walk back.

She should now be standing there.

### If it still refuses on an obviously clear tile

That's a real bug — tell me the coordinates and paste the `WARN` line. Something
is wrong with how the spawner reads the square rather than with your choice of
tile.

---

## Test 3 — The disguise

This is the test that matters. Watch her for **thirty seconds** without
attacking.

### She should

- **Stand still.** Not shuffle, not sway toward you, not follow.
- **Be silent.** No groaning, no breathing, nothing.
- **Ignore you completely** even if you stand next to her.

### If she shambles toward you

The animation nodes aren't loading, or `setCanWalk` isn't holding. First check
`mod\knoxstories\42\media\animsets\` actually made it into your copy — there
should be **113 `.xml` files** across a lot of subfolders. If they're missing,
that's the copy; if they're present, tell me and that's mine.

### If she groans

The voice prefix isn't clearing. A groaning NPC is a zombie however she stands —
worth reporting even though everything else works.

### If she lunges or bites

`setUseless` or the AI suppression isn't taking. Report it; this is the one that
would make her actively dangerous rather than just unconvincing.

### Then try to hit her

Swing at her once.

**She should not die and should not be hurt.** She's invulnerable on purpose —
an NPC a player can delete by accident is a quest a group can lose.

If she dies, stop and tell me. That's the most serious failure in this document.

> If she's hit hard she may stagger — those animation states were lifted too, so
> she should stagger like a person rather than a zombie, then return to standing.

---

## Test 4 — Talking to her

### Do this

**Right-click on Diane**, or on the tile she's standing on.

### You should see

A **`Talk to Diane`** option. Choosing it opens a window with her name at the
top and her first line beneath it.

Close it. The **second** page opens. Close that, the **third**. Close the third
and it stops.

In the console (debug only): `[KnoxStories] talking to 'diane'`

### If there's no Talk option

The menu finds her by looking at what's standing on the square under your
cursor. Try right-clicking the floor tile she's on rather than her body. If
neither works, tell me — I flagged this as the part of the dialogue code I was
least able to verify without the game.

### If the window opens but is empty or unreadable

Tell me. The window is the stock game one, so a layout problem is more likely to
be how I'm handing it the text.

### If closing page one doesn't open page two

The chaining is broken. Not serious — the text is all readable via repeated
Talk — but tell me.

---

## Test 5 — Delivering to a person

Phase 3's `deliver_item` could only aim at a coordinate, because there was
nobody to deliver to. `dummy_e` now names Diane instead.

### Do this

1. `[KnoxStories] Debug` → **`Spawn note: dummy_letter`**.
2. Walk to Diane, within about three tiles.

### You should see

```
[KnoxStories] quest 'dummy_e': step 'take_it_to_diane' was the last one -- COMPLETE
[KnoxStories] took note 'dummy_letter' (Water-stained letter) on delivery
```

The letter leaves your inventory.

### The point of this test

You never typed Diane's coordinates into the quest. The delivery reads them off
her at load, so **moving her in Test 2 moved the delivery with her**. If you had
to edit two places to move one person, that would be a design failure.

If the delivery still fires at the old location, that's exactly what's happened
— tell me.

---

## Test 6 — She comes back

### Do this

Walk far enough away that the area unloads — a few hundred tiles, or quit and
reload. Then come back.

### You should see

Diane standing where she was, and a fresh spawn line in the console.

A zombie doesn't survive its cell unloading, so she's re-created each time rather
than persisted. That's intended.

### If she doesn't come back

Look for `npc 'diane' unloaded with its cell; it may spawn again`. If that line
never appears, the record thinks she's still there and won't spawn a second one —
tell me.

### If there are suddenly two of her

Worse. The spawn guard has failed. Report it immediately.

---

## When you're done

Ranked by how much I want to know:

1. **She can be killed** — a group can permanently lose a quest.
2. **She lunges or bites** — actively dangerous, not just unconvincing.
3. **She shambles** — the animation lift didn't take, and it's the largest single
   piece of this build.
4. **She groans** — small, but it breaks the illusion completely.
5. **No Talk option** — the bit I could verify least.
6. **She never spawns on a tile you know is clear** — as opposed to the expected
   coordinate problem in Test 2.

## Known gaps

- **She has no idea what's happening.** Dialogue is three fixed lines that never
  change, regardless of quest state. Branching on progress is Phase 5, when the
  writers' Markdown becomes the source of the text.
- **She can't be given things by hand.** `deliver_item` takes the item when you
  stand near her; there's no exchange window.
- **Nothing turns her back into a zombie.** The hook exists — clearing the
  animation variable does it — but no quest uses it.
- **Multiplayer is untested.** She's spawned through the same command boundary
  as everything else, but Phase 6 is where that gets exercised.
