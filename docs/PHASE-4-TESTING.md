# Phase 4 testing — dressing recorder, coordinate readout, conditional examine

Read this with the game open. Each test says what to do, what you should see, and
what it means if you see something else.

Console file, where it's needed:

```
C:\Users\malib\Zomboid\console.txt
```

The recorder writes its export somewhere **else** — see Test 2. It is not next to
`console.txt`.

---

## Re-testing after the v0.5.0 fix round

If you tested v0.4.1, four things changed underneath you. **Your previously
exported dressing file is stale** — the item format gained offset fields — so
Test 2 needs running from the top.

| Was | Now |
|---|---|
| Export path was wrong in the docs and the console | The console prints the real absolute path |
| Items recorded on tables came back on the floor | Offsets and rotation are captured and restored |
| Examine fired on picking the item up | Only the menu option can fire it — nothing polls it |
| `Reset quest` left stale state on the item | Nothing is written to the item at all; reset is a real reset |

Tests 4 and 5 changed mechanism entirely, so run them carefully rather than
skimming. Test 6 is new and covers the widened copy materials.

---

## What's in this build, and what isn't

1. **A dressing recorder** — dress a house by hand, export what you added.
2. **An on-screen coordinate readout** — so you stop reading `console.txt`.
3. **A conditional examine trigger** — a thing only becomes examinable once
   you're carrying the note about it.

**Not in this build:** the zombie-as-NPC spawn and the dialogue window. Those are
the other half of build-plan Phase 4. Nothing here needs an NPC to test.

### Two substitutions you should know about

**There is no inhaler in Build 42.** There's an "asthmatic" character trait, but
no item. The examine test uses **beta blockers** (`Base.PillsBeta`) instead. The
trigger doesn't care what the object is — but if Casey's object needs to be an
inhaler specifically, that's a custom item, which is work we haven't scoped.

**No dressing data ships with the mod.** The recorder produces it; nothing is
applied to your world until you record something and copy the file in.

---

## Before you start

```
[KnoxStories] v0.5.0 loaded - 4 quest(s), 3 note(s)
```

If it says `v0.4.x`, the copy in `Zomboid\mods\knoxstories` is stale — it's a real
directory copy, not a junction, so it needs re-copying after every change.

---

## Test 1 — The coordinate readout

### Do this

Look at the top-left of the screen.

### You should see

Three numbers — **`8241, 11503, 0`** — updating as you walk.

### If it's in an awkward place

Tell me where you'd rather have it. Two-line change.

---

## Test 2 — Recording a dressing

### Do this

1. Find a small building with **a table or counter in it**. That matters this
   time — see the dressing step.
2. Stand roughly in the middle. The recorder scans a **15-tile radius**.
3. Right-click the ground → **`[KnoxStories] Debug` → `Start recording dressing
   here`**.

### You should see

The readout turns **orange** with a second line under it. In the console:

```
[KnoxStories] recording 'house_8241_11503' over x 8226-8256, y 11488-11518, floors 0-1
[KnoxStories] place your objects, then use Finish recording. Stay inside that box.
```

**Anything placed outside that box won't be captured.**

### Now dress it — and use the table

Count what you place:

- Drop **two** items on the floor.
- Put **one item on the table or counter**. This is the case that was broken:
  height within the tile was being thrown away, so everything came back on the
  ground.
- Place **one piece of furniture** if you can — the `objects` list is the half
  your first run never exercised.

### Finish

**`[KnoxStories] Debug` → `Finish recording and export`**.

```
[KnoxStories] exported 'house_8241_11503': 1 object(s), 3 item(s)
[KnoxStories] written to C:\Users\malib\Zomboid\Lua\KnoxStories_house_8241_11503.txt
[KnoxStories] rename it to .lua, then copy it into the mod's dressing folder
```

That second line is now the **actual absolute path**, not a guess. Follow it.

### Open the file

```lua
table.insert(KnoxStories.DressingSets, {
    id = "house_8241_11503",
    area = { x1 = 8226, y1 = 11488, x2 = 8256, y2 = 11518, z1 = 0, z2 = 1 },
    objects = {
        { x = 8241, y = 11502, z = 0, sprite = "furniture_tables_01_1" },
    },
    items = {
        { x = 8240, y = 11503, z = 0, item = "Base.TinCanEmpty", ox = 0.213, oy = 0.884, oz = 0.000, rot = 0.0 },
        { x = 8241, y = 11502, z = 0, item = "Base.Plate", ox = 0.400, oy = 0.600, oz = 0.500, rot = 0.0 },
    },
})
```

### Two things to check

**The item you put on the table has a non-zero `oz`.** Roughly 0.5. If every `oz`
is `0.000`, the height isn't being read and Test 3 will put things on the floor
again.

**No walls, no floors.** Search for `walls_` and `floors_`. There should be none.
This is still the number-one risk: if the building itself is in the file, the
data breaks on every map update.

### If the counts are wrong

- **Too few** — something was outside the 15-tile box, or above `z2`.
- **Too many** — the engine spawned something as a side effect. Send me the file.

---

## Test 3 — Loading a dressing back

### Do this

