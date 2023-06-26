--[[
Immersive Travel Mod
v 0.1
by rfuzzo

mwse real-time travel mod

---
Current Usage (Debug)
- render current route 						... p key
- move a marker 									... L-Ctrl
- delete a marker 								... Del
- exit edit mode 									... L-Ctrl
- add a marker										... <
- log the current marker list 		... >
- display distance to ground 			... o
- 

to refactor:
- to start traveling	... / on the silt strider in Seyda Neen --]] -- 
-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// VARIABLES
local edit_menu = tes3ui.registerID("it:MenuEdit")
local edit_menu_display = tes3ui.registerID("it:MenuEdit_Display")
local edit_menu_cancel = tes3ui.registerID("it:MenuEdit_Cancel")

local test_menu = tes3ui.registerID("it:test_menu")
local test_menu_ok = tes3ui.registerID("it:test_menu_ok")
local test_menu_cancel = tes3ui.registerID("it:test_menu_cancel")

---@type mwseTimer | nil
local myTimer = nil
local spline_index = 1
local speed = 4 -- the speed of the object in units per timertick
local angle = 0.002 -- the angle of rotation in radians per timertick
local timertick = 0.01

local current_travel_target = ""

local data = require("rfuzzo.ImmersiveTravel.data.data")
local current_data = "sb_bm"

---@type tes3reference | nil
local mount = nil
local mountOffset = tes3vector3.new(0, 0, -1100)

-- editor
local editmode = false
local editor_marker = "marker_arrow.nif"
---@type niNode[]
local editor_markers = {}
local editor_instance = nil

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// LOGIC

--- @return table<string, table>
local function get_current_spline()
    -- get currently selected spline
    local inverted = string.endswith(current_travel_target, ".inv")
    if inverted then return table.invert(data.splines[current_travel_target]) end
    return data.splines[current_travel_target]
end

local function get_current_editor_spline()
    -- get currently selected spline
    return data.splines[current_data]
end

local function getLookedAtReference()
    -- Get the player's eye position and direction.
    local eyePos = tes3.getPlayerEyePosition()
    local eyeDir = tes3.getPlayerEyeVector()

    -- Perform a ray test from the eye position along the eye direction.
    local result = tes3.rayTest({
        position = eyePos,
        direction = eyeDir,
        ignore = {tes3.player}
    })

    -- If the ray hit something, return the reference of the object.
    if (result) then return result.reference end

    -- Otherwise, return nil.
    return nil
end

---@param a number
---@return tes3matrix33
local function rotation_matrix_z(a)
    local c = math.cos(a)
    local s = math.sin(a)
    return tes3matrix33.new(c, -s, 0, s, c, 0, 0, 0, 1)
end

local function raytest()
    local from = tes3.player.position
    local rayhit = tes3.rayTest {
        position = from,
        direction = tes3vector3.new(0, 0, -1),
        returnNormal = true
    }

    if (rayhit) then
        local to = rayhit.intersection
        local dist = to.z - from.z
        tes3.messageBox("DIST( " .. dist .. " ) - FROM (" .. from.z .. ")" ..
                            "TO (" .. to.z .. ")")

    end

end

--- @param from tes3vector3
--- @return number|nil
local function getDistToGround(from)
    local rayhit = tes3.rayTest {
        position = from,
        direction = tes3vector3.new(0, 0, -1),
        returnNormal = true
    }

    if (rayhit) then
        local to = rayhit.intersection
        local dist = to.z - from.z
        return dist
    end

    return nil
end

--- @param from tes3vector3
--- @return number|nil
local function getGroundZ(from)
    local rayhit = tes3.rayTest {
        position = from,
        direction = tes3vector3.new(0, 0, -1),
        returnNormal = true
    }

    if (rayhit) then
        local to = rayhit.intersection
        return to.z
    end

    return nil
end

