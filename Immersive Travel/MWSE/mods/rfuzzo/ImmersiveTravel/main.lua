local test_menu = tes3ui.registerID("example:MenuTest")
local test_menu_ok = tes3ui.registerID("example:MenuTest_Ok")
local test_menu_cancel = tes3ui.registerID("example:MenuTest_Cancel")

local trace_menu = tes3ui.registerID("example:MenuTrace")
local trace_menu_cancel = tes3ui.registerID("example:MenuTrace_Cancel")
local trace_menu_start = tes3ui.registerID("example:MenuTrace_Start")
local trace_menu_stop = tes3ui.registerID("example:MenuTrace_Stop")
local trace_menu_save = tes3ui.registerID("example:MenuTrace_Save")

local speed = 2 -- the speed of the object in units per frame
local angle = 0.005 -- the angle of rotation in radians per frame

local normal = 1.7

local obj = nil
local started = false
local i = 1

local is_trace = false;
local last_spline_pos = { x = 0, y = 0, z = 0 }
local current_spline = {}

local last_dir = nil
local last_facing = nil

local sn = require("rfuzzo.ImmersiveTravel.data.sn")

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// LOGIC

local function getLookedAtReference()
	-- Get the player's eye position and direction.
	local eyePos = tes3.getPlayerEyePosition()
	local eyeDir = tes3.getPlayerEyeVector()

	-- Perform a ray test from the eye position along the eye direction.
	local result = tes3.rayTest({ position = eyePos, direction = eyeDir, ignore = { tes3.player } })

	-- If the ray hit something, return the reference of the object.
	if (result) then
		return result.reference
	end

	-- Otherwise, return nil.
	return nil
end

-- Define a variable for the current index of the coordinate
local index = 1

-- Define a variable for the interpolation factor
local factor = 0

--- @param e simulateEventData
local function moveObj(e)
	if obj == nil then
		return;
	end
	if not started then
		return;
	end

	if i <= #sn.spline then -- if i is not at the end of the list

		local s = sn.spline[i]
		local next_pos = tes3vector3.new(s.x, s.y, s.z - 700)
		local d = next_pos - obj.position -- get the direction vector from the object to the coordinate
		local dist = d:length() -- get the distance from the object to the coordinate
		d:normalize()

		local d_n = d
		-- if last_dir ~= nil then
		-- 	d_n = (d + last_dir) / normal
		-- end
		-- last_dir = d_n

		-- position

		if dist > speed then -- if the distance is greater than the speed
			-- normalize the direction vector
			obj.position = obj.position + (d_n * speed) -- move the object by speed units along the direction vector
		else -- if the distance is less than or equal to the speed
			obj.position = next_pos -- set the object position to the coordinate position
			i = i + 1 -- increment i by 1
		end

		-- heading
		local current_facing = obj.facing
		local new_facing = math.atan2(d_n.x, d_n.y)
		obj.facing = new_facing

		-- logging
		mwse.log(obj.position.x .. "," .. obj.position.y .. "," .. d_n.x .. ", " .. d_n.y .. "," .. new_facing)

	else -- if i is at the end of the list
		-- cleanup all
		obj = nil
		started = false
		last_dir = nil
		i = 1
		tes3.messageBox("ended")
	end
end

event.register(tes3.event.simulate, moveObj) -- register the moveObj function to run every frame

--- @param e simulateEventData
local function traceSpline(e)
	if not is_trace then
		return
	end

	-- todo: 
	local eyePos = tes3.getPlayerEyePosition()
	local pos = { x = math.floor(eyePos.x), y = math.floor(eyePos.y), z = math.floor(eyePos.z) }

	if last_spline_pos.x == pos.x and last_spline_pos.y == pos.y and last_spline_pos.z == pos.z then
		return
	end

	last_spline_pos = pos
	table.insert(current_spline, pos)

end
event.register(tes3.event.simulate, traceSpline)

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// TEST WINDOW

-- OK button callback.
local function onTestOK(e)
	local menu = tes3ui.findMenu(test_menu)

	if (menu) then
		tes3.messageBox(obj.baseObject.name)
		started = true
		tes3ui.leaveMenuMode()
		menu:destroy()
	end
end

-- Cancel button callback.
local function onTestCancel(e)
	local menu = tes3ui.findMenu(test_menu)

	if (menu) then
		tes3ui.leaveMenuMode()
		menu:destroy()
	end
end

