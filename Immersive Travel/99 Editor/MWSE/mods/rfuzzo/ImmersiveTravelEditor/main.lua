--[[
Immersive Travel Mod
v 1.0
by rfuzzo

mwse real-time travel mod


--]] -- 
local common = require("rfuzzo.ImmersiveTravel.common")

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local logger = require("logging.logger")
local log = logger.new {
    name = "Immersive Travel Editor",
    logLevel = "DEBUG",
    logToConsole = true,
    includeTimestamp = true
}

---@class SEditorData
---@field service ServiceData
---@field start string
---@field destination string
---@field mount tes3reference|nil
---@field splineIndex integer
---@field editorMarkers niNode[]?
---@field currentMarker niNode?

--[[
Current Usage (Debug)
- Open route editor 						... R-Ctrl
- move a marker 							... L-Ctrl
- delete a marker 							... Del
- exit edit mode 							... L-Ctrl
- add a marker								... >
- start traveling            		        ... <

--]]
local editMenuId = tes3ui.registerID("it:MenuEdit")
local editMenuSaveId = tes3ui.registerID("it:MenuEdit_Display")
local editMenuPrintId = tes3ui.registerID("it:MenuEdit_Print")
local editMenuModeId = tes3ui.registerID("it:MenuEdit_Mode")
local editMenuCancelId = tes3ui.registerID("it:MenuEdit_Cancel")
local editMenuTeleportId = tes3ui.registerID("it:MenuEdit_Teleport")

local editorMarker2 = "marker_divine.nif"
local editorMarker = "marker_arrow.nif"

-- editor
---@type string | nil
local currentServiceName = nil
---@type SEditorData | nil
local editorData = nil
local editmode = false

-- tracing
local eN = 5000
local positions = {} ---@type tes3vector3[]
local arrows = {}
local arrow = nil
local GRAIN = 20

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// FUNCTIONS

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

local function updateMarkers()
    if not editorData then return end
    local editorMarkers = editorData.editorMarkers
    if not editorMarkers then return end

    -- update rotation
    for index, marker in ipairs(editorMarkers) do
        if index < #editorMarkers then
            local nextMarker = editorMarkers[index + 1]
            local direction = nextMarker.translation - marker.translation
            local rotation_matrix = common.rotationFromDirection(direction)
            marker.rotation = rotation_matrix

        end
    end

    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    vfxRoot:update()
end

---@return number|nil
local function getClosestMarkerIdx()
    if not editorData then return nil end
    local editorMarkers = editorData.editorMarkers
    if not editorMarkers then return nil end

    -- get closest marker
    local pp = tes3.player.position

    local final_idx = 0
    local last_distance = nil
    for index, marker in ipairs(editorMarkers) do
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

    editorData.currentMarker = editorMarkers[final_idx]

    updateMarkers()

    return final_idx
end

---comment
---@param spline PositionRecord[]
local function renderMarkers(spline)
    if not editorData then return nil end

    editorData.editorMarkers = {}
    editorData.currentMarker = nil

    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    vfxRoot:detachAllChildren()

    -- add markers
    local mesh = tes3.loadMesh(editorMarker)

    for idx, v in ipairs(spline) do
        local child = mesh:clone()
        child.translation = tes3vector3.new(v.x, v.y, v.z)
        child.appCulled = false

        ---@diagnostic disable-next-line: param-type-mismatch
        vfxRoot:attachChild(child)
        vfxRoot:update()

        ---@diagnostic disable-next-line: assign-type-mismatch
        editorData.editorMarkers[idx] = child
    end

    updateMarkers()
end

local function cleanup()
    if editorData then
        if editorData.mount ~= nil then editorData.mount:delete() end
    end
    editorData = nil
end

