--[[
		Mod Compare Tooltip
		Author: rfuzzo

		This mod adds compare tooltips to inventory items against equipped items of the same category.
]] --

local config = require("rfuzzo.CompareTooltip.config")
local lock = false

--[[
    compares two strings popup child fields
		and returns a comparison result integer
		comparison options:
			a) scalars: 	28 vs 1 or 3.00 vs 3.00)
			b) ranges: 		1 - 11 vs 4 - 5)
			c) ratios:		300/300 vs 400/400
		status: 		0 (equal), 1 (better), 2 (worse)
]]
--- @param curText string
--- @param equText string
--- @param elementName string
local function compare_text(curText, equText, elementName)
	local status = 0

	-- calculate compare factors
	local equ = tonumber(equText)
	local cur = nil
	if (equ ~= nil) then -- (a) check scalars
		-- if that worked, then the current one will work as well
		cur = tonumber(curText)
		-- mwse.log("[ CE ]   scalar comparison (" .. obj.id .. ") " .. cur .. " vs " .. equ)
	elseif (string.find(equText, "-")) then -- (b) check ranges
		-- what IS a better range?
		-- average
		local split = string.split(equText)
		if (#split == 3) then
			local first = tonumber(split[1])
			local last = tonumber(split[3])

			if (first ~= nil and last ~= nil) then
				equ = (last + first)
				-- if that worked, then the current one will work as well
				split = string.split(curText)
				if (#split == 3) then
					first = tonumber(split[1])
					last = tonumber(split[3])

					if (first ~= nil and last ~= nil) then
						cur = (last + first)
						-- mwse.log("[ CE ]   range comparison (" .. obj.id .. ") " .. cur .. " vs " .. equ)
					end
				end
			end
		end
	elseif (string.find(equText, "/")) then -- (b) check ratio
		-- calculate ratio? (not necessarily a good indicator)
		-- for now, calculate the highest last value
		local split = string.split(equText, "/")
		if (#split == 2) then
			local first = tonumber(split[1])
			local last = tonumber(split[2])
			if (first ~= nil and last ~= nil) then
				equ = last
				-- if that worked, then the current one will work as well
				split = string.split(curText, "/")
				first = tonumber(split[1])
				last = tonumber(split[2])
				if (first ~= nil and last ~= nil) then
					cur = last
					-- mwse.log("[ CE ]   ratio comparison (" .. obj.id .. ") " .. cur .. " vs " .. equ)
				end
			end
		end
	end

	-- compare
	if (cur ~= nil and equ ~= nil) then
		-- is bigger always better?
		local isReversed = false
		if (elementName == "HelpMenu_weight") then
			isReversed = true
		end
		if (cur > equ) then
			if isReversed then
				status = 2
			else
				status = 1
			end
		elseif (cur < equ) then
			if isReversed then
				status = 1
			else
				status = 2
			end
		end
	end

	return status
end

--[[
    Find an item to compare for a given object
]]
--- @param e uiObjectTooltipEventData
local function find_compare_object(e)
	-- don't do anything for non-inventory tile objects
	-- TODO figure out different tooltips for looked-at objects vs inventory
	-- local reference = e.reference
	-- if (reference ~= nil) then
	-- 	return
	-- end

	local obj = e.object

	--[[
  	filter to object types:
		armor				1330467393
		weapon			1346454871
		clothing		1414483011
		TODO not supported yet:
		ammunition	1330466113
		lockpick		1262702412
		probe				1112494672
	]]
	local objectType = obj.objectType
	if (objectType ~= 1330467393 and objectType ~= 1346454871 and objectType ~= 1414483011) then
		-- mwse.log("[ CE ] not supported type: " .. tostring(objectType))
		return
	end
	-- redundant check
	if (obj.slotName == nil and obj.typeName == nil) then
		-- mwse.log("[ CE ] <<<<< " .. obj.id .. " cannot be equipped")
		return
	end

	-- if equipped, return
	local isEquipped = tes3.player.object:hasItemEquipped(obj)
	if (isEquipped) then
		-- mwse.log("[ CE ] <<<<< " .. obj.id .. " is equipped")
		return
	end

	-- get corresponding Equipped
	local stack = tes3.getEquippedItem({
		actor = tes3.player,
		objectType = obj.objectType,
		slot = obj.slot,
		-- type = obj.type,
	})
	if (stack == nil) then
		-- mwse.log("[ CE ] <<<<< " .. obj.id .. " nothing equipped found for slot")
		return
	end

	-- found an item to compare against
	local equipped = stack.object
	-- mwse.log("[ CE ] Found equipped item: %s (for %s)", equipped.id, obj.id)

	-- if the weapon types don't match, don't compare
	-- marksmanBow 	9 	Marksman, Bow
	-- marksmanCrossbow 	10 	Marksman, Crossbow
	-- marksmanThrown 	11 	Marksman, Thrown
	-- arrow 	12 	Arrows
	-- bolt 	13 	Bolts
	local curWeapType = tonumber(obj.type)
	local equWeapType = tonumber(equipped.type)
	if (curWeapType ~= nil and equWeapType ~= nil) then
		-- mwse.log("[ CE ] weap type: %s (for %s)", curWeapType, equWeapType)
		if (curWeapType < 9 and equWeapType > 8) then
			return
		end
		if (equWeapType < 9 and curWeapType > 8) then
			return
		end
	end

	return stack
end

--[[
    Sets the color of an element by status
]]
--- @param element tes3uiElement
--- @param status integer
local function set_color(element, status)
	local color = "normal_color"
	if (status == 1) then
		color = "fatigue_color" -- better
	elseif (status == 2) then
		color = "health_color" -- worse
	end
	-- update color
	if (color ~= "normal_color") then
		element.color = tes3ui.getPalette(color)
	end
end

--[[
    Creates the inline compare tooltip
]]
--- @param e uiObjectTooltipEventData
--- @param stack tes3equipmentStack 
local function create_inline(e, stack)
	-- create equipped tooltip to get the fields
	local equTooltip = tes3ui.createTooltipMenu { item = stack.object, itemData = stack.itemData } -- equiped item
	local equTable = {}
	for _, element in pairs(equTooltip:findChild('PartHelpMenu_main').children) do
		if (element.text ~= nil and element.name ~= nil) then
			equTable[element.name] = element.text
		end
	end
	-- UI Expansion support
	-- TODO check if installed I guess
	local uiExpElement = equTooltip:findChild('UIEXP_Tooltip_IconGoldBlock')
	if (uiExpElement ~= nil) then
		for _, element in pairs(uiExpElement.children) do
			if (element.text ~= nil and element.text ~= '') then
				equTable['UIEXP_Tooltip_IconGoldBlock'] = element.text
			end
		end
	end
	uiExpElement = equTooltip:findChild('UIEXP_Tooltip_IconWeightBlock')
	if (uiExpElement ~= nil) then
		for _, element in pairs(equTooltip:findChild('UIEXP_Tooltip_IconWeightBlock').children) do
			if (element.text ~= nil and element.text ~= '') then
				equTable['UIEXP_Tooltip_IconWeightBlock'] = element.text
			end
		end
	end

	-- create this tooltip again but don't raise the event
	lock = true
	local tooltip = tes3ui.createTooltipMenu { item = e.object, itemData = e.itemData } -- current item
	lock = false

	-- compare all properties
	for _, element in pairs(tooltip:findChild('PartHelpMenu_main').children) do
		local eText = equTable[element.name]
		-- do not compare new fields
		if (eText == nil) then
			goto continue2
		end
		-- do not compare fields without a text TODO improve this somehow?
		if (eText == nil) then
			goto continue2
		end
		local cText = element.text
		-- TODO: investigate mod compatibility
		-- do not compare the type in vanilla (UI expansion is handled by the next check)
		if (string.find(cText, "Type: ")) then
			goto continue2
		end
		-- do not compare fields without a colon
		local _, j = string.find(cText, ":")
		if (j == nil) then
			goto continue2
		end

		eText = string.sub(eText, j + 2)
		cText = string.sub(cText, j + 2)

		-- Compare
		local status = compare_text(cText, eText, element.name)
		if (config.useColors) then
			set_color(element, status)
		end

		-- add arrows
		local icon = ""
		if (status == 1) then
			icon = "textures/menu_scroll_up.dds" -- better
		elseif (status == 2) then
			icon = "textures/menu_scroll_down.dds" -- worse
		end
		if (icon ~= "") then
			local img = element:createImage{ path = icon }
			img.absolutePosAlignX = 0.98
			img.absolutePosAlignY = 2.5
			img.imageScaleX = 0.5
			img.imageScaleY = 0.5
		end

		if (not config.useMinimal) then
			-- add compare text
			element.text = element.text .. " (" .. eText .. ")"
		end

		-- icon hack
		element.text = element.text .. "     "
		element:updateLayout()

		::continue2::
	end

	-- UI Expansion support
	uiExpElement = equTooltip:findChild('UIEXP_Tooltip_IconGoldBlock')
	if (uiExpElement ~= nil) then
		for _, element in pairs(uiExpElement.children) do
			if (element.text ~= nil and element.text ~= '') then
				local eText = equTable['UIEXP_Tooltip_IconGoldBlock']
				local cText = element.text
				-- Compare
				local status = compare_text(cText, eText, element.name)
				if (config.useColors) then
					set_color(element, status)
				end
				if (config.useMinimal) then

				else
					-- add compare text
					element.text = element.text .. " (" .. eText .. ")"
				end
			end
		end
	end
	uiExpElement = equTooltip:findChild('UIEXP_Tooltip_IconWeightBlock')
	if (uiExpElement ~= nil) then
		for _, element in pairs(uiExpElement.children) do
			if (element.text ~= nil and element.text ~= '') then
				local eText = equTable['UIEXP_Tooltip_IconWeightBlock']
				local cText = element.text
				-- Compare
				local status = compare_text(cText, eText, element.name)
				if (config.useColors) then
					set_color(element, status)
				end
				if (config.useMinimal) then

				else
					-- add compare text
					element.text = element.text .. " (" .. eText .. ")"
				end
			end
		end
	end

	tooltip:updateLayout()
end

--[[
    main mod
]]
--- @param e uiObjectTooltipEventData
local function uiObjectTooltipCallback(e)
	if (not config.enableMod) then
		return
	end
	if (lock) then
		return
	end
	local obj = e.object
	if (obj == nil) then
		return
	end
	-- no item found to compare to
	local stack = find_compare_object(e)
	if (stack == nil) then
		-- TODO then it's always better?
		return
	end

	if (config.useInlineTooltips) then
		create_inline(e, stack)
	else
		-- TODO side-by-side comparison
	end
end

--[[
    Init mod
]]
--- @param e initializedEventData
local function initializedCallback(e)
	if (config.enableMod) then
		-- init mod
		event.register(tes3.event.uiObjectTooltip, uiObjectTooltipCallback, { priority = -110 })
		mwse.log("[ CE ] %s v%.1f Initialized", config.mod, config.version)
	end
end

event.register(tes3.event.initialized, initializedCallback)

--[[
		Handle mod config menu.
]]
require("rfuzzo.CompareTooltip.mcm")
