--[[
    KS_CoordinateHUD.lua

    Your position, on screen, so placing a trigger does not mean alt-tabbing to
    console.txt every few steps.

    Debug only, and it draws nothing at all when the flag is off -- not a hidden
    panel, no handler cost beyond one boolean test per frame.

    It also shows the dressing recorder's state, because the one thing you want
    to be certain of while dressing a house is whether it is actually recording.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

local MARGIN = 12
local LINE_HEIGHT = 16

-- Off-white, and a warmer colour while recording so it is obvious at a glance.
local IDLE = { r = 0.85, g = 0.85, b = 0.82 }
local RECORDING = { r = 1.0, g = 0.72, b = 0.35 }

local function onPostUIDraw()
    if not KS.DEBUG then
        return
    end

    local player = getPlayer()
    if not player then
        return
    end

    local recording = KS.Recorder and KS.Recorder.isRecording()
    local colour = recording and RECORDING or IDLE

    local text = string.format("%d, %d, %d",
        math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()))

    -- DrawStringCentre is what the game's own UI uses; there is no left-aligned
    -- DrawString in the Lua API, so the anchor is a centre point near the top.
    local textManager = getTextManager()
    local x = MARGIN + 90
    local y = MARGIN

    textManager:DrawStringCentre(UIFont.Small, x, y, text, colour.r, colour.g, colour.b, 1)

    if recording then
        textManager:DrawStringCentre(UIFont.Small, x, y + LINE_HEIGHT,
            KS.Recorder.status(), RECORDING.r, RECORDING.g, RECORDING.b, 1)
    end
end

Events.OnPostUIDraw.Add(onPostUIDraw)
