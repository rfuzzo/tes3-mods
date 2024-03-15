--- This script handles the main functionality of the MagicSynergies mod.
--- It applies and removes various effects based on the current environment and weather conditions.
--- The effects include wetness, cold, charged, and warm effects.

local effect_wet
local effect_cold
local effect_charged
local effect_warm

local id_wet = "rf_ms_rain"
-- resistances: fire
-- weaknesses: shock
-- damage increase: shock, frost
-- damage decrease: fire

local id_cold = "rf_ms_snow"
-- resistances: fire
-- weaknesses: frost
-- damage increase: frost
-- damage decrease: fire

local id_charged = "rf_ms_thunderstorm"
-- resistances:
-- weaknesses: shock
-- damage increase: shock
-- damage decrease:

local id_warm = "rf_ms_ashstorm"
-- resistances:
-- weaknesses: fire
-- damage increase: fire
-- damage decrease: frost

local FROST_THRESHOLD = 5
local SHOCK_THRESHOLD = 5
local FIRE_THRESHOLD = 5
local POISON_THRESHOLD = 5

--- @param id string
local function getSpellFromId(id)
    if id == id_wet then
        return effect_wet
    end
    if id == id_cold then
        return effect_cold
    end
    if id == id_charged then
        return effect_charged
    end
    if id == id_warm then
        return effect_warm
    end
end

--- @param reference tes3reference
--- @return number?
local function getWaterLevel(reference)
    if not reference.cell then
        return nil
    end
    if not reference.cell.waterLevel then
        return nil
    end

    local waterlevel = 0
    if reference.cell and reference.cell.isInterior and reference.cell.waterLevel then
        waterlevel = reference.cell.waterLevel
    end
    return waterlevel
end

--- @param mobile tes3mobileActor
--- @param effectname string
--- @return boolean
local function has_effect(mobile, effectname)
    local hasEffect = false

    local spells = tes3.getSpells({
        target = mobile.reference,
        spellType = tes3.spellType.ability,
        getActorSpells = true,
        getRaceSpells = false,
        getBirthsignSpells = false
    })
    for _, spell in pairs(spells) do
        if spell.id == effectname then
            hasEffect = true
            break
        end
    end

    return hasEffect
end

--- @param reference tes3reference
local function apply_effect(reference, effectname)
    if not has_effect(reference.mobile, effectname) then
        tes3.addSpell({
            reference = reference,
            spell = getSpellFromId(effectname)
        })
        mwse.log("Added effect to %s", reference)
    end
end

--- @param mobile tes3mobileActor
--- @param effectname string
local function remove_effect(mobile, effectname)
    if has_effect(mobile, effectname) then
        tes3.removeSpell({
            reference = mobile.reference,
            spell = getSpellFromId(effectname)
        })
        mwse.log("Removed effect from %s", mobile.reference)
    end
end

--- @param mobile tes3mobileActor
local function handleWetEffect(mobile)
    local reference = mobile.reference

    -- check if the actor is underwater
    local isUnderWater = false
    local waterlevel = getWaterLevel(reference)
    if waterlevel then
        isUnderWater = reference.position.z < waterlevel
    end

    -- check if weather is rain or thunder
    local weather = tes3.worldController.weatherController.currentWeather.index
    local isRain = weather == tes3.weather.rain or weather == tes3.weather.thunder
    if reference.cell and reference.cell.isInterior then
        isRain = false
    end

    -- apply the wetness effect
    if isUnderWater or isRain then
        apply_effect(reference, id_wet)
    elseif not isRain and not isUnderWater then
        remove_effect(mobile, id_wet)
    end
end

--- @param mobile tes3mobileActor
local function handleChargedEffect(mobile)
    local reference = mobile.reference

    -- check if weather is thunderstorm
    local isThunderstorm = tes3.worldController.weatherController.currentWeather.index == tes3.weather.thunder
    if reference.cell and reference.cell.isInterior then
        isThunderstorm = false
    end

    if isThunderstorm then
        apply_effect(reference, id_charged)
    else
        remove_effect(mobile, id_charged)
    end
end

--- @param mobile tes3mobileActor
local function handleColdEffect(mobile)
    local reference = mobile.reference

    -- check if weather is snow or blizzard
    local weather = tes3.worldController.weatherController.currentWeather.index
    local isSnowing = weather == tes3.weather.snow or weather == tes3.weather.blizzard
    if reference.cell and reference.cell.isInterior then
        isSnowing = false
    end

    if isSnowing then
        apply_effect(reference, id_cold)
    else
        remove_effect(mobile, id_cold)
    end
