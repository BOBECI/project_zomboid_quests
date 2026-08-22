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
function WorldItem.new(item) return setmetatable({ _item = item }, WorldItem) end
function WorldItem:getItem() return self._item end

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
function Square:AddWorldInventoryItem(fullType, _, _, _)
    local item = instanceItem(fullType) or Item.new(fullType)
    self._worldItems:add(WorldItem.new(item))
    return item
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
function getFileWriter(name, _, _)
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
