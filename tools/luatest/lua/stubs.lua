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
        _drainable = (fullType == "Base.Pen" or fullType == "Base.Pencil"),
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

function instanceItem(fullType)
    -- The engine returns nil for a type that does not exist. Only the types the
    -- dummy content actually uses are considered real here.
    local known = {
        ["Base.Notepad"] = true,
        ["Base.GenericMail"] = true,
        ["Base.SheetPaper"] = true,
        ["Base.Pen"] = true,
        ["Base.Pencil"] = true,
    }
    if not known[fullType] then
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
