local lib                   = require("Flin.lib")
local log                   = lib.log

local CardSlot              = require("Flin.cardSlot")
local Card                  = require("Flin.card")

local ESuit                 = lib.ESuit
local EValue                = lib.EValue
local GameState             = lib.GameState

-- constants
local GAME_WARNING_DISTANCE = 200
local GAME_FORFEIT_DISTANCE = 300


---@class FlinGame
---@field currentState GameState
---@field pot number
---@field handle mwseSafeObjectHandle?
---@field talon Card[]
---@field trumpSuit ESuit?
---@field playerHand Card[]
---@field npcHand Card[]
---@field talonSlot CardSlot?
---@field trumpCardSlot CardSlot?
---@field trickPCSlot CardSlot?
---@field trickNPCSlot CardSlot?
---@field wonCardsPc Card[]
---@field wonCardsNpc Card[]
local FlinGame = {}


-- temp
local playerDrewCard     = false
local firstTurn          = false
local playerJustHitTrick = false
local callbacklock       = false
local setupWarned        = false
local gameWarned         = false

---@param id string
---@return boolean
function FlinGame:IsNpcTrick(id)
    -- get the id of the trick activator
    local trickNPCSlot = self.trickNPCSlot
    if trickNPCSlot and trickNPCSlot.handle and trickNPCSlot.handle:valid() then
        if trickNPCSlot.handle:getObject().id == id then
            return true
        end
    end

    return false
end

---@param id string
---@return boolean
function FlinGame:IsTrumpCard(id)
    -- get the id of the trump card activator
    local trumpCardSlot = self.trumpCardSlot
    if trumpCardSlot and trumpCardSlot.handle and trumpCardSlot.handle:valid() then
        if trumpCardSlot.handle:getObject().id == id then
            return true
        end
    end

    return false
end

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

function FlinGame:ShuffleDeck()
    for i = #self.talon, 2, -1 do
        local j = math.random(i)
        self.talon[i], self.talon[j] = self.talon[j], self.talon[i]
    end
end

function FlinGame:SetNewTalon()
    local talon = {}

    table.insert(talon, Card.new(ESuit.Hearts, EValue.Unter))
    table.insert(talon, Card.new(ESuit.Hearts, EValue.Ober))
    table.insert(talon, Card.new(ESuit.Hearts, EValue.King))
    table.insert(talon, Card.new(ESuit.Hearts, EValue.X))
    table.insert(talon, Card.new(ESuit.Hearts, EValue.Ace))

    table.insert(talon, Card.new(ESuit.Bells, EValue.Unter))
    table.insert(talon, Card.new(ESuit.Bells, EValue.Ober))
    table.insert(talon, Card.new(ESuit.Bells, EValue.King))
    table.insert(talon, Card.new(ESuit.Bells, EValue.X))
    table.insert(talon, Card.new(ESuit.Bells, EValue.Ace))

    table.insert(talon, Card.new(ESuit.Acorns, EValue.Unter))
    table.insert(talon, Card.new(ESuit.Acorns, EValue.Ober))
    table.insert(talon, Card.new(ESuit.Acorns, EValue.King))
    table.insert(talon, Card.new(ESuit.Acorns, EValue.X))
    table.insert(talon, Card.new(ESuit.Acorns, EValue.Ace))

    table.insert(talon, Card.new(ESuit.Leaves, EValue.Unter))
    table.insert(talon, Card.new(ESuit.Leaves, EValue.Ober))
    table.insert(talon, Card.new(ESuit.Leaves, EValue.King))
    table.insert(talon, Card.new(ESuit.Leaves, EValue.X))
    table.insert(talon, Card.new(ESuit.Leaves, EValue.Ace))

    self.talon = talon
    self:ShuffleDeck()
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

---@return boolean
function FlinGame:IsTalonEmpty()
    return #self.talon == 0 and not self.trumpCardSlot.card
end

---@param isPlayer boolean
function FlinGame:dealCardTo(isPlayer)
    if isPlayer then
        table.insert(self.playerHand, self:talonPop())
    else
        table.insert(self.npcHand, self:talonPop())
    end
end

