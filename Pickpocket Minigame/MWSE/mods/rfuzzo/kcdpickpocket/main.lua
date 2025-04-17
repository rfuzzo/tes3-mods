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

local logger = require("logging.logger")
local log = logger.new {
	name = "kcdpickpocket",
	logLevel = "DEBUG",
	logToConsole = false,
	includeTimestamp = false,
}

-- const
local PICKPOCKET_DISTANCE = 250
local TIMER_DURATION = 0.01
local TIMER_RESOLUTION = 1000
local MINIGAME_TIME_MULT = 10
local BACKSTAB_DEG = 80
local BACKSTAB_ANGLE = (2 * math.pi) * (BACKSTAB_DEG / 360)

local CRIME_VAL = 25 -- static crime value for when a victim detected you

-- experience
local EXP_TRIED = 1
local EXP_STARTED = 1
-- local EXP_SINGLE_ITEM = 0
local EXP_FINISHED = 2

-- IDs
local id_menu = nil ---@type number?
local id_ok = nil ---@type number?
-- local id_cancel = nil ---@type number?
local id_fillbar = nil ---@type number?
local id_minigameProgressBar = nil ---@type number?
local id_minigame_fillbar = nil ---@type number?
local GUI_Pickpocket_multi = nil ---@type number?
local GUI_Pickpocket_sneak = nil ---@type number?

---@enum EModState
local EModState = {
	NONE = 0,
	CHARGE = 1,
	MINIGAME = 2
}

-- variables
---@class SModData
---@field myTimer mwseTimer?
---@field timePassed number
---@field detectionTime number the time after which the victim detects you
---@field maxDetectionTime number the time after which the victim detects you
---@field detectionTimeGuessed number how accurate you are with detecting the time left
---@field victimHandle mwseSafeObjectHandle
---@field itemsStolen number
---@field state EModState

local modData = nil ---@type SModData?

-- /////////////////////////////////////////////////////////////////
-- LIB
-- /////////////////////////////////////////////////////////////////

local function isPlayerSneaking()
	return tes3ui.findMenu(GUI_Pickpocket_multi):findChild(GUI_Pickpocket_sneak).visible
end

---@param item tes3alchemy|tes3apparatus|tes3armor|tes3book|tes3clothing|tes3ingredient|tes3item|tes3light|tes3lockpick|tes3misc|tes3probe|tes3repairTool|tes3weapon
---@param itemData tes3itemData?
---@return boolean
local function canStealItem(item, itemData)
	if not item then
		return false
	end
	if not modData then
		return false
	end
	if not modData.victimHandle:valid() then
		return false
	end

	-- filter items by value depending on your skill
	local playerSkill = tes3.mobilePlayer.security.current
	local itemWeight = item.weight
	local isItemEquipped = modData.victimHandle:getObject().object:hasItemEquipped(item, itemData)

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

--- @param e tes3ui.showInventorySelectMenu.filterParams
local function valueFilter(e)
	return canStealItem(e.item, e.itemData)
end

--- @param victim tes3reference
local function reportCrime(victim)
	log:debug("reportCrime")

	tes3.worldController.mobManager.processManager:detectPresence(tes3.mobilePlayer, true)

	if tes3.mobilePlayer.isPlayerDetected then
		log:debug("triggerCrime")
		tes3.triggerCrime({ type = tes3.crimeType.theft, value = CRIME_VAL, victim = victim.mobile, forceDetection = false })
	end
end

--- @param shouldReportCrime boolean
local function CleanupAndReport(shouldReportCrime)
	assert(modData)

	log:debug("CleanupAndReport %s", shouldReportCrime)

	-- destroy timer
	if modData.myTimer then
		modData.myTimer:cancel()
		modData.myTimer = nil
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
	if (shouldReportCrime and modData.victimHandle:valid()) then
		log:debug("doreportcrime")

		reportCrime(modData.victimHandle:getObject())
	end

	tes3ui.leaveMenuMode()

	modData = nil
end

