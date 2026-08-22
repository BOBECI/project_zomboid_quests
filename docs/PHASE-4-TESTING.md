# Phase 4 testing — dressing recorder, coordinate readout, conditional examine

Read this with the game open. Each test says what to do, what you should see, and
what it means if you see something else.

Console file, where it's needed:

```
C:\Users\malib\Zomboid\console.txt
```

The recorder writes its export to that **same folder**, so keep it open.

---

## What's in this build, and what isn't

Three things:

1. **A dressing recorder** — dress a house by hand, export what you added.
2. **An on-screen coordinate readout** — so you stop reading `console.txt`.
3. **A conditional examine trigger** — a thing only becomes examinable once
   you're carrying the note about it.

**Not in this build:** the zombie-as-NPC spawn and the dialogue window. Those are
the other half of build-plan Phase 4 and are still to come. Nothing here needs an
NPC to test.

### Two substitutions you should know about

**There is no inhaler in Build 42.** There's an "asthmatic" character trait, but
no item. The examine test uses **beta blockers** (`Base.PillsBeta`) instead. The
trigger doesn't care what the object is — but if Diane's object needs to be an
inhaler specifically, that's a custom item, which is work we haven't scoped.

**No dressing data ships with the mod.** The recorder produces it; nothing is
applied to your world until you record something and copy the file in. So Test 1
is you making the data, and Test 3 is you proving it loads.

---

## Before you start

```
[KnoxStories] v0.4.0 loaded - 4 quest(s), 3 note(s)
```

Four quests now — `dummy_d` is the examine one. If it says three, `dummy_d` was
rejected; there'll be a `WARN` line saying why.

---

## Test 1 — The coordinate readout

Do this first, because every other test is easier with it.

### Do this

Just look at the top-left of the screen.

### You should see

Three numbers — **`8241, 11503, 0`** — updating as you walk. Same values that
were going to `console.txt`.

### If you see nothing

The readout is gated on the debug flag, which is on in this build. If it's
missing, tell me — but check you're on v0.4.0 first.

### If it's in an awkward place or hard to read

Tell me roughly where you'd rather have it. It's a two-line change and I'd rather
put it where you'll actually use it than guess.

---

## Test 2 — Recording a dressing

This is the workflow: dress a house in game rather than typing coordinates.

### Do this

1. Find a small building. A shed or a one-room house is ideal for a first run —
   the recorder scans a **15-tile radius** around where you start.
2. Stand roughly in the middle of it.
3. Right-click the ground → **`[KnoxStories] Debug` → `Start recording dressing
   here`**.

### You should see

The coordinate readout turns **orange**, and a second line appears under it
saying `recording 'dressing_<x>_<y>'`. In the console:

```
[KnoxStories] recording 'dressing_8241_11503' over x 8226-8256, y 11488-11518, floors 0-1
[KnoxStories] place your objects, then use Finish recording. Stay inside that box.
```

**Note the box.** Anything you place outside it won't be captured.

### Now dress it

Use whatever you'd normally use — debug item spawner, dropping items from your
inventory, moving furniture in. For a first test, keep it simple and countable:

- Drop **three** items on the floor, in different spots.
- Place **one** piece of furniture if you can.

Count what you place. You'll check the number in a moment.

### Finish

Right-click the ground → **`[KnoxStories] Debug` → `Finish recording and
export`**.

### You should see

```
[KnoxStories] exported 'dressing_8241_11503': 1 object(s), 3 item(s)
[KnoxStories] written to your Zomboid folder as KnoxStories_dressing_dressing_8241_11503.lua
```

The counts should match what you placed. The orange readout goes back to normal.

### Now open the file

It's in `C:\Users\malib\Zomboid\`. It should look like the mod's own data files:

```lua
table.insert(KnoxStories.DressingSets, {
    id = "dressing_8241_11503",
    area = { x1 = 8226, y1 = 11488, x2 = 8256, y2 = 11518, z1 = 0, z2 = 1 },
    objects = {
        { x = 8241, y = 11502, z = 0, sprite = "furniture_tables_01_1" },
    },
    items = {
        { x = 8240, y = 11503, z = 0, item = "Base.TinCanEmpty" },
    },
})
```

### The thing that actually matters

**Search the file for a wall or a floor sprite.** Something like
`walls_exterior_house_01_` or `floors_`. There should be **none**.

That's the whole design goal: the file contains your additions and nothing else,
so a future map update that moves a wall doesn't invalidate it. If the building
itself is in there, the recorder is capturing too much and the data is fragile —
tell me immediately.

