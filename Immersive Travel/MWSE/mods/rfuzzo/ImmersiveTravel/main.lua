--[[
Immersive Travel Mod
v 0.1
by rfuzzo

mwse real-time travel mod

---
Current Usage (Debug)
- Open route editor 						... R-Ctrl
- move a marker 							... L-Ctrl
- delete a marker 							... Del
- exit edit mode 							... L-Ctrl
- add a marker								... >
- start traveling            		        ... <

to do
- move player forward
- complex routes
---
--]] -- 
-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local config = require("rfuzzo.ImmersiveTravel.config")

local angle = 0.002 -- the angle of rotation in radians per timertick
local sway_frequency = 0.12
local sway_amplitude = 0.014
local mountOffset = tes3vector3.new(0, 0, -1220)

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// VARIABLES
local edit_menu = tes3ui.registerID("it:MenuEdit")
local edit_menu_display = tes3ui.registerID("it:MenuEdit_Display")
local edit_menu_cancel = tes3ui.registerID("it:MenuEdit_Cancel")

local test_menu = tes3ui.registerID("it:test_menu")
local test_menu_ok = tes3ui.registerID("it:test_menu_ok")
local test_menu_cancel = tes3ui.registerID("it:test_menu_cancel")

-- local data = require("rfuzzo.ImmersiveTravel.data.data")

local timertick = 0.01
---@type mwseTimer | nil
local myTimer = nil

---@type tes3reference | nil
local mount = nil

local spline_index = 1
local sway_time = 0
local mount_scale = 1.0

local is_fade_out = false;

-- editor
local editmode = false
local editor_marker = "marker_arrow.nif"
---@type niNode[]
local editor_markers = {}
local editor_instance = nil

local current_spline = {}
local destination_map = {} ---@type table<string, table>

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// LOGIC

local logger = require("logging.logger")
local log = logger.new {
    name = config.mod,
    logLevel = config.logLevel,
    logToConsole = true,
    includeTimestamp = true
}

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

-- This function loops over the references inside the
-- tes3referenceList and adds them to an array-style table
---@param list tes3referenceList
---@return tes3reference[]
local function referenceListToTable(list)
    local references = {} ---@type tes3reference[]
    local i = 1
    if list.size == 0 then return {} end
    local ref = list.head

    while ref.nextNode do
        references[i] = ref
        i = i + 1
        ref = ref.nextNode
    end

    -- Add the last reference
    references[i] = ref
    return references
end

local function teleport_to_closest_marker()
    -- local strider = nil
    local results = {}
    local cells = tes3.getActiveCells()
    for _index, cell in ipairs(cells) do
        local references = referenceListToTable(cell.activators)
        for _, r in ipairs(references) do
            if r.baseObject.isLocationMarker and r.baseObject.id ==
                "TravelMarker" then
                table.insert(results, {cell = cell, position = r.position})
            end
        end
    end

    local last_distance = 9999
    local last_index = 1
    for index, marker in ipairs(results) do
        local dist = tes3.mobilePlayer.position:distance(marker.position)
        if dist < last_distance then
            last_index = index
            last_distance = dist
        end
    end

    tes3.positionCell({
        reference = tes3.mobilePlayer,
        cell = results[last_index].cell,
        position = results[last_index].position
    })
end

local function onTimerTick()
    if mount == nil then return; end
    if myTimer == nil then return; end

    local len = #current_spline
    if spline_index <= len then -- if i is not at the end of the list
        -- set position
        local point = nil
        point = current_spline[spline_index]

        local next_pos = tes3vector3.new(point.x, point.y, point.z)
        local d = next_pos - tes3.player.position -- get the direction vector from the object to the coordinate
        local dist = d:length() -- get the distance from the object to the coordinate
        d:normalize()
        local d_n = d

        if dist > config.speed then
            local p = tes3.player.position + (d_n * config.speed) -- move the object by speed units along the direction vector 

            mount.position = p + (mountOffset * mount_scale)
            tes3.player.position = p
        else
            mount.position = next_pos + (mountOffset * mount_scale)
            tes3.player.position = next_pos

            spline_index = spline_index + 1
        end

        -- set heading
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

        -- set sway
        sway_time = sway_time + timertick
        if sway_time > (2000 * sway_frequency) then sway_time = timertick end
        local sway = sway_amplitude *
                         math.sin(2 * math.pi * sway_frequency * sway_time)
        mount.orientation = tes3vector3.new(0.0, sway, mount.orientation.z)

        -- fade close to end
        if is_fade_out == false and spline_index == len then
            tes3.fadeOut({duration = 1.0})
            is_fade_out = true
        end

    else -- if i is at the end of the list
        -- cleanup
        myTimer:cancel()
        spline_index = 1

        -- fade back in
        timer.start({
            type = timer.real,
            iterations = 1,
            duration = 1,
            callback = (function()
                tes3.fadeIn({duration = 1})
                is_fade_out = false
            end)
        })

        -- teleport player to travel marker
        teleport_to_closest_marker();

        -- remove tcl
        tes3.mobilePlayer.movementCollision = true;

        -- delete the mount
        mount:delete()
        mount = nil
        mount_scale = 1.0
    end
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// TRAVEL

