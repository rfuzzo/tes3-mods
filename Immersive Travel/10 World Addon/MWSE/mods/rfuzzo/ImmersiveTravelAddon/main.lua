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

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS
--- @param e initializedEventData
local function initializedCallback(e)
    debug.log("initializedCallback")

    local services = common.loadServices()
    if not services then return end

    debug.log(" main")
    local map = {}

    for key, service in pairs(services) do
        debug.log(service.class)

        common.loadRoutes(service)
        local destinations = service.routes
        if destinations then

            for _i, start in ipairs(table.keys(destinations)) do
                for _j, destination in ipairs(destinations[start]) do
                    local spline =
                        common.loadSpline(start, destination, service)
                    for _, pos in ipairs(spline) do
                        local cx = math.floor(pos.x / 8192)
                        local cy = math.floor(pos.y / 8192)

                        debug.log(cx .. " " .. cy)

                    end
                end
            end
        end

    end

    debug.log("end initializedCallback")
end
event.register(tes3.event.initialized, initializedCallback)
