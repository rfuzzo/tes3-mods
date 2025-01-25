--[[
  KCD pickpocketing
  by rfuzzo
  version 1.0

  - governing skill: security

  - security perks:
    25  has an idea of how much time can be taken
    50
    75  can steal equipped weapon
    100 can steal equipped items?

]] --
-- const
local timerDuration = 0.01
local timerResolution = 1000
local crimeValue = 25 -- static crime value for when a victim detected you
local pickpocketExpValue = 2
local backstabDegrees = 80
local backstabAngle = (2 * math.pi) * (backstabDegrees / 360)

local logger = require("logging.logger")
local log = logger.new {
	name = "kcdpickpocket",
	logLevel = "DEBUG",
	logToConsole = false,
	includeTimestamp = false,
}

-- IDs
local id_menu = nil ---@type number?
local id_ok = nil ---@type number?
local id_cancel = nil ---@type number?
local id_fillbar = nil ---@type number?
local id_minigameProgressBar = nil ---@type number?
local id_minigame_fillbar = nil ---@type number?
local GUI_Pickpocket_multi = nil ---@type number?
local GUI_Pickpocket_sneak = nil ---@type number?

-- variables
local myTimer = nil ---@type mwseTimer?
local timePassed = 0
local detectionTime = 10        -- the time after which the victim detects you
local maxDetectionTime = 20     -- the time after which the victim detects you
local detectionTimeGuessed = 10 -- how accurate you are with detecting the time left
---@type mwseSafeObjectHandle | nil
local victimHandle = nil

-- /////////////////////////////////////////////////////////////////

local function isPlayerSneaking()
	return tes3ui.findMenu(GUI_Pickpocket_multi):findChild(GUI_Pickpocket_sneak).visible
end

-- This function will filter items depending on certain parameters
--- @param e tes3ui.showInventorySelectMenu.filterParams
local function valueFilter(e)
	if not victimHandle then
		return false
	end
	if not victimHandle:valid() then
		return false
	end

	-- filter items by value depending on your skill
	local playerSkill = tes3.mobilePlayer.security.current
	local itemWeight = e.item.weight
	local isItemEquipped = victimHandle:getObject().object:hasItemEquipped(e.item, e.itemData)

	local canSteal = false
	if playerSkill >= 100 then
		canSteal = true
	elseif playerSkill >= 75 then
		canSteal = true
	elseif playerSkill >= 50 then
		canSteal = itemWeight <= 30
	elseif playerSkill >= 25 then
		canSteal = itemWeight <= 15
	elseif playerSkill >= 1 then
		canSteal = itemWeight <= 2
	end

	if isItemEquipped and playerSkill < 100 then
		canSteal = false
	end

	return canSteal
end

--- @param e pickpocketEventData
local function pickpocketCallback(e)
	log:debug("pickpocketCallback")

	e.chance = 100

	-- proc skill
	tes3.mobilePlayer:exerciseSkill(tes3.skill.security, pickpocketExpValue)
end

--- @param victim tes3reference
local function reportCrime(victim)
	log:debug("reportCrime")


	local blind = victim.mobile.blind
	local invisible = tes3.mobilePlayer.invisibility
	-- TODO crime report modifiers

	tes3.worldController.mobManager.processManager:detectPresence(tes3.mobilePlayer, true)

	if tes3.mobilePlayer.isPlayerDetected then
		-- tes3.messageBox("Detected!")
		log:debug("triggerCrime")
		tes3.triggerCrime({ type = tes3.crimeType.theft, value = crimeValue, victim = victim.mobile, forceDetection = true })
	end
end

--- @param shouldReportCrime boolean
local function OnPickpocketMinigameEnd(shouldReportCrime)
	log:debug("OnPickpocketMinigameEnd")

	event.unregister(tes3.event.pickpocket, pickpocketCallback)

	-- destroy timer
	if myTimer then
		myTimer:cancel()
		myTimer = nil
	end

	-- leave minigame menu
	local menu = tes3ui.findMenu(id_minigameProgressBar)
	if (menu) then
		menu:destroy()
	end

	-- leave charge menu
	local menu2 = tes3ui.findMenu(id_menu)
	if (menu2) then
		menu2:destroy()
	end

	-- trigger crime for stealing
	if (shouldReportCrime and victimHandle and victimHandle:valid()) then
		local victim = victimHandle:getObject()
		reportCrime(victim)
	end

	victimHandle = nil

	tes3ui.leaveMenuMode()
end

