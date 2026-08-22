# Phase 3 testing — the four trigger types

Read this with the game open. Each test says what to do, what you should see, and
what it means if you see something else.

Console file, for the tests that need it:

```
C:\Users\malib\Zomboid\console.txt
```

---

## What you're testing

One quest, `dummy_c`, with one step per trigger type. Walking it end to end is
the whole of Phase 3.

| Step | Trigger | What advances it |
|---|---|---|
| `arrive` | `enter_area` | walking into Rosewood — hands you a note |
| `read_the_letter` | `read_note` | opening that note |
| `find_a_screwdriver` | `acquire_item` | having a screwdriver on you |
| `hand_it_over` | `deliver_item` | carrying the note to the fire station |

`dummy_a` and `dummy_b` from earlier phases are still there and still work. They
share the Rosewood arrival area, so expect them to move at the same time as
`dummy_c`'s first step. That's correct, not a bug.

### One thing that will look wrong and isn't

Step 4 delivers a note to **an empty patch of ground**. There's nobody there to
hand it to, because NPCs are Phase 4. The trigger works; its destination is a
coordinate for now. It'll feel strange to play, and that's expected.

---

## Before you start

**Your existing save is fine this time.** New quests are seeded into an existing
world on load, so `dummy_c` will appear even though your save predates it. No new
character needed.

### Check the right version loaded

```
[KnoxStories] v0.3.1 loaded - 3 quest(s), 3 note(s)
[KnoxStories]   dummy_a: complete (step: nil)
[KnoxStories]   dummy_b: complete (step: nil)
[KnoxStories]   dummy_c: active (step: arrive)
```

The first two lines will show whatever state you left them in. The one that
matters is **`dummy_c: active (step: arrive)`**.

**If it says `2 quest(s)`** — `dummy_c` was rejected as invalid. There'll be a
`WARN` line saying why, in plain language. Send it to me.

**If there's no `dummy_c` line at all** — it registered but wasn't seeded into
your world. That's a bug in the additive seeding; tell me.

**If you're already standing in Rosewood when you load**, step 1 may fire within
a second or two of the save opening. That's fine — just start at Test 2.

### Starting over at any point

Right-click the ground → **`[KnoxStories] Debug` → `Reset quest: dummy_c`** puts
it back to step one. Use it freely — if a test goes sideways, reset and re-run
rather than untangling it.

---

## Test 1 — `enter_area`

Already proven in Phase 1, but it's step one of the chain, so it has to work.

### Do this

Walk around outdoors in Rosewood, on the **ground floor**.

### You should see

- Halo text: **`Quest step: dummy_c / arrive`**
- A new item: **`Torn scrap of graph paper`**
- In `console.txt`:

```
[KnoxStories] trigger fired: dummy_c / arrive
[KnoxStories] quest 'dummy_c': step 'arrive' -> 'read_the_letter'
[KnoxStories] gave note 'dummy_scrap' to the player
```

### If nothing happens

Find a `position:` line in the console. The area is **x 7800–8600, y 11100–12000,
ground floor**. If you're inside that and it still doesn't fire, tell me the
numbers.

---

## Test 2 — `read_note`

This is the trigger most likely to break, because it's the only one that hooks
into a function the game owns rather than reading state.

### First, confirm it does NOT fire on possession alone

You're now carrying the scrap and haven't opened it. Walk around for ten seconds.

**You should see** `dummy_c` stay on `read_the_letter`. Nothing in the console.

If it advances *without* you opening the note, the trigger is firing on merely
holding it — that's wrong. Tell me.

### Now read it

Right-click the **`Torn scrap of graph paper`** and choose **Read**.

> It should say *Read*, not *Write*, even if you're carrying a pen. That's the
> lock working.

### You should see

Within about half a second of the window opening:

```
[KnoxStories] note 'dummy_scrap' was opened for the first time
[KnoxStories] trigger fired: dummy_c / read_the_letter
[KnoxStories] quest 'dummy_c': step 'read_the_letter' -> 'find_a_screwdriver'
```

You can close the note straight away — opening it is what counts.

### If the note window opens but nothing fires

The hook didn't install. Most likely another mod replaced the same function.
Check the console for the `was opened for the first time` line — if that's
missing, the hook never ran. Tell me, and mention any other mods you have
enabled.

### If the note opens and the game throws an error

Also the hook — tell me the error text. This is the one place Phase 3 wraps a
vanilla function, so it's the first suspect for anything odd around reading.

### Worth knowing

The trigger needs the note **in your inventory** as well as read. If you read it
and then drop it before the next scan, it won't fire. Pick it back up.

---

## Test 3 — `acquire_item`

### Do this

Get a screwdriver. Either loot one, or right-click the ground →
**`[KnoxStories] Debug` → `Spawn screwdriver`**.

### You should see

