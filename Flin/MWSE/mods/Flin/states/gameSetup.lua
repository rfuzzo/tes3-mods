local lib = require("Flin.lib")
local log = lib.log

---@class GameSetupState
---@field game FlinGame
---@field gold number
---@field handle mwseSafeObjectHandle
local state = {}

state.setupWarned = false

local SETUP_WARNING_DISTANCE = 200
local SETUP_FORFEIT_DISTANCE = 300

---@param game FlinGame
---@return GameSetupState
function state:new(game, gold, ref)
    ---@type GameSetupState
    local newObj = {
        game = game,
        gold = gold,
        handle = tes3.makeSafeObjectHandle(ref)
    }
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj GameSetupState
    return newObj
end

--- @param e activateEventData
local function SetupActivateCallback(e)
    if e.target and e.target.object.id == lib.FLIN_DECK_ID then
        self.game:startGame(e.target)
        e.claim = true
        return false
    end
end

--- @param e simulateEventData
local function SetupWarningCheck(e)
    -- TODO check cells too

    if self.setupWarned then
        -- calculate the distance between the NPC and the player
        local distance = npcLocation:distance(tes3.player.position)
        if distance > SETUP_FORFEIT_DISTANCE then
            -- warn the player and forfeit the game
            tes3.messageBox("You lose the game")
            -- TODO give npc the pot

            event.unregister(tes3.event.activate, SetupActivateCallback)
            event.unregister(tes3.event.simulate, SetupWarningCheck)

            self.game.cleanup()
        end
    else
        -- calculate the distance between the NPC and the player
        local distance = npcLocation:distance(tes3.player.position)
        if distance > SETUP_WARNING_DISTANCE then
            -- warn the player
            tes3.messageBox("You are too far away to continue the game, you will forfeit if you move further away")
            self.setupWarned = true
        end
    end
end

function state:enterState()
    self.game:cleanup()

    log:info("Setup game with gold: %s", self.gold)
    tes3.messageBox("Place the deck somewhere and and activate it to start the game")

    -- store the NPC location for checks
    self.game.handle = self.handle

    -- store the gold in the pot
    self.game.pot = self.gold * 2
    tes3.removeItem({ reference = tes3.player, item = "Gold_001", count = self.gold })
    tes3.playSound({ sound = "Item Gold Up" })

    event.register(tes3.event.activate, SetupActivateCallback)
    event.register(tes3.event.simulate, SetupWarningCheck)
end

function state.endState()

end

return state
