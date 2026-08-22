--[[
    KS_DressingRecorder.lua

    Dress a house by hand in game, then export what you added.

    HOW IT AVOIDS CAPTURING THE BUILDING

    Not by listening for placement events -- those also fire for vanilla objects
    as cells stream in, and telling the two apart afterwards is guesswork.
    Instead it takes a full snapshot of everything in the area when you start,
    and diffs against it when you stop. Whatever is in the second scan and not
    the first is yours, by definition.

    That is what makes the exported data survive a map update: it contains your
    additions only, so a wall moving in a future build does not invalidate it.

    WHAT IT CAPTURES

      - objects, by sprite name
      - items dropped on the ground, by full type

    WHAT IT DOES NOT

      - furniture rotation, or objects modified rather than added
      - blood, broken glass, and other things the engine spawns as side effects
      - anything outside the recorded area, or on a floor outside it

    A thing you place and then remove during the same recording simply will not
    appear, because only the end state is compared. That is usually what you want.

    Debug only.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

KS.Recorder = KS.Recorder or {}

local DEFAULT_RADIUS = 15

-- nil when not recording.
local session = nil

--------------------------------------------------------------------------------
-- Scanning
--------------------------------------------------------------------------------

-- Where an item sits WITHIN its tile, not just which tile it is on.
--
-- AddWorldInventoryItem takes (type, xoff, yoff, zoff): the first two place it
-- across the tile, the third is height. A plate on a table has a zoff of
-- roughly half a tile; a plate on the floor has zero. Recording only the tile
-- coordinate is why the first version put everything on the ground.
local function offsetsOf(worldItem, x, y, z)
    local ok, ox, oy, oz = pcall(function()
        return worldItem:getWorldPosX() - x,
               worldItem:getWorldPosY() - y,
               worldItem:getWorldPosZ() - z
    end)

    if not ok or type(ox) ~= "number" then
        return 0, 0, 0, 0
    end

    local rotOk, rot = pcall(function() return worldItem:getWorldZRotation() end)

    return ox, oy, oz, (rotOk and type(rot) == "number") and rot or 0
end

-- Sprites are counted; items are listed, because an item's offsets have to
-- survive into the export and a count cannot carry them. Counting rather than
-- just listing sprites means a second identical chair on one tile is noticed.
local function scanSquare(square)
    local sprites, items = {}, {}

    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        local sprite = object:getSprite()
        local name = sprite and sprite:getName()
        if name then
            sprites[name] = (sprites[name] or 0) + 1
        end
    end

    local worldItems = square:getWorldObjects()
    if worldItems then
        local x, y, z = square:getX(), square:getY(), square:getZ()

        for i = 0, worldItems:size() - 1 do
            local worldItem = worldItems:get(i)
            local item = worldItem:getItem()

            if item then
                local ox, oy, oz, rot = offsetsOf(worldItem, x, y, z)
                table.insert(items, {
                    item = item:getFullType(),
                    ox = ox, oy = oy, oz = oz, rot = rot,
                })
            end
        end
    end

    return { sprites = sprites, items = items }
end

local function countByType(itemList)
    local counts = {}
    for i = 1, #itemList do
        counts[itemList[i].item] = (counts[itemList[i].item] or 0) + 1
    end
    return counts
end

local function scanArea(area)
    local cell = getCell()
    local scan = {}

    for z = area.z1, area.z2 do
        for x = area.x1, area.x2 do
            for y = area.y1, area.y2 do
                local square = cell:getGridSquare(x, y, z)
                if square then
                    scan[KS.Dressing.key(x, y, z)] = scanSquare(square)
                end
            end
        end
    end

    return scan
end

--------------------------------------------------------------------------------
-- Recording
--------------------------------------------------------------------------------

function KS.Recorder.isRecording()
    return session ~= nil
end

function KS.Recorder.status()
    if not session then
        return "not recording"
    end
    return "recording '" .. session.id .. "'"
end

function KS.Recorder.start(player, setId, radius)
    if not KS.DEBUG then
        return false
    end

    radius = radius or DEFAULT_RADIUS

    local x, y, z = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())

    -- Floors are swept from ground up to the player's level plus one, so an
    -- upstairs dressing still gets recorded without scanning the whole column.
    local area = {
        x1 = x - radius, x2 = x + radius,
        y1 = y - radius, y2 = y + radius,
        z1 = 0, z2 = math.max(z + 1, 1),
    }

    session = {
        id = setId,
        area = area,
        before = scanArea(area),
    }

    KS.print("recording '" .. setId .. "' over x " .. area.x1 .. "-" .. area.x2
        .. ", y " .. area.y1 .. "-" .. area.y2 .. ", floors " .. area.z1 .. "-" .. area.z2)
    KS.print("place your objects, then use Finish recording. Stay inside that box.")

    return true
end

function KS.Recorder.cancel()
    if not session then
        return false
    end
    KS.print("discarded recording '" .. session.id .. "'")
    session = nil
    return true
end

-- Diffs the area against the opening snapshot and returns a dressing set.
local function buildSet()
    local after = scanArea(session.area)

    local objects, items = {}, {}

    for k, now in pairs(after) do
        local before = session.before[k] or { sprites = {}, items = {} }

        -- The key is "x,y,z"; splitting it back is cheaper than carrying the
        -- numbers through both scans.
        local x, y, z = k:match("^(-?%d+),(-?%d+),(-?%d+)$")
        x, y, z = tonumber(x), tonumber(y), tonumber(z)

        for sprite, count in pairs(now.sprites) do
            local added = count - (before.sprites[sprite] or 0)
            for _ = 1, added do
                table.insert(objects, { x = x, y = y, z = z, sprite = sprite })
            end
        end

        -- Match by type, then emit the actual records for the surplus ones, so
        -- the offsets that came off the world go into the export.
        local nowCounts = countByType(now.items)
        local beforeCounts = countByType(before.items)

        local emitted = {}
        for fullType, count in pairs(nowCounts) do
            emitted[fullType] = count - (beforeCounts[fullType] or 0)
        end

        for i = 1, #now.items do
            local record = now.items[i]

            if (emitted[record.item] or 0) > 0 then
                emitted[record.item] = emitted[record.item] - 1
                table.insert(items, {
                    x = x, y = y, z = z, item = record.item,
                    ox = record.ox, oy = record.oy, oz = record.oz, rot = record.rot,
                })
            end
        end
    end

    return {
        id = session.id,
        area = session.area,
        objects = objects,
        items = items,
    }
end

--------------------------------------------------------------------------------
-- Export
--
-- Written as a Lua file in the same shape as notes/ and quests/, so finishing a
-- recording means copying one file into the mod.
--
-- getFileWriter is sandboxed to the Lua subfolder of the user directory, NOT the
-- user directory itself -- the file lands in Zomboid/Lua/, alongside the game's
-- own layout.ini and emote.ini, not next to console.txt.
--------------------------------------------------------------------------------

-- The engine refuses to open a .lua file for writing. That is not documented
-- anywhere, but it is consistent with the game's own code: every getFileWriter
-- call in media/lua uses .txt, .ini, .log or .cfg, and never .lua. Writing
-- executable Lua into the user folder is an obvious thing to refuse.
--
-- So the export is a .txt containing Lua, and you rename it when you copy it in.
-- The list is tried in order rather than hard-coded to .txt so that a build which
-- allows more, or fewer, still produces a file -- and the log says which one
-- worked.
local EXPORT_EXTENSIONS = { ".txt", ".ini", ".log", ".cfg", ".lua" }

local function openExport(baseName)
    for i = 1, #EXPORT_EXTENSIONS do
        local filename = baseName .. EXPORT_EXTENSIONS[i]
        local writer = getFileWriter(filename, true, false)

        if writer then
            return writer, filename
        end

        KS.log("the game refused to open " .. filename .. ", trying the next extension")
    end

    return nil
end

local function writeObjects(writer, list)
    writer:write("    objects = {\r\n")
    for i = 1, #list do
        local p = list[i]
        writer:write(string.format("        { x = %d, y = %d, z = %d, sprite = %q },\r\n",
            p.x, p.y, p.z, p.sprite))
    end
    writer:write("    },\r\n")
end

local function writeItems(writer, list)
    writer:write("    items = {\r\n")
    for i = 1, #list do
        local p = list[i]
        writer:write(string.format(
            "        { x = %d, y = %d, z = %d, item = %q, ox = %.3f, oy = %.3f, oz = %.3f, rot = %.1f },\r\n",
            p.x, p.y, p.z, p.item, p.ox or 0, p.oy or 0, p.oz or 0, p.rot or 0))
    end
    writer:write("    },\r\n")
end

-- The absolute path the export actually landed on. getFileWriter is sandboxed
-- to the Lua subfolder of the user directory, which is NOT where the docs used
-- to say to look -- a success message naming the wrong folder is worse than no
-- message, so this reports the real one.
local function exportPath(filename)
    local ok, base = pcall(function()
        return Core.getMyDocumentFolder() .. getFileSeparator() .. "Lua" .. getFileSeparator()
    end)

    if ok and type(base) == "string" then
        return base .. filename
    end

    return "<Zomboid user folder>" .. "/Lua/" .. filename
end

function KS.Recorder.finish()
    if not session then
        KS.warn("nothing is being recorded")
        return nil
    end

    local set = buildSet()

    local writer, filename = openExport("KnoxStories_" .. set.id)
    if not writer then
        KS.warn("the game refused to open a file for writing under every extension tried."
            .. " Nothing was exported, and the recording has been kept -- try Finish again.")
        return nil
    end

    writer:write("-- Recorded in game by the KnoxStories dressing recorder.\r\n")
    writer:write("--\r\n")
    writer:write("-- RENAME THIS FILE TO .lua, then copy it into\r\n")
    writer:write("-- mod/knoxstories/42/media/lua/shared/KnoxStories/dressing/\r\n")
    writer:write("-- It is written as .txt because the game will not open a .lua\r\n")
    writer:write("-- file for writing.\r\n")
    writer:write("--\r\n")
    writer:write("-- Contains only what was added during the recording, never the\r\n")
    writer:write("-- building itself, so it stays valid across map updates.\r\n\r\n")
    writer:write("KnoxStories = KnoxStories or {}\r\n")
    writer:write("KnoxStories.DressingSets = KnoxStories.DressingSets or {}\r\n\r\n")
    writer:write("table.insert(KnoxStories.DressingSets, {\r\n")
    writer:write(string.format("    id = %q,\r\n", set.id))
    writer:write(string.format("    area = { x1 = %d, y1 = %d, x2 = %d, y2 = %d, z1 = %d, z2 = %d },\r\n",
        set.area.x1, set.area.y1, set.area.x2, set.area.y2, set.area.z1, set.area.z2))
    writeObjects(writer, set.objects)
    writeItems(writer, set.items)
    writer:write("})\r\n")
    writer:close()

    KS.print("exported '" .. set.id .. "': " .. #set.objects .. " object(s), "
        .. #set.items .. " item(s)")
    KS.print("written to " .. exportPath(filename))
    KS.print("rename it to .lua, then copy it into the mod's dressing folder")

    session = nil
    return set
end
