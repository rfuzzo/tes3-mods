local config = require("rfuzzo.CompareTooltip.config")
local common = require("rfuzzo.CompareTooltip.common")

local isUIExpansionInstalled = tes3.isLuaModActive("UI Expansion")

local this = {}

--[[
    caches uiexpansion label text for element id
]]
--- @param id string
--- @param equTooltip tes3uiElement
--- @param equTable table
function this.uiexpansion_cache(equTooltip, id, equTable)
	if (not isUIExpansionInstalled) then
		return
	end

	local uiExpElement = equTooltip:findChild(id)
	if (uiExpElement ~= nil) then
		for _, element in pairs(uiExpElement.children) do
			if (element.text ~= nil and element.text ~= '') then
				equTable[id] = element.text
			end
		end
	end
end

--[[
    updates uiexpansion label with comparisons
]]
--- @param id string
--- @param equTooltip tes3uiElement
--- @param equTable table
function this.uiexpansion_update(equTooltip, id, equTable)
	if (not isUIExpansionInstalled) then
		return
	end

	local uiExpElement = equTooltip:findChild(id)
	if (uiExpElement ~= nil) then
		for _, element in pairs(uiExpElement.children) do
			if (element.text ~= nil and element.text ~= '') then
				local eText = equTable[id]
				local cText = element.text

				-- Compare
				local status = common.compare_text(cText, eText, element.name)
				common.set_color(element, status)

				if (not config.useMinimal) then
					-- add compare text
					element.text = "  " .. element.text .. " (" .. eText .. ")"
				end

				element:updateLayout()
			end
		end
	end
end

return this
