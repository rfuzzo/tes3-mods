--[[

TODOS
- only render in visible range
- add passengers
- add statics
- add guide

- evade the player ship as well

--]]
--
local common = require("rfuzzo.ImmersiveTravel.common")

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local config = require("ImmersiveTravelAddonWorld.config")
local logger = require("logging.logger")
local log = logger.new {
    name = config.mod,
    logLevel = config.logLevel,
    logToConsole = false,
    includeTimestamp = false
}

local timertick = 0.01

local splines = {} ---@type table<string, table<string, PositionRecord[]>>
local map = {} ---@type table<string, SPointDto[]>
local services = {} ---@type table<string, ServiceData>?

local instanceTimer = nil ---@type mwseTimer?
local tracked = {} ---@type SPoint[]

local VFX_DRAW = 1

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CLASSES

---@class SPointDto
---@field point PositionRecord
---@field routeId string
---@field serviceId string
---@field splineIndex number

---@class SPoint
---@field point PositionRecord
---@field routeId string
---@field serviceId string
---@field splineIndex number
---@field last_position tes3vector3
---@field last_forwardDirection tes3vector3
---@field last_facing number
---@field currentSpline PositionRecord[]?
---@field mountData MountData?
---@field handle mwseSafeObjectHandle?


-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// HELPERS

---@param pos PositionRecord
--- @return tes3vector3
local function vec(pos) return tes3vector3.new(pos.x, pos.y, pos.z) end

-- ---
-- ---@param data MountData
-- ---@param startPoint tes3vector3
-- ---@param nextPoint tes3vector3
-- ---@param mountId string
-- ---@return niNode
-- local function createMountVfx(data, startPoint, nextPoint, mountId)
--     local d = nextPoint - startPoint
--     d:normalize()

--     -- create mount
--     local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
--     local mountOffset = tes3vector3.new(0, 0, data.offset)

--     local meshPath = data.mesh
--     local mount = tes3.loadMesh(meshPath):clone()
--     mount.translation = startPoint + mountOffset
--     mount.rotation = common.rotationFromDirection(d)

--     log:debug("Created mount: " .. mountId)
--     vfxRoot:attachChild(mount)

--     return mount
-- end

---@param data MountData
---@param node niNode|nil
---@param idx integer
local function registerNodeInSlot(data, node, idx) data.slots[idx].node = node end

---@param data MountData
---@return integer|nil index
local function getFirstFreeSlot(data)
    for index, value in ipairs(data.slots) do
        if value.node == nil then return index end
    end
    return nil
end

---@param data MountData
---@param node niNode
local function registerNode(data, node)
    -- get first free slot
    local i = getFirstFreeSlot(data)
    if not i then return end
    registerNodeInSlot(data, node, i)
end

---@param data MountData
---@param node niNode
---@param i integer
local function registerStaticNode(data, node, i)
    data.clutter[i].node = node

    log:debug("registered " .. node.name .. " in static slot " .. tostring(i))
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// FUNCTIONS

--- cull single object
---@param p SPoint
local function cullObject(p)
    if p.mountData then
        if p.handle and p.handle:valid() then
            tes3.removeSound({ reference = p.handle:getObject() })
        end

        -- delete guide
        if p.mountData.guideSlot.handle and p.mountData.guideSlot.handle:valid() then
            p.mountData.guideSlot.handle:getObject():delete()
            p.mountData.guideSlot.handle = nil
        end

        -- delete passengers
        for index, slot in ipairs(p.mountData.slots) do
            if slot.handle and slot.handle:valid() then
                local ref = slot.handle:getObject()
                if ref ~= tes3.player and not common.isFollower(ref.mobile) then
                    ref:delete()
                    slot.handle = nil
                end
            end
        end

        -- delete statics
        if p.mountData.clutter then
            for index, clutter in ipairs(p.mountData.clutter) do
                if clutter.handle and clutter.handle:valid() then
                    clutter.handle:getObject():delete()
                    clutter.handle = nil
                end
            end
        end
    end
    p.mountData = nil

    -- delete the mount
    if p.handle and p.handle:valid() then
        p.handle:getObject():delete()
        p.handle = nil
    end


    table.removevalue(tracked, p)
end

