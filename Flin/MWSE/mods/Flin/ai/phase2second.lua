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

    local preferences = {}

    --[[
during their turn a player must:

1. Head the trick with a higher card of the same suit.
2. If unable to do so, they must discard a lower card of the same suit.
3. If both above are not possible, they must head the trick with a trump.
4. Only if they are unable to do the three above, they can discard a card of their choice.

Following suit (Farbzwang) always takes precedence over winning the trick (Stichzwang)
a player may not play a trump if they can follow suit.
    ]]

    for i, card in ipairs(npcHand) do
        local preference = 0

        -- first we need to find a card that has the same suit and can beat
        if card.suit == trickPCSlot.card.suit and card.value > valueToBeat then
            preference = 100
        end
        log:debug("No card found that can beat the current trick with the same suit")

        -- if that fails we need to find any card with the same suit
        -- and we want to dump the lowest card
        if card.suit == trickPCSlot.card.suit then
            preference = 70 + EValue.Ace - card.value
        end
        log:debug("No card found that has the same suit")

        -- if that also fails then we need to play a trump card
        -- TODO and we want to play the lowest trump card
        if card.suit == trumpSuit then
            preference = 30 + EValue.Ace - card.value
        end
        log:debug("No card found that is a trump card")

        -- we couldn't find anything
        preference = 0

        table.insert(preferences, { card = card, preference = preference })
    end

    return preferences
end

return this
