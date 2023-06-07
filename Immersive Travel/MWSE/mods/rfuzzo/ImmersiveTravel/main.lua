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
- to start traveling	... / on the silt strider in Seyda Neen

--]] local test_menu = tes3ui.registerID("example:MenuTest")
local test_menu_ok = tes3ui.registerID("example:MenuTest_Ok")
local test_menu_cancel = tes3ui.registerID("example:MenuTest_Cancel")

---@type mwseTimer | nil
local myTimer = nil
local spline_index = 1
local speed = 4 -- the speed of the object in units per timertick
local angle = 0.002 -- the angle of rotation in radians per timertick
local timertick = 0.01

local sn = require("rfuzzo.ImmersiveTravel.data.default")

---@type tes3reference | nil
local mount = nil
local mountOffset = tes3vector3.new(0, 0, -1100)

-- editor
---@type niNode[]
local editor_markers = {}
local editor_instance = nil
local editmode = false
local editor_marker = "marker_arrow.nif"

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

local function onTimerTick()
    if mount == nil then return; end
    if myTimer == nil then return; end

    if spline_index <= #sn.spline then -- if i is not at the end of the list
        local s = sn.spline[spline_index]
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

-- OK button callback.
local function onTestOK(e)
    if mount == nil then return end

    local menu = tes3ui.findMenu(test_menu)
    if (menu) then
        myTimer = timer.start({
            duration = timertick,
            type = timer.real,
            iterations = -1,
            callback = onTimerTick
        })

        tes3ui.leaveMenuMode()
        menu:destroy()
    end
end

-- Cancel button callback.
local function onTestCancel(e)
    local menu = tes3ui.findMenu(test_menu)

    if (menu) then
        mount = nil
        tes3ui.leaveMenuMode()
        menu:destroy()
    end
end

-- Create window and layout. Called by onCommand.
local function createTestWindow()
    -- Return if window is already open
    if (tes3ui.findMenu(test_menu) ~= nil) then return end

    -- Create window and frame
    local menu = tes3ui.createMenu {id = test_menu, fixedFrame = true}

    -- To avoid low contrast, text input windows should not use menu transparency settings
    menu.alpha = 1.0

    -- Create layout
    local input_label = menu:createLabel{text = "Start"}
    input_label.borderBottom = 5

    local input_block = menu:createBlock{}
    input_block.width = 300
    input_block.autoHeight = true
    input_block.childAlignX = 0.5 -- centre content alignment

    local button_block = menu:createBlock{}
    button_block.widthProportional = 1.0 -- width is 100% parent width
    button_block.autoHeight = true
    button_block.childAlignX = 1.0 -- right content alignment

    local button_ok = button_block:createButton{
        id = test_menu_ok,
        text = "Start"
    }
    local button_cancel = button_block:createButton{
        id = test_menu_cancel,
        text = "Cancel"
    }

    -- Events
    button_cancel:register(tes3.uiEvent.mouseClick, onTestCancel)
    button_ok:register(tes3.uiEvent.mouseClick, onTestOK)

    -- Final setup
    menu:updateLayout()
    tes3ui.enterMenuMode(test_menu)
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EDITOR

-- Keydown callback.
local function startTravel()
    local t = getLookedAtReference()
    if (t) then

        mwse.log("=== start === ")
        mwse.log("baseObject: " .. t.baseObject.id)
        mwse.log("mesh: " .. t.baseObject.mesh)
        mwse.log("position: " .. t.position:__tostring())
        mwse.log("boundingBox: " .. t.baseObject.boundingBox:__tostring())
        mwse.log("height: " .. t.baseObject.boundingBox.max.z)
        mwse.log("=== end === ")

        mount = t
        createTestWindow()
    end
end

---@param a number
---@return tes3matrix33
local function rotation_matrix_z(a)
    local c = math.cos(a)
    local s = math.sin(a)
    return tes3matrix33.new(c, -s, 0, s, c, 0, 0, 0, 1)
end

