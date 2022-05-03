--[[
	Mod Immersive Bosmer Corpse Disposal
	Author: rfuzzo

	This mod changes the "dispose corpse" button to "eat corpse" if you are playing as a Bosmer

	TODO:
		- 

]] --
local config = require("rfuzzo.ImmersiveBosmerDisposal.config")

--- local logger
--- @param msg string
--- @vararg any *Optional*. No description yet available.
local function mod_log(msg, ...)
	local str = "[ %s/%s ] " .. msg
	local arg = { ... }
	return mwse.log(str, config.author, config.id, unpack(arg))
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

