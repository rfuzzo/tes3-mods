local defaultConfig = {
    enabled = true,
    debug = false,
    xpAttempt = 1,
    xpSuccess = 2,
    xpChanceNone = 75,
    condFail = 1,
    condChanceNone = 75,
    keybindRight = {
        keyCode = tes3.scanCode.keyRight,
        isShiftDown = false,
        isAltDown = false,
        isControlDown = false,
    },
    keybindLeft = {
        keyCode = tes3.scanCode.keyLeft,
        isShiftDown = false,
        isAltDown = false,
        isControlDown = false,
    },
}

local mwseConfig = mwse.loadConfig("gothiclockpick", defaultConfig)

return mwseConfig;