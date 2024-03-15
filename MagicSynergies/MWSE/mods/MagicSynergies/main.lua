-- Add new fortify luck spell
local rf_ms_weaknessToShock
local rf_ms_poisonArmor

local str_shockWetness = "rf_ms_weaknessToShock"
local str_poisonArmor = "rf_ms_poisonArmor"

local FROST_THRESHOLD = -10
local SHOCK_THRESHOLD = -10
local FIRE_THRESHOLD = -10
local POISON_THRESHOLD = -10

--- @param id string
local function getSpellFromId(id)
    if id == str_shockWetness then
        return rf_ms_weaknessToShock
    end
    if id == str_poisonArmor then
        return rf_ms_poisonArmor
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

--- @param reference tes3reference
--- @return number
local function getWaterLevel(reference)
    local waterlevel = 0
    if reference.cell and reference.cell.isInterior and reference.cell.waterLevel then
        waterlevel = reference.cell.waterLevel
    end
    return waterlevel
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
    local isUnderWater = reference.position.z < getWaterLevel(reference)

    -- check if weather is rain
    local isRain = tes3.worldController.weatherController.currentWeather.index == tes3.weather.rain
    if reference.cell and reference.cell.isInterior then
        isRain = false
    end

    -- apply the effect is the actor is underwater or it's raining
    if isUnderWater or isRain then
        if not has_effect(mobile, str_shockWetness) then
            apply_effect(reference, str_shockWetness)
        end
    end

    -- remove the effect if it's not raining and the actor is not underwater
    if not isRain and not isUnderWater then
        -- remove the effect
        if has_effect(mobile, str_shockWetness) then
            remove_effect(mobile, str_shockWetness)
        end
    end
end

-- TODO keep track of refs?

--- @param e mobileActivatedEventData
local function mobileActivatedCallback(e)
    if tes3.canCastSpells({ target = e.reference }) then
        toggleShockSynergies(e.mobile)
    end
end
event.register(tes3.event.mobileActivated, mobileActivatedCallback)

--- @param e calcWalkSpeedEventData
local function calcWalkSpeedCallback(e)
    if tes3.canCastSpells({ target = e.reference }) then
        toggleShockSynergies(e.mobile)
    end
end
event.register(tes3.event.calcWalkSpeed, calcWalkSpeedCallback)



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
--- @param damage number
local function proc_frost(reference, damage)
    -- add damage to tempdata
    if not reference.tempData.rf_ms_frost_cooldown then
        if not reference.tempData.rf_ms_frost then
            reference.tempData.rf_ms_frost = damage
        else
            reference.tempData.rf_ms_frost = reference.tempData.rf_ms_frost + damage
        end

        -- mwse.log("Frost damage: %s", reference.tempData.rf_ms_frost)
    end

    local threshold = FROST_THRESHOLD
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

--- @param reference tes3reference
--- @param damage number
local function proc_poison(reference, damage)
    -- add damage to tempdata
    if not reference.tempData.rf_ms_poison_cooldown then
        if not reference.tempData.rf_ms_poison then
            reference.tempData.rf_ms_poison = damage
        else
            reference.tempData.rf_ms_poison = reference.tempData.rf_ms_poison + damage
        end

        -- mwse.log("Poison damage: %s", reference.tempData.rf_ms_poison)
    end

    -- check if tempdata is over threshold
    if reference.tempData.rf_ms_poison < POISON_THRESHOLD then
        -- reset tempdata
        reference.tempData.rf_ms_poison = 0
        -- add cooldown
        reference.tempData.rf_ms_poison_cooldown = true
        -- add vfx VFX_DestructionHit
        tes3.createVisualEffect({ object = "VFX_PoisonHit", lifespan = 5, reference = reference })

        -- disintegrate armor
        tes3.messageBox("You are poisoned!")
        apply_effect(reference, str_poisonArmor)

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
        proc_shock(e.reference, e.damage)
    end

    -- check if magic effect is fire
    if e.magicEffect and e.magicEffect.id == tes3.effect.fireDamage then
        proc_fire(e.reference, e.attackerReference, e.damage)
    end

    -- check if magic effect is frost
    if e.magicEffect and e.magicEffect.id == tes3.effect.frostDamage then
        proc_frost(e.reference, e.damage)
    end

    -- check if magic effect is poison
    if e.magicEffect and e.magicEffect.id == tes3.effect.poison then
        proc_poison(e.reference, e.damage)
    end
