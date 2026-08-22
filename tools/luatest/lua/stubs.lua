--[[
    stubs.lua

    Stand-ins for the Project Zomboid globals the mod touches.

    These are a MODEL of the PZ API, written from its documented behaviour, not
    the real thing. They are good enough to catch logic errors -- wrong state
    transitions, missing validation, items consumed on a failed copy -- and they
    cannot catch an API that behaves differently from what is modelled here.
    Anything that depends on how the engine really behaves still has to be tested
    in game.
]]

_G.LOG = {}
local realprint = print
function print(s)
    table.insert(_G.LOG, tostring(s))
    realprint(tostring(s))
end

function isServer() return false end
function isClient() return false end

--------------------------------------------------------------------------------
-- ModData
--------------------------------------------------------------------------------

ModData = ModData or { _store = {} }
function ModData.getOrCreate(key)
    ModData._store[key] = ModData._store[key] or {}
    return ModData._store[key]
end

--------------------------------------------------------------------------------
-- A Java-ish ArrayList, because ItemContainer:getItems() returns one and it is
-- zero-indexed with size()/get(), not a Lua array.
--------------------------------------------------------------------------------

local ArrayList = {}
ArrayList.__index = ArrayList

function ArrayList.new()
    return setmetatable({ _n = 0, _v = {} }, ArrayList)
end
function ArrayList:size() return self._n end
function ArrayList:get(i) return self._v[i] end
function ArrayList:add(v)
    self._v[self._n] = v
    self._n = self._n + 1
end
function ArrayList:remove(v)
    local out, n = {}, 0
    for i = 0, self._n - 1 do
        if self._v[i] ~= v then
            out[n] = self._v[i]
            n = n + 1
        end
    end
    self._v, self._n = out, n
end

--------------------------------------------------------------------------------
-- InventoryItem
--------------------------------------------------------------------------------

local Item = {}
Item.__index = Item

function Item.new(fullType)
    return setmetatable({
        _fullType = fullType,
        _name = fullType,
        _pages = {},
        _modData = {},
        -- No vanilla writing implement is drainable: Pen and Pencil are
        -- base:weapon with a condition, not a use delta. Tests that want the
        -- drainable path set _drainable on the instance.
        _drainable = false,
        _uses = 1.0,
    }, Item)
end

function Item:getFullType() return self._fullType end
function Item:getName() return self._name end
function Item:setName(n) self._name = n end
function Item:setCustomName(b) self._customName = b end
function Item:setCanBeWrite(b) self._canBeWrite = b end
function Item:setPageToWrite(n) self._pageToWrite = n end
function Item:addPage(i, text) self._pages[i] = text end
function Item:getPage(i) return self._pages[i] end
function Item:getNumberOfPages()
    local n = 0
    for _ in pairs(self._pages) do n = n + 1 end
    return n
end
function Item:setLockedBy(s) self._lockedBy = s end
function Item:getLockedBy() return self._lockedBy end
function Item:getModData() return self._modData end
function Item:IsInventoryContainer() return self._inventory ~= nil end
function Item:getInventory() return self._inventory end
function Item:getContainer() return self._container end
function Item:IsDrainable() return self._drainable == true end
function Item:Use() self._uses = self._uses - 0.1 end
function Item:getUsedDelta() return self._uses end

-- Item names verified against media/scripts/generated/items/ in the B42 install.
-- Keep this in sync with the game, not with what the mod happens to ask for:
-- scenario_quests asserts that every type the mod names appears here, which is
-- what catches a typo'd or invented item name before it reaches the game.
--
-- Deliberately absent: Base.SheetPaper (does not exist; it is SheetPaper2) and
-- Base.GenericMail (exists, but has no CanBeWrite, so it cannot hold pages).
local KNOWN_ITEMS = {
    ["Base.Notepad"] = true,
    ["Base.Journal"] = true,
    ["Base.Notebook"] = true,
    ["Base.SheetPaper2"] = true,
    ["Base.GraphPaper"] = true,
    ["Base.IndexCard"] = true,
    ["Base.Pen"] = true,
    ["Base.Pencil"] = true,
    ["Base.BluePen"] = true,
    ["Base.RedPen"] = true,
    ["Base.Screwdriver"] = true,
    ["Base.PillsBeta"] = true,
    ["Base.Plate"] = true,
    ["Base.TinCanEmpty"] = true,
}

function instanceItem(fullType)
    -- The engine returns nil for a type that does not exist.
    if not KNOWN_ITEMS[fullType] then
        return nil
    end
    return Item.new(fullType)
end

_G.TestItem = Item

