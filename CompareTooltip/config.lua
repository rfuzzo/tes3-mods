local defaultConfig = {
	mod = "MWSE Compare Tooltip",
	id = "CTT",
	file = "compareTooltip",
	version = 1.0,
	author = "rfuzzo",

	enableMod = true,
	-- useInlineTooltips = true, -- or comparison

	useColors = true, -- or not
	useMinimal = false, -- if yes: only display arrows, if no: display arrows and numbers
}

local mwseConfig = mwse.loadConfig(defaultConfig.file, defaultConfig)

return mwseConfig;
