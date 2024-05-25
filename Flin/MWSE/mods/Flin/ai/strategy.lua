local lib = require("Flin.lib")

local phase1First = require("Flin.ai.phase1first")
local phase1Second = require("Flin.ai.phase1second")
local phase2First = require("Flin.ai.phase2first")
local phase2Second = require("Flin.ai.phase2second")

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

---@class AiStrategy
---@field phase1First fun(game: FlinGame): CardPreference[]
---@field phase1Second fun(game: FlinGame): CardPreference[]
---@field phase2First fun(game: FlinGame): CardPreference[]
---@field phase2Second fun(game: FlinGame): CardPreference[]
local strategy = {}

-- constructor
--- @param handle mwseSafeObjectHandle
function strategy:new(handle)
    ---@type AiStrategy

    -- TODO depend on npc attributes
    local newObj = {
        phase1First = phase1First.MinMax,
        phase1Second = phase1Second.MinMax,
        phase2First = phase2First.MinMax,
        phase2Second = phase2Second.MinMax
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
            preferences = self.phase2Second(game)
        else
            preferences = self.phase2First(game)
        end
    else
        if npcGoesSecond then
            preferences = self.phase1Second(game)
        else
            preferences = self.phase1First(game)
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
        local randomIndex = math.random(1, n)
        card = preferences[randomIndex].card
    end

    return card
end

return strategy
