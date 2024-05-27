local lib = require("Flin.lib")

-- --- @param e keyDownEventData
-- local function keyDownCallback(e)
--     if e.isAltDown then
--         if e.keyCode == tes3.scanCode["o"] then
--             local t = lib.getLookedAtReference()
--             if t then
--                 local refBelow = lib.FindRefBelow(t)
--                 if refBelow then
--                     local position = lib.findPlayerPosition(refBelow)
--                     lib.DEBUG_ShowMarkerAt(position)
--                 end
--             end
--         end
--     end
-- end
-- event.register(tes3.event.keyDown, keyDownCallback)


-- /////////////////////////////////////////////////////////////////////////////////////////
-- ////////////// CONFIG
require("Flin.mcm")
