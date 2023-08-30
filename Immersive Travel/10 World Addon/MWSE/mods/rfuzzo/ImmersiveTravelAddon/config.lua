local defaultConfig = {
    mod = "Immersive Travel World Addon",
    id = "IT",
    version = 1.0,
    author = "rfuzzo",
    -- configs
    logLevel = "INFO",
    -- configs
    spawnChance = 10,
    spawnExlusionRadius = 8200,
    spawnRadius = 2,
    cullRadius = 2,
    budget = 100
}

return mwse.loadConfig("ImmersiveTravelAddon", defaultConfig)
