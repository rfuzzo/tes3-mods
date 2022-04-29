local defaultConfig = {
	mod = "MWSE Always First Equip",
	id = "AFE",
	file = "alwaysfirstequip",
	version = 1.0,
	author = "rfuzzo",
}

local mwseConfig = mwse.loadConfig(defaultConfig.file, defaultConfig)

return mwseConfig;
