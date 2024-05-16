local logger = require("logging.logger")

local this   = {}

this.log     = logger.new {
    name = "Flin",
    logLevel = "TRACE", --TODO INFO
    logToConsole = false,
    includeTimestamp = false
}

function this.getLookedAtReference()
    -- Get the player's eye position and direction.
    local eyePos = tes3.getPlayerEyePosition()
    local eyeDir = tes3.getPlayerEyeVector()

    -- Perform a ray test from the eye position along the eye direction.
    local result = tes3.rayTest({
        position = eyePos,
        direction = eyeDir,
        ignore = { tes3.player }
    })

    -- If the ray hit something, return the reference of the object.
    if (result) then return result.reference end

    -- Otherwise, return nil.
    return nil
end

-- DEBUG
local function showDebugMarkerAt(pos)
    tes3.createReference({
        object = "light_com_candle_06_64",
        position = pos,
        orientation = tes3vector3.new(0, 0, 0),
        cell = tes3.getPlayerCell(),
        scale = 0.2
    })
end

---@param ref tes3reference
---@return tes3vector3?
function this.findPlayerPosition(ref)
    local bb = ref.object.boundingBox:copy()
    local xyoffset = 20
    bb.max.x = math.round(bb.max.x + xyoffset)
    bb.max.y = math.round(bb.max.y + xyoffset)
    bb.min.x = math.round(bb.min.x - xyoffset)
    bb.min.y = math.round(bb.min.y - xyoffset)

    local t = ref.sceneNode.worldTransform

    local stepsize = 40
    -- get x steps in a table
    local xsteps = {}
    for x = bb.min.x, bb.max.x, stepsize do
        table.insert(xsteps, x)
    end
    -- insert end pos
    table.insert(xsteps, bb.max.x)
    -- get y steps in a table
    local ysteps = {}
    for y = bb.min.y, bb.max.y, stepsize do
        table.insert(ysteps, y)
    end
    -- insert end pos
    table.insert(ysteps, bb.max.y)

    -- get all positions on the edge of the bounding box in xyoffset step
    local testOffset = 10
    local height = bb.max.z - bb.min.z
    local testHeight = height + testOffset
    local results = {} ---@type tes3vector3[]
    for _, x in ipairs(xsteps) do
        for _, y in ipairs(ysteps) do
            -- only test the edges of the bounding box
            if x == bb.min.x or x == bb.max.x or y == bb.min.y or y == bb.max.y then
                -- log:trace("Testing %d %d", x, y)

                -- convert to world position
                local testPosRaw = t * tes3vector3.new(x, y, testHeight)
                local testPos1 = testPosRaw --+ (direction * 30)
                local result = tes3.rayTest({
                    position = testPos1,
                    direction = tes3vector3.new(0, 0, -1),
                    maxDistance = testHeight - (testOffset / 2),
                    root = tes3.game.worldPickRoot
                })
                local result2 = tes3.rayTest({
                    position = testPos1,
                    direction = tes3vector3.new(0, 0, -1),
                    maxDistance = testHeight - (testOffset / 2),
                    root = tes3.game.worldObjectRoot
                })

                -- if no result then we found no obstacles
                showDebugMarkerAt(testPos1)
                if result == nil and result2 == nil then
                    showDebugMarkerAt(testPos1 - tes3vector3.new(0, 0, testHeight - (testOffset / 2)))

                    -- final pos is on the ground
                    local resultPos = testPos1 - tes3vector3.new(0, 0, testHeight)
                    -- add to results
                    table.insert(results, resultPos)
                end
            end
        end
    end

    -- if table is empty then we found no valid positions
    if #results == 0 then
        return nil
    end

    -- otherwise get a random position from the table
    local resultPos = results[math.random(#results)]
    tes3.createReference({
        object = "furn_6th_ashstatue",
        position = resultPos,
        orientation = tes3vector3.new(0, 0, 0),
        cell = tes3.getPlayerCell()
    })
    return resultPos
end

return this
