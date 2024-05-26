local lib = require("Flin.lib")
local strategy = require("Flin.ai.strategy")

local EValue = lib.EValue
local log = lib.log
local EStrategyPhase = strategy.EStrategyPhase

local this = {}

---@param playerCard Card
---@param card Card
---@return number
local function pointsToGain(playerCard, card)
    return playerCard.value + card.value
end

---@param game FlinGame
---@return CardPreference[]
local function MinMax(game)
    local npcHand = game.npcHand
    local trumpSuit = game.trumpSuit
    local trickPCSlot = game.trickPCSlot

    assert(trickPCSlot, "trickPCSlot is nil")

    local lowValueThreshold = EValue.X
    local valueToBeat = trickPCSlot.card.value

    local preferences = {}

    for i, card in ipairs(npcHand) do
        local preference = 0
        --TODO try to maximize the value of the won trick
        -- local pointsToGain = pointsToGain(trickPCSlot.card, card)

        if valueToBeat < lowValueThreshold then
            -- if the current trick is of low value then just dump a low non trump card
            if card.suit ~= trumpSuit and card.value < lowValueThreshold then
                -- the lower the better
                -- 13 - 2,3,4
                preference = EValue.Ace + 50 - card.value
            elseif
            -- we couldn't find a low non-trump card to dump so we try to win the trick with the same suit
                card.suit == trickPCSlot.card.suit and card.value > valueToBeat then
                -- the lower the better
                -- 13 - 2,3,4,10,11
                preference = EValue.Ace + 50 - card.value
            else
                -- we only have high value cards so we try to minimize loss
                if card.suit ~= trumpSuit then
                    preference = EValue.Ace + EValue.Ace - card.value
                else
                    preference = EValue.Ace - card.value
                end
            end
        else
            -- if the current trick is of high value then try to win it with a non-trump card of the same suit
            -- the higher the better
            -- 10 + 2,3,4,10,11
            if card.suit ~= trumpSuit and card.suit == trickPCSlot.card.suit and card.value > valueToBeat then
                preference = 100 + card.value
            elseif
            -- now try to win it with a trump card
            -- the higher the better
            -- 2,3,4,10,11
                card.suit == trumpSuit then
                preference = 50 + card.value
            else
                -- try to minimize loss
                -- the lower the better
                -- 11 - 2,3,4,10,11
                -- trunp cards are more valuable
                if card.suit ~= trumpSuit then
                    preference = EValue.Ace + EValue.Ace - card.value
                else
                    preference = EValue.Ace - card.value
                end
            end
        end

        table.insert(preferences, { card = card, preference = preference })
    end

    return preferences
end

---@return AiStrategyPhase
function this.MinMaxStrategy()
    ---@type AiStrategyPhase
    local s = {
        phase = EStrategyPhase.PHASE1SECOND,
        name = "MinMax",
        fun = MinMax,
        evaluate = function(handle)
            return 1
        end
    }
    return s
end

-- TODO more strateges

-- defensive: only win high value tricks

-- aggressive: always try to win the trick

-- smart: try to win the trick with non-trump cards

return this
