local lib        = require("Flin.lib")
local game       = require("Flin.game")
local log        = lib.log

local GAME_TOPIC = "game of Flin"
local DECK_TOPIC = "deck of Flin cards"

--- @param e loadedEventData
local function loadedCallback(e)
    local result = tes3.addTopic({
        topic = GAME_TOPIC
    })
    log:debug("addTopic %s: %s", GAME_TOPIC, result)

    local result2 = tes3.addTopic({
        topic = DECK_TOPIC
    })
    log:debug("addTopic %s: %s", DECK_TOPIC, result2)
end
event.register(tes3.event.loaded, loadedCallback)
