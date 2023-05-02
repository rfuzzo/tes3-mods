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
-- TODO keep track of pickpocketed npcs
-- UI ids
local id_menu = nil
local id_ok = nil
local id_cancel = nil
local id_fillbar = nil
local id_minigame = nil
local id_minigame_fillbar = nil
local GUI_Pickpocket_multi = nil
local GUI_Pickpocket_sneak = nil

local pickpocketExpValue = 2
local itemsTaken = 0
local myTimer = nil
local timePassed = 0
local detectionTime = 10 -- the time after which the victim detects you
local maxDetectionTime = 20 -- the time after which the victim detects you
local detectionTimeGuessed = 10 -- how accurate you are with detecting the time left

local victim = nil
local crimeValue = 100 -- static crime value for when a victim detected you
local ready = false

local backstabDegrees = 80
local backstabAngle = (2 * math.pi) * (backstabDegrees / 360)

-- /////////////////////////////////////////////////////////////////

-- OK button callback.
local function onMinigameOK(e)
	local menu = tes3ui.findMenu(id_minigame)
	if (menu) then
		tes3ui.leaveMenuMode()
		menu:destroy()

		-- stop timer
		myTimer:cancel()
		myTimer = nil
	end
end

--- checks if any items can be stolen still
local function canStealItems()
	local playerSkill = tes3.mobilePlayer.security.current
	if (itemsTaken < 2 + (playerSkill / 10)) then
		return true
	else
		return false
	end
end

-- This function will filter items depending on certain parameters
local function valueFilter(e)
	-- filter items by value depending on your skill
	local playerSkill = tes3.mobilePlayer.security.current
	local isValueOk = e.item.value < 10 + (100 * playerSkill)

	-- filter on equipped
	local isItemEquipped = victim.object:hasItemEquipped(e.item, e.itemData)

	if (isValueOk and not isItemEquipped) then
		return true
	else
		return false
	end
end

--- Shows an item select menu
local function ShowItemSelectmenu()
	ready = false

	tes3ui.showInventorySelectMenu {
		reference = victim,
		title = "Pickpocket",
		noResultsText = "There are no items to steal.",
		filter = valueFilter,
		callback = function(e)
			if e.item then
				-- steal item
				tes3.transferItem({ from = victim, to = tes3.player, item = e.item, itemData = e.itemData, count = e.count })

				-- proc skill
				tes3.mobilePlayer:exerciseSkill(tes3.skill.security, pickpocketExpValue)
				ready = true

			end
		end,
	}
end

local function reportCrime()
	local blind = victim.mobile.blind
	local invisible = tes3.mobilePlayer.invisibility
	-- TODO crime report modifiers

	---@diagnostic disable-next-line: undefined-field
	tes3.worldController.mobController.processManager:detectPresence(tes3.mobilePlayer, true)
	tes3.triggerCrime({ type = 5, value = crimeValue, victim = victim })
end

--- Count down timer
local function onMinigameTimerTick()
	if myTimer == nil then
		return
	end

	timePassed = timePassed - 1

	if timePassed <= 0 then
		-- trigger crime for stealing
		if (victim) then
			reportCrime()
		end

		-- destroy timer
		myTimer:cancel()
		myTimer = nil

		-- destroy inventorySelectMenu if it exists
		local menu1 = tes3ui.findMenu("MenuInventorySelect")
		if (menu1) then
			tes3ui.leaveMenuMode()
			menu1:destroy()
		end
		-- leave minigame menu
		local menu = tes3ui.findMenu(id_minigame)
		if (menu) then
			tes3ui.leaveMenuMode()
			menu:destroy()
		end

	else
		-- update UI
		local menu = tes3ui.findMenu(id_minigame)
		if (menu) then
			local fillBar = menu:findChild(id_minigame_fillbar)
			-- decrement time
			fillBar.widget.current = timePassed

			menu:updateLayout()

			-- open the menu again
			if ready and canStealItems() then
				ShowItemSelectmenu()
			end
		end
	end

end

