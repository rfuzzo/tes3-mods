local common = require("rfuzzo.ImmersiveTravel.common")

local DEBUG = true

local logger = require("logging.logger")
local log = logger.new {
    name = "Immersive Vehicles",
    logLevel = "DEBUG", -- TODO add to mcm?
    logToConsole = true,
    includeTimestamp = true
}

-- CONSTANTS

-- TODO read from files
---@type string[]
local mounts = {}

local localmodpath = "mods\\rfuzzo\\ImmersiveVehicles\\"
local fullmodpath = "Data Files\\MWSE\\" .. localmodpath

local sway_max_amplitude = 3       -- how much the ship can sway in a turn
local sway_amplitude_change = 0.01 -- how much the ship can sway in a turn
local sway_frequency = 0.12        -- how fast the mount sways
local sway_amplitude = 0.014       -- how much the mount sways
local timertick = 0.01
local travelMarkerId = "marker_arrow.nif"

local travelMarkerMesh = nil
local mountMarkerMesh = nil

-- VARIABLES

local myTimer = nil ---@type mwseTimer | nil
local virtualDestination = nil ---@type tes3vector3|nil

local swayTime = 0
local last_position = nil ---@type tes3vector3|nil
local last_forwardDirection = nil ---@type tes3vector3|nil
local last_facing = nil ---@type number|nil
local last_sway = 0 ---@type number
local current_speed = 0 ---@type number
local is_on_mount = false

local mountData = nil ---@type MountData|nil
local mountHandle = nil ---@type mwseSafeObjectHandle|nil

local travelMarker = nil ---@type niNode?
local mountMarker = nil ---@type niNode?

local cameraOffset = nil ---@type tes3vector3?
local editmode = false
local speedChange = 0

--- HELPERS


--- @param from tes3vector3
--- @return number|nil
local function getGroundZ(from)
    local rayhit = tes3.rayTest {
        position = from,
        direction = tes3vector3.new(0, 0, -1),
        returnNormal = true,
        root = tes3.game.worldLandscapeRoot
    }

    if (rayhit) then
        local to = rayhit.intersection
        return to.z
    end

    return nil
end

--- EVENTS

--- @param e mouseWheelEventData
local function mouseWheelCallback(e)
    local isControlDown = tes3.worldController.inputController:isControlDown()
    if is_on_mount and isControlDown then
        -- update fov
        if e.delta > 0 then
            tes3.set3rdPersonCameraOffset({ offset = tes3.get3rdPersonCameraOffset() + tes3vector3.new(0, 10, 0) })
        else
            tes3.set3rdPersonCameraOffset({ offset = tes3.get3rdPersonCameraOffset() - tes3vector3.new(0, 10, 0) })
        end
    end
end

--- @param e keyDownEventData
local function mountKeyDownCallback(e)
    if is_on_mount and mountHandle and mountHandle:valid() and mountData then
        if e.keyCode == tes3.scanCode["w"] then
            -- increment speed
            if current_speed < mountData.maxSpeed then
                speedChange = 1
                -- play anim
                if mountData.accelerateAnimation then
                    tes3.loadAnimation({ reference = mountHandle:getObject() })
                    tes3.playAnimation({
                        reference = mountHandle:getObject(),
                        group = tes3.animationGroup
                            [mountData.accelerateAnimation]
                    })
                end
            end
        end

        if e.keyCode == tes3.scanCode["s"] then
            -- decrement speed
            if current_speed > mountData.minSpeed then
                speedChange = -1
                -- play anim
                if mountData.accelerateAnimation then
                    tes3.loadAnimation({ reference = mountHandle:getObject() })
                    tes3.playAnimation({
                        reference = mountHandle:getObject(),
                        group = tes3.animationGroup
                            [mountData.accelerateAnimation]
                    })
                end
            end
        end
    end
end

--- @param e keyUpEventData
local function keyUpCallback(e)
    if is_on_mount and mountHandle and mountHandle:valid() and mountData then
        if e.keyCode == tes3.scanCode["w"] or e.keyCode == tes3.scanCode["s"] then
            -- stop increment speed
            speedChange = 0
            -- play anim
            if mountData.forwardAnimation then
                tes3.loadAnimation({ reference = mountHandle:getObject() })
                tes3.playAnimation({
                    reference = mountHandle:getObject(),
                    group = tes3.animationGroup
                        [mountData.forwardAnimation]
                })
            end

            if DEBUG then
                tes3.messageBox("Current Speed: " .. tostring(current_speed))
            end
        end
    end
