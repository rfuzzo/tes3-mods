local config = require("rfuzzo.CompareTooltip.config")
local common = require("rfuzzo.CompareTooltip.common")

local isAshfallInstalled = tes3.isLuaModActive("mer.ashfall")

local this = {}

--[[
    caches ashfall label text for element id
]] --- @param id string
--- @param equTooltip tes3uiElement
--- @param equTable table
function this.ashfall_cache(equTooltip, id, equTable)
	if (not isAshfallInstalled) then
		return
	end

	local element = equTooltip:findChild(id)
	if (element ~= nil and element.text ~= nil) then
		equTable[id] = string.trim(element.text)
	end
end

--[[
    updates ashfall label with comparisons
]]
--- @param id string
--- @param equTooltip tes3uiElement
--- @param equTable table
function this.ashfall_update(equTooltip, id, equTable)
	if (not isAshfallInstalled) then
		return
	end

	local element = equTooltip:findChild(id)
	if (element ~= nil and element.text ~= nil) then
		local eText = equTable[id]
		local cText = element.text

		-- Compare
		local status = common.compare_text(cText, eText, element.name)
		common.set_color(element, status)
		-- set header color
		local headerID = string.sub(id, 0, string.len(id) - 5) .. "Header"
		local header = equTooltip:findChild(headerID)
		if (header ~= nil) then
			common.set_color(header, status)
			-- icon hack for arrows
			header.text = "  " .. header.text
			header:updateLayout()
		end

		common.set_arrows(element, status)

		if (not config.useMinimal) then
			-- add compare text
			element.text = element.text .. " (" .. eText .. ")"
		end

		-- icon hack for arrows
		element.text = element.text .. "     "

		element:updateLayout()
	end
end

return this
