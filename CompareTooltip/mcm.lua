--- Setup MCM.
local function registerModConfig()
	local config = require("rfuzzo.CompareTooltip.config")
	local template = mwse.mcm.createTemplate(config.mod)
	template:saveOnClose(config.file, config)
	template:register()

	local page = template:createSideBarPage({ label = "Settings" })
	page.sidebar:createInfo{ text = ("%s v%.1f\n\nBy %s"):format(config.mod, config.version, config.author) }

	local settings = page:createCategory("Settings")

	settings:createOnOffButton({
		label = "Enable Mod",
		description = "Enable the mod.",
		variable = mwse.mcm.createTableVariable { id = "enableMod", table = config },
	})

	-- settings:createOnOffButton({
	-- 	label = "Use Inline Tooltips",
	-- 	description = "Use inline tooltips instead of a full compare popup.",
	-- 	variable = mwse.mcm.createTableVariable { id = "useInlineTooltips", table = config },
	-- })

	settings:createOnOffButton({
		label = "Display Colors",
		description = "Use colored comparisons.",
		variable = mwse.mcm.createTableVariable { id = "useColors", table = config },
	})

	settings:createOnOffButton({
		label = "Display Parentheses",
		description = "Display parenthese in comparisons",
		variable = mwse.mcm.createTableVariable { id = "useParens", table = config },
	})

	settings:createOnOffButton({
		label = "Display Arrows",
		description = "Display arrows in comparisons.",
		variable = mwse.mcm.createTableVariable { id = "useArrows", table = config },
	})

end

event.register("modConfigReady", registerModConfig)