end
event.register(tes3.event.damaged, damagedCallback)

-- INITIALIZATION

--- add the spell on initialization
--- @param e initializedEventData
local function initializedCallback(e)
    -- create custom spells

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

    rf_ms_poisonArmor = tes3.createObject({
        objectType = tes3.objectType.spell,
        castType = tes3.spellType.curse,
        id = str_poisonArmor,
        name = "Disintegrate Armor",
        effects = {
            {
                id = tes3.effect.disintegrateArmor,
                min = 100,
                max = 100,
                rangeType = tes3.effectRange.self,
                duration = 5,
            },
        }
    })
end
event.register(tes3.event.initialized, initializedCallback)


-- SPELLSWORD

-- --- @param e spellCastEventData
-- local function spellCastCallback(e)
--     -- get sourceeffects
--     local effects = e.source.effects

--     local spellswordEffects = {}

--     local hasElementalEffect = false
--     local hasBoundEffect = false


--     for i = #effects, 1, -1 do
--         local magicEffect = effects[i]
--         local magicEffectId = magicEffect.id

--         if magicEffectId == tes3.effect.fireDamage or
--             magicEffectId == tes3.effect.frostDamage or
--             magicEffectId == tes3.effect.shockDamage or
--             magicEffectId == tes3.effect.poison then
--             if magicEffect.rangeType == tes3.effectRange.self then
--                 hasElementalEffect = true
--             end
--         end
--         -- check bound effect
--         if magicEffectId == tes3.effect.boundDagger or
--             magicEffectId == tes3.effect.boundLongsword or
--             magicEffectId == tes3.effect.boundMace or
--             magicEffectId == tes3.effect.boundBattleAxe or
--             magicEffectId == tes3.effect.boundSpear or
--             magicEffectId == tes3.effect.boundLongbow then
--             if magicEffect.rangeType == tes3.effectRange.self then
--                 hasBoundEffect = true
--             end
--         end

--         if hasBoundEffect and hasElementalEffect then
--             table.insert(spellswordEffects, {
--                 id = magicEffectId,
--                 min = magicEffect.min,
--                 max = magicEffect.max,
--             })
--         end
--     end

--     -- if the spell has an elemental effect and a bound effect, add the spellsword effect
--     if hasElementalEffect and hasBoundEffect and #spellswordEffects > 0 then
--         local final_effects = {}
--         for index, value in ipairs(spellswordEffects) do
--             local min = value.min
--             local max = value.max
--             local id = value.id

--             table.insert(final_effects, {
--                 id = tes3.effect.fireShield,
--                 min = min,
--                 max = max,
--                 rangeType = tes3.effectRange.self,
--                 duration = 10,
--             })
--         end

--         local id = "rf_spellsword" -- TODO generate id

--         local spell_spellsword = tes3.createObject({
--             objectType = tes3.objectType.spell,
--             castType = tes3.spellType.ability,
--             id = id,
--             name = "Spellsword",
--             effects = final_effects,
--             duration = 10,
--         })

--         tes3.addSpell({
--             reference = e.caster,
--             spell = spell_spellsword
--         })


--         return false
--     end
-- end
-- event.register(tes3.event.spellCast, spellCastCallback)

-- local function myOnAttackCallback(e)
--     -- Someone other than the player is attacking.
--     if (e.reference ~= tes3.player) then
--         return
--     end

--     -- We hit someone!
--     if (e.targetReference ~= nil) then
--         -- check if I have the spellsword effect
--         if has_effect(e.reference.mobile, "rf_spellsword") then
--             tes3.messageBox("Spellsword: You hit %s!", e.targetReference.object.name or e.targetReference.object.id)
--             -- apply the effects
--         end
--     end
-- end
-- event.register(tes3.event.attack, myOnAttackCallback)

-- ENVIRONMENT EVENTS


-- --- @param e projectileExpireEventData
-- local function projectileExpireCallback(e)
--     local mobile = e.mobile
--     local z = mobile.position.z
--     local waterlevel = getWaterLevel(mobile.reference)

--     if z < (waterlevel + 6) then
--         mwse.log("Projectile expired at %s", z)
--         tes3.messageBox("Projectile expired at %s", z)

--         -- create explosion effect


--     end
-- end
-- event.register(tes3.event.projectileExpire, projectileExpireCallback)
