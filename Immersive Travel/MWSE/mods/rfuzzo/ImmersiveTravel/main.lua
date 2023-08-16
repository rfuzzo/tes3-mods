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

--]] -- 
-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local config = require("rfuzzo.ImmersiveTravel.config")

local sway_frequency = 0.12 -- how fast the mount sways
local sway_amplitude = 0.014 -- how much the mount sways

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// VARIABLES
local edit_menu = tes3ui.registerID("it:MenuEdit")
local edit_menu_display = tes3ui.registerID("it:MenuEdit_Display")
local edit_menu_mode = tes3ui.registerID("it:MenuEdit_Mode")
local edit_menu_cancel = tes3ui.registerID("it:MenuEdit_Cancel")

local travel_menu = tes3ui.registerID("it:travel_menu")
local travel_menu_cancel = tes3ui.registerID("it:travel_menu_cancel")

local timertick = 0.01
---@type mwseTimer | nil
local myTimer = nil

---@type tes3reference | nil
local mount = nil
---@type tes3reference | nil
local guide = nil
local is_traveling = false
local spline_index = 1
local sway_time = 0
local mount_scale = 1.0
local npc_menu = nil

-- editor
local editmode = false

local editor_marker = "marker_arrow.nif"
---@type niNode[]
local editor_markers = {}
local editor_instance = nil

---@class PositionRecord
---@field x number The x position
---@field y number The y position
---@field z number The z position

---@class MountData
---@field offset number? The mount offset to ground
---@field sway number The sway intensity
---@field mountpoint1 number A mountpoint relative to player position and facing
---@field mountpoint1_z number hack
---@field mountpoint2 number A mountpoint relative to player position and facing

local current_spline = {} ---@type PositionRecord[]
local mount_data = nil ---@type MountData|nil

local destination_map = {} ---@type table<string, table>
local destination_boat_map = {} ---@type table<string, table>

local boat_mode = false

local logger = require("logging.logger")
local log = logger.new {
    name = config.mod,
    logLevel = config.logLevel,
    logToConsole = true,
    includeTimestamp = true
}

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// GETTERS

-- speed of the mount
--- @return number
local function get_speed()
    if boat_mode then
        return config.boatspeed
    else
        return config.speed
    end
end

-- rotation speed of the mount
local function get_angle()
    if boat_mode then
        return config.boatturnspeed / 10000
    else
        return config.turnspeed / 10000
    end
end

-- get destination_map var for mounts
local function get_destinations()
    if boat_mode then
        return destination_boat_map
    else
        return destination_map
    end
end

-- editor: get marker offset from the ground
local function get_ground_offset()
    if boat_mode then
        return 0
    else
        return 1025
    end
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// LOGIC

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

---@class ReferenceRecord
---@field cell tes3cell The cell
---@field position tes3vector3 The reference position

---@return ReferenceRecord|nil
local function findClosestTravelMarker()
    ---@type table<ReferenceRecord>
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

    return results[last_index]
end

local function teleport_to_closest_marker()
    local marker = findClosestTravelMarker()
    if marker ~= nil then
        tes3.positionCell({
            reference = tes3.mobilePlayer,
            cell = marker.cell,
            position = marker.position
        })
    end
end

--- find the first a_siltstrider in the actors cell
---@param actor tes3mobileActor
---@return tes3reference|nil
local function findStrider(actor)
    local cell = actor.cell
    local references = referenceListToTable(cell.statics)
    for _, r in ipairs(references) do
        if r.baseObject.id == "a_siltstrider" then return r end
    end
end

--- find the first boat in the actors cell
---@param actor tes3mobileActor
---@return tes3reference|nil
local function findBoat(actor)
    local cell = actor.cell
    local references = referenceListToTable(cell.statics)
    for _, r in ipairs(references) do
        if r.baseObject.id == "ex_longboat" or r.baseObject.id ==
            "ex_longboat01" or r.baseObject.id == "Ex_longboat02" or
            r.baseObject.id == "Ex_DE_ship" then return r end
    end
end

