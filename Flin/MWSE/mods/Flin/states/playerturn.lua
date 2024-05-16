local lib = require("Flin.lib")
local log = lib.log

---@class PlayerTurnState
---@field game FlinGame
local state = {

}

---@param game FlinGame
---@return PlayerTurnState
function state:new(game)
    ---@type PlayerTurnState
    local newObj = {
        game = game
    }
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj PlayerTurnState
    return newObj
end

function state.enterState()

end

function state.endState()

end

---@param card Card
local function PcPlayCard(card)
    for i, c in ipairs(playerHand) do
        if c == card then
            local result = table.remove(playerHand, i)
            AddCardToSlot(trickPCSlot, result)

            log:debug("PC plays card: %s", cardToString(result))
            -- tes3.messageBox("You play: %s", cardToString(result))

            return
        end
    end
end

local function getHeaderText()
    return string.format("Choose a card to play (Trump is %s)", suitToString(trumpSuit))
end

local function getMessageText()
    local trick = ""
    if trickNPCSlot and trickNPCSlot.card then
        trick = string.format("Trick: %s", cardToString(trickNPCSlot.card))
    end

    return string.format(
        "Player's turn (you have %s points, NPC has %s points).\n%s",
        GetPlayerPoints(),
        GetNpcPoints(), trick)
end

local function choosePcCardToPlay()
    local buttons = {}
    for i, card in ipairs(playerHand) do
        local buttonText = string.format("%s %s", suitToString(card.suit), valueToString(card.value))
        table.insert(
            buttons,
            {
                text = buttonText,
                callback = function()
                    this.PcPlayCard(card)
                    this.determineNextState()

                    -- wait one second before updating
                    timer.start({
                        duration = 1,
                        callback = function()
                            this.update()
                        end
                    })
                end
            })
    end

    -- add custom block to call game
    tes3ui.showMessageMenu({
        header = getHeaderText(),
        message = getMessageText(),
        buttons = buttons,
        cancels = true,
        cancelCallback = function()
            playerJustHitTrick = false
        end,
        customBlock = function(parent)
            -- only show if player has >= 66 points
            if GetPlayerPoints() < 66 then
                return
            end

            parent.childAlignX = 0.5
            parent.paddingAllSides = 8

            local callButton = parent:createButton({
                text = "Call the game",
                id = tes3ui.registerID("flin:callGame")
            })
            callButton:register("mouseClick", function()
                log:debug("Player calls the game")
                tes3ui.leaveMenuMode()
                parent:destroy()

                currentState = GameState.GAME_END
                this.update()
            end)
        end,
    })
end

function state:playerDrawCard()
    -- Code for the player's turn
    -- draw a card
    if not self.game:drawCard(true) then
        log:debug("Player cannot draw a card")
        tes3.messageBox("You cannot draw another card")
    else
        playerDrewCard = true
    end
end

function state:playerHitTrick()
    log:debug("> Player turn")

    -- hacks for first turn and phase 2 turns
    if self.game:IsTalonEmpty() and self.game.trumpCardSlot and not self.game.trumpCardSlot.card then
        playerDrewCard = true
    end

    -- if the player has not drawn a card then they cannot hit the trick
    if not playerDrewCard then
        log:debug("Player cannot hit the trick, they must draw a card first")
        tes3.messageBox("You must draw a card first")
        playerJustHitTrick = false
        return
    end

    -- get the card the player wants to play
    choosePcCardToPlay()
end

return state
