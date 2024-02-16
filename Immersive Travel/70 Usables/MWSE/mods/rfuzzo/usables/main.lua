local common = require("rfuzzo.ImmersiveTravel.common")

local logger = require("logging.logger")
local log = logger.new {
    name = "mygondola",
    logLevel = "DEBUG",
    logToConsole = true,
    includeTimestamp = true
}

-- constants

local sway_max_amplitude = 3       -- how much the ship can sway in a turn
local sway_amplitude_change = 0.01 -- how much the ship can sway in a turn
local sway_frequency = 0.12        -- how fast the mount sways
local sway_amplitude = 0.014       -- how much the mount sways
local speed_change = 1
local speed_max = 10
local timertick = 0.01

-- variables

local myTimer = nil ---@type mwseTimer | nil

local mount = nil ---@type tes3reference | nil
local swayTime = 0
local currentSpline = nil ---@type tes3vector3|nil
local mountData = nil ---@type MountData|nil

local last_position = nil ---@type tes3vector3|nil
local last_forwardDirection = nil ---@type tes3vector3|nil
local last_facing = nil ---@type number|nil
local last_sway = 0 ---@type number

local current_speed = 0 ---@type number
local is_on_boat = false

local travelMarker = nil ---@type niNode?
local mountMarker = nil ---@type niNode?

local editmode = false

local travelMarkerId = "marker_arrow.nif"
local travelMarkerMesh = nil


local mountMarkerId = "x\\Ex_Gondola_01_rot.nif"
local mountMarkerMesh = nil

-- common

---@param pos PositionRecord
--- @return tes3vector3
local function vec(pos) return tes3vector3.new(pos.x, pos.y, pos.z) end

---@param pos PositionRecord
--- @return tes3vector3
local function radvec(pos)
    return
        tes3vector3.new(math.rad(pos.x), math.rad(pos.y), math.rad(pos.z))
end

local function cancel_timer()
    if myTimer ~= nil then myTimer:cancel() end
end

local function cleanup()
    log:debug("cleanup")

    -- reset global vars
    is_on_boat = false
    current_speed = 0

    last_position = nil
    last_forwardDirection = nil
    last_facing = nil
    currentSpline = nil
    last_sway = 0
    if myTimer ~= nil then myTimer:cancel() end

    if mountData then
        tes3.removeSound({ sound = mountData.sound, reference = mount })

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
        mountData = nil
    end

    -- delete the mount
    if mount then
        mount:delete()
        mount = nil
    end

    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    ---@diagnostic disable-next-line: param-type-mismatch
    vfxRoot:detachChild(travelMarker)
    vfxRoot:detachChild(mountMarker)

    cancel_timer()
end

---@param data MountData
---@param handle mwseSafeObjectHandle|nil
---@param i integer
local function registerStatic(data, handle, i)
    data.clutter[i].handle = handle

    if handle and handle:valid() then
        log:debug("registered " .. handle:getObject().id .. " in static slot " .. tostring(i))
    end
end

