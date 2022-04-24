--[[
		Mod Compare Tooltip
		Author: rfuzzo

		This mod adds compare tooltips to inventory items against equipped items of the same category.

		TODO:
			- Compare Key
			- arrows toggle ?
		BUGS:
			- do not compare alchemy tools
			- fix layout overflow for long words...
]] --
local config = require("rfuzzo.CompareTooltip.config")
local common = require("rfuzzo.CompareTooltip.common")
local ashfall = require("rfuzzo.CompareTooltip.module_ashfall")
local uiexpansion = require("rfuzzo.CompareTooltip.module_uiexpansion")

local lock = false

-- Make sure we have the latest MWSE version.
if (mwse.buildDate == nil) or (mwse.buildDate < 20220420) then
	event.register("initialized", function()
		tes3.messageBox("[ CE ]  Compare tooltips requires the latest version of MWSE. Please run MWSE-Updater.exe.")
	end)
	return
end

--- Find an item to compare for a given object
--- @param e uiObjectTooltipEventData
local function find_compare_object(e)
	-- don't do anything for non-inventory tile objects
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

	--[[
		if the weapon types don't match, don't compare
		marksmanBow 	9 	Marksman, Bow
		marksmanCrossbow 	10 	Marksman, Crossbow
		marksmanThrown 	11 	Marksman, Thrown
		arrow 	12 	Arrows
		bolt 	13 	Bolts
	]]
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

--- Creates the inline compare tooltip
--- @param e uiObjectTooltipEventData
--- @param stack tes3equipmentStack 
local function create_inline(e, stack)

	-- cache values
	-- create equipped tooltip to get the fields
	lock = true
	local equTooltip = tes3ui.createTooltipMenu { item = stack.object, itemData = stack.itemData } -- equiped item
	lock = false
	local equTable = {}
	for _, element in pairs(equTooltip:findChild('PartHelpMenu_main').children) do
		if (element.text ~= nil and element.name ~= nil) then
			equTable[element.name] = element.text
		end
	end

	-- UI Expansion support
	uiexpansion.uiexpansion_cache(equTooltip, 'UIEXP_Tooltip_IconGoldBlock', equTable)
	uiexpansion.uiexpansion_cache(equTooltip, 'UIEXP_Tooltip_IconWeightBlock', equTable)

	-- Ashfall support
	ashfall.ashfall_cache(equTooltip, 'Ashfall:ratings_warmthValue', equTable)
	ashfall.ashfall_cache(equTooltip, 'Ashfall:ratings_coverageValue', equTable)

	-- modify values
	-- create this tooltip again but don't raise the event
	lock = true
	local tooltip = tes3ui.createTooltipMenu { item = e.object, itemData = e.itemData } -- current item
	lock = false

	-- compare all toplevel properties
	for _, element in pairs(tooltip:findChild('PartHelpMenu_main').children) do

		-- checks
		-- do not compare the name field
		if (element.name == 'HelpMenu_name') then
			goto continue
		end
		local cText = element.text
		-- do not compare the type in vanilla (UI expansion is handled by the next check)
		if (string.find(cText, "Type: ")) then
			goto continue
		end
		-- do not compare fields without a colon
		local _, j = string.find(cText, ":")
		if (j == nil) then
			goto continue
		end
		local eText = equTable[element.name]
		-- do not compare fields without a text
		if (eText == nil) then
			goto continue
		end

		eText = string.sub(eText, j + 2)
		cText = string.sub(cText, j + 2)

		-- Compare
		local status = common.compare_text(cText, eText, element.name)
		common.set_color(element, status)
		common.set_arrows(element, status)

		if (not config.useMinimal) then
			-- add compare text
			element.text = element.text .. " (" .. eText .. ")"
		end

		-- icon hack for arrows
		element.text = "  " .. element.text .. "     "

		element:updateLayout()

		::continue::
	end

	-- UI Expansion support
	uiexpansion.uiexpansion_update(equTooltip, 'UIEXP_Tooltip_IconGoldBlock', equTable)
	uiexpansion.uiexpansion_update(equTooltip, 'UIEXP_Tooltip_IconWeightBlock', equTable)
	-- ashfall support support
	ashfall.ashfall_update(equTooltip, 'Ashfall:ratings_warmthValue', equTable)
	ashfall.ashfall_update(equTooltip, 'Ashfall:ratings_coverageValue', equTable)

	tooltip:updateLayout()
end

--- main mod
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

		-- set color to green
		local tt = e.tooltip
		for _, element in pairs(tt:findChild('PartHelpMenu_main').children) do
			-- checks
			-- do not compare the name field
			if (element.name == 'HelpMenu_name') then
				goto continue
			end
			local cText = element.text
			-- do not compare the type in vanilla (UI expansion is handled by the next check)
			if (string.find(cText, "Type: ")) then
				goto continue
			end
			-- do not compare fields without a colon
			local _, j = string.find(cText, ":")
			if (j == nil) then
				goto continue
			end

			-- Compare
			common.set_color(element, 1)
			common.set_arrows(element, 1)

			-- icon hack for arrows
			-- TODO this messes with the layout...
			element.text = "  " .. element.text .. "     "

			element:updateLayout()

			::continue::
		end

		-- UI Expansion support disabled here becasue annoying
		-- uiexpansion.uiexpansion_color_block(tt, 'UIEXP_Tooltip_IconGoldBlock', 1)
		-- uiexpansion.uiexpansion_color_block(tt, 'UIEXP_Tooltip_IconWeightBlock', 1)

		-- Ashfall support
		ashfall.ashfall_color_block(tt, 'Ashfall:ratings_warmthValue', 1)
		ashfall.ashfall_color_block(tt, 'Ashfall:ratings_coverageValue', 1)

		return
	end

	-- if (config.useInlineTooltips) then
	create_inline(e, stack)
	-- end
end

--[[
    Init mod
]]
--- @param e initializedEventData
local function initializedCallback(e)
	if (config.enableMod) then

		-- init mod
		common.mod_log("ashfall plugin active: %s", tostring(tes3.isLuaModActive("mer.ashfall")))
		common.mod_log("UI Expansion plugin active: %s", tostring(tes3.isLuaModActive("UI Expansion")))

		event.register(tes3.event.uiObjectTooltip, uiObjectTooltipCallback, { priority = -110 })
		common.mod_log("%s v%.1f Initialized", config.mod, config.version)
	end
end

event.register(tes3.event.initialized, initializedCallback)

--[[
		Handle mod config menu.
]]
require("rfuzzo.CompareTooltip.mcm")