---comment
---@param origin tes3vector3
---@param forwardVector tes3vector3
---@param target tes3vector3
---@param coneRadius number
---@param coneAngle number
---@return boolean
local function isPointInCone(origin, forwardVector, target, coneRadius,
                             coneAngle)
    -- Calculate the vector from the origin to the target point
    local toTarget = target - origin

    -- Calculate the cosine of the angle between the forward vector and the vector to the target
    local dotProduct = forwardVector:dot(toTarget)

    -- Calculate the magnitudes of both vectors
    local forwardMagnitude = forwardVector:length()
    local toTargetMagnitude = toTarget:length()

    -- Calculate the cosine of the angle between the vectors
    local cosAngle = dotProduct / (forwardMagnitude * toTargetMagnitude)

    -- Calculate the angle in radians
    local angleInRadians = math.acos(cosAngle)

    -- Check if the angle is less than or equal to half of the cone angle and the distance is within the cone radius
    if angleInRadians <= coneAngle / 2 and toTargetMagnitude <= coneRadius then
        return true
    else
        return false
    end
end

---@param referenceVector tes3vector3
---@param targetVector tes3vector3
---@return boolean
local function isVectorRight(referenceVector, targetVector)
    local crossProduct =
        referenceVector.x * targetVector.y - referenceVector.y * targetVector.x

    if crossProduct > 0 then
        return true  -- "right"
    elseif crossProduct < 0 then
        return false -- "left"
    else
        return false --- "collinear"  -- The vectors are collinear
    end
end

--- move a mount in the world
---@param p SPoint
local function simulate(p)
    -- checks
    if p.handle == nil then return end
    local mountData = p.mountData
    if mountData == nil then return end
    if p.currentSpline == nil then return end
    if not p.handle:valid() then return end
    if not p.handle:getObject() then return end


    local boneOffset = tes3vector3.new(0, 0, 0)
    local rootBone = p.handle:getObject().sceneNode
    if not rootBone then return end
    if p.mountData.nodeName then
        rootBone = p.handle:getObject().sceneNode:getObjectByName(p.mountData.nodeName) --[[@as niNode]]
        boneOffset = vec(p.mountData.nodeOffset)
    end
    if rootBone == nil then
        rootBone = p.handle:getObject().sceneNode
    end
    if rootBone == nil then
        return
    end

    if p.splineIndex <= #p.currentSpline then
        local mountOffset = tes3vector3.new(0, 0, mountData.offset)
        local nextPos = vec(p.currentSpline[p.splineIndex])
        local currentPos = p.last_position - mountOffset



        -- change position when about to collide
        local collision = false
        for index, value in ipairs(tracked) do
            if value ~= p and currentPos:distance(value.last_position) < 8192 then
                -- TODO what values to use here?
                local check = isPointInCone(currentPos, p.last_forwardDirection, value.last_position, 6144, 0.785)
                if check then
                    collision = true
                    break
                end
            end
        end

        -- evade
        local virtualpos = nextPos
        if collision then
            -- override the next position temporarily
            virtualpos = rootBone.worldTransform * tes3vector3.new(1204, 1024, nextPos.z)
        end

        -- calculate diffs
        local forwardDirection = p.last_forwardDirection
        if forwardDirection == nil then return end
        forwardDirection:normalize()
        local d = (virtualpos - currentPos):normalized()
        local lerp = forwardDirection:lerp(d, mountData.turnspeed / 10):normalized()

        -- calculate position
        local forward = tes3vector3.new(p.handle:getObject().forwardDirection.x, p.handle:getObject().forwardDirection.y,
            lerp.z):normalized()
        local delta = forward * mountData.speed
        local playerShipLocal = rootBone.worldTransform:invert() * tes3.player.position

        -- calculate facing
        local turn = 0
        local current_facing = p.last_facing
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

        -- move
        p.handle:getObject().facing = facing
        p.handle:getObject().position = currentPos + delta + mountOffset

        -- save
        p.last_position = p.handle:getObject().position
        p.last_forwardDirection = p.handle:getObject().forwardDirection
        p.last_facing = p.handle:getObject().facing

        -- -- TODO render only in visible range
        -- TODO calculate the normalized forward or Y direction vector of the reference.
        -- p.last_position = currentPos + delta + mountOffset
        -- p.last_facing = facing
        -- p.last_forwardDirection = newforwardDirection

        -- -- render
        -- local behind = common.isPointBehindObject(p.handle:getObject().position,
        --     tes3.player.position,
        --     tes3.player.forwardDirection)
        -- if not behind then
        --     -- move ship
        --     p.handle:getObject().facing = facing
        --     p.handle:getObject().position = currentPos + delta + mountOffset
        -- end

        -- TODO additional refs

        -- move to next marker
        local isBehind = common.isPointBehindObject(nextPos, p.handle:getObject().position,
            p.handle:getObject().forwardDirection)
        if isBehind then
            p.splineIndex = p.splineIndex + 1
        end
    else -- if i is at the end of the list
        timer.start({
            type = timer.simulate,
            iterations = 1,
            duration = 1,
            callback = (function()
                cullObject(p)
            end)
        })
    end