---@return boolean
function FlinGame:drawCard(isPlayer)
    -- log:trace("============")
    -- log:trace("player hand:")
    -- for i, c in ipairs(playerHand) do
    --     log:trace("\t%s", cardToString(c))
    -- end
    -- log:trace("npc hand:")
    -- for i, c in ipairs(npcHand) do
    --     log:trace("\t%s", cardToString(c))
    -- end
    -- log:trace("talon:")
    -- for i, c in ipairs(talon) do
    --     log:trace("\t%s", cardToString(c))
    -- end
    -- log:trace("trick pc:")
    -- if trickPCSlot and trickPCSlot.card then
    --     log:trace("\t%s", cardToString(trickPCSlot.card))
    -- end
    -- log:trace("trick npc:")
    -- if trickNPCSlot and trickNPCSlot.card then
    --     log:trace("\t%s", cardToString(trickNPCSlot.card))
    -- end
    -- log:trace("============")

    -- only draw a card if the hand is less than 5 cards
    if isPlayer and #self.playerHand >= 5 then
        return false
    end

    if not isPlayer and #self.npcHand >= 5 then
        return false
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
        return false
    end

    if isPlayer then
        log:debug("player draws card: %s", lib.cardToString(card))
        tes3.messageBox("You draw: %s", lib.cardToString(card))

        table.insert(self.playerHand, card)
    else
        log:debug("NPC draws card: %s", lib.cardToString(card))
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


    return true
end

---@return GameState
local function evaluate()
    log:trace("evaluate")

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
            if currentState == GameState.PLAYER_TURN then
                playerWins = false
            elseif currentState == GameState.NPC_TURN then
                playerWins = true
            end
        end


        -- add the value of the trick to the winner's points
        local valueOfTrick = trickPCSlot.card.value + trickNPCSlot.card.value
        if playerWins then
            log:debug("> Player wins the trick (%s > %s)", cardToString(trickPCSlot.card),
                cardToString(trickNPCSlot.card))
            tes3.messageBox("You won the trick (%s > %s)", cardToString(trickPCSlot.card),
                cardToString(trickNPCSlot.card))

            -- move the cards to the player's won cards
            table.insert(wonCardsPc, RemoveCardFromSlot(trickPCSlot))
            table.insert(wonCardsPc, RemoveCardFromSlot(trickNPCSlot))
        else
            log:debug("> NPC wins the trick (%s > %s)", cardToString(trickNPCSlot.card), cardToString(trickPCSlot.card))
            tes3.messageBox("NPC won the trick (%s > %s)", cardToString(trickNPCSlot.card),
                cardToString(trickPCSlot.card))

            -- move the cards to the NPC's won cards
            table.insert(wonCardsNpc, RemoveCardFromSlot(trickPCSlot))
            table.insert(wonCardsNpc, RemoveCardFromSlot(trickNPCSlot))
        end


        log:debug("\tPlayer points: %s, NPC points: %s", GetPlayerPoints(), GetNpcPoints())

        -- check if the game has ended
        if #playerHand == 0 and #npcHand == 0 then
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

local function determineNextState()
    if currentState == GameState.DEAL then
        -- determine at random who goes next
        local startPlayer = math.random(2)
        if startPlayer == 1 then
            log:debug("Player starts")
        else
            log:debug("NPC starts")
        end

        -- go to the next state, depending on who starts
        if startPlayer == 1 then
            currentState = GameState.PLAYER_TURN
        else
            currentState = GameState.NPC_TURN
        end
        firstTurn = true
    elseif currentState == GameState.PLAYER_TURN then
        currentState = this.evaluate()
    elseif currentState == GameState.NPC_TURN then
        currentState = this.evaluate()
    end

    -- push the game to the next state
    log:trace("Next state: %s", stateToString(currentState))
end

local function update()
    log:trace("currentState %s", stateToString(currentState))

    playerJustHitTrick = false

    if currentState == GameState.DEAL then
        this.dealCards()
        this.determineNextState()
        this.update()
    elseif currentState == GameState.PLAYER_TURN then
        tes3.messageBox("It's your turn")
        -- the player is active so they get to chose when to push the statemachine
        playerDrewCard = false

        if firstTurn then
            playerDrewCard = true
            firstTurn = false
        end
    elseif currentState == GameState.NPC_TURN then
        this.npcTurn()

        -- wait one second before updating
        callbacklock = true
        timer.start({
            duration = 1,
            callback = function()
                this.determineNextState()

                -- wait one second before updating
                timer.start({
                    duration = 1,
                    callback = function()
                        this.update()

                        callbacklock = false
                    end
                })
            end
        })
    elseif currentState == GameState.GAME_END then
        this.endGame()
    elseif currentState == GameState.INVALID then
        log:error("Invalid state: Cleaning up")
        this.cleanup()
    end
end

--- @param e activateEventData
local function GameActivateCallback(e)
    log:trace("GameActivateCallback %s", e.target and e.target.object.id or "nil")

    if not e.target then
        return
    end

    if callbacklock then
        return
    end

    -- during the player turn
    if currentState ~= GameState.PLAYER_TURN then
        return
    end

    -- the player can hit the trick if there is a trick and the target is the trick
    if IsNpcTrick(e.target.object.id) then
        -- hit the trick
        log:debug("Player hits the trick")

        this.playerHitTrick()
        return
    end

    -- if there is no trick then the player can draw a card to start their turn
    if e.target.object.id == this.FLIN_DECK_ID_FACEDOWN then
        log:debug("Player draws a card")

        this.playerDrawCard()

        -- the deck is an item
        e.claim = true
        return false
    end

    -- if the talon is empty the player can still draw the trump card
    if talonEmpty and IsTrumpCard(e.target.object.id) then
        log:debug("Player draws the trump card")

        this.playerDrawCard()
        return
    end
