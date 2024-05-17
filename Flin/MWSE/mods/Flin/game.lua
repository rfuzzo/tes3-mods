local lib                   = require("Flin.lib")
local log                   = lib.log

local Card                  = require("Flin.card")
local CardSlot              = require("Flin.cardSlot")
local bb                    = require("Flin.blackboard")

local ESuit                 = lib.ESuit
local EValue                = lib.EValue
local GameState             = lib.GameState

-- constants
local GAME_WARNING_DISTANCE = 200
local GAME_FORFEIT_DISTANCE = 300


---@class FlinGame
---@field private currentState GameState
---@field private state AbstractState?
---@field pot number
---@field npcHandle mwseSafeObjectHandle?
---@field talon Card[]
---@field trumpSuit ESuit?
---@field playerHand Card[]
---@field npcHand Card[]
---@field talonSlot CardSlot?
---@field trumpCardSlot CardSlot?
---@field trickPCSlot CardSlot?
---@field trickNPCSlot CardSlot?
---@field private wonCardsPc Card[]
---@field private wonCardsNpc Card[]
local FlinGame = {}

-- constructor
---@param pot number
---@param npcHandle mwseSafeObjectHandle
---@return FlinGame
function FlinGame:new(pot, npcHandle)
    ---@type FlinGame
    local newObj = {
        currentState = GameState.INVALID,
        pot = pot,
        npcHandle = npcHandle,
        playerHand = {},
        npcHand = {},
        talon = {},
        wonCardsNpc = {},
        wonCardsPc = {}
    }
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj FlinGame
    return newObj
end

--#region methods

---@return number
function FlinGame:GetPlayerPoints()
    local points = 0
    for _, card in ipairs(self.wonCardsPc) do
        points = points + card.value
    end
    return points
end

---@return number
function FlinGame:GetNpcPoints()
    local points = 0
    for _, card in ipairs(self.wonCardsNpc) do
        points = points + card.value
    end
    return points
end

function FlinGame:ShuffleTalon()
    for i = #self.talon, 2, -1 do
        local j = math.random(i)
        self.talon[i], self.talon[j] = self.talon[j], self.talon[i]
    end
end

function FlinGame:SetNewTalon()
    local talon = {}

    table.insert(talon, Card:new(ESuit.Hearts, EValue.Unter))
    table.insert(talon, Card:new(ESuit.Hearts, EValue.Ober))
    table.insert(talon, Card:new(ESuit.Hearts, EValue.King))
    table.insert(talon, Card:new(ESuit.Hearts, EValue.X))
    table.insert(talon, Card:new(ESuit.Hearts, EValue.Ace))

    table.insert(talon, Card:new(ESuit.Bells, EValue.Unter))
    table.insert(talon, Card:new(ESuit.Bells, EValue.Ober))
    table.insert(talon, Card:new(ESuit.Bells, EValue.King))
    table.insert(talon, Card:new(ESuit.Bells, EValue.X))
    table.insert(talon, Card:new(ESuit.Bells, EValue.Ace))

    table.insert(talon, Card:new(ESuit.Acorns, EValue.Unter))
    table.insert(talon, Card:new(ESuit.Acorns, EValue.Ober))
    table.insert(talon, Card:new(ESuit.Acorns, EValue.King))
    table.insert(talon, Card:new(ESuit.Acorns, EValue.X))
    table.insert(talon, Card:new(ESuit.Acorns, EValue.Ace))

    table.insert(talon, Card:new(ESuit.Leaves, EValue.Unter))
    table.insert(talon, Card:new(ESuit.Leaves, EValue.Ober))
    table.insert(talon, Card:new(ESuit.Leaves, EValue.King))
    table.insert(talon, Card:new(ESuit.Leaves, EValue.X))
    table.insert(talon, Card:new(ESuit.Leaves, EValue.Ace))

    self.talon = talon
    self:ShuffleTalon()
end

---@return Card?
function FlinGame:talonPop()
    if #self.talon == 0 then
        -- update slot
        local talonSlot = self.talonSlot
        if talonSlot and talonSlot.handle and talonSlot.handle:valid() then
            talonSlot.handle:getObject():delete()
            talonSlot.handle = nil
        end

        return nil
    end

    local card = self.talon[1]
    table.remove(self.talon, 1)
    return card
end

-- TODO move the tricks up and down

---@param card Card
function FlinGame:PcPlayCard(card)
    for i, c in ipairs(self.playerHand) do
        if c == card then
            local result = table.remove(self.playerHand, i)
            self.trickPCSlot:AddCardToSlot(result)

            log:debug("PC plays card: %s", result:toString())

            return
        end
    end
end

---@param card Card
function FlinGame:NpcPlayCard(card)
    self.trickNPCSlot:AddCardToSlot(card)

    log:debug("NPC plays card: %s", card:toString())
end

