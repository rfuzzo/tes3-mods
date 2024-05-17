local config = require("Flin.config")
local lib = require("Flin.lib")
local log = lib.log

local AbstractState = require("Flin.states.abstractState")
local bb = require("Flin.blackboard")

---@class PlayerTurnState: AbstractState
---@field game FlinGame
local state = {}
setmetatable(state, { __index = AbstractState })

---@param game FlinGame
---@return PlayerTurnState
function state:new(game)
    ---@type PlayerTurnState
    local newObj = {
        game = game
    }
    self.__index = self
    setmetatable(newObj, self)
    ---@cast newObj PlayerTurnState
    return newObj
end

---@param game FlinGame
---@param card Card
local function PcPlayCard(game, card)
    for i, c in ipairs(game.playerHand) do
        if c == card then
            local result = table.remove(game.playerHand, i)
            game.trickPCSlot:AddCardToSlot(result)

            log:debug("PC plays card: %s", result:toString())
            -- tes3.messageBox("You play: %s", result:toString())

            return
        end
    end
end

---@param game FlinGame
local function getHeaderText(game)
    return string.format("Choose a card to play (Trump is %s)", lib.suitToString(game.trumpSuit))
end

---@param game FlinGame
local function getMessageText(game)
    local trickMsg = ""
    if game.trickNPCSlot and game.trickNPCSlot.card then
        trickMsg = string.format("Trick: %s", game.trickNPCSlot.card:toString())
    end

    return string.format(
        "Player's turn (you have %s points, NPC has %s points).\n%s",
        game:GetPlayerPoints(),
        game:GetNpcPoints(),
        trickMsg)
end

---@param game FlinGame
local function openHandMenu(game)
    local buttons = {}
    for i, card in ipairs(game.playerHand) do
        local buttonText = string.format("%s %s", lib.suitToString(card.suit), lib.valueToString(card.value))
        table.insert(
            buttons,
            {
                text = buttonText,
                callback = function()
                    PcPlayCard(game, card)

                    -- wait one second before updating
                    timer.start({
                        duration = 1,
                        callback = function()
                            game:PushState(game:evaluateTrick())
                        end
                    })
                end
            })
    end

    -- add custom block to call game
    tes3ui.showMessageMenu({
        header = getHeaderText(game),
        message = getMessageText(game),
        buttons = buttons,
        cancels = true,
        customBlock = function(parent)
            -- only show if player has >= 66 points
            if game:GetPlayerPoints() < 66 then
                return
            end

            parent.childAlignX = 0.5
            parent.paddingAllSides = 8

            local callButton = parent:createButton({
                text = "Call the game",
                id = tes3ui.registerID("flin:callGame")
            })
            callButton:register("mouseClick", function()
                log:debug("Player calls the game")
                tes3ui.leaveMenuMode()
                parent:destroy()

                game:PushState(lib.GameState.GAME_END)
            end)
        end,
    })
end

---@param game FlinGame
local function playerDrawCard(game)
    local playerDrewCard = bb.getInstance():getData("playerDrewCard") ---@type boolean
    if playerDrewCard then
        log:debug("Player already drew a card")
        tes3.messageBox("You already drew a card")
        return
    end

    -- draw a card
    if not game:drawCard(true) then
        log:debug("Player cannot draw a card")
        tes3.messageBox("You cannot draw another card")
        return
    end

    -- set the playerDrewCard flag to true
    bb.getInstance():setData("playerDrewCard", true)
end

--#region event callbacks

--- @param e keyDownEventData
local function KeyDownCallback(e)
    local game = bb.getInstance():getData("game") ---@type FlinGame

    local playerDrewCard = bb.getInstance():getData("playerDrewCard") ---@type boolean
    if playerDrewCard and not game:GetNpcTrickRef() then
        openHandMenu(game)
    end
end

--- @param e activateEventData
local function ActivateCallback(e)
    local game = bb.getInstance():getData("game") ---@type FlinGame

    local playerDrewCard = bb.getInstance():getData("playerDrewCard") ---@type boolean

    if playerDrewCard then
        if game:GetNpcTrickRef() and e.target.id == game:GetNpcTrickRef().id then
            log:trace("ActivateTrickCallback")
            openHandMenu(game)
            return
        end
    else
        if game:GetTalonRef() and e.target.id == game:GetTalonRef().id then
            log:trace("ActivateDeckCallback")
            playerDrawCard(game)
            return
        else
            -- if the talon is empty and there is a trump card then the player can draw the trump card
            if game:IsTalonEmpty() and game:GetTrumpCardRef() and e.target.id == game:GetTrumpCardRef().id then
                log:trace("ActivateTrumpCallback")
                playerDrawCard(game)
                return
            end
        end
    end
end

--#endregion

function state:enterState()
    log:debug("OnEnter: PlayerTurnState")

    -- register event callbacks
    local game = self.game

    debug.log(#game.playerHand)
    if #game.playerHand == 5 then
        bb.getInstance():setData("playerDrewCard", true)
    else
        bb.getInstance():setData("playerDrewCard", false)
    end

    -- register event callbacks
    event.register(tes3.event.activate, ActivateCallback)
    ---@diagnostic disable-next-line: need-check-nil
    event.register(tes3.event.keyDown, KeyDownCallback, { filter = config.openkeybind.keyCode })
    -- add game to blackboard for events
    bb.getInstance():setData("game", self.game)
    -- add check for player drew card to bb
end

function state:endState()
    -- unregister event callbacks
    event.unregister(tes3.event.activate, ActivateCallback)
    event.unregister(tes3.event.keyDown, KeyDownCallback)
    -- remove game from blackboard
    bb.getInstance():removeData("game")
    -- remove playerDrewCard from bb
    bb.getInstance():removeData("playerDrewCard")
end

return state
