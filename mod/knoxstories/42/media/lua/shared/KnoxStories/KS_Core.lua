--[[
    KS_Core.lua

    Root namespace for the mod. Lives in shared/ so it loads on the client, on
    the server, and in single-player (where both trees load in one process).

    Every file uses the "X = X or {}" idiom so load order between files never
    matters. Cross-file calls happen inside event callbacks, by which point the
    whole tree is loaded.
]]

KnoxStories = KnoxStories or {}

local KS = KnoxStories

KS.MOD_ID = "knoxstories"
KS.VERSION = "0.2.0"

-- Build plan, section 4: logging goes behind a flag from day one. The reference
-- mod ships ~258 live print() calls; we are not repeating that.
--
-- Phase 1 note: this is ON by default because the evaluator's position logger is
-- how you find coordinates to tune the dummy quest areas. Set it to false before
-- any real playtest.
KS.DEBUG = true

local LOG_PREFIX = "[KnoxStories] "

-- Always printed. The boot banner and real state transitions.
function KS.print(message)
    print(LOG_PREFIX .. tostring(message))
end

-- Always printed. Rejected commands, malformed quest data, load-order slips.
function KS.warn(message)
    print(LOG_PREFIX .. "WARN: " .. tostring(message))
end

-- Suppressed unless DEBUG is on. Everything diagnostic goes through this.
function KS.log(message)
    if KS.DEBUG then
        print(LOG_PREFIX .. tostring(message))
    end
end

-- Quest lifecycle. A quest is seeded ACTIVE and ends COMPLETE.
-- Phase 4 adds a dormant-until-discovered state, when NPCs exist to discover.
KS.STATUS = {
    ACTIVE = "active",
    COMPLETE = "complete",
}