---@param slot Slot
---@return integer
local function get_random_anim_group(slot)
    local group = tes3.animationGroup.idle5
    if slot.animationGroup then
        -- choose a random animation
        if #slot.animationGroup > 0 then
            local randomIndex = math.random(1, #slot.animationGroup)
            local animkey = slot.animationGroup[randomIndex]
            group = tes3.animationGroup[animkey]
        else
            -- if len is 0 then we pick one of the idles
            local index = { "idle2", "idle3", "idle4", "idle5", "idle6", "idle7", "idle8" }
            local randomIndex = math.random(1, #index)
            local randomkey = index[randomIndex]
            group = tes3.animationGroup[randomkey]
        end
    end

    if group == nil then
        group = tes3.animationGroup.idle5
    end

    return group
end

---@param data MountData
---@param handle mwseSafeObjectHandle|nil
---@param idx integer
local function registerInSlot(data, handle, idx)
    data.slots[idx].handle = handle

    -- play animation
    if handle and handle:valid() then
        local slot = data.slots[idx]
        local reference = handle:getObject()
        reference.mobile.movementCollision = false;
        if reference ~= tes3.player then
            reference.data.rfuzzo_invincible = true;
        end

        local group = get_random_anim_group(slot)
        tes3.loadAnimation({ reference = reference })
        if slot.animationFile then
            tes3.loadAnimation({ reference = reference, file = slot.animationFile })
        end
        tes3.playAnimation({ reference = reference, group = group })

        log:debug("registered " .. reference.id .. " in slot " .. tostring(idx) .. " with animgroup " .. tostring(group))
    end
end

---@param data MountData
---@return integer|nil index
local function getRandomFreeSlotIdx(data)
    local nilIndices = {}

    -- Collect indices of nil entries
    for index, value in ipairs(data.slots) do
        if value.handle == nil then
            table.insert(nilIndices, index)
        end
    end

    -- Check if there are nil entries
    if #nilIndices > 0 then
        local randomIndex = math.random(1, #nilIndices)
        return nilIndices[randomIndex]
    else
        return nil -- No nil entries found
    end
end

---@param data MountData
---@param handle mwseSafeObjectHandle|nil
---@return boolean
local function registerRefInRandomSlot(data, handle)
    if handle and handle:valid() then
        local i = getRandomFreeSlotIdx(data)
        if not i then
            log:debug("Could not register " .. handle:getObject().id .. " in normal slot")
            return false
        end

        registerInSlot(data, handle, i)
        return true
    end

    return false
end

--- This function returns `true` if a given mobile has
--- follow ai package with player as its target
---@param mobile tes3mobileNPC|tes3mobileCreature
---@return boolean isFollower
local function isFollower(mobile)
    local planner = mobile.aiPlanner
    if not planner then return false end

    local package = planner:getActivePackage()
    if not package then return false end
    if package.type == tes3.aiPackage.follow then
        local target = package.targetActor

        if target.objectType == tes3.objectType.mobilePlayer then
            return true
        end
    end
    return false
end

local function destinationReached()
    if not mountData then
        return
    end

    log:debug("destinationReached")

    -- reset player
    tes3.mobilePlayer.movementCollision = true;
    tes3.loadAnimation({ reference = tes3.player })
    tes3.playAnimation({ reference = tes3.player, group = 0 })

    -- teleport followers
    for index, slot in ipairs(mountData.slots) do
        if slot.handle and slot.handle:valid() then
            local ref = slot.handle:getObject()
            if ref ~= tes3.player and ref.mobile and isFollower(ref.mobile) then
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

-- methods

local function onTimerTick()
    -- checks
    if mount == nil then
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
    if mount.sceneNode == nil then
        cleanup()
        return
    end


    -- skip
    if current_speed < 0.1 then
        return
    end




    local mountOffset = tes3vector3.new(0, 0, mountData.offset)
    local nextPos = currentSpline
    local currentPos = last_position - mountOffset

    -- calculate diffs
    local forwardDirection = last_forwardDirection
    forwardDirection:normalize()
    local d = (nextPos - currentPos):normalized()
    local lerp = forwardDirection:lerp(d, mountData.turnspeed / 10):normalized()

    -- calculate position
    local forward = tes3vector3.new(mount.forwardDirection.x,
        mount.forwardDirection.y, lerp.z):normalized()
    local delta = forward * current_speed

    local playerShipLocal = mount.sceneNode.worldTransform:invert() * tes3.player.position

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
    if swayTime > (2000 * sway_frequency) then
        swayTime = timertick
    end

    local sway = amplitude * math.sin(2 * math.pi * sway_frequency * swayTime)
    -- offset roll during turns
    if turn > 0 then
        local max = (sway_max_amplitude * amplitude)
        sway = math.clamp(last_sway - sway_change, -max, max) --+ sway
    elseif turn < 0 then
        local max = (sway_max_amplitude * amplitude)
        sway = math.clamp(last_sway + sway_change, -max, max) --+ sway
    else
        -- normalize back
        if last_sway < (sway - sway_change) then
            sway = last_sway + sway_change --+ sway
        elseif last_sway > (sway + sway_change) then
            sway = last_sway - sway_change --+ sway
        end
    end
    last_sway = sway
    local newOrientation = common.toWorldOrientation(tes3vector3.new(0.0, sway, 0.0), mount.orientation)
    mount.orientation = newOrientation

    -- passengers
    for index, slot in ipairs(mountData.slots) do
        if slot.handle and slot.handle:valid() then
            local obj = slot.handle:getObject()
            slot.handle:getObject().position = mount.sceneNode.worldTransform * vec(slot.position)
        end
    end

    -- statics
    if mountData.clutter then
        for index, clutter in ipairs(mountData.clutter) do
            if clutter.handle and clutter.handle:valid() then
                clutter.handle:getObject().position = mount.sceneNode.worldTransform * vec(clutter.position)
                if clutter.orientation then
                    clutter.handle:getObject().orientation = common.toWorldOrientation(radvec(clutter.orientation),
                        mount.orientation)
                end
            end
        end
    end
end

--- set up everything
---@param translation tes3vector3
---@param orientation tes3vector3
local function startTravel(translation, orientation)
    if travelMarkerMesh == nil then return end
    if mountData == nil then return end

    currentSpline = translation

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
            local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() *
                256
            child.translation = from
            child.appCulled = false

            ---@diagnostic disable-next-line: param-type-mismatch
            vfxRoot:attachChild(child)
            vfxRoot:update()
            travelMarker = child

            -- calculate positions
            local startPos = currentSpline
            local mountOffset = tes3vector3.new(0, 0, mountData.offset)

            -- create mount
            mount = tes3.createReference {
                object = "a_gondola_01",
                position = startPos + mountOffset,
                orientation = orientation
            }
            mount.facing = tes3.player.facing

            -- register player
            log:debug("> registering player")
            tes3.player.position = startPos + mountOffset
            registerRefInRandomSlot(mountData, tes3.makeSafeObjectHandle(tes3.player))

            -- register statics
            if mountData.clutter then
                log:debug("> registering statics")
                for index, clutter in ipairs(mountData.clutter) do
                    if clutter.id then
                        -- instantiate
                        if clutter.orientation then
                            local inst = tes3.createReference {
                                object = clutter.id,
                                position = startPos + mountOffset,
                                orientation = common.toWorldOrientation(radvec(clutter.orientation), mount.orientation)
                            }
                            registerStatic(mountData, tes3.makeSafeObjectHandle(inst), index)
                        else
                            local inst = tes3.createReference {
                                object = clutter.id,
                                position = startPos + mountOffset,
                                orientation = mount.orientation
                            }
                            registerStatic(mountData, tes3.makeSafeObjectHandle(inst), index)
                        end
                    end
                end
            end

            -- start timer
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






--- @param e keyDownEventData
local function keyDownCallback(e)
    if not travelMarkerMesh then return nil end
    if not mountMarkerMesh then return nil end

    -- TODO activator
    if e.keyCode == tes3.scanCode["o"] then
        if editmode and mountMarker and not is_on_boat then
            -- currently visualizing the mount and about to start travel
            -- TODO check if in water

            -- start

            editmode = false
            is_on_boat = true
            startTravel(mountMarker.translation, mountMarker.rotation:toEulerXYZ())

            local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
            vfxRoot:detachChild(mountMarker)
            mountMarker = nil
        elseif is_on_boat then
            -- stop
            tes3.fadeOut()
            if myTimer ~= nil then myTimer:cancel() end

            timer.start({
                type = timer.simulate,
                duration = 1,
                callback = (function()
                    tes3.fadeIn()
                    destinationReached()
                    -- TODO spawn persistent ref
                end)
            })
        else
            -- first time

            -- TODO oad mount data
            ---@type ServiceData
            local service = {
                class = "Gondolier",
                mount = "my_gondola",
                ground_offset = 0,
            }
            mountData = common.loadMountData(service.mount)

            -- visualize mount
            local child = mountMarkerMesh:clone()
            local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() *
                256
            child.translation = from
            child.appCulled = false
            local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
            ---@diagnostic disable-next-line: param-type-mismatch
            vfxRoot:attachChild(child)
            vfxRoot:update()
            mountMarker = child

            editmode = true
        end
    end

    if is_on_boat then
        if e.keyCode == tes3.scanCode["w"] then
            -- increment speed
            if current_speed < speed_max then
                current_speed = math.clamp(current_speed + speed_change, 0, speed_max)
                tes3.messageBox("Current Speed: " .. tostring(current_speed))
            end
        end
        if e.keyCode == tes3.scanCode["s"] then
            -- decrement speed
            if current_speed > 0 then
                current_speed = math.clamp(current_speed - speed_change, 0, speed_max)
                tes3.messageBox("Current Speed: " .. tostring(current_speed))
            end
        end
    end
end
event.register(tes3.event.keyDown, keyDownCallback)

--- Cleanup on save load
--- @param e loadEventData
local function editloadCallback(e)
    travelMarkerMesh = tes3.loadMesh(travelMarkerId)
    mountMarkerMesh = tes3.loadMesh(mountMarkerId)
    cleanup()
end
event.register(tes3.event.load, editloadCallback)

--- @param e simulatedEventData
local function simulatedCallback(e)
    if editmode and mountMarker and mountData then
        local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 512
        from.z = mountData.offset

        mountMarker.translation = from
        local m = tes3matrix33.new()
        m:fromEulerXYZ(tes3.player.orientation.x, tes3.player.orientation.y,
            tes3.player.orientation.z)
        mountMarker.rotation = m
        mountMarker:update()
    end

    if is_on_boat and travelMarker then
        -- TODO collision


        -- update next pos
        local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 2048
        from.z = 0

        currentSpline = from
        travelMarker.translation = from
        local m = tes3matrix33.new()
        m:fromEulerXYZ(tes3.player.orientation.x, tes3.player.orientation.y,
            tes3.player.orientation.z)
        travelMarker.rotation = m
        travelMarker:update()
    end
end
event.register(tes3.event.simulated, simulatedCallback)
