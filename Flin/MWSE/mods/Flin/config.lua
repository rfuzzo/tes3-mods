local defaultConfig = {
    mod = "Flin",
    id = "FLI",
    version = 1.0,
    author = "rfuzzo",
    -- configs
    logLevel = "INFO",
    -- keybinds
    openkeybind = { keyCode = tes3.scanCode["o"] },
}

return mwse.loadConfig("Flin", defaultConfig)