local function onTimerTick()
    if mount == nil then return; end
    if myTimer == nil then return; end

    if spline_index <= #get_current_spline() then -- if i is not at the end of the list
        local s = get_current_spline()[spline_index]
        local next_pos = tes3vector3.new(s.x, s.y, s.z)

        local d = next_pos - tes3.player.position -- get the direction vector from the object to the coordinate
        local dist = d:length() -- get the distance from the object to the coordinate
        d:normalize()
        local d_n = d

        -- position of player and mount
        -- local result = tes3.rayTest {
        -- 	position = { tes3.player.position.x, tes3.player.position.y, tes3.player.position.z },
        -- 	direction = { 0, 0, -1 },
        -- 	-- ignore = ignoreList,
        -- 	returnNormal = true,
        -- 	useBackTriangles = false,
        -- 	root = tes3.game.worldLandscapeRoot,
        -- }

        -- if result then

        -- end

        if dist > speed then
            local p = tes3.player.position + (d_n * speed) -- move the object by speed units along the direction vector 

            mount.position = p + mountOffset
            tes3.player.position = p
        else
            mount.position = next_pos + mountOffset
            tes3.player.position = next_pos

            spline_index = spline_index + 1
        end

        -- heading for mount
        local current_facing = mount.facing
        local new_facing = math.atan2(d_n.x, d_n.y)
        local facing = new_facing
        local diff = new_facing - current_facing
        if diff < -math.pi then diff = diff + 2 * math.pi end
        if diff > math.pi then diff = diff - 2 * math.pi end

        if diff > 0 and diff > angle then
            facing = current_facing + angle
        elseif diff < 0 and diff < -angle then
            facing = current_facing - angle
        else
            facing = new_facing
        end
        mount.facing = facing

    else -- if i is at the end of the list
        -- cleanup all
        mount = nil
        myTimer:cancel()
        spline_index = 1
        tes3.messageBox("ended")
    end
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// TEST WINDOW

--- @param s string
--- @return string
local function sanitize(s)
    local result = string.gsub(s, "%s+", "")
    return result
end

--- @param cell_name string
local function get_destinations(cell_name)
    local id = table.get(data.cell_mapping, sanitize(cell_name), "None")
    mwse.log("cell_name: " .. cell_name .. ", sanitized: " ..
                 sanitize(cell_name) .. ", id: " .. id)

    local ids = {}
    for _index, key in ipairs(table.keys(data.splines)) do
        -- mwse.log(key)
        -- TODO additional legs
        if string.startswith(key, id .. "_") then
            table.insert(ids, {name = key, invert = false})
            -- mwse.log("Added " .. key)
        end
        if string.endswith(key, "_" .. id) then
            -- invert
            table.insert(ids, {name = key, invert = true})
            -- mwse.log("Added " .. key .. ".inv")
        end
    end

    -- dbg
    mwse.log("ids: ")
    for index, value in ipairs(ids) do mwse.log(value.name) end

    return ids
end

-- Create window and layout. Called by onCommand.
local function createTestWindow()
    -- Return if window is already open
    if (tes3ui.findMenu(test_menu) ~= nil) then return end

    -- Create window and frame
    local menu = tes3ui.createMenu {
        id = test_menu,
        fixedFrame = false,
        dragFrame = true
    }
    menu.width = 300
    menu.height = 300
    -- To avoid low contrast, text input windows should not use menu transparency settings
    menu.alpha = 1.0

    -- Create layout
    local input_label = menu:createLabel{text = tes3.player.cell.id}
    input_label.borderBottom = 5

    local pane = menu:createVerticalScrollPane{id = "sortedPane"}
    local destination_ids = get_destinations(tes3.player.cell.id)
    for _key, value in ipairs(destination_ids) do
        local name = value.name
        if value.inverted then name = name .. ".inv" end

        local button = pane:createButton{
            id = "button_spline_" .. name,
            text = name
        }
        if current_travel_target == name then
            button.widget.idle = tes3ui.getPalette("active_color")
            button.widget.over = tes3ui.getPalette("active_color")
        end
        button:register(tes3.uiEvent.mouseClick,
                        function() current_travel_target = name end)
    end
    pane:getContentElement():sortChildren(function(a, b)
        return a.text < b.text
    end)

    local button_block = menu:createBlock{}
    button_block.widthProportional = 1.0 -- width is 100% parent width
    button_block.autoHeight = true
    button_block.childAlignX = 1.0 -- right content alignment

    local button_start = button_block:createButton{
        id = test_menu_ok,
        text = "Start"
    }
    local button_cancel = button_block:createButton{
        id = test_menu_cancel,
        text = "Cancel"
    }

    -- Events
    button_cancel:register(tes3.uiEvent.mouseClick, function()
        local m = tes3ui.findMenu(test_menu)
        if (m) then
            mount = nil
            tes3ui.leaveMenuMode()
            m:destroy()
        end
    end)
    button_start:register(tes3.uiEvent.mouseClick, function()
        if mount == nil then return end

        local m = tes3ui.findMenu(test_menu)
        if (m) then
            myTimer = timer.start({
                duration = timertick,
                type = timer.real,
                iterations = -1,
                callback = onTimerTick
            })

            tes3ui.leaveMenuMode()
            m:destroy()
        end
    end)

    -- Final setup
    menu:updateLayout()
    tes3ui.enterMenuMode(test_menu)
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EDITOR

