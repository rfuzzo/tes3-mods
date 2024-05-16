local lib                    = require("Flin.lib")
local log                    = lib.log

local this                   = {}

this.FLIN_DECK_ID            = "flin_deck_20"
this.FLIN_DECK_ID_FACEDOWN   = "a_flin_deck_20_r"

local SETUP_WARNING_DISTANCE = 200
local SETUP_FORFEIT_DISTANCE = 300
local GAME_WARNING_DISTANCE  = 200
local GAME_FORFEIT_DISTANCE  = 300

---@enum GameState
local GameState              = {
    INVALID = 0,
    DEAL = 1,
    PLAYER_TURN = 2,
    NPC_TURN = 3,
    GAME_END = 4
}

---@param state GameState
---@return string
local function stateToString(state)
    if state == GameState.INVALID then
        return "INVALID"
    elseif state == GameState.DEAL then
        return "DEAL"
    elseif state == GameState.PLAYER_TURN then
        return "PLAYER_TURN"
    elseif state == GameState.NPC_TURN then
        return "NPC_TURN"
    elseif state == GameState.GAME_END then
        return "GAME_END"
    end
    return "Unknown"
end

---@enum ESuit
this.ESuit = {
    Hearts = 1,
    Bells = 2,
    Acorns = 3,
    Leaves = 4
}

---@param suit ESuit
---@return string
local function suitToString(suit)
    if suit == this.ESuit.Hearts then
        return "Hearts"
    elseif suit == this.ESuit.Bells then
        return "Bells"
    elseif suit == this.ESuit.Acorns then
        return "Acorns"
    elseif suit == this.ESuit.Leaves then
        return "Leaves"
    end
    return "Unknown"
end

---@enum EValue
this.EValue = {
    Unter = 2,
    Ober = 3,
    King = 4,
    X = 10,
    Ace = 11,
}

-- TODO english names
---@param value EValue
---@return string
local function valueToString(value)
    if value == this.EValue.Unter then
        return "Unter"
    elseif value == this.EValue.Ober then
        return "Ober"
    elseif value == this.EValue.King then
        return "King"
    elseif value == this.EValue.X then
        return "X"
    elseif value == this.EValue.Ace then
        return "Ace"
    end
    return "Unknown"
end

---@param suit ESuit
---@param value EValue
---@return string?
function this.GetCardMiscItemName(suit, value)
    local suitName = suitToString(suit):lower()
    if suitName == "unknown" then
        return nil
    end

    local valueName = valueToString(value):lower()
    if valueName == "unknown" then
        return nil
    end

    return string.format("card_%s_%s", suitName, valueName)
end

---@param suit ESuit
---@param value EValue
---@return string?
function this.GetCardActivatorName(suit, value)
    local suitName = suitToString(suit):lower()
    if suitName == "unknown" then
        return nil
    end

    local valueName = valueToString(value):lower()
    if valueName == "unknown" then
        return nil
    end

    return string.format("a_%s_%s", suitName, valueName)
end

---@param suit ESuit
---@param value EValue
---@return string?
function this.GetCardMeshName(suit, value)
    local suitName = suitToString(suit)
    if suitName == "Unknown" then
        return nil
    end

    local valueName = valueToString(value)
    if valueName == "Unknown" then
        return nil
    end

    return string.format("rf\\%s.%s.nif", suitName, valueName)
end

---@param card Card
---@return string
local function cardToString(card)
    return string.format("%s %s", suitToString(card.suit), valueToString(card.value))
end

-- card class
--- @class Card
--- @field value EValue?
--- @field suit ESuit?
local Card     = {
    value = nil,
    suit = nil
}

-- card slot class
--- @class CardSlot
--- @field card Card?
--- @field handle mwseSafeObjectHandle?
--- @field position tes3vector3?
--- @field orientation tes3vector3
local CardSlot = {
    position = nil,
    orientation = tes3vector3.new(0, 0, 0),
    card = nil,
    handle = nil
}