-- Function to translate local orientation around a player-centered coordinate system to world orientation around a fixed axis coordinate system
---@param localOrientation tes3vector3
--- @return tes3vector3
local function toWorldOrientation(localOrientation, newOrientation)
    -- Convert the local orientation to a rotation matrix
    local localRotationMatrix = tes3matrix33.new()
    localRotationMatrix:fromEulerXYZ(newOrientation.x, newOrientation.y,
                                     newOrientation.z)
    local playerRotationMatrix = tes3matrix33.new()
    playerRotationMatrix:fromEulerXYZ(localOrientation.x, localOrientation.y,
                                      localOrientation.z)

    -- Combine the rotation matrices to get the world rotation matrix
    local worldRotationMatrix = localRotationMatrix * playerRotationMatrix
    local worldOrientation, _isUnique = worldRotationMatrix:toEulerXYZ()
    return worldOrientation
end

local function cleanup()
    -- cleanup
    if myTimer ~= nil then myTimer:cancel() end
    spline_index = 1

    -- delete the mount
    if mount ~= nil then mount:delete() end
    mount = nil
    if guide ~= nil then guide:delete() end
    guide = nil
    mount_scale = 1.0

    is_traveling = false
end

local function onTimerTick()
    if mount == nil then return; end
    if mount_data == nil then return; end
    if guide == nil then return; end
    if myTimer == nil then return; end

    local len = #current_spline
    if spline_index <= len then -- if i is not at the end of the list
        -- set position
        local point = nil
        point = current_spline[spline_index]

        local next_pos = tes3vector3.new(point.x, point.y, point.z)
        local local_pos = tes3.player.position -
                              tes3vector3.new(0, 0, mount_data.mountpoint1_z)

        local d = next_pos - local_pos -- get the direction vector from the object to the coordinate
        local dist = d:length() -- get the distance from the object to the coordinate
        d:normalize()
        local d_n = d

        -- set heading
        local current_facing = mount.facing
        local new_facing = math.atan2(d_n.x, d_n.y)
        local facing = new_facing
        local diff = new_facing - current_facing
        if diff < -math.pi then diff = diff + 2 * math.pi end
        if diff > math.pi then diff = diff - 2 * math.pi end

        if diff > 0 and diff > get_angle() then
            facing = current_facing + get_angle()
        elseif diff < 0 and diff < -get_angle() then
            facing = current_facing - get_angle()
        else
            facing = new_facing
        end
        mount.facing = facing

        -- positions
        local player_offset = mount.forwardDirection * mount_data.mountpoint1
        local mount_offset = mount_data.offset

        if dist > get_speed() then
            local p = local_pos + (d_n * get_speed()) -- move the object by speed units along the direction vector 

            mount.position = p +
                                 (tes3vector3.new(0, 0, mount_offset) +
                                     player_offset)

            tes3.player.position = p +
                                       tes3vector3.new(0, 0,
                                                       mount_data.mountpoint1_z)
        else
            mount.position = next_pos +
                                 (tes3vector3.new(0, 0, mount_offset) +
                                     player_offset)

            tes3.player.position = next_pos +
                                       tes3vector3.new(0, 0,
                                                       mount_data.mountpoint1_z)

            spline_index = spline_index + 1
        end

        -- add guide npc
        guide.position = local_pos +
                             tes3vector3.new(0, 0, mount_data.mountpoint1_z) +
                             (mount.forwardDirection * mount_data.mountpoint2)
        guide.facing = facing

        -- set sway
        sway_time = sway_time + timertick
        if sway_time > (2000 * sway_frequency) then sway_time = timertick end
        local sway = (sway_amplitude * mount_data.sway) *
                         math.sin(2 * math.pi * sway_frequency * sway_time)
        local worldOrientation = toWorldOrientation(
                                     tes3vector3.new(0.0, sway, 0.0),
                                     mount.orientation)
        mount.orientation = worldOrientation

    else -- if i is at the end of the list

        tes3.fadeOut({duration = 0.5})
        cleanup()

        timer.start({
            type = timer.real,
            iterations = 1,
            duration = 1,
            callback = (function()
                tes3.mobilePlayer.movementCollision = true;
                tes3.playAnimation({reference = tes3.player, group = 0})
                tes3.fadeIn({duration = 1})
                teleport_to_closest_marker();
                is_traveling = false
            end)
        })
    end
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// TRAVEL

--- @param e combatStartEventData
local function forcedPacifism(e) if (is_traveling == true) then return false end end
event.register(tes3.event.combatStart, forcedPacifism)

