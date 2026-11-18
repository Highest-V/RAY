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

local function RAY_GetUniversalSpellCooldown(spellNameOrId)
    if not spellNameOrId or spellNameOrId == "" then return nil, nil end
    local cleanTarget = RAY_Engine.CleanSpellName(spellNameOrId)
    
    local numId = tonumber(cleanTarget)
    if numId then
        local s, d = GetSpellCooldown(numId)
        if s ~= nil then return s, d end
    end

    local i = 1
    while true do
        local name = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        if RAY_Engine.CleanSpellName(name) == cleanTarget then
            return GetSpellCooldown(i, BOOKTYPE_SPELL)
        end
        i = i + 1
    end

    return GetSpellCooldown(spellNameOrId)
end

-- Логика проверки способностей, дебаффов и внешних аур в цикле
function RAY_Engine.ProcessDebuffs(activeProfile, inCombat, currentZone, curTime, mainFrameFontSize)
    local activeSpells = activeProfile.spells or {}
    for i = 1, #activeSpells do
        local spellData = activeSpells[i]
        if spellData and spellData.name ~= "" and RAY_Engine.CheckSubRules(spellData, inCombat, currentZone) then
            if not spellData.isSummonObject then
                local target = spellData.target or "player"
                local unitValid = (target == "player" or target == "target") or (UnitExists(target) and not UnitIsDead(target))
                local chatKey = tostring(spellData.mode) .. "_" .. tostring(spellData.name) .. "_" .. tostring(target)

                if not unitValid then
                    if RAY_Engine.sentChatAlerts then
                        RAY_Engine.sentChatAlerts[chatKey] = nil
                    end
                else
                    local limitStacks, userAlertTime, prefix = (tonumber(spellData.minStacks) or 0), (tonumber(spellData.alertTime) or 0), " ст"
                    local hexColor = RAY_Engine.GetCachedHexColor(spellData.color)
                    local finalRGBColor = spellData.color or RAY_Engine.GetDefaultColor()
                    local needAlert, customReason = false, ""
                    local msgTypeCustom = nil
                    
                    if spellData.isWeaponText then
                        if spellData.isCooldown then
                            local start, duration = GetInventoryItemCooldown("player", 10)
                            if start and start > 0 and duration > 1.5 then
                                local rem = (start + duration) - curTime
                                if userAlertTime > 0 and rem > 0 and rem <= userAlertTime then
                                    needAlert = true
                                    customReason = " " .. math.ceil(rem) .. " сек"
                                end
                            else
                                needAlert = true
                            end
                        else
                            local isEnchanted, remTime = RAY_Engine.GetEnchantCooldownOrStatus(spellData.name)
                            if not isEnchanted then
                                needAlert = true
                            elseif userAlertTime > 0 and remTime > 0 and remTime <= userAlertTime then
                                needAlert = true
                                customReason = " " .. math.ceil(remTime) .. " сек"
                            end
                        end
                    elseif spellData.isCooldown then
                        local start, duration = RAY_GetUniversalSpellCooldown(spellData.name)
                        if start ~= nil then
                            if start > 0 and duration > 1.5 then
                                local rem = (start + duration) - curTime
                                if userAlertTime > 0 and rem > 0 and rem <= userAlertTime then
                                    needAlert = true
                                    customReason = " " .. math.ceil(rem) .. " сек"
                                end
                            else
                                needAlert = true
                            end
                        end
                    else
                        local CheckFunc = RAY_Engine.CheckAuraGroupDirect
                        local isActive, stacks, timeLeft, caster = false, 0, 0, nil
                        if CheckFunc then
                            isActive, stacks, timeLeft, caster = CheckFunc(target, spellData.name)
                        end
                        
                        local isAtMaxCap = false
                        if isActive and limitStacks > 0 and stacks >= limitStacks then
                            isAtMaxCap = true
                        end
                        
                        if spellData.isExternalOnly then
                            if isActive and caster and caster ~= "player" and caster ~= "vehicle" then
                                needAlert = true
                                msgTypeCustom = "[Обнаружен спелл]: " .. RAY_Engine.GetCasterColoredName(caster) .. " -> "
                            end
                        else
                            if spellData.isProc then
                                if isActive or (IsUsableSpell(spellData.name) and inCombat) then
                                    if limitStacks > 0 and stacks < limitStacks and not spellData.isStackProgress then
                                        needAlert = false
                                    elseif isAtMaxCap and spellData.isHideCap then
                                        needAlert = false
                                    else
                                        needAlert = true
                                        if isAtMaxCap then
                                            hexColor = "FF0000" finalRGBColor = { r = 1, g = 0, b = 0 }
                                        end
                                        
                                        local displayTime = ""
                                        if timeLeft > 0 and timeLeft < 3600 and (userAlertTime == 0 or timeLeft <= userAlertTime) then 
                                            displayTime = " " .. math.ceil(timeLeft) .. " сек" 
                                        elseif userAlertTime > 0 and timeLeft > userAlertTime then
                                            needAlert = false
                                        end
                                        
                                        customReason = (spellData.isStackProgress and limitStacks > 0) and (" (" .. stacks .. "/" .. limitStacks .. prefix .. ")" .. displayTime) or displayTime
                                    end
                                end
                            else
                                local stackKey = target .. "_" .. spellData.name
                                if not isActive then
                                    RAY_Engine.lastAuraStacks[stackKey] = 0
                                    RAY_Engine.auraStackDirection[stackKey] = nil
                                    needAlert = true 
                                    if limitStacks > 0 then customReason = " (0/" .. limitStacks .. prefix .. ")" end
                                else
                                    local prevStacks = RAY_Engine.lastAuraStacks[stackKey]
                                    if prevStacks and stacks ~= prevStacks then
                                        RAY_Engine.auraStackDirection[stackKey] = (stacks > prevStacks) and "up" or "down"
                                    end
                                    RAY_Engine.lastAuraStacks[stackKey] = stacks
                                    local dir = RAY_Engine.auraStackDirection[stackKey]

                                    -- 1. Независимый модуль стаков
                                    if limitStacks > 0 then
                                        if stacks < limitStacks then
                                            if spellData.isStackProgress then
                                                needAlert = true
                                                customReason = " (" .. stacks .. "/" .. limitStacks .. prefix .. ")"
                                            end
                                        else
                                            if spellData.isHideCap then
                                                if spellData.isStackProgress and dir == "down" and stacks == limitStacks then
                                                    needAlert = true
                                                    customReason = " (" .. stacks .. "/" .. limitStacks .. prefix .. ")"
                                                end
                                            else
                                                needAlert = true
                                                hexColor = "FF0000" finalRGBColor = { r = 1, g = 0, b = 0 }
                                                if spellData.isStackProgress then
                                                    customReason = " (" .. stacks .. "/" .. limitStacks .. prefix .. ")"
                                                end
                                            end
                                        end
                                    end

                                    -- 2. Независимый модуль таймера
                                    if userAlertTime > 0 and timeLeft > 0 and timeLeft <= userAlertTime then
                                    needAlert = true
                                    customReason = customReason .. " " .. math.ceil(timeLeft) .. " сек"
                                end
                            end
                        end
                    end
                end
                    -- Отправка в чат строго 1 раз при ПОЯВЛЕНИИ ауры/прока/дебаффа
                    local isCastTrigger = (spellData.isCooldown or spellData.isSummonObject or spellData.isWeaponText)
                    if not isCastTrigger and spellData.chatMsg and spellData.chatMsg ~= "" then
                        local auraTriggered = false
                        local CheckFunc = RAY_Engine.CheckAuraGroupDirect
                        if CheckFunc then
                            local activeNow, stacksNow, _, casterNow = CheckFunc(target, spellData.name)
                            if activeNow then
                                if spellData.isExternalOnly then
                                    auraTriggered = (casterNow and casterNow ~= "player" and casterNow ~= "vehicle") and true or false
                                elseif limitStacks > 0 and not spellData.isProc then
                                    auraTriggered = (stacksNow >= limitStacks)
                                else
                                    auraTriggered = true
                                end
                            end
                        end

                        if auraTriggered then
                            if not RAY_Engine.sentChatAlerts[chatKey] then
                                RAY_Engine.sentChatAlerts[chatKey] = true
                                SendChatMessage(spellData.chatMsg, spellData.chatChannel or "SAY")
                            end
                        else
                            RAY_Engine.sentChatAlerts[chatKey] = nil
                        end
                    end

                    if needAlert and not spellData.hideScreenAlert then
                        local displayName = string.match(spellData.name, "[^|/]+") or spellData.name
                        local msgType = (spellData.mode == "DEBUFF") and "RAY: Дебафф [" or "RAY: Обнови бафф ["
                        if spellData.target == "target" and spellData.mode == "DEBUFF" then msgType = "RAY: Наложи дебафф [" end
                        if spellData.isProc then msgType = "RAY: Прок! [" end
                        if spellData.isWeaponText then msgType = "RAY: Чарка [" end
                        if spellData.isCooldown then msgType = "RAY: Готово! Прожми [" end
                        if spellData.isExternalOnly then msgType = msgTypeCustom or "RAY: " end
                        
                        if spellData.isCooldown and customReason ~= "" then
                            msgType = "RAY: Скоро готово ["
                        end
                        local msg = (spellData.isExternalOnly) and (msgType .. displayName .. "]") or (msgType .. displayName .. "]" .. customReason)

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
    end
    return mainFrameFontSize
end