--------------------------------------------------------------------------------
-- ItemContainer
--------------------------------------------------------------------------------

local Container = {}
Container.__index = Container

function Container.new()
    return setmetatable({ _items = ArrayList.new() }, Container)
end

function Container:getItems() return self._items end

function Container:AddItem(itemOrType)
    local item = itemOrType
    if type(itemOrType) == "string" then
        item = instanceItem(itemOrType)
        if not item then return nil end
    end
    item._container = self
    self._items:add(item)
    return item
end

function Container:Remove(item)
    self._items:remove(item)
    item._container = nil
end

function Container:contains(item)
    for i = 0, self._items:size() - 1 do
        if self._items:get(i) == item then return true end
    end
    return false
end

_G.TestContainer = Container

--------------------------------------------------------------------------------
-- Player
--------------------------------------------------------------------------------

HaloTextHelper = { _last = nil }
function HaloTextHelper.addText(p, text) HaloTextHelper._last = text end

PLAYER = { x = 0, y = 0, z = 0, _inventory = Container.new() }
function PLAYER:getX() return self.x end
function PLAYER:getY() return self.y end
function PLAYER:getZ() return self.z end
function PLAYER:getInventory() return self._inventory end
function PLAYER:getUsername() return "TestPlayer" end
function getPlayer() return PLAYER end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

Events = {}
local function mkEvent()
    local e = { handlers = {} }
    function e.Add(f) table.insert(e.handlers, f) end
    function e.fire(...) for i = 1, #e.handlers do e.handlers[i](...) end end
    return e
end
Events.OnGameStart = mkEvent()
Events.OnPlayerUpdate = mkEvent()
Events.OnInitGlobalModData = mkEvent()
Events.OnFillInventoryObjectContextMenu = mkEvent()
Events.OnFillWorldObjectContextMenu = mkEvent()

--------------------------------------------------------------------------------
-- Client UI scaffolding: enough of it that the context menu and timed action
-- files load and can be driven, since that is where a real player meets this
-- feature.
--------------------------------------------------------------------------------

-- PZ's require is a file loader, not Lua's module system.
function require(_) end

ISBaseTimedAction = {}
ISBaseTimedAction.__index = ISBaseTimedAction

function ISBaseTimedAction:derive(name)
    local cls = setmetatable({}, { __index = self })
    cls.__index = cls
    cls.Type = name
    return cls
end

function ISBaseTimedAction.new(cls, character)
    local o = setmetatable({}, cls)
    o.character = character
    return o
end

function ISBaseTimedAction:perform() self.performed = true end
function ISBaseTimedAction:stop() self.stopped = true end
function ISBaseTimedAction:setActionAnim(_) end

ISTimedActionQueue = { queued = {} }
function ISTimedActionQueue.add(action)
    table.insert(ISTimedActionQueue.queued, action)
    return action
end

local Menu = {}
Menu.__index = Menu
function Menu.new() return setmetatable({ options = {} }, Menu) end
function Menu:addOption(name, target, onSelect, ...)
    local option = { name = name, target = target, onSelect = onSelect, args = { ... } }
    table.insert(self.options, option)
    return option
end
function Menu:addSubMenu(parent, sub) parent.subMenu = sub end
function Menu:find(name)
    for i = 1, #self.options do
        if self.options[i].name == name then return self.options[i] end
    end
    return nil
end

ISContextMenu = {}
function ISContextMenu:getNew(_) return Menu.new() end
_G.TestMenu = Menu

ISWorldObjectContextMenu = {}
function ISWorldObjectContextMenu.addToolTip() return {} end

ISInventoryPane = {}
function ISInventoryPane.getActualItems(items) return items end

function getSpecificPlayer(_) return PLAYER end

-- The vanilla function KS_NoteReadHook wraps. Signature confirmed in the B42
-- install: onWriteSomething(notebook, editable, player) where player is a
-- player number. _vanilla is kept so a simulated game restart can put the
-- unwrapped version back.
ISInventoryPaneContextMenu = ISInventoryPaneContextMenu or {}
ISInventoryPaneContextMenu.opened = {}
ISInventoryPaneContextMenu._vanillaOnWriteSomething = function(notebook, editable, player)
    table.insert(ISInventoryPaneContextMenu.opened,
        { notebook = notebook, editable = editable, player = player })
end
ISInventoryPaneContextMenu.onWriteSomething =
    ISInventoryPaneContextMenu._vanillaOnWriteSomething

--------------------------------------------------------------------------------
-- World: squares, objects and the cell
--
-- Enough to drive the dressing recorder and the cell-load dresser. Sprites are
-- modelled as plain names, which is all our data records.
--------------------------------------------------------------------------------

