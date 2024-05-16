local lib = require("Flin.lib")
local log = lib.log

---@class NpcTurnState
---@field game FlinGame
local state = {

}

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

-- AI logic

---@return Card
local function chooseNpcCardPhase1()
    -- make it depend on if the NPC goes first or second
    if trickPCSlot and trickPCSlot.card then
        -- if the NPC goes second

        -- if the current trick is of low value then just dump a low non trump card
        if trickPCSlot.card.value <= EValue.King then
            for i, card in ipairs(npcHand) do
                if card.suit ~= trumpSuit and card.value <= EValue.King then
                    return table.remove(npcHand, i)
                end
            end

            -- we couldn't find a low non-trump card to dump
        end

        -- if the current trick is of high value then try to win it with a non-trump card of the same suit
        if trickPCSlot.card.value > EValue.King then
            for i, card in ipairs(npcHand) do
                if card.suit ~= trumpSuit and card.suit == trickPCSlot.card.suit then
                    return table.remove(npcHand, i)
                end
            end

            -- now try to win it with a high trump card
            for i, card in ipairs(npcHand) do
                if card.suit == trumpSuit and card.value > EValue.King then
                    return table.remove(npcHand, i)
                end
            end

            -- now try to win it with any trump card
            for i, card in ipairs(npcHand) do
                if card.suit == trumpSuit then
                    return table.remove(npcHand, i)
                end
            end

            -- we couldn't find a card to win the trick
        end
    else
        -- if we go first
        -- if we have a high trump card then play it and try to win the trick
        for i, card in ipairs(npcHand) do
            if card.suit == trumpSuit and card.value > EValue.King then
                return table.remove(npcHand, i)
            end
        end

        -- we don't have a high trump card so try to dump a low non-trump card
        for i, card in ipairs(npcHand) do
            if card.suit ~= trumpSuit and card.value <= EValue.King then
                return table.remove(npcHand, i)
            end
        end

        -- we couldn't find a low non-trump card to dump
    end

    -- if no card was found then just play a random card
    local idx = math.random(#npcHand)
    return table.remove(npcHand, idx)
end

---@return Card
local function chooseNpcCardPhase2()
    -- TODO implement phase 2
    return chooseNpcCardPhase1()
end

---@return Card
function state:chooseNpcCardToPlay()
    if self.game:IsTalonEmpty() then
        return chooseNpcCardPhase2()
    else
        return chooseNpcCardPhase1()
    end
end

function state:enterState()
    log:debug("NPC turn")

    self.game:drawCard(false)

    local card = self:chooseNpcCardToPlay()
    trickNPCSlot:AddCardToSlot(card)

    log:debug("NPC plays card: %s", lib.cardToString(card))
    -- tes3.messageBox("NPC plays: %s", cardToString(card))

    -- npc went last
    if trickPCSlot and trickNPCSlot and trickPCSlot.card and trickNPCSlot.card then
        -- if the npc went last, they can call the game if they think they have more than 66 points
        if self.game:GetNpcPoints() >= 66 then
            log:debug("NPC calls the game")
            tes3.messageBox("NPC calls the game")
            self.game.currentState = lib.GameState.GAME_END
        end
    end
end

function state.endState()

end

return state