---comment
---@param startpos tes3vector3
---@param mountData MountData
local function calculatePositions(startpos, mountData)
    if not editorData then return end
    if not editorData.editorMarkers then return end

    editorData.splineIndex = 2

    positions = {}
    arrows = {}
    table.insert(positions, 1, startpos)

    for idx = 1, eN, 1 do
        if editorData.splineIndex <= #editorData.editorMarkers then
            -- calculate next position
            local point = editorData.editorMarkers[editorData.splineIndex]
                              .translation
            local nextPos = tes3vector3.new(point.x, point.y, point.z)
            local currentPos = positions[idx]

            local v = editorData.mount.forwardDirection
            if idx > 1 then v = currentPos - positions[idx - 1] end
            v:normalize()
            local d = (nextPos - currentPos):normalized()
            local lerp = v:lerp(d, mountData.turnspeed / 10):normalized()

            -- calculate heading
            local current_facing = editorData.mount.facing
            local new_facing = math.atan2(d.x, d.y)
            local facing = new_facing
            local diff = new_facing - current_facing
            if diff < -math.pi then diff = diff + 2 * math.pi end
            if diff > math.pi then diff = diff - 2 * math.pi end
            local angle = mountData.turnspeed / 10000 * GRAIN
            if diff > 0 and diff > angle then
                facing = current_facing + angle
            elseif diff < 0 and diff < -angle then
                facing = current_facing - angle
            else
                facing = new_facing
            end
            editorData.mount.facing = facing
            local f = tes3vector3.new(editorData.mount.forwardDirection.x,
                                      editorData.mount.forwardDirection.y,
                                      lerp.z):normalized()
            local delta = f * mountData.speed * GRAIN
            local mountPosition = currentPos + delta

            -- set position
            table.insert(positions, idx + 1, mountPosition)

            -- draw vfx lines
            if arrow then
                local child = arrow:clone()
                child.translation = mountPosition
                child.appCulled = false
                child.rotation = common.rotationFromDirection(f)
                table.insert(arrows, child)
            end

            -- move to next marker
            local isBehind = common.isPointBehindObject(nextPos, mountPosition,
                                                        f)
            if isBehind then
                editorData.splineIndex = editorData.splineIndex + 1
            end
        else
            break
        end
    end

    editorData.mount:delete()
    editorData.mount = nil
end

---comment
---@param data ServiceData
local function traceRoute(data)
    if not editorData then return end
    if not editorData.editorMarkers then return end
    if #editorData.editorMarkers < 2 then return end

    log:debug("Tracing " .. editorData.start .. " > " .. editorData.destination)

    arrow = tes3.loadMesh("mwse\\arrow.nif"):getObjectByName("unitArrow")
                :clone()
    arrow.scale = 40
    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    for index, value in ipairs(arrows) do vfxRoot:detachChild(value) end

    -- trace the route
    local start_point = editorData.editorMarkers[1].translation
    local start_pos = tes3vector3.new(start_point.x, start_point.y,
                                      start_point.z)
    local next_point = editorData.editorMarkers[2].translation
    local next_pos = tes3vector3.new(next_point.x, next_point.y, next_point.z)
    local d = next_pos - start_pos
    d:normalize()

    -- create mount
    local mountId = data.mount
    -- override mounts 
    if data.override_mount then
        for key, value in pairs(data.override_mount) do
            if common.is_in(value, editorData.start) and
                common.is_in(value, editorData.destination) then
                mountId = key
                break
            end
        end
    end

    local mountData = common.loadMountData(mountId)
    if not mountData then return end
    log:debug("loaded mount: " .. mountId)

    local startpos = start_pos
    local newFacing = math.atan2(d.x, d.y)

    -- create mount
    editorData.mount = tes3.createReference {
        object = mountId,
        position = start_pos,
        orientation = d
    }
    editorData.mount.facing = newFacing

    calculatePositions(startpos, mountData)

    -- vfx
    for index, child in ipairs(arrows) do
        ---@diagnostic disable-next-line: param-type-mismatch
        vfxRoot:attachChild(child)
        vfxRoot:update()
    end
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EDITOR