--- Shows an item select menu
--- @return boolean
local function ShowItemSelectmenu()
	if not victimHandle then
		return false
	end
	if not victimHandle:valid() then
		return false
	end

	-- events
	event.register(tes3.event.pickpocket, pickpocketCallback)

	local wasShown = tes3.showContentsMenu({ reference = victimHandle:getObject(), pickpocket = true })


	if wasShown then
		local menu1 = tes3ui.findMenu("MenuContents")
		if (menu1) then
			-- hide take all button
			menu1:findChild("MenuContents_takeallbutton").visible = false

			-- hook into the destroy event
			menu1:registerAfter(tes3.uiEvent.destroy, function()
				log:debug("destroy")
				OnPickpocketMinigameEnd(false)
			end)

			-- TODO hide certain items
			menu1:registerBefore(tes3.uiEvent.focus, function()
				log:debug("focus")
			end)
		end
	end

	return wasShown
end

--- Count down timer
local function onMinigameTimerTick()
	if myTimer == nil then
		return
	end

	-- check if right mouse buttton was pressed and end charge
	if tes3.worldController.inputController:isMouseButtonPressedThisFrame(1) then
		log:debug("isButtonPressed")
		OnPickpocketMinigameEnd(false)

		return
	end

	timePassed = timePassed - timerDuration

	if timePassed <= timerDuration then
		-- we took too long
		log:debug("timePassed <= timerDuration in minigame")
		OnPickpocketMinigameEnd(true)
	else
		-- update UI
		local menu = tes3ui.findMenu(id_minigameProgressBar)
		if (menu) then
			local fillBar = menu:findChild(id_minigame_fillbar)
			-- decrement time
			fillBar.widget.current = timePassed * timerResolution

			menu:updateLayout()
		end
	end
end

--- the actual pickpocket minigame
local function CreateMinigameMenu()
	if not victimHandle then
		return false
	end
	if not victimHandle:valid() then
		return false
	end

	-- local generate = true
	-- if table.find(npcs, victim.baseObject.id) then
	-- 	local diff = tes3.getSimulationTimestamp() - table.get(npcs, victim.baseObject.id)
	-- 	if diff < npcForgetH then
	-- 		generate = false
	-- 		-- mwse.log("skipped " .. victim.baseObject.id)
	-- 	else
	-- 		table.removevalue(npcs, victim.baseObject.id)
	-- 		-- mwse.log("removed " .. victim.baseObject.id)
	-- 	end
	-- end
	-- if generate then
	-- 	tes3.addItem({ reference = victim, item = "random_pos" })
	-- 	tes3.addItem({ reference = victim, item = "random_pos" })
	-- 	tes3.addItem({ reference = victim, item = "random gold", count = 25 })
	-- 	tes3.addItem({ reference = victim, item = "random gold", count = 25 })
	-- end

	local menu = tes3ui.createMenu({ id = id_minigameProgressBar, dragFrame = true, fixedFrame = true })
	menu.alpha = 1.0
	-- align the menu (which consists just of the timer)
	menu.absolutePosAlignX = 0.5
	menu.absolutePosAlignY = 0.89

	-- timer block
	local timerblock = menu:createBlock({ id = "kcdpickpocket:menu2_chargeBlock" })
	timerblock.autoWidth = true
	timerblock.autoHeight = true
	timerblock.paddingAllSides = 4
	timerblock.paddingLeft = 2
	timerblock.paddingRight = 2
	local fillBar = timerblock:createFillBar({
		id = id_minigame_fillbar,
		current = timePassed,
		max = timePassed * timerResolution,
	})
	fillBar.width = 356
	fillBar.widget.showText = false
	fillBar.widget.fillColor = tes3ui.getPalette("magic_color")
	-- reset timer
	myTimer = timer.start({
		duration = timerDuration,
		type = timer.real,
		iterations = timePassed / timerDuration,
		callback = onMinigameTimerTick,
	})

	-- buttons
	local button_block = menu:createBlock {}
	button_block.widthProportional = 1.0 -- width is 100% parent width
	button_block.autoHeight = true
	button_block.childAlignX = 1.0    -- right content alignment

	local button_leave = button_block:createButton { id = id_ok, text = "Leave" }
	button_leave:register(tes3.uiEvent.mouseClick, function(e)
		log:debug("leave minigame")
		OnPickpocketMinigameEnd(false)
	end)

	-- item select
	ShowItemSelectmenu()

	-- Final setup
	menu:updateLayout()
	tes3ui.enterMenuMode(id_minigameProgressBar)