end

--- visualize on tick
--- @param e simulatedEventData
local function mountSimulatedCallback(e)
    -- update next pos
    if not editmode and is_on_mount and mountHandle and mountHandle:valid() and
        mountData then
        local mount = mountHandle:getObject()
        local dist = 2048
        if mountData.freedomtype == "ground" then
            dist = 100
        end
        local target = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * dist

        local isControlDown = tes3.worldController.inputController:isControlDown()
        if isControlDown then
            target = mount.sceneNode.worldTransform * tes3vector3.new(0, 2048, 0)
        end
        if mountData.freedomtype == "boat" then
            -- pin to waterlevel
            target.z = 0
        elseif mountData.freedomtype == "ground" then
            -- pin to groundlevel
            local z = getGroundZ(target + tes3vector3.new(0, 0, 100))
            if not z then
                target.z = 0
            else
                target.z = z + 50
            end
        end

        virtualDestination = target

        -- render debug marker
        if DEBUG and travelMarker then
            travelMarker.translation = target
            local m = tes3matrix33.new()
            if isControlDown then
                m:fromEulerXYZ(mount.orientation.x, mount.orientation.y, mount.orientation.z)
            else
                m:fromEulerXYZ(tes3.player.orientation.x, tes3.player.orientation.y, tes3.player.orientation.z)
            end
            travelMarker.rotation = m
            travelMarker:update()
        end
    end

    -- collision
    if not editmode and is_on_mount and mountHandle and mountHandle:valid() and mountData then
        -- raytest at sealevel to detect shore transition
        local bbox = mountHandle:getObject().object.boundingBox
        local t = mountHandle:getObject().sceneNode.worldTransform

        if current_speed > 0 then
            if mountData.freedomtype == "boat" then
                local bowPos = t * tes3vector3.new(0, bbox.max.y, bbox.min.z + mountData.offset)
                local hitResult1 = tes3.rayTest({
                    position = bowPos,
                    direction = tes3vector3.new(0, 0, -1),
                    root = tes3.game.worldLandscapeRoot,
                    --maxDistance = 4096
                })
                if (hitResult1 == nil) then
                    current_speed = 0
                    if DEBUG then tes3.messageBox("HIT Shore Fwd") end
                end
            end

            -- raytest from above to detect objects in water
            local bowPosTop = t * tes3vector3.new(0, bbox.max.y, bbox.max.z)
            local hitResult2 = tes3.rayTest({
                position = bowPosTop,
                direction = tes3vector3.new(0, 0, -1),
                root = tes3.game.worldObjectRoot,
                maxDistance = bbox.max.z
            })
            if (hitResult2 ~= nil) then
                current_speed = 0
                if DEBUG then tes3.messageBox("HIT Object Fwd") end
            end
        elseif current_speed < 0 then
            if mountData.freedomtype == "boat" then
                local sternPos = t * tes3vector3.new(0, bbox.min.y, bbox.min.z + mountData.offset)
                local hitResult1 = tes3.rayTest({
                    position = sternPos,
                    direction = tes3vector3.new(0, 0, -1),
                    root = tes3.game.worldLandscapeRoot,
                    --maxDistance = 4096
                })
                if (hitResult1 == nil) then
                    current_speed = 0
                    if DEBUG then tes3.messageBox("HIT Shore Back") end
                end
            end

            -- raytest from above to detect objects in water
            local sternPosTop = t * tes3vector3.new(0, bbox.min.y, bbox.max.z)
            local hitResult2 = tes3.rayTest({
                position = sternPosTop,
                direction = tes3vector3.new(0, 0, -1),
                root = tes3.game.worldObjectRoot,
                maxDistance = bbox.max.z
            })
            if (hitResult2 ~= nil) then
                current_speed = 0
                if DEBUG then tes3.messageBox("HIT Object Back") end
            end
        end
    end
end

-- HELPERS

local function safeCancelTimer() if myTimer ~= nil then myTimer:cancel() end end

