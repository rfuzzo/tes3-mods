--[[
Immersive Travel Mod
v 1.0
by rfuzzo

mwse real-time travel mod

--]] -- 
local common = require("rfuzzo.ImmersiveTravel.common")

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIGURATION
local config = require("rfuzzo.ImmersiveTravelAddon.config")
local logger = require("logging.logger")
local log = logger.new {
    name = config.mod,
    logLevel = config.logLevel,
    logToConsole = true,
    includeTimestamp = true
}

local timertick = 0.01

local splines = {} ---@type table<string, table<string, PositionRecord[]>>
local map = {} ---@type table<string, SPointDto[]>
local services = {} ---@type table<string, ServiceData>?

local instanceTimer = nil ---@type mwseTimer?
local tracked = {} ---@type SPointDto[]

local VFX_DRAW = 1

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CLASSES

---@class SPointDto
---@field point PositionRecord
---@field routeId string
---@field serviceId string
---@field idx number
---@field currentSpline PositionRecord[]?
---@field splineIndex number
---@field mountData MountData?
---@field node niNode? -- debug

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// HELPERS

---@param pos PositionRecord
--- @return tes3vector3
local function vec(pos) return tes3vector3.new(pos.x, pos.y, pos.z) end

--- 
---@param data MountData
---@param startPoint tes3vector3
---@param nextPoint tes3vector3
---@param mountId string
---@return niNode
local function createMountVfx(data, startPoint, nextPoint, mountId)
    local d = nextPoint - startPoint
    d:normalize()

    -- create mount
    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    local mountOffset = tes3vector3.new(0, 0, data.offset)

    local meshPath = data.mesh
    local mount = tes3.loadMesh(meshPath):clone()
    mount.translation = startPoint + mountOffset
    mount.rotation = common.rotationFromDirection(d)

    log:debug("Created mount: " .. mountId)
    vfxRoot:attachChild(mount)

    return mount
end

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
---@param p SPointDto
local function cullObject(p)
    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot

    -- clean additional 
    if p.mountData then
        if p.mountData.guideSlot.node then
            vfxRoot:detachChild(p.mountData.guideSlot.node)
        end
        if p.mountData.slots then
            for index, slot in ipairs(p.mountData.slots) do
                if slot.node then vfxRoot:detachChild(slot.node) end
            end
        end
        if p.mountData.clutter then
            for index, slot in ipairs(p.mountData.clutter) do
                if slot.node then vfxRoot:detachChild(slot.node) end
            end
        end
    end

    if p.node then vfxRoot:detachChild(p.node) end

    table.removevalue(tracked, p)
end