local function createEditWindow()
    -- Return if window is already open
    if (tes3ui.findMenu(editMenuId) ~= nil) then return end

    -- load services
    local services = common.loadServices()
    if not services then return end

    -- get current service
    if not currentServiceName then
        currentServiceName = table.keys(services)[1]
    end
    if editorData then currentServiceName = editorData.service.class end

    local service = services[currentServiceName]
    common.loadRoutes(service)

    -- Create window and frame
    local menu = tes3ui.createMenu {
        id = editMenuId,
        fixedFrame = false,
        dragFrame = true
    }

    -- To avoid low contrast, text input windows should not use menu transparency settings
    menu.alpha = 1.0
    menu.width = 500
    menu.height = 500
    if editorData then
        menu.text = "Editor " .. editorData.start .. "_" ..
                        editorData.destination
    else
        menu.text = "Editor"
    end

    -- Create layout
    local label = menu:createLabel{text = "Loaded routes"}
    label.borderBottom = 5

    -- get destinations
    local destinations = service.routes
    if destinations then
        local pane = menu:createVerticalScrollPane{id = "sortedPane"}
        for _i, start in ipairs(table.keys(destinations)) do
            for _j, destination in ipairs(destinations[start]) do
                local text = start .. " - " .. destination
                local button = pane:createButton{
                    id = "button_spline" .. text,
                    text = text
                }
                button:register(tes3.uiEvent.mouseClick, function()
                    -- start editor
                    editorData = {
                        service = service,
                        destination = destination,
                        start = start,
                        mount = nil,
                        splineIndex = 1,
                        editorMarkers = nil,
                        currentMarker = nil
                    }

                    local spline =
                        common.loadSpline(start, destination, service)
                    tes3.messageBox("loaded spline: " .. start .. " -> " ..
                                        destination)

                    renderMarkers(spline)
                    traceRoute(service)
                end)
            end
        end
        pane:getContentElement():sortChildren(function(a, b)
            return a.text < b.text
        end)
    end

    local button_block = menu:createBlock{}
    button_block.widthProportional = 1.0 -- width is 100% parent width
    button_block.autoHeight = true
    button_block.childAlignX = 1.0 -- right content alignment

    local button_mode = button_block:createButton{
        id = editMenuModeId,
        text = currentServiceName
    }
    local button_teleport = button_block:createButton{
        id = editMenuTeleportId,
        text = "Teleport"
    }
    local button_save = button_block:createButton{
        id = editMenuSaveId,
        text = "Save"
    }
    local button_print = button_block:createButton{
        id = editMenuPrintId,
        text = "Print"
    }
    local button_cancel = button_block:createButton{
        id = editMenuCancelId,
        text = "Exit"
    }
    -- Switch mode
    button_mode:register(tes3.uiEvent.mouseClick, function()
        local m = tes3ui.findMenu(editMenuId)
        if (m) then
            -- go to next 
            local idx = table.find(table.keys(services), currentServiceName)
            local nextIdx = idx + 1
            if nextIdx > #table.keys(services) then nextIdx = 1 end
            currentServiceName = table.keys(services)[nextIdx]

            cleanup()
            m:destroy()

            createEditWindow()
        end
    end)
    -- Leave Menu
    button_cancel:register(tes3.uiEvent.mouseClick, function()
        local m = tes3ui.findMenu(editMenuId)
        if (m) then

            tes3ui.leaveMenuMode()
            m:destroy()
        end
    end)
    -- Teleport
    button_teleport:register(tes3.uiEvent.mouseClick, function()
        if not editorData then return end
        if not editorData.editorMarkers then return end

        local m = tes3ui.findMenu(editMenuId)
        if (m) then
            if #editorData.editorMarkers > 1 then
                local position = editorData.editorMarkers[1].translation
                tes3.positionCell({
                    reference = tes3.mobilePlayer,
                    position = position
                })

                tes3ui.leaveMenuMode()
                m:destroy()
            end
        end
    end)

    -- log current spline
    button_print:register(tes3.uiEvent.mouseClick, function()
        if not editorData then return end
        if not editorData.editorMarkers then return end

        -- print to log
        local current_editor_route = editorData.start .. "_" ..
                                         editorData.destination
        mwse.log("============================================")
        mwse.log(current_editor_route)
        mwse.log("============================================")
        for i, value in ipairs(editorData.editorMarkers) do
            local t = value.translation
            mwse.log("{ \"x\": " .. math.round(t.x) .. ", \"y\": " ..
                         math.round(t.y) .. ", \"z\": " .. math.round(t.z) ..
                         " },")
        end
        mwse.log("============================================")
        tes3.messageBox("printed spline: " .. current_editor_route)
    end)

    --- save to file
    button_save:register(tes3.uiEvent.mouseClick, function()
        if not editorData then return end
        if not editorData.editorMarkers then return end

        local tempSpline = {}
        for i, value in ipairs(editorData.editorMarkers) do
            local t = value.translation

            -- save currently edited markers back to spline
            table.insert(tempSpline, i, {
                x = math.round(t.x),
                y = math.round(t.y),
                z = math.round(t.z)
            })

        end

        -- save to file
        local current_editor_route = editorData.start .. "_" ..
                                         editorData.destination
        local filename = common.localmodpath .. service.class .. "\\" ..
                             current_editor_route
        json.savefile(filename, tempSpline)

        tes3.messageBox("saved spline: " .. current_editor_route)
    end)

    -- Final setup
    menu:updateLayout()
    tes3ui.enterMenuMode(editMenuId)
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

