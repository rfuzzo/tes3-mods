--[[
	Mod Always First Equip
	Author: rfuzzo

	always plays the weapon idle animation when you ready it

	TODO:
		- d
 
]] --
local config = require("rfuzzo.AlwaysFirstEquip.config")

--- local logger
--- @param msg string
--- @vararg any *Optional*. No description yet available.
local function mod_log(msg, ...)
	local str = "[ %s/%s ] " .. msg
	local arg = { ... }
	return mwse.log(str, config.author, config.id, unpack(arg))
end

--- main mod
--- @param e weaponReadiedEventData
local function weaponReadiedCallback(e)

	local ref = e.reference

	-- tes3.playAnimation({
	-- 	reference = tes3.player,
	-- 	group = tes3.animationGroup.idle1h,
	-- 	startFlag = tes3.animationStartFlag.immediate,
	-- 	loopCount = 0,
	-- })

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
event.register(tes3.event.weaponReadied, weaponReadiedCallback)
--- @param e playGroupEventData
local function playGroupCallback(e)

	if (e.reference.object.objectType ~= tes3.objectType.npc) then
		return
	end

	if (e.reference.id ~= "PlayerSaveGame" and e.reference.id ~= "Player1stPerson") then
		return
	end

	-- local data = e.animationData
	-- tes3.messageBox({ message = e.group, showInDialog = false, duration = 1 })

	-- mod_log("%s playGroupCallback. group: %s, objectType: %s", e.reference.id, e.group, e.reference.object.objectType)
end
event.register(tes3.event.playGroup, playGroupCallback, { filter = tes3.player })