local Sprite = {}
Sprite.__index = Sprite
function Sprite.new(name) return setmetatable({ _name = name }, Sprite) end
function Sprite:getName() return self._name end

local WorldObject = {}
WorldObject.__index = WorldObject
function WorldObject.new(spriteName)
    return setmetatable({ _sprite = spriteName and Sprite.new(spriteName) or nil }, WorldObject)
end
function WorldObject:getSprite() return self._sprite end

local WorldItem = {}
WorldItem.__index = WorldItem
function WorldItem.new(item, wx, wy, wz)
    return setmetatable({ _item = item, _wx = wx or 0, _wy = wy or 0, _wz = wz or 0, _rot = 0 },
        WorldItem)
end
function WorldItem:getItem() return self._item end
-- Absolute world position. The recorder subtracts the square coordinate from
-- these to recover the offsets within the tile.
function WorldItem:getWorldPosX() return self._wx end
function WorldItem:getWorldPosY() return self._wy end
function WorldItem:getWorldPosZ() return self._wz end
function WorldItem:getWorldZRotation() return self._rot end
function WorldItem:setWorldZRotation(r) self._rot = r end

local Square = {}
Square.__index = Square

function Square.new(cell, x, y, z)
    return setmetatable({
        _cell = cell, _x = x, _y = y, _z = z,
        _objects = ArrayList.new(), _worldItems = ArrayList.new(),
    }, Square)
end

function Square:getX() return self._x end
function Square:getY() return self._y end
function Square:getZ() return self._z end
function Square:getCell() return self._cell end
function Square:getObjects() return self._objects end
function Square:getWorldObjects() return self._worldItems end
function Square:AddSpecialObject(object) self._objects:add(object) end
function Square:AddWorldInventoryItem(fullType, ox, oy, oz)
    local item = instanceItem(fullType) or Item.new(fullType)
    local worldItem = WorldItem.new(item,
        self._x + (ox or 0), self._y + (oy or 0), self._z + (oz or 0))
    self._worldItems:add(worldItem)
    return worldItem
end

-- Test helper: put a vanilla object here, as the map would.
function Square:addVanilla(spriteName)
    self._objects:add(WorldObject.new(spriteName))
end

IsoObject = {}
function IsoObject.new(_, _, spriteName) return WorldObject.new(spriteName) end

local Cell = {}
Cell.__index = Cell
function Cell.new() return setmetatable({ _squares = {} }, Cell) end
function Cell:getGridSquare(x, y, z)
    local key = x .. "," .. y .. "," .. z
    -- The engine returns nil for an unloaded square. The harness treats every
    -- square inside a scan as loaded, creating it on demand.
    self._squares[key] = self._squares[key] or Square.new(self, x, y, z)
    return self._squares[key]
end

CELL = Cell.new()
function getCell() return CELL end
_G.TestSquare = Square

--------------------------------------------------------------------------------
-- File writing and the HUD
--------------------------------------------------------------------------------

WRITTEN_FILES = {}

-- Extensions the engine refuses to open for writing. Modelled as configurable
-- rather than hard-coded, because the exporter is tested on "falls through to
-- one that works", not on which particular extension this build blocks.
FILE_WRITER_BLOCKED = { [".lua"] = true }

