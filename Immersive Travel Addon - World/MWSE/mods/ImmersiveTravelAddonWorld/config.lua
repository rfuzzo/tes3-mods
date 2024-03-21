local defaultConfig = {
    mod = "Immersive Travel World Addon",
    id = "ITWA",
    version = 1.0,
    author = "rfuzzo",
    -- configs
    logLevel = "INFO",
    modEnabled = true,
    -- configs
    spawnChance = 10,
    spawnExlusionRadius = 2,
    spawnRadius = 3,
    cullRadius = 4,
    budget = 100
}

return mwse.loadConfig("ImmersiveTravelAddonWorld", defaultConfig)
