---@param item tes3item
---@return number
local function getRequiredLevel(item)
    -- todo check if weapon
    -- check if armor
    if item.objectType == tes3.objectType.armor then
        -- cast to tes3armor
        local armor = item ---@cast armor tes3armor

        -- get armor rating
        local armorRating = armor.armorRating
        -- TODO get skilltype
        -- local weightClass = armor.weightClass

        local requiredLevel = math.clamp(math.round(armorRating / 4), 1, 20)
        return requiredLevel
    elseif item.objectType == tes3.objectType.weapon then
        -- cast to tes3weapon
        local weapon = item ---@cast weapon tes3weapon

        -- get weapon damage
        local weaponDamage = math.max(weapon.chopMax, weapon.slashMax, weapon.thrustMax)
        -- TODO get skilltype
        -- local weaponType = weapon.type

        local dps = weaponDamage * weapon.speed
        local requiredLevel = math.clamp(math.round(dps / 4), 1, 20)

        -- hack
        if requiredLevel <= 3 then
            requiredLevel = 1
        end

        return requiredLevel
    end

    return 1
end

---@param item tes3item
---@return boolean
local function canEquip(item)
    return tes3.player.object.level >= getRequiredLevel(item)
end


--- mod requirement
--- @param e equipEventData
local function equipCallback(e)
    -- only check for player
    if e.reference ~= tes3.player then
        return
    end

    -- block if can_equip is false
    if not canEquip(e.item) then
        local requiredLevel = getRequiredLevel(e.item)
        tes3.messageBox("You need to be at least level " .. requiredLevel .. " to equip this item.")
        e.block = true
    end
end
event.register(tes3.event.equip, equipCallback)

--- @param e uiObjectTooltipEventData
local function uiObjectTooltipCallback(e)
    if e.tooltip then
        local result = e.tooltip:findChild("HelpMenu_weight")
        if result then
            local parent = result.parent
            if parent then
                if not canEquip(e.object) then
                    local requiredLevel = getRequiredLevel(e.object)
                    local label = parent:createLabel {
                        text = "Required level: " .. requiredLevel
                    }
                    label.color = tes3ui.getPalette(tes3.palette.magicFillColor)

                    parent:reorderChildren(result, label, -1)
                    e.tooltip:updateLayout()
                end
            end
        end
    end
end
event.register(tes3.event.uiObjectTooltip, uiObjectTooltipCallback)
