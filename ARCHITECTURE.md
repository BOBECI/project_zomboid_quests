# Storylines — Architecture Notes

Reverse-engineered notes for Steam Workshop item `108600/3620552991` ("Storylines" by QDas),
a quest / interactive-NPC framework for Project Zomboid B42 plus the story content built on it.

All paths below are relative to the Workshop item root (the folder containing `mods/`).
Source comments are in Vietnamese; they are quoted in translation where useful.

---

## 1. Package layout

The Workshop item ships **six mods** — three generations of the same two-part design
(framework + content). Only the newest pair should be enabled.

| Mod ID | Display name | Role | Version gate |
|---|---|---|---|
| `storylinesfw` | [B42.15] StorylinesFW | **Framework** | `versionMin=42.13` |
| `storylines` | [B42.15] Storylines | **Content** — `require=\storylinesfw` | `versionMin=42.13` |
| `vlquestfw` | [B42.13] VLQuestFW | previous framework | `versionMin=42.13` |
| `vlmainquest1` | [B42.13] Main Quest 1 | previous content | `versionMin=42.13` |
| `vlquestfw_legacy_42_12` | [B42.12] VLQuestFW | legacy framework | `versionMax=42.12` |
| `vlmainquest1_legacy_42_12` | [B42.12] Main Quest 1 | legacy content | `versionMax=42.12` |

`mods/storylines/42/mod.info` and `mods/storylinesfw/42/mod.info` both declare
`incompatible=\vlquestfw,\vlmainquest1,\vlmainquest1_legacy_42_12,\vlquestfw_legacy_42_12` —
the generations share global table names and ModData keys and will collide if co-enabled.

Each mod uses the B42 versioned layout: real content lives under `<mod>/42/media/…`.
`mods/storylinesfw/media/animsets/` (outside `42/`) is a leftover duplicate of the animset XMLs.
The `<mod>/common/` directories are empty.

Rough size: framework ≈ 12.2k lines of Lua across 39 files; content ≈ 8.1k lines across 17 files.

### Framework asset directories

```
mods/storylinesfw/42/media/
├─ animsets/zombie/**        ~180 XML files — see §8 (NPCs are re-skinned zombies)
├─ scripts/vl_quest_items.txt        20 custom items (syringes, specimen jars, serums)
├─ scripts/vl_quest_recipes.txt      pack/unpack + serum recipes
├─ scripts/vl_sounds.txt             30 sound definitions
├─ textures/ ui/ sound/ models_x/ clothing/
└─ lua/{client,server,shared}/
```

---

## 2. Global namespaces

Everything is exported through a handful of bare globals, all declared with the
`X = X or {}` idiom so load order is forgiving. Consumers cache them into file-locals at the top
of each file, and `assert(VLZB, "Stack trace: Missing dependency: …")` guards catch load-order slips.

| Global | Defined in | Contents |
|---|---|---|
| `VLF` | `shared/vl_quest_utils.lua:3` | catch-all: sound, geometry, world-object edits, quest-list plumbing, `VLF.npcData`, `VLF.TalkToNPC`, `VLF.QuestUI`, `VLF.var` |
| `VLZB` | `shared/vl_quest_zombie_npc_utils.lua:6` | zombie-as-NPC layer: spawn, identify, kill, stat overrides, rifle fire |
| `VLIT` | `shared/vl_quest_item_utils.lua:4` | inventory/container search, quest-item spawning, note authoring |
| `VLPL` | `shared/vl_quest_player_utils.lua:5` | player id, area tests, line-of-sight to NPC, radio detection |
| `VLGMD` | `shared/vl_quest_globalmoddata.lua:4` | **all persistence** (see §5) |
| `VLBS` | `shared/buildingstructure/vl_buildingstructure_utils.lua:6` | procedural room/bunker construction |
| `VLINTER` | `shared/vl_quest_utils.lua:12` | dialogue button registry (see §4.4) |
| `VLOCC` / `VLOSC` | `shared/vl_quest_utils.lua:9-10` | client→server / server→client command dispatch tables (see §6.3) |
| `VLQS` | content mods | `VLQS.Q1Steps`, `VLQS.Q3Steps` — the quest step function tables (see §3) |
| `VLERS` / `VLECB` | content mods | Relief Supply / Carpet Bombing event state |

---

## 3. How quests are defined

### 3.1 The `qStep` string is the unit of everything

A quest step id looks like `q1s003` — quest 1, step 3. It is simultaneously:

* the key of the step's behaviour function (`VLQS.Q1Steps["q1s003"]`),
* the key of the NPC that belongs to that step (`VLF.npcData["q1s003"]`, `VLF.outfits.clothingSet["q1s003"]`),
* the key of the dialogue handler (`VLF.TalkToNPC["q1s003"]`),
* the key of the per-player progress record (`playerGMD.Quest.Q1["q1s003"]`),
* the key of the global NPC spawn record (`questMD.NPC["q1s003"]`, `questMD.NPCsQueueToSpawn["q1s003"]`),
* and the suffix of every translation key for that step's text.

The framework's file-header comment in
`mods/storylinesfw/42/media/lua/client/npc/vl_quest_npc_client.lua:1-19` spells out the four-step
recipe for adding an NPC, and it is exactly this key convention.

Variants exist (`q1s041_3` for a secondary NPC at the same step, `freeNPC_1234` for procedurally
generated encounter NPCs, `q3s100`–`q3s106` for Bob-and-Kate epilogue states), and code that parses
the numeric tail handles both shapes — e.g. `client/questui/vl_quest_list_ui.lua:236`:

```lua
local numStep = tonumber(string.sub(qData.qStep, -3)) or tonumber(string.match(qData.qStep, "s(%d+)_"))
```

### 3.2 A step *is* a function

Quests are not data tables; each step is a Lua closure stored in a dispatch table.
`mods/storylines/42/media/lua/client/mainquest1/vl_quest1_queststep_list.lua` holds 62 of them
(`q1s000` … `q1s061`, plus `q1s990`); `…/bobandkate/vl_bnk_queststep_list.lua` holds the Q3 set.

