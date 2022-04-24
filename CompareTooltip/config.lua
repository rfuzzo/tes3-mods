local defaultConfig = {
	mod = "MWSE Compare Tooltip",
	id = "CTT",
	file = "compareTooltip",
	version = 1.0,
	author = "rfuzzo",

	enableMod = true,
	-- useInlineTooltips = true, -- or comparison

	useColors = true,
	useArrows = true,
	useParens = true,
}

local mwseConfig = mwse.loadConfig(defaultConfig.file, defaultConfig)

return mwseConfig;