-- /////////////////////////////////////////////////////////////////
-- MINIGAME
-- /////////////////////////////////////////////////////////////////

--- @param e crimeWitnessedEventData
local function crimeWitnessedCallback(e)
	log:warn("crimeWitnessedCallback")
end
event.register(tes3.event.crimeWitnessed, crimeWitnessedCallback, { filter = tes3.crimeType.pickpocket })

-- NOTE this is for hiding elements
--- @param e itemTileUpdatedEventData
local function itemTileUpdatedCallback(e)
	if not modData then
		return
	end
	if modData.state == EModState.NONE then
		return
	end

	-- e.tile.element.visible = canStealItem(e.item, e.itemData)
	-- e.element:updateLayout()

	-- hook the clicked event
	e.tile.element:registerBefore(tes3.uiEvent.mouseClick, function()
		if not modData then
			return
		end
		if modData.state == EModState.NONE then
			return
		end

		local canSteal = canStealItem(e.item, e.itemData)

		log:warn("element clicked %s, can steal %s", e.item.name, canSteal)

		if not canSteal then
			-- cancel lower callbacks
			return false
		end
	end)
end
event.register(tes3.event.itemTileUpdated, itemTileUpdatedCallback)

local function getRequiredSkillLevel(item)
	local itemWeight = item.weight

	-- get level depending on weight
	local requiredSkillLevel = 0
	if itemWeight <= 2 then
		requiredSkillLevel = 1
	elseif itemWeight <= 15 then
		requiredSkillLevel = 25
	elseif itemWeight <= 30 then
		requiredSkillLevel = 50
	else
		requiredSkillLevel = 75
	end

	return requiredSkillLevel
end

--- @param e uiObjectTooltipEventData
local function uiObjectTooltipCallback(e)
	if not modData then
		return
	end
	if modData.state == EModState.NONE then
		return
	end

	if e.tooltip then
		local result = e.tooltip:findChild("HelpMenu_weight")
		if result then
			local parent = result.parent
			if parent then
				local canSteal = canStealItem(e.object)
				if not canSteal then
					local requiredSkillLevel = getRequiredSkillLevel(e.object)
					local label = parent:createLabel {
						text = "Required security: " .. requiredSkillLevel
					}
					label.color = tes3ui.getPalette(tes3.palette.healthFillColor)

					parent:reorderChildren(result, label, -1)
					e.tooltip:updateLayout()
				end
			end
		end
	end
end
event.register(tes3.event.uiObjectTooltip, uiObjectTooltipCallback)

--- @param e pickpocketEventData
local function pickpocketCallback(e)
	if not modData then
		return
	end
	if modData.state ~= EModState.MINIGAME then
		return
	end

	log:debug("pickpocketCallback")

	-- check value
	-- TODO make this better in the UI
	local canSteal = canStealItem(e.item, e.itemData)
	if canSteal then
		e.chance = 100

		modData.itemsStolen = modData.itemsStolen + 1
	else
		return false
	end
end
event.register(tes3.event.pickpocket, pickpocketCallback)

local function EndMinigame()
	modData.state = EModState.NONE
end

local function FailPickpocketMinigame()
	EndMinigame()
	CleanupAndReport(true)
end

local function CancelPickpocketMinigame()
	assert(modData)

	-- we award experience for successfully ending the minigame
	-- amount is dependent on the number of items stolen
	tes3.mobilePlayer:exerciseSkill(tes3.skill.security, modData.itemsStolen * EXP_FINISHED)

	EndMinigame()
	CleanupAndReport(false)
end

local function OnPickpocketStart()
	-- we award exerience for successfully ending the charge and starting the minigame
	tes3.mobilePlayer:exerciseSkill(tes3.skill.security, EXP_STARTED)

	modData.state = EModState.MINIGAME
end

