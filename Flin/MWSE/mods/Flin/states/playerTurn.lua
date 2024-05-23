local config = require("Flin.config")
local lib = require("Flin.lib")
local log = lib.log

local AbstractState = require("Flin.states.abstractState")
local bb = require("Flin.blackboard")

---@class PlayerTurnState: AbstractState
---@field game FlinGame
local state = {}
setmetatable(state, { __index = AbstractState })

state.id_menu = tes3ui.registerID("flin:MenuHand")

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
---@return string
local function getHeaderText(game)
    ---@diagnostic disable-next-line: need-check-nil
    if config.enableHints then
        return string.format("Play a card (Trump is %s, you have %s points, NPC has %s points)",
            lib.suitToString(game.trumpSuit), game:GetPlayerPoints(), game:GetNpcPoints())
    end

    return "Play a card"
end

-- Cancel button callback.
function state.onCancel(e)
    local menu = tes3ui.findMenu(state.id_menu)

    if (menu) then
        tes3ui.leaveMenuMode()
        menu:destroy()
    end
end

---@param game FlinGame
local function createWindow(game)
    -- Return if window is already open
    if (tes3ui.findMenu(state.id_menu) ~= nil) then
        return
    end

    -- Create window and frame
    local dragFrame = false
    local menu = tes3ui.createMenu { id = state.id_menu, dragFrame = dragFrame, fixedFrame = true }
    if dragFrame then
        menu.text = "Play a card"
        menu.minHeight = 200
        menu.minWidth = 500
    end

    -- To avoid low contrast, text input windows should not use menu transparency settings
    menu.alpha = 1.0

    -- Create layout
    local input_label = menu:createLabel { text = getHeaderText(game) }
    input_label.borderBottom = 5

    -- local block = menu:createBlock {}
    local block = menu:createThinBorder {}
    block.autoHeight = true
    block.autoWidth = true
    block.childAlignX = 0.5 -- centre content alignment

    block.flowDirection = tes3.flowDirection.leftToRight
    for i, card in ipairs(game.playerHand) do
        local imagePath = lib.GetCardIconName(card.suit, card.value)
        if imagePath then
            local button = block:createImageButton({ idle = imagePath, over = imagePath, pressed = imagePath })

            button:register(tes3.uiEvent.mouseOver, function()
                local buttonText = string.format("%s %s", lib.suitToString(card.suit), lib.valueToString(card.value))
                local tooltip = tes3ui.createTooltipMenu()
                tooltip.autoHeight = true
                tooltip.autoWidth = true
                tooltip.wrapText = true
                local label = tooltip:createLabel { text = buttonText }
                label.autoHeight = true
                label.autoWidth = true
                label.wrapText = true
            end)
            button:register(tes3.uiEvent.mouseClick, function()
                game:PcPlayCard(card)

                tes3ui.leaveMenuMode()
                menu:destroy()

                -- TODO wait one second before updating
                timer.start({
                    duration = 1,
                    callback = function()
                        event.unregister(tes3.event.activate, state.activateCallback)
                        local nextState = game:evaluateTrick()
                        game:PushState(nextState)
                    end
                })
            end)
        end
    end



    local button_block = menu:createBlock {}
    button_block.widthProportional = 1.0 -- width is 100% parent width
    button_block.autoHeight = true
    button_block.childAlignX = 1.0       -- right content alignment
    button_block.childAlignX = 0.5
    button_block.paddingAllSides = 8

    -- only show if player has >= 66 points
    if game:GetPlayerPoints() >= 66 then
        local callButton = button_block:createButton({
            text = "Call the game",
            id = tes3ui.registerID("flin:callGame")
        })
        callButton:register("mouseClick", function()
            log:debug("Player calls the game")

            tes3ui.leaveMenuMode()
            menu:destroy()

            game:PushState(lib.GameState.GAME_END)
        end)
    end

    local button_cancel = button_block:createButton { text = tes3.findGMST("sCancel").value }
    button_cancel:register(tes3.uiEvent.mouseClick, state.onCancel)

    -- Final setup
    menu:updateLayout()
    tes3ui.enterMenuMode(state.id_menu)
end

---@param game FlinGame
local function playerDrawCard(game)
    if #game.playerHand == 5 or game:IsPhase2() then
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

    ---@diagnostic disable-next-line: need-check-nil
    local key = tes3.getKeyName(config.openkeybind.keyCode)
    tes3.messageBox("You draw: %s, press %s to play a card!", card:toString(), key)
end

--#region event callbacks

--- @param e keyDownEventData
local function KeyDownCallback(e)
    local game = bb.getInstance():getData("game") ---@type FlinGame

    if #game.playerHand == 5 or game:IsPhase2() then -- and not game:GetNpcTrickRef()
        createWindow(game)
    else
        tes3.messageBox("You must draw a card first")
    end
end

--- @param e activateEventData
function state.activateCallback(e)
    local game = bb.getInstance():getData("game") ---@type FlinGame

    if #game.playerHand == 5 or game:IsPhase2() then
        -- activate the trick
        if game:GetNpcTrickRef() and e.target.id == game:GetNpcTrickRef().id then
            -- hit the trick
            createWindow(game)
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
    -- register event callbacks
    local game = self.game

    if #game.playerHand == 5 or game:IsPhase2() then
        if game:GetNpcTrickRef() then
            tes3.messageBox("It's your turn, hit the trick!")
        else
            ---@diagnostic disable-next-line: need-check-nil
            local key = tes3.getKeyName(config.openkeybind.keyCode)
            tes3.messageBox("It's your turn, press %s to play a card!", key)
        end
    else
        tes3.messageBox("It's your turn, draw a card from the talon!")
    end

    -- register event callbacks
    event.register(tes3.event.activate, self.activateCallback)
    ---@diagnostic disable-next-line: need-check-nil
    event.register(tes3.event.keyDown, KeyDownCallback, { filter = config.openkeybind.keyCode })
    -- add game to blackboard for events
    bb.getInstance():setData("game", self.game)
    -- add check for player drew card to bb
end

function state:endState()
    -- unregister event callbacks
    event.unregister(tes3.event.activate, self.activateCallback)
    ---@diagnostic disable-next-line: need-check-nil
    event.unregister(tes3.event.keyDown, KeyDownCallback, { filter = config.openkeybind.keyCode })
    -- remove game from blackboard
    bb.getInstance():removeData("game")
end

return state
