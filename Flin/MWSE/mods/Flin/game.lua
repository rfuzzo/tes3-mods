local this      = {}

local logger    = require("logging.logger")
local log       = logger.new {
    name = "Flin",
    logLevel = "TRACE",
    logToConsole = false,
    includeTimestamp = false
}

---@alias GameState number
local GameState = {
    INVALID = 0,
    DEAL = 1,
    PLAYER_TURN = 2,
    NPC_TURN = 3,
    GAME_END = 4
}

---@alias EValue number
local EValue    = {
    Unter = 2,
    Ober = 3,
    King = 4,
    X = 10,
    Ace = 11,
}

---@alias ESuit number
local ESuit     = {
    Hearts = 1,
    Bells = 2,
    Acorns = 3,
    Leaves = 4
}

---@param suit ESuit
---@return string
local function suitToString(suit)
    if suit == ESuit.Hearts then
        return "Hearts"
    elseif suit == ESuit.Bells then
        return "Bells"
    elseif suit == ESuit.Acorns then
        return "Acorns"
    elseif suit == ESuit.Leaves then
        return "Leaves"
    end
    return "Unknown"
end


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

-- TODO english names
---@param value EValue
---@return string
local function valueToString(value)
    if value == EValue.Unter then
        return "Unter"
    elseif value == EValue.Ober then
        return "Ober"
    elseif value == EValue.King then
        return "King"
    elseif value == EValue.X then
        return "X"
    elseif value == EValue.Ace then
        return "Ace"
    end
    return "Unknown"
end

---@param card Card
---@return string
local function cardToString(card)
    return string.format("%s %s", suitToString(card.suit), valueToString(card.value))
end

-- card class
--- @class Card
--- @field value number
--- @field suit number
local Card         = {
    value = 0,
    suit = 0
}

local currentState = GameState.DEAL

local talon        = {}  --- @type Card[]
local trumpCard    = nil --- @type Card?
local trumpSuit    = 0
local talonEmpty   = false

local playerHand   = {}  --- @type Card[]
local npcHand      = {}  --- @type Card[]

local trickPC      = nil --- @type Card?
local trickNPC     = nil --- @type Card?

local wonCardsPc   = {}  --- @type Card[]
local wonCardsNpc  = {}  --- @type Card[]


function this.cleanup()
    log:trace("Cleaning up")
    talon = {}
    trumpCard = nil
    trumpSuit = 0
    playerHand = {}
    npcHand = {}
    trickPC = nil
    trickNPC = nil
    wonCardsPc = {}
    wonCardsNpc = {}
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

    table.insert(talon, newCard(ESuit.Hearts, EValue.Unter))
    table.insert(talon, newCard(ESuit.Hearts, EValue.Ober))
    table.insert(talon, newCard(ESuit.Hearts, EValue.King))
    table.insert(talon, newCard(ESuit.Hearts, EValue.X))
    table.insert(talon, newCard(ESuit.Hearts, EValue.Ace))

    table.insert(talon, newCard(ESuit.Bells, EValue.Unter))
    table.insert(talon, newCard(ESuit.Bells, EValue.Ober))
    table.insert(talon, newCard(ESuit.Bells, EValue.King))
    table.insert(talon, newCard(ESuit.Bells, EValue.X))
    table.insert(talon, newCard(ESuit.Bells, EValue.Ace))

    table.insert(talon, newCard(ESuit.Acorns, EValue.Unter))
    table.insert(talon, newCard(ESuit.Acorns, EValue.Ober))
    table.insert(talon, newCard(ESuit.Acorns, EValue.King))
    table.insert(talon, newCard(ESuit.Acorns, EValue.X))
    table.insert(talon, newCard(ESuit.Acorns, EValue.Ace))

    table.insert(talon, newCard(ESuit.Leaves, EValue.Unter))
    table.insert(talon, newCard(ESuit.Leaves, EValue.Ober))
    table.insert(talon, newCard(ESuit.Leaves, EValue.King))
    table.insert(talon, newCard(ESuit.Leaves, EValue.X))
    table.insert(talon, newCard(ESuit.Leaves, EValue.Ace))

    this.shuffleDeck(talon)
end

