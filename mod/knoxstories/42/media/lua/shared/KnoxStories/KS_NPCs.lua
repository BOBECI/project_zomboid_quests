--[[
    KS_NPCs.lua

    The NPC registry. There is no NPC entity in Project Zomboid, so an NPC is a
    zombie wearing a disguise (architecture 8.1). This file holds who they are;
    the spawning is in client/KS_NPCSpawn.lua and server/KS_NPCServer.lua.

    THE DISGUISE, IN THREE PARTS

    1. An animation variable. media/animsets/zombie/** carries 113 XML nodes
       lifted from the reference mod and renamed into our namespace: each one
       swaps a zombie animation for the human equivalent (Bob_Idle rather than
       the shamble), gated on the BOOL 'knoxNpcIdle'. Setting that variable on a
       zombie makes it stand like a person; clearing it turns it straight back
       into a zombie, which is a hook Phase 5 may want.
    2. Suppressed behaviour -- setCanWalk(false), invulnerable, no teeth, no
       voice. See KS_NPCServer.
    3. Appearance, from the outfit named here.

    Definition shape:

        {
            id       = "diane",
            name     = "Diane",             shown on the talk option and window
            x, y, z  = ,                    where she stands
            outfit   = "Naked",             a vanilla outfit name
            female   = true,
            dialogue = { "line", "line" },  one page per entry
        }

    Phase 5's loader emits this from Markdown; dialogue becomes generated
    translation keys at that point rather than raw strings.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

KS.NPCDefs = KS.NPCDefs or {}
KS.NPCs = KS.NPCs or {}

-- Written into the zombie's ModData so an NPC can be recognised again later.
local MODDATA_KEY = "knoxStoriesNPC"

-- The BOOL the lifted animation nodes are gated on.
KS.NPCs.ANIM_VARIABLE = "knoxNpcIdle"

local index = nil
local validated = false
local validCount, invalidCount = 0, 0

--------------------------------------------------------------------------------
-- Validation
--------------------------------------------------------------------------------

local function invalidate(def, reason)
    def.invalid = true
    KS.warn("npc '" .. tostring(def.id or "<no id>") .. "' was skipped: " .. reason)
end

local function validateNPC(def, seenIds)
    if type(def.id) ~= "string" or def.id == "" then
        invalidate(def, "it has no id")
        return
    end
    if seenIds[def.id] then
        invalidate(def, "another npc already uses the id '" .. def.id .. "'")
        return
    end
    seenIds[def.id] = true

    if type(def.name) ~= "string" or def.name == "" then
        invalidate(def, "it has no name")
        return
    end

    if type(def.x) ~= "number" or type(def.y) ~= "number" then
        invalidate(def, "it does not say where they stand (x and y)")
        return
    end

    if def.z == nil then
        def.z = 0
    elseif type(def.z) ~= "number" then
        invalidate(def, "'z' must be a number (0 is ground level)")
        return
    end

    def.outfit = def.outfit or "Naked"
    def.female = def.female == true

    if type(def.dialogue) ~= "table" or #def.dialogue == 0 then
        invalidate(def, "it has nothing to say (dialogue is empty)")
        return
    end

    for i = 1, #def.dialogue do
        if type(def.dialogue[i]) ~= "string" then
            invalidate(def, "dialogue line " .. i .. " is not text")
            return
        end
    end

    def.invalid = false
end

function KS.NPCs.ensureValidated()
    if validated then
        return validCount, invalidCount
    end
    validated = true

    local seenIds = {}
    validCount = 0
    index = {}

    for i = 1, #KS.NPCDefs do
        local def = KS.NPCDefs[i]
        validateNPC(def, seenIds)
        if not def.invalid then
            validCount = validCount + 1
            index[def.id] = def
        end
    end

    invalidCount = #KS.NPCDefs - validCount
    return validCount, invalidCount
end

function KS.NPCs.all()
    KS.NPCs.ensureValidated()
    return KS.NPCDefs
end

function KS.NPCs.get(npcId)
    KS.NPCs.ensureValidated()
    return index[npcId]
end

-- Which NPC, if any, is meant to stand on this tile? Matched on x and y only,
-- because LoadGridsquare fires per floor and we want the NPC considered whatever
-- floor the square belongs to.
function KS.NPCs.atTile(x, y)
    local defs = KS.NPCs.all()

    for i = 1, #defs do
        local def = defs[i]
        if not def.invalid and def.x == x and def.y == y then
            return def
        end
    end

    return nil
end

--------------------------------------------------------------------------------
-- Recognising one in the world
--------------------------------------------------------------------------------

function KS.NPCs.idOf(zombie)
    if not zombie then
        return nil
    end

    local modData = zombie:getModData()
    if not modData then
        return nil
    end

    local id = modData[MODDATA_KEY]
    if type(id) == "string" and id ~= "" then
        return id
    end

    return nil
end

function KS.NPCs.markAs(zombie, npcId)
    zombie:getModData()[MODDATA_KEY] = npcId
end

function KS.NPCs.defOf(zombie)
    local id = KS.NPCs.idOf(zombie)
    return id and KS.NPCs.get(id) or nil
end

--------------------------------------------------------------------------------
-- Wearing the disguise
--
-- This is shared, not server-only, because it has to be applied in two places:
-- once when the NPC is created, and again every time the game hands us back a
-- zombie that is already tagged as one of ours.
--
-- The second case is the important one and it is not obvious. Only ModData
-- survives a save: setCanWalk, setInvulnerable, the animation variable and the
-- voice prefix are all runtime state on the zombie object. A zombie persists in
-- its chunk, so after a reload Diane comes back still carrying her id and
-- wearing her dress, with none of the behaviour that made her a person. She was
-- a plain zombie in a long dress.
--
-- So applying the disguise has to be idempotent and cheap to repeat, and
-- something has to notice when it has lapsed. See client/KS_NPCMaintain.lua.
--------------------------------------------------------------------------------

-- Blood shows through even on an invulnerable NPC: being struck marks the
-- clothing and the body whether or not damage lands. A woman standing calmly in
-- her kitchen covered in blood spatter reads as a zombie no matter how still she
-- is, so it gets wiped.
function KS.NPCs.cleanBlood(zombie)
    if not BloodBodyPartType then
        return
    end

    local visuals = {}

    local humanVisual = zombie:getHumanVisual()
    if humanVisual then
        table.insert(visuals, humanVisual)
    end

    -- Worn clothing carries its own blood, separately from the body.
    local worn = zombie:getWornItems()
    if worn then
        for i = 0, worn:size() - 1 do
            local entry = worn:get(i)
            local item = entry and entry:getItem()
            local itemVisual = item and item:getVisual()
            if itemVisual then
                table.insert(visuals, itemVisual)
            end
        end
    end

    for i = 1, #visuals do
        local visual = visuals[i]
        for part = 1, BloodBodyPartType.MAX:index() do
            local bodyPart = BloodBodyPartType.FromIndex(part - 1)
            visual:setBlood(bodyPart, 0)
            visual:setDirt(bodyPart, 0)
        end
    end

    zombie:resetModelNextFrame()
end

-- The face.
--
-- addZombiesInOutfit hands back a zombie, and a zombie's skin texture is a
-- zombie's skin texture -- F_ZedBody01_level1 and friends. No amount of
-- behaviour suppression changes what she looks like. The reference mod
-- overwrites it with a human body texture and so must we, or she stands
-- perfectly still, silently, with a corpse's face.
local function applyHumanSkin(zombie, def)
    local visual = zombie:getHumanVisual()
    if not visual then
        return
    end

    local body = def.female and "FemaleBody0" or "MaleBody0"
    visual:setSkinTextureName(body .. tostring(def.skinTexture or 1))
end

function KS.NPCs.applyDisguise(zombie, def)
    applyHumanSkin(zombie, def)

    zombie:setCanWalk(false)
    zombie:setUseless(true)
    zombie:setInvulnerable(true)
    zombie:setNoTeeth(true)

    -- The lifted animation nodes are gated on this. Without it the model plays
    -- the zombie shamble no matter what else is set.
    zombie:setVariable(KS.NPCs.ANIM_VARIABLE, true)

    local descriptor = zombie:getDescriptor()
    if descriptor then
        descriptor:setVoicePrefix("")
    end

    local emitter = zombie:getEmitter()
    if emitter then
        emitter:stopAll()
    end

    zombie:clearAttachedItems()
    zombie:resetEquippedHandsModels()

    KS.NPCs.cleanBlood(zombie)
    KS.NPCs.markAs(zombie, def.id)
end