-- Create window and layout. Called by onCommand.
local function createTestWindow()
	-- Return if window is already open
	if (tes3ui.findMenu(test_menu) ~= nil) then
		return
	end

	-- Create window and frame
	local menu = tes3ui.createMenu { id = test_menu, fixedFrame = true }

	-- To avoid low contrast, text input windows should not use menu transparency settings
	menu.alpha = 1.0

	-- Create layout
	local input_label = menu:createLabel{ text = "Start" }
	input_label.borderBottom = 5

	local input_block = menu:createBlock{}
	input_block.width = 300
	input_block.autoHeight = true
	input_block.childAlignX = 0.5 -- centre content alignment

	local button_block = menu:createBlock{}
	button_block.widthProportional = 1.0 -- width is 100% parent width
	button_block.autoHeight = true
	button_block.childAlignX = 1.0 -- right content alignment

	local button_cancel = button_block:createButton{ id = test_menu_cancel, text = "Cancel" }
	local button_ok = button_block:createButton{ id = test_menu_ok, text = "Start" }

	-- Events
	button_cancel:register(tes3.uiEvent.mouseClick, onTestCancel)
	button_ok:register(tes3.uiEvent.mouseClick, onTestOK)

	-- Final setup
	menu:updateLayout()
	tes3ui.enterMenuMode(test_menu)
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// LOG WINDOW

-- Cancel button callback.
local function onLogCancel(e)
	local menu = tes3ui.findMenu(trace_menu)
	if (menu) then
		tes3ui.leaveMenuMode()
		menu:destroy()
	end
end

-- Start button callback.
local function onLogStart(e)
	local menu = tes3ui.findMenu(trace_menu)
	if (menu) then
		is_trace = true
		tes3ui.leaveMenuMode()
		menu:destroy()
	end
end

-- Stop button callback.
local function onLogStop(e)
	local menu = tes3ui.findMenu(trace_menu)
	if (menu) then
		is_trace = false
		tes3ui.leaveMenuMode()
		menu:destroy()
	end
end

-- Save button callback.
local function onLogSave(e)
	local menu = tes3ui.findMenu(trace_menu)
	if (menu) then
		mwse.log("===============================")
		for k, v in pairs(current_spline) do
			mwse.log("{ x = " .. v.x .. ", y = " .. v.y .. ", z = " .. v.z .. "}, ")
		end

		mwse.log("===============================")

		current_spline = {}

		tes3ui.leaveMenuMode()
		menu:destroy()
	end
end

local function createLogWindow()
	-- Return if window is already open
	if (tes3ui.findMenu(trace_menu) ~= nil) then
		return
	end

	-- Create window and frame
	local menu = tes3ui.createMenu { id = trace_menu, fixedFrame = true }

	-- To avoid low contrast, text input windows should not use menu transparency settings
	menu.alpha = 1.0

	-- Create layout
	local input_label = menu:createLabel{ text = "Trace" }
	input_label.borderBottom = 5

	local input_block = menu:createBlock{}
	input_block.width = 600
	input_block.autoHeight = true
	input_block.childAlignX = 0.5 -- centre content alignment

	local button_block = menu:createBlock{}
	button_block.widthProportional = 1.0 -- width is 100% parent width
	button_block.autoHeight = true
	button_block.childAlignX = 1.0 -- right content alignment

	local button_cancel = button_block:createButton{ id = trace_menu_cancel, text = "Cancel" }
	local button_start = button_block:createButton{ id = trace_menu_start, text = "Start" }
	local button_stop = button_block:createButton{ id = trace_menu_stop, text = "Stop" }
	local button_save = button_block:createButton{ id = trace_menu_save, text = "Save" }

	-- Events
	button_cancel:register(tes3.uiEvent.mouseClick, onLogCancel)
	button_start:register(tes3.uiEvent.mouseClick, onLogStart)
	button_stop:register(tes3.uiEvent.mouseClick, onLogStop)
	button_save:register(tes3.uiEvent.mouseClick, onLogSave)

	-- Final setup
	menu:updateLayout()
	tes3ui.enterMenuMode(trace_menu)
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// GLOBAL COMMANDS

-- Keydown callback.
local function onSlashCommand(e)
	-- local t = tes3.getPlayerTarget()
	local t = getLookedAtReference()
	if (t) then
		-- local bo = t.object.baseObject or t.object -- Select actor base object
		obj = t
		local ori = t.orientation
		tes3.messageBox(ori.x .. ", " .. ori.y .. ", " .. ori.z)
		createTestWindow()
	end
end

-- Keydown callback.
local function onHashCommand(e)
	createLogWindow()
end

event.register(tes3.event.keyDown, onSlashCommand, { filter = tes3.scanCode["/"] }) -- "/" key
event.register(tes3.event.keyDown, onHashCommand, { filter = tes3.scanCode["-"] }) -- "/" key