--- Shows an item select menu
--- @return boolean
local function ShowItemSelectmenu()
	assert(modData)

	if not modData.victimHandle:valid() then
		return false
	end

	local wasShown = tes3.showContentsMenu({ reference = modData.victimHandle:getObject(), pickpocket = true })

	if wasShown then
		OnPickpocketStart()

		local menu = tes3ui.findMenu("MenuContents")
		if (menu) then
			-- hide take all button
			menu:findChild("MenuContents_takeallbutton").visible = false

			-- hook into the destroy event
			menu:registerAfter(tes3.uiEvent.destroy, function()
				log:debug("destroy")
				if modData then
					CancelPickpocketMinigame()
				end
			end)
		end
	end

	return wasShown
end

--- Count down timer
local function onMinigameTimerTick()
	assert(modData)

	if modData.myTimer == nil then
		return
	end

	modData.timePassed = modData.timePassed - TIMER_DURATION

	if modData.timePassed <= TIMER_DURATION then
		-- we took too long
		log:debug("Pickpocket failed: out of time")
		FailPickpocketMinigame()
	else
		-- update UI
		local menu = tes3ui.findMenu(id_minigameProgressBar)
		if (menu) then
			local fillBar = menu:findChild(id_minigame_fillbar)
			if (fillBar) then
				-- decrement time
				fillBar.widget.current = modData.timePassed * TIMER_RESOLUTION

				menu:updateLayout()
			end
		end
	end
end

--- the actual pickpocket minigame
local function CreateMinigameMenu()
	assert(modData)

	-- set time passed to be double
	modData.timePassed = modData.timePassed * MINIGAME_TIME_MULT

	-- create UI
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
		current = modData.timePassed,
		max = modData.timePassed * TIMER_RESOLUTION,
	})
	fillBar.width = 356
	fillBar.widget.showText = false
	fillBar.widget.fillColor = tes3ui.getPalette("magic_color")

	-- reset timer
	modData.myTimer = timer.start({
		duration = TIMER_DURATION,
		type = timer.real,
		iterations = modData.timePassed / TIMER_DURATION,
		callback = onMinigameTimerTick,
	})

	log:debug("Pickpocket started with %s s", modData.timePassed)

	-- buttons
	local button_block = menu:createBlock {}
	button_block.widthProportional = 1.0 -- width is 100% parent width
	button_block.autoHeight = true
	button_block.childAlignX = 1.0    -- right content alignment

	local button_leave = button_block:createButton { id = id_ok, text = "Leave" }
	button_leave:register(tes3.uiEvent.mouseClick, function(e)
		log:debug("Pickpocket canceled")
		CancelPickpocketMinigame()
	end)

	-- item select
	if ShowItemSelectmenu() then
		-- Final setup
		menu:updateLayout()
		tes3ui.enterMenuMode(id_minigameProgressBar)
	else
		menu:destroy()
		tes3ui.leaveMenuMode()
	end
end

-- /////////////////////////////////////////////////////////////////
-- CHARGE
-- /////////////////////////////////////////////////////////////////

local function OnChargeFailed()
	CleanupAndReport(true)
end

-- Cancel button callback.
local function CancelCharge(e)
	assert(modData)

	-- stop timer
	if modData.myTimer then
		modData.myTimer:cancel()
		modData.myTimer = nil
	end

	local menu = tes3ui.findMenu(id_menu)
	if (menu) then
		menu:destroy()
	end

	CleanupAndReport(false)
end

-- OK button callback.
local function StartMinigame(e)
	assert(modData)

	-- stop timer
	if modData.myTimer then
		modData.myTimer:cancel()
		modData.myTimer = nil
	end

	local menu = tes3ui.findMenu(id_menu)
	if (menu) then
		menu:destroy()
	end

	CreateMinigameMenu()
end


