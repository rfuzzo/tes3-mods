local logger = require("logging.logger")
local log = logger.getLogger("Immersive Travel")

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
        label = "Editor resolution",
        description = "The speed of the silt strider",
        min = 1,
        max = 100,
        step = 1,
        jump = 10,
        variable = mwse.mcm.createTableVariable {id = "grain", table = config}
    })

    -- generalCategory:createSlider({
    --     label = "Boat speed",
    --     description = "The speed of the boat",
    --     min = 1,
    --     max = 100,
    --     step = 1,
    --     jump = 10,
    --     variable = mwse.mcm.createTableVariable {
    --         id = "boatspeed",
    --         table = config
    --     }
    -- })

    -- generalCategory:createSlider({
    --     label = "Silt Strider turning speed",
    --     description = "The turning speed of the silt strider",
    --     min = 1,
    --     max = 100,
    --     step = 1,
    --     jump = 10,
    --     variable = mwse.mcm.createTableVariable {
    --         id = "turnspeed",
    --         table = config
    --     }
    -- })

    -- generalCategory:createSlider({
    --     label = "Boat turning speed",
    --     description = "The turning speed of the boat",
    --     min = 1,
    --     max = 100,
    --     step = 1,
    --     jump = 10,
    --     variable = mwse.mcm.createTableVariable {
    --         id = "boatturnspeed",
    --         table = config
    --     }
    -- })

    generalCategory:createOnOffButton({
        label = "Enable Editor",
        description = "Enable the editor.",
        variable = mwse.mcm.createTableVariable {
            id = "enableeditor",
            table = config
        }
    })

    generalCategory:createDropdown{
        label = "Logging Level",
        description = "Set the log level.",
        options = {
            {label = "TRACE", value = "TRACE"},
            {label = "DEBUG", value = "DEBUG"},
            {label = "INFO", value = "INFO"}, {label = "WARN", value = "WARN"},
            {label = "ERROR", value = "ERROR"}, {label = "NONE", value = "NONE"}
        },
        variable = mwse.mcm.createTableVariable {
            id = "logLevel",
            table = config
        },
        callback = function(self)
            if log ~= nil then log:setLogLevel(self.variable.value) end
        end
    }

    template:register()

end

event.register("modConfigReady", registerModConfig)