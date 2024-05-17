local logger = require("logging.logger")

--- Setup MCM.
local function registerModConfig()
    local config = require("Flin.config")
    if not config then
        return
    end

    local log = logger.getLogger(config.mod)
    local template = mwse.mcm.createTemplate(config.mod)
    template:saveOnClose("Flin", config)

    local page = template:createSideBarPage({ label = "Settings" })
    page.sidebar:createInfo {
        text = ("%s v%.1f\n\nBy %s"):format(config.mod, config.version,
            config.author)
    }

    local settingsPage = page:createCategory("Settings")
    local generalCategory = settingsPage:createCategory("General")

    generalCategory:createDropdown {
        label = "Logging Level",
        description = "Set the log level.",
        options = {
            { label = "TRACE", value = "TRACE" },
            { label = "DEBUG", value = "DEBUG" },
            { label = "INFO",  value = "INFO" }, { label = "WARN", value = "WARN" },
            { label = "ERROR", value = "ERROR" }, { label = "NONE", value = "NONE" }
        },
        variable = mwse.mcm.createTableVariable {
            id = "logLevel",
            table = config
        },
        callback = function(self)
            if log ~= nil then log:setLogLevel(self.variable.value) end
        end
    }

    generalCategory:createKeyBinder({
        label = "Play a card keybind",
        description = "Assign a new keybind.",
        variable = mwse.mcm.createTableVariable {
            id = "openkeybind",
            table = config
        },
        allowCombinations = true
    })


    template:register()
end

event.register("modConfigReady", registerModConfig)