### If the counts are wrong

- **Too few** — you probably placed something outside the 15-tile box, or on a
  floor above `z2`. Check the box printed in the console.
- **Too many** — something the engine spawned as a side effect got caught. Send
  me the file and I'll add a filter.

### If the file is empty

`objects = { }` and `items = { }` with nothing between them means the diff found
no additions. Either nothing was placed inside the box, or the scan isn't seeing
what you placed. Tell me what you placed and how.

---

## Test 3 — Loading a dressing back

Proves the recorded file actually dresses the world.

### Do this

1. Copy your exported file into:
   `mod\knoxstories\42\media\lua\shared\KnoxStories\dressing\`
2. **Delete the things you placed** from the world, so you can tell whether they
   come back.
3. Fully restart the game.
4. Walk back to the building.

### You should see

Your objects and items back where you put them, and in the console:

```
[KnoxStories] dressed 8241,11502,0 with 2 thing(s) from 'dressing_8241_11503'
```

One such line per square that had something on it.

### The important second half

**Pick everything up. Walk far enough away that the area unloads** — a few
hundred tiles, or quit and reload. **Come back.**

The stuff should **not** be there again. It's dressed once, ever.

If it restocks itself, that's a real bug and the most important thing in this
test — it would mean any dressed house is an infinite loot spawner, and it would
read as a game mechanic rather than as a place someone lived.

### If nothing loads

Check the boot banner for a `WARN` about the dressing set. The likely cause is
the file not being where the mod can see it, or a syntax problem from hand-editing
it.

---

## Test 4 — The conditional examine

The Diane mechanic, on stand-in items.

### First, confirm the option is absent

1. Right-click the ground → `[KnoxStories] Debug` →
   **`Spawn examine target (pills)`**.
2. Make sure you are **not** carrying the `Scrawled index card`. Drop it if you
   have one.
3. Right-click the **beta blockers** in your inventory.

### You should see

An ordinary item menu. **No `Examine` option at all.**

Not greyed out — *absent*. A greyed-out entry would tell you there's something
worth finding here, which is exactly the information the note is supposed to
give you.

### Now get the note

Debug → **`Spawn note: dummy_envelope`**. That's the `Scrawled index card`.

### Right-click the pills again

**`Examine`** should now be there.

### Do it

Choose `Examine`. You should see halo text — *"You take a closer look."* — and
within about half a second:

```
[KnoxStories] examined Base.PillsBeta
[KnoxStories] quest 'dummy_d': step 'examine_the_pills' was the last one -- COMPLETE
```

### Then check the reverse

Drop the index card. Right-click a *fresh* packet of pills (spawn another). The
option should be gone again — the condition is live, not a one-time unlock.

> `dummy_d` is complete by then, so the option won't come back for that reason
> either. Use `Reset quest: dummy_d` from the debug menu to test the two
> conditions independently.

### If Examine appears without the note

That's the failure that matters. It means the world is giving away that the
object is significant before the player has any reason to know — which
undermines the whole item-borne-intel idea. Tell me.

### If Examine never appears even with the note

Check the banner said `4 quest(s)`. If `dummy_d` was rejected there'll be a
`WARN` explaining why.

---

## Test 5 — Sharing makes it examinable

The bit that makes this a co-op mechanic rather than a flag. Single-player can
only half-test it.

### Do this

1. `Reset quest: dummy_d`.
2. Get the pills and the index card. Confirm `Examine` appears.
3. **Put the index card in a container** — a locker, a bag on the floor — and
   walk away from it.
4. Right-click the pills.

### You should see

`Examine` gone. The requirement is "carrying it", not "have ever had it".

Take the card back out and it should return. In multiplayer this is what lets one
player hand another the note and change what the world affords for them — that
half waits for Phase 6.

---

## When you're done

Tell me which tests passed, and paste any `WARN` lines.

Ranked by how much I want to know:

1. **The recorder captured walls or floors** — the data would be fragile across
   map updates, which is the whole reason for the snapshot-and-diff approach.
2. **Dressing restocks itself after you loot it** — turns every dressed house
   into a loot spawner.
3. **`Examine` appears without the note** — gives away that an object matters,
   which is the information the note exists to carry.
4. **The readout is in an annoying place** — genuinely worth telling me, since
   you'll be staring at it for the rest of the project.

## Still to come in Phase 4

The zombie-as-NPC spawn with the retry fallback, and the dialogue window. Ruth
doesn't exist yet. When she does, `deliver_item` gains an `npc =` destination and
stops delivering to an empty patch of ground.