---@return boolean
function FlinGame:IsTalonEmpty()
    return #self.talon == 0
end

---@return boolean
function FlinGame:IsPhase2()
    return self:IsTalonEmpty() and not self.trumpCardSlot.card
end

---@return tes3reference?
function FlinGame:GetNpcTrickRef()
    -- get the id of the trick activator
    local trickNPCSlot = self.trickNPCSlot
    if trickNPCSlot and trickNPCSlot.handle and trickNPCSlot.handle:valid() then
        return trickNPCSlot.handle:getObject()
    end

    return nil
end

---@return tes3reference?
function FlinGame:GetTrumpCardRef()
    -- get the id of the trump card activator
    local trumpCardSlot = self.trumpCardSlot
    if trumpCardSlot and trumpCardSlot.handle and trumpCardSlot.handle:valid() then
        return trumpCardSlot.handle:getObject()
    end

    return nil
end

---@return tes3reference?
function FlinGame:GetTalonRef()
    -- get the id of the talon activator
    local talonSlot = self.talonSlot
    if talonSlot and talonSlot.handle and talonSlot.handle:valid() then
        return talonSlot.handle:getObject()
    end
    return nil
end

---@param isPlayer boolean
function FlinGame:dealCardTo(isPlayer)
    if isPlayer then
        table.insert(self.playerHand, self:talonPop())
    else
        table.insert(self.npcHand, self:talonPop())
    end
end

function FlinGame:DEBUG_printCards()
    log:trace("============")
    log:trace("player hand:")
    for i, c in ipairs(self.playerHand) do
        log:trace("\t%s", c:toString())
    end
    log:trace("npc hand:")
    for i, c in ipairs(self.npcHand) do
        log:trace("\t%s", c:toString())
    end
    log:trace("talon:")
    for i, c in ipairs(self.talon) do
        log:trace("\t%s", c:toString())
    end
    log:trace("trick pc:")
    if self.trickPCSlot and self.trickPCSlot.card then
        log:trace("\t%s", self.trickPCSlot.card:toString())
    end
    log:trace("trick npc:")
    if self.trickNPCSlot and self.trickNPCSlot.card then
        log:trace("\t%s", self.trickNPCSlot.card:toString())
    end
    log:trace("============")
end

---@return Card?
function FlinGame:drawCard(isPlayer)
    -- only draw a card if the hand is less than 5 cards
    if isPlayer and #self.playerHand >= 5 then
        return nil
    end

    if not isPlayer and #self.npcHand >= 5 then
        return nil
    end

    local card = self:talonPop()

    -- if the talon is empty then the trump card is the last card in the talon
    if not card and self.trumpCardSlot and self.trumpCardSlot.card then
        log:debug("No more cards in the talon")
        tes3.messageBox("No more cards in the talon")
        card = self.trumpCardSlot:RemoveCardFromSlot()
    end

    if not card then
        log:debug("No more cards in the talon")
        return nil
    end

    if isPlayer then
        log:debug("player draws card: %s", card:toString())

        table.insert(self.playerHand, card)
    else
        log:debug("NPC draws card: %s", card:toString())
        table.insert(self.npcHand, card)
    end


    -- sounds for picking up a card
    -- Menu Size
    -- scroll
    -- Item Misc Down

    -- play a sound
    tes3.playSound({
        sound = "Menu Size",
        reference = tes3.player
    })


    return card
end