end

-- handle warm effect
--- @param mobile tes3mobileActor
local function handleWarmEffect(mobile)
    local reference = mobile.reference

    -- check if weather is ashstorm or blight
    local weather = tes3.worldController.weatherController.currentWeather.index
    local isAshstorm = weather == tes3.weather.ash or weather == tes3.weather.blight
    if reference.cell and reference.cell.isInterior then
        isAshstorm = false
    end

    if isAshstorm then
        apply_effect(reference, id_warm)
    else
        remove_effect(mobile, id_warm)
    end
end

-- TODO keep track of refs?

--- @param reference tes3reference
--- @param mobile tes3mobileActor
local function handleEnvironmentEffects(reference, mobile)
    if tes3.canCastSpells({ target = reference }) then
        handleWetEffect(mobile)
        handleChargedEffect(mobile)
        handleColdEffect(mobile)
        handleWarmEffect(mobile)
    end
end

--- @param e mobileActivatedEventData
local function mobileActivatedCallback(e)
    handleEnvironmentEffects(e.reference, e.mobile)
end
event.register(tes3.event.mobileActivated, mobileActivatedCallback)

--- @param e calcWalkSpeedEventData
local function calcWalkSpeedCallback(e)
    handleEnvironmentEffects(e.reference, e.mobile)
end
event.register(tes3.event.calcWalkSpeed, calcWalkSpeedCallback)



-- //////////////////////////////////////////////////////////////////
-- /////////////////////// ENVIRONMENT EVENTS ///////////////////////

--- @param reference tes3reference
--- @param id tes3.effect
--- @return number
local function get_threshold(reference, id)
    -- fire
    if id == tes3.effect.fireDamage then
        local threshold = FIRE_THRESHOLD
        -- if the actor is wet, the threshold is higher
        if has_effect(reference.mobile, id_wet) then
            threshold = threshold + 2
        end
        -- if the actor is cold, the threshold is higher
        if has_effect(reference.mobile, id_cold) then
            threshold = threshold + 2
        end
        -- if the actor is warm, the threshold is lower
        if has_effect(reference.mobile, id_warm) then
            threshold = threshold - 2
        end
        return threshold
    end

    -- frost
    if id == tes3.effect.frostDamage then
        local threshold = FROST_THRESHOLD
        -- if the actor is warm, the threshold is higher
        if has_effect(reference.mobile, id_warm) then
            threshold = threshold + 2
        end
        -- if the actor is wet, the threshold is lower
        if has_effect(reference.mobile, id_wet) then
            threshold = threshold - 2
        end
        -- if the actor is cold, the threshold is lower
        if has_effect(reference.mobile, id_cold) then
            threshold = threshold - 2
        end
        return threshold
    end

    -- shock
    if id == tes3.effect.shockDamage then
        local threshold = SHOCK_THRESHOLD
        -- if the actor is wet, the threshold is lower
        if has_effect(reference.mobile, id_wet) then
            threshold = threshold - 2
        end
        -- if the actor is charged, the threshold is lower
        if has_effect(reference.mobile, id_charged) then
            threshold = threshold - 2
        end

        return threshold
    end

    -- poison
    if id == tes3.effect.poison then
        local threshold = POISON_THRESHOLD
        return threshold
    end

    return 5
end

--- @param reference tes3reference
--- @param damage number
local function handle_shock(reference, damage)
    -- add damage to tempdata
    -- wetness already makes the actor weak to shock
    if not reference.tempData.rf_ms_shock_cooldown then
        if not reference.tempData.rf_ms_shock then
            reference.tempData.rf_ms_shock = 1
        else
            reference.tempData.rf_ms_shock = reference.tempData.rf_ms_shock + 1
        end

        reference.tempData.rf_ms_shock_cooldown = true
        timer.start({
            duration = 1,
            callback = function()
                reference.tempData.rf_ms_shock_cooldown = nil
            end
        })
    end

    local threshold = get_threshold(reference, tes3.effect.shockDamage)
    if reference.tempData.rf_ms_shock < threshold then
        -- reset tempdata
        reference.tempData.rf_ms_shock = 0
        -- add cooldown
        reference.tempData.rf_ms_shock_cooldown = true
        -- add vfx VFX_LightningHit IllusionHit
        tes3.createVisualEffect({ object = "VFX_LightningHit", lifespan = 5, reference = reference })

        -- shock damages fatigue
        tes3.messageBox("You are shocked!")
        timer.start({
            duration = 1,
            iterations = 5,
            callback = function()
                reference.mobile:applyFatigueDamage(20)
            end
        })

        -- remove effect after 5 seconds
        timer.start({
            duration = 5,
            callback = function()
                reference.tempData.rf_ms_shock_cooldown = nil
            end
        })
    end
