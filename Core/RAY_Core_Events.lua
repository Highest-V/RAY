local engineEvents = CreateFrame("Frame")
engineEvents:RegisterEvent("ADDON_LOADED")
engineEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
engineEvents:RegisterEvent("UNIT_AURA")
engineEvents:RegisterEvent("UNIT_INVENTORY_CHANGED")
engineEvents:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
engineEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
engineEvents:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
engineEvents:RegisterEvent("PLAYER_FOCUS_CHANGED")
engineEvents:RegisterEvent("UNIT_PET")
engineEvents:RegisterEvent("PLAYER_TOTEM_UPDATE")
engineEvents:RegisterEvent("UNIT_COMBO_POINTS")
engineEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
engineEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
engineEvents:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
engineEvents:RegisterEvent("SPELL_UPDATE_COOLDOWN")

engineEvents:SetScript("OnEvent", function(self, event, arg1, arg2, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" and (arg1 == "player" or arg1 == "pet") and arg2 then
        local castClean = RAY_Engine.CleanSpellName(arg2)
        local currentSpec = GetActiveTalentGroup() or 1
        local spells = RAY_Config and RAY_Config.specSettings and RAY_Config.specSettings[currentSpec] and RAY_Config.specSettings[currentSpec].spells
        if spells then
            local inCombat = UnitAffectingCombat("player") and true or false
            local currentZone = RAY_Engine.GetCurrentZoneType()
            for i = 1, #spells do
                local sd = spells[i]
                local isCastTrigger = sd and (sd.isCooldown or sd.isSummonObject or sd.isWeaponText)
                if isCastTrigger and sd.chatMsg and sd.chatMsg ~= "" and RAY_Engine.CheckSubRules(sd, inCombat, currentZone) then
                    for cond in string.gmatch(sd.name, "[^|/]+") do
                        local cleanCond = RAY_Engine.CleanSpellName(cond:match("^%s*(.-)%s*$"))
                        if cleanCond == castClean or GetSpellInfo(tonumber(cleanCond) or 0) == arg2 then
                            SendChatMessage(sd.chatMsg, sd.chatChannel or "SAY")
                            break
                        end
                    end
                end
            end
        end
    elseif event == "ADDON_LOADED" and arg1 == RAY_addonName then
        if not RAY_Config then RAY_Config = CopyTable(RAY_defaultSettings) end
        if RAY_Engine.frame and RAY_Config.framePos then
            RAY_Engine.frame:ClearAllPoints()
            RAY_Engine.frame:SetPoint(RAY_Config.framePos.point, UIParent, RAY_Config.framePos.point, RAY_Config.framePos.x, RAY_Config.framePos.y)
        end
        RAY_Engine.RebuildSpellsLookup()
        if RAY_Engine.RebuildRadarLookup then RAY_Engine.RebuildRadarLookup() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff4ECCA3RAY - Remember About Yourself|r |cffffffffНастройка /ray. Перемещение /raymove.|r")
        local activeSpec = GetActiveTalentGroup() or 1
        local specColor = (activeSpec == 1) and COLOR_SPEC1 or COLOR_SPEC2
        DEFAULT_CHAT_FRAME:AddMessage(PASTEL_TITLE .. "[RAY Загрузка]:|r Profile initialized: Spec " .. specColor .. activeSpec .. "|r")
        RAY_Engine.RebuildSpellsLookup()
        if RAY_Engine.RebuildRadarLookup then RAY_Engine.RebuildRadarLookup() end
        if RAY_Engine.UpdateEquipmentSetsCache then RAY_Engine.UpdateEquipmentSetsCache() end
        if RAY_Engine.UpdateCustomGearEnchantCache then RAY_Engine.UpdateCustomGearEnchantCache() end
        RAY_Engine.Engine_lastDbgHash = ""
        RAY_Engine.CheckAllAuras()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or (event == "UNIT_INVENTORY_CHANGED" and arg1 == "player") or (event == "UNIT_AURA" and arg1 == "player") then
        if RAY_Engine.UpdateEquipmentSetsCache then RAY_Engine.UpdateEquipmentSetsCache() end
        if RAY_Engine.UpdateCustomGearEnchantCache then RAY_Engine.UpdateCustomGearEnchantCache() end
        RAY_Engine.Engine_lastDbgHash = ""
        RAY_Engine.CheckAllAuras()
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
        local activeSpec = GetActiveTalentGroup() or 1
        local specColor = (activeSpec == 1) and COLOR_SPEC1 or COLOR_SPEC2
        DEFAULT_CHAT_FRAME:AddMessage(PASTEL_TITLE .. "[RAY Смена Спека]:|r Profile switched to Spec " .. specColor .. activeSpec .. "|r")
        wipe(RAY_Engine.activeSummonAlerts)
        wipe(RAY_Engine.activeICDTimers)
        RAY_Engine.RebuildSpellsLookup()
        RAY_Engine.Engine_lastDbgHash = ""
        RAY_Engine.CheckAllAuras()
    else
        RAY_Engine.Engine_lastDbgHash = ""
        RAY_Engine.CheckAllAuras()
    end
end)