--[[
	Mod Immersive Rotten Corpses
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
	local ref = e.reference
	if (ref == nil) then
		return
	end

	local mobile = ref.mobile
	-- if (ref.object.objectType ~= tes3.objectType.creature) then
	-- 	return
	-- end
	if (mobile == nil) then
		return
	end

	local timestampEra = tes3.getSimulationTimestamp()
	local corpseHourstamp = mobile.corpseHourstamp
	local gameStartTimestamp = 3746001 - 33

	local timestampSinceGameStart = tes3.getSimulationTimestamp() - gameStartTimestamp
	local deadSince = timestampSinceGameStart - corpseHourstamp

	-- mod_log("obj %s current time: %s, dead since: %s(%s)", ref.id, tostring(timestampEra), tostring(deadSince), tostring(corpseHourstamp))

	local adj = 'Rotten'
	local color = tes3.palette.answerColor

	if (deadSince < 7) then
		adj = 'Fresh'
		color = tes3.palette.fatigueColor
	elseif (deadSince < 24) then
		adj = 'Bloated'
		color = tes3.palette.normalColor
	elseif (deadSince < 36) then
		adj = 'Decaying'
		color = tes3.palette.healthNpcColor
	elseif (deadSince < 48) then
		adj = 'Rotting'
		color = tes3.palette.healthColor
	elseif (deadSince < 60) then
		adj = 'Rotten'
		color = tes3.palette.answerColor
	end

	-- selector

	local nameMenu = e.tooltip:findChild('HelpMenu_name')
	if (nameMenu ~= nil) then
		local perc = deadSince / 72 * 100
		local txt = string.format("%s %s, dead since: %.1fh (%.1f%%)", adj, nameMenu.text, deadSince, perc)
		-- nameMenu.text = adj .. " " .. nameMenu.text .. ", dead since: " .. tostring(deadSince) .. "h (" .. perc .. "%)"
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