end

--- check if a node can spawn
---@param p SPointDto
---@return boolean
local function canSpawn(p)
    if #tracked >= config.budget then return false end

    for index, s in ipairs(tracked) do
        if s.last_position then
            local d = vec(p.point):distance(s.last_position)
            if d < config.spawnExlusionRadius * 8192 then return false end
        end
    end

    return true
end

--- cull nodes in distance
local function doCull()
    ---@type SPoint[]
    local toremove = {}
    for index, s in ipairs(tracked) do
        local d = tes3.player.position:distance(s.last_position)
        if d > config.cullRadius * 8192 then table.insert(toremove, s) end
        -- if d > mge.distantLandRenderConfig.drawDistance * 8192 then
        --     table.insert(toremove, s)
        -- end
    end

    for index, s in ipairs(toremove) do
        -- cull
        cullObject(s)

        log:debug("Culled %s on route %s", s.serviceId, s.routeId)
    end

    if #toremove > 0 then
        log:debug("Tracked: " .. #tracked)
        tes3.messageBox("Tracked: " .. #tracked)
    end
end

--- spawn an object on the vfx node and register it
---@param point SPointDto
local function doSpawn(point)
    if not services then return end

    local split = string.split(point.routeId, "_")
    local start = split[1]
    local destination = split[2]
    local service = services[point.serviceId]
    local idx = point.splineIndex

    local startPoint = vec(splines[service.class][point.routeId][idx])
    local nr = splines[service.class][point.routeId][idx + 1]
    if not nr then return end
    local nextPoint = vec(nr)
    local d = nextPoint - startPoint
    d:normalize()
    local new_facing = math.atan2(d.x, d.y)


    -- create mount
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
    local mountData = common.loadMountData(mountId)
    if not mountData then return end

    -- create mount
    local mountOffset = tes3vector3.new(0, 0, mountData.offset)
    local mount = tes3.createReference {
        object = mountId,
        position = startPoint + mountOffset,
        orientation = d
    }
    mount.facing = new_facing
    if mountData.forwardAnimation then
        tes3.loadAnimation({ reference = mount })
        tes3.playAnimation({ reference = mount, group = tes3.animationGroup[mountData.forwardAnimation] })
    end

    -- TODO register additional refs

    -- register guide
    local guideId = service.guide
    local guide2 = tes3.createReference {
        object = guideId,
        position = startPoint + mountOffset,
        orientation = mount.orientation
    }
    guide2.mobile.hello = 0
    log:debug("> registering guide")
    common.registerGuide(mountData, tes3.makeSafeObjectHandle(guide2))

    -- add
    ---@type SPoint
    local p = {
        point = point.point,
        routeId = point.routeId,
        serviceId = point.serviceId,
        splineIndex = idx,
        last_position = mount.position,
        last_forwardDirection = mount.forwardDirection,
        last_facing = mount.facing
    }
    p.currentSpline = splines[service.class][p.routeId]
    p.mountData = mountData
    p.handle = tes3.makeSafeObjectHandle(mount)

    table.insert(tracked, p)
    log:debug(mountId .. " spawned at: " .. p.point.x .. ", " .. p.point.y .. ", " .. p.point.z)
end

--- all logic for all simulated nodes on timer tick
local function onTimerTick()
    --
    for key, p in pairs(tracked) do
        simulate(p)
    end

    -- cull nodes
    doCull()
    tes3.worldController.vfxManager.worldVFXRoot:update()
end

local function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

--- get possible cells where objects can spawn
---@return SPointDto[]
local function getSpawnCandidates()
    local spawnCandidates = {} ---@type SPointDto[]
    local dd = config.spawnRadius
    local cx = tes3.player.cell.gridX
    local cy = tes3.player.cell.gridY
    local vplayer = tes3vector3.new(cx, cy, 0)

    for i = cx - dd, cx + dd, 1 do
        for j = cy - dd, cy + dd, 1 do
            local vtest = tes3vector3.new(i, j, 0)
            local d = vplayer:distance(vtest)

            if d > VFX_DRAW then
                local cellKey = tostring(i) .. "," .. tostring(j)
                local points = map[cellKey]
                if points then
                    for index, p in ipairs(points) do
                        table.insert(spawnCandidates, p)
                    end
                end
            end
        end
    end

    shuffle(spawnCandidates)
    return spawnCandidates
end

--- try spawn an object in the world
---@param spawnCandidates SPointDto[]
local function trySpawn(spawnCandidates)
    for index, p in ipairs(spawnCandidates) do
        -- try spawn
        local roll = math.random(100)
        if roll < config.spawnChance then
            -- check if can spawn
            if canSpawn(p) then doSpawn(p) end
        end
    end
end

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// EVENTS

--- Cleanup on save load
--- @param e loadedEventData
local function loadedCallback(e)
    if not config.modEnabled then return end

    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    vfxRoot:detachAllChildren()

    if instanceTimer then
        instanceTimer:cancel()
        instanceTimer = nil
    end

    for index, value in ipairs(tracked) do
        cullObject(value)
    end
    tracked = {}

    if not instanceTimer then
        instanceTimer = timer.start({
            duration = timertick,
            type = timer.simulate,
            iterations = -1,
            callback = onTimerTick
        })
    end
    doCull()
    local spawnCandidates = getSpawnCandidates()
    trySpawn(spawnCandidates)
    vfxRoot:update()
end
event.register(tes3.event.loaded, loadedCallback)

--- Init Mod
--- @param e initializedEventData
local function initializedCallback(e)
    if not config.modEnabled then return end

    services = common.loadServices()
    if not services then
        config.modEnabled = false
        return
    end

    for key, service in pairs(services) do
        log:info(service.class)

        common.loadRoutes(service)
        local destinations = service.routes
        if destinations then
            for _i, start in ipairs(table.keys(destinations)) do
                for _j, destination in ipairs(destinations[start]) do
                    local spline =
                        common.loadSpline(start, destination, service)
                    if spline then
                        if not splines[service.class] then
                            splines[service.class] = {}
                        end

                        splines[service.class][start .. "_" .. destination] =
                            spline

                        for idx, pos in ipairs(spline) do
                            local cx = math.floor(pos.x / 8192)
                            local cy = math.floor(pos.y / 8192)

                            local cell_key = tostring(cx) .. "," .. tostring(cy)
                            if not map[cell_key] then
                                map[cell_key] = {}
                            end

                            ---@type SPointDto
                            local point = {
                                point = pos,
                                routeId = start .. "_" .. destination,
                                serviceId = service.class,
                                splineIndex = idx
                            }
                            table.insert(map[cell_key], point)
                        end
                    end
                end
            end
        end
    end

    -- dbg
    json.savefile("dbg_splines", splines)
    json.savefile("dbg_map", map)
end
event.register(tes3.event.initialized, initializedCallback)

--- Cull and spawn on cell changed
--- @param e cellChangedEventData
local function cellChangedCallback(e)
    if not config.modEnabled then return end

    if not instanceTimer then
        instanceTimer = timer.start({
            duration = timertick,
            type = timer.simulate,
            iterations = -1,
            callback = onTimerTick
        })
    end
    doCull()
    local spawnCandidates = getSpawnCandidates()
    trySpawn(spawnCandidates)
    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    vfxRoot:update()
end
event.register(tes3.event.cellChanged, cellChangedCallback)

--- @param e saveEventData
local function saveCallback(e)
    -- go through all tracked objects and set .modified = false
    for index, s in ipairs(tracked) do
        if s.handle and s.handle:valid() then
            s.handle:getObject().modified = false
        end
    end
end
event.register(tes3.event.save, saveCallback)

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// DEBUG

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("ImmersiveTravelAddonWorld.mcm")