---comment
---@param start string
---@param destination string
local function load_spline(start, destination)
    local fileName = start .. "_" .. destination
    local filePath = "mods\\rfuzzo\\ImmersiveTravel\\data\\" .. fileName
    local result = json.loadfile(filePath)
    if result ~= nil then
        log:debug("loaded spline: " .. filePath)
        current_spline = result.data
    else
        log:debug("!!! failed to load spline: " .. filePath)
        result = nil
    end
end

---comment
---@param start string
---@param destination string
local function start_travel(start, destination)
    if mount == nil then return end

    local m = tes3ui.findMenu(test_menu)
    if (m) then
        tes3ui.leaveMenuMode()
        m:destroy()

        -- set targets
        load_spline(start, destination)
        if current_spline == nil then return end
        tes3.mobilePlayer.movementCollision = false;
        tes3.fadeOut({duration = 1.0})

        -- fade back in
        timer.start({
            type = timer.real,
            iterations = 1,
            duration = 1,
            callback = (function()
                tes3.fadeIn({duration = 1})
                is_fade_out = false

                -- start timer
                myTimer = timer.start({
                    duration = timertick,
                    type = timer.real,
                    iterations = -1,
                    callback = onTimerTick
                })
            end)
        })

    end
end

-- Create window and layout. Called by onCommand.
local function createTravelWindow()
    -- Return if window is already open
    if (tes3ui.findMenu(test_menu) ~= nil) then return end
    -- Return if no destinations
    local destinations = destination_map[tes3.player.cell.id]
    -- log:debug(json.encode(destinations))
    if destinations == nil then return end

    -- Create window and frame
    local menu = tes3ui.createMenu {
        id = test_menu,
        fixedFrame = false,
        dragFrame = true
    }
    menu.alpha = 1.0
    menu.text = tes3.player.cell.id
    menu.width = 350
    menu.height = 350

    -- Create layout
    local label = menu:createLabel{text = "Destinations"}
    label.borderBottom = 5

    local pane = menu:createVerticalScrollPane{id = "sortedPane"}
    for _key, name in ipairs(destinations) do
        local button = pane:createButton{
            id = "button_spline_" .. name,
            text = name
        }

        button:register(tes3.uiEvent.mouseClick,
                        function()
            start_travel(tes3.player.cell.id, name)
        end)
    end
    pane:getContentElement():sortChildren(function(a, b)
        return a.text < b.text
    end)
    pane.height = 400

    local button_block = menu:createBlock{}
    button_block.widthProportional = 1.0 -- width is 100% parent width
    button_block.autoHeight = true
    button_block.childAlignX = 1.0 -- right content alignment

    local button_cancel = button_block:createButton{
        id = test_menu_cancel,
        text = "Cancel"
    }

    -- Events
    button_cancel:register(tes3.uiEvent.mouseClick, function()
        local m = tes3ui.findMenu(test_menu)
        if (m) then
            mount = nil
            mount_scale = 1.0

            tes3ui.leaveMenuMode()
            m:destroy()
        end
    end)

    -- Final setup
    menu:updateLayout()
    tes3ui.enterMenuMode(test_menu)
end

-- Start Travel window
--- @param e activateEventData
local function activateCallback(e)
    if (e.activator ~= tes3.player) then return end
    if mount ~= nil then return; end

    if e.target.baseObject.id == "a_siltstrider" then
        mount = e.target
        mount_scale = e.target.scale
        createTravelWindow()
    end
end
event.register(tes3.event.activate, activateCallback)

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EDITOR

local current_editor_route = ""

