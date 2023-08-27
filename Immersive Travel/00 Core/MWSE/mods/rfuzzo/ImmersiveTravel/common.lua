local this = {}

-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// COMMON

local logger = require("logging.logger")
local log = logger.new {
    name = "Immersive Travel",
    logLevel = "DEBUG",
    logToConsole = true,
    includeTimestamp = true
}

local localmodpath = "mods\\rfuzzo\\ImmersiveTravel\\"
local fullmodpath = "Data Files\\MWSE\\" .. localmodpath

---comment
---@param point tes3vector3
---@param objectPosition tes3vector3
---@param objectForwardVector tes3vector3
---@return boolean
function this.isPointBehindObject(point, objectPosition, objectForwardVector)
    local vectorToPoint = point - objectPosition
    local dotProduct = vectorToPoint:dot(objectForwardVector)
    return dotProduct < 0
end

--- list contains
---@param table string[]
---@param str string
function this.is_in(table, str)
    for index, value in ipairs(table) do if value == str then return true end end
    return false
end

--- load json spline from file
---@param start string
---@param destination string
---@param data ServiceData
---@return PositionRecord[]|nil
function this.loadSpline(start, destination, data)
    local fileName = start .. "_" .. destination
    local filePath = localmodpath .. data.class .. "\\" .. fileName
    local result = json.loadfile(filePath)
    if result ~= nil then
        log:debug("loaded spline: " .. fileName)
        return result
    else
        log:error("!!! failed to load spline: " .. fileName)
        return nil
    end
end

--- load json static mount data
---@param id string
---@return MountData|nil
function this.loadMountData(id)
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

--- Load all services
---@return table<string,ServiceData>|nil
function this.loadServices()
    log:debug("Loading travel services...")

    ---@type table<string,ServiceData>|nil
    local services = {}
    for fileName in lfs.dir(fullmodpath .. "services") do
        if (string.endswith(fileName, ".json")) then
            -- parse
            local r = json.loadfile(localmodpath .. "services\\" .. fileName)
            if r then
                services[fileName:sub(0, -6)] = r

                log:debug("Loaded " .. fileName)
            else
                log:error("!!! failed to load " .. fileName)
            end
        end

    end
    return services
end

--- Load all route splines for a given service
---@param service ServiceData
function this.loadRoutes(service)
    local map = {} ---@type table<string, table>

    log:debug("Registered " .. service.class .. " destinations: ")

    for file in lfs.dir(fullmodpath .. service.class) do
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

return this
