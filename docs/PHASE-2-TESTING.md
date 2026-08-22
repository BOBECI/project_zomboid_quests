# Phase 2 testing — notes, copying, and corpse loot

Read this with the game open. Each test says what to do, what you should see, and
what it means if you see something else.

Nothing here needs the console except where it says so. When it does, the file is:

```
C:\Users\malib\Zomboid\console.txt
```

Leave it open in a text editor that reloads on change, or just re-open it between
tests.

---

## Before you start

**Use a new save if you can.** Two of these tests hand you a note automatically
when you walk into Rosewood, and that only happens if those quest steps haven't
already been completed. On your existing save they have been, so you'd have to
use the debug menu instead. Everything still works either way — a new save is
just less fiddly.

### Check the right version loaded

Load the save and look at the top of `console.txt`.

**You should see:**

```
[KnoxStories] v0.2.1 loaded - 2 quest(s), 2 note(s)
[KnoxStories]   dummy_a: active (step: reach_rosewood)
[KnoxStories]   dummy_b: active (step: reach_west)
```

**If it says v0.2.0 or older** — the game is still loading the old files. Close the game
fully and reopen it.

**If there's no `[KnoxStories]` line at all** — the mod isn't enabled on this
save. Mods are recorded per-save, so enabling it in the main menu isn't enough
for an existing world; it has to be on when the world is created.

**If it says `0 note(s)`** — the note files didn't load. Stop here and tell me.

**If any line starts with `WARN`** — copy those lines out. They're written in
plain language and usually say exactly what's wrong.

---

## Test 1 — The letter arrives on its own

This is the note handed over by a quest step, which is the whole point of
"spawned from data".

### Do this

Spawn in Rosewood and walk around outdoors for a few seconds. Stay on the
**ground floor** — the trigger deliberately ignores upper storeys, so standing on
a second floor will not fire it.

### You should see

- A message floating over your character reading roughly
  **`Quest step: dummy_a / reach_rosewood`**
- A new item in your inventory called **`Water-stained letter`**
- In `console.txt`:

```
[KnoxStories] quest 'dummy_a': step 'reach_rosewood' -> 'reach_fire_station'
[KnoxStories] gave note 'dummy_letter' to the player
```

### If nothing happens after a minute of walking

Check `console.txt` for a line like:

```
[KnoxStories] position: 8241, 11503, 0
```

That's your current position, printed every few seconds while you move. The
trigger area covers **x 7800–8600, y 11100–12000, ground floor**. If your numbers
are outside that, you aren't in Rosewood — head into town.

If your numbers *are* inside that range and still nothing fires, that's a real
bug. Note the position numbers and tell me.

### If the item appears but is called "Notepad"

The note was created but its name didn't stick. Tell me — that's a rename problem
on my side, not something you can fix in game.

---

## Test 2 — Reading the letter

### Do this

Right-click the `Water-stained letter` in your inventory and choose **Read**.

### You should see

Two pages. The first one starts *"If you are reading this I am already gone
west"* and contains **real line breaks** — the text should sit in short
paragraphs, not run together.

### If you see the text `<LINE>` printed literally

The line-break token isn't being expanded. Tell me. Harmless but wrong.

### If it only shows one page

The second page didn't get written. Tell me.

---

## Test 3 — The letter can't be overwritten

Quest text has to survive the player. This is the test most likely to fail,
because it depends on game behaviour I couldn't verify outside the game.

### Do this

With the letter open, try to write on it or edit it — whatever the notepad UI
normally offers for a blank page.

### You should see

**No way to change the text.** The write option should be absent or refuse. You
should still be able to *read* it freely.

### If you can type over the quest text

That's a genuine failure — tell me. It means the lock isn't holding, and it
matters, because a player could wipe a quest note by accident.

### If you can't read it either

Also a failure, and a worse one. Tell me.

---

## Test 4 — The copy recipe

This is the mechanic the whole design leans on, so take it slowly.

### Step 1 — check it refuses with nothing in your pockets

Do this **before** spawning any materials.

Right-click the `Water-stained letter` in your inventory.

**You should see** a **`Copy this note`** option that is **greyed out**, with a
tooltip reading **`You need a pen or pencil.`**

If the option is greyed out but shows *no* tooltip, that's minor — tell me, but
carry on.

### Step 2 — get the materials

Right-click the **ground** (not an item) and choose
**`[KnoxStories] Debug` → `Spawn pen + paper`**.

That puts one pen and two sheets of paper in your inventory.

> The debug menu only exists because the debug flag is on. It'll disappear before
> release.

### Step 3 — check the second refusal

Drop both sheets of paper on the ground, keeping the pen.

Right-click the letter again. The tooltip should now read
**`You need a blank sheet of paper.`** — a different message from Step 1.

Pick the paper back up.

### Step 4 — do the copy

With the pen and both sheets of paper in your inventory:

1. Right-click the `Water-stained letter`.
2. Choose **`Copy this note`**.
3. **Stand still.** Walking or running cancels it.

