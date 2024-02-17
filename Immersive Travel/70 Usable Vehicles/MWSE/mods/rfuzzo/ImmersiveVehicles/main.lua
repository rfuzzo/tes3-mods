local common = require("rfuzzo.ImmersiveTravel.common")

local logger = require("logging.logger")
local log = logger.new {
    name = "ImmersiveVehicles",
    logLevel = "DEBUG", --TODO remove after debugging
    logToConsole = true,
    includeTimestamp = true
}

-- CONSTANTS

local localmodpath = "mods\\rfuzzo\\ImmersiveVehicles\\"

local sway_max_amplitude = 3       -- how much the ship can sway in a turn
local sway_amplitude_change = 0.01 -- how much the ship can sway in a turn
local sway_frequency = 0.12        -- how fast the mount sways
local sway_amplitude = 0.014       -- how much the mount sways
local speed_change = 1
local timertick = 0.01
local travelMarkerId = "marker_arrow.nif"

local travelMarkerMesh = nil
local mountMarkerMesh = nil

-- VARIABLES

local myTimer = nil ---@type mwseTimer | nil
local currentSpline = nil ---@type tes3vector3|nil

local swayTime = 0
local last_position = nil ---@type tes3vector3|nil
local last_forwardDirection = nil ---@type tes3vector3|nil
local last_facing = nil ---@type number|nil
local last_sway = 0 ---@type number
local current_speed = 0 ---@type number
local is_on_boat = false

local mountData = nil ---@type MountData|nil
local mountHandle = nil ---@type mwseSafeObjectHandle|nil

local travelMarker = nil ---@type niNode?
local mountMarker = nil ---@type niNode?

local editmode = false

-- HELPERS

local function safeCancelTimer() if myTimer ~= nil then myTimer:cancel() end end

local function cleanup()
    log:debug("cleanup")

    -- reset global vars
    safeCancelTimer()
    currentSpline = nil

    swayTime = 0
    last_position = nil
    last_forwardDirection = nil
    last_facing = nil
    last_sway = 0
    current_speed = 0
    is_on_boat = false

    if mountData and mountHandle and mountHandle:valid() then
        tes3.removeSound({ sound = mountData.sound, reference = mountHandle:getObject() })
    end

    if mountData then
        -- delete guide
        if mountData.guideSlot.handle and mountData.guideSlot.handle:valid() then
            mountData.guideSlot.handle:getObject():delete()
            mountData.guideSlot.handle = nil
        end

        -- delete statics
        if mountData.clutter then
            for index, clutter in ipairs(mountData.clutter) do
                if clutter.handle and clutter.handle:valid() then
                    clutter.handle:getObject():delete()
                    clutter.handle = nil
                end
            end
        end
    end
    mountData = nil
    mountHandle = nil
    -- don't delete ref since we may want to use the mount later
    -- if mount then mount:delete() end

    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    ---@diagnostic disable-next-line: param-type-mismatch
    if travelMarker then vfxRoot:detachChild(travelMarker) end
    if mountMarker then vfxRoot:detachChild(mountMarker) end
    travelMarker = nil
    mountMarker = nil
end

local function destinationReached()
    if not mountData then return end

    log:debug("destinationReached")

    -- reset player
    tes3.mobilePlayer.movementCollision = true;
    tes3.loadAnimation({ reference = tes3.player })
    tes3.playAnimation({ reference = tes3.player, group = 0 })

    -- teleport followers
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

    cleanup()
end

--- load json static mount data
---@param id string
---@return MountData|nil
local function loadMountData(id)
    local filePath = localmodpath .. "mounts\\" .. id .. ".json"
    local result = {} ---@type table<string, MountData>
    result = json.loadfile(filePath)
    if result then
        log:debug("loaded mount: " .. id)
        return result
    else
        log:error("!!! failed to load mount: " .. id)
        return nil
    end
end

-- LOGIC

