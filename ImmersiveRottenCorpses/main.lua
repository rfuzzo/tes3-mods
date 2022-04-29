--[[
	Mod Immersive Rotten Corpses
	Author: rfuzzo

	This mod changes the tooltip of creature corpses to reflect their "decay" - time passed since they died

	TODO:
		- decals

]] --
local config = require("rfuzzo.ImmersiveRottenCorpses.config")

--- local logger
--- @param msg string
--- @vararg any *Optional*. No description yet available.
local function mod_log(msg, ...)
	local str = "[ %s/%s ] " .. msg
	local arg = { ... }
	return mwse.log(str, config.author, config.id, unpack(arg))
end

--- custom timestamp on the actor, but don't store anything in the save
local function onDamaged(e)
	if e.attackerReference ~= tes3.player then
		return
	end

	if e.killingBlow == true then
		local ref = e.reference
		local timestampEra = tes3.getSimulationTimestamp()

		mod_log("%s killed, current time: %s", ref.id, tostring(timestampEra))

		-- store in tempData
		ref.tempData["rf_corpseTimeStamp"] = timestampEra

		-- and when first loading get from corpseTimestamp
	end
end

--- main mod
--- @param e uiObjectTooltipEventData
local function uiObjectTooltipCallback(e)
	local ref = e.reference
	if (ref == nil) then
		return
	end

	local mobile = ref.mobile
	if (ref.object.objectType ~= tes3.objectType.creature) then
		return
	end
	if (mobile == nil) then
		return
	end

	local timestampEra = tes3.getSimulationTimestamp()
	local deadSince = mobile.corpseHourstamp - 34 -- ???

	local corpseHourstampReal = ref.tempData["rf_corpseTimeStamp"]
	if (corpseHourstampReal ~= nil) then
		deadSince = timestampEra - corpseHourstampReal
		mod_log("obj %s current time: %s, dead since: %s(%s)", ref.id, tostring(timestampEra), tostring(deadSince),
		        tostring(corpseHourstampReal))
	end

	local adj = 'Rotten'
	local color = tes3.palette.answerColor
	local level = 5

	if (deadSince < 7) then
		adj = 'Fresh'
		color = tes3.palette.fatigueColor
		level = 1
	elseif (deadSince < 24) then
		adj = 'Bloated'
		color = tes3.palette.normalColor
		level = 2
	elseif (deadSince < 36) then
		adj = 'Decaying'
		color = tes3.palette.healthNpcColor
		level = 3
	elseif (deadSince < 48) then
		adj = 'Rotting'
		color = tes3.palette.healthColor
		level = 4
	elseif (deadSince < 60) then
		adj = 'Rotten'
		color = tes3.palette.answerColor
		level = 5
	end

	-- selector

	local nameMenu = e.tooltip:findChild('HelpMenu_name')
	if (nameMenu ~= nil) then
		local perc = deadSince / 72 * 100
		local txt = string.format("%s %s, dead since: %.1fh (%.1f%%)", adj, nameMenu.text, deadSince, perc)
		-- local txt = string.format("%s %s", adj, nameMenu.text)
		nameMenu.text = txt
		nameMenu.color = tes3ui.getPalette(color)
		nameMenu:updateLayout()
	end
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
event.register(tes3.event.damaged, onDamaged)

