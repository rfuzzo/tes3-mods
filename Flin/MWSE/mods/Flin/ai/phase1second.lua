local lib = require("Flin.lib")

local EValue = lib.EValue
local log = lib.log

local this = {}

---@param game FlinGame
---@return CardPreference[]
function this.MinMax(game)
    local npcHand = game.npcHand
    local trumpSuit = game.trumpSuit
    local trickPCSlot = game.trickPCSlot

    assert(trickPCSlot, "trickPCSlot is nil")

    local valueToBeat = trickPCSlot.card.value
    local lowValueThreshold = EValue.X

    local preferences = {}

    --TODO try to maximize the value of the won trick

    if valueToBeat < lowValueThreshold then
        for i, card in ipairs(npcHand) do
            local preference = 0

            -- if the current trick is of low value then just dump a low non trump card
            if card.suit ~= trumpSuit and card.value <= valueToBeat then
                preference = 2
            end
            log:debug("No card found to dump")

            -- we couldn't find a low non-trump card to dump so we try to win the trick with the same suit
            if card.suit == trickPCSlot.card.suit and card.value > valueToBeat then
                preference = 1
            end
            log:debug("No card found to win the trick with the same suit")

            -- we couldn't find anything
            preference = 0

            table.insert(preferences, { card = card, preference = preference })
        end
    else
        for i, card in ipairs(npcHand) do
            local preference = 0

            -- if the current trick is of high value then try to win it with a non-trump card of the same suit
            -- TODO the higher the better
            -- 10 + 2,3,4,10,11
            if card.suit ~= trumpSuit and card.suit == trickPCSlot.card.suit and card.value > valueToBeat then
                preference = lowValueThreshold + card.value
            end
            log:debug("No card found to win the trick with the same suit")

            -- now try to win it with a high trump card
            -- TODO the higher the better
            -- 2,3,4,10,11
            if card.suit == trumpSuit then
                preference = card.value
            end
            log:debug("No card found to win the trick with a trump card")

            -- we couldn't find a card to win the trick
            preference = 0

            table.insert(preferences, { card = card, preference = preference })
        end
    end

    return preferences
end

-- TODO more strateges

-- defensive: only win high value tricks

-- aggressive: always try to win the trick

-- smart: try to win the trick with non-trump cards

return this
