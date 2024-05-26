local lib = require("Flin.lib")
local strategy = require("Flin.ai.strategy")

local EValue = lib.EValue
local log = lib.log
local EStrategyPhase = strategy.EStrategyPhase

local this = {}

---@param game FlinGame
---@return CardPreference[]
local function MinMax(game)
    local npcHand = game.npcHand
    local trumpSuit = game.trumpSuit
    local trickPCSlot = game.trickPCSlot

    local preferences = {}
    for i, card in ipairs(npcHand) do
        local preference = 0

        --TODO here everything depends on how much the npc knows
        -- about the player hand
        -- and the already played cards

        -- I win the trick only if
        -- 1. I know the player has only a lower card of the same suit
        -- 2. I know the player has no card of the same suit and no trump card


        table.insert(preferences, { card = card, preference = preference })
    end

    return preferences
end

---@return AiStrategyPhase
function this.MinMaxStrategy()
    ---@type AiStrategyPhase
    local s = {
        phase = EStrategyPhase.PHASE2FIRST,
        name = "MinMax",
        fun = MinMax,
        evaluate = function(handle)
            return 1
        end
    }
    return s
end

return this