local function onChargeTimerTick()
	if not modData then
		return
	end

	-- fails
	--  end if we move to far away from the victim
	local distance = tes3.player.position:distance(modData.victimHandle:getObject().position)
	if distance > PICKPOCKET_DISTANCE then
		log:debug("Charge failed: distance > 200")
		OnChargeFailed()
		return
	end

	-- also check if we are still in sneak mode
	if not isPlayerSneaking() then
		log:debug("Charge failed: not sneaking")
		OnChargeFailed()
		return
	end

	modData.timePassed = modData.timePassed + TIMER_DURATION

	if modData.timePassed >= modData.detectionTime then
		-- we took too long
		log:debug("Charge failed: out of time")
		OnChargeFailed()
		return
	end

	-- update UI
	local menu = tes3ui.findMenu(id_menu)
	if (menu) then
		local fillBar = menu:findChild(id_fillbar)
		if (fillBar) then
			-- increment time
			fillBar.widget.current = modData.timePassed * TIMER_RESOLUTION
			-- increment color
			if modData.timePassed < ((modData.detectionTimeGuessed / 3) * 1) then
				fillBar.widget.fillColor = tes3ui.getPalette("fatigue_color")
			elseif modData.timePassed < ((modData.detectionTimeGuessed / 3) * 2) then
				fillBar.widget.fillColor = tes3ui.getPalette("health_npc_color")
			else
				fillBar.widget.fillColor = tes3ui.getPalette("health_color")
			end

			menu:updateLayout()
		end
	end
end

---@param data SModData
local function OnChargeStart(data)
	-- reset timer
	data.myTimer = timer.start({
		duration = TIMER_DURATION,
		type = timer.simulate,
		iterations = data.maxDetectionTime / TIMER_DURATION,
		callback = onChargeTimerTick,
	})

	data.state = EModState.CHARGE

	-- we award experience for trying to pickpocket
	tes3.mobilePlayer:exerciseSkill(tes3.skill.security, EXP_TRIED)
end

--- the timer menu that determins how much time you get with the minigame
--- @param data SModData
local function CreateChargeMenu(data)
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
	local fillBar = block:createFillBar({ id = id_fillbar, current = 0, max = data.maxDetectionTime * TIMER_RESOLUTION })
	fillBar.widget.showText = false
	fillBar.widget.fillColor = tes3ui.getPalette("fatigue_color")

	-- Final setup
	menu:updateLayout()
	-- tes3ui.enterMenuMode(id_menu)

	OnChargeStart(data)
end

-- /////////////////////////////////////////////////////////////////
-- EVENTS
-- /////////////////////////////////////////////////////////////////

--- @param e keyUpEventData
local function keyUpCallback(e)
	if not modData then
		return
	end

	if modData.state == EModState.CHARGE then
		-- check if escape was pressed and end charge
		if e.keyCode == tes3.scanCode.escape then
			log:debug("isKeyPressedThisFrame escape")

			CancelCharge()

			return
			-- check if enter was pressed and start minigame
		elseif e.keyCode == tes3.scanCode.enter then
			log:debug("isKeyPressedThisFrame enter")

			StartMinigame()

			return
		end
	elseif modData.state == EModState.MINIGAME then
		-- check if enter was pressed and end minigame
		if e.keyCode == tes3.scanCode.enter then
			log:debug("Pickpocket canceled")

			CancelPickpocketMinigame()

			return
		end
	end
end
event.register(tes3.event.keyUp, keyUpCallback)

--- @param e mouseButtonUpEventData
local function mouseButtonUpCallback(e)
	if not modData then
		return
	end

	if modData.state == EModState.CHARGE then
		-- check if right mouse buttton was pressed and end charge
		if e.button == 1 then
			log:debug("Charge canceled")

			CancelCharge()

			return
		end
	elseif modData.state == EModState.MINIGAME then
		-- check if right mouse buttton was pressed and end charge
		if e.button == 1 then
			log:debug("Minigame canceled")

			CancelPickpocketMinigame()

			return
		end
	end
end
event.register(tes3.event.mouseButtonUp, mouseButtonUpCallback)


-- /////////////////////////////////////////////////////////////////
-- INIT
-- /////////////////////////////////////////////////////////////////