end

--- @param reference tes3reference
--- @param attackerReference tes3reference
--- @param damage number
local function handle_fire(reference, attackerReference, damage)
    -- add damage to tempdata
    if not reference.tempData.rf_ms_fire_cooldown then
        if not reference.tempData.rf_ms_fire then
            reference.tempData.rf_ms_fire = 1
        else
            reference.tempData.rf_ms_fire = reference.tempData.rf_ms_fire + 1
        end

        -- mwse.log("Fire damage: %s", reference.tempData.rf_ms_fire)
        reference.tempData.rf_ms_fire_cooldown = true
        timer.start({
            duration = 1,
            callback = function()
                reference.tempData.rf_ms_fire_cooldown = nil
            end
        })
    end

    local threshold = get_threshold(reference, tes3.effect.fireDamage)
    if reference.tempData.rf_ms_fire < threshold then
        -- reset tempdata
        reference.tempData.rf_ms_fire = 0
        -- add cooldown
        reference.tempData.rf_ms_fire_cooldown = true
        -- add vfx VFX_DestructionHit
        tes3.createVisualEffect({ object = "VFX_FireShield", lifespan = 5, reference = reference })

        -- add burning effect
        -- 50 iterations of 0.1 seconds is 5 seconds
        -- 0.2 damage per iteration is 10 damage
        tes3.messageBox("You are burning!")
        timer.start({
            duration = 0.1,
            iterations = 50,
            callback = function()
                reference.mobile:applyDamage({
                    damage = 0.2,
                    applyArmor = false,
                    resistAttribute = tes3.effectAttribute.resistFire,
                    applyDifficulty = true,
                    playerAttack = attackerReference == tes3.player,
                })
            end
        })


        -- remove effect after 5 seconds
        timer.start({
            duration = 5,
            callback = function()
                reference.tempData.rf_ms_fire_cooldown = nil
            end
        })
    end
end

--- @param reference tes3reference
--- @param damage number
local function handle_frost(reference, damage)
    -- add damage to tempdata
    if not reference.tempData.rf_ms_frost_cooldown then
        if not reference.tempData.rf_ms_frost then
            reference.tempData.rf_ms_frost = 1
        else
            reference.tempData.rf_ms_frost = reference.tempData.rf_ms_frost + 1
        end

        -- mwse.log("Frost damage: %s", reference.tempData.rf_ms_frost)
        reference.tempData.rf_ms_frost_cooldown = true
        timer.start({
            duration = 1,
            callback = function()
                reference.tempData.rf_ms_frost_cooldown = nil
            end
        })
    end

    local threshold = get_threshold(reference, tes3.effect.frostDamage)
    if reference.tempData.rf_ms_frost < threshold then
        -- reset tempdata
        reference.tempData.rf_ms_frost = 0
        -- add cooldown
        reference.tempData.rf_ms_frost_cooldown = true
        -- add vfx VFX_DestructionHit
        tes3.createVisualEffect({ object = "VFX_FrostHit", lifespan = 5, reference = reference })

        -- paralyze reference
        tes3.messageBox("You are frozen!")
        reference.mobile.paralyze = 1

        -- remove effect after 5 seconds
        timer.start({
            duration = 5,
            callback = function()
                reference.tempData.rf_ms_frost_cooldown = nil
                reference.mobile.paralyze = 0
            end
        })
    end
end