---@param slot CardSlot
---@param card Card
local function AddCardToSlot(slot, card)
    slot.card = card
    slot.handle = tes3.makeSafeObjectHandle(
        tes3.createReference({
            object = this.GetCardActivatorName(card.suit, card.value),
            position = slot.position,
            orientation = tes3vector3.new(0, 0, 0),
            cell = tes3.player.cell
        })
    )
end

---@param slot CardSlot
---@return Card?
local function RemoveCardFromSlot(slot)
    if slot.handle then
        if slot.handle:valid() then
            slot.handle:getObject():delete()
        end
        slot.handle = nil
    end

    local card_ = slot.card
    slot.card = nil

    return card_
end

---@param slot CardSlot?
local function CleanupSlot(slot)
    if slot then
        RemoveCardFromSlot(slot)
        slot = nil
    end
end


local currentState = GameState.DEAL


local setupWarned    = false

local talon          = {}  --- @type Card[]
local trumpSuit      = nil --- @type ESuit?
local talonEmpty     = false

local playerHand     = {}  --- @type Card[]
local npcHand        = {}  --- @type Card[]

local wonCardsPc     = {}  --- @type Card[]
local wonCardsNpc    = {}  --- @type Card[]

local npcLocation    = nil --- @type tes3vector3?

local talonSlot      = nil --- @type CardSlot?
local trumpCardSlot  = nil --- @type CardSlot?
local trickPCSlot    = nil --- @type CardSlot?
local trickNPCSlot   = nil --- @type CardSlot?

local wonCardsPcPos  = nil --- @type CardSlot?
local wonCardsNpcPos = nil --- @type CardSlot?

-- temp
local playerDrewCard = false

---@param id string
local function IsNpcTrick(id)
    -- get the id of the trick activator
    if trickNPCSlot and trickNPCSlot.handle and trickNPCSlot.handle:valid() then
        if trickNPCSlot.handle:getObject().id == id then
            return true
        end
    end

    return false
end

---@param id string
local function IsTrumpCard(id)
    -- get the id of the trump card activator
    if trumpCardSlot and trumpCardSlot.handle and trumpCardSlot.handle:valid() then
        if trumpCardSlot.handle:getObject().id == id then
            return true
        end
    end

    return false
end

local function GetPlayerPoints()
    local points = 0
    for _, card in ipairs(wonCardsPc) do
        points = points + card.value
    end
    return points
end

local function GetNpcPoints()
    local points = 0
    for _, card in ipairs(wonCardsNpc) do
        points = points + card.value
    end
    return points
end

function this.shuffleDeck(deck)
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
end

---@param suit ESuit
---@param value EValue
---@return Card
local function newCard(suit, value)
    local card = {
        suit = suit,
        value = value
    } ---@type Card
    return card
end

function this.newTalon()
    talon = {}

    table.insert(talon, newCard(this.ESuit.Hearts, this.EValue.Unter))
    table.insert(talon, newCard(this.ESuit.Hearts, this.EValue.Ober))
    table.insert(talon, newCard(this.ESuit.Hearts, this.EValue.King))
    table.insert(talon, newCard(this.ESuit.Hearts, this.EValue.X))
    table.insert(talon, newCard(this.ESuit.Hearts, this.EValue.Ace))

    table.insert(talon, newCard(this.ESuit.Bells, this.EValue.Unter))
    table.insert(talon, newCard(this.ESuit.Bells, this.EValue.Ober))
    table.insert(talon, newCard(this.ESuit.Bells, this.EValue.King))
    table.insert(talon, newCard(this.ESuit.Bells, this.EValue.X))
    table.insert(talon, newCard(this.ESuit.Bells, this.EValue.Ace))

    table.insert(talon, newCard(this.ESuit.Acorns, this.EValue.Unter))
    table.insert(talon, newCard(this.ESuit.Acorns, this.EValue.Ober))
    table.insert(talon, newCard(this.ESuit.Acorns, this.EValue.King))
    table.insert(talon, newCard(this.ESuit.Acorns, this.EValue.X))
    table.insert(talon, newCard(this.ESuit.Acorns, this.EValue.Ace))

    table.insert(talon, newCard(this.ESuit.Leaves, this.EValue.Unter))
    table.insert(talon, newCard(this.ESuit.Leaves, this.EValue.Ober))
    table.insert(talon, newCard(this.ESuit.Leaves, this.EValue.King))
    table.insert(talon, newCard(this.ESuit.Leaves, this.EValue.X))
    table.insert(talon, newCard(this.ESuit.Leaves, this.EValue.Ace))

    this.shuffleDeck(talon)