event.register("simulate", function(e)
    if editmode == false then return end

    local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256
    local groundZ = getGroundZ(from)
    from.z = groundZ + 1025

    editor_instance.translation = from
    editor_instance:update()
end)

--- @param forward tes3vector3
--- @return tes3matrix33
local function rotation_matrix_from_direction(forward)
    forward:normalize()
    local up = tes3vector3.new(0, 0, 1)
    local right = up:cross(forward)
    right:normalize()
    up = right:cross(forward)

    local rotation_matrix = tes3matrix33.new(right.x, forward.x, up.x, right.y,
                                             forward.y, up.y, right.z,
                                             forward.z, up.z)

    return rotation_matrix
end

local function updateMarkers()
    -- update rotation
    for index, marker in ipairs(editor_markers) do
        if index < #editor_markers then
            local nextMarker = editor_markers[index + 1]
            local direction = nextMarker.translation - marker.translation
            local rotation_matrix = rotation_matrix_from_direction(direction)
            marker.rotation = rotation_matrix

        end
    end

    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    vfxRoot:update()
end

---@return number
local function getClosestMarkerIdx()
    -- get closest marker
    local pp = tes3.player.position

    local final_idx = 1
    local last_distance = nil
    for index, marker in ipairs(editor_markers) do
        local distance_to_marker = pp:distance(marker.translation)

        -- first
        if last_distance == nil then
            last_distance = distance_to_marker
            final_idx = 1
        end

        if distance_to_marker < last_distance then
            final_idx = index
            last_distance = distance_to_marker
        end
    end

    editor_instance = editor_markers[final_idx]

    updateMarkers()

    return final_idx
end

local function renderMarkers()
    -- cleanup
    editor_markers = {}
    editor_instance = nil
    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    vfxRoot:detachAllChildren()

    -- add markers
    local mesh = tes3.loadMesh(editor_marker)

    for idx, v in ipairs(get_current_editor_spline()) do

        local child = mesh:clone()
        child.translation = tes3vector3.new(v.x, v.y, v.z)
        child.appCulled = false

        ---@diagnostic disable-next-line: param-type-mismatch
        vfxRoot:attachChild(child)
        vfxRoot:update()

        ---@diagnostic disable-next-line: assign-type-mismatch
        editor_markers[idx] = child
    end

    updateMarkers()
end

