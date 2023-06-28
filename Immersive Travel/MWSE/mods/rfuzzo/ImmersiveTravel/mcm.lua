--- Setup MCM.
local function registerModConfig()
    local config = require("rfuzzo.ImmersiveTravel.config")
    local template = mwse.mcm.createTemplate(config.mod)
    template:saveOnClose("immersiveTravel", config)
    template:register()

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

end

event.register("modConfigReady", registerModConfig)
