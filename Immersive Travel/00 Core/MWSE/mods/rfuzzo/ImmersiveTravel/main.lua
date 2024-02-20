--[[
Immersive Travel Mod
v 1.0.2
by rfuzzo

mwse real-time travel mod

--]]
--
local common = require("rfuzzo.ImmersiveTravel.common")

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local config = require("rfuzzo.ImmersiveTravel.config")

local ANIM_CHANGE_FREQ = 10        -- change passenger animations every 10 seconds
local sway_max_amplitude = 3       -- how much the ship can sway in a turn
local sway_amplitude_change = 0.01 -- how much the ship can sway in a turn
local sway_frequency = 0.12        -- how fast the mount sways
local sway_amplitude = 0.014       -- how much the mount sways
local timertick = 0.01

local logger = require("logging.logger")
local log = logger.new {
    name = config.mod,
    logLevel = config.logLevel,
    logToConsole = true,
    includeTimestamp = true
}

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CLASSES

---@class PositionRecord
---@field x number The x position
---@field y number The y position
---@field z number The z position

---@class ServiceData
---@field class string The npc class name
---@field mount string The mount
---@field override_npc string[]? register specific npcs with the service
---@field override_mount table<string,string[]>? register specific mounts with the service
---@field routes table<string, string[]>? routes
---@field ground_offset number DEPRECATED: editor marker offset

---@class Slot
---@field position PositionRecord slot
---@field animationGroup string[]?
---@field animationFile string?
---@field handle mwseSafeObjectHandle?
---@field node niNode?

---@class HiddenSlot
---@field position PositionRecord slot
---@field handles mwseSafeObjectHandle[]?

---@class Clutter
---@field position PositionRecord slot
---@field orientation PositionRecord? slot
---@field id string? reference id
---@field mesh string? reference id
---@field handle mwseSafeObjectHandle?
---@field node niNode?

---@class MountData
---@field sound string The mount sound id
---@field mesh string The mount mesh path
---@field offset number The mount offset to ground
---@field sway number The sway intensity
---@field speed number forward speed
---@field turnspeed number turning speed
---@field hasFreeMovement boolean turning speed
---@field slots Slot[]
---@field guideSlot Slot?
---@field hiddenSlot HiddenSlot?
---@field clutter Clutter[]?
---@field idList string[]?
---@field scale number?
---@field minSpeed number?
---@field maxSpeed number?
---@field changeSpeed number?
---@field freedomtype string? -- flying, boat, ground
---@field accelerateAnimation string? -- flying, boat, ground
---@field forwardAnimation string? -- flying, boat, ground

---@class ReferenceRecord
---@field cell tes3cell The cell
---@field position tes3vector3 The reference position

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// VARIABLES

local travelMenuId = tes3ui.registerID("it:travel_menu")
local travelMenuCancelId = tes3ui.registerID("it:travel_menu_cancel")
local npcMenu = nil

local myTimer = nil ---@type mwseTimer | nil
local currentSpline = nil ---@type PositionRecord[]|nil

local splineIndex = 2
local swayTime = 0
local last_position = nil ---@type tes3vector3|nil
local last_forwardDirection = nil ---@type tes3vector3|nil
local last_facing = nil ---@type number|nil
local last_sway = 0 ---@type number

local mountData = nil ---@type MountData|nil
local mount = nil ---@type tes3reference | nil

local free_movement = false

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// FUNCTIONS

local function vec(pos) return common.vec(pos) end
local function radvec(pos) return common.radvec(pos) end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// TES3

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

-- teleport player to closest travel marker
local function teleportToClosestMarker()
    local marker = common.findClosestTravelMarker()
    if marker ~= nil then
        tes3.positionCell({
            reference = tes3.mobilePlayer,
            position = marker.position,
            suppressFader = true
        })
    end
end

