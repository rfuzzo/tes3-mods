--[[
  Gothic 2 lockpicking
  by rfuzzo
  version 1.0

  Implements a gothic-like lockpicking minigame.

	- uses charges of lockpick each attempt
	- may break lockpick completely on fail (uses vanilla formula)
]] --
-- dbg
local ENABLE_MOD = true
local ENABLE_LOG = false

-- const
local lockpickAttemptExpValue = 1
local lockpickSuccessExpValueBase = 2
local pickConditionSub = 10 -- how much condition a pick loses on fail

-- ui
local id_menu = nil
local id_left = nil
local id_right = nil
local id_cancel = nil

-- logic
local currentRef = nil
local currentSequence = {}
local currentAttempt = {}
--- @type number | nil
local currentLockLevel = nil
--- @type number | nil
local currentPickQuality = nil
--- @type tes3itemData | nil
local currentPickData = nil
local currentPickName = ""
--- @type tes3item | nil
local currentPick = nil

-- ///////////////////////////////////////////////////////////////
-- LOCALS

--- @param s tes3vector3
--- @return {}
local function GetCombination(s)
	-- generate sequence
	local hash = 16777619
	-- for i = 1, #s do
	-- 	local c = s:sub(i, i)
	-- 	hash = hash * string.byte(c)
	-- end
	hash = math.round(hash * s.x * s.y * s.z)
	local hashStr = string.format("%.f", hash)

	-- reverse hash
	local sequence = {}
	-- clamp length of sequence by lock level: 
	-- y = 2 + (x * 2 / 11)
	local sequenceMax = math.round(2 + (currentLockLevel * 2 / 11))
	local max = math.min(#hashStr, sequenceMax)
	for i = 1, max do
		local idxRev = #hashStr + 1 - i
		local c = hashStr:sub(idxRev, idxRev)

		if tonumber(c) < 5 then
			sequence[i] = "L"
		else
			sequence[i] = "R"
		end

	end

	if ENABLE_LOG then
		debug.log(s)
		debug.log(hash)
		debug.log(hashStr)
		debug.log(sequenceMax)
	end

	return sequence
end

--- picked the wrong sequence
local function EndAttempt()
	-- play lockpick fail sound
	tes3.playSound({ sound = "Open Lock Fail" })

	-- exit menu
	local menu = tes3ui.findMenu(id_menu)
	if (menu) then
		tes3ui.leaveMenuMode()
		menu:destroy()
	end

	-- calculate vanilla unlock chance
	local mp = tes3.mobilePlayer
	local chance = 0.2 * mp.agility.current + 0.1 * mp.luck.current + mp.security.current;
	chance = chance * currentPickQuality * mp:getFatigueTerm();
	chance = chance + (tes3.findGMST("fPickLockMult").value * currentLockLevel);

	-- random roll
	local rnd = math.random(100)

	if ENABLE_LOG then
		debug.log(mp.agility.current)
		debug.log(mp.luck.current)
		debug.log(mp.security.current)
		debug.log(currentPickQuality)
		debug.log(mp:getFatigueTerm())
		debug.log(tes3.findGMST("fPickLockMult").value)
		debug.log(currentLockLevel)
		debug.log(rnd)
	end

	--- break lockpick
	if rnd > chance then

		---@diagnostic disable-next-line: param-type-mismatch
		tes3.messageBox(tes3.findGMST("sLockFail").value)

		-- break lockpick
		-- currentPickData.condition = 0
		if currentPickData ~= nil and currentPick ~= nil then
			-- local newCondition = math.max(0, currentPickData.condition - pickConditionSub)
			local newCondition = currentPickData.condition - pickConditionSub
			currentPickData.condition = newCondition

			-- delete and notify
			if newCondition <= 0 then
				---@diagnostic disable-next-line: assign-type-mismatch
				tes3.removeItem({ reference = tes3.player, item = currentPick, itemData = currentPickData })
				tes3.messageBox(currentPickName .. " has been used up.")
			end
		end
	end
end

--- Unlocks the container
local function Unlock()
	tes3.playSound({ sound = "Open Lock" })

	-- exit menu
	local menu = tes3ui.findMenu(id_menu)
	if (menu) then
		tes3ui.leaveMenuMode()
		menu:destroy()
	end

	-- proc skill
	tes3.mobilePlayer:exerciseSkill(tes3.skill.security, lockpickSuccessExpValueBase * currentLockLevel * 0.1)

	-- unlock reference
	tes3.unlock({ reference = currentRef })

	---@diagnostic disable-next-line: param-type-mismatch
	tes3.messageBox(tes3.findGMST("sLockSuccess").value)
end

local function Validate()
	-- decrease pick use
	if currentPickData ~= nil then
		currentPickData.charge = currentPickData.charge - 1
	end

	-- proc skill
	tes3.mobilePlayer:exerciseSkill(tes3.skill.security, lockpickAttemptExpValue)

	for i, value in ipairs(currentAttempt) do
		if currentSequence[i] ~= value then
			EndAttempt()
			return
		end
	end

	-- if we make it here, we unlock the container
	if #currentAttempt == #currentSequence then
		Unlock()
	end

end

-- ///////////////////////////////////////////////////////////////
-- UI

-- Cancel button callback.
local function onCancel(e)
	local menu = tes3ui.findMenu(id_menu)
	if (menu) then
		tes3ui.leaveMenuMode()
		menu:destroy()
	end
end

-- Cancel button callback.
local function onLeft(e)
	table.insert(currentAttempt, "L")
	Validate()
end

-- Cancel button callback.
local function onRight(e)
	table.insert(currentAttempt, "R")
	Validate()
end

--- the timer menu that determins how much time you get with the minigame 
local function CreateLockpickMenu()
	-- Create window and frame
	local menu = tes3ui.createMenu { id = id_menu, dragFrame = true, fixedFrame = true }
	menu.alpha = 1.0

	-- Create layout
	local input_label = menu:createLabel{ text = "Lockpicking ..." }
	input_label.borderBottom = 5

	-- buttons
	local button_block = menu:createBlock{}
	button_block.widthProportional = 1.0 -- width is 100% parent width
	button_block.autoHeight = true
	button_block.autoWidth = true
	button_block.childAlignX = 1.0 -- right content alignment

	local button_cancel = button_block:createButton{ id = id_cancel, text = "Cancel" }
	local button_left = button_block:createButton{ id = id_left, text = "<" }
	local button_right = button_block:createButton{ id = id_right, text = ">" }

	-- Events
	button_cancel:register(tes3.uiEvent.mouseClick, onCancel)

	button_left:register(tes3.uiEvent.mouseClick, onLeft)
	button_right:register(tes3.uiEvent.mouseClick, onRight)

	-- TODO register keys
	-- menu:register(tes3.uiEvent.keyEnter, onOK)
	-- menu:register(tes3.uiEvent.keyEnter, onOK)

	-- Final setup
	menu:updateLayout()
	tes3ui.enterMenuMode(id_menu)

end

-- ///////////////////////////////////////////////////////////////
-- EVENTS

--- @param e lockPickEventData
local function lockPickCallback(e)
	if ENABLE_MOD == false then
		return
	end
	-- special case for skeleton_key
	if e.tool.id == "skeleton_key" then
		return
	end

	-- only care about actually locked chests
	if e.lockPresent == false then
		return
	end

	-- cleanup
	currentSequence = {}
	currentAttempt = {}
	currentRef = e.reference
	currentLockLevel = e.lockData.level
	currentPickName = e.tool.name
	currentPickQuality = e.tool.quality
	currentPickData = e.toolItemData
	currentPick = e.tool

	-- on lockpicking
	local pos = e.reference.position
	currentSequence = GetCombination(pos)

	if ENABLE_LOG then
		local dbg = ""
		for _, value in ipairs(currentSequence) do
			dbg = dbg .. value
		end
		tes3.messageBox("Level: " .. e.lockData.level .. " Chance: " .. e.chance .. " Lock: " .. dbg)
		mwse.log("Level: " .. e.lockData.level .. " Chance: " .. e.chance .. " Lock: " .. dbg)
	end

	-- make ui
	CreateLockpickMenu()

	-- claim the event
	return false
end
event.register(tes3.event.lockPick, lockPickCallback)

--- init mod
local function init()
	id_menu = tes3ui.registerID("gothiclockpick:menu1")
	id_left = tes3ui.registerID("gothiclockpick:menu1_left")
	id_right = tes3ui.registerID("gothiclockpick:menu1_right")
	id_cancel = tes3ui.registerID("gothiclockpick:menu1_cancel")
end
event.register(tes3.event.initialized, init)
