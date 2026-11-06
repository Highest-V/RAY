function RAY_Engine.GetCasterColoredName(casterUnit)
    if not casterUnit then return "Напарник" end
    local name = UnitName(casterUnit) or casterUnit
    local _, class = UnitClass(casterUnit)
    if class and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return string.format("|cff%02x%02x%02x%s|r", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255), name)
    end
    return name
end

-- Логика проверки способностей, дебаффов и внешних аур в цикле
function RAY_Engine.ProcessDebuffs(activeProfile, inCombat, currentZone, curTime, mainFrameFontSize)
    local activeSpells = activeProfile.spells or {}
    for i = 1, #activeSpells do
        local spellData = activeSpells[i]
        if spellData and spellData.name ~= "" and RAY_Engine.CheckSubRules(spellData, inCombat, currentZone) then
            if not spellData.isSummonObject then
                local limitStacks, userAlertTime, prefix = (tonumber(spellData.minStacks) or 0), (tonumber(spellData.alertTime) or 0), " ст"
                local hexColor = RAY_Engine.GetCachedHexColor(spellData.color)
                local finalRGBColor = spellData.color or RAY_Engine.GetDefaultColor()
                local needAlert, customReason = false, ""
                local msgTypeCustom = nil
                
                if spellData.isWeaponText then
                    if spellData.isCooldown then
                        local start, duration = GetInventoryItemCooldown("player", 10)
                        needAlert = not (start and start > 0 and duration > 1.5)
                    else
                        needAlert = not RAY_Engine.GetEnchantCooldownOrStatus(spellData.name)
                    end
                elseif spellData.isCooldown then
                    local start, duration = GetSpellCooldown(spellData.name)
                    needAlert = (not (start and start > 0 and duration > 1.5) and not RAY_Engine.CheckAuraGroupDirect("player", spellData.name))
                else
                    local target = spellData.target or "player"
                    local isActive, stacks, timeLeft, caster = RAY_Engine.CheckAuraGroupDirect(target, spellData.name)
                    local isAtMaxCap = false
                    if isActive and limitStacks > 0 and stacks >= limitStacks then
                        isAtMaxCap = true hexColor = "FF0000" finalRGBColor = { r = 1, g = 0, b = 0 }
                    end
                    
                    if spellData.isExternalOnly then
                        if isActive and caster and caster ~= "player" and caster ~= "vehicle" then
                            needAlert = true
                            msgTypeCustom = "[Обнаружен спелл]: " .. RAY_Engine.GetCasterColoredName(caster) .. " -> "
                        end
                    else
                        if spellData.isProc then
                            if isActive or (IsUsableSpell(spellData.name) and inCombat) then
                                needAlert = true
                                local displayTime = ""
                                if timeLeft > 0 and timeLeft < 3600 and (userAlertTime == 0 or timeLeft <= userAlertTime) then displayTime = " " .. math.ceil(timeLeft) .. " сек" end
                                customReason = (spellData.isStackProgress and limitStacks > 0) and (" (" .. stacks .. "/" .. limitStacks .. prefix .. ")" .. displayTime) or displayTime
                            end
                        else
                            if not isActive then
                                needAlert = true if limitStacks > 0 then customReason = " (0/" .. limitStacks .. prefix .. ")" end
                            else
                                if spellData.isStackProgress and limitStacks > 0 and (stacks < limitStacks) then
                                    needAlert = true customReason = " (" .. stacks .. "/" .. limitStacks .. prefix .. ")"
                                elseif userAlertTime > 0 then
                                    if timeLeft <= userAlertTime then
                                        needAlert = true
                                        customReason = ((limitStacks > 0) and (" (" .. stacks .. "/" .. limitStacks .. prefix .. ") ") or "") .. math.ceil(timeLeft) .. " сек"
                                    end
                                else
                                    needAlert = isAtMaxCap and not spellData.isHideCap
                                    if needAlert then
                                        local displayTime = (timeLeft > 0 and timeLeft < 3600) and (" " .. math.ceil(timeLeft) .. " сек") or ""
                                        customReason = " (" .. stacks .. "/" .. limitStacks .. prefix .. ")" .. displayTime
                                    end
                                end
                            end
                        end
                    end
                end
                
                if needAlert then
                    local displayName = string.match(spellData.name, "[^|/]+") or spellData.name
                    local msgType = (spellData.mode == "DEBUFF") and "RAY: Дебафф [" or "RAY: Обнови бафф ["
                    if spellData.target == "target" and spellData.mode == "DEBUFF" then msgType = "RAY: Наложи дебафф [" end
                    if spellData.isProc then msgType = "RAY: Прок! [" end
                    if spellData.isWeaponText then msgType = "RAY: Чарка [" end
                    if spellData.isCooldown then msgType = "RAY: Готово! Прожми [" end
                    if spellData.isExternalOnly then msgType = msgTypeCustom or "RAY: " end
                    
                    local msg = (spellData.isCooldown or spellData.isExternalOnly or (spellData.isWeaponText and spellData.isCooldown)) and (msgType .. displayName .. "]") or (msgType .. displayName .. "]" .. customReason)
                    if spellData.isOwnWindow then
                        RAY_Engine.customAlertsByWindow[RAY_Engine.GetFrameKey(spellData.name)] = { text = "|cff" .. hexColor .. msg .. "|r", color = finalRGBColor, size = spellData.customSize }
                    else
                        RAY_Engine.uniqueAlerts["|cff" .. hexColor .. msg .. "|r"] = true
                        if spellData.customSize and spellData.customSize > mainFrameFontSize then mainFrameFontSize = spellData.customSize end
                    end
                end
            end
        end
    end
    return mainFrameFontSize
end