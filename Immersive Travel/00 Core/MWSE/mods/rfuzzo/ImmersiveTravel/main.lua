--[[
Immersive Travel Mod
v 1.0
by rfuzzo

mwse real-time travel mod


--]]
--
local common = require("rfuzzo.ImmersiveTravel.common")

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local config = require("rfuzzo.ImmersiveTravel.config")

local sway_max_amplitude = 3       -- how much the ship can sway in a turn
local sway_amplitude_change = 0.01 -- how much the ship can sway in a turn
local sway_frequency = 0.12        -- how fast the mount sways
local sway_amplitude = 0.014       -- how much the mount sways

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
---@field animationGroup string?
---@field animationFile string?
---@field handle mwseSafeObjectHandle?
---@field node niNode?

---@class Clutter
---@field position PositionRecord slot
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
---@field guideSlot Slot
---@field slots Slot[]
---@field clutter Clutter[]?
---@field idList string[]?

---@class ReferenceRecord
---@field cell tes3cell The cell
---@field position tes3vector3 The reference position

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// VARIABLES

local travelMenuId = tes3ui.registerID("it:travel_menu")
local travelMenuCancelId = tes3ui.registerID("it:travel_menu_cancel")
local npcMenu = nil

local timertick = 0.01
local myTimer = nil ---@type mwseTimer | nil

local mount = nil ---@type tes3reference | nil
local isTraveling = false
local splineIndex = 2
local swayTime = 0
local currentSpline = {} ---@type PositionRecord[]|nil
local mountData = nil ---@type MountData|nil

local last_position = nil ---@type tes3vector3|nil
local last_forwardDirection = nil ---@type tes3vector3|nil
local last_facing = nil ---@type number|nil
local last_sway = 0 ---@type number

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// FUNCTIONS

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

---@param pos PositionRecord
--- @return tes3vector3
local function vec(pos) return tes3vector3.new(pos.x, pos.y, pos.z) end

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

--- With the above function we can build a function that
--- creates a table with all of the player's followers
---@return tes3reference[] followerList
local function getFollowers()
    local followers = {}
    local i = 1

    for _, mobile in pairs(tes3.mobilePlayer.friendlyActors) do
        ---@cast mobile tes3mobileNPC|tes3mobileCreature
        if isFollower(mobile) then
            followers[i] = mobile.reference
            i = i + 1
        end
    end

    return followers
end

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
                table.insert(results, { cell = cell, position = r.position })
            end
        end
    end

    local last_distance = 8000
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

local function teleportToClosestMarker()
    local marker = findClosestTravelMarker()
    if marker ~= nil then
        tes3.positionCell({
            reference = tes3.mobilePlayer,
            cell = marker.cell,
            position = marker.position
        })
    end
end

local function cleanup()
    last_position = nil
    last_forwardDirection = nil
    last_facing = nil
    last_sway = 0

    -- cleanup
    if myTimer ~= nil then myTimer:cancel() end
    splineIndex = 2

    if mountData then
        tes3.removeSound({ sound = mountData.sound, reference = mount })

        -- guide
        if mountData.guideSlot.handle and mountData.guideSlot.handle:valid() then
            mountData.guideSlot.handle:getObject():delete()
            mountData.guideSlot.handle = nil
        end

        -- passengers
        for index, slot in ipairs(mountData.slots) do
            if slot.handle and slot.handle:valid() then
                local ref = slot.handle:getObject()
                if ref.mobile then
                    if not isFollower(ref.mobile) and slot.handle:getObject() ~= tes3.player then
                        ref:delete()
                        slot.handle = nil
                    end
                end
            end
        end

        -- statics
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

    isTraveling = false
end

---@param data MountData
---@param handle mwseSafeObjectHandle|nil
local function registerGuide(data, handle)
    if handle and handle:valid() then
        data.guideSlot.handle = handle
        -- tcl
        local reference = handle:getObject()
        reference.mobile.movementCollision = false;

        -- play animation
        local slot = data.guideSlot
        tes3.loadAnimation({ reference = reference })
        if slot.animationFile then
            tes3.loadAnimation({ reference = reference, file = slot.animationFile })
        end
        local group = tes3.animationGroup.idle5
        if slot.animationGroup then
            group = tes3.animationGroup[slot.animationGroup]
        end
        tes3.playAnimation({ reference = reference, group = group })

        log:debug("registered " .. reference.id .. " in guide slot")
    end
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
        tes3.loadAnimation({ reference = reference })
        if slot.animationFile then
            tes3.loadAnimation({
                reference = reference,
                file = slot.animationFile
            })
        end
        local group = tes3.animationGroup.idle5
        if slot.animationGroup then
            group = tes3.animationGroup[slot.animationGroup]
        end
        tes3.playAnimation({ reference = reference, group = group })

        log:debug("registered " .. reference.id .. " in slot " .. tostring(idx))
    end
end