### You should see

- A progress bar, running a few seconds. The letter takes about twice as long as
  the envelope does later, because it has twice the pages.
- Afterwards, **two** `Water-stained letter` items in your inventory.
- **One sheet of paper fewer than you had when you started** — so one left of the
  two.
- In `console.txt`: `[KnoxStories] copied note 'dummy_letter'`

### Check the copy is real

Read the second letter. It should be **identical** — same title, same two pages,
same line breaks — and it should be just as locked as the original (repeat Test 3
on it).

Then copy the copy, using your remaining sheet of paper. The third one should
still match the original exactly.

### If "Copy this note" never appears at all

The game doesn't recognise the item as one of ours. Tell me.

### If it stays greyed out even with a pen and paper in hand

The names the mod looks for don't match this build. They've now been read
directly out of the game's own item files rather than guessed, so this is
unlikely — but if it happens, tell me what pen and paper you're actually holding
and I'll correct the list.

### If the progress bar runs but nothing is produced

Check `console.txt` for a `WARN` line. Send it to me.

### If paper disappears but no copy appears

Tell me immediately. That's the worst outcome — it means a player could burn
materials for nothing.

---

## Test 5 — The index card

Same mechanic, different vanilla item and only one page. This is here to prove
the code isn't quietly assuming every note is a notepad.

> Its internal id is still `dummy_envelope`, so that's what the debug menu calls
> it. It was originally going to be a piece of mail; that item turned out not to
> support written pages, so it's an index card now. Only the id kept the old name.

### Do this

Easiest route: right-click the ground →
**`[KnoxStories] Debug` → `Spawn note: dummy_envelope`**.

The intended route is walking to the west side of Rosewood — roughly
**x 7950–7970, y 11850–11870** — which hands it over via `dummy_b`. That's a
small area and my coordinates for it are a guess, so use the `position:` lines in
`console.txt` to steer if you want to try it. Don't spend long on it; the debug
spawn tests the same thing.

### You should see

An item called **`Scrawled index card`**, one page, readable, locked, and copyable
exactly like the letter.

### If it never spawns

Look for a console line like:

```
[KnoxStories] WARN: cannot create note 'dummy_envelope': the game has no item called 'Base.IndexCard'
```

That means the base item doesn't exist in this build. Easy fix — just send me the
line.

---

## Test 6 — Dying with the note

The design says losing the note should hurt, and that recovering it means going
back for your body. So the note has to survive your death intact.

### Do this

1. Make sure you have the letter **and at least one copy** in your inventory.
2. Note roughly where you are.
3. Kill your character. Drinking bleach is the quickest reliable way.
4. Start a new character in the **same world**.
5. Walk back and loot your corpse.

### You should see

- Both letters still on the body.
- Both still called `Water-stained letter`, still with their text.
- **Right-clicking one still offers `Copy this note`** (greyed out until you have
  a pen and paper again).

That last point is the one that actually matters. It proves the note kept its
hidden identity through dying and being moved onto a corpse — not just its text.

### If the notes are on the body but "Copy this note" is gone

The text survived but the identity didn't. Tell me — the note would still read
fine but would be dead weight for quest purposes.

### If the notes aren't on the body at all

That's vanilla behaviour rather than our code, but tell me anyway.

---

## Test 7 — Save and reload

### Do this

With at least one letter and one copy in your inventory, quit to the main menu
and load the save again.

### You should see

In `console.txt`, the same quest lines as before you quit — whatever steps you'd
reached, not reset to the beginning:

```
[KnoxStories] v0.2.1 loaded - 2 quest(s), 2 note(s)
[KnoxStories]   dummy_a: active (step: reach_fire_station)
```

And in your inventory: both letters, still named, still readable, still offering
`Copy this note`.

### If the quest lines say `reach_rosewood` again

Progress reset. That's a serious bug — tell me. (This worked in Phase 1, so it
would be new.)

### If the notes are there but blank, or unnamed

The item text didn't persist. Tell me.

---

## Test 8 — Passing a note (partial)

The full version of this test is two players handing a letter between them, and
that needs multiplayer, which is Phase 6. What you *can* check now is the same
transfer path:

### Do this

Drop a letter on the ground, walk away far enough that the area unloads, come
back, and pick it up. Then put one in a container — a locker, a bag, a car boot —
close it, and take it back out.

### You should see

The note unchanged each time: same name, same text, still locked, still offering
`Copy this note`.

---

## When you're done

Tell me which tests passed and paste any `WARN` lines from `console.txt`. If
something failed, the position numbers or the exact item names you were holding
are usually all I need.

Every vanilla item name the mod uses has now been read out of the game's own
files in your install, so the "wrong item name" class of failure should be gone.

The one I'd genuinely like to know about early is **Test 3**, whether the lock
holds. A wrong name is a one-line correction; the lock not working is a behaviour
I'd have to design around.

After that, **Test 6** — whether the copy option survives on a note looted off
your own corpse.