A minimal step registers itself in the quest UI and drops a map marker:

```lua
-- vl_quest1_queststep_list.lua:255
VLQS.Q1Steps["q1s003"] = function(player)
	local qStep, qStep_Next = "q1s003", "q1s004"
	DoQuestList_AddItem({id = 1, qStep = qStep, isDone = false, qtype = qtype, ...})
	MarkerList_Add({qStep = qStep, x = 6444, y = 5447, texture = questMarker})
end
```

A step with a completion condition tests it inline and advances itself:

```lua
-- vl_quest1_queststep_list.lua:235
VLQS.Q1Steps["q1s001"] = function(player)
	local qStep, qStep_Next = "q1s001", "q1s002"
	DoQuestList_AddItem({id = 1, qStep = qStep, ...})
	if HasDrinkInINV(player) then
		DoQuestStepActive(player, {isPopIn = true, qStep = qStep, active = "done",
		                           qStep_Next = qStep_Next, active_Next = true})
		ActiveQuestIntro_Free(getText("IGUI_VLQ_1_Desc_q1s002"), …)
	end
end
```

Because the step function is re-entered every ~20 player updates (§4.1), it must be idempotent.
Two guard mechanisms recur:

* **`localVar[…]`** — a file-local table (`vl_quest1_queststep_list.lua:29`) used as a
  *this-session-only* latch: `if not localVar["addItem5"] then … localVar["addItem5"] = true end`,
  reset to `false` when the player leaves the area. Not persisted; correct for "already spawned
  this in the currently loaded cell".
* **ModData flags** — `playerGMD_Quest_Q1[qStep].isAddedCorpses`, `.metBrother`,
  `.activeQStepEvent` — for things that must never repeat across saves.

### 3.3 Step state values

`playerGMD.Quest.Q1[qStep].active` is tri-state:

| value | meaning |
|---|---|
| `nil` / `false` | not reached |
| `true` | **active** — its function runs each tick |
| `"done"` | completed; function no longer runs |

Other per-step fields seen in the wild: `isNPC` (this step has a spawnable NPC),
`startHourWait` / `waitHourPassed` (timed gates), `collected<Name>` / `request<Name>`
(collection counters), `CreQStepMD` (one-time init flag, stored on `q1s000`).

### 3.4 Advancing a step

Two nearly identical helpers exist — the content-mod one and the framework one:

* `VLF.DoQuestStepActive(player, args)` — `mods/storylines/42/media/lua/client/mainquest1/vl_quest1_questupdate.lua:73`
* `VLF.UpdateQuestStepAndNext(player, qID, isNpcTalk, isIntroWindow, isPopIn, qStep, active, qStep_Next, active_Next)` — `mods/storylinesfw/42/media/lua/shared/vl_quest_utils.lua:834`

Both do the same five things: mark the old step, activate the next one, optionally show the
"quest updated" pop-in, optionally show the intro / NPC-talk window, and clear the map marker.
`DoQuestStepActive` additionally manages the NPC spawn queue — dropping the finished step's NPC
out of `questMD.NPCsQueueToSpawn` and enqueueing the next step's NPC when `isNPC_Next = true`.

The Bob-and-Kate line calls the framework variant with a positional signature
(`UpdateQuestStepAndNext(player, 3, false, false, true, qStep, "done", "q3s015", true)` —
`client/bobandkate/vl_bnk_talktonpcs.lua:474`); Q1/Q2 use the named-args variant.

### 3.5 Collection ("bring me N of X") steps

`SetDataForCollectQuest` (`vl_quest1_queststep_list.lua:213`) seeds
`collected<Name>` / `request<Name>` into the step's ModData, and the requested amounts live in one
table at the top of the file:

```lua
-- vl_quest1_queststep_list.lua:14
VLF.var.requestCol = { ["q1s053"] = 3000, ["q1s032"] = 2, ["q1s031"] = 1500, ["q1s016"] = 1400, … }
```

Handing items in happens in the dialogue layer (`GiveFoodsForQuest`, `GiveWaterForQuest` in
`client/mainquest1/vl_quest1_talktonpcs.lua:114` / `:158`), which converts food to hunger-points and
water to thirst-units before decrementing, then mirrors the counter to the server with
`sendClientCommand(player, "MainQuest1", "CollectQuestItemPGMD", …)`.

### 3.6 Text and translation keys

No quest prose lives in Lua. Every string is a `getText` lookup against
`<mod>/42/media/lua/shared/Translate/<LANG>/IG_UI_<LANG>.txt` (13 languages; the framework also
ships `ItemName`, `Recipes`, `Tooltip`). The key grammar is mechanical:

| Key pattern | Used for |
|---|---|
| `IGUI_VLQ_<qID>_Name` | quest title in the list and map tooltip |
| `IGUI_VLQ_<qID>_Task_<qStep>` | one-line objective |
| `IGUI_VLQ_<qID>_Desc_<qStep>` | long description / intro window body |
| `IGUI_VLQ_<qID>_NPCTalk_<qStep>` | what the NPC says on completion |
| `IGUI_VLQ_<qID>_HaloText1_<qStep>` | floating hint text |
| `IGUI_VLQ_<qID>_Notification1_<qStep>` | free-floating notice window |
| `IGUI_VLQ_InteractionBtn<N>Label_<qStep>` | dialogue button caption |
| `IGUI_VLQ_InteractionBtn<N>Talk_<qStep>` | that button's reply text |
| `IGUI_VLQ_<qID>_NoteTitle<n>_<qStep>` | in-world note title (§4.5) |
| `IGUI_VLQ_<qID>_NotePage<n>_<page>_<qStep>` | note page body |

`<LINE>` inside a string is the mod's own line-break token, expanded at display time.

---

## 4. How triggers fire

There is **no event bus**. Everything is either a polled per-tick check, a vanilla `Events.*`
hook, or a direct UI callback.