event.register("simulate", function(e)
    if editmode == false then return end
    if editor_instance == nil then return end

    local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256
    local groundZ = getGroundZ(from)
    if groundZ == nil then
        from.z = 1025
    else
        from.z = groundZ + 1025
    end

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

    local final_idx = 0
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

    for idx, v in ipairs(current_spline) do

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
    local label = menu:createLabel{text = "Editor"}
    label.borderBottom = 5

    local pane = menu:createVerticalScrollPane{id = "sortedPane"}

    for _i, start in ipairs(table.keys(destination_map)) do
        for _j, destination in ipairs(destination_map[start]) do
            local text = start .. " - " .. destination
            local button = pane:createButton{
                id = "button_spline" .. text,
                text = text
            }
            button:register(tes3.uiEvent.mouseClick, function()
                -- start editor
                current_editor_route = start .. "_" .. destination
                load_spline(start, destination)
                renderMarkers()
            end)
        end
    end
    pane:getContentElement():sortChildren(function(a, b)
        return a.text < b.text
    end)

    local button_block = menu:createBlock{}
    button_block.widthProportional = 1.0 -- width is 100% parent width
    button_block.autoHeight = true
    button_block.childAlignX = 1.0 -- right content alignment

    local button_save = button_block:createButton{
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
            mount_scale = 1.0
            tes3ui.leaveMenuMode()
            m:destroy()
        end
    end)

    -- log current spline
    button_save:register(tes3.uiEvent.mouseClick, function()
        -- print to log
        mwse.log("============================================")
        mwse.log(current_editor_route)
        mwse.log("============================================")
        for i, value in ipairs(editor_markers) do
            local t = value.translation
            mwse.log(
                "{ x = " .. math.round(t.x) .. ", y = " .. math.round(t.y) ..
                    ", z = " .. math.round(t.z) .. " },")

            -- save currently edited markers back to spline
            table.insert(current_spline, i, {
                x = math.round(t.x),
                y = math.round(t.y),
                z = math.round(t.z)
            })

        end
        mwse.log("============================================")

        -- save to file
        json.savefile("mods\\rfuzzo\\ImmersiveTravel\\data\\" ..
                          current_editor_route .. ".saved", current_spline)

        renderMarkers()
    end)

    -- Final setup
    menu:updateLayout()
    tes3ui.enterMenuMode(edit_menu)
end

--- @param e keyDownEventData
local function keyDownCallback(e)

    if config.enableeditor == false then return end

    -- editor menu
    if e.keyCode == tes3.scanCode["rCtrl"] then createEditWindow() end

    -- marker edit mode
    if e.keyCode == tes3.scanCode["lCtrl"] then
        local idx = getClosestMarkerIdx()
        editmode = not editmode
        tes3.messageBox("Marker index: " .. idx)
    end

    -- if e.keyCode == tes3.scanCode["o"] then
    --     tes3.messageBox(tes3.player.cell.id)
    --     mwse.log("cell: " .. tes3.player.cell.id)

    --     local t = getLookedAtReference()
    --     if (t) then
    --         mwse.log("=== start === ")
    --         mwse.log("baseObject: " .. t.baseObject.id)
    --         mwse.log("mesh: " .. t.baseObject.mesh)
    --         mwse.log("scale: " .. tostring(t.scale))
    --         mwse.log("position: " .. t.position:__tostring())
    --         mwse.log("orientation: " .. t.orientation:__tostring())
    --         mwse.log("boundingBox: " .. t.baseObject.boundingBox:__tostring())
    --         mwse.log("height: " .. t.baseObject.boundingBox.max.z)
    --         mwse.log("=== end === ")
    --     end

    --     teleport_to_closest_marker()
    -- end

    -- delete
    if e.keyCode == tes3.scanCode["delete"] then
        local idx = getClosestMarkerIdx()

        local instance = editor_markers[idx]
        local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
        vfxRoot:detachChild(instance)

        table.remove(editor_markers, idx)
    end

    -- insert
    if e.keyCode == tes3.scanCode["keyRight"] then
        local idx = getClosestMarkerIdx()
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

end
event.register(tes3.event.keyDown, keyDownCallback)

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("rfuzzo.ImmersiveTravel.mcm")

--- init mod
local function init()
    local map = {} ---@type table<string, table>
    log:info("[Immersive Travel] Loaded successfully.")
    log:debug("Registered destinations: ")
    for file in lfs.dir("Data Files\\MWSE\\mods\\rfuzzo\\ImmersiveTravel\\data") do
        if (string.endswith(file, ".json")) then
            local split = string.split(file:sub(0, -6), "_")
            if #split == 2 then
                local start = ""
                local destination = ""
                for i, id in ipairs(split) do
                    if i == 1 then
                        start = id
                    else
                        destination = id
                    end
                end

                log:debug("  " .. start .. " - " .. destination)
                local result = table.get(map, start, nil)
                if result == nil then
                    local vec = {}
                    table.insert(vec, destination)
                    map[start] = vec

                else
                    table.insert(result, destination)
                    map[start] = result
                end
            end
        end
    end

    destination_map = map
end
event.register(tes3.event.initialized, init)
