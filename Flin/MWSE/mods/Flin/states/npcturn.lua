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
    local trickNPCSlot = game.trickNPCSlot
    local trumpSuit = game.trumpSuit
    local npcHand = game.npcHand

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
---@param game FlinGame
local function chooseNpcCardPhase2(game)
    -- TODO implement phase 2
    return chooseNpcCardPhase1(game)
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

function state:enterState()
    log:debug("OnEnter: NpcTurnState")

    local game = self.game

    game:drawCard(false)

    local card = chooseNpcCardToPlay(game)
    game:NpcPlayCard(card)

    log:debug("NPC plays card: %s", card:toString())
    -- tes3.messageBox("NPC plays: %s", card:toString())

    -- npc went last
    if game.trickPCSlot and game.trickNPCSlot and game.trickPCSlot.card and game.trickNPCSlot.card then
        -- if the npc went last, they can call the game if they think they have more than 66 points
        if game:GetNpcPoints() >= 66 then
            log:debug("NPC calls the game")
            tes3.messageBox("NPC calls the game")

            self.game:PushState(lib.GameState.GAME_END)
            return
        end
    end

    -- wait one second before updating
    timer.start({
        duration = 1,
        callback = function()
            local nextState = game:evaluateTrick()
            game:PushState(nextState)
        end
    })
end

function state:endState()

end

return state