### 4.1 The main loop — polled step evaluation

`mods/storylines/42/media/lua/client/mainquest1/vl_quest1_questupdate.lua:222`

```lua
local pTick = 1
local delay = 20

local function OnPlayerUpdate_Q1(player)
    if not player or player:isDead() then return end
    if pTick % delay == 0 then
        local playerGMD_Quest_Q1 = GetPlayerGlobalModDataQ1(player, nil)
        local activeQStepTab = {}
        for qStep, data in pairs(playerGMD_Quest_Q1) do
            if data.active == true then table.insert(activeQStepTab, qStep) end
        end
        for i = 1, #activeQStepTab do
            local func = VLQS.Q1Steps[activeQStepTab[i]]
            if func then func(player) end
        end
    end
    if pTick == 1000 then pTick = 0 end
    pTick = pTick + 1
end
Events.OnPlayerUpdate.Add(OnPlayerUpdate_Q1)
```

Every 20th player update it scans the player's own ModData for steps flagged `active == true`
and calls each one's function. Multiple steps can be active at once (Q1 and Q2 interleave).
`client/bobandkate/vl_bnk_questupdate.lua:172` is the identical loop for `VLQS.Q3Steps`.

A second, independent loop (`OnPlayerUpdate_EventQ1`, `vl_quest1_questupdate.lua:253`, gated on
`p2Tick % 29`) handles world-state effects that are not tied to an active step: sealing the lab
stairwell until `q1s011`, repairing generators, clearing zombies out of the bunker, and detecting
"the player is standing in room X" transitions.

### 4.2 Trigger vocabulary

| Trigger kind | Mechanism | Example |
|---|---|---|
| Player carries an item | `HasDrinkInINV` / `VLIT.GetItemQuestInINVPlayer` inside the step fn | `q1s001`, `q1s005` |
| Player enters an area | `VLPL.IsPlayerInArea(player, x1,y1,x2,y2,z)` | `q1s006` at the Military Research Facility |
| Player can see an NPC | `VLPL.IsPlayerCanSeeNPC(player, zNPC, variable, qStep)` | `q1s041`, meeting the brother |
| Talk to an NPC | right-click context menu → `VLF.TalkToNPC[qStep]` (§4.3) | most story beats |
| Time must pass | `VLF.WaitTimePassQ1` on `Events.EveryHours` | `q1s019` waits 24 h, `q1s033` waits 168 h |
| Square streams in | `Events.LoadGridsquare` → NPC spawn (§8.2) | all fixed-position NPCs |
| Ambient world event | `Events.EveryHours` roll on the **server** | Relief Supply, Carpet Bombing (§7) |
| Per-zombie hook | `Events.OnZombieUpdate`, added/removed by area | `OnZombieUpdateq1s006` weakens 1-in-20 zombies in the MRF |
| Timed action completes | custom `ISBaseTimedAction` subclasses | blood draw, specimen take (§9) |

The timed-gate helper is worth reading in full — `vl_quest1_queststep_list.lua:159`
(`VLF.WaitTimePassQ1`) is one large `if/elseif` over every waiting step, stamping `startHourWait`
on first run and setting `waitHourPassed = true` once `getGameTime():getWorldAgeHours()` has
advanced far enough. Steps subscribe it on demand:

```lua
-- vl_quest1_queststep_list.lua:589
if not playerGMD_Quest_Q1[qStep].waitHourPassed then
    Events.EveryHours.Remove(WaitTimePassQ1)
    Events.EveryHours.Add(WaitTimePassQ1)
end
```

The `Remove`-then-`Add` pattern appears before nearly every `Events.*.Add` in the codebase; it is
the mod's defence against double registration on reload.

### 4.3 Dialogue: entry point

Talking is a context-menu option, built in
`mods/storylinesfw/42/media/lua/client/vl_addcontextmenu.lua:88` (`ContextMenu_TalkToNPC`,
hooked to `Events.OnPreFillWorldObjectContextMenu`). It scans a 2×2 square block under the cursor
for zombies, then:

```lua
local questMD = GetQuestGlobalModData(nil)
local zID = GetZombieOnlineIDorUID(zNPC)
local qStep = questMD.NPCqStep[zID]          -- reverse lookup: zombie id → quest step
local npcData = VLF.npcData[qStep]
if qStep and zNPC:getVariableBoolean(npcData.variable) then …
```

`questMD.NPCqStep[zID]` is the reverse index that makes an arbitrary zombie identifiable as
"the NPC for step q1s003". Depending on `npcData`, the menu offers:

* `needTakeCare == true` → a **Take Care** submenu: Info / Feed / Give a Drink
  (`ShowNPCInfo`, `FeedTheNPC`, `GiveADrinkForNPC` — the last one drains a real bottle's fluid,
  lowers `npcThirst` and grants +1 reputation, `vl_addcontextmenu.lua:41`).
* `infected == true` → talking triggers `NPCTurnToZombie` instead of dialogue.
* a `qStep` matching `freeNPC_` → the shared `VLF.TalkToNPC["freeNPC"]` handler.
* otherwise → `VLF.TalkToNPC[qStep]`, labelled with the NPC's stored name when present.

With `isDebugEnabled()`, the raw `qStep` string is added to the menu as a debug readout.

### 4.4 Dialogue: the interaction window

`VLF.TalkToNPC[qStep]` handlers live in the content mod (`client/mainquest1/vl_quest1_talktonpcs.lua`,
`client/bobandkate/vl_bnk_talktonpcs.lua`). A simple handler just shows narration via
`ActiveQuestIntro_Centre(getText("IGUI_VLQ_1_NPCTalk_q1s003"), 800, 500, false, "")` and advances
the step. A branching handler opens the button window instead:

```lua
VLF.QuestUI.NPCInteractionWindow(player, qStep, text, width, height, zNPC)
```

— defined at `mods/storylinesfw/42/media/lua/client/questui/vl_quest_talktonpc_interaction_ui.lua:365`.

Which buttons appear is decided by a registry, not by the window:

```lua
-- vl_quest_talktonpc_interaction_ui.lua:30
local function ActivateVisibleButtons(player, qStep)
    local buttonList = { interactionButton1 = false, … , rewardButton3 = false }
    if string.find(qStep, "freeNPC_") then
        VLINTER.SetButtons["freeNPC"](player, qStep, buttonList)   -- all free NPCs share one fn
    else
        -- walk playerGMD.Quest looking for this qStep, then call its SetButtons fn
        VLINTER.SetButtons[qStep](player, qStep, buttonList)
    end
    return buttonList
end
```

Content registers the two halves side by side. The five-way choice at Bob's bedside is the
clearest example (`client/bobandkate/vl_bnk_talktonpcs.lua:432`):

```lua
VLINTER.SetButtons["q3s013"] = function(player, qStep, buttonList)
	local playerGMD_Quest_Q3 = GetPlayerGlobalModDataQ3(player, qStep)
	if not playerGMD_Quest_Q3[qStep]["offerHelpFindMedicine"] then buttonList["interactionButton1"] = true end
	if not playerGMD_Quest_Q3[qStep]["giveKateMercy1"] then buttonList["interactionButton2"] = true
	elseif playerGMD_Quest_Q3[qStep]["giveKateMercy1"] == true then buttonList["interactionButton4"] = true end
	local antiserum = GetItemInContainerRecursive(player:getInventory(), nil, "Base.VLAntiserum")
	if antiserum then buttonList["interactionButton3"] = true end
	buttonList["interactionButton5"] = true
end

VLINTER.InteractionButton3["q3s013"] = function(player, qStep, zNPC)   -- offer Kate the antiserum
	local antiserum = GetItemInContainerRecursive(player:getInventory(), nil, "Base.VLAntiserum")
	if antiserum then
		ActiveQuestIntro_Centre(getText("IGUI_VLQ_InteractionBtn3Talk_q3s013"), 800, 500, false, "")
		UpdateQuestStepAndNext(player, 3, false, false, true, qStep, "done", "q3s015", true)
	end
end
```

So: button **visibility** is a pure function of ModData + inventory; button **effect** is a
separate function that writes ModData and/or advances the step. Captions and replies come from
`IGUI_VLQ_InteractionBtn<N>Label_<qStep>` / `…Talk_<qStep>`. `VLINTER.Rewards[qStep]` fills the
three optional reward buttons the same way.

The window itself lays buttons out bottom-up from the always-present **Confirm** button and sizes
each to its measured caption width (`vl_quest_talktonpc_interaction_ui.lua:112-140`).

### 4.5 Notes and readable documents

In-world notes are **vanilla notepad / mail items rewritten at spawn time**, not custom items.
`mods/storylinesfw/42/media/lua/shared/vl_quest_item_utils.lua:305`:

```lua
local function EditNotepadItem(item, qID, qStep, noteStep, totalPage)
	item:setName(getText("IGUI_VLQ_"..qID.."_NoteTitle"..noteStep.."_"..qStep))
	item:setCanBeWrite(true)
	item:setPageToWrite(totalPage)
	local lang = getCore():getOptionLanguageName()
	for i = 1, totalPage do
		local text = getText("IGUI_VLQ_"..qID.."_NotePage"..noteStep.."_"..i.."_"..qStep)
		text = text:gsub("<LINE>", "\n")
		if IsSpecialLanguage(lang) then                 -- CN/CH/JP/KO/TH: no spaces to wrap on
			local lines = SplitTextByLength(text, 300, UIFont.NewSmall)
			…                                           -- pre-wrap manually
		end
		item:addPage(i, text)
	end
	item:setLockedBy("npcQuest")                        -- player cannot overwrite the text
end
```

Callers spawn them positionally, tagging the item's ModData so the step can recognise it later:

```lua
-- vl_quest1_queststep_list.lua:302 (the police chief's diary)
DoSpawnItemQuestOnSquare({qStep = qStep, x = 6760, y = 5391, z = 1,
    itemFullType = "Base.GenericMail", range = 1,
    isNote = true, noteStep = 1, qID = 1, iModData = "isKeyQuest1"})
```

Three spawn entry points, all in `shared/vl_quest_item_utils.lua`:

| Function | Line | Behaviour |
|---|---|---|
| `VLIT.DoSpawnItemQuestOnSquare` | 333 | drops on the floor; first checks the square (± `range`) for an existing quest item so re-entry doesn't duplicate |
| `VLIT.AddQuestItemToContainer` | 362 | instantiates and inserts into a given container |
| `VLIT.DoSpawnItemQuestInContainer` | 394 | finds the container at x/y/z, dedupes, falls back to a floor drop when `addOnSquare = true` |

Detection of "player picked it up" is
`VLIT.GetItemQuestInINVPlayer(player, itemFullType, qStep, iModData)` (line 428), which recursively
walks the inventory and matches `iData.isQuestItem[qStep] == true and iData[iModData] == true`.
The step function polls this every tick — that is how `q1s005` and `q1s006` complete.

---

## 5. How state persists

Everything durable is PZ **ModData**, which the engine serialises with the save. There are exactly
two tables, both created in `mods/storylinesfw/42/media/lua/shared/vl_quest_globalmoddata.lua:15`.

### 5.1 `VL_Quest` — world-global

```
ModData "VL_Quest"
├─ NPC[qStep]              = { spawned, uid, zID, x, y, z, turnToZombie }   -- reset when a quest ends
├─ NPCsQueueToSpawn[qStep] = true|nil     -- "this NPC should spawn when its square loads"
├─ NPCqStep[zID]           = qStep        -- reverse index, zombie id → step
├─ Object[qStep]           = { AddedObj1, AddedEventObjects, AddedBuilding }  -- NOT reset
├─ Events["ReliefSupply"]  = { [supplyID] = {…} }
├─ Events["CarpetBombing"] = { Plan = { [bombPlanCode] = {…} } }
└─ QData                   = { DifficultyLevel }
```