---@return GameState
function FlinGame:evaluateTrick()
    log:trace("evaluate")

    local trickPCSlot = self.trickPCSlot
    local trickNPCSlot = self.trickNPCSlot
    local trumpSuit = self.trumpSuit

    if not trickPCSlot then
        return GameState.INVALID
    end
    if not trickNPCSlot then
        return GameState.INVALID
    end


    -- Code to evaluate the trick

    -- if the player has played and the NPC has not then it is the NPC's turn
    if trickPCSlot.card and not trickNPCSlot.card then
        log:debug("Player has played a card, NPC has not")
        return GameState.NPC_TURN
    end

    -- if the NPC has played and the player has not then it is the player's turn
    if trickNPCSlot.card and not trickPCSlot.card then
        log:debug("NPC has played a card, player has not")
        return GameState.PLAYER_TURN
    end

    -- evaluate the trick if both players have played a card
    if trickPCSlot.card and trickNPCSlot.card then
        log:debug("Both players have played a card")

        -- the winner of the trick goes next
        -- evaluate the trick
        local playerWins = false
        -- if the player has played a trump card and the NPC has not then the player wins
        if trickPCSlot.card.suit == trumpSuit and trickNPCSlot.card.suit ~= trumpSuit then
            playerWins = true
            -- if the NPC has played a trump card and the player has not then the NPC wins
        elseif trickNPCSlot.card.suit == trumpSuit and trickPCSlot.card.suit ~= trumpSuit then
            playerWins = false
            -- if both players have played a trump card then the higher value wins
        elseif trickPCSlot.card.suit == trumpSuit and trickNPCSlot.card.suit == trumpSuit then
            if trickPCSlot.card.value > trickNPCSlot.card.value then
                playerWins = true
            else
                playerWins = false
            end
            -- if both players have played a card of the same suit then the higher value wins
        elseif trickPCSlot.card.suit == trickNPCSlot.card.suit then
            if trickPCSlot.card.value > trickNPCSlot.card.value then
                playerWins = true
            else
                playerWins = false
            end
        else
            -- the suits don't match so the current player loses as they went last
            if self.currentState == GameState.PLAYER_TURN then
                playerWins = false
            elseif self.currentState == GameState.NPC_TURN then
                playerWins = true
            end
        end


        -- add the value of the trick to the winner's points
        if playerWins then
            log:debug("> Player wins the trick (%s > %s)", trickPCSlot.card:toString(),
                trickNPCSlot.card:toString())
            tes3.messageBox("You won the trick (%s > %s)", trickPCSlot.card:toString(),
                trickNPCSlot.card:toString())

            -- move the cards to the player's won cards
            table.insert(self.wonCardsPc, trickPCSlot:RemoveCardFromSlot())
            table.insert(self.wonCardsPc, trickNPCSlot:RemoveCardFromSlot())
        else
            log:debug("> NPC wins the trick (%s > %s)", trickNPCSlot.card:toString(),
                trickPCSlot.card:toString())
            tes3.messageBox("NPC won the trick (%s > %s)", trickNPCSlot.card:toString(),
                trickPCSlot.card:toString())

            -- move the cards to the NPC's won cards
            table.insert(self.wonCardsNpc, trickPCSlot:RemoveCardFromSlot())
            table.insert(self.wonCardsNpc, trickNPCSlot:RemoveCardFromSlot())
        end


        log:debug("\tPlayer points: %s, NPC points: %s", self:GetPlayerPoints(), self:GetNpcPoints())

        -- check if the game has ended
        if #self.playerHand == 0 and #self.npcHand == 0 then
            return GameState.GAME_END
        end

        -- determine who goes next
        -- sounds
        -- enchant fail
        -- enchant success
        if playerWins then
            -- play a sound
            tes3.playSound({
                sound = "enchant success",
                reference = tes3.player
            })
            return GameState.PLAYER_TURN
        else
            -- play a sound
            tes3.playSound({
                sound = "enchant fail",
                reference = tes3.player
            })
            return GameState.NPC_TURN
        end
    end

    -- if neither player has played a card then the game is in an invalid state
    log:error("Invalid state")
    return GameState.INVALID
end

--#endregion

--#region state machine

-- only certain transitions are allowed
local transitions = {
    [GameState.SETUP] = {
        [GameState.DEAL] = true,
        [GameState.INVALID] = true
    },
    [GameState.DEAL] = {
        [GameState.PLAYER_TURN] = true,
        [GameState.NPC_TURN] = true,
        [GameState.INVALID] = true
    },
    [GameState.PLAYER_TURN] = {
        [GameState.PLAYER_TURN] = true,
        [GameState.NPC_TURN] = true,
        [GameState.GAME_END] = true,
        [GameState.INVALID] = true
    },
    [GameState.NPC_TURN] = {
        [GameState.PLAYER_TURN] = true,
        [GameState.NPC_TURN] = true,
        [GameState.GAME_END] = true,
        [GameState.INVALID] = true
    },
    [GameState.GAME_END] = {
        [GameState.INVALID] = true
    },
    [GameState.INVALID] = {
        [GameState.SETUP] = true
    }
}

---@param nextState GameState
function FlinGame:PushState(nextState)
    log:trace("PushState: %s -> %s", lib.stateToString(self.currentState), lib.stateToString(nextState))

    -- check if the transition is allowed
    if not transitions[self.currentState][nextState] then
        log:error("Invalid state transition: %s -> %s", lib.stateToString(self.currentState),
            lib.stateToString(nextState))
        return
    end

    self:ExitState()
    self:EnterState(nextState)
end

---@private
function FlinGame:ExitState()
    log:trace("ExitState: %s", lib.stateToString(self.currentState))
    if self.state then
        self.state:endState()
    end
end

---@private
---@param state GameState
function FlinGame:EnterState(state)
    log:trace("EnterState: %s", lib.stateToString(state))

    if state == GameState.SETUP then
        local setupState = require("Flin.states.gameSetup")
        self.state = setupState:new(self)
    elseif state == GameState.DEAL then
        local dealState = require("Flin.states.gameDeal")
        self.state = dealState:new(self)
    elseif state == GameState.PLAYER_TURN then
        local playerTurnState = require("Flin.states.playerTurn")
        self.state = playerTurnState:new(self)
    elseif state == GameState.NPC_TURN then
        local npcTurnState = require("Flin.states.npcTurn")
        self.state = npcTurnState:new(self)
    elseif state == GameState.GAME_END then
        local gameEndState = require("Flin.states.gameEnd")
        self.state = gameEndState:new(self)
    elseif state == GameState.INVALID then
        log:error("Invalid state: Cleaning up")
        self:cleanup()
        return
    end

    self.currentState = state
    self.state:enterState()
