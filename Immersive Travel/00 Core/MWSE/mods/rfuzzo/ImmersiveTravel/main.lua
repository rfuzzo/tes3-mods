--[[
Immersive Travel Mod
v 1.0
by rfuzzo

mwse real-time travel mod


--]] -- 
-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local config = require("rfuzzo.ImmersiveTravel.config")

local sway_frequency = 0.12 -- how fast the mount sways
local sway_amplitude = 0.014 -- how much the mount sways

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
---@field routes table<string, table>? routes
---@field ground_offset number DEPRECATED: editor marker offset

---@class Slot
---@field position PositionRecord slot
---@field animationGroup string?
---@field animationFile string?
---@field reference tes3reference?

---@class Clutter
---@field position PositionRecord slot
---@field id string reference id
---@field reference tes3reference?

---@class MountData
---@field sound string The mount sound id
---@field offset number The mount offset to ground
---@field sway number The sway intensity
---@field speed number forward speed
---@field turnspeed number turning speed
---@field guideSlot Slot
---@field slots Slot[]
---@field clutter Clutter[]?

---@class ReferenceRecord
---@field cell tes3cell The cell
---@field position tes3vector3 The reference position

---@param pos PositionRecord
--- @return tes3vector3
local function vec(pos) return tes3vector3.new(pos.x, pos.y, pos.z) end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// VARIABLES

local travelMenuId = tes3ui.registerID("it:travel_menu")
local travelMenuCancelId = tes3ui.registerID("it:travel_menu_cancel")

local npcMenu = nil

local services = {} ---@type table<string, ServiceData>|nil

local timertick = 0.01
---@type mwseTimer | nil
local myTimer = nil

---@type tes3reference | nil
local mount = nil
local isTraveling = false
local splineIndex = 1
local swayTime = 0
local currentSpline = {} ---@type PositionRecord[]
local mountData = nil ---@type MountData|nil

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// COMMON

---comment
---@param point tes3vector3
---@param objectPosition tes3vector3
---@param objectForwardVector tes3vector3
---@return boolean
local function isPointBehindObject(point, objectPosition, objectForwardVector)
    local vectorToPoint = point - objectPosition
    local dotProduct = vectorToPoint:dot(objectForwardVector)
    return dotProduct < 0
end

--- list contains
---@param table string[]
---@param str string
local function is_in(table, str)
    for index, value in ipairs(table) do if value == str then return true end end
    return false
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

-- Translate local orientation around a base-centered coordinate system to world orientation
---@param localOrientation tes3vector3
---@param baseOrientation tes3vector3
--- @return tes3vector3
local function toWorldOrientation(localOrientation, baseOrientation)
    -- Convert the local orientation to a rotation matrix
    local baseRotationMatrix = tes3matrix33.new()
    baseRotationMatrix:fromEulerXYZ(baseOrientation.x, baseOrientation.y,
                                    baseOrientation.z)

    local localRotationMatrix = tes3matrix33.new()
    localRotationMatrix:fromEulerXYZ(localOrientation.x, localOrientation.y,
                                     localOrientation.z)

    -- Combine the rotation matrices to get the world rotation matrix
    local worldRotationMatrix = baseRotationMatrix * localRotationMatrix
    local worldOrientation, _isUnique = worldRotationMatrix:toEulerXYZ()
    return worldOrientation
end

-- Transform a local offset to world coordinates given a fixed orientation
---@param localVector tes3vector3
---@param worldOrientation tes3vector3
--- @return tes3vector3
local function toWorld(localVector, worldOrientation)
    -- Convert the local orientation to a rotation matrix
    local baseRotationMatrix = tes3matrix33.new()
    baseRotationMatrix:fromEulerXYZ(worldOrientation.x, worldOrientation.y,
                                    worldOrientation.z)

    -- Combine the rotation matrices to get the world rotation matrix
    return baseRotationMatrix * localVector
end

--- @param forward tes3vector3
--- @return tes3matrix33
local function rotationFromDirection(forward)
    forward:normalize()
    local up = tes3vector3.new(0, 0, -1)
    local right = up:cross(forward)
    right:normalize()
    up = right:cross(forward)

    local rotation_matrix = tes3matrix33.new(right.x, forward.x, up.x, right.y,
                                             forward.y, up.y, right.z,
                                             forward.z, up.z)

    return rotation_matrix
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

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// LOGIC