Accessor: `VLGMD.GetQuestGlobalModData(qStep)` (`vl_quest_globalmoddata.lua:31`) — passing a
`qStep` also lazily creates `questMD.NPC[qStep]`.

### 5.2 `VL_Player_<pID>` — per-player

`pID` comes from `VLPL.GetPlayerID` (`shared/vl_quest_player_utils.lua:14`):
`player:getOnlineID()` in multiplayer, hard-coded **`0`** in single-player.

```
ModData "VL_Player_<pID>"
├─ Quest
│   ├─ Q1[qStep] = { active, isNPC, startHourWait, waitHourPassed,
│   │                collected<Name>, request<Name>, activeQStepEvent, metBrother, … }
│   └─ Q3[qStep] = { active, given200Hunger, giveKateMercy1, offerHelpFindMedicine, … }
├─ Data  = { ReputationPoint = 0, SPSafehouseCoords, hasQItem1_q1s006, … }
└─ Event[qStep] = { isQCreated, lastTime, … }     -- survivalist / ambient encounters
```

Accessors and mutators (all in `shared/vl_quest_globalmoddata.lua`):

| Function | Line | Writes to |
|---|---|---|
| `VLGMD.GetPlayerGlobalModData` | 42 | root; seeds `Quest`, `Data`, `Event`, `ReputationPoint = 0` |
| `VLGMD.GetPlayerGlobalModDataQ1` / `…Q3` | 67 / 168 | `Quest.Q1` / `Quest.Q3` |
| `VLGMD.SetPlayerGMD_Quest` | 99 | `Quest[questKey][qStep][key]` |
| `VLGMD.SetPlayerGMD_Q1` / `_Q3` | 116 / 180 | one step's field |
| `VLGMD.SetPlayerGMD_Data` | 125 | `Data[key]` |
| `VLGMD.SetPlayerGMD_Event` | 137 | `Event[qStep][key]` |
| `VLGMD.ClearTablePlayerGMD` | 148 | deletes a subtable |
| `VLGMD.AddReputationPoint` | 201 | `Data.ReputationPoint` |

Every setter follows the same shape — write locally, then mirror to the server *only if this is a
multiplayer client*:

```lua
playerGMD_Quest_Q1[qStep][modDataKey] = val
if isClient() then
	sendClientCommand(player, "MainQuest1", "UpdatePlayerGMD", {qStep = qStep, modDataKey = modDataKey, val = val})
end
```

### 5.3 Bootstrapping and reset

* `Events.OnInitGlobalModData` (`vl_quest_globalmoddata.lua:15`) creates the `VL_Quest` subtables
  and, on a client, calls `ModData.request("VL_Quest")` to pull the authoritative copy.
* `Events.OnCreatePlayer` → `CreateGlobalModDataPlayer` (line 59) asks the server for the player's
  own table via `sendClientCommand(player, 'NPCQuestCM', 'GetOrCreatePlayerGMD', …)`; the server
  replies with the whole table and the client copies it key-by-key
  (`client/vl_onservercommand.lua`, `VLOSC["NPCQuestCM_C"]["GetOrCreatePlayerGMD_C"]`).
* `Events.OnGameStart` → `OnStartQuestQ1` (`client/mainquest1/vl_quest1_questupdate.lua:181`)
  pre-creates an empty table for every step `q1s000`…`q1s0<VLF.var.Q1MaxStep>` (60) once, latched by
  `q1s000.CreQStepMD`, and shows the opening intro window only when
  `player:getHoursSurvived() < 12` — so joining with an established character doesn't replay the
  intro. The server mirrors this in `CreateAllQuestStepMD`
  (`storylines/…/server/mainquest1/vl_quest1_onserver.lua:53`).
* Quest-end cleanup is explicit and per-questline, e.g. `VLF.ResetData_EndQ3`
  (`shared/bobandkate/vl_bnk_utils.lua:18`) marks every still-active Q3 step `"done"` (except the
  `q3s100`–`q3s106` epilogue states) and clears every `q3s*` entry from `NPCsQueueToSpawn`.

### 5.4 What is *not* persisted

`VLF.MarkerList` (map markers), `VLF.QuestListShowOnUI` (quest window rows), `VLF.var.itemList`
(item catalogues built at `OnGameStart`), and every `localVar` / `thisSession` table are rebuilt
from ModData each session — which is why every step function re-calls `DoQuestList_AddItem` and
`MarkerList_Add` on every tick rather than once.

---

## 6. Client / server split

### 6.1 Directory contract

PZ loads `media/lua/client/**` on clients (and in single-player), `media/lua/server/**` on the
server (and in single-player), `media/lua/shared/**` everywhere. This mod respects that, with extra
in-file guards where the directory alone isn't precise enough:

* `if isServer() then return end` — `shared/npc/vl_npc_firearm.lua:7`,
  `shared/npc/vl_npc_sleeponbed.lua:6`, `shared/bobandkate/vl_bnk_utils.lua:5`
  (client-only logic that lives in `shared/` for load-order reasons)
* `if isClient() then return end` — `client/vl_claim_safehouse_singleplayer.lua:11` (SP only)
* `VLF.IsMultiplayerMode()` = `isClient() or isServer()` (`shared/vl_quest_utils.lua:157`)

### 6.2 Where each responsibility lives

