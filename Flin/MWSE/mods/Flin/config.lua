local defaultConfig = {
    mod = "Flin",
    id = "FLI",
    version = 1.0,
    author = "rfuzzo",
    -- configs
    logLevel = "INFO",
    -- keybinds
    openkeybind = { keyCode = tes3.scanCode["o"] },
    enableHints = false,
    enableMessages = true,
}

return mwse.loadConfig("Flin", defaultConfig)