--- load json spline from file
---@param start string
---@param destination string
---@param data ServiceData
local function loadSpline(start, destination, data)
    local fileName = start .. "_" .. destination
    local filePath = "mods\\rfuzzo\\ImmersiveTravel\\" .. data.class .. "\\" ..
                         fileName
    local result = json.loadfile(filePath)
    if result ~= nil then
        log:debug("loaded spline: " .. filePath)
        currentSpline = result
    else
        log:debug("!!! failed to load spline: " .. filePath)
        result = nil
    end
end

--- load json static mount data
---@param id string
local function loadMountData(id)
    local filePath = "mods\\rfuzzo\\ImmersiveTravel\\mounts.json"
    local result = {} ---@type table<string, MountData>
    result = json.loadfile(filePath)

    if result ~= nil then
        mountData = result[id]
    else
        log:debug("!!! failed to load mount: " .. filePath)
        mountData = nil
    end

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
                table.insert(results, {cell = cell, position = r.position})
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
    -- cleanup
    if myTimer ~= nil then myTimer:cancel() end
    splineIndex = 1

    if mountData then
        tes3.removeSound({sound = mountData.sound, reference = mount})

        -- statics
        if mountData.guideSlot.reference then
            mountData.guideSlot.reference:delete()
            mountData.guideSlot.reference = nil
        end

        if mountData.clutter then
            for index, slot in ipairs(mountData.clutter) do
                if slot.reference then
                    slot.reference:delete()
                    slot.reference = nil
                end
            end
        end

    end

    -- delete the mount
    if mount ~= nil then mount:delete() end
    mount = nil

    mountData = nil
    isTraveling = false
end

---@param data MountData
---@return integer|nil index
local function getFirstFreeSlot(data)
    for index, value in ipairs(data.slots) do
        if value.reference == nil then return index end
    end
    return nil
end

-- sitting mod
-- idle2 ... praying
-- idle3 ... crossed legs
-- idle4 ... crossed legs
-- idle5 ... hugging legs
-- idle6 ... sitting

-- TODO if sitting: fixed facing?

---@param data MountData
---@param reference tes3reference|nil
---@param idx integer
local function registerInSlot(data, reference, idx)
    data.slots[idx].reference = reference
    -- play animation
    if reference then
        local slot = data.slots[idx]

        tes3.loadAnimation({reference = reference})
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
        tes3.playAnimation({reference = reference, group = group})

        log:debug("registered " .. reference.id .. " in slot " .. tostring(idx))
    end

end

---@param data MountData
---@param reference tes3reference
local function registerGuide(data, reference)
    data.guideSlot.reference = reference
    -- tcl
    reference.mobile.movementCollision = false;
    -- play animation
    local slot = data.guideSlot
    tes3.loadAnimation({reference = reference})
    if slot.animationFile then
        tes3.loadAnimation({reference = reference, file = slot.animationFile})
    end
    local group = tes3.animationGroup.idle5
    if slot.animationGroup then
        group = tes3.animationGroup[slot.animationGroup]
    end
    tes3.playAnimation({reference = reference, group = group})

    log:debug("registered " .. reference.id .. " in guide slot")
end

---@param data MountData
---@param reference tes3reference
local function registerRef(data, reference)
    -- get first free slot
    local i = getFirstFreeSlot(data)
    if not i then return end

    reference.mobile.movementCollision = false;
    registerInSlot(data, reference, i)
end

---@param data MountData
local function incrementSlot(data)
    local playerIdx = nil
    local idx = nil

    -- find index of next slot
    for index, slot in ipairs(data.slots) do
        if slot.reference == tes3.player then
            idx = index + 1
            if idx > #data.slots then idx = 1 end
            playerIdx = index
            break
        end
    end

    -- register anew for anims
    if playerIdx and idx then
        local tmp = data.slots[idx].reference
        registerInSlot(data, tmp, playerIdx)
        registerInSlot(data, tes3.player, idx)
    end