--- move a mount in the world
---@param p SPointDto
local function simulate(p)

    -- checks
    if p.node == nil then return end
    if p.mountData == nil then return end
    if p.currentSpline == nil then return end

    if p.splineIndex <= #p.currentSpline then
        local mountOffset = tes3vector3.new(0, 0, p.mountData.offset)
        local nextPos = vec(p.currentSpline[p.splineIndex])
        local currentPos = p.node.translation - mountOffset

        local v = p.node.rotation:getForwardVector()
        v:normalize()
        local d = (nextPos - currentPos):normalized()
        local lerp = v:lerp(d, p.mountData.turnspeed / 10):normalized()

        -- calculate heading
        local current_rotation = p.node.rotation:toEulerXYZ()
        local current_facing = current_rotation.z
        local new_facing = math.atan2(d.x, d.y)
        local facing = new_facing
        local diff = new_facing - current_facing
        if diff < -math.pi then diff = diff + 2 * math.pi end
        if diff > math.pi then diff = diff - 2 * math.pi end
        local angle = p.mountData.turnspeed / 10000
        if diff > 0 and diff > angle then
            facing = current_facing + angle
        elseif diff < 0 and diff < -angle then
            facing = current_facing - angle
        else
            facing = new_facing
        end
        local m = tes3matrix33.new()
        m:fromEulerXYZ(current_rotation.x, current_rotation.y, facing)

        local f = tes3vector3.new(p.node.rotation:getForwardVector().x,
                                  p.node.rotation:getForwardVector().y, lerp.z):normalized()
        local delta = f * p.mountData.speed
        local mountPosition = currentPos + delta + mountOffset

        p.node.rotation = m
        p.node.translation = mountPosition

        -- position passengers in slots
        -- don't update passengers while behind
        local behind = common.isPointBehindObject(mountPosition,
                                                  tes3.player.position,
                                                  tes3.player.forwardDirection)
        if not behind then

            -- -- set sway
            -- swayTime = swayTime + timertick
            -- if swayTime > (2000 * sway_frequency) then swayTime = timertick end
            -- local sway = (sway_amplitude * mountData.sway) *
            --                  math.sin(2 * math.pi * sway_frequency * swayTime)
            -- local worldOrientation = toWorldOrientation(
            --                              tes3vector3.new(0.0, sway, 0.0),
            --                              mount.orientation)
            -- mount.orientation = worldOrientation

            local guidePos = mountPosition +
                                 common.toWorld(
                                     vec(p.mountData.guideSlot.position),
                                     p.node.rotation:toEulerXYZ())
            if p.mountData.guideSlot.node then
                p.mountData.guideSlot.node.translation = guidePos
            end
            for index, slot in ipairs(p.mountData.slots) do
                if slot.node then
                    local refpos = mountPosition +
                                       common.toWorld(vec(slot.position), p.node
                                                          .rotation:toEulerXYZ())
                    slot.node.translation = refpos
                end
            end
        end

        -- statics
        -- if p.mountData.clutter then
        --     for index, slot in ipairs(p.mountData.clutter) do
        --         if slot.node then
        --             local refpos = mountPosition +
        --                                common.toWorld(vec(slot.position), p.node
        --                                                   .rotation:toEulerXYZ())
        --             slot.node.translation = refpos
        --         end
        --     end
        -- end

        -- move to next marker
        local isBehind = -- common.isPointBehindObject(nextPos, p.mount.position, f)
        common.isPointBehindObject(nextPos, p.node.translation, f)
        if isBehind then p.splineIndex = p.splineIndex + 1 end

    else -- if i is at the end of the list
        timer.start({
            type = timer.simulate,
            iterations = 1,
            duration = 1,
            callback = (function()
                cullObject(p)
                -- tes3.worldController.vfxManager.worldVFXRoot:update()
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
        local d = vec(p.point):distance(s.node.translation)
        if d < config.spawnExlusionRadius * 8192 then return false end
    end

    return true
end

--- cull nodes in distance
local function doCull()

    local toremove = {}
    for index, s in ipairs(tracked) do
        local d = tes3.player.position:distance(s.node.translation)
        if d > config.cullRadius * 8192 then table.insert(toremove, s) end
        -- if d > mge.distantLandRenderConfig.drawDistance * 8192 then
        --     table.insert(toremove, s)
        -- end
    end

    for index, s in ipairs(toremove) do
        -- cull
        cullObject(s)

        log:debug("Culled ref at pos: " .. index)
    end

    if #toremove > 0 then
        log:debug("Tracked: " .. #tracked)
        tes3.messageBox("Tracked: " .. #tracked)
    end

end

--- spawn an object on the vfx node and register it
---@param p SPointDto
local function doSpawn(p)

    if not services then return end

    local split = string.split(p.routeId, "_")
    local start = split[1]
    local destination = split[2]
    local service = services[p.serviceId]
    local idx = p.idx

    local startPoint = vec(splines[service.class][p.routeId][idx])
    local nr = splines[service.class][p.routeId][idx + 1]
    if not nr then return end
    local nextPoint = vec(nr)

    -- create mount
    local mountId = service.mount
    -- override mounts 
    if service.override_mount then
        for key, value in pairs(service.override_mount) do
            if common.is_in(value, start) and common.is_in(value, destination) then
                mountId = key
                break
            end
        end
    end
    local mountData = common.loadMountData(mountId)
    if not mountData then return end

    -- simulate
    p.splineIndex = idx
    p.currentSpline = splines[service.class][p.routeId]
    p.mountData = mountData
    p.node = createMountVfx(p.mountData, startPoint, nextPoint, mountId)

    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot

    -- register passengers
    if p.mountData.idList then
        for index, meshPath in ipairs(p.mountData.idList) do
            local node = tes3.loadMesh(meshPath):clone()
            node.translation = startPoint +
                                   tes3vector3.new(0, 0, p.mountData.offset)
            local m = tes3matrix33.new()
            m:toIdentity()
            node.rotation = m
            vfxRoot:attachChild(node)

            if index == 1 then
                -- register as guide
                p.mountData.guideSlot.node = node
            else
                registerNode(p.mountData, node)
            end

        end
    end

    -- register statics
    -- statics
    if p.mountData.clutter then
        for index, clutter in ipairs(p.mountData.clutter) do
            if clutter.mesh then
                -- instantiate
                local node = tes3.loadMesh(clutter.mesh):clone()
                node.translation = startPoint +
                                       tes3vector3.new(0, 0, p.mountData.offset)
                local m = tes3matrix33.new()
                m:toIdentity()
                node.rotation = m
                vfxRoot:attachChild(node)

                -- register
                registerStaticNode(p.mountData, node, index)
            end
        end
    end

    table.insert(tracked, p)

    log:debug(mountId .. " spawned at: " .. p.point.x .. ", " .. p.point.y ..
                  ", " .. p.point.z)
    -- tes3.messageBox(
    --     mountId .. " spawned at: " .. p.point.x .. ", " .. p.point.y .. ", " ..
    --         p.point.z)
end

--- all logic for all simulated nodes on timer tick
local function onTimerTick()
    for key, p in pairs(tracked) do simulate(p) end
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
---@param allowFront boolean also allow spawn in front
---@return SPointDto[]
local function getSpawnCandidates(allowFront)
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

    for index, value in ipairs(tracked) do cullObject(value) end
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
    local spawnCandidates = getSpawnCandidates(true)
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

                            table.insert(map[cell_key], {
                                point = pos,
                                routeId = start .. "_" .. destination,
                                serviceId = service.class,
                                idx = idx
                            })

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
    local spawnCandidates = getSpawnCandidates(false)
    trySpawn(spawnCandidates)
    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    vfxRoot:update()
end
event.register(tes3.event.cellChanged, cellChangedCallback)

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// DEBUG

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("rfuzzo.ImmersiveTravelAddon.mcm")
