--[[
Immersive Travel Mod
v 1.0
by rfuzzo

mwse real-time travel mod

--]] -- 
local common = require("rfuzzo.ImmersiveTravel.common")

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION

local logger = require("logging.logger")
local log = logger.new {
    name = "Immersive Travel World Addon",
    logLevel = "DEBUG",
    logToConsole = true,
    includeTimestamp = true
}

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CLASSES
