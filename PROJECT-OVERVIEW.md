# Project Zomboid — Co-op Storyline Mod

**Project overview · v0.2 · Build 42**

> Supersedes the v0.1 design brief. The protagonist model changed: it is no longer host-driven.

---

## 1. What this is

A storyline mod for Project Zomboid built for multiplayer, where **the group is collectively the protagonist**.

There is no chosen one and no designated main character. Quests belong to the world, not to a player. Whoever finds an NPC unlocks that quest, and from that point it becomes something the group can carry forward — anyone can advance it, anyone can finish it.

## 2. Why it doesn't exist yet

Almost every existing PZ story mod is single-player. The reason is structural: narrative assumes one protagonist making choices, and the moment you add four players you inherit the branching-narrative problem — whose decision counts, whose save holds the state, what happens to players who weren't there.

Most co-op games dodge this by making the host canonical (Dying Light does this). We considered that approach and rejected it. Zomboid is a game about a group surviving, not about a hero. Tying the story to one player fights the game's own premise.

**Our answer:** make quest state *world state*. It lives on the server, not on a character. This removes the branching problem entirely and fits the game's fiction.

## 3. The core mechanic — quest info as physical items

This is the idea the whole design hangs on.

Quest information is **not** a UI element. It's an object in the world: a note, a letter, an envelope, a scrawled page. You pick it up, it goes in your bag, and it is the thing that lets you act on the quest.

Consequences that fall out of this, all of them good:

- **Sharing is an action.** Handing a friend the letter is how they get the objective. No menu toggle, no party sync.
- **Catching up is diegetic.** A player who joins mid-quest doesn't get a recap screen. They read the note on the wall, or the letter in the NPC's house, and now they know what's going on.
- **Losing it hurts.** Die with the only copy in your bag and the intel is on your corpse. Getting the quest back means a recovery run through whatever killed you.
- **Redundancy is a real decision.** Using pen + paper + the original, you can hand-copy the note into a duplicate. Do we spend the time copying before we head out, or risk carrying the only copy? That's a genuine trade-off, and it's built from items already in the base game.

No magic reset, no quest-log fallback. The information is a survivable object like everything else in Zomboid.

## 4. Content structure — quest hubs

Not one long linear campaign. Instead, small authored story pockets scattered across the map, each 3–4 beats long, each with its own NPC and location. Players stumble into them while looting.

This scales well in co-op — different people can be pulling on different threads at once — and it lets us build and test one hub at a time.

**Pool size:** current lean is a curated set of roughly 60–80 quests, all present in every world, rather than a 1000-quest pool that draws 50 at random. Reasoning: nobody experiences the pool, they experience their own fifty. A curated set lets us place quests deliberately — this one belongs in Rosewood, that one only makes sense near the prison. Location-authored content feels far more alive than shuffled content. The big-pool approach only earns its cost if replayability is the headline feature.

**On generated content:** templates work fine for quest *structure* (fetch, escort, clear, deliver). They do not work for voice — at volume, generated quest text goes samey and players notice fast. Plan is roughly 30 hand-written quests as the memorable backbone, with generation filling the long tail.

## 5. Technical model

### Cell loading does most of the work for us

Zomboid streams the world in cells around the player. Cells outside that range are unloaded and **not simulated at all**. This is enormously convenient:

- An NPC's house is **dressed when its cell first loads** — barricades, broken furniture, corpses outside, empty tins. The player never sees it happen, they only find the result.
- This means we don't need to protect the house from zombie spawns. A pristine untouched building in an apocalypse reads as "game mechanic." Letting the world chew on it normally and then dressing it makes the NPC's survival look *earned*.
- Walk away and the cell freezes. The NPC doesn't die off-screen, zombies don't path in. Come back three days later and it's exactly as you left it.
- Fifty NPCs scattered across Knox County cost essentially nothing in performance.

Quest progress is stored in the mod's own save data, so it persists regardless of who is nearby.

### Components

| Component | Responsibility |
|---|---|
| Quest state manager | Server-side world state; no player ownership |
| Event / trigger system | Location, item, kill, and read triggers |
| Item-borne intel | Note/letter items, the copy recipe, corpse-loot behaviour |
| Client display layer | Story text, popups, radio broadcasts |
| Save hook | Persistence across sessions |
| Cell-load dresser | Builds out the NPC location on first load |

The plan is to get this skeleton working end-to-end with dummy content first. Writing slots into a proven framework afterwards.

## 6. Phase 1 — Rosewood pilot

- **Three small quests**, all in Rosewood.
- Rosewood chosen because it's compact and walkable, and the fire station and prison give natural landmarks to hang quests on.
- Played with a small group of friends to find bugs and dead ends.
- The real question this answers: is it *fun*, and is it *actually buildable*?

## 7. Distribution

No Workshop upload needed. The mod runs from the local `mods` folder and is enabled at world creation. For multiplayer everyone just needs the files — zipping the folder and sharing it is fine for a test group. Workshop only becomes necessary for public release and automatic updates.

## 8. Reference material

- PZwiki — Lua API and LuaDocs pages
- `gotmayonase/pz-modding-guide` (GitHub) — practical ground-up Build 42 guide
- `JBD-Mods/awesome-project-zomboid-build42-resources` — tooling and resource index
- Unofficial JavaDocs (Build 42) — for the underlying Java classes
- **Fastest way to learn:** Workshop mods download as unencrypted folders. The Lua of any existing single-player story mod can be read directly.

## 9. Open questions

1. **Should NPCs be killable?** Killing one and looting the house is a legitimate alternative path — but it removes content. Undecided; revisit during build.
2. **Does a shared journal exist alongside the item-borne intel, or is the item enough?** Leaning toward item-only for purity, but it may be unfriendly.
3. **What happens if every copy of a note is destroyed?** Currently: the quest is dead. Acceptable, or should the NPC be able to rewrite it?
4. **Which three quest types for the Rosewood pilot?** Ideally three structurally different ones, to test the trigger system broadly.
5. **Pool size — final call.** 60–80 curated, or the large randomised pool?