1. **Rename the exported file from `.txt` to `.lua`**, then copy it into:
   `mod\knoxstories\42\media\lua\shared\KnoxStories\dressing\`

   > It exports as `.txt` because the game refuses to open a `.lua` file for
   > writing. The contents are already Lua; only the extension changes.
   >
   > Windows 11 hides known file extensions by default, so the rename is
   > impossible until you tick **View → Show → File name extensions** in
   > Explorer.

2. Re-copy the mod into `Zomboid\mods\`.
3. **Clear the things you placed** from the world.
4. Fully restart the game and walk back.

### You should see

```
[KnoxStories] dressed 8241,11502,0 with 2 thing(s) from 'house_8241_11503'
```

**The item you put on the table should be back on the table**, not on the floor
beside it. That's the defect-2 fix, and it's the one Diane's place settings
depend on.

### The important second half

**Pick everything up. Walk far enough that the area unloads, or quit and reload.
Come back.**

Nothing should have returned. A dressed house is a place someone lived, not a
respawning loot node.

### If items are on the floor rather than the surface

Check the `oz` values in your file. If they're all zero, the recorder didn't read
the height — tell me what you placed it on.

---

## Test 4 — The conditional examine

Rebuilt since v0.4.1. Nothing polls this any more: the **menu option is the only
thing that can advance it**.

### First — the regression that made this look broken

This is the exact sequence that failed before, so do it in this order.

1. `[KnoxStories] Debug` → **`Reset quest: dummy_d`**.
2. `[KnoxStories] Debug` → **`Spawn note: dummy_envelope`** — get the note
   **first**.
3. *Now* → **`Spawn examine target (pills)`**.
4. **Wait ten seconds. Walk around. Don't right-click anything.**

**You should see nothing happen.** `dummy_d` stays active. No completion line.

Previously the step fired the instant the pills entered your inventory, so the
option was already spent by the time you looked for it. If you see a
`dummy_d ... COMPLETE` line before you've right-clicked, the defect is back and
that's the single most important thing to report.

### Now confirm the option is gated

Drop the index card, then right-click the pills.

**No `Examine` option at all** — absent, not greyed out. A greyed-out entry would
tell you the object matters, which is what the note is there to tell you.

Pick the card back up, right-click again: **`Examine` appears.**

### Do it

Choose `Examine`. Halo text — *"You take a closer look."* — and:

```
[KnoxStories] quest 'dummy_d': step 'examine_the_pills' was the last one -- COMPLETE
```

Right-click the pills again: the option should be **gone**, because the step is
done.

### If Examine appears without the note

The world is announcing that an object is significant before the player has any
reason to know. Tell me.

---

## Test 5 — Reset works on the same objects

This was defect 4. Previously a reset only worked with a *freshly spawned* packet
and card, which made `Reset quest` useless as a debug tool.

### Do this

Using **the same pills and the same card** you just examined — don't spawn new
ones:

1. `[KnoxStories] Debug` → **`Reset quest: dummy_d`**.

```
[KnoxStories] reset quest 'dummy_d' to step 'examine_the_pills'
```

2. Right-click the same packet of pills.

### You should see

**`Examine` is back.** Choosing it completes the quest again.

Repeat two or three times. It should work every time, on the same objects.

### If the option doesn't come back

Something is still being written to the item and surviving the reset. Tell me —
that's the defect reopening.

### Also worth checking

Spawn a **second** packet of pills while one is already in your bag. Both should
offer `Examine` identically. Two identical packets behaving differently was the
symptom that pointed at the root cause.

---

## Test 6 — Copying accepts more kinds of paper

New in v0.5.0. Copying now asks the game "can this be written on, and is it
blank?" instead of consulting a hard-coded list, because paper is scarce in B42
and the mechanic shouldn't be a treasure hunt.

### Do this

Get a quest note — `Spawn note: dummy_letter` — and a pen. Then try each of these
as the paper, one at a time, checking `Copy this note` is enabled:

- a sheet of paper
- **graph paper**
- **an index card**
- **an empty notebook or journal**

All four should work.

### Then check the guard still holds

Write something in a journal yourself, then try to copy onto it.

**It should refuse** — `You need a blank sheet of paper.` Copying over somebody's
diary would be worse than not having enough paper.

A quest note should also never be usable as blank paper.

---

## Test 7 — Things that should NOT happen

1. Stand in the Rosewood box **on a second floor** — no trigger.
2. Stand at the fire station **without** the delivery item — nothing.
3. Read a **plain vanilla notepad** — no `was opened for the first time` line.
4. Carry the card and the pills and **wait** — no examine.

A false positive matters more than a miss: it advances world state for the whole
group.

---

## When you're done

Ranked by how much I want to know:

1. **Examine fires without you choosing it** (Test 4) — defect 3 reopening.
2. **The recorder captured walls or floors** (Test 2) — makes the data fragile
   across map updates.
3. **Items restored to the floor instead of the surface** (Test 3) — defect 2
   reopening; the one Diane's table depends on.
4. **Dressing restocks after looting** (Test 3) — turns a dressed house into a
   loot spawner.
5. **Reset doesn't restore the option on the same objects** (Test 5) — defect 4
   reopening.

## Known gap

Items placed **inside a container** — a cupboard, a fridge, a drawer — are still
not captured. Only surfaces and floors are. Different mechanism, deliberately not
half-done. Say if the pilot needs it.

## Still to come in Phase 4

The zombie-as-NPC spawn with the retry fallback, and the dialogue window. Diane
and Casey do not exist yet. When they do, `deliver_item` gains an `npc =`
destination and stops delivering to an empty patch of ground.