local function cleanup()
    log:debug("cleanup")

    if cameraOffset then
        tes3.set3rdPersonCameraOffset({ offset = cameraOffset })
    end

    -- reset global vars
    safeCancelTimer()
    virtualDestination = nil

    swayTime = 0
    last_position = nil
    last_forwardDirection = nil
    last_facing = nil
    last_sway = 0
    current_speed = 0
    is_on_mount = false
    current_speed = 0

    if mountData and mountHandle and mountHandle:valid() then
        tes3.removeSound({
            sound = mountData.sound,
            reference = mountHandle:getObject()
        })
    end
    mountHandle = nil

    if mountData then
        -- delete statics
        if mountData.clutter then
            log:debug("cleanup statics")
            for index, clutter in ipairs(mountData.clutter) do
                if clutter.handle and clutter.handle:valid() then
                    clutter.handle:getObject():delete()
                    clutter.handle = nil
                    log:debug("cleanup static " .. clutter.id)
                end
            end
        end
    end
    mountData = nil

    -- don't delete ref since we may want to use the mount later
    -- if mount then mount:delete() end

    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    ---@diagnostic disable-next-line: param-type-mismatch
    if travelMarker then vfxRoot:detachChild(travelMarker) end
    if mountMarker then vfxRoot:detachChild(mountMarker) end
    travelMarker = nil
    mountMarker = nil

    -- unregister events
    event.unregister(tes3.event.mouseWheel, mouseWheelCallback)
    event.unregister(tes3.event.keyDown, mountKeyDownCallback)
    event.unregister(tes3.event.keyUp, keyUpCallback)
    event.unregister(tes3.event.simulated, mountSimulatedCallback)
end

local function destinationReached()
    log:debug("destinationReached")

    -- reset player
    tes3.mobilePlayer.movementCollision = true;
    tes3.loadAnimation({ reference = tes3.player })
    tes3.playAnimation({ reference = tes3.player, group = 0 })

    -- teleport followers
    if mountData then
        for index, slot in ipairs(mountData.slots) do
            if slot.handle and slot.handle:valid() then
                local ref = slot.handle:getObject()
                if ref ~= tes3.player and ref.mobile and
                    common.isFollower(ref.mobile) then
                    log:debug("teleporting follower " .. ref.id)

                    ref.mobile.movementCollision = true;
                    tes3.loadAnimation({ reference = ref })
                    tes3.playAnimation({ reference = ref, group = 0 })

                    local f = tes3.player.forwardDirection
                    f:normalize()
                    local offset = f * 60.0
                    tes3.positionCell({
                        reference = ref,
                        position = tes3.player.position + offset
                    })

                    slot.handle = nil
                end
            end
        end
    end

    cleanup()
end

---Checks if a reference is on water
---@param reference tes3reference
---@param data MountData
---@return boolean
local function onWater(reference, data)
    local cell = tes3.player.cell
    local waterLevel = cell.hasWater and cell.waterLevel
    if not cell.isInterior and waterLevel and reference.position.z - waterLevel <
        data.offset then
        return true
    end
    return false
end

local function playerIsUnderwater()
    local waterLevel = tes3.mobilePlayer.cell.waterLevel
    local minPosition = tes3.mobilePlayer.position.z

    return minPosition < waterLevel
end



--- load json static mount data
---@param id string
---@return MountData|nil
local function loadMountData(id)
    local filePath = localmodpath .. "mounts\\" .. id .. ".json"
    local result = nil ---@type MountData?
    result = json.loadfile(filePath)
    if result then
        log:debug("loaded mount: " .. id)
        -- set defaults
        if not result.scale then
            result.scale = 1.0
        end

        return result
    else
        log:error("!!! failed to load mount: " .. id)
        return nil
    end
end

-- LOGIC

--- check if valid mount
---@param id string
---@return boolean
local function validMount(id) return common.is_in(mounts, id) end

--- Load all mounts
---@return table<string,ServiceData>|nil
local function loadMounts()
    log:debug("Loading mounts...")

    ---@type string[]
    local services = {}
    for fileName in lfs.dir(fullmodpath .. "mounts") do
        if (string.endswith(fileName, ".json")) then
            -- parse
            local fullpath = localmodpath .. "mounts\\" .. fileName
            local r = json.loadfile(fullpath)
            if r then
                table.insert(services, fileName:sub(0, -6))

                log:trace("Loaded " .. fullpath)
            else
                log:error("!!! failed to load " .. fileName)
            end
        end
    end
    return services