---@return Card?
local function talonPop()
    if #talon == 0 then
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

    this.cleanup()

    -- Code to deal cards to players
    -- first init the talon
    this.newTalon()

    -- deal 3 cards to each player, remove them from the talon
    for i = 1, 3 do
        dealCardTo(true)
        dealCardTo(false)
    end

    -- the trump card is the next card in the talon
    trumpCard = talonPop()
    -- save the trump suit
    if not trumpCard then
        log:error("No trump card")
        currentState = GameState.INVALID
        return
    end
    trumpSuit = trumpCard.suit
    log:debug("Trump suit: %s", trumpSuit)
    tes3.messageBox("Trump suit: %s", trumpSuit)

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
    if trickPC then
        -- if the NPC goes second

        -- if the current trick is of low value then just dump a low non trump card
        if trickPC.value <= EValue.King then
            for i, card in ipairs(npcHand) do
                if card.suit ~= trumpSuit and card.value <= EValue.King then
                    return table.remove(npcHand, i)
                end
            end

            -- we couldn't find a low non-trump card to dump
        end

        -- if the current trick is of high value then try to win it with a non-trump card of the same suit
        if trickPC.value > EValue.King then
            for i, card in ipairs(npcHand) do
                if card.suit ~= trumpSuit and card.suit == trickPC.suit then
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
    local card = npcHand[math.random(#npcHand)]
    return card
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
            trickPC = result

            log:debug("PC plays card: %s", cardToString(result))
            tes3.messageBox("You play: %s", cardToString(result))
            break
        end
    end
end

---@param card Card
function this.NpcPlayCard(card)
    trickNPC = card

    log:debug("NPC plays card: %s", cardToString(card))
    tes3.messageBox("NPC plays: %s", cardToString(card))
end

function this.drawCard(isPlayer)
    -- only draw a card if the hand is less than 5 cards
    if isPlayer and #playerHand >= 5 then
        return
    end

    if not isPlayer and #npcHand >= 5 then
        return
    end

    local card = talonPop()

    if not card and not trumpCard then
        talonEmpty = true
        return
    end

    if not card and trumpCard then
        log:debug("No more cards in the talon")
        tes3.messageBox("No more cards in the talon")
        talonEmpty = true
        card = newCard(trumpCard.suit, trumpCard.value)
        trumpCard = nil
    end

    if isPlayer then
        log:debug("player draws card: %s", cardToString(card))
        table.insert(playerHand, card)
    else
        log:debug("NPC draws card: %s", cardToString(card))
        table.insert(npcHand, card)
    end
end

---@return GameState
function this.evaluate()
    log:trace("evaluate")
    -- Code to evaluate the trick

    -- if the player has played and the NPC has not then it is the NPC's turn
    if trickPC and not trickNPC then
        log:debug("Player has played a card, NPC has not")
        return GameState.NPC_TURN
    end

    -- if the NPC has played and the player has not then it is the player's turn
    if trickNPC and not trickPC then
        log:debug("NPC has played a card, player has not")
        return GameState.PLAYER_TURN
    end

    -- evaluate the trick if both players have played a card
    if trickPC and trickNPC then
        log:debug("Both players have played a card")

        -- the winner of the trick goes next
        -- evaluate the trick
        local playerWins = false
        -- if the player has played a trump card and the NPC has not then the player wins
        if trickPC.suit == trumpSuit and trickNPC.suit ~= trumpSuit then
            playerWins = true
            -- if the NPC has played a trump card and the player has not then the NPC wins
        elseif trickNPC.suit == trumpSuit and trickPC.suit ~= trumpSuit then
            playerWins = false
            -- if both players have played a trump card then the higher value wins
        elseif trickPC.suit == trumpSuit and trickNPC.suit == trumpSuit then
            if trickPC.value > trickNPC.value then
                playerWins = true
            else
                playerWins = false
            end
            -- if both players have played a card of the same suit then the higher value wins
        elseif trickPC.suit == trickNPC.suit then
            if trickPC.value > trickNPC.value then
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
        local valueOfTrick = trickPC.value + trickNPC.value
        if playerWins then
            log:debug("Player wins the trick (%s > %s)", cardToString(trickPC), cardToString(trickNPC))

            -- move the cards to the player's won cards
            table.insert(wonCardsPc, trickPC)
            table.insert(wonCardsPc, trickNPC)
        else
            log:debug("NPC wins the trick (%s > %s)", cardToString(trickNPC), cardToString(trickPC))

            -- move the cards to the NPC's won cards
            table.insert(wonCardsNpc, trickPC)
            table.insert(wonCardsNpc, trickNPC)
        end

        -- reset the trick
        trickPC = nil
        trickNPC = nil

        log:debug("\tPlayer points: %s, NPC points: %s", GetPlayerPoints(), GetNpcPoints())

        -- check if the game has ended
        if #playerHand == 0 and #npcHand == 0 then
            return GameState.GAME_END
        end

        -- determine who goes next
        if playerWins then
            return GameState.PLAYER_TURN
        else
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
    if trickNPC then
        trick = string.format("Trick: %s", cardToString(trickNPC))
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
        table.insert(buttons, {
            text = buttonText,
            callback = function()
                this.PcPlayCard(card)
                this.determineNextState()
                this.update()
            end
        })
    end

    tes3ui.showMessageMenu({
        header = getHeaderText(),
        message = getMessageText(),
        buttons = buttons,
        cancels = true
    })
end

function this.playerTurn()
    -- if we're not in player turn state then return
    if currentState ~= GameState.PLAYER_TURN then
        return
    end

    log:debug("> Player turn")
    log:debug("player hand:")
    for i, c in ipairs(playerHand) do
        log:debug("\t%s", cardToString(c))
    end

    -- Code for the player's turn
    -- draw a card
    this.drawCard(true)

    -- get the card the player wants to play
    choosePcCardToPlay()
end

function this.npcTurn()
    log:trace("NPC turn")
    log:debug("npc hand:")
    for i, c in ipairs(npcHand) do
        log:debug("\t%s", cardToString(c))
    end

    this.drawCard(false)
    local card = chooseNpcCardToPlay()

    this.NpcPlayCard(card)

    -- npc went last
    if trickPC and trickNPC then
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
        -- this.playerTurn()
        -- this.determineNextState()
        -- this.update()
    elseif currentState == GameState.NPC_TURN then
        this.npcTurn()
        this.determineNextState()

        -- wait one second before updating
        timer.start({
            duration = 1,
            callback = function()
                this.update()
            end
        })
    elseif currentState == GameState.GAME_END then
        this.endGame()
    elseif currentState == GameState.INVALID then
        log:error("Invalid state: Cleaning up")
        this.cleanup()
    end
end

--- @param ref tes3reference?
function this.startGame(ref)
    log:info("Starting game")
    tes3.messageBox("Starting game")

    currentState = GameState.DEAL
    this.update()
end

return this
