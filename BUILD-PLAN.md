# Build plan

**v0.1 · reads alongside PROJECT-OVERVIEW.md and PROJECT-SETUP.md**

Written after reading `ARCHITECTURE.md` — the reverse-engineered notes on Storylines (QDas). That mod is the closest existing thing to what we're building, so this plan is partly a list of what to take from it and partly a list of where we deliberately go the other way.

---

## 1. What we do not need

Worth stating plainly, because it removes most of what looks intimidating about the reference mod.

| Not needed | Why |
|---|---|
| 3D models | Their NPCs are zombies in vanilla clothing. Notes are vanilla notepads. Nothing in the reference mod is modelled. |
| Custom textures | Only if we want a bespoke quest-log icon. Cosmetic, deferrable. |
| New animations | We need an NPC that stands still. Their rifle-aiming and sleeping states are content we don't have. |
| Map editing | Quests attach to existing buildings by coordinate. Ruth lives in a house that already exists. |
| Custom items, mostly | Notes are vanilla `Base.Notepad` / `Base.GenericMail` rewritten at spawn. |
| A translation pipeline, initially | English only for the pilot. The key structure goes in from day one so translation is possible later, but we don't ship thirteen languages. |

## 2. What to lift from Storylines

Three things only.

**The animation XMLs** (`media/animsets/zombie/**`, ~180 files). These add an `npcquest_*` variant to every zombie animation state, gated on a variable. That's mechanical, tedious, already-correct work. We need the idle variant; we can drop the rifle and sleep sets. Lift, prune, rename to our own variable.

**The spawn handshake, as reference.** `client/npc/vl_npc_spawn_loadgridsquare.lua` — specifically `CheckNPCSpawnPoint` and the fallback that retries for 120 ticks and, failing everything, clears the square and lays down a floor tile. That's hard-won knowledge about how PZ actually behaves when a square is blocked. Read it, understand it, reimplement it. Don't copy the file.

**The zombie-as-NPC technique itself.** `addZombiesInOutfit` → `setUseless(true)` → invulnerable → set the animation variable → dress via clothing/tint tables. The technique is sound. Our implementation, their approach.

Everything else is written fresh. Their code is entangled with their globals (`VLF`, `VLZB`, `VLQS`, `VLINTER`) and their quest ID conventions; untangling it would cost more than writing it.

## 3. Where we diverge — the four decisions that matter

### 3.1 Quest state is world state, not player state

Their model: `VL_Player_<pID>.Quest.Q1[qStep]`. Every player carries their own copy of every quest's progress. The client decides it has finished a step, writes its own ModData, and tells the server, which doesn't validate.

Our model: quest progress lives in the **world** ModData table, once. There is no per-player copy because there is no per-player story. The server owns it and is authoritative.

This is the single biggest structural difference and it simplifies more than it complicates — no sync problem, because there's only one copy.

Per-player data still exists, but only for genuinely personal things: which notes are in your inventory, which dialogue you've personally seen.

### 3.2 Steps are data, not functions

Their model: each step is a Lua closure in a dispatch table. Adding a quest means writing Lua.

Ours can't work that way — our writers produce Markdown. So a step is a **data record**: trigger type, trigger parameters, what it unlocks, what text it shows. A single generic evaluator runs all of them.

This is more constrained than closures. That constraint is the point: it's what makes the loader possible, and it forces us to define a small vocabulary of trigger types instead of writing arbitrary code per quest.

Their polled loop is still the right shape — scan active steps every N player updates, evaluate each. We just evaluate data instead of calling closures.

### 3.3 Notes are copyable

Nothing in the reference mod does this. Their notes are locked (`setLockedBy("npcQuest")`) so the player can't overwrite them, spawned at fixed coordinates, and that's it.

Ours need a recipe: **pen + paper + original note → second identical note**. This is new work, no reference implementation. It's also the mechanic the whole design leans on, so it gets built early and tested hard.

