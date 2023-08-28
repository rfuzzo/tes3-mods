local defaultConfig = {
    mod = "Immersive Travel Editor",
    id = "IT",
    version = 1.0,
    author = "rfuzzo",
    -- configs
    logLevel = "INFO",
    grain = 20,
    traceOnSave = true
}

return mwse.loadConfig("ImmersiveTravelEditor", defaultConfig)
