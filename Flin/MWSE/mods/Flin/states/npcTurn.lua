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

function state:enterState()
    log:trace("OnEnter: NpcTurnState")

    local game = self.game

    local quipProbability = 0.3
    local esound = lib.ESound.TURN_START_NEUTRAL

    -- exchange trump card if needed
    if game:GetTrumpCardRef() and game:CanExchangeTrumpCard(false) then
        game:ExchangeTrumpCard(false)
        quipProbability = 0.5
        esound = lib.ESound.TURN_START_HAPPY
    end

    -- if we go first
    local marriageKing = game:CanDoMarriage(false)
    if marriageKing then
        esound = lib.ESound.TURN_START_HAPPY
        -- add points
        local isRoyalMarriage = marriageKing.suit == game.trumpSuit
        local points = 20
        if isRoyalMarriage then
            quipProbability = 1
            points = 40
            log:debug("NPC calls a royal marriage")
            tes3.messageBox("NPC calls a royal marriage")
        else
            quipProbability = 0.75
            log:debug("NPC calls a marriage")
            tes3.messageBox("NPC calls a marriage")
        end
        game:AddPoints(points, false)

        -- return card
        for i, card in ipairs(game.npcHand) do
            if card == marriageKing then
                game:NpcPlayCard(card)
                break
            end
        end
    else
        local card = game.npcData.npcStrategy:choose(game)
        game:NpcPlayCard(card)
    end

    if game:IsPhase2() and not game.npcData.hasQuippedPhase2 then
        esound = lib.ESound.MIDDLE_NEUTRAL
        -- depends on points
        if game:GetNpcPoints() >= 40 then
            esound = lib.ESound.MIDDLE_HAPPY
        elseif game:GetNpcPoints() < 20 then
            esound = lib.ESound.MIDDLE_SAD
        end

        game.npcData.hasQuippedPhase2 = true
        quipProbability = 1
    end

    -- quip
    if math.random() < quipProbability then
        lib.quip(game.npcData.npcHandle:getObject(), esound)
    end

    -- wait before updating
    timer.start({
        duration = 1,
        callback = function()
            local nextState = game:evaluateTrick()

            if game:GetNpcPoints() >= 66 then
                log:debug("NPC calls the game")
                tes3.messageBox("NPC calls the game")

                game:PushState(lib.GameState.GAME_END)
            else
                if nextState == lib.GameState.NPC_TURN then
                    timer.start({
                        duration = 1,
                        callback = function()
                            game:PushState(nextState)
                        end
                    })
                else
                    game:PushState(nextState)
                end
            end
        end
    })
end

function state:endState()
    log:trace("OnExit: NpcTurnState")

    -- only draw a card if both players have played a card
    if self.game.trickNPCSlot and not self.game.trickNPCSlot.card and
        self.game.trickPCSlot and not self.game.trickPCSlot.card then
        self.game:drawCard(false)
    end
end

return state