end

---@return Card?
local function talonPop()
    if #talon == 0 then
        -- update slot
        if talonSlot and talonSlot.handle and talonSlot.handle:valid() then
            talonSlot.handle:getObject():delete()
            talonSlot.handle = nil
        end

        return nil
    end

    local card = talon[1]
    table.remove(talon, 1)
    return card
end

---@param isPlayer boolean
local function dealCardTo(isPlayer)
    if isPlayer then
        table.insert(playerHand, talonPop())
    else
        table.insert(npcHand, talonPop())
    end
end

function this.dealCards()
    log:trace("Dealing cards")

    -- Code to deal cards to players
    -- first init the talon
    this.newTalon()

    -- deal 3 cards to each player, remove them from the talon
    for i = 1, 3 do
        dealCardTo(true)
        dealCardTo(false)
    end

    -- the trump card is the next card in the talon
    local trumpCard = talonPop()
    if not trumpCard then
        log:error("No trump card")
        currentState = GameState.INVALID
        return
    end
    AddCardToSlot(trumpCardSlot, trumpCard)
    -- save the trump suit
    trumpSuit = trumpCard.suit
    log:debug("Trump suit: %s", suitToString(trumpSuit))
    -- tes3.messageBox("Trump suit: %s", suitToString(trumpSuit))

    -- deal the rest of the cards to the players
    -- 2 cards to the player, 2 cards to the npc
    for i = 1, 2 do
        dealCardTo(true)
        dealCardTo(false)
    end
end

-- AI logic

---@return Card
local function chooseNpcCardPhase1()
    -- make it depend on if the NPC goes first or second
    if trickPCSlot and trickPCSlot.card then
        -- if the NPC goes second

        -- if the current trick is of low value then just dump a low non trump card
        if trickPCSlot.card.value <= this.EValue.King then
            for i, card in ipairs(npcHand) do
                if card.suit ~= trumpSuit and card.value <= this.EValue.King then
                    return table.remove(npcHand, i)
                end
            end

            -- we couldn't find a low non-trump card to dump
        end

        -- if the current trick is of high value then try to win it with a non-trump card of the same suit
        if trickPCSlot.card.value > this.EValue.King then
            for i, card in ipairs(npcHand) do
                if card.suit ~= trumpSuit and card.suit == trickPCSlot.card.suit then
                    return table.remove(npcHand, i)
                end
            end

            -- now try to win it with a high trump card
            for i, card in ipairs(npcHand) do
                if card.suit == trumpSuit and card.value > this.EValue.King then
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
            if card.suit == trumpSuit and card.value > this.EValue.King then
                return table.remove(npcHand, i)
            end
        end

        -- we don't have a high trump card so try to dump a low non-trump card
        for i, card in ipairs(npcHand) do
            if card.suit ~= trumpSuit and card.value <= this.EValue.King then
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
local function chooseNpcCardPhase2()
    -- TODO implement phase 2
    return chooseNpcCardPhase1()
end

---@return Card
local function chooseNpcCardToPlay()
    if talonEmpty then
        return chooseNpcCardPhase2()
    else
        return chooseNpcCardPhase1()
    end
end

---@param card Card
function this.PcPlayCard(card)
    for i, c in ipairs(playerHand) do
        if c == card then
            local result = table.remove(playerHand, i)
            AddCardToSlot(trickPCSlot, result)

            log:debug("PC plays card: %s", cardToString(result))
            tes3.messageBox("You play: %s", cardToString(result))

            return
        end
    end
end

---@param card Card
function this.NpcPlayCard(card)
    AddCardToSlot(trickNPCSlot, card)

    log:debug("NPC plays card: %s", cardToString(card))
    tes3.messageBox("NPC plays: %s", cardToString(card))
end