local function createEditWindow()
    -- Return if window is already open
    if (tes3ui.findMenu(edit_menu) ~= nil) then return end

    -- Create window and frame
    local menu = tes3ui.createMenu {
        id = edit_menu,
        fixedFrame = false,
        dragFrame = true
    }

    -- To avoid low contrast, text input windows should not use menu transparency settings
    menu.alpha = 1.0
    menu.width = 300
    menu.height = 400

    -- Create layout
    local input_label = menu:createLabel{text = "Editor"}
    input_label.borderBottom = 5

    local pane = menu:createVerticalScrollPane{id = "sortedPane"}
    for _key, value in ipairs(table.keys(data.splines)) do
        local button = pane:createButton{
            id = "button_spline" .. value,
            text = value
        }
        if current_data == value then
            button.widget.idle = tes3ui.getPalette("active_color")
            button.widget.over = tes3ui.getPalette("active_color")
        end
        button:register(tes3.uiEvent.mouseClick, function()
            current_data = value
            renderMarkers()
        end)
    end
    pane:getContentElement():sortChildren(function(a, b)
        return a.text < b.text
    end)

    local button_block = menu:createBlock{}
    button_block.widthProportional = 1.0 -- width is 100% parent width
    button_block.autoHeight = true
    button_block.childAlignX = 1.0 -- right content alignment

    local button_display = button_block:createButton{
        id = edit_menu_display,
        text = "Save"
    }
    local button_cancel = button_block:createButton{
        id = edit_menu_cancel,
        text = "Exit"
    }

    -- Leave Menu
    button_cancel:register(tes3.uiEvent.mouseClick, function()
        local m = tes3ui.findMenu(edit_menu)
        if (m) then
            mount = nil
            tes3ui.leaveMenuMode()
            m:destroy()
        end
    end)
    -- log current spline
    button_display:register(tes3.uiEvent.mouseClick, function()
        -- reset spline
        data.splines[current_data] = {}
        -- print to file
        mwse.log("============================================")
        mwse.log(current_data)
        mwse.log("============================================")
        for i, value in ipairs(editor_markers) do
            local t = value.translation
            mwse.log(
                "{ x = " .. math.round(t.x) .. ", y = " .. math.round(t.y) ..
                    ", z = " .. math.round(t.z) .. " },")
            -- save currently edited markers back to spline
            table.insert(data.splines[current_data], i, {
                x = math.round(t.x),
                y = math.round(t.y),
                z = math.round(t.z)
            })

        end
        mwse.log("============================================")

        renderMarkers()

        tes3.messageBox("Printed coordinates: " .. current_data)
    end)

    -- Final setup
    menu:updateLayout()
    tes3ui.enterMenuMode(edit_menu)
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// INPUT

--- @param e keyDownEventData
local function keyDownCallback(e)

    -- editor menu
    if e.keyCode == tes3.scanCode["rCtrl"] then createEditWindow() end

    -- marker edit mode
    if e.keyCode == tes3.scanCode["lCtrl"] then
        local idx = getClosestMarkerIdx()
        editmode = not editmode
        tes3.messageBox("Marker index: " .. idx)
    end

    -- raytest
    if e.keyCode == tes3.scanCode["o"] then
        tes3.messageBox("Cell: " .. tes3.player.cell.id)
    end

    -- delete
    if e.keyCode == tes3.scanCode["delete"] then
        local idx = getClosestMarkerIdx()

        local instance = editor_markers[idx]
        local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
        vfxRoot:detachChild(instance)

        table.remove(editor_markers, idx)
    end

    -- insert
    if e.keyCode == tes3.scanCode["keyRight"] or e.keyCode ==
        tes3.scanCode["leftAlt"] then
        local idx = getClosestMarkerIdx()
        -- insert new instance

        local mesh = tes3.loadMesh(editor_marker)
        local child = mesh:clone()

        local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() *
                         256

        child.translation = tes3vector3.new(from.x, from.y, from.z)
        child.appCulled = false

        local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
        ---@diagnostic disable-next-line: param-type-mismatch
        vfxRoot:attachChild(child)
        vfxRoot:update()

        table.insert(editor_markers, idx + 1, child)

        editor_instance = child
        editmode = true
    end

    -- start travel
    if e.keyCode == tes3.scanCode["keyLeft"] then
        local t = getLookedAtReference()
        if (t) then
            mount = t
            createTestWindow()
        end
    end

end
event.register(tes3.event.keyDown, keyDownCallback)

