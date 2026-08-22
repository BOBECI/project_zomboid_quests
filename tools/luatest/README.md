# luatest

Runs the mod's Lua outside Project Zomboid, against stubbed game globals.

```bash
cd tools/luatest
npm install     # once
npm test
```

Exit code is non-zero if anything fails, so it drops straight into CI later.

## What it does

Two passes:

1. **Syntax.** Every `.lua` file under `mod/knoxstories/42/media/lua` is parsed as
   Lua 5.1, which is what PZ's Kahlua interpreter accepts.
2. **Behaviour.** The whole mod is executed inside a real Lua VM
   ([fengari](https://github.com/fengari-lua/fengari)) against `lua/stubs.lua`,
   and the scenario files assert on what it did.

Files are loaded in plain alphabetical order — `client/` before `server/` before
`shared/` — which is *harsher* than PZ's real shared-then-client-then-server
order. If any file grows a load-order dependency, this breaks first.

Scenarios share one Lua state and run in order, because the reload tests need to
carry a ModData store across a wipe of the mod's globals:

| Scenario | Covers |
|---|---|
| `scenario_quests.lua` | registry validation, the polled evaluator, quest steps advancing, notes handed over by a step, the command boundary rejecting bad and stale payloads |
| `scenario_reload.lua` | progress surviving a quit and reload, the loop still running afterwards |
| `scenario_newquest.lua` | a quest added to the mod after players already have a save |
| `scenario_notes.lua` | note validation, writing text onto a vanilla item, locking, the copy recipe, the context menu, the timed action |

## What it cannot tell you

**`lua/stubs.lua` is a model of the PZ API, not the API.** It was written from
documented behaviour and from how the reference mod uses these calls. It will
catch logic errors — a step advancing when it should not, paper consumed by a
failed copy, a missing validation — and it will not catch a game function that
behaves differently from the model.

Specifically unverifiable here:

- whether `setLockedBy` really prevents overwriting, and still allows reading
- whether `instanceItem`, `addPage`, `setPageToWrite` behave as modelled
- whether `ModData.getOrCreate` data really persists across a save
- anything about coordinates, rendering, timing, or multiplayer

Those need the game. Treat a green run as "the logic is consistent", not as
"this works".

### Item names

`KNOWN_ITEMS` in `lua/stubs.lua` mirrors the real item names in
`media/scripts/generated/items/` from a B42 install, and `scenario_quests.lua`
asserts that every type the mod names appears in it. That catches a typo'd or
invented item name — which is worth having, because `Base.SheetPaper` looked
entirely reasonable and does not exist.

It is a hand-maintained mirror, so it goes stale if the game's items change.
When adding a note on a new base item, check the real scripts and add the name
here in the same commit.

## Adding a scenario

Drop a `scenario_*.lua` in `lua/` and add it to `SCENARIOS` in `run.js`. Use the
global `CHECK(label, condition, detail)` — `detail` is printed on failure and is
usually the actual value. Set `reload: true` if it should start from a fresh
load of the mod.
