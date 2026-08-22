# Project state — handover

**As of v0.7.3, branch `quest-engine-phases-0-4`.** Written to pick the project
up on another machine.

---

## Where the work is

```
mod/knoxstories/          the mod itself (28 Lua files, 113 animset XMLs x2)
tools/luatest/            runs the mod's Lua outside the game (333 checks)
docs/                     testing docs, findings, this file
```

The branch is pushed. The PR was never opened —
`gh` is not installed on the machine this was built on. Create it from:

<https://github.com/BOBECI/project_zomboid_quests/pull/new/quest-engine-phases-0-4>

The body is written and ready in the session scratchpad, or rewrite it from the
commit messages; they are detailed on purpose.

---

## Setting up on a new machine

1. **Clone, then install the test harness.**

   ```bash
   cd tools/luatest && npm install && npm test
   ```

   Expect `ALL CHECKS PASSED` and 333 passes. If that works, the engine logic is
   intact regardless of anything else.

2. **Install the mod.** Copy `mod/knoxstories` into `<user>/Zomboid/mods/`.

   On the previous machine this was a real directory copy, so it needed
   re-copying after every change. A junction is less error-prone:

   ```
   mklink /J "%USERPROFILE%\Zomboid\mods\knoxstories" "<repo>\mod\knoxstories"
   ```

   **Copy the whole folder.** There is a top-level `mod/knoxstories/media/`
   as well as `mod/knoxstories/42/media/` — a Lua-only copy misses the animsets.

3. **Nothing depends on the Steam path at runtime.** Several investigations read
   the game install directly (item names, API shapes, the reference mod). Those
   paths are machine-specific and appear only in commit messages, not in code.
   The install moved from `D:\SteamLibrary` to `C:\Program Files (x86)\Steam`
   mid-project and nothing in the repo broke.

4. **The reference mod** is Steam Workshop item `3620552991` (Storylines by
   QDas), under `steamapps/workshop/content/108600/`. Worth subscribing to on
   the new machine — it is the only working example of the NPC technique, and
   the open bug below may need it again.

---

## Phase status

| Phase | State |
|---|---|
| 0 — Repo and skeleton | Done, confirmed in game |
| 1 — World state and the polled loop | Done, confirmed in game |
| 2 — Notes, copying, corpse loot | Done, confirmed in game |
| 3 — The four trigger types | Done, confirmed in game |
| 4a — Dressing recorder, coordinate readout, conditional examine | Done, confirmed in game after one fix round |
| 4b — Zombie-as-NPC, spawn, dialogue | Working except one bug — see below |
| 5 — The Markdown loader | Not started. **Unblocked**, and the thing the writers are waiting on |
| 6 — Multiplayer pass | Not started |

---

## THE OPEN PROBLEM

**Diane is correct on the first visit to her house and a plain zombie on every
visit after the cell has unloaded and reloaded.**

She is a zombie in the sense that matters: she shambles, and she looks like one.
On a second visit there is no figure standing still in the house.

### What is known to be true

- **The first visit works.** This is the most important fact and it was
  established late. It means the 113 lifted animation XMLs load correctly, the
  rename into our namespace is fine, the variable name is fine, and shipping
  them in both `media/animsets` and `42/media/animsets` is fine. Several rounds
  of investigation into the animsets were chasing something that was never
  broken.
- **She is created on the second visit.** The engine logs
  `Spawning new Female Zed, Dressed in DressLong` and the mod logs
  `npc 'diane' (Diane) spawned at 8003,11743,0`.
- **The disguise reads back correct at spawn**, every field:
  `skin=FemaleBody01 animVar=true canWalk=false useless=true invuln=true voice=`
  — read off the object, not assumed from the setters having been called.
- **The maintenance never logged anything on the second visit.** On the first
  visit it logs `dressing 'diane' -- before: ...` followed by a dozen
  `after dressing` lines. On the second, nothing.

### What has been ruled out

- Item names, outfit, and spawn tile — all verified from the game's own files.
- The animsets not loading — disproved by the first visit working.
- `OnZombieUpdate` not existing — it does, and it fires (the first visit's log
  proves it).
