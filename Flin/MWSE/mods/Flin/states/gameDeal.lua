local lib = require("Flin.lib")
local log = lib.log

---@class GameDealState
---@field game FlinGame
local state = {

}

---@param game FlinGame
---@return GameDealState
function state:new(game)
    ---@type GameDealState
    local newObj = {
        game = game
    }
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj GameDealState
    return newObj
end

function state:enterState()
    log:trace("Dealing cards")

    -- Code to deal cards to players
    -- first init the talon
    self.game:SetNewTalon()

    -- deal 3 cards to each player, remove them from the talon
    for i = 1, 3 do
        self.game:dealCardTo(true)
        self.game:dealCardTo(false)
    end

    -- the trump card is the next card in the talon
    local trumpCard = self.game:talonPop()
    if not trumpCard then
        log:error("No trump card")
        self.game.currentState = lib.GameState.INVALID
        return
    end
    trumpCardSlot:AddCardToSlot(trumpCard)
    -- save the trump suit
    self.game.trumpSuit = trumpCard.suit
    log:debug("Trump suit: %s", lib.suitToString(self.game.trumpSuit))
    -- tes3.messageBox("Trump suit: %s", suitToString(trumpSuit))

    -- deal the rest of the cards to the players
    -- 2 cards to the player, 2 cards to the npc
    for i = 1, 2 do
        self.game:dealCardTo(true)
        self.game:dealCardTo(false)
    end
end

function state.endState()

end

return state
