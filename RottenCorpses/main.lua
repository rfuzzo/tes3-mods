--[[
	Mod Loading Splash Screens
	Author: rfuzzo

	This mod displys splash screens during the cell loading phase instead of freezing the current frame
	Splash screens are randomly taken from the installed splash screen pool
]] --
local config = require("rfuzzo.RottenCorpses.config")

--- local logger
--- @param msg string
--- @vararg any *Optional*. No description yet available.
local function mod_log(msg, ...)
	local str = "[ %s/%s ] " .. msg
	local arg = { ... }
	return mwse.log(str, config.author, config.id, unpack(arg))
end

--- main mod
--- @param e uiObjectTooltipEventData
local function uiObjectTooltipCallback(e)

end

--- Init mod 
--- @param e initializedEventData
local function initializedCallback(e)
	mod_log("%s v%.1f Initialized", config.mod, config.version)
end

--[[
    event hooks
]]
event.register(tes3.event.initialized, initializedCallback)
event.register(tes3.event.uiObjectTooltip, uiObjectTooltipCallback)