| Concern | Side | File |
|---|---|---|
| Quest step evaluation, all completion logic | **client** | `storylines/…/client/mainquest1/vl_quest1_questupdate.lua` |
| Quest step definitions | **client** | `storylines/…/client/*/vl_*_queststep_list.lua` |
| Dialogue, all UI | **client** | `storylinesfw/…/client/questui/*` |
| NPC data / outfits | **client** | `storylines/…/client/*/vl_*_npcsdata.lua` |
| Per-frame NPC behaviour (idle, aim, sleep) | **client** | `client/npc/vl_quest_npc_client.lua`, `shared/npc/vl_npc_firearm.lua` |
| Deciding *when* an NPC should exist | **client** | `client/npc/vl_npc_spawn_loadgridsquare.lua` |
| Actually creating the zombie | **server** | `server/vl_quest_npc_server.lua:105` (`VLF.SpawnZombieNPCQuest`) |
| NPC liveness sweep | **server** | `server/vl_quest_npc_server.lua:57` (`EveryOneMinute_CheckNPCExist`) |
| Ambient event rolls, crate / bomb spawning | **server** | `storylines/…/server/event_*/…_s.lua` |
| Vehicle spawning | **server** | `storylines/…/server/mainquest1/vl_quest1_onserver.lua:42` |
| Item distribution, recipe callbacks | **server** | `server/items/vl_proceduraldistributions.lua`, `server/vl_quest_recipe_codeoncreate.lua` |
| ModData authority in MP | **server** | `server/vl_quest_npc_server.lua`, `…/vl_quest1_onserver.lua` |

The design is **client-authoritative for quest progress** and **server-authoritative for world
mutation**. A client decides it has finished a step, writes its own ModData, and informs the
server; the server does not validate that. Anything that must be consistent for all players
(spawning a zombie, deleting zombies in an area, dropping a supply crate, detonating a bomb) is
requested from the server instead.

### 6.3 The command bus

Two thin dispatchers turn PZ's `(module, command, args)` events into table lookups:

```lua
-- server/vl_onclientcommand.lua:7
local function OnClientCommand(module, command, player, args)
    local _module = VLOCC[module];  if not _module then return end
    local fn = _module[command];    if fn then fn(player, args) end
end
Events.OnClientCommand.Add(OnClientCommand)
```

```lua
-- client/vl_onservercommand.lua:125   -- "OnServerCommand does NOT run in single-player"
local function OnServerCommand(module, command, args)
    local _module = VLOSC[module];  if not _module then return end
    local fn = _module[command];    if fn then fn(args) end
end
```

Handlers are registered as `VLOCC["<Module>"]["<Command>"] = function(player, args)`.

**Client → server modules** (`VLOCC`):

| Module | Commands | Defined in |
|---|---|---|
| `NPCQuestCM` | `RequestSpawnNPC`, `RemoveNPC`, `RemoveNPCWhenFarAwayPlayers`, `KillNPC`, `SetDefaultZombie`, `UpdateNPCToNextQStep`, `ActiveNPCInQueueSpawnCM`, `UpdateQuestModData`, `RemoveZombiesInAreaExceptNPC`, `GetOrCreatePlayerGMD` | `server/vl_quest_npc_server.lua:325+` |
| `MainQuest1` | `UpdateQuestStep`, `UpdatePlayerGMD`, `CreAllQuestStepMD`, `CollectQuestItemPGMD`, `ClearTableInPlayerGMD`, `AddVehicleEvents` | `storylines/…/server/mainquest1/vl_quest1_onserver.lua:73+` |
| `BobAndKate` | `UpdatePlayerGMDQ3` | `storylines/…/server/bobandkate/vl_bnk_onserver.lua` |
| `FreeNPCCM` | `RequestEvents`, `UpdateFreeNPCs`, `CheckedAllFreeNPCs` | `server/npc/vl_event_survivalist_npc_s.lua:433` |
| `NPCFirearmCM` | rifle-fire arbitration | `server/npc/vl_npc_firearm_s.lua` |
| `Event_CarpetBombing` | `RequestExplode`, `RequestPlayBombEffect`, `UpdatePlayerGMDCB` | `storylines/…/server/event_carpet_bombing/…_s.lua:621` |

**Server → client modules** (`VLOSC`, suffixed `_C`): `NPCQuestCM_C`, `NPCFirearmCM_C`,
`FreeNPCCM_C`, `Event_CarpetBombing_C`, `Event_ReliefSupply_C` — mirroring spawn state, forcing
sound / animation playback, and pushing event registration to every client.

Bulk `ModData.transmit("VL_Quest")` exists (`server/vl_quest_npc_server.lua:31`) but every call
site is commented out; the mod pushes narrow `sendServerCommand` deltas instead.

### 6.4 Single-player behaviour

In single-player both `client/` and `server/` trees load in one process, `isClient()` and
`isServer()` are both false, `IsMultiplayerMode()` is false, and `pID` is `0`. Consequences the
code explicitly handles:

* `OnServerCommand` never fires, so the survivalist server code writes shared state directly
  instead of broadcasting (`server/npc/vl_event_survivalist_npc_s.lua:233`).
* `ActiveNPCInQueueSpawn` skips the "is any *other* player still on this step" scan
  (`server/vl_quest_npc_server.lua:293`).
* Safehouse claiming gets a bespoke single-player implementation
  (`client/vl_claim_safehouse_singleplayer.lua`) so events can avoid the player's base via
  `playerGMD.Data["SPSafehouseCoords"]` → `VLF.IgnoredBuildingPositions`
  (`shared/vl_quest_utils.lua:1067`).
* Free-NPC records are pruned on relogin rather than kept (`server/vl_quest_npc_server.lua:66-73`).

---

## 7. Ambient world events

Three self-contained systems, each split shared / client / server, each keyed off world age and
each announced over the radio rather than the quest log.

**Relief Supply** — `storylines/…/{shared,client,server}/event_relief_supply/`
Starts after `VLERS.requiredHoursToStartEvent = 168` (7 days). `Events.EveryHours` on the server
(`…_s.lua:301`) rolls `VLERS.TryTriggerReliefSupply()` against a world-age-scaled rule table
(`…_s.lua:22`: 1/12 chance per hour before day 30, decaying to 1/60 after a year), picks a weighted
drop area from an 11-town table (`…_s.lua:59`, Louisville weighted 4×), and registers a crate.
`Events.EveryTenMinutes` (`…_s.lua:369`) rolls for offscreen NPCs looting the crate before you
reach it. Players only learn about drops through `VLF.BroadcastAllMHz`
(`shared/vl_quest_utils.lua:875`), which injects a `RadioBroadCast` on every channel — the shared
file notes you must have a radio switched on and be awake to hear it.