end

--- @param e simulateEventData
local function GameWarningCheck(e)
    if not talonSlot then
        return
    end

    -- TODO check cells too

    if gameWarned then
        -- calculate the distance between the NPC and the player
        local distance = talonSlot.position:distance(tes3.player.position)
        if distance > GAME_FORFEIT_DISTANCE then
            -- warn the player and forfeit the game
            tes3.messageBox("You lose the game")
            -- TODO give npc the pot

            this.cleanup()
        end
    else
        -- calculate the distance between the NPC and the player
        local distance = talonSlot.position:distance(tes3.player.position)
        if distance > GAME_WARNING_DISTANCE then
            -- warn the player
            tes3.messageBox("You are too far away to continue the game, you will forfeit if you move further away")
            gameWarned = true
        end
    end
end

--- @param e keyDownEventData
local function GameKeyDownCallback(e)
    if callbacklock then
        return
    end
    -- during the player turn
    if currentState ~= GameState.PLAYER_TURN then
        return
    end

    -- this is only needed when the npctrick is null
    if trickNPCSlot and not trickNPCSlot.card then
        if e.keyCode == tes3.scanCode["o"] then
            debug.log(playerJustHitTrick)

            if playerJustHitTrick then
                return
            end

            log:debug("Player hits the trick")
            playerJustHitTrick = true

            this.playerHitTrick()
        end
    end
end


--- @param deck tes3reference
function FlinGame:startGame(deck)
    log:info("Starting game")
    tes3.messageBox("The game is on! The pot is %s gold", pot)

    event.unregister(tes3.event.activate, SetupActivateCallback)
    event.unregister(tes3.event.simulate, SetupWarningCheck)

    event.register(tes3.event.activate, GameActivateCallback)
    event.register(tes3.event.simulate, GameWarningCheck)
    event.register(tes3.event.keyDown, GameKeyDownCallback)

    local zOffsetTalon = 2
    local zOffsetTrump = 1

    -- replace the deck with a facedown deck
    local deckPos = deck.position:copy()
    local deckOrientation = deck.orientation:copy()
    deck:delete()

    -- store positions: deck, trump, trickPC, trickNPC
    talonSlot = {
        position = deckPos + tes3vector3.new(0, 0, zOffsetTalon),
        orientation = deckOrientation,
        card = nil,
        handle = tes3.makeSafeObjectHandle(
            tes3.createReference({
                object = this.FLIN_DECK_ID_FACEDOWN,
                position = deckPos + tes3vector3.new(0, 0, zOffsetTalon),
                orientation = deckOrientation,
                cell = tes3.player.cell
            })
        )
    }

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
    trumpCardSlot = {
        position = trumpPosition + tes3vector3.new(0, 0, zOffsetTrump),
        orientation = trumpOrientation,
        card = nil,
        handle = nil
    }

    -- trick slots are off to the side
    local trickOrientation = deckOrientation
    trickPCSlot = {
        position = deckPos + tes3vector3.new(0, 10, zOffsetTrump),
        orientation = trickOrientation,
        card = nil,
        handle = nil
    }
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

    trickNPCSlot = {
        position = deckPos + tes3vector3.new(0, 10, zOffsetTrump),
        orientation = rotation2:toEulerXYZ(),
        card = nil,
        handle = nil
    }

    currentState = GameState.DEAL
    this.update()
end

function FlinGame:cleanup()
    log:trace("Cleaning up")

    self.currentState = GameState.INVALID

    gameWarned = false

    self.pot = 0

    self.talon = {}
    self.trumpSuit = nil
    self.talonEmpty = false

    self.playerHand = {}
    self.npcHand = {}

    self.wonCardsPc = {}
    self.wonCardsNpc = {}

    -- cleanup handles and references
    self.handle = nil

    CardSlot.CleanupSlot(talonSlot)
    CardSlot.CleanupSlot(trumpCardSlot)
    CardSlot.CleanupSlot(trickPCSlot)
    CardSlot.CleanupSlot(trickNPCSlot)

    -- temps
    playerDrewCard = false
    firstTurn = false
    playerJustHitTrick = false
    callbacklock = false

    event.unregister(tes3.event.activate, GameActivateCallback)
    event.unregister(tes3.event.simulate, GameWarningCheck)
    event.unregister(tes3.event.keyDown, GameKeyDownCallback)
end

return FlinGame
