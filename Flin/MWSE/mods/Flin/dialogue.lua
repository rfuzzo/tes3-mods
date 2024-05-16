local game = require("Flin.game")

local this = {}

--- A function designed to be called from a dialogue result.
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
            -- TODO set wager

            -- exit dialogue
            npc_menu:destroy()
            tes3ui.leaveMenuMode()
            game.setupGame(reference)
        else
            tes3.messageBox("You need a Flin deck to play.")
        end
    end
end

return this