end

-- /////////////////////////////////////////////////////////////////

-- OK button callback.
local function onChargeOK(e)
	-- stop timer
	if myTimer then
		myTimer:cancel()
		myTimer = nil
	end

	local menu = tes3ui.findMenu(id_menu)
	if (menu) then
		-- tes3ui.leaveMenuMode()
		menu:destroy()
	end

	CreateMinigameMenu()
end

-- Cancel button callback.
local function onChargeCancel(e)
	-- stop timer
	if myTimer then
		myTimer:cancel()
		myTimer = nil
	end

	local menu = tes3ui.findMenu(id_menu)
	if (menu) then
		tes3ui.leaveMenuMode()
		menu:destroy()
	end
end

--- Count up timer
local function onChargeTimerTick()
	if myTimer == nil then
		return
	end

	-- enters
	-- check if enter was pressed and end charge
	if tes3.worldController.inputController:isKeyPressedThisFrame(tes3.scanCode.enter) then
		log:debug("isKeyPressedThisFrame")
		onChargeOK()

		return
	end

	-- cancels
	-- check if escape was pressed and end charge
	if tes3.worldController.inputController:isKeyPressedThisFrame(tes3.scanCode.escape) then
		log:debug("isKeyPressedThisFrame")
		onChargeCancel()

		return
	end
	-- check if right mouse buttton was pressed and end charge
	if tes3.worldController.inputController:isMouseButtonPressedThisFrame(1) then
		log:debug("isButtonPressed")
		onChargeCancel()

		return
	end

	-- TODO end if we move to far away from the victim

	-- fails
	-- also check if we are still in sneak mode
	if not isPlayerSneaking() then
		log:debug("not isPlayerSneaking")
		OnPickpocketMinigameEnd(true)

		return
	end

	timePassed = timePassed + timerDuration

	if timePassed >= detectionTime then
		-- we took too long
		log:debug("timePassed >= detectionTime during charge")
		OnPickpocketMinigameEnd(true)
	else
		-- update UI
		local menu = tes3ui.findMenu(id_menu)
		if (menu) then
			local fillBar = menu:findChild(id_fillbar)
			-- increment time
			fillBar.widget.current = timePassed * timerResolution
			-- increment color
			if timePassed < ((detectionTimeGuessed / 3) * 1) then
				fillBar.widget.fillColor = tes3ui.getPalette("fatigue_color")
			elseif timePassed < ((detectionTimeGuessed / 3) * 2) then
				fillBar.widget.fillColor = tes3ui.getPalette("health_npc_color")
			else
				fillBar.widget.fillColor = tes3ui.getPalette("health_color")
			end

			menu:updateLayout()
		end
	end
end

--- the timer menu that determins how much time you get with the minigame
local function CreateTimerMenu()
	-- Create window and frame
	local menu = tes3ui.createMenu { id = id_menu, dragFrame = true, fixedFrame = true }
	menu.alpha = 1.0

	-- Create layout
	local input_label = menu:createLabel { text = "Pickpocketing ..." }
	input_label.borderBottom = 5

	-- create timer
	local block = menu:createBlock({ id = "kcdpickpocket:menu1_chargeBlock" })
	block.autoWidth = true
	block.autoHeight = true
	block.paddingAllSides = 4
	block.paddingLeft = 2
	block.paddingRight = 2
	local fillBar = block:createFillBar({ id = id_fillbar, current = 0, max = maxDetectionTime * timerResolution })
	fillBar.widget.showText = false
	fillBar.widget.fillColor = tes3ui.getPalette("fatigue_color")
	-- reset timer
	timePassed = 0
	myTimer = timer.start({
		duration = timerDuration,
		type = timer.real,
		iterations = maxDetectionTime / timerDuration,
		callback = onChargeTimerTick,
	})

	-- buttons
	local button_block = menu:createBlock {}
	button_block.widthProportional = 1.0 -- width is 100% parent width
	button_block.autoHeight = true
	button_block.childAlignX = 1.0    -- right content alignment

	-- local button_cancel = button_block:createButton { id = id_cancel, text = "Cancel" }
	--local button_ok = button_block:createButton { id = id_ok, text = "Start" }

	-- Events
	-- button_cancel:register(tes3.uiEvent.mouseClick, onChargeCancel)
	--button_ok:register(tes3.uiEvent.mouseClick, onChargeOK)

	-- Final setup
	menu:updateLayout()
	-- tes3ui.enterMenuMode(id_menu)