end

---@param data MountData
---@param reference tes3reference
---@param i integer
local function registerStatic(data, reference, i)
    data.clutter[i].reference = reference

    log:debug("registered " .. reference.id .. " in static slot " .. tostring(i))
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// TRAVEL

local function onTimerTick()
    -- checks
    if mount == nil then return; end
    if mountData == nil then return; end
    if myTimer == nil then return; end
    if isTraveling == false then return end

    if splineIndex <= #currentSpline then

        local next_pos = vec(currentSpline[splineIndex])
        local mount_offset = tes3vector3.new(0, 0, mountData.offset)
        local local_pos = mount.position - mount_offset

        -- calculate heading
        local d = next_pos - local_pos
        d:normalize()
        local current_facing = mount.facing
        local new_facing = math.atan2(d.x, d.y)
        local facing = new_facing
        local diff = new_facing - current_facing
        if diff < -math.pi then diff = diff + 2 * math.pi end
        if diff > math.pi then diff = diff - 2 * math.pi end
        local angle = mountData.turnspeed / 10000
        if diff > 0 and diff > angle then
            facing = current_facing + angle
        elseif diff < 0 and diff < -angle then
            facing = current_facing - angle
        else
            facing = new_facing
        end

        mount.facing = facing
        local f = mount.forwardDirection
        f:normalize()

        local delta = f * mountData.speed
        local mountPosition = local_pos + delta + mount_offset
        tes3.positionCell({reference = mount, position = mountPosition})

        -- set sway
        swayTime = swayTime + timertick
        if swayTime > (2000 * sway_frequency) then swayTime = timertick end
        local sway = (sway_amplitude * mountData.sway) *
                         math.sin(2 * math.pi * sway_frequency * swayTime)
        local worldOrientation = toWorldOrientation(
                                     tes3vector3.new(0.0, sway, 0.0),
                                     mount.orientation)
        mount.orientation = worldOrientation

        -- guide
        local guidePos = mount.position +
                             toWorld(vec(mountData.guideSlot.position),
                                     mount.orientation)
        tes3.positionCell({
            reference = mountData.guideSlot.reference,
            position = guidePos
        })
        mountData.guideSlot.reference.facing = mount.facing

        -- position references in slots
        for index, slot in ipairs(mountData.slots) do
            if slot.reference then
                local refpos = mount.position +
                                   toWorld(vec(slot.position), mount.orientation)
                slot.reference.position = refpos
                if slot.reference ~= tes3.player then
                    slot.reference.facing = mount.facing
                end
            end
        end

        -- statics
        if mountData.clutter then
            for index, slot in ipairs(mountData.clutter) do
                if slot.reference then
                    local refpos = mount.position +
                                       toWorld(vec(slot.position),
                                               mount.orientation)
                    slot.reference.position = refpos
                end
            end
        end

        -- move to next marker
        local isBehind = isPointBehindObject(next_pos, mount.position, f)
        if isBehind then splineIndex = splineIndex + 1 end

    else -- if i is at the end of the list

        tes3.fadeOut({duration = 1})
        isTraveling = false

        timer.start({
            type = timer.simulate,
            iterations = 1,
            duration = 1,
            callback = (function()
                tes3.fadeIn({duration = 1})

                cleanup()

                -- reset player
                tes3.mobilePlayer.movementCollision = true;
                tes3.loadAnimation({reference = tes3.player})
                tes3.playAnimation({reference = tes3.player, group = 0})

                -- followers
                local followers = getFollowers()
                for index, follower in ipairs(followers) do
                    follower.mobile.movementCollision = true;
                    tes3.loadAnimation({reference = follower})
                    tes3.playAnimation({reference = follower, group = 0})
                end

                teleportToClosestMarker();

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

    loadSpline(start, destination, service)
    if currentSpline == nil then return end

    local mountId = service.mount
    -- override mounts 
    if service.override_mount then
        for key, value in pairs(service.override_mount) do
            if is_in(value, start) and is_in(value, destination) then
                mountId = key
                break
            end
        end
    end

    -- load mount data
    loadMountData(mountId)
    if mountData == nil then return end
    log:debug("loaded mount: " .. mountId)

    -- fade out
    tes3.fadeOut({duration = 1})

    -- fade back in
    timer.start({
        type = timer.simulate,
        iterations = 1,
        duration = 1,
        callback = (function()

            tes3.fadeIn({duration = 1})

            local start_point = currentSpline[1]
            local start_pos = tes3vector3.new(start_point.x, start_point.y,
                                              start_point.z)

            -- set initial facing of mount
            local next_point = currentSpline[2]
            local next_pos = tes3vector3.new(next_point.x, next_point.y,
                                             next_point.z)
            local d = next_pos - start_pos
            d:normalize()
            local new_facing = math.atan2(d.x, d.y)

            -- create mount
            mount = tes3.createReference {
                object = mountId,
                position = start_pos + tes3vector3.new(0, 0, mountData.offset),
                orientation = d
            }
            mount.facing = new_facing

            -- register refs in slots
            tes3.player.position = start_pos +
                                       tes3vector3.new(0, 0, mountData.offset)
            tes3.player.facing = new_facing
            registerRef(mountData, tes3.player)

            -- duplicate guide
            local guide2 = tes3.createReference {
                object = guide.baseObject.id,
                position = start_pos + tes3vector3.new(0, 0, mountData.offset),
                orientation = mount.orientation
            }
            registerGuide(mountData, guide2)

            -- followers
            local followers = getFollowers()
            for index, follower in ipairs(followers) do
                registerRef(mountData, follower)
            end

            -- clutter
            if mountData.clutter then
                for index, clutter in ipairs(mountData.clutter) do
                    -- instantiate
                    local inst = tes3.createReference {
                        object = clutter.id,
                        position = start_pos +
                            tes3vector3.new(0, 0, mountData.offset),
                        orientation = mount.orientation
                    }
                    -- register
                    registerStatic(mountData, inst, index)
                end
            end

            -- start timer
            splineIndex = 1
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
    local label = menu:createLabel{text = "Destinations"}
    label.borderBottom = 5

    local pane = menu:createVerticalScrollPane{id = "sortedPane"}
    for _key, name in ipairs(destinations) do
        local button = pane:createButton{
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

    local button_block = menu:createBlock{}
    button_block.widthProportional = 1.0 -- width is 100% parent width
    button_block.autoHeight = true
    button_block.childAlignX = 1.0 -- right content alignment

    local button_cancel = button_block:createButton{
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

    if e.target.id == mountData.guideSlot.reference.id then return false end
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

    if e.object.id == mountData.guideSlot.reference.id then
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

        -- get npc class
        local class = npc.class.id
        local service = table.get(services, class)
        for key, value in pairs(services) do
            if value.override_npc ~= nil then
                if is_in(value.override_npc, npc.id) then
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
        local destinations = service.routes[ref.cell.id]
        if destinations == nil then return end
        if #destinations == 0 then return end

        log:debug("createTravelButton for " .. npc.id)
        createTravelButton(menuDialog, ref, service)
        menuDialog:updateLayout()

    end

end
event.register("uiActivated", onMenuDialog, {filter = "MenuDialog"})

-- key down callbacks while in travel
--- @param e keyDownEventData
local function keyDownCallback(e)
    -- move
    if e.keyCode == tes3.scanCode["w"] then

        if isTraveling and mountData then incrementSlot(mountData) end
    end
end
event.register(tes3.event.keyDown, keyDownCallback)

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EDITOR

--[[
Current Usage (Debug)
- Open route editor 						... R-Ctrl
- move a marker 							... L-Ctrl
- delete a marker 							... Del
- exit edit mode 							... L-Ctrl
- add a marker								... >
- start traveling            		        ... <

--]]
local edit_menu = tes3ui.registerID("it:MenuEdit")
local edit_menu_save = tes3ui.registerID("it:MenuEdit_Display")
local edit_menu_print = tes3ui.registerID("it:MenuEdit_Print")
local edit_menu_mode = tes3ui.registerID("it:MenuEdit_Mode")
local edit_menu_cancel = tes3ui.registerID("it:MenuEdit_Cancel")
local edit_menu_teleport = tes3ui.registerID("it:MenuEdit_Teleport")
-- local edit_menu_trace = tes3ui.registerID("it:MenuEdit_Trace")
-- local edit_menu_traceStop = tes3ui.registerID("it:MenuEdit_TraceStop")

local editmode = false

local editor_marker2 = "marker_divine.nif"
local editor_marker = "marker_arrow.nif"
---@type niNode[]
local editor_markers = {}
local editor_instance = nil
local current_editor_route = ""
local current_editor_start = ""
local current_editor_dest = ""
---@type number | nil
local current_editor_idx = nil
---@type string[]
local editor_services = {}

---@class SPositionRecord
---@field position tes3vector3
---@field forward tes3vector3

---@type mwseTimer | nil
local myEditorTimer = nil
local eN = 5000
local positions = {} ---@type SPositionRecord[]
local arrows = {}
local arrow = nil

event.register("simulate", function(e)
    if editmode == false then return end
    if editor_instance == nil then return end
    if services == nil then return end
    local data = services[editor_services[current_editor_idx]]
    if not data then return end

    local from = tes3.getPlayerEyePosition() + tes3.getPlayerEyeVector() * 256

    if data.ground_offset == 0 then
        from.z = 0
    else
        local groundZ = getGroundZ(from)
        if groundZ == nil then
            from.z = data.ground_offset
        else
            from.z = groundZ + data.ground_offset
        end
    end

    editor_instance.translation = from
    editor_instance:update()
end)

local function updateMarkers()
    -- update rotation
    for index, marker in ipairs(editor_markers) do
        if index < #editor_markers then
            local nextMarker = editor_markers[index + 1]
            local direction = nextMarker.translation - marker.translation
            local rotation_matrix = rotationFromDirection(direction)
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
    editor_markers = {}
    editor_instance = nil
    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    vfxRoot:detachAllChildren()

    -- add markers
    local mesh = tes3.loadMesh(editor_marker)

    for idx, v in ipairs(currentSpline) do

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

---comment
---@param startpos tes3vector3
local function calculatePositions(startpos)
    -- checks
    if mountData == nil then return; end
    if mount == nil then return; end

    positions = {}
    arrows = {}
    table.insert(positions, 1, {position = startpos})

    for idx = 1, eN, 1 do
        if splineIndex <= #editor_markers then
            -- calculate next position
            local point = editor_markers[splineIndex].translation
            local next_pos = tes3vector3.new(point.x, point.y, point.z)
            local mount_offset = tes3vector3.new(0, 0, mountData.offset)
            local local_pos = positions[idx].position - mount_offset

            -- calculate heading
            local d = next_pos - local_pos
            d:normalize()
            local current_facing = mount.facing
            local new_facing = math.atan2(d.x, d.y)
            local facing = new_facing
            local diff = new_facing - current_facing
            if diff < -math.pi then diff = diff + 2 * math.pi end
            if diff > math.pi then diff = diff - 2 * math.pi end
            local angle = mountData.turnspeed / 10000 * config.grain
            if diff > 0 and diff > angle then
                facing = current_facing + angle
            elseif diff < 0 and diff < -angle then
                facing = current_facing - angle
            else
                facing = new_facing
            end

            mount.facing = facing
            local f = mount.forwardDirection
            f:normalize()

            local delta = f * mountData.speed * config.grain
            local mountPosition = local_pos + delta + mount_offset
            table.insert(positions, idx + 1,
                         {position = mountPosition, forward = delta})

            -- draw vfx lines
            if arrow then
                local child = arrow:clone()
                child.translation = mountPosition - mount_offset
                child.appCulled = false
                child.rotation = rotationFromDirection(f)
                table.insert(arrows, child)
            end

            -- move to next marker
            local isBehind = isPointBehindObject(next_pos, mountPosition, f)
            if isBehind then splineIndex = splineIndex + 1 end
        else
            break
        end
    end

end

---comment
---@param data ServiceData
local function traceRoute(data)
    if #editor_markers < 2 then return end

    arrow = tes3.loadMesh("mwse\\arrow.nif"):getObjectByName("unitArrow")
                :clone()
    arrow.scale = 40
    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    for index, value in ipairs(arrows) do vfxRoot:detachChild(value) end

    -- trace the route
    local start_point = editor_markers[1].translation
    local start_pos = tes3vector3.new(start_point.x, start_point.y,
                                      start_point.z)
    local next_point = editor_markers[2].translation
    local next_pos = tes3vector3.new(next_point.x, next_point.y, next_point.z)
    local d = next_pos - start_pos
    d:normalize()

    -- create mount
    local mountId = data.mount
    -- override mounts 
    if data.override_mount then
        for key, value in pairs(data.override_mount) do
            if is_in(value, current_editor_start) and
                is_in(value, current_editor_dest) then
                mountId = key
                break
            end
        end
    end

    loadMountData(mountId)
    if not mountData then return end
    log:debug("loaded mount: " .. mountId)

    local startpos = start_pos + tes3vector3.new(0, 0, mountData.offset)
    local new_facing = math.atan2(d.x, d.y)

    -- create mount
    mount = tes3.createReference {
        object = mountId,
        position = start_pos,
        orientation = d
    }
    mount.facing = new_facing

    splineIndex = 1
    calculatePositions(startpos)

    cleanup()
    -- vfx
    for index, child in ipairs(arrows) do
        ---@diagnostic disable-next-line: param-type-mismatch
        vfxRoot:attachChild(child)
        vfxRoot:update()
    end
end

--- Cleanup on save load
--- @param e loadEventData
local function editloadCallback(e)
    if myEditorTimer ~= nil then myEditorTimer:cancel() end
    splineIndex = 1
    if mount ~= nil then mount:delete() end
    mount = nil
    mountData = nil
end
event.register(tes3.event.load, editloadCallback)

local function createEditWindow()
    -- Return if window is already open
    if (tes3ui.findMenu(edit_menu) ~= nil) then return end
    if services == nil then return end

    -- Create window and frame
    local menu = tes3ui.createMenu {
        id = edit_menu,
        fixedFrame = false,
        dragFrame = true
    }

    -- To avoid low contrast, text input windows should not use menu transparency settings
    menu.alpha = 1.0
    menu.width = 500
    menu.height = 500
    menu.text = "Editor " .. current_editor_route

    -- Create layout
    local label = menu:createLabel{text = "Loaded routes"}
    label.borderBottom = 5

    for key, value in pairs(services) do
        if current_editor_idx == nil then current_editor_idx = 1 end
        table.insert(editor_services, key)
    end
    if current_editor_idx == nil then return end
    local service = services[editor_services[current_editor_idx]]

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
                    current_editor_route = start .. "_" .. destination
                    current_editor_start = start
                    current_editor_dest = destination
                    loadSpline(start, destination, service)
                    renderMarkers()
                    tes3.messageBox("loaded spline: " .. start .. " -> " ..
                                        destination)

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
        id = edit_menu_mode,
        text = editor_services[current_editor_idx]
    }
    local button_teleport = button_block:createButton{
        id = edit_menu_teleport,
        text = "Teleport"
    }
    -- local button_trace = button_block:createButton{
    --     id = edit_menu_trace,
    --     text = "Trace"
    -- }
    -- local button_trace_stop = button_block:createButton{
    --     id = edit_menu_traceStop,
    --     text = "Trace Stop"
    -- }
    local button_save = button_block:createButton{
        id = edit_menu_save,
        text = "Save"
    }
    local button_print = button_block:createButton{
        id = edit_menu_print,
        text = "Print"
    }
    local button_cancel = button_block:createButton{
        id = edit_menu_cancel,
        text = "Exit"
    }
    -- Switch mode
    button_mode:register(tes3.uiEvent.mouseClick, function()
        local m = tes3ui.findMenu(edit_menu)
        if (m) then
            current_editor_idx = current_editor_idx + 1
            if current_editor_idx > #editor_services then
                current_editor_idx = 1
            end

            mount = nil
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
            tes3ui.leaveMenuMode()
            m:destroy()
        end
    end)
    -- Teleport
    button_teleport:register(tes3.uiEvent.mouseClick, function()
        local m = tes3ui.findMenu(edit_menu)
        if (m) then
            if #editor_markers > 1 then
                local position = editor_markers[1].translation
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
        -- print to log
        mwse.log("============================================")
        mwse.log(current_editor_route)
        mwse.log("============================================")
        for i, value in ipairs(editor_markers) do
            local t = value.translation
            mwse.log("{ \"x\": " .. math.round(t.x) .. ", \"y\": " ..
                         math.round(t.y) .. ", \"z\": " .. math.round(t.z) ..
                         " },")
        end
        mwse.log("============================================")
        tes3.messageBox("printed spline: " .. current_editor_route)
    end)
    button_save:register(tes3.uiEvent.mouseClick, function()
        -- print to log
        mwse.log("============================================")
        mwse.log(current_editor_route)
        mwse.log("============================================")
        currentSpline = {}
        for i, value in ipairs(editor_markers) do
            local t = value.translation
            mwse.log("{ \"x\": " .. math.round(t.x) .. ", \"y\": " ..
                         math.round(t.y) .. ", \"z\": " .. math.round(t.z) ..
                         " },")

            -- save currently edited markers back to spline
            table.insert(currentSpline, i, {
                x = math.round(t.x),
                y = math.round(t.y),
                z = math.round(t.z)
            })

        end
        mwse.log("============================================")

        -- save to file
        local filename = "mods\\rfuzzo\\ImmersiveTravel\\" .. service.class ..
                             "\\" .. current_editor_route
        json.savefile(filename, currentSpline)

        tes3.messageBox("saved spline: " .. current_editor_route)

        renderMarkers()
    end)

    -- Final setup
    menu:updateLayout()
    tes3ui.enterMenuMode(edit_menu)
end

--- @param e keyDownEventData
local function editor_keyDownCallback(e)

    if config.enableeditor == false then return end

    -- editor menu
    if e.keyCode == tes3.scanCode["rCtrl"] then createEditWindow() end

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

    -- marker edit mode
    if e.keyCode == tes3.scanCode["lCtrl"] then
        local idx = getClosestMarkerIdx()
        editmode = not editmode
        tes3.messageBox("Marker index: " .. idx)
        if not editmode then
            if services then
                local service = services[editor_services[current_editor_idx]]
                traceRoute(service)
            end
        end
    end

    -- delete
    if e.keyCode == tes3.scanCode["delete"] then
        local idx = getClosestMarkerIdx()

        local instance = editor_markers[idx]
        local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
        vfxRoot:detachChild(instance)

        table.remove(editor_markers, idx)

        if services then
            local service = services[editor_services[current_editor_idx]]
            traceRoute(service)
        end
    end

    -- trace
    if e.keyCode == tes3.scanCode["forwardSlash"] then
        if services then
            local service = services[editor_services[current_editor_idx]]
            traceRoute(service)
        end
    end

end
event.register(tes3.event.keyDown, editor_keyDownCallback)

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("rfuzzo.ImmersiveTravel.mcm")

--- init mod
local function init()

    -- load services
    log:debug("Loading travel services...")
    local r = json.loadfile("mods\\rfuzzo\\ImmersiveTravel\\services.json")
    if r == nil then
        log:debug("!!! failed to load travel services.")
        return
    else
        services = r
    end

    for key, service in pairs(services) do
        local map = {} ---@type table<string, table>
        -- striders
        log:debug("Registered " .. key .. " destinations: ")
        for file in lfs.dir(
                        "Data Files\\MWSE\\mods\\rfuzzo\\ImmersiveTravel\\" ..
                            key) do
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
                        local v = {}
                        table.insert(v, destination)
                        map[start] = v

                    else
                        table.insert(result, destination)
                        map[start] = result
                    end
                end
            end
        end
        service.routes = map
    end

    log:info("[Immersive Travel] Loaded successfully.")

    -- dbg
    -- tes3.setGlobal("PS_GnisisDocks", 1)
    -- tes3.setGlobal("ColonyService", 6)
end
event.register(tes3.event.initialized, init)

--[[
"animationGroup": "walkForward",
      "animationFile": "ds22\\anim\\gondola.nif",
      "position": {
        "x": 0,
        "y": 0,
        "z": -46
      }
--]]