- A stale mod copy — the installed copy was verified current at each step.
- `resetModelNextFrame` being skipped — fixed in v0.6.6; the skin now reads back
  as `FemaleBody01`.
- The disguise being applied once and overwritten — the re-assertion runs and
  the values hold.

### The most recent theory, and the fix that did not resolve it

`spawnNPC` was writing the world record by hand rather than calling
`recordSpawned`, so the **live reference the maintenance sweep works from was
never stored on a normal spawn**. The sweep therefore had nothing to maintain.
The first visit survived only because `OnZombieUpdate` happened to see her and
register her itself.

Fixed in v0.7.2. It did not resolve the symptom, so either the sweep is still
not seeing her, or something else undresses her after the sweep dresses her.

### What v0.7.3 adds, and what to do next

Nothing was fixed in v0.7.3. It adds a **heartbeat**, because the failure mode
in this investigation has repeatedly been silence, and absent log lines were
twice misread as "nothing to see".

Every five seconds the sweep now says one of four things, and they are four
different bugs:

| Heartbeat line | Meaning |
|---|---|
| `sweep: maintaining diane=true` | She is dressed and the sweep sees her — the fault is elsewhere, most likely rendering |
| `sweep: maintaining diane=false` | The sweep sees her and the disguise will not hold — something is undressing her |
| `sweep: running, but holding nobody` | The sweep runs but the reference was lost — look at `KS.NPCServer.live` and `forgetUnloadedNPCs` |
| *no line at all* | The sweep is not running — `OnPlayerUpdate` handler missing, or `KS_NPCMaintain` failed to load |

**Next session: walk in, walk away until the cell unloads, come back, and read
the `[KnoxStories]` lines.** The two that matter are the second
`npc 'diane' ... spawned at ... -- skin=...` line and any `sweep:` lines after
it. Between them they say whether she was dressed at spawn and whether anything
kept her dressed.

### An experiment still on the table

`KS_DummyNPCs.lua` has a commented-out `animVariable = "npcQuestIdle"`. With
StorylinesFW enabled, that borrows the reference mod's own animation variable.
It was written before the first-visit-works fact was known, so it is less
urgent now, but it still cleanly separates "our files" from "our code" if the
heartbeat points back that way.

---

## Other things worth knowing

**The debug flag ships on.** `KnoxStories.DEBUG` is `true` in `KS_Core.lua`. It
drives the coordinate readout, the debug context menu, position logging and all
the diagnostics above. **It must go false before any real playtest**, and
certainly before anything is shared with the writers.

**Diane's coordinates are a guess.** `8003, 11743` came from the filename of the
dressing recording, which is where the player was standing when recording
started. She has never been moved. Fix with the coordinate readout.

**A recorded dressing file is committed.** `KnoxStories_house_8003_11743.lua`
under `dressing/` was a test artifact that got swept into a commit. It dresses a
real Rosewood house in every world. Probably wants deleting; it was left in
because it is real data and the call is not mine.

**Two unexplained file losses.** Twice, files vanished from the working tree
minutes after being written — six Phase 1 files once, and everything from the
Phase 4b commit the second time. Both were recovered (the second exactly, from
git). No antivirus detection, no Controlled Folder Access, Desktop not
OneDrive-redirected. A third apparent loss turned out to be the Steam library
moving and was not the same thing. **Commit often** until it is understood, or
confirmed not to happen on the new machine.

**The animsets are derived from the Storylines Workshop item**, as BUILD-PLAN §2
sanctions. Fine for a friends-only build; worth checking that item's terms
before any public release.

**Line endings.** Git converts LF to CRLF on checkout here. It has caused no
problems, but if the animation bug ever points back at file contents, the XMLs
are worth checking byte-for-byte against the originals — that is the one thing
about our copies never verified.

---

## Known gaps, by phase

- **Dressing recorder** does not capture items placed *inside* containers —
  surfaces and floors only.
- **Diane's dialogue** is three fixed lines that never change with quest state.
  Branching belongs in Phase 5.
- **No exchange window.** `deliver_item` takes the item when you stand near her.
- **Nothing turns an NPC back into a zombie.** The hook exists — clear the
  animation variable — but no quest uses it.
- **Multiplayer is designed for but never exercised.** Seams are marked in
  comments; Phase 6 is where they get tested.
