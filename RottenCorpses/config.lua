local defaultConfig = {
	mod = "MWSE Rotten Corpses",
	id = "IRC",
	file = "rottenCorpses",
	version = 1.0,
	author = "rfuzzo",
}

local mwseConfig = mwse.loadConfig(defaultConfig.file, defaultConfig)

return mwseConfig;
