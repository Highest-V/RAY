local combatLogFrame = CreateFrame("Frame")
combatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
combatLogFrame:SetScript("OnEvent", function(self, event, ...)
    local timestamp, subEvent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellID, spellName = ...
    local playerGUID = UnitGUID("player")
    local curTime = GetTime()

    if RAY_Config and RAY_Config.radarEnabled then
        if sourceGUID == playerGUID or destGUID == playerGUID then
            if subEvent:find("AURA") or subEvent:find("CAST") or subEvent:find("SUMMON") then
                if spellID and spellName then
                    print(string.format("|cff4ECCA3[RAY-Radar]:|r |cffffffff%s|r [|cffFFD369ID: %d|r] (Type: %s)", spellName, spellID, subEvent))
                end
            end
        end
    end

    -- Наша неизменяемая шкатулка Сильваны
    if subEvent == "SPELL_CAST_SUCCESS" and spellID == 72007 then
        RAY_Engine.sylvanasAlertActive = curTime + 6.0
        RAY_Engine.Engine_lastDbgHash = ""
        RAY_Engine.CheckAllAuras()
        return
    end

    if sourceGUID == playerGUID and (subEvent == "SPELL_CAST_SUCCESS" or subEvent == "SPELL_SUMMON") then
        local summonNameLower = spellName and spellName:lower() or ""
        if summonNameLower:find("тотем") or summonNameLower:find("totem") then
            return
        end
        local spellData = RAY_Engine.spellsLookup[summonNameLower]
        if spellData and spellData.isSummonObject then
            local duration = tonumber(spellData.alertTime) or 30
            if duration == 0 then duration = 30 end
            RAY_Engine.activeSummonAlerts["non_totem_summon" .. summonNameLower] = {
                endTime = curTime + duration,
                spellName = spellName,
                color = spellData.color or RAY_Engine.GetDefaultColor(),
                customSize = spellData.customSize or 24,
                isOwnWindow = spellData.isOwnWindow or false,
                configKey = spellData.name,
                isRealTotem = false
            }
            RAY_Engine.Engine_lastDbgHash = ""
            RAY_Engine.CheckAllAuras()
        end
    end

    if destGUID == playerGUID and subEvent == "SPELL_AURA_APPLIED" then
        local currentSpec = GetActiveTalentGroup() or 1
        if RAY_Config and RAY_Config.specSettings and RAY_Config.specSettings[currentSpec] and RAY_Config.specSettings[currentSpec].icds then
            local combatSpellLower = spellName:lower()
            local configData = RAY_Config.specSettings[currentSpec].icds
            for i = 1, #configData do
                local data = configData[i]
                if data and data.name and data.name:lower() == combatSpellLower then
                    local parsedSeconds = tostring(data.seconds or "45"):match("([^/]+)")
                    RAY_Engine.activeICDTimers[combatSpellLower] = curTime + (tonumber(parsedSeconds) or 45)
                    RAY_Engine.Engine_lastDbgHash = ""
                    RAY_Engine.CheckAllAuras()
                    break
                end
            end
        end
    end
end)