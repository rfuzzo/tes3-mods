local configPath = "immersiveTravel"

local defaultConfig = {
    mod = "Immersive Travel",
    id = "IT",
    version = 1.0,
    author = "rfuzzo",
    -- configs
    speed = 3
}

return mwse.loadConfig(configPath, defaultConfig)
