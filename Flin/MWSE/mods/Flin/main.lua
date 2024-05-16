local lib        = require("Flin.lib")
local game       = require("Flin.game")
local log        = lib.log

local GAME_TOPIC = "game of Flin"

--- @param e loadedEventData
local function loadedCallback(e)
    local result = tes3.addTopic({
        topic = GAME_TOPIC
    })

    log:debug("addTopic %s: %s", GAME_TOPIC, result)
end
event.register(tes3.event.loaded, loadedCallback)


---@param ref tes3reference
---@param npcPos tes3vector3
local function findCardSpawnPoints(ref, npcPos)
    -- get reference bounding box
    local bb = ref.object.boundingBox:copy()
    -- get reference transform
    local t = ref.sceneNode.worldTransform
    -- get middle of ref
    local middle = ((bb.min + bb.max) / 2)
    -- get top middle of ref in world space

    local offset = 50
    local startpos = t * tes3vector3.new(middle.x, middle.y, bb.max.z + offset)
    -- get pos in world space
    local endpos = tes3vector3.new(npcPos.x, npcPos.y, bb.max.z + offset)

    local direction = (endpos - startpos)
    local distance = direction:length()
    direction = direction:normalized()
    -- now go in a line from topMiddle to pos in 20 units steps
    for i = 0, distance, 20 do
        local pos = startpos + direction * i
        local result = tes3.rayTest({
            position = pos,
            direction = tes3vector3.new(0, 0, -1),
            ignore = { ref },
            maxDistance = offset
        })

        if not result then
            -- final pos is on the surface
            local cardPos = pos - tes3vector3.new(0, 0, offset)
            -- spawn mesh on top
            --local cardName = game.GetCardMiscItemName(game.ESuit.Acorns, game.EValue.Ace)
            local cardName = game.GetCardActivatorName(game.ESuit.Acorns, game.EValue.Ace)
            if cardName then
                --get top of the target position
                local card = tes3.createReference({
                    object = cardName,
                    position = cardPos,
                    orientation = tes3vector3.new(0, 0, 0), --target.orientation
                    cell = tes3.getPlayerCell()
                })
                if card then
                    debug.log(card)
                    log:debug("Spawned card '%s' at %s", cardName, cardPos)
                else
                    log:debug("Failed to spawn card '%s' at %s", cardName, cardPos)
                    return
                end
            end

            break
        end
    end
end

--- @param e keyDownEventData
local function keyDownCallback(e)
    if e.keyCode == tes3.scanCode["o"] then
        -- spawn mesh
        -- get target reference
        local target = lib.getLookedAtReference()
        if not target then
            tes3.messageBox("No target")
            return
        end

        lib.findPlayerPosition(target)
    end
end
event.register(tes3.event.keyDown, keyDownCallback)
