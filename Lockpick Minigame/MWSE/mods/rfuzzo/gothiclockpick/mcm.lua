local function registerModConfig()
    local config = require("rfuzzo.gothiclockpick.config")
    local template = mwse.mcm.createTemplate({ name = "Gothic 2 Lockpicking" })
    template:saveOnClose("gothiclockpick", config)
    template:register()

    local page = template:createSideBarPage({ label = "Settings" })

    page.sidebar:createInfo({
        text = (
            "Gothic 2 Lockpicking v1.1.0\n"
            .. "By rfuzzo\n\n"
            .. "Implements a gothic-like lockpicking minigame. Try to guess the correct sequence of right or left nudges to pick the lock open!\n\n"
        ),
    })

    local settings = page:createCategory("Settings")

    settings:createYesNoButton({
        label = "Enable Mod",
        description =
            "If this setting is enabled, the mod is enabled.\n" ..
            "\n" ..
            "If this setting is disabled, the mod is disabled.\n" ..
            "\n" ..
            "Default: yes",
        variable = mwse.mcm.createTableVariable {
            id = "enabled",
            table = config
        },
    })

    settings:createYesNoButton({
        label = "Enable Debug mode",
        description =
            "If this setting is enabled, debug prints are enabled.\n" ..
            "\n" ..
            "If this setting is disabled, debug prints are disabled.\n" ..
            "\n" ..
            "Default: no",
        variable = mwse.mcm.createTableVariable {
            id = "debug",
            table = config
        },
    })

    settings:createSlider({
        label = "XP Amount per Lockpick Attempt",
        description = (
            "The amount of experience gained per lockpicking attempt by choosing an arrow.\n\n"
            .. "Default: 1"
        ),
        min = 0,
        max = 32,
        step = 1,
        jump = 4,
        variable = mwse.mcm.createTableVariable({
            id = "xpAttempt",
            table = config,
        }),
    })

    settings:createSlider({
        label = "XP Amount per Lockpick Success",
        description = (
            "The amount of experience gained after successfully picking the lock.\n\n"
            .. "Default: 2"
        ),
        min = 0,
        max = 32,
        step = 1,
        jump = 4,
        variable = mwse.mcm.createTableVariable({
            id = "xpSuccess",
            table = config,
        }),
    })

    settings:createSlider({
        label = "Chance No XP Gain",
        description = (
            "The chance that no experience is gained when attempting to pick a lock by choosing an arrow.\n\n"
            .. "Default: 75"
        ),
        min = 0,
        max = 100,
        step = 2,
        jump = 10,
        variable = mwse.mcm.createTableVariable({
            id = "xpChanceNone",
            table = config,
        }),
    })

    settings:createSlider({
        label = "Condition Loss On Failure",
        description = (
            "The amount of extra condition lost after a failed lockpicking attempt.\n\n"
            .. "Default: 1"
        ),
        min = 0,
        max = 32,
        step = 1,
        jump = 4,
        variable = mwse.mcm.createTableVariable({
            id = "condFail",
            table = config,
        }),
    })

    settings:createSlider({
        label = "Chance no condition loss",
        description = (
            "The chance that no condition is lost when attempting to pick a lock by choosing an arrow.\n\n"
            .. "Default: 75"
        ),
        min = 0,
        max = 100,
        step = 2,
        jump = 10,
        variable = mwse.mcm.createTableVariable({
            id = "condChanceNone",
            table = config,
        }),
    })

    settings:createKeyBinder({
        label = "Assign Keybind for Right Arrow",
        description = "Assign a new keybind for the right arrow.",
        variable = mwse.mcm.createTableVariable({
            id = "keybindRight",
            table = config,
        }),
        allowCombinations = false,
    })

    settings:createKeyBinder({
        label = "Assign Keybind for Left Arrow",
        description = "Assign a new keybind for the left arrow.",
        variable = mwse.mcm.createTableVariable({
            id = "keybindLeft",
            table = config,
        }),
        allowCombinations = false,
    })
end

event.register("modConfigReady", registerModConfig)
