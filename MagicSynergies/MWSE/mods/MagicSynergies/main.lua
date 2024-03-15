-- Add new fortify luck spell
local rf_ms_weaknessToShock

local str_shockWetness = "rf_ms_weaknessToShock"

local FROST_THRESHOLD = -10
local SHOCK_THRESHOLD = -10
local FIRE_THRESHOLD = -10

--- @param id string
local function getSpellFromId(id)
    if id == str_shockWetness then
        return rf_ms_weaknessToShock
    end
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
local function toggleShockSynergies(mobile)
    if not mobile then
        return
    end

    local reference = mobile.reference
    if not reference then
        return
    end

    -- check if z < 0 which means the actor is underwater
    local waterlevel = 0
    if reference.cell.isInterior then
        waterlevel = reference.cell.waterLevel
    end
    local isUnderWater = reference.position.z < waterlevel

    -- check if weather is rain
    local isRain = tes3.worldController.weatherController.currentWeather.index == tes3.weather.rain
    if reference.cell.isInterior then
        isRain = false
    end

    -- apply the effect is the actor is underwater or it's raining
    if isUnderWater or isRain then
        local hasEffect = has_effect(mobile, str_shockWetness)
        if not hasEffect then
            apply_effect(reference, str_shockWetness)
        end
    end

    -- remove the effect if it's not raining and the actor is not underwater
    if not isRain and not isUnderWater then
        -- remove the effect
        local hasEffect = has_effect(mobile, str_shockWetness)
        if hasEffect then
            remove_effect(mobile, str_shockWetness)
        end
    end
end

-- TODO keep track of refs?

--- @param e mobileActivatedEventData
local function mobileActivatedCallback(e)
    toggleShockSynergies(e.mobile)
end
event.register(tes3.event.mobileActivated, mobileActivatedCallback)

--- @param e calcWalkSpeedEventData
local function calcWalkSpeedCallback(e)
    toggleShockSynergies(e.mobile)
end
event.register(tes3.event.calcWalkSpeed, calcWalkSpeedCallback)

--- add the spell on initialization
--- @param e initializedEventData
local function initializedCallback(e)
    rf_ms_weaknessToShock = tes3.createObject({
        objectType = tes3.objectType.spell,
        castType = tes3.spellType.ability,
        id = str_shockWetness,
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
end
event.register(tes3.event.initialized, initializedCallback)

--- @param reference tes3reference
--- @param damage number
local function proc_shock(reference, damage)
    -- add damage to tempdata
    -- wetness already makes the actor weak to shock
    if not reference.tempData.rf_ms_shock_cooldown then
        if not reference.tempData.rf_ms_shock then
            reference.tempData.rf_ms_shock = damage
        else
            reference.tempData.rf_ms_shock = reference.tempData.rf_ms_shock + damage
        end

        -- mwse.log("Shock damage: %s", reference.tempData.rf_ms_shock)
    end

    -- check if tempdata is over threshold
    if reference.tempData.rf_ms_shock < SHOCK_THRESHOLD then
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
local function proc_fire(reference, attackerReference, damage)
    -- add damage to tempdata
    if not reference.tempData.rf_ms_fire_cooldown then
        if not reference.tempData.rf_ms_fire then
            reference.tempData.rf_ms_fire = damage
        else
            reference.tempData.rf_ms_fire = reference.tempData.rf_ms_fire + damage
        end

        -- mwse.log("Fire damage: %s", reference.tempData.rf_ms_fire)
    end

    local threshold = FIRE_THRESHOLD
    if has_effect(reference.mobile, str_shockWetness) then
        -- if the actor is wet, the threshold is higher
        threshold = threshold * 2
    end

    -- check if tempdata is over threshold
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
--- @param attackerReference tes3reference
--- @param damage number
local function proc_frost(reference, attackerReference, damage)
    -- add damage to tempdata
    if not reference.tempData.rf_ms_frost_cooldown then
        if not reference.tempData.rf_ms_frost then
            reference.tempData.rf_ms_frost = damage
        else
            reference.tempData.rf_ms_frost = reference.tempData.rf_ms_frost + damage
        end

        -- mwse.log("Frost damage: %s", reference.tempData.rf_ms_frost)
    end

    local threshold = FIRE_THRESHOLD
    if has_effect(reference.mobile, str_shockWetness) then
        -- if the actor is wet, the threshold is lower
        threshold = threshold * 0.5
    end

    -- check if tempdata is over threshold
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

--- @param e damagedEventData
local function damagedCallback(e)
    -- check if magic effect is shock
    if e.magicEffect and e.magicEffect.id == tes3.effect.shockDamage then
        proc_shock(e.reference, e.damage)
    end

    -- check if magic effect is fire
    if e.magicEffect and e.magicEffect.id == tes3.effect.fireDamage then
        proc_fire(e.reference, e.attackerReference, e.damage)
    end

    -- check if magic effect is frost
    if e.magicEffect and e.magicEffect.id == tes3.effect.frostDamage then
        proc_frost(e.reference, e.attackerReference, e.damage)
    end
end
event.register(tes3.event.damaged, damagedCallback)
