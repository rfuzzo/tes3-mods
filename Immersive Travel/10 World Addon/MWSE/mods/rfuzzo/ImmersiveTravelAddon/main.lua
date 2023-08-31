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

local splines = {} ---@type table<string, table<string, PositionRecord[]>>
local map = {} ---@type table<string, SPointDto[]>
local services = {} ---@type table<string, ServiceData>?

local instanceTimer = nil ---@type mwseTimer?
local tracked = {} ---@type SPointDto[]

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

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// FUNCTIONS

---@param p SPointDto
local function destinationReached(p)
    if p.node then
        local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
        vfxRoot:detachChild(p.node)
        p.node = nil
    end

    if p.mountData then
        if p.mountData.slots then
            for index, slot in ipairs(p.mountData.slots) do
                if slot.reference then
                    slot.reference:delete()
                    slot.reference = nil
                end
            end
        end
        p.mountData = nil
    end

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
        p.node.rotation = m
        local f = tes3vector3.new(p.node.rotation:getForwardVector().x,
                                  p.node.rotation:getForwardVector().y, lerp.z):normalized()
        local delta = f * p.mountData.speed
        local mountPosition = currentPos + delta + mountOffset
        p.node.translation = mountPosition

        tes3.worldController.vfxManager.worldVFXRoot:update()
        -- -- set sway
        -- swayTime = swayTime + timertick
        -- if swayTime > (2000 * sway_frequency) then swayTime = timertick end
        -- local sway = (sway_amplitude * mountData.sway) *
        --                  math.sin(2 * math.pi * sway_frequency * swayTime)
        -- local worldOrientation = toWorldOrientation(
        --                              tes3vector3.new(0.0, sway, 0.0),
        --                              mount.orientation)
        -- mount.orientation = worldOrientation

        -- -- guide
        -- local guidePos = mount.position +
        --                      common.toWorld(vec(mountData.guideSlot.position),
        --                                     mount.orientation)
        -- tes3.positionCell({
        --     reference = mountData.guideSlot.reference,
        --     position = guidePos
        -- })
        -- mountData.guideSlot.reference.facing = mount.facing

        -- position references in slots
        for index, slot in ipairs(p.mountData.slots) do
            if slot.reference then
                local refpos = mountPosition -- + vec(slot.position)
                +
                                   common.toWorld(vec(slot.position),
                                                  p.node.rotation:toEulerXYZ())
                slot.reference.position = refpos
            end
        end

        -- statics
        -- if p.mountData.clutter then
        --     for index, slot in ipairs(p.mountData.clutter) do
        --         if slot.reference then
        --             local refpos = p.node.translation +
        --                                common.toWorld(vec(slot.position),
        --                                               p.node.translation)
        --             slot.reference.position = refpos
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
                destinationReached(p)
                tes3.worldController.vfxManager.worldVFXRoot:update()
            end)
        })
    end
end

local function onTimerTick() for key, p in pairs(tracked) do simulate(p) end end

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

local function doCull()

    local toremove = {}
    for index, s in ipairs(tracked) do
        local d = tes3.player.position:distance(s.node.translation)
        if d > config.cullRadius * 8192 then table.insert(toremove, s) end
    end

    for index, s in ipairs(toremove) do
        -- cull
        destinationReached(s)

        log:debug("Culled ref at pos: " .. index)
        tes3.messageBox("Culled ref at pos: " .. index)
    end
end

local timertick = 0.01