end

-- /////////////////////////////////////////////////////////////////

--- Calculate how fast a victim will detect you pickpocketing
--- @param actor tes3reference
--- @param target tes3reference
local function CalculateDetectionTime(actor, target)
	if not victimHandle then
		return false
	end
	if not victimHandle:valid() then
		return false
	end

	local playerSkill = tes3.mobilePlayer.security.current
	local victimSkill = target.mobile.security.current

	-- max detection time is dependent on your skill
	-- value is 10 + playerSkill / 10
	maxDetectionTime = 10 + playerSkill / 10

	-- value is 10 + playerSkill / 10 - victimSkill / 10
	detectionTime = 10 + playerSkill / 10 - victimSkill / 10
	-- mwse.log("-------------------")
	-- mwse.log(detectionTime)

	-- other modifiers
	-- if detected ... -5
	if not isPlayerSneaking() then
		detectionTime = math.max(detectionTime - 5, 0);
		-- mwse.log("visible " .. detectionTime)
	end

	-- if in front ... -5, blind and invisibility victims can be pickpocketed from the front
	local blind = target.mobile.blind
	if (tes3.mobilePlayer.invisibility == 1) or (blind > 15) then
		-- invisibility grants a flat bonus
		detectionTime = detectionTime + 3
		-- mwse.log("invisibility " .. detectionTime)
	else
		local playerFacing = actor.facing
		local targetFacing = target.facing
		local diff = math.abs(playerFacing - targetFacing)
		if diff > math.pi then
			diff = math.abs(diff - (2 * math.pi))
		end
		if (diff < backstabAngle) then
			-- in the back: a slight bonus
			detectionTime = detectionTime + 1
			-- mwse.log("back " .. detectionTime)
		else
			detectionTime = math.max(detectionTime - 5, 0);
			-- mwse.log("front " .. detectionTime)
		end
	end

	-- noise: a distracted person would have a hard time detecting a thief, but could report one
	local sound = target.mobile.sound
	detectionTime = detectionTime + (sound / 10)
	-- mwse.log("sound " .. detectionTime)
	-- mwse.log("-------------------")

	detectionTime = math.min(detectionTime, maxDetectionTime - timerDuration)

	-- guess detection time
	local randomOffset = (100 - playerSkill) / 20
	local min = math.clamp(detectionTime - randomOffset, 0, detectionTime - randomOffset)
	detectionTimeGuessed = math.random(min, detectionTime + randomOffset)

	-- DBG
	-- tes3.messageBox(detectionTime .. " / " .. maxDetectionTime)
end

--- steal from NPC
--- @param e activateEventData
local function activateCallback(e)
	if e.target == nil then
		return
	end
	-- check if sneaking
	if tes3.mobilePlayer.isSneaking ~= true then
		return
	end
	-- check if npc
	local baseObject = e.target.baseObject
	if baseObject == nil then
		return
	end
	if baseObject.objectType ~= tes3.objectType.npc then
		return
	end
	-- check if not dead
	if e.target.isDead then
		return
	end

	-- taken from mort
	-- so many npcs have alarms of 0, its ridiculous
	-- debug.log(tes3.getPlayerTarget().mobile.alarm)
	-- if tes3.getPlayerTarget().mobile.alarm < 50 then
	-- 	tes3.getPlayerTarget().mobile.alarm = 50
	-- end

	-- make a new ui with a timer
	victimHandle = tes3.makeSafeObjectHandle(e.target)
	CalculateDetectionTime(e.activator, e.target)
	CreateTimerMenu()

	-- cancel normal steal menu
	return false
end
event.register(tes3.event.activate, activateCallback)

--- init mod
local function init()
	id_menu = tes3ui.registerID("kcdpickpocket:menu1")
	id_fillbar = tes3ui.registerID("kcdpickpocket:menu1_fillbar")
	id_ok = tes3ui.registerID("kcdpickpocket:menu1_ok")
	id_cancel = tes3ui.registerID("kcdpickpocket:menu1_cancel")

	id_minigameProgressBar = tes3ui.registerID("kcdpickpocket:menu2")
	id_minigame_fillbar = tes3ui.registerID("kcdpickpocket:menu2_fillbar")

	GUI_Pickpocket_multi = tes3ui.registerID("MenuMulti")
	GUI_Pickpocket_sneak = tes3ui.registerID("MenuMulti_sneak_icon")
end
event.register(tes3.event.initialized, init)
