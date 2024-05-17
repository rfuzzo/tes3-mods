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
                    game:PcPlayCard(card)
                    local nextState = game:evaluateTrick()

                    -- wait one second before updating
                    timer.start({
                        duration = 1,
                        callback = function()
                            game:PushState(nextState)
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
    local card = game:drawCard(true)
    if not card then
        log:debug("Player cannot draw a card")
        tes3.messageBox("You cannot draw another card")
        return
    end

    -- set the playerDrewCard flag to true
    bb.getInstance():setData("playerDrewCard", true)


    -- get the key from the tes3.scanCode table with value 24
    ---@diagnostic disable-next-line: need-check-nil
    local key = tes3.scanCode[config.openkeybind.keyCode]
    tes3.messageBox("You draw: %s, press %s to play a card!", card:toString(), key)
end

--#region event callbacks

--- @param e keyDownEventData
local function KeyDownCallback(e)
    local game = bb.getInstance():getData("game") ---@type FlinGame

    local playerDrewCard = bb.getInstance():getData("playerDrewCard") ---@type boolean
    if playerDrewCard and not game:GetNpcTrickRef() then
        openHandMenu(game)
    else
        tes3.messageBox("You must draw a card first")
    end
end

--- @param e activateEventData
local function ActivateCallback(e)
    local game = bb.getInstance():getData("game") ---@type FlinGame

    local playerDrewCard = bb.getInstance():getData("playerDrewCard") ---@type boolean
    if playerDrewCard then
        -- activate the trick
        if game:GetNpcTrickRef() and e.target.id == game:GetNpcTrickRef().id then
            -- hit the trick
            openHandMenu(game)
            return
        end

        -- activate the talon
        if game:GetTalonRef() and e.target.id == game:GetTalonRef().id then
            tes3.messageBox("You cannot draw another card")
            return
        end
    else
        -- activate the talon
        if game:GetTalonRef() and e.target.id == game:GetTalonRef().id then
            playerDrawCard(game)
            return
        elseif game:IsTalonEmpty() and game:GetTrumpCardRef() and e.target.id == game:GetTrumpCardRef().id then
            -- if the talon is empty and there is a trump card then the player can draw the trump card
            playerDrawCard(game)
            return
        end

        -- activate the trick
        if game:GetNpcTrickRef() and e.target.id == game:GetNpcTrickRef().id then
            tes3.messageBox("You must draw a card first")
            return
        end
    end
end

--#endregion

function state:enterState()
    log:debug("OnEnter: PlayerTurnState")




    -- register event callbacks
    local game = self.game

    if #game.playerHand == 5 or game:IsPhase2() then
        bb.getInstance():setData("playerDrewCard", true)

        if game:GetNpcTrickRef() then
            tes3.messageBox("It's your turn, hit the trick!")
        else
            ---@diagnostic disable-next-line: need-check-nil
            local key = tes3.scanCode[config.openkeybind.keyCode]
            tes3.messageBox("It's your turn, press %s to play a card!", key)
        end
    else
        bb.getInstance():setData("playerDrewCard", false)

        tes3.messageBox("It's your turn, draw a card from the talon!")
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
    ---@diagnostic disable-next-line: need-check-nil
    event.unregister(tes3.event.keyDown, KeyDownCallback, { filter = config.openkeybind.keyCode })
    -- remove game from blackboard
    bb.getInstance():removeData("game")
    -- remove playerDrewCard from bb
    bb.getInstance():removeData("playerDrewCard")
end

return state