end

--#endregion

--#region event callbacks

--- this runs during the whole game
--- @param e simulateEventData
local function SimulateCallback(e)
    local game = bb.getInstance():getData("game") ---@type FlinGame

    if not game then
        return
    end

    if not game.talonSlot then
        return
    end

    -- TODO check cells too
    local gameWarned = bb.getInstance():getData("gameWarned")
    if gameWarned then
        -- calculate the distance between the NPC and the player
        local distance = game.talonSlot.position:distance(tes3.player.position)
        if distance > GAME_FORFEIT_DISTANCE then
            -- warn the player and forfeit the game
            tes3.messageBox("You lose the game")
            -- TODO give npc the pot

            game:cleanup()
        end
    else
        -- calculate the distance between the NPC and the player
        local distance = game.talonSlot.position:distance(tes3.player.position)
        if distance > GAME_WARNING_DISTANCE then
            -- warn the player
            tes3.messageBox("You are too far away to continue the game, you will forfeit if you move further away")
            bb.getInstance():setData("gameWarned", true)
        end
    end
end

--#endregion

--- @param deckRef tes3reference
function FlinGame:startGame(deckRef)
    log:info("Starting game")
    tes3.messageBox("The game is on! The pot is %s gold", self.pot)

    -- register event callbacks
    event.register(tes3.event.simulate, SimulateCallback)
    -- add game to blackboard for events
    bb.getInstance():setData("game", self)

    local zOffsetTrump = 1

    -- replace the deck with a facedown deck
    local deckPos = deckRef.position:copy()
    local deckOrientation = deckRef.orientation:copy()

    -- store positions: deck, trump, trickPC, trickNPC
    self.talonSlot = CardSlot:new(deckPos, deckOrientation)
    self.talonSlot.handle = tes3.makeSafeObjectHandle(deckRef)

    -- trick slot is under the talon and rotated
    -- rotate by 90 degrees around the z axis
    local rotation = tes3matrix33.new()
    rotation:fromEulerXYZ(deckOrientation.x, deckOrientation.y, deckOrientation.z)
    rotation = rotation * tes3matrix33.new(
        0, 1, 0,
        -1, 0, 0,
        0, 0, 1
    )
    local trumpOrientation = rotation:toEulerXYZ()
    -- move it a bit along the orientation
    local trumpPosition = deckPos + rotation:transpose() * tes3vector3.new(0, 6, 0)
    self.trumpCardSlot = CardSlot:new(trumpPosition + tes3vector3.new(0, 0, zOffsetTrump), trumpOrientation)

    -- trick slots are off to the side
    local trickOrientation = deckOrientation
    self.trickPCSlot = CardSlot:new(deckPos + tes3vector3.new(0, 10, zOffsetTrump), trickOrientation)

    -- rotate by 45 degrees around the z axis
    -- angle_rad = math.rad(45)
    local rotation2 = tes3matrix33.new()
    rotation2:fromEulerXYZ(trickOrientation.x, trickOrientation.y, trickOrientation.z)
    -- rotate matrix 90 degrees
    rotation2 = rotation2 * tes3matrix33.new(
        0, 1, 0,
        -1, 0, 0,
        0, 0, 1
    )

    self.trickNPCSlot = CardSlot:new(deckPos + tes3vector3.new(0, 10, zOffsetTrump), rotation2:toEulerXYZ())
end

---@param slot CardSlot?
local function CleanupSlot(slot)
    if slot then
        slot:RemoveCardFromSlot()
        slot = nil
    end
end

function FlinGame:cleanup()
    log:trace("Cleaning up")

    self.currentState = GameState.INVALID
    self.pot = 0
    self.talon = {}
    self.trumpSuit = nil
    self.playerHand = {}
    self.npcHand = {}
    self.wonCardsPc = {}
    self.wonCardsNpc = {}

    -- cleanup handles and references
    self.npcHandle = nil

    CleanupSlot(self.talonSlot)
    CleanupSlot(self.trumpCardSlot)
    CleanupSlot(self.trickPCSlot)
    CleanupSlot(self.trickNPCSlot)

    -- remove event callbacks
    event.unregister(tes3.event.simulate, SimulateCallback)
    -- remove game from blackboard
    bb.getInstance():removeData("game")
    bb.getInstance():removeData("setupWarned")
    bb.getInstance():clean()
end

return FlinGame