---@param data MountData
---@return integer|nil index
local function getFirstFreeSlot(data)
    for index, value in ipairs(data.slots) do
        if value.handle == nil then return index end
    end
    return nil
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
local function registerRefInRandomSlot(data, handle)
    if handle and handle:valid() then
        local i = getRandomFreeSlotIdx(data)
        if not i then return end

        handle:getObject().mobile.movementCollision = false;
        registerInSlot(data, handle, i)
    end
end

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
        registerInSlot(data, temp_handle, playerIdx)
        registerInSlot(data, tes3.makeSafeObjectHandle(tes3.player), idx)
    end
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

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// TRAVEL

local function destinationReached()
    cleanup()

    -- reset player
    tes3.mobilePlayer.movementCollision = true;
    tes3.loadAnimation({ reference = tes3.player })
    tes3.playAnimation({ reference = tes3.player, group = 0 })

    -- followers
    local followers = getFollowers()
    for index, follower in ipairs(followers) do
        follower.mobile.movementCollision = true;
        tes3.loadAnimation({ reference = follower })
        tes3.playAnimation({ reference = follower, group = 0 })
    end

    teleportToClosestMarker()
end

local function onTimerTick()
    -- checks
    if mount == nil then return end
    if mountData == nil then return end
    if myTimer == nil then return end
    if isTraveling == false then return end
    if currentSpline == nil then return end

    if last_position == nil then return end
    if last_facing == nil then return end
    if last_forwardDirection == nil then return end

    if splineIndex <= #currentSpline then
        local mountOffset = tes3vector3.new(0, 0, mountData.offset)
        local nextPos = vec(currentSpline[splineIndex])
        local currentPos = last_position - mountOffset

        -- calculate diffs
        local forwardDirection = last_forwardDirection
        forwardDirection:normalize()
        local d = (nextPos - currentPos):normalized()
        local lerp = forwardDirection:lerp(d, mountData.turnspeed / 10):normalized()

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
        mount.facing = facing

        -- calculate position
        local forward = tes3vector3.new(mount.forwardDirection.x,
            mount.forwardDirection.y, lerp.z):normalized()
        local delta = forward * mountData.speed
        local mountPosition = currentPos + delta + mountOffset
        mount.position = mountPosition

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
        local worldOrientation = common.toWorldOrientation(
            tes3vector3.new(0.0, sway, 0.0),
            mount.orientation)
        mount.orientation = worldOrientation

        -- guide
        local guidePos = mount.position +
            common.toWorld(vec(mountData.guideSlot.position),
                mount.orientation)
        tes3.positionCell({
            reference = mountData.guideSlot.handle:getObject(),
            position = guidePos
        })
        mountData.guideSlot.handle:getObject().facing = mount.facing

        -- position references in slots
        for index, slot in ipairs(mountData.slots) do
            if slot.handle and slot.handle:valid() then
                local refpos = mount.position +
                    common.toWorld(vec(slot.position),
                        mount.orientation)
                slot.handle:getObject().position = refpos
                if slot.handle:getObject() ~= tes3.player then
                    slot.handle:getObject().facing = mount.facing
                end
            end
        end

        -- statics
        if mountData.clutter then
            for index, slot in ipairs(mountData.clutter) do
                if slot.handle and slot.handle:valid() then
                    local refpos = mount.position +
                        common.toWorld(vec(slot.position),
                            mount.orientation)
                    slot.handle:getObject().position = refpos
                end
            end
        end

        -- move to next marker
        local isBehind = common.isPointBehindObject(nextPos, mount.position, forward)
        if isBehind then splineIndex = splineIndex + 1 end
    else -- if i is at the end of the list
        tes3.fadeOut({ duration = 1 })
        isTraveling = false

        timer.start({
            type = timer.simulate,
            iterations = 1,
            duration = 1,
            callback = (function()
                tes3.fadeIn({ duration = 1 })

                destinationReached()
            end)
        })
    end
end