end

--- map ids to mounts
---@param id string
---@return string|nil
local function getMountForId(id)
    -- NOTE add exceptions here
    return id
end

--- main loop
local function onTimerTick()
    -- checks
    if mountHandle == nil then
        return
    end
    if not mountHandle:valid() then
        return
    end
    if mountData == nil then
        return
    end
    if myTimer == nil then
        return
    end
    if virtualDestination == nil then
        return
    end

    if last_position == nil then
        return
    end
    if last_facing == nil then
        return
    end
    if last_forwardDirection == nil then
        return
    end

    local mount = mountHandle:getObject()
    if mount.sceneNode == nil then
        return
    end

    local rootBone = mount.sceneNode
    if mountData.nodeName then
        rootBone = mount.sceneNode:getObjectByName(mountData.nodeName) --[[@as niNode]]
    end
    if rootBone == nil then
        rootBone = mount.sceneNode
    end
    if rootBone == nil then
        return
    end

    -- register keypresses
    if speedChange > 0 then
        local change = current_speed + (mountData.changeSpeed * timertick)
        current_speed = math.clamp(change, mountData.minSpeed, mountData.maxSpeed)
    elseif speedChange < 0 then
        local change = current_speed - (mountData.changeSpeed * timertick)
        current_speed = math.clamp(change, mountData.minSpeed, mountData.maxSpeed)
    end

    -- skip
    if current_speed < mountData.minSpeed then return end

    local mountOffset = tes3vector3.new(0, 0, mountData.offset) * mount.scale
    local nextPos = virtualDestination
    local currentPos = last_position - mountOffset

    -- calculate diffs
    local forwardDirection = last_forwardDirection
    forwardDirection:normalize()
    local d = (nextPos - currentPos):normalized()

    -- calculate position
    local lerp = forwardDirection:lerp(d, mountData.turnspeed / 10.0):normalized()
    local forward = tes3vector3.new(mount.forwardDirection.x, mount.forwardDirection.y, lerp.z):normalized()
    local delta = forward * current_speed

    -- calculate facing
    local turn = 0
    local current_facing = last_facing
    local new_facing = math.atan2(d.x, d.y)
    local facing = new_facing
    local diff = new_facing - current_facing
    if diff < -math.pi then diff = diff + 2 * math.pi end
    if diff > math.pi then diff = diff - 2 * math.pi end
    local angle = mountData.turnspeed / 10000
    if diff > 0 and diff > angle then
        facing = current_facing + angle
        turn = 1
    elseif diff < 0 and diff < -angle then
        facing = current_facing - angle
        turn = -1
    else
        facing = new_facing
    end

    -- move ship
    mount.facing = facing
    mount.position = currentPos + delta + mountOffset

    -- save
    last_position = mount.position
    last_forwardDirection = mount.forwardDirection
    last_facing = mount.facing

    -- set sway
    local amplitude = sway_amplitude * mountData.sway
    local sway_change = amplitude * sway_amplitude_change
    swayTime = swayTime + timertick
    if swayTime > (2000 * sway_frequency) then swayTime = timertick end

    local sway = amplitude * math.sin(2 * math.pi * sway_frequency * swayTime)
    -- offset roll during turns
    if turn > 0 then
        local max = (sway_max_amplitude * amplitude)
        sway = math.clamp(last_sway - sway_change, -max, max) -- + sway
    elseif turn < 0 then
        local max = (sway_max_amplitude * amplitude)
        sway = math.clamp(last_sway + sway_change, -max, max) -- + sway
    else
        -- normalize back
        if last_sway < (sway - sway_change) then
            sway = last_sway + sway_change -- + sway
        elseif last_sway > (sway + sway_change) then
            sway = last_sway - sway_change -- + sway
        end
    end
    last_sway = sway
    local newOrientation = common.toWorldOrientation(
        tes3vector3.new(0.0, sway, 0.0),
        mount.orientation)
    mount.orientation = newOrientation

    -- passengers
    for index, slot in ipairs(mountData.slots) do
        if slot.handle and slot.handle:valid() then
            slot.handle:getObject().position = rootBone.worldTransform * common.vec(slot.position)
        end
    end

    -- statics
    if mountData.clutter then
        for index, clutter in ipairs(mountData.clutter) do
            if clutter.handle and clutter.handle:valid() then
                clutter.handle:getObject().position = rootBone.worldTransform * common.vec(clutter.position)
                if clutter.orientation then
                    clutter.handle:getObject().orientation = common.toWorldOrientation(
                        common.radvec(clutter.orientation), mount.orientation)
                end
            end
        end
    end
