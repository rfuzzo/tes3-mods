local game = require("Flin.game")

-- dbg enter

---@param menu tes3uiElement
local function orderFlinButton(menu)
    timer.frame.delayOneFrame(function()
        if not menu then return end
        local flinButton = menu:findChild("rf_fln_game_button")
        local divider = menu:findChild("MenuDialog_divider")
        if not flinButton then return end
        flinButton.visible = true
        flinButton.disabled = false

        local topicsList = flinButton.parent
        local children = topicsList.children

        -- get index
        local index = 0
        for i, child in ipairs(children) do
            if child == divider then
                index = i
                break
            end
        end

        -- insert
        topicsList:reorderChildren(children[index + 1], flinButton, 1)
    end)
end

---@param menu tes3uiElement
---@param ref tes3reference
local function createFlinButton(menu, ref)
    local divider = menu:findChild("MenuDialog_divider")
    local topicsList = divider.parent
    local button = topicsList:createTextSelect({
        id = "rf_fln_game_button",
        text = "Flin"
    })
    button.widthProportional = 1.0
    button.visible = true
    button.disabled = false

    -- insert
    topicsList:reorderChildren(divider, button, 1)

    button:register("mouseClick", function()
        tes3.messageBox("Care for a round of flin?")
    end)
    menu:registerAfter("update", function()
        orderFlinButton(menu)
    end)

    debug.log("Flin button created")
end


-- upon entering the dialog menu, create the travel menu
---@param e uiActivatedEventData
local function onMenuDialog(e)
    -- local menuDialog = e.element
    -- local mobileActor = menuDialog:getPropertyObject("PartHyperText_actor") ---@cast mobileActor tes3mobileActor
    -- if mobileActor.actorType == tes3.actorType.npc then
    --     local ref = mobileActor.reference
    --     createFlinButton(menuDialog, ref)
    --     menuDialog:updateLayout()
    -- end
end
event.register("uiActivated", onMenuDialog, { filter = "MenuDialog" })

--- @param e loadedEventData
local function loadedCallback(e)
    local result = tes3.addTopic({
        topic = "Flin game"
    })
    debug.log(result)
end
event.register(tes3.event.loaded, loadedCallback)

--- @param e infoResponseEventData
local function infoResponseCallback(e)
    debug.log(e.dialogue.id)
    debug.log(e.info.id)
    tes3.messageBox("infoResponse dialogue %s", e.dialogue.id)
    tes3.messageBox("infoResponse info %s", e.info.id)

    if e.dialogue.id == "Flin game" then
        tes3.messageBox("Care for a round of Gwent?")
    end
end
event.register(tes3.event.infoResponse, infoResponseCallback)

--- @param e postInfoResponseEventData
local function postInfoResponseCallback(e)
    debug.log(e.dialogue.id)
    debug.log(e.info.id)
    tes3.messageBox("postInfoResponse dialogue %s", e.dialogue.id)
    tes3.messageBox("postInfoResponse info %s", e.info.id)

    if e.dialogue.id == "Flin game" then
        tes3.messageBox("Care for a round of Gwent?")
    end
end
event.register(tes3.event.postInfoResponse, postInfoResponseCallback)

--- @param e keyDownEventData
local function keyDownCallback(e)
    if e.keyCode == tes3.scanCode["o"] then
        -- TODO you can only enter a game at a table
        -- local ref = tes3.getPlayerTarget()
        -- if not ref then
        --     return
        -- end

        game.startGame(nil)
    end

    -- mock taking a card
    if e.keyCode == tes3.scanCode["l"] then
        game.playerTurn()
    end
end
event.register(tes3.event.keyDown, keyDownCallback)

-- TODO leave when out of range