Their `EditNotepadItem` (`shared/vl_quest_item_utils.lua:305`) is the right starting point for how to write text into a vanilla notepad — multi-page, `<LINE>` token expansion, locking. Extend from there.

### 3.4 Text keys, generated

Their translation key grammar is mechanical and good: `IGUI_VLQ_<qID>_NoteTitle<n>_<qStep>` and so on. Predictable enough that a tool can generate it.

So: writers write prose in Markdown, the loader emits both the quest data *and* the translation entries. Writers never see a key. This is the piece that makes the whole non-coder workflow hang together.

## 4. Bugs in the reference mod worth not repeating

From `ARCHITECTURE.md` §11 — these are free lessons.

- **Undefined-global bug** in `UpdatePlayerGMD`: a variable bound inside one branch, compared in the next. Every message falls through to the wrong handler. Cause: positional/loose arg passing with no validation. *Lesson: validate command payloads at the boundary.*
- **`Data` writes never mirrored to the server** — handler starts with `if args.qStep then`, but `Data` writes have no `qStep`. Reputation silently stays client-side in MP. *Lesson: one command shape, tested both ways.*
- **`Caldistance` defined twice**, second silently replacing the first, making an argument inert everywhere. *Lesson: no duplicate names in a flat global namespace — which is an argument for not using a flat global namespace.*
- **Quest progress unvalidated in MP.** Not a problem for a friends-only server; would be for a public one. Our server-authoritative model avoids it by construction.
- **~258 live `print()` calls.** Put logging behind a debug flag from day one.

## 5. Build order

Phases, each ending in something testable.

### Phase 0 — Repo

Create it, push `PROJECT-OVERVIEW.md`, `PROJECT-SETUP.md`, this file, and `stories/rosewood_what_ruth_knew.md`. Draft `CLAUDE.md`. Empty Build 42 mod skeleton that loads without errors and prints one line to console.

*Done when: the mod appears in the in-game mod list and enables cleanly.*

### Phase 1 — State and the loop

World ModData table. Quest registry. The polled evaluator. Two hardcoded dummy quests with a single trigger type (walk into an area) and no content.

*Done when: walking to a coordinate advances a step, and it survives a save/reload.*

### Phase 2 — Notes

Note items spawned from data, text written in, locked. The copy recipe. Corpse-loot behaviour verified — kill yourself with a note and check it's on the body.

*Done when: two players can pass a note between them, and a copy can be made and read.*

### Phase 3 — Triggers

The full vocabulary the pilot needs: enter area, acquire item, read note, deliver item to NPC. Each one generic and data-driven.

*Done when: all four fire correctly from a data file, not from bespoke code.*

### Phase 4 — NPCs

Zombie-as-NPC. Spawn on cell load with the retry fallback. Dialogue window. Cell-load dressing for the house exterior.

*Done when: Ruth exists, stands still, talks, and her house looks lived-in.*

### Phase 5 — The loader

Markdown → quest data + translation entries. Plain-language error messages. This is where `_TEMPLATE.md` and `WRITERS-GUIDE.md` get written, generated from the data shape now that it's settled.

*Done when: `rosewood_what_ruth_knew.md` loads and plays end-to-end without hand-written Lua.*

### Phase 6 — Multiplayer pass

Everything above built single-player-first, because single-player is the fast iteration loop. Now: server authority, command validation, and the test that matters — one player takes the quest, another finishes it.

*Done when: three people play Ruth's quest together and it holds.*

## 6. Sequencing note

Phases 1–5 are single-player work. That's deliberate. In single-player both client and server trees load in one process and there's no sync to debug, so the iteration loop is fast. Multiplayer correctness is designed for throughout — world-state quest data, server-authoritative writes — but only exercised in Phase 6.

The risk in this ordering is discovering an MP problem late. The mitigation is §3.1: because quest state lives in exactly one place, most of the class of bug that bites the reference mod can't occur.

## 7. Immediate next steps

1. Create the GitHub repo.
2. Push the four existing docs.
3. Draft `CLAUDE.md`.
4. Start Phase 0.