local function getRandomActorsInCell(N)
    -- get all actors
    local t = {} ---@type string[]
    local cells = tes3.getActiveCells()
    for _index, cell in ipairs(cells) do
        local references = referenceListToTable(cell.actors)
        for _, r in ipairs(references) do
            if r.baseObject.objectType == tes3.objectType.npc then
                if not common.is_in(t, r.baseObject.id) then
                    table.insert(t, r.baseObject.id)
                end
            end
        end
    end

    -- get random pick
    local result = {}
    for i = 1, N do
        local randomIndex = math.random(1, #t)
        table.insert(result, t[randomIndex])
    end

    return result
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
            if common.is_in(o.points, start) and common.is_in(o.points, destination) then
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

            local startPoint = currentSpline[1]
            local startPos = tes3vector3.new(startPoint.x, startPoint.y,
                startPoint.z)

            -- set initial facing of mount
            local next_point = currentSpline[2]
            local next_pos = tes3vector3.new(next_point.x, next_point.y,
                next_point.z)
            local d = next_pos - startPos
            d:normalize()
            local new_facing = math.atan2(d.x, d.y)

            -- create mount
            local mountOffset = tes3vector3.new(0, 0, mountData.offset)
            mount = tes3.createReference {
                object = mountId,
                position = startPos + mountOffset,
                orientation = d
            }
            mount.facing = new_facing

            -- register refs in slots
            tes3.player.position = startPos + mountOffset
            tes3.player.facing = new_facing
            log:debug("register player")
            registerRefInRandomSlot(mountData, tes3.makeSafeObjectHandle(tes3.player))

            -- duplicate guide
            local guide2 = tes3.createReference {
                object = guide.baseObject.id,
                position = startPos + mountOffset,
                orientation = mount.orientation
            }
            guide2.mobile.hello = 0
            log:debug("register guide")
            registerGuide(mountData, tes3.makeSafeObjectHandle(guide2))

            -- followers
            log:debug("register followers")
            local followers = getFollowers()
            for index, follower in ipairs(followers) do
                registerRefInRandomSlot(mountData, tes3.makeSafeObjectHandle(follower))
            end

            -- register a random number of passengers
            local n = math.random(#mountData.slots - 2);
            log:debug("try register " .. n .. " / " .. #mountData.slots .. " passengers")
            local actors = getRandomActorsInCell(n)
            for _i, value in ipairs(actors) do
                local passenger = tes3.createReference {
                    object = value,
                    position = startPos + mountOffset,
                    orientation = mount.orientation
                }
                local refHandle = tes3.makeSafeObjectHandle(passenger)
                registerRefInRandomSlot(mountData, refHandle)
            end


            -- statics
            if mountData.clutter then
                for index, clutter in ipairs(mountData.clutter) do
                    if clutter.id then
                        -- instantiate
                        local inst = tes3.createReference {
                            object = clutter.id,
                            position = startPos + mountOffset,
                            orientation = mount.orientation
                        }
                        -- register
                        registerStatic(mountData, tes3.makeSafeObjectHandle(inst), index)
                    end
                end
            end

            -- start timer
            last_position = mount.position
            last_forwardDirection = mount.forwardDirection
            last_facing = mount.facing
            last_sway = 0
            splineIndex = 2
            isTraveling = true
            tes3.playSound({
                sound = mountData.sound,
                reference = mount,
                loop = true
            })

            myTimer = timer.start({
                duration = timertick,
                type = timer.simulate,
                iterations = -1,
                callback = onTimerTick
            })
        end)
    })
end

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

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

--- Disable combat while in travel
--- @param e combatStartEventData
local function forcedPacifism(e) if (isTraveling == true) then return false end end
event.register(tes3.event.combatStart, forcedPacifism)

--- Disable activate of mount and guide while in travel
--- @param e activateEventData
local function activateCallback(e)
    if (e.activator ~= tes3.player) then return end
    if not isTraveling then return end
    if mount == nil then return; end
    if mountData == nil then return; end
    if myTimer == nil then return; end
    if mountData.guideSlot.handle == nil then return; end
    if not mountData.guideSlot.handle:valid() then return; end

    if e.target.id == mountData.guideSlot.handle:getObject().id then return false end
    if e.target.id == mount.id then return false end
end
event.register(tes3.event.activate, activateCallback)

--- Disable tooltips of mount and guide while in travel
--- @param e uiObjectTooltipEventData
local function uiObjectTooltipCallback(e)
    if not isTraveling then return end
    if mount == nil then return; end
    if myTimer == nil then return; end
    if mountData == nil then return; end
    if mountData.guideSlot.handle == nil then return; end
    if not mountData.guideSlot.handle:valid() then return; end

    if e.object.id == mountData.guideSlot.handle:getObject().id then
        e.tooltip.visible = false
        return false
    end
    if e.object.id == mount.id then
        e.tooltip.visible = false
        return false
    end
end
event.register(tes3.event.uiObjectTooltip, uiObjectTooltipCallback)

--- Cleanup on save load
--- @param e loadEventData
local function loadCallback(e) cleanup() end
event.register(tes3.event.load, loadCallback)

-- upon entering the dialog menu, create the hot tea button
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
    if e.keyCode == tes3.scanCode["w"] then
        if isTraveling and mountData then incrementSlot(mountData) end
    end
end
event.register(tes3.event.keyDown, keyDownCallback)

-- always allow resting on a mount
--- @param e preventRestEventData
local function preventRestCallback(e)
    if isTraveling and currentSpline then
        return false
    end
end
event.register(tes3.event.preventRest, preventRestCallback)

--- @param e uiShowRestMenuEventData
local function uiShowRestMenuCallback(e)
    if isTraveling and currentSpline then
        -- always allow resting on a mount
        e.allowRest = true

        -- custom UI
        local buttons = {
            {
                text = "Rest",
                callback = function()
                    tes3.fadeOut({ duration = 1 })
                    isTraveling = false

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
                            destinationReached()
                        end)
                    })
                end
            }
        }

        tes3ui.showMessageMenu {
            message = "Rest and skip to the end of the journey?",
            buttons = buttons,
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

-- TODO if sitting: fixed facing?
