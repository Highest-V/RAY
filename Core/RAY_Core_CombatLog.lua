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

    -- РЛ-Радар (отслеживание выбранных способностей по журналу боя)
    if RAY_Config and RAY_Config.enabled and RAY_Engine.radarLookup and spellName then
        if subEvent == "SPELL_CAST_SUCCESS" or subEvent == "SPELL_SUMMON" or subEvent == "SPELL_AURA_APPLIED" or subEvent == "SPELL_INTERRUPT" then
            local cleanLogSpell = RAY_Engine.CleanSpellName(spellName)
            local radarData = RAY_Engine.radarLookup[cleanLogSpell] or RAY_Engine.radarLookup[tostring(spellID)]
            if radarData then
                local inCombat = UnitAffectingCombat("player")
                if not radarData.onlyInCombat or inCombat then
                    local dur = tonumber(radarData.duration) or 5
                    if dur <= 0 then dur = 5 end

                    local casterDisplay = sourceName or "Неизвестно"
                    if sourceName and UnitExists(sourceName) then
                        local _, class = UnitClass(sourceName)
                        if class and RAID_CLASS_COLORS[class] then
                            local c = RAID_CLASS_COLORS[class]
                            casterDisplay = string.format("|cff%02x%02x%02x%s|r", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255), sourceName)
                        end
                    end

                    local cleanDisplay = tostring(spellName):gsub("%s+[IVXLCDM]+%s*$", ""):gsub("%s*$", "")
                    local alertKey = cleanLogSpell .. "_" .. tostring(sourceGUID or "unknown")
                    RAY_Engine.activeRadarAlerts[alertKey] = {
                        endTime = curTime + dur,
                        casterText = casterDisplay,
                        spellName = cleanDisplay,
                        color = radarData.color or { r = 0.5, g = 0.95, b = 0.8 },
                        customSize = radarData.customSize or 24,
                        isOwnWindow = radarData.isOwnWindow == true,
                        configKey = radarData.name
                    }
                    RAY_Engine.Engine_lastDbgHash = ""
                    RAY_Engine.CheckAllAuras()
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