--- the actual pickpocket minigame
local function CreateMinigameMenu()
	if victim == nil then
		return
	end

	itemsTaken = 0;
	-- TODO always add some money to steal?
	tes3.addItem({ reference = victim, item = "random_bandit_1-5" })
	tes3.addItem({ reference = victim, item = "l_b_Bandit_goods" })
	tes3.addItem({ reference = victim, item = "l_n_smuggled_goods" }) -- random gold
	tes3.addItem({ reference = victim, item = "random gold", count = 25 }) -- 

	local menu = tes3ui.createMenu({ id = id_minigame, dragFrame = true, fixedFrame = true })
	menu.alpha = 1.0
	-- align the menu (which consists just of the timer)
	menu.absolutePosAlignX = 0.5
	menu.absolutePosAlignY = 0.9

	-- timer block
	local timerblock = menu:createBlock({ id = "kcdpickpocket:menu2_chargeBlock" })
	timerblock.autoWidth = true
	timerblock.autoHeight = true
	timerblock.paddingAllSides = 4
	timerblock.paddingLeft = 2
	timerblock.paddingRight = 2
	local fillBar = timerblock:createFillBar({ id = id_minigame_fillbar, current = timePassed, max = timePassed })
	fillBar.widget.showText = false
	fillBar.widget.fillColor = tes3ui.getPalette("magic_color")
	-- reset timer
	myTimer = timer.start({ duration = 1, type = timer.real, iterations = timePassed, callback = onMinigameTimerTick })

	-- buttons
	local button_block = menu:createBlock{}
	button_block.widthProportional = 1.0 -- width is 100% parent width
	button_block.autoHeight = true
	button_block.childAlignX = 1.0 -- right content alignment

	local button_ok = button_block:createButton{ id = id_ok, text = "Leave" }

	-- Events
	menu:register(tes3.uiEvent.keyEnter, onMinigameOK)
	button_ok:register(tes3.uiEvent.mouseClick, onMinigameOK)

	-- item select
	ShowItemSelectmenu()

	-- Final setup
	menu:updateLayout()
	tes3ui.enterMenuMode(id_minigame)

end

-- /////////////////////////////////////////////////////////////////

-- OK button callback.
local function onOK(e)
	local menu = tes3ui.findMenu(id_menu)
	if (menu) then
		tes3ui.leaveMenuMode()
		menu:destroy()

		-- stop timer
		myTimer:cancel()
		myTimer = nil

		CreateMinigameMenu()
	end
end

-- Cancel button callback.
local function onCancel(e)
	local menu = tes3ui.findMenu(id_menu)
	if (menu) then
		tes3ui.leaveMenuMode()
		menu:destroy()

		-- stop timer
		myTimer:cancel()
		myTimer = nil
	end
end

--- Count up timer
local function onChargeTimerTick()
	if myTimer == nil then
		return
	end

	timePassed = timePassed + 1

	if timePassed >= detectionTime then
		-- trigger crime for "just browsing"
		if (victim) then
			reportCrime()
		end

		-- destroy timer
		myTimer:cancel()
		myTimer = nil

		-- leave menu
		local menu = tes3ui.findMenu(id_menu)
		if (menu) then
			tes3ui.leaveMenuMode()
			menu:destroy()
		end

	else
		-- update UI
		local menu = tes3ui.findMenu(id_menu)
		if (menu) then
			local fillBar = menu:findChild(id_fillbar)
			-- increment time
			fillBar.widget.current = timePassed
			-- increment color
			if timePassed < (detectionTimeGuessed / (3 * 1)) then
				fillBar.widget.fillColor = tes3ui.getPalette("fatigue_color")
			elseif timePassed < (detectionTimeGuessed / (3 * 2)) then
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
	local input_label = menu:createLabel{ text = "Pickpocketing ..." }
	input_label.borderBottom = 5

	-- create timer
	local block = menu:createBlock({ id = "kcdpickpocket:menu1_chargeBlock" })
	block.autoWidth = true
	block.autoHeight = true
	block.paddingAllSides = 4
	block.paddingLeft = 2
	block.paddingRight = 2
	local fillBar = block:createFillBar({ id = id_fillbar, current = 0, max = maxDetectionTime })
	fillBar.widget.showText = true
	fillBar.widget.fillColor = tes3ui.getPalette("fatigue_color")
	-- reset timer
	timePassed = 0
	myTimer = timer.start({ duration = 1, type = timer.real, iterations = maxDetectionTime, callback = onChargeTimerTick })

	-- buttons
	local button_block = menu:createBlock{}
	button_block.widthProportional = 1.0 -- width is 100% parent width
	button_block.autoHeight = true
	button_block.childAlignX = 1.0 -- right content alignment

	local button_cancel = button_block:createButton{ id = id_cancel, text = "Cancel" }
	local button_ok = button_block:createButton{ id = id_ok, text = "OK" }

	-- Events
	button_cancel:register(tes3.uiEvent.mouseClick, onCancel)
	menu:register(tes3.uiEvent.keyEnter, onOK)
	button_ok:register(tes3.uiEvent.mouseClick, onOK)

	-- Final setup
	menu:updateLayout()
	tes3ui.enterMenuMode(id_menu)

