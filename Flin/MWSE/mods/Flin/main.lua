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

    local game = game.getInstance()
    if game then
        game:load()
    end
end
event.register(tes3.event.loaded, loadedCallback)

-- --- @param e keyDownEventData
-- local function keyDownCallback(e)
--     if e.isAltDown then
--         if e.keyCode == tes3.scanCode["o"] then
--             local t = lib.getLookedAtReference()
--             if t then
--                 local refBelow = lib.FindRefBelow(t)
--                 if refBelow then
--                     local position = lib.findPlayerPosition(refBelow)
--                     lib.DEBUG_ShowMarkerAt(position)
--                 end
--             end
--         end
--     end
-- end
-- event.register(tes3.event.keyDown, keyDownCallback)


-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("Flin.mcm")
