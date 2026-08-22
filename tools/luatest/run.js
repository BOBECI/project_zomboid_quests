/*
 * run.js -- runs the mod's Lua against stubbed Project Zomboid globals.
 *
 * Two passes:
 *   1. every .lua file is parsed as Lua 5.1 (what PZ's Kahlua accepts)
 *   2. the whole mod is executed inside a Lua VM against lua/stubs.lua, and the
 *      scenario files assert on what it did
 *
 * See README.md for what this can and cannot tell you.
 */

const fs = require('fs');
const path = require('path');
const luaparse = require('luaparse');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');

const REPO = path.resolve(__dirname, '..', '..');
const MOD_LUA = path.join(REPO, 'mod', 'knoxstories', '42', 'media', 'lua');
const LUA_DIR = path.join(__dirname, 'lua');

// Scenarios run in order and share one Lua state, because the reload tests need
// to carry a ModData store across a wipe of the mod's globals.
const SCENARIOS = [
  { file: 'scenario_quests.lua', banner: 'SCENARIO 1: fresh world' },
  { file: 'scenario_reload.lua', banner: 'QUIT AND RELOAD (globals wiped, ModData kept)', reload: true },
  { file: 'scenario_newquest.lua', banner: 'RELOAD AGAIN, WITH A NEW QUEST ADDED', reload: true },
  { file: 'scenario_notes.lua', banner: 'RELOAD AGAIN: NOTES AND THE COPY RECIPE', reload: true },
  { file: 'scenario_triggers.lua', banner: 'RELOAD AGAIN: THE FOUR TRIGGER TYPES', reload: true },
];

function findLuaFiles(dir) {
  const out = [];
  (function walk(d) {
    for (const entry of fs.readdirSync(d, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const p = path.join(d, entry.name);
      if (entry.isDirectory()) walk(p);
      else if (entry.name.endsWith('.lua')) out.push(p);
    }
  })(dir);
  return out.sort();
}

const modFiles = findLuaFiles(MOD_LUA);

// ---------------------------------------------------------------------------
// Pass 1: syntax
// ---------------------------------------------------------------------------

console.log('=== SYNTAX (Lua 5.1) ===');
let syntaxErrors = 0;
for (const file of modFiles) {
  const rel = path.relative(MOD_LUA, file).replace(/\\/g, '/');
  try {
    luaparse.parse(fs.readFileSync(file, 'utf8'), { luaVersion: '5.1', comments: false });
    console.log('  OK   ' + rel);
  } catch (err) {
    syntaxErrors++;
    console.log('  FAIL ' + rel + '  -> ' + err.message);
  }
}
if (syntaxErrors) {
  console.error(`\n${syntaxErrors} syntax error(s); not running the scenarios.`);
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Pass 2: behaviour
// ---------------------------------------------------------------------------

// Files are loaded in plain alphabetical order rather than PZ's
// shared/client/server order. That is deliberately harsher than the real thing:
// if anything here depended on load order, this would break first.
//
// Each file becomes its own do..end block, which reproduces the file-local
// scoping PZ gives each chunk.
const modSource = modFiles
  .map((f) => `do\n${fs.readFileSync(f, 'utf8')}\nend\n`)
  .join('\n');

// Wipes the mod's globals and every registered event handler, keeping only the
// ModData store -- what survives a quit to the main menu.
const RELOAD = `
    local keep = ModData._store
    KnoxStories = nil
    ModData = { _store = keep }
    function ModData.getOrCreate(key)
        ModData._store[key] = ModData._store[key] or {}
        return ModData._store[key]
    end
    -- A game restart also restores any vanilla function the mod wrapped.
    ISInventoryPaneContextMenu.onWriteSomething =
        ISInventoryPaneContextMenu._vanillaOnWriteSomething
    ISInventoryPaneContextMenu.opened = {}
    for _, name in ipairs({ "OnGameStart", "OnPlayerUpdate", "OnInitGlobalModData",
                            "OnFillInventoryObjectContextMenu", "OnFillWorldObjectContextMenu" }) do
        Events[name].handlers = {}
    end
`;

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

function run(label, src) {
  if (lauxlib.luaL_dostring(L, to_luastring(src)) !== lua.LUA_OK) {
    console.error(`\n!! ${label} errored: ${lua.lua_tojsstring(L, -1)}`);
    process.exit(1);
  }
}

const readLua = (name) => fs.readFileSync(path.join(LUA_DIR, name), 'utf8');

run('stubs', readLua('stubs.lua'));
run('mod', modSource);

for (const scenario of SCENARIOS) {
  if (scenario.reload) {
    run('reload', RELOAD);
    run('mod', modSource);
  }
  console.log(`\n=== ${scenario.banner} ===`);
  run(scenario.file, readLua(scenario.file));
}

run('exit', 'if FAILURES ~= 0 then error("failures: " .. FAILURES, 0) end');