end

-- /////////////////////////////////////////////////////////////////
--- Calculate how fast a victim will detect you pickpocketing
local function CalculateDetectionTime(actor, target)
	local playerSkill = tes3.mobilePlayer.security.current
	local victimSkill = target.mobile.security.current

	-- value is 10 + playerSkill / 10 - victimSkill / 10
	detectionTime = 10 + playerSkill / 10 - victimSkill / 10

	-- other modifiers
	-- if detected ... -5
	if (tes3ui.findMenu(GUI_Pickpocket_multi):findChild(GUI_Pickpocket_sneak).visible == false) then
		detectionTime = math.max(detectionTime - 5, 0);
	end

	-- if in front ... -5
	-- blind: a blinded person would still detect a thief, but couldn't report anyone
	-- player invisible or chameleon: same as blind
	local blind = victim.mobile.blind
	-- debug.log(blind)

	if tes3.mobilePlayer.invisibility < 1 then
		local playerFacing = actor.facing
		local targetFacing = target.facing
		local diff = math.abs(playerFacing - targetFacing)
		if diff > math.pi then
			diff = math.abs(diff - (2 * math.pi))
		end
		if (diff < backstabAngle) then
			-- in the back: a slight bonus
			detectionTime = detectionTime + 1
		else
			detectionTime = math.max(detectionTime - 5, 0);
		end
	end

	-- noise: a distracted person would have a hard time detecting a thief, but could report one
	local sound = victim.mobile.sound
	-- debug.log(sound)
	detectionTime = detectionTime + (sound / 10)

	-- guess detection time
	local randomOffset = (100 - playerSkill) / 20
	local min = math.clamp(detectionTime - randomOffset, 0, detectionTime - randomOffset)
	detectionTimeGuessed = math.random(min, detectionTime + randomOffset)

	-- max detection time is dependent on your skill
	-- value is 10 + playerSkill / 10
	maxDetectionTime = 10 + playerSkill / 10

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

	-- taken from mort
	-- so many npcs have alarms of 0, its ridiculous
	-- debug.log(tes3.getPlayerTarget().mobile.alarm)
	-- if tes3.getPlayerTarget().mobile.alarm < 50 then
	-- 	tes3.getPlayerTarget().mobile.alarm = 50
	-- end

	-- make a new ui with a timer
	victim = e.target
	CalculateDetectionTime(e.activator, e.target)
	CreateTimerMenu()

	-- cancel normal steal menu
	return false
end
event.register(tes3.event.activate, activateCallback)

--- innit mod
local function init()
	id_menu = tes3ui.registerID("kcdpickpocket:menu1")
	id_fillbar = tes3ui.registerID("kcdpickpocket:menu1_fillbar")
	id_ok = tes3ui.registerID("kcdpickpocket:menu1_ok")
	id_cancel = tes3ui.registerID("kcdpickpocket:menu1_cancel")

	id_minigame = tes3ui.registerID("kcdpickpocket:menu2")
	id_minigame_fillbar = tes3ui.registerID("kcdpickpocket:menu2_fillbar")

	GUI_Pickpocket_multi = tes3ui.registerID("MenuMulti")
	GUI_Pickpocket_sneak = tes3ui.registerID("MenuMulti_sneak_icon")
end
event.register(tes3.event.initialized, init)