end

--- set up everything
local function startTravel()
    if mountData == nil then return end
    if mountHandle == nil then return end
    if not mountHandle:valid() then return end

    local mount = mountHandle:getObject()
    virtualDestination = mount.position

    -- fade out
    tes3.fadeOut({ duration = 1 })

    -- fade back in
    timer.start({
        type = timer.simulate,
        iterations = 1,
        duration = 1,
        callback = (function()
            tes3.fadeIn({ duration = 1 })

            -- position mount at ground level
            if mountData.freedomtype ~= "boat" then
                local top = tes3vector3.new(0, 0, mount.object.boundingBox.max.z)
                local z = getGroundZ(mount.position + top)
                if not z then
                    z = tes3.player.position.z
                end
                mount.position = tes3vector3.new(mount.position.x, mount.position.y,
                    z + (mountData.offset * mountData.scale))
            end
            mount.orientation = tes3.player.orientation

            -- visualize debug marker
            if DEBUG and travelMarkerMesh then
                local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
                local child = travelMarkerMesh:clone()
                local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256
                child.translation = from
                child.appCulled = false
                ---@diagnostic disable-next-line: param-type-mismatch
                vfxRoot:attachChild(child)
                vfxRoot:update()
                travelMarker = child
            end

            -- calculate positions
            local startPos = virtualDestination
            local mountOffset = tes3vector3.new(0, 0, mountData.offset) *
                mountData.scale

            -- register player
            log:debug("> registering player")
            tes3.player.position = startPos + mountOffset
            common.registerRefInRandomSlot(mountData, tes3.makeSafeObjectHandle(
                tes3.player))

            -- register statics
            if mountData.clutter then
                log:debug("> registering statics")
                for index, clutter in ipairs(mountData.clutter) do
                    if clutter.id then
                        -- instantiate
                        if clutter.orientation then
                            local inst =
                                tes3.createReference {
                                    object = clutter.id,
                                    position = startPos + mountOffset,
                                    orientation = common.toWorldOrientation(common.radvec(clutter.orientation), mount.orientation)
                                }
                            common.registerStatic(mountData,
                                tes3.makeSafeObjectHandle(inst),
                                index)
                        else
                            local inst =
                                tes3.createReference {
                                    object = clutter.id,
                                    position = startPos + mountOffset,
                                    orientation = mount.orientation
                                }
                            common.registerStatic(mountData,
                                tes3.makeSafeObjectHandle(inst),
                                index)
                        end
                    end
                end
            end

            -- start timer
            cameraOffset = tes3.get3rdPersonCameraOffset()
            is_on_mount = true
            current_speed = 1
            last_position = mount.position
            last_forwardDirection = mount.forwardDirection
            last_facing = mount.facing
            last_sway = 0
            tes3.playSound({
                sound = mountData.sound,
                reference = mount,
                loop = true
            })

            -- register events
            event.register(tes3.event.mouseWheel, mouseWheelCallback)
            event.register(tes3.event.keyDown, mountKeyDownCallback)
            event.register(tes3.event.keyUp, keyUpCallback)
            event.register(tes3.event.simulated, mountSimulatedCallback)

            log:debug("starting timer")
            myTimer = timer.start({
                duration = timertick,
                type = timer.simulate,
                iterations = -1,
                callback = onTimerTick
            })
        end)
    })
end

--- activate the vehicle
---@param reference tes3reference
local function activateMount(reference)
    if validMount(reference.id) then
        if is_on_mount then
            -- stop
            safeCancelTimer()
            destinationReached()
        else
            -- start
            mountData = loadMountData(getMountForId(reference.id))
            if mountData then
                mountHandle = tes3.makeSafeObjectHandle(reference)
                startTravel()
            end
        end
    end
end

-- EVENTS

local dbg_mount_id = nil ---@type string?

