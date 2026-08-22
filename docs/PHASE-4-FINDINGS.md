# Phase 4 findings — dressing recorder, coordinate readout, conditional examine

Tested against **v0.4.1** in single-player, Rosewood. Written from the live test
session; every item below was observed, not inferred.

> **Resolved in v0.5.0.** All four defects fixed, plus both carried-over items.
> Defects 3 and 4 turned out to be one mistake: the examined flag was on the
> item, and this doc asking whether it belonged there is what found it. Examine
> is now an action trigger with no polling, so nothing but the menu can fire it
> and a reset leaves nothing behind. Regressions for defects 2, 3 and 4 were
> written from the reproduction steps below. See PHASE-4-TESTING.md for the
> re-test.
>
> Still open: items placed inside a container are not captured by the recorder
> (surfaces and floors only).

**Summary:** all five tests pass in substance. The recorder produces exactly the
data we wanted it to produce — additions only, no building geometry. Four defects
found, none structural. The most interesting one was only visible because the
tests were run out of order.

---

## Test results

| Test | Result |
|---|---|
| 1 — Coordinate readout | **Pass.** Top-left, updates as you walk, no complaints about placement. |
| 2 — Recording a dressing | **Pass**, with a wrong path in the docs (defect 1). |
| 3 — Loading a dressing back | **Pass**, including the no-restock check. Items placed on furniture return to the floor (defect 2). |
| 4 — Conditional examine | **Pass**, both directions. |
| 5 — Sharing makes it examinable | **Pass** on the removal half. The restore half exposed defects 3 and 4. |

---

## Defects, in the order they should be fixed

### 1. The export lands somewhere other than where the docs say

`PHASE-4-TESTING.md` says the file appears in `C:\Users\malib\Zomboid\`,
alongside `console.txt`. It doesn't — it's written one level down, in a subfolder.
The console line printed on export repeats the same wrong location.

Cost us several minutes of hunting a file that had written successfully.

**Fix:** either write to the documented folder, or — better — make the console
line print the *actual* absolute path it just wrote to, and correct the doc to
match. A success message that names the wrong place is worse than no message.

The `.lua` → `.txt` change from v0.4.1 is confirmed working. The game will not
open a `.lua` file for writing; exporting as `.txt` and renaming is the right
workaround.

*Doc note:* Windows 11 hides known file extensions by default, so the rename step
is impossible until `View → Show → File name extensions` is ticked. Worth one line
in the guide.

### 2. Items placed on furniture come back on the floor

Recorded three items sitting on tables and counters. On reload they were all on
the ground at the right tile.

The recorder stores a square coordinate — `x`, `y`, `z` — and `z` is the floor
level, not the height within the square. There is nothing in the data that says
"in this container" or "on this surface", so everything is restored to the tile
itself.

This matters for the pilot specifically. **Diane's two place settings on the
table** are the detail the whole house is built around; on the floor they read as
looting, not as a woman still setting a place for her daughter.

**Fix:** capture the surface or container the item was in, not just the tile, and
restore into it. Falling back to the floor when the container is missing is the
right failure mode.

### 3. Picking up the target item auto-fires the examine

This is the one worth reading carefully.

If you are already carrying the note when the pills enter your inventory, the
examine fires immediately on pickup. The quest completes, and the menu option is
therefore already gone by the time you right-click. It looks like the option is
broken; it isn't, it has already been used.

The first run through Test 4 didn't show this only because the pills were spawned
*before* the card existed. Every later attempt had the card in inventory first.

**Fix:** examine should fire only from the context-menu option, never as a
side-effect of acquisition.

Design reason, not just a mechanical one: the whole point of the mechanic is that
looking closer is a **deliberate act**. The player decides to check, and the world
answers. If pickup does it automatically, the recognition happens *to* the player
rather than being chosen by them, and the moment where Casey stops being scenery
loses its weight entirely.

### 4. Items that have been through an examine cycle carry stale state

After `Reset quest: dummy_d`, reusing the *same* pills and the *same* card does
not restore the `Examine` option. Spawning a **fresh** packet and a **fresh**
card, with the same steps in the same order, works correctly every time.

So the condition logic is sound. Something is being written onto the item and is
not cleared by the quest reset.

**Fix:** find what's stuck on the item — most likely a ModData flag set at examine
time — and clear it on reset. Two follow-on questions worth answering while in
there:

- Should the flag be on the *item* at all, or on the quest state? An item-borne
  flag means two identical packets of pills behave differently, which is a
  surprising thing to be true.
- Whatever the answer, `Reset quest` needs to reset **everything** the quest
  touched, or it isn't a usable debug tool for the rest of the project.

---

## What passed cleanly, and why it matters

**The recorder captures no walls or floors.** Searched the exported file: only the
three items and their coordinates. This was the number-one risk going in — if the
diff had swept up the building itself, the data would break on every map update.
It doesn't. The snapshot-and-diff approach is validated.

**Dressing does not restock.** Looted the house, reloaded, came back — nothing had
returned. A dressed house is a place someone lived, not a respawning loot node.

**The examine condition is live, not a one-time unlock.** Removing the card hides
the option; the card sitting in a nearby drawer is not enough, it has to be
carried. That is precisely the property Phase 6 needs: one player hands another a
note and the world starts affording things it didn't before.

---

## Not a defect, but fix it before it spreads

The testing doc still refers to the NPC as **Ruth**. The pilot is now *Not On The
List* — **Diane** and **Casey**. Ruth is a spare quest.

If the name is in the code as well as the docs, it should be changed now, while
it's cheap.

---

## Carried over from earlier phases

Still open, unrelated to Phase 4:

- `KS_Evaluator.lua` holds `tickCounter` / `TICKS_PER_SCAN` as file-locals rather
  than per-player. Harmless in single-player; wrong the moment two players exist.
- The note-copy recipe should accept a wide family of paper and writing items.
  Paper is scarce in B42 and the mechanic shouldn't become a treasure hunt.

---

## Next

Fix round on the four defects above, then the second half of Phase 4: zombie-as-NPC
spawn with the retry fallback, and the dialogue window. `deliver_item` gains an
`npc =` destination at that point.
