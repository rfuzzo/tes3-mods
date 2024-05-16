local lib = require("Flin.lib")
local log = lib.log

---@class GameEndState
---@field game FlinGame
local state = {

}

---@param game FlinGame
---@return GameEndState
function state:new(game)
    ---@type GameEndState
    local newObj = {
        game = game
    }
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj GameEndState
    return newObj
end

function state.enterState()

end

function state:endState()
    -- Code for ending the game
    log:debug("Game ended")

    -- calculate the points
    local playerPoints = self.game:GetPlayerPoints()
    local npcPoints = self.game:GetNpcPoints()

    log:debug("Player points: %s, NPC points: %s", playerPoints, npcPoints)
    log:debug("Pot: %s", self.game.pot)

    -- determine the winner
    if playerPoints >= 66 then
        log:debug("Player wins")
        tes3.messageBox("You won the game and the pot of %s gold", self.game.pot)

        -- give the player the pot
        tes3.addItem({ reference = tes3.player, item = "Gold_001", count = self.game.pot })
        tes3.playSound({ sound = "Item Gold Up" })
    elseif npcPoints >= 66 then
        log:debug("NPC wins")
        tes3.messageBox("You lose!")

        -- TODO give npc the pot
    else
        log:debug("It's a draw")
        tes3.messageBox("It's a draw!")

        -- give the player half the pot
        tes3.addItem({ reference = tes3.player, item = "Gold_001", count = math.floor(self.game.pot / 2) })
        tes3.playSound({ sound = "Item Gold Up" })
    end

    -- cleanup
    self.game:cleanup()
end

return state
