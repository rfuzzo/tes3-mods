---@meta

local lib = require("Flin.lib")

-- card class
--- @class Card
--- @field value EValue?
--- @field suit ESuit?
local Card = {
    value = nil,
    suit = nil
}

---@return string
function Card:toString()
    return string.format("%s %s",
        lib.suitToString(self.suit),
        lib.valueToString(self.value)
    )
end

---@param suit ESuit
---@param value EValue
---@return Card
function Card.new(suit, value)
    local card = {
        suit = suit,
        value = value
    } ---@type Card
    return card
end