--- get a table of N actors in the current 9 cells
--- @param N integer
---@return string[]
local function getRandomActorsInCell(N)
    -- get all actors
    local t = {} ---@type string[]
    local cells = tes3.getActiveCells()
    for _index, cell in ipairs(cells) do
        local references = common.referenceListToTable(cell.actors)
        for _, r in ipairs(references) do
            if r.baseObject.objectType == tes3.objectType.npc then
                if not common.is_in(t, r.baseObject.id) then
                    table.insert(t, r.baseObject.id)
                end
            end
        end
    end

    -- get random pick
    local result = {} ---@type string[]
    for i = 1, math.min(N, #t) do
        local randomIndex = math.random(1, #t)
        table.insert(result, t[randomIndex])
    end

    return result
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// MOD

-- player is within the surface of the mount
---@return boolean
local function isOnMount()
    if not mount then return false end

    if not mountData then return false end

    local inside = true

    local volumeHeight = 200

    local bbox = mount.object.boundingBox

    local pos = tes3.player.position
    local surfaceOffset = mountData.slots[1].position.z
    local mountSurface = mount.position + tes3vector3.new(0, 0, surfaceOffset)

    if pos.z < (mountSurface.z - volumeHeight) then inside = false end
    if pos.z > (mountSurface.z + volumeHeight) then inside = false end

    local max_xy_d = tes3vector3.new(bbox.max.x, bbox.max.y, 0):length()
    local min_xy_d = tes3vector3.new(bbox.min.x, bbox.min.y, 0):length()
    local dist = mountSurface:distance(pos)
    local r = math.max(min_xy_d, max_xy_d) + 50
    if dist > r then inside = false end

    return inside
end

-- convenience method to check if player is currently travelling
local function isTraveling()
    if not currentSpline then return false end

    if not isOnMount() then return false end

    return true
end

local function safeCancelTimer() if myTimer ~= nil then myTimer:cancel() end end

-- cleanup all variables
local function cleanup()
    log:debug("cleanup")

    -- reset global vars
    safeCancelTimer()
    currentSpline = nil

    splineIndex = 2
    swayTime = 0
    last_position = nil
    last_forwardDirection = nil
    last_facing = nil
    last_sway = 0

    if mountData then
        tes3.removeSound({ sound = mountData.sound, reference = mount })

        -- delete guide
        if mountData.guideSlot.handle and mountData.guideSlot.handle:valid() then
            mountData.guideSlot.handle:getObject():delete()
            mountData.guideSlot.handle = nil
        end

        -- delete passengers
        for index, slot in ipairs(mountData.slots) do
            if slot.handle and slot.handle:valid() then
                local ref = slot.handle:getObject()
                if ref ~= tes3.player and ref.mobile and
                    not common.isFollower(ref.mobile) then
                    ref:delete()
                    slot.handle = nil
                end
            end
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

    -- delete the mount
    if mount then mount:delete() end
    mount = nil
end

-- register a ref in the dedicated guide slot
---@param data MountData
---@param handle mwseSafeObjectHandle|nil
local function registerGuide(data, handle)
    if data.guideSlot and handle and handle:valid() then
        data.guideSlot.handle = handle
        -- tcl
        local reference = handle:getObject()
        reference.mobile.movementCollision = false;
        reference.data.rfuzzo_invincible = true;

        -- play animation
        local group = common.getRandomAnimGroup(data.guideSlot)
        tes3.loadAnimation({ reference = reference })
        if data.guideSlot.animationFile then
            tes3.loadAnimation({
                reference = reference,
                file = data.guideSlot.animationFile
            })
        end
        tes3.playAnimation({ reference = reference, group = group })

        log:debug("registered " .. reference.id ..
            " in guide slot with animgroup " .. tostring(group))
    end
end

-- register a ref in the hidden slot container
---@param data MountData
---@param handle mwseSafeObjectHandle|nil
local function registerRefInHiddenSlot(data, handle)
    if data.hiddenSlot.handles == nil then data.hiddenSlot.handles = {} end

    if handle and handle:valid() then
        local idx = #data.hiddenSlot.handles + 1
        data.hiddenSlot.handles[idx] = handle
        -- tcl
        local reference = handle:getObject()
        reference.mobile.movementCollision = false;
        reference.data.rfuzzo_invincible = true;

        log:debug("registered " .. reference.id .. " in hidden slot #" .. idx)
    end
end

-- move player to next slot and rotate registered refs in slots
---@param data MountData
local function incrementSlot(data)
    local playerIdx = nil
    local idx = nil

    -- find index of next slot
    for index, slot in ipairs(data.slots) do
        if slot.handle and slot.handle:getObject() == tes3.player then
            idx = index + 1
            if idx > #data.slots then idx = 1 end
            playerIdx = index
            break
        end
    end

    -- register anew for anims
    if playerIdx and idx then
        local temp_handle = data.slots[idx].handle
        common.registerInSlot(data, temp_handle, playerIdx)
        common.registerInSlot(data, tes3.makeSafeObjectHandle(tes3.player), idx)
    end
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// TRAVEL

-- what happens when we reach the destination
---@param force boolean
local function destinationReached(force)
    if not mountData then return end

    log:debug("destinationReached")

    -- reset player
    tes3.mobilePlayer.movementCollision = true;
    tes3.loadAnimation({ reference = tes3.player })
    tes3.playAnimation({ reference = tes3.player, group = 0 })

    if force then
        teleportToClosestMarker()
    else
        if isTraveling() then teleportToClosestMarker() end
    end

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

    if mountData.hiddenSlot.handles then
        for index, handle in ipairs(mountData.hiddenSlot.handles) do
            if handle and handle:valid() then
                local ref = handle:getObject()
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
                end
            end
        end
        mountData.hiddenSlot.handles = nil
    end

    cleanup()
end

-- main loop
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

    if splineIndex <= #currentSpline then
        local mountOffset = tes3vector3.new(0, 0, mountData.offset)
        local nextPos = vec(currentSpline[splineIndex])
        local currentPos = last_position - mountOffset

        -- calculate diffs
        local forwardDirection = last_forwardDirection
        forwardDirection:normalize()
        local d = (nextPos - currentPos):normalized()
        local lerp = forwardDirection:lerp(d, mountData.turnspeed / 10)
            :normalized()

        -- calculate position
        local forward = tes3vector3.new(mount.forwardDirection.x,
            mount.forwardDirection.y, lerp.z):normalized()
        local delta = forward * mountData.speed

        local playerShipLocal = mount.sceneNode.worldTransform:invert() *
            tes3.player.position

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
        local changeAnims = false
        swayTime = swayTime + timertick
        if swayTime > (2000 * sway_frequency) then swayTime = timertick end

        -- periodically change anims
        local i, f = math.modf(swayTime)
        if i > 0 and f < timertick and math.fmod(i, ANIM_CHANGE_FREQ) == 0 then
            changeAnims = true
        end

        local sway = amplitude *
            math.sin(2 * math.pi * sway_frequency * swayTime)
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

        -- player
        if free_movement == true and isOnMount() then
            -- this is needed to enable collisions :todd:
            tes3.dataHandler:updateCollisionGroupsForActiveCells {}
            mount.sceneNode:update() -- TODO needed?
            tes3.player.position = mount.sceneNode.worldTransform *
                playerShipLocal
        end

        -- hidden slot
        if mountData.hiddenSlot.handles then
            for index, handle in ipairs(mountData.hiddenSlot.handles) do
                if handle and handle:valid() then
                    tes3.positionCell({
                        reference = handle:getObject(),
                        position = mount.sceneNode.worldTransform *
                            vec(mountData.hiddenSlot.position)
                    })
                end
            end
        end

        -- guide
        local guide = mountData.guideSlot.handle:getObject()
        tes3.positionCell({
            reference = guide,
            position = mount.sceneNode.worldTransform *
                vec(mountData.guideSlot.position)
        })
        guide.facing = mount.facing
        -- only change anims if behind player
        if changeAnims and
            common.isPointBehindObject(guide.position, tes3.player.position,
                tes3.player.forwardDirection) then
            local group = common.getRandomAnimGroup(mountData.guideSlot)
            local animController = guide.mobile.animationController
            if animController then
                local currentAnimationGroup =
                    animController.animationData.currentAnimGroups[tes3.animationBodySection
                    .upper]
                log:debug(guide.id .. " switching to animgroup " ..
                    tostring(group))
                if group ~= currentAnimationGroup then
                    tes3.loadAnimation({ reference = guide })
                    if mountData.guideSlot.animationFile then
                        tes3.loadAnimation({
                            reference = guide,
                            file = mountData.guideSlot.animationFile
                        })
                    end
                    tes3.playAnimation({ reference = guide, group = group })
                end
            end
        end

        -- passengers
        for index, slot in ipairs(mountData.slots) do
            if slot.handle and slot.handle:valid() then
                local obj = slot.handle:getObject()
                slot.handle:getObject().position = mount.sceneNode
                    .worldTransform *
                    vec(slot.position)
                if obj ~= tes3.player then
                    --- obj.facing = mount.facing
                    -- only change anims if behind player
                    if changeAnims and
                        common.isPointBehindObject(obj.position,
                            tes3.player.position,
                            tes3.player.forwardDirection) then
                        local group = common.getRandomAnimGroup(slot)
                        log:debug(obj.id .. " switching to animgroup " ..
                            tostring(group))
                        local animController = obj.mobile.animationController
                        if animController then
                            local currentAnimationGroup =
                                animController.animationData.currentAnimGroups[tes3.animationBodySection
                                .upper]

                            if group ~= currentAnimationGroup then
                                tes3.loadAnimation({ reference = obj })
                                if slot.animationFile then
                                    tes3.loadAnimation({
                                        reference = obj,
                                        file = slot.animationFile
                                    })
                                end
                                tes3.playAnimation({
                                    reference = obj,
                                    group = group
                                })
                            end
                        end
                    end
                end
            end
        end

        -- statics
        if mountData.clutter then
            for index, clutter in ipairs(mountData.clutter) do
                if clutter.handle and clutter.handle:valid() then
                    clutter.handle:getObject().position = mount.sceneNode
                        .worldTransform *
                        vec(
                            clutter.position)
                    if clutter.orientation then
                        clutter.handle:getObject().orientation =
                            common.toWorldOrientation(radvec(clutter.orientation),
                                mount.orientation)
                    end
                end
            end
        end

        -- move to next marker
        local isBehind = common.isPointBehindObject(nextPos, mount.position,
            forward)
        if isBehind then splineIndex = splineIndex + 1 end
    else -- if i is at the end of the list
        tes3.fadeOut()
        if myTimer ~= nil then myTimer:cancel() end

        timer.start({
            type = timer.simulate,
            duration = 1,
            callback = (function()
                tes3.fadeIn()
                destinationReached(false)
            end)
        })
    end
end

--- set up everything
---@param start string
---@param destination string
---@param service ServiceData
---@param guide tes3reference
local function startTravel(start, destination, service, guide)
    -- if guide == nil then return end

    local m = tes3ui.findMenu(travelMenuId)
    if not m then return end

    -- leave dialogue
    tes3ui.leaveMenuMode()
    m:destroy()

    if npcMenu then
        local menu = tes3ui.findMenu(npcMenu)
        if menu then
            npcMenu = nil
            menu:destroy()
        end
    end

    currentSpline = common.loadSpline(start, destination, service)
    if currentSpline == nil then return end

    local mountId = service.mount
    -- override mounts
    if service.override_mount then
        for _, o in ipairs(service.override_mount) do
            if common.is_in(o.points, start) and
                common.is_in(o.points, destination) then
                mountId = o.id
                break
            end
        end
    end

    -- load mount data
    mountData = common.loadMountData(mountId)
    if mountData == nil then return end
    log:debug("loaded mount: " .. mountId)

    -- fade out
    tes3.fadeOut({ duration = 1 })

    -- fade back in
    timer.start({
        type = timer.simulate,
        iterations = 1,
        duration = 1,
        callback = (function()
            tes3.fadeIn({ duration = 1 })

            -- calculate positions
            local startPoint = currentSpline[1]
            local startPos = tes3vector3.new(startPoint.x, startPoint.y,
                startPoint.z)
            local next_point = currentSpline[2]
            local next_pos = tes3vector3.new(next_point.x, next_point.y,
                next_point.z)
            local d = next_pos - startPos
            d:normalize()
            local new_facing = math.atan2(d.x, d.y)
            local mountOffset = tes3vector3.new(0, 0, mountData.offset)

            -- create mount
            mount = tes3.createReference {
                object = mountId,
                position = startPos + mountOffset,
                orientation = d
            }
            mount.facing = new_facing

            -- always start slotted
            free_movement = false

            -- register guide
            local guide2 = tes3.createReference {
                object = guide.baseObject.id,
                position = startPos + mountOffset,
                orientation = mount.orientation
            }
            guide2.mobile.hello = 0
            log:debug("> registering guide")
            registerGuide(mountData, tes3.makeSafeObjectHandle(guide2))

            -- register player
            log:debug("> registering player")
            tes3.player.position = startPos + mountOffset
            common.registerRefInRandomSlot(mountData, tes3.makeSafeObjectHandle(
                tes3.player))
            tes3.player.facing = new_facing

            -- register followers
            local followers = common.getFollowers()
            log:debug("> registering " .. #followers .. " followers")
            for index, follower in ipairs(followers) do
                local handle = tes3.makeSafeObjectHandle(follower)
                local result = common.registerRefInRandomSlot(mountData, handle)
                if not result then
                    registerRefInHiddenSlot(mountData, handle)
                end
            end

            -- register passengers
            local maxPassengers = math.max(0, #mountData.slots - 2)
            if maxPassengers > 0 then
                local n = math.random(maxPassengers);
                log:debug("> registering " .. n .. " / " .. maxPassengers ..
                    " passengers")
                local actors = getRandomActorsInCell(n)
                for _i, value in ipairs(actors) do
                    local passenger = tes3.createReference {
                        object = value,
                        position = startPos + mountOffset,
                        orientation = mount.orientation
                    }
                    local refHandle = tes3.makeSafeObjectHandle(passenger)
                    common.registerRefInRandomSlot(mountData, refHandle)
                end
            end

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
                                    orientation = common.toWorldOrientation(
                                        radvec(clutter.orientation),
                                        mount.orientation)
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
            last_position = mount.position
            last_forwardDirection = mount.forwardDirection
            last_facing = mount.facing
            last_sway = 0
            splineIndex = 2
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

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// UI

--- Start Travel window
-- Create window and layout. Called by onCommand.
---@param service ServiceData
---@param guide tes3reference
local function createTravelWindow(service, guide)
    -- Return if window is already open
    if (tes3ui.findMenu(travelMenuId) ~= nil) then return end
    -- Return if no destinations
    local destinations = service.routes[guide.cell.id]
    if destinations == nil then return end
    if #destinations == 0 then return end

    -- Create window and frame
    local menu = tes3ui.createMenu {
        id = travelMenuId,
        fixedFrame = false,
        dragFrame = true
    }
    menu.alpha = 1.0
    menu.text = tes3.player.cell.id
    menu.width = 350
    menu.height = 350

    -- Create layout
    local label = menu:createLabel { text = "Destinations" }
    label.borderBottom = 5

    local pane = menu:createVerticalScrollPane { id = "sortedPane" }
    for _key, name in ipairs(destinations) do
        local button = pane:createButton {
            id = "button_spline_" .. name,
            text = name
        }

        button:register(tes3.uiEvent.mouseClick, function()
            startTravel(tes3.player.cell.id, name, service, guide)
        end)
    end
    pane:getContentElement():sortChildren(function(a, b)
        return a.text < b.text
    end)
    pane.height = 400

    local button_block = menu:createBlock {}
    button_block.widthProportional = 1.0 -- width is 100% parent width
    button_block.autoHeight = true
    button_block.childAlignX = 1.0       -- right content alignment

    local button_cancel = button_block:createButton {
        id = travelMenuCancelId,
        text = "Cancel"
    }

    -- Events
    button_cancel:register(tes3.uiEvent.mouseClick, function()
        local m = tes3ui.findMenu(travelMenuId)
        if (m) then
            mount = nil
            tes3ui.leaveMenuMode()
            m:destroy()
        end
    end)

    -- Final setup
    menu:updateLayout()
    tes3ui.enterMenuMode(travelMenuId)
end

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
---@param guide tes3reference
---@param service ServiceData
local function createTravelButton(menu, guide, service)
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
        npcMenu = menu.id
        createTravelWindow(service, guide)
    end)
    menu:registerAfter("update", function() updateServiceButton(menu) end)
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

-- Disable damage on select characters in travel, thanks Null
--- @param e damageEventData
local function damageInvincibilityGate(e)
    if (e.reference.data and e.reference.data.rfuzzo_invincible) then
        return false
    end
end
event.register(tes3.event.damage, damageInvincibilityGate)

--- Disable combat while in travel
--- @param e combatStartEventData
local function forcedPacifism(e) if (isTraveling()) then return false end end
event.register(tes3.event.combatStart, forcedPacifism)

--- Disable all activate while in travel
--- @param e activateEventData
local function activateCallback(e)
    if (e.activator ~= tes3.player) then return end
    if not isTraveling() then return end
    if mount == nil then return; end
    if mountData == nil then return; end
    if myTimer == nil then return; end
    if mountData.guideSlot.handle == nil then return; end
    if not mountData.guideSlot.handle:valid() then return; end

    if e.target.id == mountData.guideSlot.handle:getObject().id and
        free_movement then
        -- register player in slot
        tes3ui.showMessageMenu {
            message = "Do you want to sit down?",
            buttons = {
                {
                    text = "Yes",
                    callback = function()
                        free_movement = false
                        log:debug("register player")
                        tes3.player.facing = mount.facing
                        common.registerRefInRandomSlot(mountData,
                            tes3.makeSafeObjectHandle(
                                tes3.player))
                    end
                }
            },
            cancels = true
        }

        return false
    end

    return false
end
event.register(tes3.event.activate, activateCallback)

--- Disable tooltips while in travel
--- @param e uiObjectTooltipEventData
local function uiObjectTooltipCallback(e)
    if not isTraveling() then return end
    if mount == nil then return; end
    if myTimer == nil then return; end
    if mountData == nil then return; end
    if mountData.guideSlot.handle == nil then return; end
    if not mountData.guideSlot.handle:valid() then return; end

    e.tooltip.visible = false
    return false
end
event.register(tes3.event.uiObjectTooltip, uiObjectTooltipCallback)

--- Cleanup on save load
--- @param e loadEventData
local function loadCallback(e) cleanup() end
event.register(tes3.event.load, loadCallback)

-- upon entering the dialog menu, create the travel menu
---@param e uiActivatedEventData
local function onMenuDialog(e)
    local menuDialog = e.element
    local mobileActor = menuDialog:getPropertyObject("PartHyperText_actor") ---@cast mobileActor tes3mobileActor
    if mobileActor.actorType == tes3.actorType.npc then
        local ref = mobileActor.reference
        local obj = ref.baseObject
        local npc = obj ---@cast obj tes3npc

        if not offersTraveling(npc) then return end

        local services = common.loadServices()
        if not services then return end

        -- get npc class
        local class = npc.class.id
        local service = table.get(services, class)
        for key, value in pairs(services) do
            if value.override_npc ~= nil then
                if common.is_in(value.override_npc, npc.id) then
                    service = value
                    break
                end
            end
        end

        if service == nil then
            log:debug("no service found for " .. npc.id)
            return
        end

        -- Return if no destinations
        common.loadRoutes(service)
        local destinations = service.routes[ref.cell.id]
        if destinations == nil then return end
        if #destinations == 0 then return end

        log:debug("createTravelButton for " .. npc.id)
        createTravelButton(menuDialog, ref, service)
        menuDialog:updateLayout()
    end
end
event.register("uiActivated", onMenuDialog, { filter = "MenuDialog" })

-- key down callbacks while in travel
--- @param e keyDownEventData
local function keyDownCallback(e)
    -- move
    if not free_movement and isTraveling() then
        if e.keyCode == tes3.scanCode["w"] or e.keyCode == tes3.scanCode["a"] or
            e.keyCode == tes3.scanCode["d"] then
            incrementSlot(mountData)
        end

        if e.keyCode == tes3.scanCode["s"] then
            if mountData == nil then return; end
            if mountData.hasFreeMovement then
                -- remove from slot
                for index, slot in ipairs(mountData.slots) do
                    if slot.handle and slot.handle:valid() and
                        slot.handle:getObject() == tes3.player then
                        slot.handle = nil
                        free_movement = true
                        -- free animations
                        tes3.mobilePlayer.movementCollision = true;
                        tes3.loadAnimation({ reference = tes3.player })
                        tes3.playAnimation({ reference = tes3.player, group = 0 })
                    end
                end
            end
        end
    end
end
event.register(tes3.event.keyDown, keyDownCallback)

-- prevent saving while travelling
--- @param e saveEventData
local function saveCallback(e)
    if isTraveling() then
        tes3.messageBox("You cannot save the game while travelling")
        return false
    end
end
event.register(tes3.event.save, saveCallback)

-- always allow resting on a mount even with enemies near
--- @param e preventRestEventData
local function preventRestCallback(e) if isTraveling() then return false end end
event.register(tes3.event.preventRest, preventRestCallback)

-- resting while travelling skips to end
--- @param e uiShowRestMenuEventData
local function uiShowRestMenuCallback(e)
    if isTraveling() and currentSpline then
        -- always allow resting on a mount
        e.allowRest = true

        -- custom UI
        tes3ui.showMessageMenu {
            message = "Rest and skip to the end of the journey?",
            buttons = {
                {
                    text = "Rest",
                    callback = function()
                        tes3.fadeOut({ duration = 1 })

                        timer.start({
                            type = timer.simulate,
                            iterations = 1,
                            duration = 1,
                            callback = (function()
                                tes3.fadeIn({ duration = 1 })

                                -- teleport to last marker
                                tes3.positionCell({
                                    reference = tes3.mobilePlayer,
                                    position = vec(currentSpline[#currentSpline])
                                })
                                -- then to destination
                                destinationReached(true)
                            end)
                        })
                    end
                }
            },
            cancels = true
        }

        return false
    end
end
event.register(tes3.event.uiShowRestMenu, uiShowRestMenuCallback)

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("rfuzzo.ImmersiveTravel.mcm")

--[[
"animationGroup": "walkForward",
      "animationFile": "ds22\\anim\\gondola.nif",
      "position": {
        "x": 0,
        "y": 0,
        "z": -46
      }
--]]

-- sitting mod
-- idle2 ... praying
-- idle3 ... crossed legs
-- idle4 ... crossed legs
-- idle5 ... hugging legs
-- idle6 ... sitting
