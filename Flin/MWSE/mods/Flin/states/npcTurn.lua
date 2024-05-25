local lib = require("Flin.lib")
local log = lib.log

local EValue = lib.EValue
local AbstractState = require("Flin.states.abstractState")

---@class NpcTurnState: AbstractState
---@field game FlinGame
local state = {}
setmetatable(state, { __index = AbstractState })

---@param game FlinGame
---@return NpcTurnState
function state:new(game)
    ---@type NpcTurnState
    local newObj = {
        game = game
    }
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj NpcTurnState
    return newObj
end

--#region AI logic


---@param game FlinGame
---@return Card
local function chooseNpcCardPhase1(game)
    local trickPCSlot = game.trickPCSlot
    local trumpSuit = game.trumpSuit
    local npcHand = game.npcHand

    -- make it depend on if the NPC goes first or second
    if trickPCSlot and trickPCSlot.card then
        -- if the NPC goes second
        local valueToBeat = trickPCSlot.card.value


        if valueToBeat <= EValue.King then
            -- if the current trick is of low value then just dump a low non trump card
            for i, card in ipairs(npcHand) do
                if card.suit ~= trumpSuit and card.value <= valueToBeat then
                    return table.remove(npcHand, i)
                end
            end
            log:debug("No card found to dump")

            -- we couldn't find a low non-trump card to dump so we try to win the trick with the same suit
            for i, card in ipairs(npcHand) do
                if card.suit == trickPCSlot.card.suit and card.value > valueToBeat then
                    return table.remove(npcHand, i)
                end
            end
            log:debug("No card found to win the trick with the same suit")
        else
            -- if the current trick is of high value then try to win it with a non-trump card of the same suit
            for i, card in ipairs(npcHand) do
                if card.suit ~= trumpSuit and card.suit == trickPCSlot.card.suit and card.value > valueToBeat then
                    return table.remove(npcHand, i)
                end
            end
            log:debug("No card found to win the trick with the same suit")

            -- now try to win it with a high trump card
            for i, card in ipairs(npcHand) do
                if card.suit == trumpSuit and card.value > EValue.King then
                    return table.remove(npcHand, i)
                end
            end
            log:debug("No card found to win the trick with a trump card")

            -- now try to win it with any trump card
            for i, card in ipairs(npcHand) do
                if card.suit == trumpSuit then
                    return table.remove(npcHand, i)
                end
            end
            log:debug("No card found to win the trick with any trump card")

            -- we couldn't find a card to win the trick
        end
    else
        -- if we go first
        local marriageKing = game:CanDoMarriage(false)
        if marriageKing then
            log:debug("NPC calls marriage")


            -- add points
            local isRoyalMarriage = marriageKing.suit == game.trumpSuit
            local points = 20
            if isRoyalMarriage then
                points = 40
                tes3.messageBox("NPC calls a royal marriage")
            else
                tes3.messageBox("NPC calls a marriage")
            end
            game:AddPoints(points, false)

            -- return card
            for i, card in ipairs(npcHand) do
                if card == marriageKing then
                    return table.remove(npcHand, i)
                end
            end

            log:error("Marriage card not found")
        end

        -- if we have a high trump card then play it and try to win the trick
        for i, card in ipairs(npcHand) do
            if card.suit == trumpSuit and card.value > EValue.King then
                return table.remove(npcHand, i)
            end
        end
        log:debug("No high trump card found")

        -- we don't have a high trump card so try to dump a low non-trump card
        for i, card in ipairs(npcHand) do
            if card.suit ~= trumpSuit and card.value <= EValue.King then
                return table.remove(npcHand, i)
            end
        end
        log:debug("No low non-trump card found")

        -- we couldn't find a low non-trump card to dump
    end

    -- if no card was found then just play a random card
    log:debug("nothing found, playing random card")
    local idx = math.random(#npcHand)
    return table.remove(npcHand, idx)
end

---@return Card
---@param game FlinGame
local function chooseNpcCardPhase2(game)
    -- "Farb und Stichzwang"

    local trickPCSlot = game.trickPCSlot
    local trumpSuit = game.trumpSuit
    local npcHand = game.npcHand

    -- make it depend on if the NPC goes first or second
    if trickPCSlot and trickPCSlot.card then
        -- if the NPC goes second
        local valueToBeat = trickPCSlot.card.value

        -- first we need to find a card that has the same suit and can beat
        for i, card in ipairs(npcHand) do
            if card.suit == trickPCSlot.card.suit and card.value > valueToBeat then
                return table.remove(npcHand, i)
            end
        end
        log:debug("No card found that can beat the current trick with the same suit")

        -- if that fails we need to find any card with the same suit and we want to dump the lowest card
        local lowestCard = nil
        for i, card in ipairs(npcHand) do
            if card.suit == trickPCSlot.card.suit then
                if not lowestCard or card.value < lowestCard.value then
                    lowestCard = card
                end
            end
        end
        -- if we found a card with the same suit then play it
        if lowestCard then
            -- find the index of the card
            for i, card in ipairs(npcHand) do
                if card == lowestCard then
                    return table.remove(npcHand, i)
                end
            end
        end
        log:debug("No card found that has the same suit")

        -- if that also fails then we need to play a trump card and we want to play the lowest trump card
        local lowestTrumpCard = nil
        for i, card in ipairs(npcHand) do
            if card.suit == trumpSuit then
                if not lowestTrumpCard or card.value < lowestTrumpCard.value then
                    lowestTrumpCard = card
                end
            end
        end
        -- if we found a trump card then play it
        if lowestTrumpCard then
            -- find the index of the card
            for i, card in ipairs(npcHand) do
                if card == lowestTrumpCard then
                    return table.remove(npcHand, i)
                end
            end
        end
        log:debug("No card found that is a trump card")
    else
        -- if we go first
        -- TODO here the strategy depends on how much you know about the other players hand
        log:debug("NPC goes first in phase 2")
    end

    log:debug("nothing found, playing random card")
    -- if no card was found then just play a random card
    local idx = math.random(#npcHand)
    return table.remove(npcHand, idx)
end

---@return Card
local function chooseNpcCardToPlay(game)
    if game:IsPhase2() then
        return chooseNpcCardPhase2(game)
    else
        return chooseNpcCardPhase1(game)
    end
end

--#endregion

-- prevent saving while travelling
--- @param e saveEventData
local function saveCallback(e)
    tes3.messageBox("You cannot save the game during the NPCs turn")
    return false
end

function state:enterState()
    log:debug("OnEnter: NpcTurnState")

    event.register(tes3.event.save, saveCallback)

    local game = self.game

    -- exchange trump card if needed
    if game:GetTrumpCardRef() and game:CanExchangeTrumpCard(false) then
        game:ExchangeTrumpCard(false)
    end

    local card = chooseNpcCardToPlay(game)
    game:NpcPlayCard(card)

    -- wait before updating
    timer.start({
        duration = 1,
        callback = function()
            local nextState = game:evaluateTrick()

            if game:GetNpcPoints() >= 66 then
                log:debug("NPC calls the game")
                tes3.messageBox("NPC calls the game")

                game:PushState(lib.GameState.GAME_END)
            else
                if nextState == lib.GameState.NPC_TURN then
                    timer.start({
                        duration = 1,
                        callback = function()
                            game:PushState(nextState)
                        end
                    })
                else
                    game:PushState(nextState)
                end
            end
        end
    })
end

function state:endState()
    log:debug("OnExit: NpcTurnState")

    -- only draw a card if both players have played a card
    if self.game.trickNPCSlot and not self.game.trickNPCSlot.card and
        self.game.trickPCSlot and not self.game.trickPCSlot.card then
        self.game:drawCard(false)
    end

    event.unregister(tes3.event.save, saveCallback)
end

return state
