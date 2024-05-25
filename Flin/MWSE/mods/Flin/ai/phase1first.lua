local lib = require("Flin.lib")

local EValue = lib.EValue
local log = lib.log

local this = {}

---@param game FlinGame
---@return CardPreference[]
function this.MinMax(game)
    local npcHand = game.npcHand
    local trumpSuit = game.trumpSuit

    local preferences = {} ---@type CardPreference[]
    for i, card in ipairs(npcHand) do
        local preference = 0

        -- if we have a high trump card then play it and try to win the trick
        if card.suit == trumpSuit then
            -- my confidence is higher the higher the card is
            -- 2,3,4,10,11
            -- 2,3,4,10,11
            preference = card.value
        else
            -- we don't have a high trump card so try to dump a low non-trump card
            -- my confidence is higher the lower the card is
            -- 2,3,4,10,11
            -- 15,14,13,7,6
            preference = 17 - card.value
        end

        table.insert(preferences, { card = card, preference = preference })
    end

    return preferences
end

-- TODO more strategies

-- defensive: try to dump low non-trump cards always

-- aggressive: try to always play high trump cards

-- smart: know how many trump cards there are

return this