local function updateMarkers()
    -- update rotation
    for index, marker in ipairs(editor_markers) do
        if index < #editor_markers then
            local nextMarker = editor_markers[index + 1]
            local dist = nextMarker.translation - marker.translation
            -- dist:normalize()
            local rotz = tes3vector3.new(0, 1, 0):angle(
                             tes3vector3.new(dist.x, dist.y, 0))
            -- local rotz = math.atan2(dist.x, dist.y)
            -- if index == 1 then
            -- 	mwse.log(rotz)
            -- end

            local m = tes3matrix33.new()
            m:toIdentity()
            m = rotation_matrix_z(rotz)
            marker.rotation = m

        end
    end

    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    vfxRoot:update()
end

---@return number
local function getClosestMarkerIdx()
    -- get closest marker
    local pp = tes3.player.position

    local finali = 0
    local last_d = nil
    for index, value in ipairs(editor_markers) do
        local d = pp:distance(value.translation)

        -- first
        if last_d == nil then
            last_d = d
            finali = 1
        end

        if d < last_d then
            finali = index
            last_d = d
        end
    end

    editor_instance = editor_markers[finali]

    updateMarkers()

    return finali
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

local function renderMarkers()
    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    vfxRoot:detachAllChildren()

    -- add markers
    local mesh = tes3.loadMesh(editor_marker)

    for idx, v in ipairs(sn.spline) do

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

-- Keydown callback.
local function onLogCommand(e)
    -- createLogWindow()
    mwse.log(tes3.player.position.x .. "," .. tes3.player.position.y .. "," ..
                 tes3.player.position.z)
    tes3.messageBox(tes3.player.position.x .. "," .. tes3.player.position.y ..
                        "," .. tes3.player.position.z)

end

--- @param e loadEventData
local function loadCallback(e)
    -- renderMarkers()
end
event.register(tes3.event.load, loadCallback)

event.register("simulate", function(e)
    if editmode == false then return end

    local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256
    local groundZ = getGroundZ(from)
    from.z = groundZ + 1025

    editor_instance.translation = from
    editor_instance:update()
end)

--- @param e keyDownEventData
local function keyDownCallback(e)

    -- edit mode
    if e.keyCode == tes3.scanCode["lCtrl"] then
        getClosestMarkerIdx()

        -- if editmode == true then
        --     -- leave edit mode and adjust marker
        --     local gz = getGroundZ(editor_instance.translation)
        --     editor_instance.translation.z = gz + 1025
        --     updateMarkers()
        -- end

        editmode = not editmode
    end

    -- start travel
    if e.keyCode == tes3.scanCode["forwardSlash"] then startTravel() end

    -- render markers
    if e.keyCode == tes3.scanCode["p"] then renderMarkers() end

    -- raytest
    if e.keyCode == tes3.scanCode["o"] then raytest() end

    -- delete
    if e.keyCode == tes3.scanCode["delete"] then
        local idx = getClosestMarkerIdx()

        local instance = editor_markers[idx]
        local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
        vfxRoot:detachChild(instance)

        table.remove(editor_markers, idx)
    end

    -- insert
    if e.keyCode == tes3.scanCode["keyLeft"] then
        local idx = getClosestMarkerIdx()
        -- insert new instance

        local mesh = tes3.loadMesh(editor_marker)
        local child = mesh:clone()

        local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() *
                         256

        child.translation = tes3vector3.new(from.x, from.y, from.z)
        -- TODO heading to next node
        child.appCulled = false

        local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
        ---@diagnostic disable-next-line: param-type-mismatch
        vfxRoot:attachChild(child)
        vfxRoot:update()

        table.insert(editor_markers, idx, child)

        editor_instance = child
        editmode = true
    end

    -- print
    if e.keyCode == tes3.scanCode["keyRight"] then

        mwse.log("============================================")
        for _, value in ipairs(editor_markers) do
            local p = value.translation

            -- local z = getGroundZ(p)
            -- if z == nil then
            mwse.log("X { x = " .. math.round(p.x) .. ", y = " ..
                         math.round(p.y) .. ", z = " .. math.round(p.z) .. " },")
            -- else
            --     mwse.log("{ x = " .. math.round(p.x) .. ", y = " ..
            --                  math.round(p.y) .. ", z = " .. math.round(z + 1025) ..
            --                  " },")
            -- end

        end
        mwse.log("============================================")

        tes3.messageBox("Printed coordinates")
    end
end
event.register(tes3.event.keyDown, keyDownCallback)