---@return boolean
function this.drawCard(isPlayer)
    log:trace("============")
    log:trace("player hand:")
    for i, c in ipairs(playerHand) do
        log:debug("\t%s", cardToString(c))
    end
    log:trace("npc hand:")
    for i, c in ipairs(npcHand) do
        log:debug("\t%s", cardToString(c))
    end
    log:trace("talon:")
    for i, c in ipairs(talon) do
        log:debug("\t%s", cardToString(c))
    end
    log:trace("trick pc:")
    if trickPCSlot and trickPCSlot.card then
        log:debug("\t%s", cardToString(trickPCSlot.card))
    end
    log:trace("trick npc:")
    if trickNPCSlot and trickNPCSlot.card then
        log:debug("\t%s", cardToString(trickNPCSlot.card))
    end
    log:trace("============")

    -- only draw a card if the hand is less than 5 cards
    if isPlayer and #playerHand >= 5 then
        return false
    end

    if not isPlayer and #npcHand >= 5 then
        return false
    end

    local card = talonPop()

    -- if the talon is empty then the trump card is the last card in the talon
    if not card and trumpCardSlot and trumpCardSlot.card then
        log:debug("No more cards in the talon")
        tes3.messageBox("No more cards in the talon")
        talonEmpty = true
        card = RemoveCardFromSlot(trumpCardSlot)
    end

    if not card then
        log:error("No more cards in the talon")
        return false
    end

    if isPlayer then
        log:debug("player draws card: %s", cardToString(card))
        table.insert(playerHand, card)
    else
        log:debug("NPC draws card: %s", cardToString(card))
        table.insert(npcHand, card)
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
function this.evaluate()
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
            tes3.messageBox("> Player wins the trick (%s > %s)", cardToString(trickPCSlot.card),
                cardToString(trickNPCSlot.card))

            -- move the cards to the player's won cards
            table.insert(wonCardsPc, RemoveCardFromSlot(trickPCSlot))
            table.insert(wonCardsPc, RemoveCardFromSlot(trickNPCSlot))
        else
            log:debug("> NPC wins the trick (%s > %s)", cardToString(trickNPCSlot.card), cardToString(trickPCSlot.card))
            tes3.messageBox("> NPC wins the trick (%s > %s)", cardToString(trickNPCSlot.card),
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

local function getHeaderText()
    return string.format("Choose a card to play (Trump is %s)", suitToString(trumpSuit))
end

local function getMessageText()
    local trick = ""
    if trickNPCSlot and trickNPCSlot.card then
        trick = string.format("Trick: %s", cardToString(trickNPCSlot.card))
    end

    return string.format(
        "Player's turn (you have %s points, NPC has %s points).\n%s",
        GetPlayerPoints(),
        GetNpcPoints(), trick)
end

local function choosePcCardToPlay()
    -- UI
    local buttons = {}
    for i, card in ipairs(playerHand) do
        local buttonText = string.format("%s %s", suitToString(card.suit), valueToString(card.value))
        table.insert(
            buttons,
            {
                text = buttonText,
                callback = function()
                    this.PcPlayCard(card)
                    this.determineNextState()

                    -- wait one second before updating
                    timer.start({
                        duration = 1,
                        callback = function()
                            this.update()
                        end
                    })
                end
            })
    end

    -- TODO add custom block to call game
    -- TODO add easy mode
    tes3ui.showMessageMenu({
        header = getHeaderText(),
        message = getMessageText(),
        buttons = buttons,
        cancels = true
    })
end

function this.playerDrawCard()
    -- if we're not in player turn state then return
    if currentState ~= GameState.PLAYER_TURN then
        return
    end

    -- Code for the player's turn
    -- draw a card
    if not this.drawCard(true) then
        log:debug("Player cannot draw a card")
        tes3.messageBox("You cannot draw a card")
    else
        playerDrewCard = true
    end
end

function this.playerHitTrick()
    -- if we're not in player turn state then return
    if currentState ~= GameState.PLAYER_TURN then
        return
    end

    log:debug("> Player turn")

    -- hacks for first turn and phase 2 turns
    if not playerDrewCard and #playerHand == 5 then
        playerDrewCard = true
    end
    if talonEmpty and trumpCardSlot and not trumpCardSlot.card then
        playerDrewCard = true
    end

    -- if the player has not drawn a card then they cannot hit the trick
    if not playerDrewCard then
        log:debug("Player cannot hit the trick, they must draw a card first")
        tes3.messageBox("You must draw a card first")
        return
    end

    -- get the card the player wants to play
    choosePcCardToPlay()
end

function this.npcTurn()
    log:debug("NPC turn")

    this.drawCard(false)

    local card = chooseNpcCardToPlay()
    this.NpcPlayCard(card)

    -- npc went last
    if trickPCSlot and trickNPCSlot and trickPCSlot.card and trickNPCSlot.card then
        -- if the npc went last, they can call the game if they think they have more than 66 points
        if GetNpcPoints() > 66 then
            log:debug("NPC calls the game")
            tes3.messageBox("NPC calls the game")
            currentState = GameState.GAME_END
        end
    end
end

function this.endGame()
    -- Code for ending the game
    log:debug("Game ended")

    -- calculate the points
    local playerPoints = GetPlayerPoints()
    local npcPoints = GetNpcPoints()

    log:debug("Player points: %s, NPC points: %s", playerPoints, npcPoints)

    -- determine the winner
    if playerPoints > 66 then
        log:debug("Player wins")
        tes3.messageBox("You win!")
    elseif npcPoints > 66 then
        log:debug("NPC wins")
        tes3.messageBox("You lose!")
    else
        log:debug("It's a draw")
        tes3.messageBox("It's a draw!")
    end

    -- cleanup
    this.cleanup()
end

function this.determineNextState()
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
    elseif currentState == GameState.PLAYER_TURN then
        currentState = this.evaluate()
    elseif currentState == GameState.NPC_TURN then
        currentState = this.evaluate()
    end

    -- push the game to the next state
    log:trace("Next state: %s", stateToString(currentState))
end

function this.update()
    log:trace("currentState %s", stateToString(currentState))

    if currentState == GameState.DEAL then
        this.dealCards()
        this.determineNextState()
        this.update()
    elseif currentState == GameState.PLAYER_TURN then
        tes3.messageBox("It's your turn")
        -- the player is active so they get to chose when to push the statemachine
        playerDrewCard = false

        -- NOTE this can be activated to play in dialogue
        -- this.playerTurn()
        -- this.determineNextState()
        -- this.update()
    elseif currentState == GameState.NPC_TURN then
        this.npcTurn()

        -- wait one second before updating
        timer.start({
            duration = 1,
            callback = function()
                this.determineNextState()

                -- wait one second before updating
                timer.start({
                    duration = 1,
                    callback = function()
                        this.update()
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
local function SetupActivateCallback(e)
    log:trace("activateCallback")

    if e.target and e.target.object.id == this.FLIN_DECK_ID then
        this.startGame(e.target)
        e.claim = true
        return false
    end
end

--- @param e simulateEventData
local function SetupWarningCheck(e)
    if not npcLocation then
        return
    end

    -- TODO check cells too

    if setupWarned then
        -- calculate the distance between the NPC and the player
        local distance = npcLocation:distance(tes3.player.position)
        if distance > SETUP_FORFEIT_DISTANCE then
            -- warn the player and forfeit the game
            tes3.messageBox("You lose the game")

            event.unregister(tes3.event.activate, SetupActivateCallback)
            event.unregister(tes3.event.simulate, SetupWarningCheck)

            this.cleanup()
        end
    else
        -- calculate the distance between the NPC and the player
        local distance = npcLocation:distance(tes3.player.position)
        if distance > SETUP_WARNING_DISTANCE then
            -- warn the player
            tes3.messageBox("You are too far away from the NPC")
            setupWarned = true
        end
    end
end

--- @param e activateEventData
local function GameActivateCallback(e)
    log:trace("activateCallback")

    if not e.target then
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
    if e.target.object.id == this.FLIN_DECK_ID then
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

    -- if everything is empty the player must hit the trick (= play a card from hand)
    if talonEmpty and trumpCardSlot and not trumpCardSlot.card then
        -- TODO add a way to play a card
    end
end

--- @param e simulateEventData
local function GameWarningCheck(e)
    if not npcLocation then
        return
    end

    -- TODO check cells too

    if setupWarned then
        -- calculate the distance between the NPC and the player
        local distance = npcLocation:distance(tes3.player.position)
        if distance > GAME_FORFEIT_DISTANCE then
            -- warn the player and forfeit the game
            tes3.messageBox("You lose the game")

            event.unregister(tes3.event.activate, GameActivateCallback)
            event.unregister(tes3.event.simulate, GameWarningCheck)
            this.cleanup()
        end
    else
        -- calculate the distance between the NPC and the player
        local distance = npcLocation:distance(tes3.player.position)
        if distance > GAME_WARNING_DISTANCE then
            -- warn the player
            tes3.messageBox("You are too far away from the NPC")
            setupWarned = true
        end
    end
end


--- @param ref tes3reference
function this.setupGame(ref)
    log:info("Setup game")
    tes3.messageBox("Setup game")

    -- store the NPC location for checks
    npcLocation = ref.position

    event.register(tes3.event.activate, SetupActivateCallback)
    event.register(tes3.event.simulate, SetupWarningCheck)
end

--- @param deck tes3reference
function this.startGame(deck)
    log:info("Starting game")
    tes3.messageBox("Starting game")

    this.cleanup()

    event.unregister(tes3.event.activate, SetupActivateCallback)
    event.unregister(tes3.event.simulate, SetupWarningCheck)

    event.register(tes3.event.activate, GameActivateCallback)
    event.register(tes3.event.simulate, GameWarningCheck)

    -- replace the deck with a facedown deck
    local deckPos = deck.position:copy()
    local deckOrientation = deck.orientation:copy()
    deck:delete()
    local newDeck = tes3.createReference({
        object = this.FLIN_DECK_ID_FACEDOWN,
        position = deckPos,
        orientation = deckOrientation,
        cell = tes3.player.cell
    })

    -- store positions: deck, trump, trickPC, trickNPC
    talonSlot = {
        position = deckPos,
        orientation = deckOrientation,
        card = nil,
        handle = tes3.makeSafeObjectHandle(newDeck)
    }
    local trumpCardOrientation = deckOrientation:copy()
    -- rotate by 90 degrees around the z axis
    trumpCardOrientation.z = trumpCardOrientation.z + math.rad(90)
    trumpCardSlot = {
        position = deckPos + tes3vector3.new(0, 0, 2),
        orientation = trumpCardOrientation,
        card = nil,
        handle = nil
    }

    local trickOrientation = tes3vector3.new(0, 0, 0)
    local trickOffset = tes3vector3.new(0, -10, 2)
    trickPCSlot = {
        position = deckPos + trickOffset,
        orientation = trickOrientation,
        card = nil,
        handle = nil
    }
    local trickOrientation2 = trickOrientation:copy()
    -- rotate by 45 degrees around the z axis
    trickOrientation2.z = trickOrientation2.z + math.rad(45)
    trickNPCSlot = {
        position = deckPos + trickOffset,
        orientation = trickOrientation,
        card = nil,
        handle = nil
    }

    currentState = GameState.DEAL
    this.update()
end

function this.cleanup()
    log:trace("Cleaning up")

    currentState = GameState.INVALID

    setupWarned = false

    talon = {}
    trumpSuit = nil
    talonEmpty = false

    playerHand = {}
    npcHand = {}

    wonCardsPc = {}
    wonCardsNpc = {}

    npcLocation = nil

    -- cleanup handles and references

    CleanupSlot(talonSlot)
    CleanupSlot(trumpCardSlot)
    CleanupSlot(trickPCSlot)
    CleanupSlot(trickNPCSlot)

    wonCardsPcPos = nil
    wonCardsNpcPos = nil

    -- temps
    playerDrewCard = false

    event.unregister(tes3.event.activate, GameActivateCallback)
    event.unregister(tes3.event.simulate, GameWarningCheck)
end

return this
