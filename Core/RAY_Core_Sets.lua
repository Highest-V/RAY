-- Сканирование КД и чарок через скрытый тултип
local textScanFrameMain = CreateFrame("GameTooltip", "RAY_EnchantScannerTooltipMain", nil, "GameTooltipTemplate")
textScanFrameMain:SetOwner(UIParent, "ANCHOR_NONE")

function RAY_Engine.UpdateCustomGearEnchantCache()
    wipe(RAY_Engine.cachedEnchantStatus)
    local slotsToScan = { 10, 15, 16, 17 }
    for idx = 1, 4 do
        local slotID = slotsToScan[idx]
        textScanFrameMain:ClearLines() 
        textScanFrameMain:SetInventoryItem("player", slotID)
        
        RAY_Engine.cachedEnchantStatus[slotID] = {}
        
        for i = 1, 15 do
            local lineText = _G["RAY_EnchantScannerTooltipMainTextLeft"..i] 
            local txt = lineText and lineText:GetText()
            if txt then
                table.insert(RAY_Engine.cachedEnchantStatus[slotID], txt:lower())
            end
        end
    end
end

function RAY_Engine.GetEnchantCooldownOrStatus(enchantName)
    local targetClean = RAY_Engine.CleanSpellName(enchantName)
    if targetClean == "" then return false end
    
    local nonWeaponSlots = { 10, 15 }
    for i = 1, #nonWeaponSlots do
        local slotID = nonWeaponSlots[i]
        local cache = RAY_Engine.cachedEnchantStatus[slotID]
        if cache then
            for j = 1, #cache do
                local cleanCacheLine = cache[j]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                if cleanCacheLine:find(targetClean, 1, true) then
                    if slotID == 10 then
                        local start, duration = GetInventoryItemCooldown("player", 10)
                        if start and start > 0 and duration > 1.5 then return false end
                        return true
                    elseif slotID == 15 then
                        return true
                    end
                end
            end
        end
    end

    local hasMain, mainExp, _, hasOff, offExp, _ = GetWeaponEnchantInfo()
    local hasOffhandWeapon = GetInventoryItemID("player", 17) and true or false

    local mainMatch = false
    local cacheMain = RAY_Engine.cachedEnchantStatus[16]
    if hasMain and mainExp > 0 and cacheMain then
        for j = 1, #cacheMain do
            local line = cacheMain[j]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if line:find(targetClean, 1, true) then
                mainMatch = true
                break
            end
        end
    end

    local offMatch = false
    local cacheOff = RAY_Engine.cachedEnchantStatus[17]
    if hasOff and offExp > 0 and cacheOff then
        for j = 1, #cacheOff do
            local line = cacheOff[j]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if line:find(targetClean, 1, true) then
                offMatch = true
                break
            end
        end
    end

    if mainMatch or offMatch then
        if hasOffhandWeapon then
            if mainMatch and not offMatch then
                return (hasMain and mainExp > 0)
            elseif offMatch and not mainMatch then
                return (hasOff and offExp > 0)
            else
                return (hasMain and mainExp > 0) and (hasOff and offExp > 0)
            end
        else
            return (hasMain and mainExp > 0)
        end
    end
    return false
end

function RAY_Engine.UpdateEquipmentSetsCache()
    wipe(RAY_Engine.cachedEquipmentStatus)
    if not RAY_Config or not RAY_Config.enabled then return end
    local currentSpec = GetActiveTalentGroup() or 1
    local configData = RAY_Config.specSettings and RAY_Config.specSettings[currentSpec]
    if not configData or not configData.sets then return end
    local numSets = GetNumEquipmentSets()
    
    for i = 1, #configData.sets do
        local set = configData.sets[i]
        if set and set.name and set.name ~= "" then
            local finalStatus = "NOT_FOUND"
            for subSetName in string.gmatch(set.name, "[^|/]+") do
                subSetName = subSetName:match("^%s*(.-)%s*$")
                if subSetName ~= "" then
                    local foundIndex = nil
                    local setLower = subSetName:lower()
                    for s = 1, numSets do
                        local name = GetEquipmentSetInfo(s)
                        if name and name:lower() == setLower then foundIndex = s break end
                    end
                    if foundIndex then
                        local setItemIDs = GetEquipmentSetItemIDs(GetEquipmentSetInfo(foundIndex))
                        local currentSubStatus = "OK"
                        if setItemIDs then
                            for slotID = 1, 18 do
                                local savedItemID = setItemIDs[slotID]
                                if savedItemID and savedItemID > 1 and GetInventoryItemID("player", slotID) ~= savedItemID then
                                    currentSubStatus = "PARTIAL" 
                                    break
                                end
                            end
                        else 
                            currentSubStatus = "NOT_FOUND"
                        end
                        if currentSubStatus == "OK" then
                            finalStatus = "OK"
                            break
                        elseif currentSubStatus == "PARTIAL" and finalStatus ~= "OK" then
                            finalStatus = "PARTIAL"
                        end
                    end
                end
            end
            RAY_Engine.cachedEquipmentStatus[set.name] = finalStatus
        end
    end
end

-- Обработка вызовов комплектов и ICD в основном цикле
function RAY_Engine.ProcessSets(activeProfile, inCombat, currentZone, curTime, mainFrameFontSize)
    if activeProfile.sets then
        for i = 1, #activeProfile.sets do
            local set = activeProfile.sets[i]
            if set and set.name ~= "" and RAY_Engine.CheckSubRules(set, inCombat, currentZone) then
                local status = RAY_Engine.cachedEquipmentStatus[set.name] or "OK"
                if status == "NOT_FOUND" then RAY_Engine.uniqueAlerts["RAY: Комплект [" .. set.name .. "] не найден!"] = true
                elseif status == "PARTIAL" then RAY_Engine.uniqueAlerts["RAY: Комплект [" .. set.name .. "] не полон!"] = true end
            end
        end
    end

    if activeProfile.icds then
        for i = 1, #activeProfile.icds do
            local data = activeProfile.icds[i]
            if data and data.name ~= "" and RAY_Engine.CheckSubRules(data, inCombat, currentZone) then
                local endTime = RAY_Engine.activeICDTimers[data.name:lower()]
                if endTime and endTime > curTime then
                    local remainingCD = endTime - curTime
                    local _, alertWindow = tostring(data.seconds or "45"):match("([^/]+)/?([^/]*)")
                    alertWindow = tonumber(alertWindow) or 10
                    if remainingCD <= alertWindow then
                        RAY_Engine.uniqueAlerts["RAY: КД " .. data.name .. " (" .. math.ceil(remainingCD) .. " сек)"] = true
                    end
                end
            end
        end
    end
    return mainFrameFontSize
end