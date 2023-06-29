--- Setup MCM.
local function registerModConfig()
    local config = require("rfuzzo.ImmersiveTravel.config")
    local template = mwse.mcm.createTemplate(config.mod)
    template:saveOnClose("ImmersiveTravel", config)

    local page = template:createSideBarPage({label = "Settings"})
    page.sidebar:createInfo{
        text = ("%s v%.1f\n\nBy %s"):format(config.mod, config.version,
                                            config.author)
    }

    local settingsPage = page:createCategory("Settings")
    local generalCategory = settingsPage:createCategory("General")

    generalCategory:createSlider({
        label = "Mount speed",
        description = "The speed of the silt strider",
        min = 1,
        max = 100,
        step = 1,
        jump = 10,
        variable = mwse.mcm.createTableVariable {id = "speed", table = config}
    })

    generalCategory:createOnOffButton({
        label = "Enable Editor",
        description = "Enable the editor.",
        variable = mwse.mcm.createTableVariable {
            id = "enableeditor",
            table = config
        }
    })

    template:register()

end

event.register("modConfigReady", registerModConfig)
