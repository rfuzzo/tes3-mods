local lib = require("Flin.lib")
local interop = require("Flin.interop")

-- a strategy for the NPC to play a card in the Flin game
-- a strategy consists of four parts:
-- 1. during phase 1, if the NPC goes first
-- 2. during phase 1, if the NPC goes second
-- 3. during phase 2, if the NPC goes first
-- 4. during phase 2, if the NPC goes second
-- the stragy has four functions, one for each part
-- each function takes the game object as an argument
-- and returns a table of preferences for the cards in the NPC's hand
-- the table is a list of tables, each table has the following keys:
-- - card: the card object
-- - preference: a number representing how much the NPC wants to play this card
-- the higher the number, the more the NPC wants to play the card

---@class CardPreference
---@field card Card
---@field preference number

---@class AiStrategyPhase
---@field phase EStrategyPhase
---@field name string
---@field fun fun(game: FlinGame): CardPreference[]
---@field evaluate fun(handle: mwseSafeObjectHandle): number

---@class FlinNpcAi
---@field phase1First AiStrategyPhase
---@field phase1Second AiStrategyPhase
---@field phase2First AiStrategyPhase
---@field phase2Second AiStrategyPhase
local strategy = {}

---@enum EStrategyPhase
strategy.EStrategyPhase = {
    PHASE1FIRST = 1,
    PHASE1SECOND = 2,
    PHASE2FIRST = 3,
    PHASE2SECOND = 4,
}

-- constructor
--- @param handle mwseSafeObjectHandle
function strategy:new(handle)
    ---@type FlinNpcAi
    local newObj = {
        phase1First = interop.chooseStrategy(strategy.EStrategyPhase.PHASE1FIRST, handle),
        phase1Second = interop.chooseStrategy(strategy.EStrategyPhase.PHASE1SECOND, handle),
        phase2First = interop.chooseStrategy(strategy.EStrategyPhase.PHASE2FIRST, handle),
        phase2Second = interop.chooseStrategy(strategy.EStrategyPhase.PHASE2SECOND, handle)
    }

    setmetatable(newObj, self)
    self.__index = self
    return newObj
end

--- choose a card to play
---@param game FlinGame
---@return Card
function strategy:choose(game)
    local trickPCSlot = game.trickPCSlot
    local npcGoesSecond = trickPCSlot and trickPCSlot.card

    local preferences = nil
    if game:IsPhase2() then
        if npcGoesSecond then
            preferences = self.phase2Second.fun(game)
        else
            preferences = self.phase2First.fun(game)
        end
    else
        if npcGoesSecond then
            preferences = self.phase1Second.fun(game)
        else
            preferences = self.phase1First.fun(game)
        end
    end

    local card = self:evaluate(preferences, game)
    return card
end

--- evaluate the preferences and choose the best card
---@param preferences CardPreference[]
---@param game FlinGame
---@return Card
function strategy:evaluate(preferences, game)
    local card = nil
    local maxPreference = -1

    -- find the card with the highest preference
    -- in phase 2 when the NPC goes 2nd we need to be strict
    -- TODO cheating
    local trickPCSlot = game.trickPCSlot
    local npcGoesSecond = trickPCSlot and trickPCSlot.card
    if game:IsPhase2() and npcGoesSecond then
        for _, pref in ipairs(preferences) do
            if pref.preference > maxPreference then
                card = pref.card
                maxPreference = pref.preference
            end
        end
    else
        -- sort the preferences by preference
        table.sort(preferences, function(a, b) return a.preference > b.preference end)
        -- choose a card at random from the highest N cards
        -- TODO depend on npc attributes
        -- we have Inteligence, Willpower(, Luck, Personality)
        -- n can be between 1 and 5 (1 is best, always choose the best card)
        local n = 3
        local randomIndex = math.random(n)
        card = preferences[randomIndex].card

        -- log the preferences
        for i, pref in ipairs(preferences) do
            lib.log:debug("Card %s: preference %s", pref.card:toString(), pref.preference)
        end
        lib.log:debug("Chose card index %s", randomIndex)
    end

    return card
end

return strategy