function getFileWriter(name, _, _)
    for ext in pairs(FILE_WRITER_BLOCKED) do
        if name:sub(-#ext) == ext then
            return nil
        end
    end

    WRITTEN_FILES[name] = ""
    return {
        write = function(_, text) WRITTEN_FILES[name] = WRITTEN_FILES[name] .. text end,
        close = function() end,
    }
end

UIFont = { Small = "Small", Large = "Large" }
DRAWN_STRINGS = {}
function getTextManager()
    return {
        DrawStringCentre = function(_, _, _, _, text)
            table.insert(DRAWN_STRINGS, text)
        end,
    }
end

Events.LoadGridsquare = mkEvent()
Events.OnPostUIDraw = mkEvent()

--------------------------------------------------------------------------------
-- Phase 4 fix round: tags, writability, per-player numbers, the user folder
--------------------------------------------------------------------------------

ItemTag = { WRITE = "write", PEN = "pen", PENCIL = "pencil",
            BLUE_PEN = "bluepen", RED_PEN = "redpen", GREEN_PEN = "greenpen" }

-- hasTag is on InventoryItem, so it is safe for anything.
function Item:hasTag(tag) return self._tags ~= nil and self._tags[tag] == true end

function Item:getCategory() return self._category or "Item" end

-- canBeWrite and isEmptyPages live on literature. Calling them on a hammer
-- raises an engine error, and the engine logs a stack trace even when the Lua
-- side catches it -- so the stub throws, and any code that forgets to guard
-- fails the suite instead of quietly spamming the player's console.
-- The engine writes a stack trace to console BEFORE the error reaches Lua, so a
-- pcall on the Lua side hides the failure from the mod while the player still
-- watches their console fill up. Recording the call here models that: a test can
-- then assert on "the engine was never asked", which a pcall cannot satisfy.
ENGINE_ERRORS = {}

local function engineRefuses(item, method)
    table.insert(ENGINE_ERRORS, method .. " on " .. tostring(item._fullType))
    error(method .. " called on a non-literature item: " .. tostring(item._fullType), 0)
end

function Item:canBeWrite()
    if self._category ~= "Literature" then
        engineRefuses(self, "canBeWrite")
    end
    return self._canBeWriteScript == true
end

function Item:isEmptyPages()
    if self._category ~= "Literature" then
        engineRefuses(self, "isEmptyPages")
    end
    for _ in pairs(self._pages) do return false end
    return true
end
function Item:setWorldZRotation(r) self._rot = r end

-- Mirrors CanBeWrite and Tags from the real item scripts, so "is this paper" and
-- "is this a pen" are answered the way the game would answer them.
local ITEM_PROPS = {
    ["Base.Notepad"] = { write = true },
    ["Base.Journal"] = { write = true },
    ["Base.Notebook"] = { write = true },
    ["Base.SheetPaper2"] = { write = true },
    ["Base.GraphPaper"] = { write = true },
    ["Base.IndexCard"] = { write = true },
    ["Base.Pen"] = { tags = { write = true, pen = true } },
    ["Base.Pencil"] = { tags = { write = true, pencil = true } },
    ["Base.BluePen"] = { tags = { write = true, bluepen = true } },
    ["Base.RedPen"] = { tags = { write = true, redpen = true } },
}

local plainInstanceItem = instanceItem

function instanceItem(fullType)
    local item = plainInstanceItem(fullType)
    if not item then
        return nil
    end

    local props = ITEM_PROPS[fullType]
    if props then
        item._canBeWriteScript = props.write == true
        item._tags = props.tags
        item._category = props.write and "Literature" or "Item"
    end

    return item
end

function PLAYER:getPlayerNum() return self._playerNum or 0 end

Core = { getMyDocumentFolder = function() return "C:/Users/test/Zomboid" end }
function getFileSeparator() return "/" end

--------------------------------------------------------------------------------
-- Zombies, squares as places to stand, and the dialogue window
--------------------------------------------------------------------------------

local Zombie = {}
Zombie.__index = Zombie

function Zombie.new(x, y, z, outfit, female)
    return setmetatable({
        _x = x, _y = y, _z = z, _outfit = outfit, _female = female,
        _modData = {}, _vars = {}, _attached = true, _handModels = true,
        _descriptor = { voice = "zombie" }, _emitter = { playing = true },
    }, Zombie)
end

function Zombie:getX() return self._x end
function Zombie:getY() return self._y end
function Zombie:getZ() return self._z end
function Zombie:setPosition(x, y, z) self._x, self._y, self._z = x, y, z end
function Zombie:getModData() return self._modData end
function Zombie:setCanWalk(b) self._canWalk = b end
function Zombie:setUseless(b) self._useless = b end
function Zombie:setInvulnerable(b) self._invulnerable = b end
function Zombie:setNoTeeth(b) self._noTeeth = b end
function Zombie:setVariable(name, value) self._vars[name] = value end
function Zombie:getVariable(name) return self._vars[name] end
function Zombie:clearAttachedItems() self._attached = false end
function Zombie:resetEquippedHandsModels() self._handModels = false end
function Zombie:getDescriptor()
    local d = self._descriptor
    return { setVoicePrefix = function(_, v) d.voice = v end }
end
function Zombie:getEmitter()
    local e = self._emitter
    return { stopAll = function() e.playing = false end }
end
_G.TestZombie = Zombie

-- addZombiesInOutfit is the vanilla spawner the disguise is built on top of.
SPAWNED_ZOMBIES = {}
ADD_ZOMBIES_FAILS = false

function addZombiesInOutfit(x, y, z, count, outfit, femaleChance, ...)
    if ADD_ZOMBIES_FAILS then
        return nil
    end

    local zombie = Zombie.new(x, y, z, outfit, femaleChance == 100)
    zombie:zombieSkin()
    table.insert(SPAWNED_ZOMBIES, zombie)

    local list = ArrayList.new()
    list:add(zombie)
    return list
end

-- Squares report whether something can stand on them, and who is standing there.
function Square:setStandable(solid, free)
    self._solid = solid
    self._free = free
end
function Square:isSolidFloor() return self._solid == true end
function Square:isFree(_) return self._free == true end
function Square:getMovingObjects()
    self._moving = self._moving or ArrayList.new()
    return self._moving
end
function Square:addMovingObject(o) self:getMovingObjects():add(o) end
function Square:transmitRemoveItemFromSquare(o) self._objects:remove(o) end

-- Everything a square in a loaded cell can do; getGridSquare returns nil for
-- anything outside the loaded set so the spawner's guards get exercised.
LOADED_SQUARES = nil

local plainGetGridSquare = Cell.getGridSquare
function Cell:getGridSquare(x, y, z)
    if LOADED_SQUARES and not LOADED_SQUARES[x .. "," .. y .. "," .. z] then
        return nil
    end
    return plainGetGridSquare(self, x, y, z)
end

DIALOGUE_SHOWN = {}
ISModalRichText = {}
function ISModalRichText:new(x, y, w, h, text, yesno, target, onclick, player)
    local o = setmetatable({ text = text, player = player }, { __index = self })
    return o
end
function ISModalRichText:initialise() self.initialised = true end
function ISModalRichText:addToUIManager() table.insert(DIALOGUE_SHOWN, self.text) end
function ISModalRichText:destroy() self.destroyed = true end

Events.EveryOneMinute = mkEvent()

-- OnFillWorldObjectContextMenu hands over IsoObjects, not squares, and the mod
-- reaches the square through them. Modelled so the test cannot take a shortcut
-- the game would not offer.
function WorldObject:getSquare() return self._square end

function Square:makeObject(spriteName)
    local object = WorldObject.new(spriteName)
    object._square = self
    self._objects:add(object)
    return object
end

--------------------------------------------------------------------------------
-- Blood, worn clothing and zombie identity
--------------------------------------------------------------------------------

BloodBodyPartType = {
    MAX = { index = function() return 3 end },
    FromIndex = function(i) return "part" .. i end,
}

local function newVisual()
    local blood, dirt = {}, {}
    local state = { skin = nil }
    return {
        _blood = blood, _dirt = dirt, _state = state,
        setSkinTextureName = function(_, name) state.skin = name end,
        getSkinTextureName = function() return state.skin end,
        setBlood = function(_, part, v) blood[part] = v end,
        getBlood = function(_, part) return blood[part] or 0 end,
        setDirt = function(_, part, v) dirt[part] = v end,
        getDirt = function(_, part) return dirt[part] or 0 end,
    }
end

local nextUID = 1

function Zombie:getUID()
    if not self._uid then
        self._uid = nextUID
        nextUID = nextUID + 1
    end
    return self._uid
end

function Zombie:getHumanVisual()
    self._humanVisual = self._humanVisual or newVisual()
    return self._humanVisual
end

function Zombie:getWornItems()
    if not self._worn then
        self._worn = ArrayList.new()
        local visual = newVisual()
        local item = { getVisual = function() return visual end }
        self._worn:add({ getItem = function() return item end })
    end
    return self._worn
end

function Zombie:resetModelNextFrame() self._modelReset = (self._modelReset or 0) + 1 end

-- Test helper: smear blood on everything, as being struck does.
function Zombie:bloody()
    self:getHumanVisual():setBlood("part0", 1)
    self:getWornItems():get(0):getItem():getVisual():setBlood("part1", 1)
end

function Zombie:isBloody()
    if self:getHumanVisual():getBlood("part0") > 0 then return true end
    if self:getWornItems():get(0):getItem():getVisual():getBlood("part1") > 0 then return true end
    return false
end

-- addZombiesInOutfit hands back a ZOMBIE, so its skin texture is a zombie one.
-- Modelled so a disguise that forgets the face fails here.
function Zombie:zombieSkin()
    self:getHumanVisual():setSkinTextureName(self._female and "F_ZedBody01_level1"
        or "M_ZedBody01_level1")
end

function Zombie:skinName() return self:getHumanVisual():getSkinTextureName() end

-- Losing the runtime half of the disguise, as a save and reload does. ModData
-- survives; nothing else on the object does.
function Zombie:forgetRuntimeState()
    self._canWalk = nil
    self._useless = nil
    self._invulnerable = nil
    self._noTeeth = nil
    self._vars = {}
    self._descriptor.voice = "zombie"
    self._emitter.playing = true
    self:zombieSkin()
end

Events.OnZombieUpdate = mkEvent()