**Carpet Bombing** — `storylines/…/{shared,client,server}/event_carpet_bombing/`
Starts after `VLECB.needHoursToStartCBEvent = 336` (14 days), warns on the radio, then
`bomb_DropAfterHours = 24` later a B-52 passes and bombs the marked area with
`VLECB.bombEffectRadius = 6`. The server owns the bomb plan and the explosion authority
(`RequestExplode`); clients own animation and sound (`PlaySound_B52Appeared_C`,
`RequestPlayBombEffect_C`) via `VLF.PlayAnimation` (`shared/vl_quest_utils.lua:942`) and the
`VL_Explode_Anim_512_*` item sprites.

**Survivalist encounter** — `storylinesfw/…/client/npc/event_survivalist/`,
`…/server/npc/vl_event_survivalist_npc_s.lua`
The one procedurally generated NPC. The client finds a suitable building, checks a per-player
cooldown (`playerGMD.Event["Survivalist_InHouse"].lastTime`, default 6 h) and a per-building
cooldown stored on the building's own square ModData
(`sqData.event_Survivalist_InHouse.lastActive`, 168 h), then asks the server. The server picks a
random `freeNPC_<n>` id, points it at one of four canned data rows
(`VLF.npcData["freeNPC_male" | "freeNPC_female" | "…_ghoul"]`,
`client/npc/vl_quest_npc_client.lua:41`) and broadcasts that aliasing to every client. These NPCs
have no fixed coordinates, are never added to `NPCsQueueToSpawn`, and are deliberately dropped on
relogin.

`VLF.IgnoredBuildingPositions` and `VLF.IsBuildingInIgnoredList`
(`shared/vl_quest_utils.lua:1067`, `:1097`) keep story locations and the player's safehouse out of
these events.

---

## 8. NPCs are re-skinned zombies

### 8.1 The disguise

There is no NPC entity. `VLF.SpawnZombieNPCQuest` (`server/vl_quest_npc_server.lua:105`) calls
vanilla `addZombiesInOutfit(...)` with `isInvulnerable = true`, then marks the result:

```lua
zData.isNPCQuest = true
zData.spawnPoint = getCell():getGridSquare(…)
ActiveNPCSpawnedData(x, y, z, qStep, zID, zUID)     -- writes questMD.NPC / NPCqStep
zombie:setUseless(true)
SetZombieInactiveFakeNPC(zombie)
```

The illusion rests on three things:

1. **An animation variable.** Each NPC carries one of
   `VLF.var.npcVariableList = {"npcQuestIdle", "npcQuestRifleAiming", "npcQuestSleepOnBed"}`
   (`shared/vl_quest_utils.lua:34`). The ~180 XML files under
   `mods/storylinesfw/42/media/animsets/zombie/**` add an `npcquest_*` / `npcrifle_*` / `npcsleep_*`
   variant to every zombie animation state (idle, hit reaction, falldown, staggerback, getup,
   vehicle collision, ragdoll), gated on that variable. Clearing the variable —
   `zNPC:setVariable(VLF.npcData[qStep].variable, false)` — instantly turns the NPC back into a
   normal zombie, which is exactly what `VLF.NPCTurnToZombie`
   (`client/npc/vl_quest_npc_client.lua:415`) does, complete with a voice-prefix swap and a staged
   1 s / 8 s sound sequence.
2. **Appearance data.** `VLF.npcData[qStep]` plus
   `VLF.outfits.clothingSet` / `clothingTINT` / `weaponsAttachment[qStep]`
   (`storylines/…/client/mainquest1/vl_quest1_npcsdata.lua`) drive clothing, tints, hair/beard ids,
   wound decals and attachment slots; `VLZB.SetZombieDefault` reverses it.
3. **Suppression of zombie behaviour.** `setUseless(true)`, invulnerability, stat overrides via
   `VLZB.SetNewZombieStats`, and a compatibility shim that stops the Bandits NPC mod's
   `OnZombieUpdate` from hijacking them (`client/compatible/vl_compatible_banditsnpc.lua`).
   `client/vl_ragdoll_switch.lua` temporarily disables physics hit reactions while any NPC is
   loaded and restores the player's original setting afterwards.

`VLZB.zombieStats` caches the world's real `ZombieLore.*` sandbox values at
`OnGameStart` / `OnServerStarted` (`shared/vl_quest_zombie_npc_utils.lua:25`) so per-NPC overrides
can be reverted.

### 8.2 The spawn handshake

```
client: Events.LoadGridsquare(square)                 client/npc/vl_npc_spawn_loadgridsquare.lua:87
      → GetNPCStartPointSameAsSquare(square)          match square x/y against VLF.npcData[*].startX/startY
      → questMD.NPCsQueueToSpawn[qStep] == true?      and not questMD.NPC[qStep].turnToZombie
      → CheckNPCSpawnPoint(square, qStep, range)      find a solid, free tile (searches downward through floors)
      → sendClientCommand("NPCQuestCM", "RequestSpawnNPC", {qStep, x, y, z, outfit, femaleChance, removeZRange})
server: VLOCC["NPCQuestCM"]["RequestSpawnNPC"]        server/vl_quest_npc_server.lua:339
      → guard on questMD.NPC[qStep].spawned
      → RemoveZombieFromSquares(sq, range)            clear real zombies out of the way
      → DelayFunction(SpawnZombieNPCQuest, 15)
      → sendServerCommand("NPCQuestCM_C", "ActiveNPCSpawnedData_C", …)   all clients update their index
```

If no valid tile is found within 120 ticks, the client falls back to an `OnPlayerUpdate` retry loop
that will, as a last resort, delete everything on the square and lay down a `floors_burnt_01_0`
tile to spawn on (`vl_npc_spawn_loadgridsquare.lua:130-160`).