--- Calculate how fast a victim will detect you pickpocketing
--- @param actor tes3reference
--- @param target tes3reference
local function CalculateDetectionTime(data, actor, target)
	local playerSkill = tes3.mobilePlayer.security.current
	local victimSkill = target.mobile.security.current

	-- max detection time is dependent on your skill
	-- value is 10 + playerSkill / 10
	data.maxDetectionTime = 10 + playerSkill / 10

	-- value is 10 + playerSkill / 10 - victimSkill / 10
	data.detectionTime = 10 + playerSkill / 10 - victimSkill / 10
	-- mwse.log("-------------------")
	-- mwse.log(detectionTime)

	-- other modifiers
	-- if detected ... -5
	if not isPlayerSneaking() then
		data.detectionTime = math.max(data.detectionTime - 5, 0);
		-- mwse.log("visible " .. detectionTime)
	end

	-- if in front ... -5, blind and invisibility victims can be pickpocketed from the front
	local blind = target.mobile.blind
	if (tes3.mobilePlayer.invisibility == 1) or (blind > 15) then
		-- invisibility grants a flat bonus
		data.detectionTime = data.detectionTime + 3
		-- mwse.log("invisibility " .. detectionTime)
	else
		local playerFacing = actor.facing
		local targetFacing = target.facing
		local diff = math.abs(playerFacing - targetFacing)
		if diff > math.pi then
			diff = math.abs(diff - (2 * math.pi))
		end
		if (diff < BACKSTAB_ANGLE) then
			-- in the back: a slight bonus
			data.detectionTime = data.detectionTime + 1
			-- mwse.log("back " .. detectionTime)
		else
			data.detectionTime = math.max(data.detectionTime - 5, 0);
			-- mwse.log("front " .. detectionTime)
		end
	end

	-- noise: a distracted person would have a hard time detecting a thief, but could report one
	local sound = target.mobile.sound
	data.detectionTime = data.detectionTime + (sound / 10)
	-- mwse.log("sound " .. detectionTime)
	-- mwse.log("-------------------")

	data.detectionTime = math.min(data.detectionTime, data.maxDetectionTime - TIMER_DURATION)

	-- guess detection time
	local randomOffset = (100 - playerSkill) / 20
	local min = math.clamp(data.detectionTime - randomOffset, 0, data.detectionTime - randomOffset)
	data.detectionTimeGuessed = math.random(min, data.detectionTime + randomOffset)

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

	-- check if already pickpocketing
	if modData then
		if modData.state == EModState.CHARGE then
			StartMinigame()
		end

		return false
	end

	-- taken from mort
	-- so many npcs have alarms of 0, its ridiculous
	if e.target.mobile.alarm < 50 then
		e.target.mobile.alarm = 50
	end

	-- make a new ui with a timer
	modData = {
		myTimer = nil,
		timePassed = 0,
		detectionTime = 10,
		maxDetectionTime = 20,
		detectionTimeGuessed = 10,
		victimHandle = tes3.makeSafeObjectHandle(e.target),
		itemsStolen = 0,
		state = EModState.NONE
	}

	CalculateDetectionTime(modData, e.activator, e.target)
	CreateChargeMenu(modData)

	-- cancel normal steal menu
	return false
end
event.register(tes3.event.activate, activateCallback)

--- init mod
local function init()
	id_menu = tes3ui.registerID("kcdpickpocket:menu1")
	id_fillbar = tes3ui.registerID("kcdpickpocket:menu1_fillbar")
	id_ok = tes3ui.registerID("kcdpickpocket:menu1_ok")
	-- id_cancel = tes3ui.registerID("kcdpickpocket:menu1_cancel")

	id_minigameProgressBar = tes3ui.registerID("kcdpickpocket:menu2")
	id_minigame_fillbar = tes3ui.registerID("kcdpickpocket:menu2_fillbar")

	GUI_Pickpocket_multi = tes3ui.registerID("MenuMulti")
	GUI_Pickpocket_sneak = tes3ui.registerID("MenuMulti_sneak_icon")
end
event.register(tes3.event.initialized, init)