--- load json spline from file
---@param start string
---@param destination string
local function load_spline(start, destination)
    local fileName = start .. "_" .. destination
    local filePath = "mods\\rfuzzo\\ImmersiveTravel\\data\\" .. fileName
    if boat_mode then
        filePath = "mods\\rfuzzo\\ImmersiveTravel\\data_boats\\" .. fileName
    end
    local result = json.loadfile(filePath)
    if result ~= nil then
        log:debug("loaded spline: " .. filePath)
        current_spline = result
    else
        log:debug("!!! failed to load spline: " .. filePath)
        result = nil
    end
end

--- load json static mount data
---@param id string
local function load_mount_data(id)
    local filePath = "mods\\rfuzzo\\ImmersiveTravel\\mounts.json"
    local result = {} ---@type table<string, MountData>
    result = json.loadfile(filePath)

    if result ~= nil then
        log:debug("loaded mount " .. id .. ": " .. filePath)
        mount_data = result[id]
    else
        log:debug("!!! failed to load mount: " .. filePath)
        mount_data = nil
    end

end

--- set up everything
---@param start string
---@param destination string
local function start_travel(start, destination)
    if mount == nil then return end
    if guide == nil then return end

    local m = tes3ui.findMenu(travel_menu)
    if (m) then

        tes3ui.leaveMenuMode()
        m:destroy()

        -- set targets
        load_spline(start, destination)
        if current_spline == nil then return end

        local original_mount = mount
        local original_guide = guide

        -- hide original mount for a while
        original_mount:disable()
        timer.start({
            type = timer.real,
            iterations = 1,
            duration = 7,
            callback = (function() original_mount:enable() end)
        })

        -- duplicate mount
        local object_id = "a_siltstrider"
        if boat_mode then
            if (string.startswith(start, "Dagon Fel") or
                string.startswith(start, "Vos") or
                string.startswith(start, "Sadrith Mora") or
                string.startswith(start, "Ebonheart")) and
                (string.startswith(destination, "Dagon Fel") or
                    string.startswith(destination, "Vos") or
                    string.startswith(destination, "Sadrith Mora") or
                    string.startswith(destination, "Ebonheart")) then
                object_id = "a_DE_ship"
            else
                object_id = "a_longboat"
            end
        end

        -- load mount data
        load_mount_data(object_id)
        if mount_data == nil then return end

        -- fade out
        tes3.fadeOut({duration = 1.0})
        is_traveling = true

        local start_point = current_spline[1]
        local start_pos = tes3vector3.new(start_point.x, start_point.y,
                                          start_point.z)
        mount = tes3.createReference {
            object = object_id,
            position = start_pos,
            orientation = mount.orientation
        }

        -- duplicate guide
        object_id = original_guide.baseObject.id
        guide = tes3.createReference {
            object = object_id,
            position = mount.position,
            orientation = mount.orientation
        }

        -- leave npc dialogue
        local menu = tes3ui.findMenu(npc_menu)
        if menu then
            npc_menu = nil
            menu:destroy()
        end

        -- facing
        local next_point = current_spline[2]
        local next_pos = tes3vector3.new(next_point.x, next_point.y,
                                         next_point.z)
        local d = next_pos - mount.position
        d:normalize()
        local new_facing = math.atan2(d.x, d.y)
        mount.facing = new_facing

        tes3.mobilePlayer.movementCollision = false;
        tes3.playAnimation({
            reference = tes3.player,
            group = tes3.animationGroup.idle2
        })

        -- play mount animation
        -- tes3.playAnimation({
        --     reference = mount,
        --     group = tes3.animationGroup["walkForward"]
        -- })

        -- play guide animation
        guide.mobile.movementCollision = false;
        tes3.playAnimation({
            reference = guide,
            group = tes3.animationGroup.idle5
        })

        -- fade back in
        timer.start({
            type = timer.real,
            iterations = 1,
            duration = 1,
            callback = (function()

                tes3.fadeIn({duration = 1})

                -- teleport player to mount
                local p = mount.position -
                              tes3vector3.new(0, 0, mount_data.offset)
                tes3.positionCell({reference = tes3.mobilePlayer, position = p})

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

--- Disable activate of mount and guide while in travel
--- @param e activateEventData
local function activateCallback(e)
    if (e.activator ~= tes3.player) then return end
    if mount == nil then return; end
    if guide == nil then return; end
    if myTimer == nil then return; end

    if e.target.id == guide.id then return false end
    if e.target.id == mount.id then return false end
end
event.register(tes3.event.activate, activateCallback)

--- Disable tooltips of mount and guide while in travel
--- @param e uiObjectTooltipEventData
local function uiObjectTooltipCallback(e)
    if mount == nil then return; end
    if guide == nil then return; end
    if myTimer == nil then return; end

    if e.object.id == guide.id then
        e.tooltip.visible = false
        return false
    end
    if e.object.id == mount.id then
        e.tooltip.visible = false
        return false
    end
end
event.register(tes3.event.uiObjectTooltip, uiObjectTooltipCallback)

--- Start Travel window
-- Create window and layout. Called by onCommand.
local function createTravelWindow()
    log:debug("travel from: " .. tes3.player.cell.id)
    -- Return if window is already open
    if (tes3ui.findMenu(travel_menu) ~= nil) then return end
    -- Return if no destinations
    local destinations = get_destinations()[tes3.player.cell.id]
    -- log:debug(json.encode(destinations))
    if destinations == nil then return end

    -- Create window and frame
    local menu = tes3ui.createMenu {
        id = travel_menu,
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
        id = travel_menu_cancel,
        text = "Cancel"
    }

    -- Events
    button_cancel:register(tes3.uiEvent.mouseClick, function()
        local m = tes3ui.findMenu(travel_menu)
        if (m) then
            mount = nil
            mount_scale = 1.0

            tes3ui.leaveMenuMode()
            m:destroy()
        end
    end)

    -- Final setup
    menu:updateLayout()
    tes3ui.enterMenuMode(travel_menu)
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EDITOR

local current_editor_route = ""

event.register("simulate", function(e)
    if editmode == false then return end
    if editor_instance == nil then return end

    local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256

    if boat_mode then
        from.z = 0
    else

        local groundZ = getGroundZ(from)
        if groundZ == nil then
            from.z = get_ground_offset()
        else
            from.z = groundZ + get_ground_offset()
        end
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
    menu.text = "Editor"

    -- Create layout
    local label = menu:createLabel{text = "Loaded routes"}
    label.borderBottom = 5

    local pane = menu:createVerticalScrollPane{id = "sortedPane"}

    local destinations = get_destinations()

    for _i, start in ipairs(table.keys(destinations)) do
        for _j, destination in ipairs(destinations[start]) do
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

    local mode_text = "Strider"
    if boat_mode then mode_text = "Boat" end
    local button_mode = button_block:createButton{
        id = edit_menu_mode,
        text = mode_text
    }
    local button_save = button_block:createButton{
        id = edit_menu_display,
        text = "Save"
    }
    local button_cancel = button_block:createButton{
        id = edit_menu_cancel,
        text = "Exit"
    }

    -- Switch mode
    button_mode:register(tes3.uiEvent.mouseClick, function()
        local m = tes3ui.findMenu(edit_menu)
        if (m) then
            boat_mode = not boat_mode

            mount = nil
            mount_scale = 1.0
            -- tes3ui.leaveMenuMode()
            m:destroy()

            createEditWindow()
        end
    end)

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
        current_spline = {}
        for i, value in ipairs(editor_markers) do
            local t = value.translation
            mwse.log("{ \"x\": " .. math.round(t.x) .. ", \"y\": " ..
                         math.round(t.y) .. ", \"z\": " .. math.round(t.z) ..
                         " },")

            -- save currently edited markers back to spline
            table.insert(current_spline, i, {
                x = math.round(t.x),
                y = math.round(t.y),
                z = math.round(t.z)
            })

        end
        mwse.log("============================================")

        -- save to file
        if boat_mode then
            json.savefile("mods\\rfuzzo\\ImmersiveTravel\\data_boats\\" ..
                              current_editor_route .. ".saved", current_spline)
        else
            json.savefile("mods\\rfuzzo\\ImmersiveTravel\\data\\" ..
                              current_editor_route .. ".saved", current_spline)
        end

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

    if e.keyCode == tes3.scanCode["forwardSlash"] then
        tes3.messageBox(tes3.player.cell.id)
        mwse.log("cell: " .. tes3.player.cell.id)

        local t = getLookedAtReference()
        if (t) then
            -- mwse.log("=== start === ")
            -- mwse.log("baseObject: " .. t.baseObject.id)
            -- mwse.log("mesh: " .. t.baseObject.mesh)
            -- mwse.log("scale: " .. tostring(t.scale))
            -- mwse.log("position: " .. t.position:__tostring())
            -- mwse.log("orientation: " .. t.orientation:__tostring())
            -- mwse.log("boundingBox: " .. t.baseObject.boundingBox:__tostring())
            -- mwse.log("height: " .. t.baseObject.boundingBox.max.z)
            -- mwse.log("=== end === ")

            -- facing

            local mesh = tes3.loadMesh(editor_marker)
            local child = mesh:clone()
            child.appCulled = false
            local pos = t.position + tes3vector3.new(0, 0, 60)
            child.translation = pos

            local facing = t.facing
            local orientation = t.orientation
            local m = tes3matrix33.new()
            -- local rotation_matrix = rotation_matrix_from_direction(direction)
            m:fromEulerXYZ(orientation.x, orientation.y, orientation.z)
            child.rotation = m

            local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
            ---@diagnostic disable-next-line: param-type-mismatch
            vfxRoot:attachChild(child)
            vfxRoot:update()

        end
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

-- lots of hot tea

---@param menu tes3uiElement
local function updateServiceButton(menu)
    timer.frame.delayOneFrame(function()
        if not menu then return end
        local serviceButton = menu:findChild("rf_id_travel_button")
        if not serviceButton then return end
        serviceButton.visible = true
        serviceButton.disabled = false
    end)
end

---@param menu tes3uiElement
---@param attached_mount tes3reference
---@param attached_guide tes3reference
---@param mode boolean
local function createTravelButton(menu, attached_mount, attached_guide, mode)
    local divider = menu:findChild("MenuDialog_divider")
    local topicsList = divider.parent
    local button = topicsList:createTextSelect({
        id = "rf_id_travel_button",
        text = "Take me to..."
    })
    button.widthProportional = 1.0
    button.visible = true
    button.disabled = false

    topicsList:reorderChildren(divider, button, 1)

    button:register("mouseClick", function()
        boat_mode = mode;
        mount = attached_mount
        guide = attached_guide
        npc_menu = menu.id
        createTravelWindow()
    end)
    menu:registerAfter("update", function() updateServiceButton(menu) end)
end

--- This function returns `true` if given NPC
--- or creature offers traveling service.
---@param actor tes3npc|tes3npcInstance|tes3creature|tes3creatureInstance
---@return boolean
local function offersTraveling(actor)
    local travelDestinations = actor.aiConfig.travelDestinations

    -- Actors that can't transport the player
    -- have travelDestinations equal to `nil`
    return travelDestinations ~= nil
end

-- upon entering the dialog menu, create the hot tea button (thanks joseph)
---@param e uiActivatedEventData
local function onMenuDialog(e)
    local menuDialog = e.element
    local mobileActor = menuDialog:getPropertyObject("PartHyperText_actor") ---@cast mobileActor tes3mobileActor
    if mobileActor.actorType == tes3.actorType.npc then
        local ref = mobileActor.reference
        local obj = ref.baseObject
        local npc = obj ---@cast obj tes3npc

        -- an npc that is class Caravaner AND has AI travel package AND in the same cell as a siltstrider is eligible
        if npc.class.id == "Caravaner" and offersTraveling(npc) then
            local strider = findStrider(mobileActor)
            if strider ~= nil then
                log:debug("Adding Hot Tea Service to %s", ref.id)

                createTravelButton(menuDialog, strider, ref, false)
                menuDialog:updateLayout()
            end
        end

        -- an npc that is class Shipmaster AND has AI travel package AND in the same cell as a boat is eligible
        if npc.class.id == "Shipmaster" and offersTraveling(npc) then
            local boat = findBoat(mobileActor)
            if boat ~= nil then
                log:debug("Adding Hot Tea Service to %s", ref.id)

                createTravelButton(menuDialog, boat, ref, true)
                menuDialog:updateLayout()
            end
        end

    end

end
event.register("uiActivated", onMenuDialog, {filter = "MenuDialog"})

--- @param e loadEventData
local function loadCallback(e) cleanup() end
event.register(tes3.event.load, loadCallback)

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("rfuzzo.ImmersiveTravel.mcm")

--- init mod
local function init()
    local map = {} ---@type table<string, table>
    log:info("[Immersive Travel] Loaded successfully.")
    -- striders
    log:debug("Registered strider destinations: ")
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

    -- boats
    map = {}
    log:debug("Registered boat destinations: ")
    for file in lfs.dir(
                    "Data Files\\MWSE\\mods\\rfuzzo\\ImmersiveTravel\\data_boats") do
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
    destination_boat_map = map

    -- mounts

end
event.register(tes3.event.initialized, init)