```
[KnoxStories] trigger fired: dummy_c / find_a_screwdriver
[KnoxStories] quest 'dummy_c': step 'find_a_screwdriver' -> 'hand_it_over'
```

### Then check it finds things inside bags

Not required, but it's the case most likely to be wrong. Put the screwdriver in a
backpack **before** this step fires, if you're testing on a fresh run — the
search is supposed to recurse into containers.

### If it doesn't fire with a screwdriver in hand

Tell me what the item is actually called (hover it). The name was read from the
game's own files, so this shouldn't happen, but it's a one-line fix if it does.

---

## Test 4 — `deliver_item`

### Do this

Carry the **`Torn scrap of graph paper`** to the **Rosewood fire station**,
around **x 8040, y 11790, ground floor**. Anywhere within about 3 tiles counts.

Use the `position:` lines in the console to steer — these coordinates are still a
best guess.

### You should see

```
[KnoxStories] trigger fired: dummy_c / hand_it_over
[KnoxStories] quest 'dummy_c': step 'hand_it_over' was the last one -- COMPLETE
[KnoxStories] took note 'dummy_scrap' (Torn scrap of graph paper) on delivery
```

And in your inventory: **the scrap is gone.** That's the delivery.

### Check the screwdriver is still there

It should be. `deliver_item` takes only the thing it names — if the screwdriver
vanished too, that's a real bug and I want to know.

### If you arrive and nothing happens

Two possibilities, and the console tells you which:

- **No `position:` line near 8040 / 11790** — you're not where you think you are.
  Walk until the numbers match.
- **Position is right but no trigger** — you're not carrying the scrap, or the
  coordinates in the quest data are wrong for this building. Tell me your
  position numbers and I'll retune.

### If the step completes but the scrap stays in your bag

Look for:

```
[KnoxStories] WARN: delivered note 'dummy_scrap' (...) was gone before it could be taken
```

If that line is present, the quest advanced but the item had already moved — tell
me. If the line is *absent* and the scrap is still there, the consume step didn't
run at all, which is worse. Also tell me.

---

## Test 5 — Delivering one copy of two

A delivery should take **one** matching item, not every matching item. If you're
carrying the original and a hand-made copy, you should hand over one and keep the
other — which is exactly the redundancy the design is built around.

### Do this

1. Right-click the ground → `[KnoxStories] Debug` → **`Reset quest: dummy_c`**.
   The console confirms:
   `[KnoxStories] reset quest 'dummy_c' to step 'arrive'`
2. Walk the chain again as far as step 4 — arrive, read the scrap, get a
   screwdriver. Don't go to the fire station yet.
3. Debug → `Spawn pen + paper`, then right-click the scrap → **`Copy this note`**.
   You now have two.
4. Walk to the fire station.

### You should see

- The quest completes as before.
- **One** scrap gone, **one** still in your bag.
- One `took note 'dummy_scrap' ... on delivery` line, not two.

### If both disappear

That's a real bug and an important one — it means a delivery strips every copy
the group is carrying. Tell me.

### If neither disappears

See the "step completes but the scrap stays in your bag" notes in Test 4.

> `Reset quest` is debug-only and writes world state directly, bypassing the
> normal command boundary. It disappears with the debug flag.

---

## Test 6 — Save and reload mid-quest

### Do this

Get `dummy_c` to a middle step — say, after reading the note but before the
screwdriver. Quit to the main menu and load again.

### You should see

```
[KnoxStories]   dummy_c: active (step: find_a_screwdriver)
```

The same step you left on. Then pick a screwdriver up and confirm it still
advances.

### The one to watch

Does the **read flag survive**? If you reload while on `find_a_screwdriver` and
then somehow end up back on `read_the_letter`, the note would need re-reading.
Shouldn't happen, but if the quest ever goes backwards after a reload, that's
serious — tell me.

---

## Test 7 — Things that should NOT happen

Quick negative checks. None should fire anything.

1. **Upstairs.** Stand inside the Rosewood box but on a second floor. No trigger.
2. **The delivery spot without the item.** Stand at the fire station carrying
   nothing. No trigger, no console line.
3. **Reading someone else's paper.** Read a plain vanilla notepad or magazine.
   No `was opened for the first time` line — that's only for our notes.

If any of these *does* fire something, that's a false positive and more important
than a trigger failing to fire. Tell me which one.

---

## When you're done

Tell me which of the four fired cleanly, and paste any `WARN` lines.

Ranked by how much I want to know:

1. **`read_note` didn't fire** — it's the only trigger depending on a wrapped
   vanilla function, so it's the most fragile thing in this phase and the most
   likely to break when you add other mods.
2. **`deliver_item` fired but didn't take the item** — a delivery that doesn't
   deliver breaks the design's whole point about notes being physical.
3. **Anything in Test 7 firing when it shouldn't** — a false positive is worse
   than a miss, because it advances the world's quest state for everyone.
4. **Coordinates being off** — expected, and a one-line fix.
