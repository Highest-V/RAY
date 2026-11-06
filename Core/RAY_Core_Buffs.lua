function RAY_Engine.FindAuraDirect(target, nameOrId)
    local searchKey = RAY_Engine.CleanSpellName(nameOrId)
    if searchKey == "" then return false, 0, 0, nil end
    local curTime = GetTime()
    for f = 1, 2 do
        local filter = (f == 1) and "HELPFUL" or "HARMFUL"
        for i = 1, 40 do
            local name, _, _, count, _, _, expirationTime, caster, _, _, spellID = UnitAura(target, i, filter)
            if not name then break end
            if RAY_Engine.CleanSpellName(name) == searchKey or tostring(spellID) == searchKey then
                local rem = (expirationTime and expirationTime > 0) and (expirationTime - curTime) or 0
                local actualStacks = (count and count > 0) and count or 1
                return true, actualStacks, rem, caster
            end
        end
    end
    return false, 0, 0, nil
end

function RAY_Engine.CheckAuraGroupDirect(target, spellLine)
    local active, currentStacks, minRemaining, lastCaster = false, 0, 999999, nil
    for condition in string.gmatch(spellLine, "[^|/]+") do
        condition = condition:match("^%s*(.-)%s*$")
        local found, stacks, timeLeft, caster = RAY_Engine.FindAuraDirect(target, condition)
        if found then
            active = true
            currentStacks = math.max(currentStacks, stacks)
            if timeLeft < minRemaining then minRemaining = timeLeft end
            if caster then lastCaster = caster end
        end
    end
    return active, currentStacks, minRemaining, lastCaster
end

function RAY_Engine.IsTotemActiveInGame(totemName)
    local lowerName = RAY_Engine.CleanSpellName(totemName)
    for i = 1, 4 do
        local haveTotem, name = GetTotemInfo(i)
        if haveTotem and name and RAY_Engine.CleanSpellName(name):find(lowerName, 1, true) then return true end
    end
    return false
end

-- Логика проверки баффов и призывов в основном цикле
function RAY_Engine.ProcessBuffs(activeProfile, inCombat, currentZone, curTime, mainFrameFontSize)
    local activeSpells = activeProfile.spells or {}
    local currentActiveTotems = {}
    
    for slot = 1, 4 do
        local haveTotem, totemName, startTime, duration = GetTotemInfo(slot)
        if haveTotem and totemName and totemName ~= "" then
            local cleanTName = RAY_Engine.CleanSpellName(totemName)
            for i = 1, #activeSpells do
                local spellData = activeSpells[i]
                if spellData and spellData.isSummonObject and RAY_Engine.CleanSpellName(spellData.name) == cleanTName then
                    if not spellData.isCooldown then
                        local endTime = (startTime > 0) and (startTime + duration) or (curTime + duration)
                        if duration == 0 or duration > 90000 then endTime = curTime + 300 end
                        local storageKey = "totem_slot" .. slot
                        currentActiveTotems[storageKey] = true
                        RAY_Engine.activeSummonAlerts[storageKey] = {
                            endTime = endTime,
                            spellName = totemName,
                            color = spellData.color,
                            customSize = spellData.customSize,
                            isOwnWindow = spellData.isOwnWindow,
                            configKey = spellData.name,
                            isRealTotem = true
                        }
                    end
                end
            end
        end
    end

    for key, data in pairs(RAY_Engine.activeSummonAlerts) do
        if data.isRealTotem and not currentActiveTotems[key] then RAY_Engine.activeSummonAlerts[key] = nil end
    end

    for key, data in pairs(RAY_Engine.activeSummonAlerts) do
        local stillExists = data.isRealTotem and RAY_Engine.IsTotemActiveInGame(data.spellName) or (curTime < data.endTime)
        if stillExists then
            local rem = math.max(0, math.ceil(data.endTime - curTime))
            if rem > 0 then
                local displaySpellName = tostring(data.spellName):gsub("%s+[IVXLCDM]+%s*$", ""):gsub("%s*$", "")
                local msg = "[Призыв]: [" .. displaySpellName .. "] " .. rem .. " сек"
                local hex = RAY_Engine.GetCachedHexColor(data.color)
                local fKey = RAY_Engine.GetFrameKey(data.configKey)
                local cf = RAY_Engine.customFramesPool[fKey]
                if cf and cf.cooldown then cf.cooldown:Hide() end
                if RAY_Engine.frame and RAY_Engine.frame.cooldown then RAY_Engine.frame.cooldown:Hide() end
                
                if data.isOwnWindow then
                    RAY_Engine.customAlertsByWindow[fKey] = { text = "|cff" .. hex .. msg .. "|r", color = data.color or RAY_Engine.GetDefaultColor(), size = data.customSize }
                else
                    RAY_Engine.uniqueAlerts["|cff" .. hex .. msg .. "|r"] = true
                    if data.customSize and data.customSize > mainFrameFontSize then mainFrameFontSize = data.customSize end
                end
            else RAY_Engine.activeSummonAlerts[key] = nil end
        else RAY_Engine.activeSummonAlerts[key] = nil end
    end

    if activeProfile.buffs then
        for i = 1, #activeProfile.buffs do
            local buff = activeProfile.buffs[i]
            if buff and buff.name ~= "" and RAY_Engine.CheckSubRules(buff, inCombat, currentZone) then
                local hasAura = false
                if buff.isPetTracker then
                    if UnitExists("pet") and not UnitIsDead("pet") then hasAura = true end
                else
                    hasAura = RAY_Engine.CheckAuraGroupDirect("player", buff.name)
                    if not hasAura then
                        local currentFormIndex = GetShapeshiftForm()
                        if currentFormIndex and currentFormIndex > 0 then
                            local _, formName = GetShapeshiftFormInfo(currentFormIndex)
                            if formName and RAY_Engine.CleanSpellName(formName) == RAY_Engine.CleanSpellName(buff.name) then hasAura = true end
                        end
                    end
                end
                if buff.invert then
                    if hasAura then RAY_Engine.uniqueAlerts["|cffFF7676RAY: Сними [" .. buff.name .. "]!|r"] = true end
                else
                    if not hasAura then
                        local displayName = buff.name
                        RAY_Engine.uniqueAlerts[buff.isPetTracker and ("|cffA8FF35RAY: Призови [" .. displayName .. "]!|r") or ("|cffA8FF35RAY: Включи [" .. displayName .. "]!|r")] = true
                    end
                end
            end
        end
    end
    return mainFrameFontSize
end