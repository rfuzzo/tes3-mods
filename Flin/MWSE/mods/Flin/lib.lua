local logger = require("logging.logger")

local this   = {}


this.FLIN_DECK_ID          = "flin_deck_20"
this.FLIN_DECK_ID_FACEDOWN = "a_flin_deck_20_r"

this.log                   = logger.new {
    name = "Flin",
    logLevel = "TRACE", --TODO INFO
    logToConsole = false,
    includeTimestamp = false
}

---@enum ESuit
this.ESuit                 = {
    Hearts = 1,
    Bells = 2,
    Acorns = 3,
    Leaves = 4
}

---@param suit ESuit
---@return string
function this.suitToString(suit)
    if suit == this.ESuit.Hearts then
        return "Hearts"
    elseif suit == this.ESuit.Bells then
        return "Bells"
    elseif suit == this.ESuit.Acorns then
        return "Acorns"
    elseif suit == this.ESuit.Leaves then
        return "Leaves"
    end
    return "Unknown"
end

---@enum EValue
this.EValue = {
    Unter = 2,
    Ober = 3,
    King = 4,
    X = 10,
    Ace = 11,
}

-- TODO english names
---@param value EValue
---@return string
function this.valueToString(value)
    if value == this.EValue.Unter then
        return "Unter"
    elseif value == this.EValue.Ober then
        return "Ober"
    elseif value == this.EValue.King then
        return "King"
    elseif value == this.EValue.X then
        return "X"
    elseif value == this.EValue.Ace then
        return "Ace"
    end
    return "Unknown"
end

---@param suit ESuit
---@param value EValue
---@return string?
function this.GetCardMiscItemName(suit, value)
    local suitName = this.suitToString(suit):lower()
    if suitName == "unknown" then
        return nil
    end

    local valueName = this.valueToString(value):lower()
    if valueName == "unknown" then
        return nil
    end

    return string.format("card_%s_%s", suitName, valueName)
end

---@param suit ESuit
---@param value EValue
---@return string?
function this.GetCardActivatorName(suit, value)
    local suitName = this.suitToString(suit):lower()
    if suitName == "unknown" then
        return nil
    end

    local valueName = this.valueToString(value):lower()
    if valueName == "unknown" then
        return nil
    end

    return string.format("a_%s_%s", suitName, valueName)
end

---@param suit ESuit
---@param value EValue
---@return string?
function this.GetCardMeshName(suit, value)
    local suitName = this.suitToString(suit)
    if suitName == "Unknown" then
        return nil
    end

    local valueName = this.valueToString(value)
    if valueName == "Unknown" then
        return nil
    end

    return string.format("rf\\%s.%s.nif", suitName, valueName)
end

---@enum GameState
local GameState = {
    INVALID = 0,
    SETUP = 1,
    DEAL = 2,
    PLAYER_TURN = 3,
    NPC_TURN = 4,
    GAME_END = 5
}

---@param state GameState
---@return string
function this.stateToString(state)
    if state == GameState.INVALID then
        return "INVALID"
    elseif state == GameState.DEAL then
        return "DEAL"
    elseif state == GameState.PLAYER_TURN then
        return "PLAYER_TURN"
    elseif state == GameState.NPC_TURN then
        return "NPC_TURN"
    elseif state == GameState.GAME_END then
        return "GAME_END"
    end
    return "Unknown"
end

--#region tes3

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

--#endregion

return this