--- main loop
local function onTimerTick()
    -- checks
    if mountHandle == nil then
        cleanup()
        return
    end
    if not mountHandle:valid() then
        cleanup()
        return
    end
    if mountData == nil then
        cleanup()
        return
    end
    if myTimer == nil then
        cleanup()
        return
    end
    if currentSpline == nil then
        cleanup()
        return
    end

    if last_position == nil then
        cleanup()
        return
    end
    if last_facing == nil then
        cleanup()
        return
    end
    if last_forwardDirection == nil then
        cleanup()
        return
    end

    local mount = mountHandle:getObject()
    if mount.sceneNode == nil then
        cleanup()
        return
    end

    -- skip
    if current_speed < mountData.minSpeed then return end

    local mountOffset = tes3vector3.new(0, 0, mountData.offset) * mount.scale
    local nextPos = currentSpline
    local currentPos = last_position - mountOffset

    -- calculate diffs
    local forwardDirection = last_forwardDirection
    forwardDirection:normalize()
    local d = (nextPos - currentPos):normalized()
    local lerp = forwardDirection:lerp(d, mountData.turnspeed / 10):normalized()

    -- calculate position
    local forward = tes3vector3.new(mount.forwardDirection.x, mount.forwardDirection.y, lerp.z):normalized()
    local delta = forward * current_speed

    -- local playerShipLocal = mount.sceneNode.worldTransform:invert() * tes3.player.position

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
    local newOrientation = common.toWorldOrientation(tes3vector3.new(0.0, sway, 0.0), mount.orientation)
    mount.orientation = newOrientation

    -- passengers
    for index, slot in ipairs(mountData.slots) do
        if slot.handle and slot.handle:valid() then
            local obj = slot.handle:getObject()
            slot.handle:getObject().position =
                mount.sceneNode.worldTransform * common.vec(slot.position)
        end
    end

    -- statics
    if mountData.clutter then
        for index, clutter in ipairs(mountData.clutter) do
            if clutter.handle and clutter.handle:valid() then
                clutter.handle:getObject().position = mount.sceneNode.worldTransform * common.vec(clutter.position)
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
    if travelMarkerMesh == nil then return end
    if mountData == nil then return end
    if mountHandle == nil then return end
    if not mountHandle:valid() then return end

    cleanup()

    local mount = mountHandle:getObject()
    currentSpline = mount.position

    -- fade out
    tes3.fadeOut({ duration = 1 })

    -- fade back in
    timer.start({
        type = timer.simulate,
        iterations = 1,
        duration = 1,
        callback = (function()
            tes3.fadeIn({ duration = 1 })

            -- visualize debug marker
            local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
            local child = travelMarkerMesh:clone()
            local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256
            child.translation = from
            child.appCulled = false
            ---@diagnostic disable-next-line: param-type-mismatch
            vfxRoot:attachChild(child)
            vfxRoot:update()
            travelMarker = child

            -- calculate positions
            local startPos = currentSpline
            local mountOffset = tes3vector3.new(0, 0, mountData.offset) * mountData.scale

            -- register player
            log:debug("> registering player")
            tes3.player.position = startPos + mountOffset
            common.registerRefInRandomSlot(mountData, tes3.makeSafeObjectHandle(tes3.player))

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
                            common.registerStatic(mountData, tes3.makeSafeObjectHandle(inst), index)
                        else
                            local inst =
                                tes3.createReference {
                                    object = clutter.id,
                                    position = startPos + mountOffset,
                                    orientation = mount.orientation
                                }
                            common.registerStatic(mountData, tes3.makeSafeObjectHandle(inst), index)
                        end
                    end
                end
            end

            -- start timer
            is_on_boat = true
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

-- EVENTS

---@type string[]
local mounts = {
    "a_gondola_01",
    "ex_gondola_01"
}

--- check if valid mount
---@param id string
---@return boolean
local function validMount(id)
    return common.is_in(mounts, id)
end

--- map ids to mounts
---@param id string
---@return string|nil
local function getMountForId(id)
    if id == "a_gondola_01" or id == "ex_gondola_01" then
        return "my_gondola"
    end
    return nil
end

--- @param e activateEventData
local function activateCallback(e)
    if validMount(e.target.id) then
        if is_on_boat then
            -- stop
            safeCancelTimer()
            tes3.fadeOut()
            timer.start({
                type = timer.simulate,
                duration = 1,
                callback = (function()
                    tes3.fadeIn()
                    destinationReached()
                end)
            })
        else
            mountData = loadMountData(getMountForId(e.target.id))
            if mountData then
                mountHandle = tes3.makeSafeObjectHandle(e.target)
                startTravel()
            end
        end
    end
end
event.register(tes3.event.activate, activateCallback)

--- @param e keyDownEventData
local function keyDownCallback(e)
    if not travelMarkerMesh then return nil end

    -- TODO remove after debug
    if e.keyCode == tes3.scanCode["o"] then
        if editmode then
            -- leave editor and spawn vehicle
            if mountMarker then
                -- add vehicles selections
                local obj = tes3.createReference {
                    object = "a_gondola_01",
                    position = mountMarker.translation,
                    orientation = mountMarker.rotation:toEulerXYZ(),
                    scale = mountMarker.scale -- TODO use proper mountdata
                }
                obj.facing = tes3.player.facing

                -- remove marker
                -- TODO use real ref instead of vfx node
                local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
                vfxRoot:detachChild(mountMarker)
                mountMarker = nil
            end

            editmode = false
        else
            -- start editor
            mountData = loadMountData("my_gondola")
            if not mountData then return nil end

            -- visualize placement node
            local target = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256

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
        end
    end

    if is_on_boat and mountData then
        if e.keyCode == tes3.scanCode["w"] then
            -- increment speed
            if current_speed < mountData.maxSpeed then
                current_speed = math.clamp(current_speed + speed_change, mountData.minSpeed, mountData.maxSpeed)
                tes3.messageBox("Current Speed: " .. tostring(current_speed))
            end
        end
        if e.keyCode == tes3.scanCode["s"] then
            -- decrement speed
            if current_speed > mountData.minSpeed then
                current_speed = math.clamp(current_speed - speed_change, mountData.minSpeed, mountData.maxSpeed)
                tes3.messageBox("Current Speed: " .. tostring(current_speed))
            end
        end
    end
end
event.register(tes3.event.keyDown, keyDownCallback)

--- visualize on tick
--- @param e simulatedEventData
local function simulatedCallback(e)
    if editmode and mountMarker and mountData then
        -- visualize mount scene node
        -- TODO inwater check
        local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 512
        from.z = mountData.offset * mountData.scale
        mountMarker.translation = from
        local m = tes3matrix33.new()
        m:fromEulerXYZ(tes3.player.orientation.x, tes3.player.orientation.y, tes3.player.orientation.z)
        mountMarker.rotation = m
        mountMarker:update()
    end

    if is_on_boat and travelMarker and mountHandle and mountHandle:valid() and mountData then
        -- update next pos
        local target = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 2048
        target.z = 0
        currentSpline = target

        -- render debug marker
        --TODO remove after debugging
        travelMarker.translation = target
        local m = tes3matrix33.new()
        m:fromEulerXYZ(tes3.player.orientation.x, tes3.player.orientation.y, tes3.player.orientation.z)
        travelMarker.rotation = m
        travelMarker:update()

        -- collision
        -- TODO get positions from mount data
        -- raytest at sealevel to detect shore transition
        local testPosition1 = mountHandle:getObject().sceneNode.worldTransform * common.vec(mountData.shoreRayPos)
        local hitResult1 = tes3.rayTest({
            position = testPosition1,
            direction = tes3vector3.new(0, 0, -1),
            root = tes3.game.worldLandscapeRoot,
            maxDistance = 4096
        })
        if (hitResult1 == nil) then
            current_speed = 0
            tes3.messageBox("HIT Shore")
        end

        -- raytest from above to detect objects in water
        local testPosition2 = mountHandle:getObject().sceneNode.worldTransform * common.vec(mountData.objectRayPos)
        local hitResult2 = tes3.rayTest({
            position = testPosition2,
            direction = tes3vector3.new(0, 0, -1),
            root = tes3.game.worldObjectRoot,
            maxDistance = 512
        })
        if (hitResult2 ~= nil) then
            -- TODO clamp max speed
            current_speed = 0
            tes3.messageBox("HIT Object")
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
