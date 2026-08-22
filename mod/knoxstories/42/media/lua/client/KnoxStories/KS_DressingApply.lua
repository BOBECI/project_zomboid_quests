--[[
    KS_DressingApply.lua

    Hooks cell loading and dresses squares as they stream in.

    LoadGridsquare fires once per square as the world loads it around the player,
    which is exactly the moment overview section 5 describes: the house is dressed
    before the player ever sees it, so its state looks earned rather than placed.

    Phase 6 seam. This mutates the world, which architecture 6.2 puts on the
    server, and LoadGridsquare is a client event. In single-player both trees
    share a process so this is correct as written. In multiplayer the client will
    need to ask the server to dress the square instead -- the same shape as
    KS.Commands, with KS.Dressing.applyToSquare running server-side unchanged.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

local function onLoadGridsquare(square)
    KS.Dressing.applyToSquare(square)
end

Events.LoadGridsquare.Add(onLoadGridsquare)
