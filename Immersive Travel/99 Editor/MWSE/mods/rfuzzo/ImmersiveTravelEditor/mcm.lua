local logger = require("logging.logger")
local log = logger.getLogger("Immersive Travel Editor")

--- Setup MCM.
local function registerModConfig()
    local config = require("rfuzzo.ImmersiveTravelEditor.config")
    local template = mwse.mcm.createTemplate(config.mod)
    template:saveOnClose("ImmersiveTravelEditor", config)

    local page = template:createSideBarPage({label = "Settings"})
    page.sidebar:createInfo{
        text = ("%s v%.1f\n\nBy %s"):format(config.mod, config.version,
                                            config.author)
    }

    local settingsPage = page:createCategory("Settings")
    local generalCategory = settingsPage:createCategory("General")

    generalCategory:createSlider({
        label = "Editor resolution",
        description = "Editor resolution, the higher the faster but less correct",
        min = 1,
        max = 100,
        step = 1,
        jump = 10,
        variable = mwse.mcm.createTableVariable {id = "grain", table = config}
    })

    generalCategory:createOnOffButton({
        label = "Trace on Save",
        description = "Trace on Save.",
        variable = mwse.mcm.createTableVariable {
            id = "traceOnSave",
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