---@param p SPointDto
local function doSpawn(p)

    if not services then return end

    local split = string.split(p.routeId, "_")
    local start = split[1]
    local destination = split[2]
    local service = services[p.serviceId]
    local idx = p.idx

    local startPoint = vec(splines[service.class][p.routeId][idx])
    local nextPoint = vec(splines[service.class][p.routeId][idx + 1])

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
    p.mountData = table.deepcopy(mountData)
    p.node = common.createMountVfx(p.mountData, startPoint, nextPoint, mountId)

    -- register passagers
    if p.mountData.idList then
        for index, id in ipairs(p.mountData.idList) do
            local ref = tes3.createReference {
                object = id,
                position = startPoint +
                    tes3vector3.new(0, 0, p.mountData.offset),
                orientation = tes3vector3.new(0, 0, 0)
            }
            common.registerNode(p.mountData, ref)
        end
    end

    table.insert(tracked, p)

    log:debug(mountId .. " spawned at: " .. p.point.x .. ", " .. p.point.y ..
                  ", " .. p.point.z)
    tes3.messageBox(
        mountId .. " spawned at: " .. p.point.x .. ", " .. p.point.y .. ", " ..
            p.point.z)
end

---@return SPointDto[]
local function getSpawnCandidates()
    local spawnCandidates = {} ---@type SPointDto[]

    -- get cells behind me in a radius
    local r = config.spawnRadius
    local cx = tes3.player.cell.gridX
    local cy = tes3.player.cell.gridY
    local vplayer = tes3vector3.new(cx, cy, 0)

    for i = cx - r, cx + r, 1 do
        for j = cy - r, cy + r, 1 do
            -- check if behind
            local vtest = tes3vector3.new(i, j, 0)
            local behind = common.isPointBehindObject(vtest, vplayer,
                                                      tes3.player
                                                          .forwardDirection)
            if behind then
                local cellKey = tostring(i) .. "," .. tostring(j)
                -- get points
                local points = map[cellKey]
                if points then
                    -- log:debug("cell: " .. tostring(i) .. "," .. tostring(j))

                    for index, p in ipairs(points) do
                        -- log:debug(
                        --     p.id .. ": " .. p.point.x .. ", " .. p.point.y ..
                        --         ", " .. p.point.z)

                        table.insert(spawnCandidates, p)
                    end
                end
            end
        end
    end

    return spawnCandidates
end

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
--- @param e loadEventData
local function loadCallback(e)
    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    vfxRoot:detachAllChildren()

    if instanceTimer then
        instanceTimer:cancel()
        instanceTimer = nil
    end

    for index, value in ipairs(tracked) do destinationReached(value) end
    tracked = {}

    vfxRoot:update()
end
event.register(tes3.event.load, loadCallback)

--- Init Mod
--- @param e initializedEventData
local function initializedCallback(e)

    services = common.loadServices()
    if not services then return end

    -- TODO disable mod

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

    -- divineMarker = tes3.loadMesh(divineMarkerId)
end
event.register(tes3.event.initialized, initializedCallback)

--- Cull and spawn on cell changed
--- @param e cellChangedEventData
local function cellChangedCallback(e)

    if not instanceTimer then
        instanceTimer = timer.start({
            duration = timertick,
            type = timer.simulate,
            iterations = -1,
            callback = onTimerTick
        })
    end

    -- /////////////////////////
    -- log:debug("STAGE Cull")
    doCull()

    -- /////////////////////////
    -- log:debug("STAGE Check availability")
    local spawnCandidates = getSpawnCandidates()

    -- /////////////////////////
    -- log:debug("STAGE Spawning")
    trySpawn(spawnCandidates)

    local vfxRoot = tes3.worldController.vfxManager.worldVFXRoot
    vfxRoot:update()
end
event.register(tes3.event.cellChanged, cellChangedCallback)

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// DEBUG

--- @param e keyDownEventData
local function keyDownCallback(e)
    if e.keyCode == tes3.scanCode["6"] then

        -- /////////////////////////
        log:debug("STAGE Cull")
        doCull()

        -- /////////////////////////
        log:debug("STAGE Check availability")
        local spawnCandidates = getSpawnCandidates()

        -- /////////////////////////
        log:debug("STAGE Spawning")
        trySpawn(spawnCandidates)

    end
end
event.register(tes3.event.keyDown, keyDownCallback)

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("rfuzzo.ImmersiveTravelAddon.mcm")