--- @param e simulatedEventData
local function simulatedCallback(e)
    if not editorData then return end
    if not editorData.currentMarker then return end

    if editmode == false then return end

    local service = editorData.service
    local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256

    if service.ground_offset == 0 then
        from.z = 0
    else
        local groundZ = getGroundZ(from)
        if groundZ == nil then
            from.z = service.ground_offset
        else
            from.z = groundZ + service.ground_offset
        end
    end

    editorData.currentMarker.translation = from
    editorData.currentMarker:update()
end
event.register(tes3.event.simulated, simulatedCallback)

--- @param e keyDownEventData
local function editor_keyDownCallback(e)
    -- editor menu
    if e.keyCode == tes3.scanCode["rCtrl"] then createEditWindow() end

    -- insert
    if e.keyCode == tes3.scanCode["keyRight"] then
        if not editorData then return end
        if not editorData.editorMarkers then return end

        local idx = getClosestMarkerIdx()
        local mesh = tes3.loadMesh(editorMarker)
        local child = mesh:clone()

        local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() *
                         256

        child.translation = tes3vector3.new(from.x, from.y, from.z)
        child.appCulled = false

        local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
        ---@diagnostic disable-next-line: param-type-mismatch
        vfxRoot:attachChild(child)
        vfxRoot:update()

        table.insert(editorData.editorMarkers, idx + 1, child)

        editorData.currentMarker = child
        editmode = true
    end

    -- marker edit mode
    if e.keyCode == tes3.scanCode["lCtrl"] then
        local idx = getClosestMarkerIdx()
        editmode = not editmode
        tes3.messageBox("Marker index: " .. idx)
        if not editmode then
            if editorData then traceRoute(editorData.service) end
        end
    end

    -- delete
    if e.keyCode == tes3.scanCode["delete"] then
        if not editorData then return end
        if not editorData.editorMarkers then return end

        local idx = getClosestMarkerIdx()

        local instance = editorData.editorMarkers[idx]
        local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
        vfxRoot:detachChild(instance)

        table.remove(editorData.editorMarkers, idx)

        if editorData then traceRoute(editorData.service) end
    end

    -- trace
    if e.keyCode == tes3.scanCode["forwardSlash"] then
        if editorData then traceRoute(editorData.service) end
    end

end
event.register(tes3.event.keyDown, editor_keyDownCallback)

--- Cleanup on save load
--- @param e loadEventData
local function editloadCallback(e) cleanup() end
event.register(tes3.event.load, editloadCallback)
