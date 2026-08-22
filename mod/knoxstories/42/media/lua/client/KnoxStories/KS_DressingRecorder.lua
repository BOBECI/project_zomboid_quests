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

-- A square's contents as two name -> count tables. Counting rather than just
-- listing means placing a second identical tin can on one square is noticed.
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
        for i = 0, worldItems:size() - 1 do
            local worldItem = worldItems:get(i)
            local item = worldItem:getItem()
            if item then
                local fullType = item:getFullType()
                items[fullType] = (items[fullType] or 0) + 1
            end
        end
    end

    return { sprites = sprites, items = items }
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

        for fullType, count in pairs(now.items) do
            local added = count - (before.items[fullType] or 0)
            for _ = 1, added do
                table.insert(items, { x = x, y = y, z = z, item = fullType })
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
-- recording means copying one file into the mod. getFileWriter puts it in the
-- Zomboid folder, next to console.txt.
--------------------------------------------------------------------------------

local function writePlacements(writer, listName, list, field)
    writer:write("    " .. listName .. " = {\r\n")
    for i = 1, #list do
        local p = list[i]
        writer:write(string.format("        { x = %d, y = %d, z = %d, %s = %q },\r\n",
            p.x, p.y, p.z, field, p[field]))
    end
    writer:write("    },\r\n")
end

function KS.Recorder.finish()
    if not session then
        KS.warn("nothing is being recorded")
        return nil
    end

    local set = buildSet()
    local filename = "KnoxStories_dressing_" .. set.id .. ".lua"

    local writer = getFileWriter(filename, true, false)
    if not writer then
        KS.warn("could not open " .. filename .. " for writing")
        session = nil
        return nil
    end

    writer:write("-- Recorded in game by the KnoxStories dressing recorder.\r\n")
    writer:write("-- Copy into mod/knoxstories/42/media/lua/shared/KnoxStories/dressing/\r\n")
    writer:write("--\r\n")
    writer:write("-- Contains only what was added during the recording, never the\r\n")
    writer:write("-- building itself, so it stays valid across map updates.\r\n\r\n")
    writer:write("KnoxStories = KnoxStories or {}\r\n")
    writer:write("KnoxStories.DressingSets = KnoxStories.DressingSets or {}\r\n\r\n")
    writer:write("table.insert(KnoxStories.DressingSets, {\r\n")
    writer:write(string.format("    id = %q,\r\n", set.id))
    writer:write(string.format("    area = { x1 = %d, y1 = %d, x2 = %d, y2 = %d, z1 = %d, z2 = %d },\r\n",
        set.area.x1, set.area.y1, set.area.x2, set.area.y2, set.area.z1, set.area.z2))
    writePlacements(writer, "objects", set.objects, "sprite")
    writePlacements(writer, "items", set.items, "item")
    writer:write("})\r\n")
    writer:close()

    KS.print("exported '" .. set.id .. "': " .. #set.objects .. " object(s), "
        .. #set.items .. " item(s)")
    KS.print("written to your Zomboid folder as " .. filename)

    session = nil
    return set
end
