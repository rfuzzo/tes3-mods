local game = require("Flin.game")
local lib = require("Flin.lib")

local this = {}

--- @param reference tes3reference The reference the dialogue is running on.
--- @param dialogue tes3dialogue The parent dialogue for our info.
--- @param info tes3dialogueInfo The specific INFO object that is being executed.
function this.buyDeck(reference, dialogue, info)
    local goldCount = tes3.getPlayerGold()
    local deckPrice = 120
    if goldCount < deckPrice then
        tes3.messageBox("You don't have enough gold")
        return
    end

    tes3.messageBox("You bought a Flin deck for 120 gold.")
    tes3.addItem({ reference = tes3.player, item = "flin_deck_20", count = 1 })
    tes3.playSound({ sound = "Item Up" })
end

--- @param reference tes3reference The reference the dialogue is running on.
--- @param dialogue tes3dialogue The parent dialogue for our info.
--- @param info tes3dialogueInfo The specific INFO object that is being executed.
function this.enter(reference, dialogue, info)
    local npc_menu = tes3ui.getMenuOnTop()
    if npc_menu and npc_menu.name == "MenuDialog" then
        -- check if flin_deck_20 is in inventory of player
        local player = tes3.player
        local hasDeck = player.object.inventory:contains("flin_deck_20")
        if hasDeck then
            local gold = 1

            -- add slider ui with inventory money
            local buttons = {}
            table.insert(
                buttons,
                {
                    text = "Yes",
                    callback = function()
                        -- exit dialogue
                        npc_menu:destroy()
                        tes3ui.leaveMenuMode()

                        -- store the gold in the pot
                        tes3.removeItem({ reference = tes3.player, item = "Gold_001", count = gold })
                        tes3.playSound({ sound = "Item Gold Up" })
                        local g = game:new(gold * 2, tes3.makeSafeObjectHandle(reference))

                        g:PushState(lib.GameState.SETUP)
                    end
                })
            tes3ui.showMessageMenu({
                header = "Care for a round of Flin?",
                message = "Start game",
                buttons = buttons,
                cancels = true,
                customBlock = function(parent)
                    -- money slider
                    local goldCount = tes3.getPlayerGold()

                    local slider = parent:createSlider({
                        current = gold,
                        max = goldCount,
                        step = 1,
                        jump = 10
                    })
                    slider.width = 256

                    local scaleLabel = parent:createLabel({
                        text = string.format("Gold to bet: %d", gold)
                    })

                    slider:register("PartScrollBar_changed", function(e)
                        gold = slider:getPropertyInt("PartScrollBar_current")
                        scaleLabel.text = string.format("Gold to bet: %d", gold)
                    end)
                end,
            })
        else
            tes3.messageBox(
                "You need a deck of Flin cards to play. You should be able to buy one from the local publican.")
        end
    end
end

return this