--- @param reference tes3reference
--- @param damage number
local function handle_poison(reference, damage)
    -- add damage to tempdata
    if not reference.tempData.rf_ms_poison_cooldown then
        if not reference.tempData.rf_ms_poison then
            reference.tempData.rf_ms_poison = 1
        else
            reference.tempData.rf_ms_poison = reference.tempData.rf_ms_poison + 1
        end

        -- mwse.log("Poison damage: %s", reference.tempData.rf_ms_poison)
        reference.tempData.rf_ms_poison_cooldown = true
        timer.start({
            duration = 1,
            callback = function()
                reference.tempData.rf_ms_poison_cooldown = nil
            end
        })
    end

    -- check if tempdata is over threshold
    local threshold = get_threshold(reference, tes3.effect.poison)
    if reference.tempData.rf_ms_poison < threshold then
        -- reset tempdata
        reference.tempData.rf_ms_poison = 0
        -- add cooldown
        reference.tempData.rf_ms_poison_cooldown = true
        -- add vfx VFX_DestructionHit
        tes3.createVisualEffect({ object = "VFX_PoisonHit", lifespan = 5, reference = reference })

        -- disintegrate armor
        tes3.messageBox("You are poisoned!")
        tes3.applyMagicSource({
            reference = reference,
            bypassResistances = true,
            name = "poison proc",
            effects = {
                {
                    id = tes3.effect.disintegrateArmor,
                    min = 100,
                    max = 100,
                    rangeType = tes3.effectRange.self,
                    duration = 5,
                },
            },
        })

        -- remove effect after 5 seconds
        timer.start({
            duration = 5,
            callback = function()
                reference.tempData.rf_ms_poison_cooldown = nil
            end
        })
    end
end

--- @param e damagedEventData
local function damagedCallback(e)
    -- check if magic effect is shock
    if e.magicEffect and e.magicEffect.id == tes3.effect.shockDamage then
        handle_shock(e.reference, e.damage)
    end

    -- check if magic effect is fire
    if e.magicEffect and e.magicEffect.id == tes3.effect.fireDamage then
        handle_fire(e.reference, e.attackerReference, e.damage)
    end

    -- check if magic effect is frost
    if e.magicEffect and e.magicEffect.id == tes3.effect.frostDamage then
        handle_frost(e.reference, e.damage)
    end

    -- check if magic effect is poison
    if e.magicEffect and e.magicEffect.id == tes3.effect.poison then
        handle_poison(e.reference, e.damage)
    end
end
event.register(tes3.event.damaged, damagedCallback)

-- INITIALIZATION

--- add the spell on initialization
--- @param e initializedEventData
local function initializedCallback(e)
    -- create custom spells
    effect_wet = tes3.createObject({
        objectType = tes3.objectType.spell,
        castType = tes3.spellType.ability,
        id = id_wet,
        name = "Wet",
        effects = {
            -- if you are wet, you are weak to shock
            {
                id = tes3.effect.weaknesstoShock,
                min = 100,
                max = 100,
                rangeType = tes3.effectRange.self,
            },
            -- if you are wet, you are resistant to fire
            {
                id = tes3.effect.resistFire,
                min = 100,
                max = 100,
                rangeType = tes3.effectRange.self,
            },
        }
    })

    effect_cold = tes3.createObject({
        objectType = tes3.objectType.spell,
        castType = tes3.spellType.ability,
        id = id_cold,
        name = "Cold",
        effects = {
            -- if you are cold, you are weak to frost
            {
                id = tes3.effect.weaknesstoFrost,
                min = 100,
                max = 100,
                rangeType = tes3.effectRange.self,
            },
            -- if you are cold, you are resistant to fire
            {
                id = tes3.effect.resistFire,
                min = 100,
                max = 100,
                rangeType = tes3.effectRange.self,
            },
        }
    })

    effect_charged = tes3.createObject({
        objectType = tes3.objectType.spell,
        castType = tes3.spellType.ability,
        id = id_charged,
        name = "Shocked",
        effects = {
            -- during a thunderstorm, you are weak to shock
            {
                id = tes3.effect.weaknesstoShock,
                min = 100,
                max = 100,
                rangeType = tes3.effectRange.self,
            },
        }
    })

    effect_warm = tes3.createObject({
        objectType = tes3.objectType.spell,
        castType = tes3.spellType.ability,
        id = id_warm,
        name = "Ash",
        effects = {
            -- during an ashstorm, you are weak to fire
            {
                id = tes3.effect.weaknesstoFire,
                min = 100,
                max = 100,
                rangeType = tes3.effectRange.self,
            },
        }
    })
end
event.register(tes3.event.initialized, initializedCallback)