Despawn is equally explicit — NPCs are removed when no player is within 70 tiles, when real zombies
get close, when fire is nearby, or when they are pushed off their spawn point. The server's
`EveryOneMinute_CheckNPCExist` (`server/vl_quest_npc_server.lua:57`) clears stale `spawned` records
for NPCs that drifted more than 5 tiles or no longer exist in memory.

---

## 9. UI surface

| Element | File | Hook |
|---|---|---|
| Floating quest icon (draggable, opens the log) | `client/questui/vl_quest_button_ui.lua` | `Events.OnCreatePlayer`; removed on `OnPlayerDeath` |
| Quest log window (`VLF.QuestUI.OpenQuestWindow`) | `client/questui/vl_quest_list_ui.lua` | reads `VLF.QuestListShowOnUI`; draws mod version and a difficulty badge |
| On-screen objective text | `client/questui/vl_textonscreen.lua` | `Events.OnPostUIDraw` |
| "Quest updated" pop-in (~4 s, then refreshes the log) | `client/questui/vl_quest_popup_ui.lua` | `VLF.QuestUpdatedPopIn()` |
| Narration windows — centred / free / fullscreen-with-image | `client/questui/vl_quest_introwindow_ui.lua` | `VLF.ActiveQuestIntro_Centre` / `_Free` / `_FullScreen` |
| NPC dialogue + choice buttons | `client/questui/vl_quest_talktonpc_interaction_ui.lua` | `VLF.QuestUI.NPCInteractionWindow` |
| NPC health / feeding panels | `client/questui/vl_quest_npc_health_info_ui.lua`, `vl_quest_feed_npc_ui.lua` | context menu |
| World-map quest markers | `client/questui/vl_quest_markers.lua` | overrides `ISWorldMap.render`; reads `VLF.MarkerList` |
| Reputation on the character screen | `client/vl_ischaracterscreen_reputation.lua` | wraps `ISCharacterScreen.render` |

There are **no keybindings** — the log is opened only through the floating icon.

The difficulty badge comes from `shared/vl_check_overall_difficulty.lua`, which maps the world's
`ZombieLore` sandbox settings onto a 1–5 scale each hour and stores the **minimum ever seen** in
`questMD.QData.DifficultyLevel` (line 251) — lowering difficulty mid-run permanently lowers the
badge; raising it again does not restore it.

Custom timed actions live in `shared/vl_isdoaction.lua` (generic; sets
`VLF.var.doAction[actionKey] = true` on completion) plus `vl_istakebloodsample.lua`,
`vl_istakezombiespecimen.lua` and `vl_istakeinfectednpcspecimen.lua`, all wired up from the context
menu in `client/vl_addcontextmenu.lua`.

---

## 10. Adding a new quest step — the checklist implied by the code

1. Pick the next `qStep` id and, if the questline has a max, bump `VLF.var.Q1MaxStep`
   (`shared/vl_quest_globalmoddata.lua:5`) so the step's ModData table is pre-created.
2. Add `VLQS.Q<n>Steps["<qStep>"] = function(player) … end` to the questline's
   `*_queststep_list.lua`. Call `DoQuestList_AddItem` first, `MarkerList_Add` if it has a location,
   and finish with `DoQuestStepActive` / `UpdateQuestStepAndNext`.
3. If it has an NPC: add `VLF.npcData["<qStep>"]` (plus optional `VLF.outfits.*`) in
   `*_npcsdata.lua`, and pass `isNPC_Next = true` when advancing *into* the step so it enters
   `NPCsQueueToSpawn`.
4. Add `VLF.TalkToNPC["<qStep>"]` in `*_talktonpcs.lua`; for branching dialogue also add
   `VLINTER.SetButtons["<qStep>"]` and `VLINTER.InteractionButton<N>["<qStep>"]`.
5. Add the translation keys (§3.6) to `Translate/EN/IG_UI_EN.txt` and every other language folder.
6. Any world mutation other players must see goes through a `VLOCC` command, not direct code.

---

## 11. Observations worth knowing before editing

* **`storylines/…/server/mainquest1/vl_quest1_onserver.lua:85` reads an undefined global.** In
  `VLOCC["MainQuest1"]["UpdatePlayerGMD"]` the branch tests are `if key == "waitHourPass"` /
  `elseif key == "Data"` … but `key` is only bound *inside* the first branch
  (`local qStep, key = args.qStep, args.key`). At the point of comparison `key` is a nil global, so
  every message falls through to the final `else` and is written via `SetPlayerGMD_Q1`. Multiplayer
  only — single-player never sends these (the senders are wrapped in `if isClient()`).
* **`Data` writes are never mirrored to the server.** `VLGMD.SetPlayerGMD_Data` sends
  `{key = "Data", modDataKey = …, val = …}` with no `qStep`, and the handler above begins with
  `if args and args.qStep then`. Reputation and other `Data.*` flags therefore stay client-side
  in MP.
* **`VLF.Caldistance` is defined twice** — `shared/vl_quest_utils.lua:331` (3-arg, with a
  `zDistPenalty` of +3 tiles per floor) and `:363` (2-arg). The second silently replaces the first,
  so the `zDistPenalty` argument is inert everywhere.
* **`shared/vl_quest_cached.lua` is a 0-byte file.**
* **Quest progress is unvalidated in MP** (§6.2) — worth knowing before running this on a public
  server.
* **Console noise.** ~258 live `print()` calls, plus
  `client/debug_vl_moddata_console_prints.lua`, which dumps ModData tables every 6 in-game hours.
* **`--FIXME:` markers next to constants** (`336`, `24`, `168`, `1/72`, …) are the author's
  reminders of the intended shipping values, not defects — the values beside them look correct.
* **The world-map marker override is unconditional.** `client/questui/vl_quest_markers.lua`
  replaces `ISWorldMap.render` at file scope; any other mod doing the same must load in a
  compatible order.
* **Steps above `VLF.var.Q1MaxStep`** (`q1s061`, `q1s990`) are not pre-created by the bootstrap
  loop; they rely on `GetPlayerGlobalModDataQ1(player, qStep)` creating their table on first access.
