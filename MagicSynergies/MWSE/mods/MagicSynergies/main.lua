-- Add new fortify luck spell
local rf_ms_weaknessToShock

local str_shockWetness = "rf_ms_weaknessToShock"

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
    local isUnderWater = reference.position.z < 0
    -- check if weather is rain
    local isRain = tes3.worldController.weatherController.currentWeather.index == tes3.weather.rain

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


--- @param e mobileActivatedEventData
local function mobileActivatedCallback(e)
    toggleShockSynergies(e.mobile)
end
event.register(tes3.event.mobileActivated, mobileActivatedCallback)

-- TODO this doesn't really work for npcs that don't walk
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
            {
                id = tes3.effect.weaknesstoShock,
                min = 600,
                max = 600,
                rangeType = tes3.effectRange.self,
            }
        }
    })
end
event.register(tes3.event.initialized, initializedCallback)