--- @param e keyDownEventData
local function keyDownCallback(e)
    -- leave editor and spawn vehicle
    if DEBUG then
        if e.keyCode == tes3.scanCode["o"] and editmode and mountMarker and dbg_mount_id then
            -- add vehicles selections
            local obj = tes3.createReference {
                object = dbg_mount_id,
                position = mountMarker.translation,
                orientation = mountMarker.rotation:toEulerXYZ(),
                scale = mountMarker.scale
            }
            obj.facing = tes3.player.facing

            -- remove marker
            local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
            vfxRoot:detachChild(mountMarker)
            mountMarker = nil
            editmode = false
        elseif e.keyCode == tes3.scanCode["o"] and not editmode and not is_on_mount then
            local buttons = {}
            mounts = loadMounts()
            for _, id in ipairs(mounts) do
                table.insert(buttons, {
                    text = id,
                    callback = function(e)
                        mountData = loadMountData(getMountForId(id))
                        if not mountData then return nil end
                        -- visualize placement node
                        local target = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * (256 / mountData.scale)

                        mountMarkerMesh = tes3.loadMesh(mountData.mesh)
                        local child = mountMarkerMesh:clone()
                        child.translation = target
                        child.scale = mountData.scale
                        child.appCulled = false
                        local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
                        ---@diagnostic disable-next-line: param-type-mismatch
                        vfxRoot:attachChild(child)
                        vfxRoot:update()
                        mountMarker = child

                        -- enter placement mode
                        editmode = true
                        dbg_mount_id = id
                    end,
                })
            end
            tes3ui.showMessageMenu({ id = "rf_dbg_iv", message = "Choose your mount", buttons = buttons, cancels = true })
        end
    end
end
event.register(tes3.event.keyDown, keyDownCallback)

--- visualize on tick
--- @param e simulatedEventData
local function simulatedCallback(e)
    -- visualize mount scene node
    if DEBUG then
        if editmode and mountMarker and mountData then
            local from = tes3.getPlayerEyePosition() + (tes3.getPlayerEyeVector() * 500.0 * mountData.scale)
            if mountData.freedomtype == "boat" then
                from.z = mountData.offset * mountData.scale
            elseif mountData.freedomtype == "ground" then
                local z = getGroundZ(from + tes3vector3.new(0, 0, 200))
                if not z then
                    from.z = 0
                else
                    from.z = z
                end
            end

            mountMarker.translation = from
            local m = tes3matrix33.new()
            m:fromEulerXYZ(tes3.player.orientation.x, tes3.player.orientation.y, tes3.player.orientation.z)
            mountMarker.rotation = m
            mountMarker:update()
        end
    end
end
event.register(tes3.event.simulated, simulatedCallback)

--- Cleanup on save load
--- @param e loadEventData
local function loadCallback(e)
    cleanup()
    travelMarkerMesh = tes3.loadMesh(travelMarkerId)
end
event.register(tes3.event.load, loadCallback)

--- @param e activateEventData
local function activateCallback(e) activateMount(e.target) end
event.register(tes3.event.activate, activateCallback)

-- RECIPES

local CraftingFramework = include("CraftingFramework")
if not CraftingFramework then return end

local enterVehicle = {
    text = "Get in/out",
    callback = function(e)
        activateMount(e.reference)
    end
}

---get recipe with data
---@param id string
local function getRecipeFor(id)
    local data = loadMountData(getMountForId(id))
    if data and data.materials and data.scale then
        local recipe = {
            id = "recipe_" .. id,
            craftableId = id,
            soundType = "wood",
            category = "Vehicles",
            materials = data.materials,
            scale = data.scale,
            craftedOnly = false,
            additionalMenuOptions = { enterVehicle },
            -- secondaryMenu         = false,
            quickActivateCallback = function(_, e) activateMount(e.reference) end
        }

        return recipe
    end
    return nil
end

---@type CraftingFramework.Recipe.data[]
local recipes = {}
mounts = loadMounts()
for _, id in ipairs(mounts) do
    local r = getRecipeFor(id)
    if r then
        table.insert(recipes, r)
    end
end

local function registerRecipes(e)
    if e.menuActivator then e.menuActivator:registerRecipes(recipes) end
end
event.register("Ashfall:ActivateBushcrafting:Registered", registerRecipes)
