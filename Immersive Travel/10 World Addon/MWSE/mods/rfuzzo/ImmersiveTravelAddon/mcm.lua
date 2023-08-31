local logger = require("logging.logger")

--- Setup MCM.
local function registerModConfig()
    local config = require("rfuzzo.ImmersiveTravelAddon.config")
    local log = logger.getLogger(config.mod)
    local template = mwse.mcm.createTemplate(config.mod)
    template:saveOnClose("ImmersiveTravelAddon", config)

    local page = template:createSideBarPage({label = "Settings"})
    page.sidebar:createInfo{
        text = ("%s v%.1f\n\nBy %s"):format(config.mod, config.version,
                                            config.author)
    }

    local settingsPage = page:createCategory("Settings")
    local generalCategory = settingsPage:createCategory("General")

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

    -- //////////////////////

    generalCategory:createSlider({
        label = "Spawn Chance",
        description = "Chance a mount is spawned in the world",
        min = 1,
        max = 100,
        step = 1,
        jump = 10,
        variable = mwse.mcm.createTableVariable {
            id = "spawnChance",
            table = config
        }
    })

    generalCategory:createSlider({
        label = "Spawn Exlusion Radius",
        description = "The radius in cells a mount cannot be spawned around another mount",
        min = 1,
        max = 40,
        step = 1,
        jump = 10,
        variable = mwse.mcm.createTableVariable {
            id = "spawnExlusionRadius",
            table = config
        }
    })

    generalCategory:createSlider({
        label = "Spawn Radius",
        description = "Radius within which mounts are spawned around player",
        min = 1,
        max = 40,
        step = 1,
        jump = 10,
        variable = mwse.mcm.createTableVariable {
            id = "spawnRadius",
            table = config
        }
    })

    generalCategory:createSlider({
        label = "Reference Budget",
        description = "The amount of mounts allowed at one time",
        min = 1,
        max = 100,
        step = 1,
        jump = 10,
        variable = mwse.mcm.createTableVariable {id = "budget", table = config}
    })

    generalCategory:createSlider({
        label = "Cull Radius",
        description = "The distance in cells after which mounts get destroyed",
        min = 1,
        max = 100,
        step = 1,
        jump = 10,
        variable = mwse.mcm.createTableVariable {
            id = "cullRadius",
            table = config
        }
    })

    template:register()

end

event.register("modConfigReady", registerModConfig)
