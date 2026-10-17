-- =========================================================================
-- 1. ИНИЦИАЛИЗАЦИЯ И РАЗДЕЛЬНОЕ СОХРАНЕНИЕ НАСТРОЕК
-- =========================================================================
local addonName = "RAY"
local RAY_EventFrame = CreateFrame("Frame")

local defaultSettings = {
    enabled = true,
    fontSize = 24,
    radarEnabled = false,
    boxHunterEnabled = true,
    spells = {},
    framePos = { point = "CENTER", x = 0, y = 150 },
    specSettings = {
        [1] = { sets = {}, buffs = {}, icds = {} },
        [2] = { sets = {}, buffs = {}, icds = {} }
    }
}

-- Глобальные переменные интерфейса
local optionsPanel, subOptionsPanel
local selectedBuffIndex, selectedDebuffIndex
local listButtonsBuff, listButtonsDebuff = {}, {}
local listButtonsSub = { 
    [1] = { sets = {}, buffs = {}, icds = {} }, 
    [2] = { sets = {}, buffs = {}, icds = {} } 
}
local updateSpellLists, selectBuff, selectDebuff, CheckAllAuras
local RefreshLocalSubList

-- Кэш и переменные состояния (Оптимизация памяти)
local activeICDTimers = {}
local sylvanasAlertActive = false
local uniqueAlerts = {}
local alertStringTable = {}
local cachePlayerAuras = {}
local cacheTargetAuras = {}

-- Статичные фреймы-сканеры (Устранение утечки памяти)
local textScanFrameMain = CreateFrame("GameTooltip", "RAY_EnchantScannerTooltipMain", nil, "GameTooltipTemplate")
textScanFrameMain:SetOwner(UIParent, "ANCHOR_NONE")
local textScanFrameOff = CreateFrame("GameTooltip", "RAY_EnchantScannerTooltipOff", nil, "GameTooltipTemplate")
textScanFrameOff:SetOwner(UIParent, "ANCHOR_NONE")

local function CreateBlizzardEditBox(parent, x, y, width, name)
    local eb = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    eb:SetSize(width, 24)
    eb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal")
    eb:SetTextInsets(4, 4, 0, 0)
    return eb
end

RAY_EventFrame:RegisterEvent("ADDON_LOADED")
RAY_EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
RAY_EventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not RAY_Config then 
            RAY_Config = CopyTable(defaultSettings)
        else
            if RAY_Config.enabled == nil then RAY_Config.enabled = true end
            if RAY_Config.fontSize == nil then RAY_Config.fontSize = 24 end
            if RAY_Config.radarEnabled == nil then RAY_Config.radarEnabled = false end
            if RAY_Config.boxHunterEnabled == nil then RAY_Config.boxHunterEnabled = true end
            if not RAY_Config.spells then RAY_Config.spells = {} end
            if not RAY_Config.framePos then RAY_Config.framePos = { point = "CENTER", x = 0, y = 150 } end
            if not RAY_Config.specSettings then 
                RAY_Config.specSettings = CopyTable(defaultSettings.specSettings)
            else
                for i = 1, 2 do
                    if not RAY_Config.specSettings[i] then RAY_Config.specSettings[i] = { sets = {}, buffs = {}, icds = {} } end
                    if not RAY_Config.specSettings[i].sets then RAY_Config.specSettings[i].sets = {} end
                    if not RAY_Config.specSettings[i].buffs then RAY_Config.specSettings[i].buffs = {} end
                    if not RAY_Config.specSettings[i].icds then RAY_Config.specSettings[i].icds = {} end
                end
            end
        end
        if RAY_MainFrame and RAY_Config.framePos then
            RAY_MainFrame:ClearAllPoints()
            RAY_MainFrame:SetPoint(RAY_Config.framePos.point, UIParent, RAY_Config.framePos.point, RAY_Config.framePos.x, RAY_Config.framePos.y)
            RAY_MainFrame:SetScale((RAY_Config.fontSize or 24) / 24)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFFRAY - Remember About Yourself|r загружен. Настройка: /ray")
    end
end)

-- =========================================================================
-- 2. СОЗДАНИЕ ГЛАВНОГО ИНДИКАТОРА НА ЭКРАНЕ
-- =========================================================================
local frame = CreateFrame("Frame", "RAY_MainFrame", UIParent)
frame:SetSize(400, 60) 
frame:SetPoint("CENTER", 0, 150) 
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self) 
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint() 
    RAY_Config.framePos = { point = p, x = x, y = y } 
end)
frame:Hide()

local dragBg, dragBorder = frame:CreateTexture(nil, "BACKGROUND"), frame:CreateTexture(nil, "OVERLAY")
dragBg:SetAllPoints() dragBg:SetTexture(0.1, 0.1, 0.1, 0.6) dragBg:Hide()
dragBorder:SetAllPoints() dragBorder:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border") dragBorder:Hide()

local text = frame:CreateFontString("RAY_MainFrameText", "OVERLAY", "GameFontNormalLarge")
text:SetPoint("CENTER", frame, "CENTER") text:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE") text:SetTextColor(0, 1, 0.9) text:SetJustifyH("CENTER")

local animGroup = frame:CreateAnimationGroup()
local fadeOut = animGroup:CreateAnimation("Alpha") fadeOut:SetChange(-0.6) fadeOut:SetDuration(0.5) fadeOut:SetOrder(1)
local fadeIn = animGroup:CreateAnimation("Alpha") fadeIn:SetChange(0.6) fadeIn:SetDuration(0.5) fadeIn:SetOrder(2)
animGroup:SetLooping("REPEAT")

local function SetTooltip(widget, uText)
    widget:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT") GameTooltip:SetText(uText, 1, 1, 1, nil, true) GameTooltip:Show() end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- =========================================================================
-- 3. УНИВЕРСАЛЬНЫЙ ДВИЖОК ПРОВЕРКИ СУЩНОСТЕЙ И ЗОН
-- =========================================================================
local function GetCurrentZoneType()
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid") then
        return instanceType
    end
    if GetNumRaidMembers() > 0 then return "raid" end
    if GetNumPartyMembers() > 0 then return "party" end
    return "world"
end

local function CheckSubRules(data, inCombat, currentZone)
    if not data then return true end
    
    local zoneWorld = (data.zoneWorld == true)
    local zoneParty = (data.zoneParty == true)
    local zoneRaid = (data.zoneRaid == true)
    local onlyInCombat = (data.onlyInCombat == true)

    if currentZone == "world" and not zoneWorld then
        return false
    elseif currentZone == "party" and not zoneParty then
        return false
    elseif currentZone == "raid" and not zoneRaid then
        return false
    end
    
    if onlyInCombat and not inCombat then 
        return false 
    end
    
    return true
end

local function CheckEquipmentSetFull(setName)
    if not setName or setName == "" then return "OK" end
    local numSets = GetNumEquipmentSets() local foundName = nil
    local setLower = setName:lower()
    for i = 1, numSets do 
        local name = GetEquipmentSetInfo(i) 
        if name and name:lower() == setLower then foundName = name break end 
    end
    if not foundName then return "NOT_FOUND" end
    local setItemIDs = GetEquipmentSetItemIDs(foundName) if not setItemIDs then return "NOT_FOUND" end
    for slotID = 1, 18 do
        local savedItemID = setItemIDs[slotID]
        if savedItemID and savedItemID > 1 and GetInventoryItemID("player", slotID) ~= savedItemID then return "PARTIAL" end
    end
    return "OK"
end

local function CheckCustomGearEnchant(enchantName)
    local nameLower = enchantName:lower()
    local slotsToScan = { 16, 17, 10, 15 }

    for idx = 1, #slotsToScan do
        local slotID = slotsToScan[idx]
        
        local start, duration, enable = GetInventoryItemCooldown("player", slotID)
        if start and start > 0 and duration and duration > 1.5 then
            return true, 1, math.ceil(duration - (GetTime() - start))
        end

        textScanFrameMain:ClearLines()
        textScanFrameMain:SetInventoryItem("player", slotID)
        for i = 1, textScanFrameMain:NumLines() do
            local lineText = _G["RAY_EnchantScannerTooltipMainTextLeft"..i]
            local txt = lineText and lineText:GetText()
            if txt and txt:lower():find(nameLower, 1, true) then
                if slotID == 16 or slotID == 17 then
                    local hasMain, mainExp, _, _, hasOff, offExp = GetWeaponEnchantInfo()
                    if slotID == 16 and hasMain and mainExp then return true, 1, math.floor(mainExp / 1000) end
                    if slotID == 17 and hasOff and offExp then return true, 1, math.floor(offExp / 1000) end
                else
                    return false, 0, 0
                end
            end
        end
    end
    return false, 0, 0
end

local function BuildAuraCache(target, cacheTable)
    wipe(cacheTable)
    for i = 1, 40 do
        local name, _, _, count, _, _, expirationTime, _, _, _, spellID = UnitAura(target, i, "HELPFUL")
        if not name then break end
        local rem = (expirationTime and expirationTime > 0) and math.max(0, math.floor(expirationTime - GetTime())) or 0
        local data = { count = count or 0, rem = rem, filter = "HELPFUL" }
        cacheTable[name:lower()] = data
        cacheTable[tostring(spellID)] = data
    end
    for i = 1, 40 do
        local name, _, _, count, _, _, expirationTime, _, _, _, spellID = UnitAura(target, i, "HARMFUL")
        if not name then break end
        local rem = (expirationTime and expirationTime > 0) and math.max(0, math.floor(expirationTime - GetTime())) or 0
        local data = { count = count or 0, rem = rem, filter = "HARMFUL" }
        cacheTable[name:lower()] = data
        cacheTable[tostring(spellID)] = data
    end
end

local function FindAuraCached(target, nameOrId, filter, isCombo, isWeaponText)
    if isCombo then
local cp = GetComboPoints("player", "target")
if cp and cp > 0 then return true, cp, 0 else return false, 0, 0 end
end
if isWeaponText then
local hasEnchant, fakeStacks, secondsLeft = CheckCustomGearEnchant(nameOrId)
return hasEnchant, fakeStacks, secondsLeft
end
local cache = (target == "target") and cacheTargetAuras or cachePlayerAuras
local aura = cache[tostring(nameOrId):lower()]
if aura and aura.filter == filter then
return true, aura.count, aura.rem
end
return false, 0, 0
end
local function CheckAuraGroup(target, spellLine, filter, isCombo, isWeaponText)
local active, currentStacks, minRemaining = false, 0, 999999
for condition in string.gmatch(spellLine, "[^|/]+") do
condition = condition:match("^%s*(.-)%s*$")
local found, stacks, timeLeft = FindAuraCached(target, condition, filter, isCombo, isWeaponText)
if found then
active = true
currentStacks = math.max(currentStacks, stacks)
if timeLeft < minRemaining then minRemaining = timeLeft end
end
end
return active, currentStacks, minRemaining
end
local engineEvents = CreateFrame("Frame")
CheckAllAuras = function()
if not RAY_Config or RAY_Config.enabled == false then
text:SetText("")
frame:Hide()
animGroup:Stop()
engineEvents:UnregisterAllEvents()
return
end
if frame:IsMouseEnabled() and frame:IsShown() then return end
local inCombat = UnitAffectingCombat("player")
local currentZone = GetCurrentZoneType()
local currentSpec = GetActiveTalentGroup() or 1
local curTime = GetTime()
wipe(uniqueAlerts)
BuildAuraCache("player", cachePlayerAuras)
if UnitExists("target") and not UnitIsDead("target") then
BuildAuraCache("target", cacheTargetAuras)
else
wipe(cacheTargetAuras)
end
if sylvanasAlertActive and RAY_Config.boxHunterEnabled then
if curTime <= sylvanasAlertActive then
uniqueAlerts["|cffFF0000[RAY Детектор]: Шкатулку завел -> " .. tostring(sylvanasAlertActivePlayer or "Неизвестно") .. "!|r"] = true
else
sylvanasAlertActive = false
sylvanasAlertActivePlayer = nil
end
end
if RAY_Config.specSettings and RAY_Config.specSettings[currentSpec] then
local configData = RAY_Config.specSettings[currentSpec]
if configData.sets then
for _, set in ipairs(configData.sets) do
if set.name and set.name ~= "" and CheckSubRules(set, inCombat, currentZone) then
local status = CheckEquipmentSetFull(set.name)
if status == "NOT_FOUND" then uniqueAlerts["RAY: Комплект [" .. set.name .. "] не найден!"] = true
elseif status == "PARTIAL" then uniqueAlerts["RAY: Комплект [" .. set.name .. "] не полон!"] = true end
end
end
end
if configData.buffs then
for _, buff in ipairs(configData.buffs) do
if buff.name and buff.name ~= "" and CheckSubRules(buff, inCombat, currentZone) and not CheckAuraGroup("player", buff.name, "HELPFUL", false, false) then
uniqueAlerts["RAY: Включи [" .. buff.name .. "]!"] = true
end
end
end
if configData.icds then
for _, data in ipairs(configData.icds) do
if data.name and data.name ~= "" and CheckSubRules(data, inCombat, currentZone) then
local endTime = activeICDTimers[data.name:lower()]
local isAuraActive = CheckAuraGroup("player", data.name, "HELPFUL", false, false)
if not isAuraActive and endTime and endTime > curTime then
local remainingCD = endTime - curTime
local baseCD, alertWindow = tostring(data.seconds or "45"):match("([^/]+)/?([^/]*)")
alertWindow = tonumber(alertWindow) or 0
if alertWindow == 0 or remainingCD <= alertWindow then
uniqueAlerts["RAY: КД " .. data.name .. " (" .. math.ceil(remainingCD) .. " сек)"] = true
end
end
end
end
end
end
for _, spellData in ipairs(RAY_Config.spells or {}) do
if spellData.name and spellData.name ~= "" and CheckSubRules(spellData, inCombat, currentZone) then
local limitStacks = tonumber(spellData.minStacks) or 0
local userAlertTime = tonumber(spellData.alertTime) or 0
local prefix = (spellData.isCombo) and " КП" or " ст"
if spellData.isCooldown then
local start, duration, enabled = GetSpellCooldown(spellData.name)
local isReady = true
if start and start > 0 and duration and duration > 1.5 then
isReady = false
end
if isReady then
local displayName = string.match(spellData.name, "[^|/]+") or spellData.name
uniqueAlerts["RAY: Готово! Прожми [" .. displayName .. "]"] = true
end
else
local target = spellData.target or "player"
if target ~= "target" or (UnitExists("target") and not UnitIsDead("target")) then
local filter = (spellData.mode == "DEBUFF") and "HARMFUL" or "HELPFUL"
local isActive, stacks, timeLeft = CheckAuraGroup(target, spellData.name, filter, spellData.isCombo, spellData.isWeaponText)
if not isActive and spellData.isProc then
local isUsable = IsUsableSpell(spellData.name)
if isUsable then isActive = true stacks = 0 timeLeft = 9999 end
end
local needAlert, customReason = false, ""
                local isMax = false

                if not isActive then
                    if spellData.isStackProgress and limitStacks > 0 then
                        needAlert = true
                        customReason = " (0/" .. limitStacks .. prefix .. ")"
                    elseif not spellData.isProc and not spellData.isCombo then
                        needAlert = true
                    end
                else
                    if limitStacks > 0 and stacks >= limitStacks then
                        isMax = true
                    end

                    if spellData.isHideCap and isMax then
                        if userAlertTime > 0 and timeLeft <= userAlertTime then
                            needAlert = true
                            customReason = " (" .. timeLeft .. " сек)"
                        else
                            needAlert = false
                        end
                    elseif spellData.isStackProgress and limitStacks > 0 then
                        needAlert = true
                        customReason = " (" .. stacks .. "/" .. limitStacks .. prefix .. ")"
                    else
                        if limitStacks > 0 and (stacks <= limitStacks) and not (spellData.isProc or spellData.isCombo) then
                            needAlert = true 
                            customReason = " (Осталось: " .. stacks .. prefix .. ")"
                        elseif userAlertTime > 0 and timeLeft <= userAlertTime then
                            needAlert = true 
                            customReason = " (" .. timeLeft .. " сек)"
                        elseif spellData.isProc or spellData.isCombo then
                            needAlert = true
                            local displayStacks = (stacks > 0 and limitStacks > 0) and (" (" .. stacks .. prefix .. ")") or ""
                            local displayTime = (userAlertTime > 0 and timeLeft <= userAlertTime and timeLeft < 9000) and (" " .. timeLeft .. " сек") or ""
                            customReason = displayStacks .. displayTime
                        end
                    end
                end

                if needAlert then
                    local displayName = string.match(spellData.name, "[^|/]+") or spellData.name
                    if spellData.isCombo then displayName = "Серия приёмов (КП)" end
                    
                    local rawAlertText = (spellData.mode == "DEBUFF" and "RAY: Наложи дебафф [" or spellData.isProc and "RAY: Прок! [" or "RAY: Обнови бафф [") .. displayName .. "]" .. customReason
                    
                    if isMax or (userAlertTime > 0 and timeLeft <= userAlertTime and isActive) then
                        uniqueAlerts["|cffFF0000" .. rawAlertText .. "|r"] = true
                    else
                        uniqueAlerts[rawAlertText] = true
                    end
                end
end
end
end
end
wipe(alertStringTable)
local hasMaxStacks = false
for k, _ in pairs(uniqueAlerts) do
    table.insert(alertStringTable, k)
    -- Проверяем, есть ли в строке оповещения индикатор, что стаки собраны (например, "5/5" или "5 КП")
    for _, spellData in ipairs(RAY_Config.spells or {}) do
        local limitStacks = tonumber(spellData.minStacks) or 0
        if limitStacks > 0 and not spellData.isHideCap and not spellData.isStackProgress then
            -- Если это обычное отслеживание стаков/КП, то при достижении лимита customReason не содержит (X/Y),
            -- но мы можем перекрасить надпись, если isActive вернул полное количество стаков.
            -- Однако самый надежный и простой способ для всех режимов — найти совпадение собранного капа в строке:
            local prefix = spellData.isCombo and " КП" or " ст"
            if string.find(k, limitStacks .. prefix, 1, true) or (spellData.isStackProgress and string.find(k, limitStacks .. "/" .. limitStacks, 1, true)) then
                hasMaxStacks = true
            end
        elseif limitStacks > 0 and spellData.isStackProgress then
            if string.find(k, limitStacks .. "/" .. limitStacks, 1, true) then
                hasMaxStacks = true
            end
        end
    end
end

if #alertStringTable > 0 then
    text:SetText(table.concat(alertStringTable, "\n"))
    -- Меняем цвет текста: если кап стаков собран — ярко-красный (1, 0, 0), иначе стандартный бирюзовый (0, 1, 0.9)
    if hasMaxStacks then
        text:SetTextColor(1, 0, 0)
    else
        text:SetTextColor(0, 1, 0.9)
    end
    if not frame:IsShown() then frame:Show() animGroup:Play() end
else
    frame:Hide()
    animGroup:Stop()
end
end
-- =========================================================================
-- Лог Боя и Внутренние Кулдауны (ICD)
-- =========================================================================
local combatLogFrame = CreateFrame("Frame")
combatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
combatLogFrame:SetScript("OnEvent", function(self, event, ...)
local subEvent, sourceName, destName, spellID, spellName = select(2, ...), select(4, ...), select(7, ...), select(9, ...), select(10, ...)
if subEvent == "SPELL_AURA_APPLIED" and spellName and type(spellName) == "string" then
if RAY_Config and RAY_Config.radarEnabled then
local caster = sourceName or "Неизвестно"
DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[RAY Радар]|r |cff00FF00" .. tostring(caster) .. "|r применил: |cff00FFFF" .. tostring(spellName) .. "|r (" .. tostring(spellID) .. ")")
end
if destName == UnitName("player") then
local currentSpec = GetActiveTalentGroup() or 1
if RAY_Config.specSettings and RAY_Config.specSettings[currentSpec] and RAY_Config.specSettings[currentSpec].icds then
local combatSpellLower = spellName:lower()
local combatSpellID = tostring(spellID)
for _, data in ipairs(RAY_Config.specSettings[currentSpec].icds) do
if type(data) == "table" and data.name then
local nameLower = data.name:lower()
if nameLower == combatSpellLower or nameLower == combatSpellID then
local baseCD = tostring(data.seconds or "45"):match("([^/]+)")
activeICDTimers[nameLower] = GetTime() + (tonumber(baseCD) or 45)
CheckAllAuras()
break
end
end
end
end
end
end
end)
-- НАДЕЖНЫЙ ОХОТНИК ЗА ШКАТУЛКАМИ СИЛЬВАНЫ С МНОГОКАНАЛЬНЫМ ОПОВЕЩЕНИЕМ
local sylvanasHunterFrame = CreateFrame("Frame")
sylvanasHunterFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
sylvanasHunterFrame:SetScript("OnEvent", function(_, event, unit, spellName)
if not RAY_Config or not RAY_Config.boxHunterEnabled then return end
if event == "UNIT_SPELLCAST_SUCCEEDED" and spellName == "Плач высокорожденных" then
if UnitInRaid(unit) or UnitInParty(unit) or unit == "player" then
local now = GetTime()
local joker = UnitName(unit) or "Кто-то в рейде"
sylvanasAlertActive = now + 7
sylvanasAlertActivePlayer = joker
-- 1. Простая белая отладка лично вам в чат
DEFAULT_CHAT_FRAME:AddMessage("RAY Детектор: Обнаружен запуск шкатулки Сильваны! Шутник пойман: " .. joker)
-- Формируем текст для общих каналов
local msgText = "[RAY Детектор]: Игрок " .. joker .. " запустил Шкатулку Сильваны!"
-- 2. Отправка сообщения в рейд-чат (оранжевый) или пати-чат
if GetNumRaidMembers() > 0 then
SendChatMessage(msgText, "RAID")
elseif GetNumPartyMembers() > 0 then
SendChatMessage(msgText, "PARTY")
end
-- 3. Отправка сообщения в чат офицеров гильдии (темно-зеленый), если вы в гильдии
if IsInGuild() then
SendChatMessage(msgText, "OFFICER")
end
CheckAllAuras()
end
end
end)
for _, e in ipairs({"UNIT_AURA", "UNIT_INVENTORY_CHANGED", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ACTIONBAR_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "ACTIVE_TALENT_GROUP_CHANGED", "ZONE_CHANGED_NEW_AREA"}) do
engineEvents:RegisterEvent(e)
end
engineEvents:SetScript("OnEvent", function(self, event) CheckAllAuras() end)
-- =========================================================================
-- 4. ЕДИНЫЙ ЦЕНТР РЕГИСТРАЦИИ ИНТЕРФЕЙСА BLIZZARD
-- =========================================================================
local shortcutFrame = CreateFrame("Frame")
shortcutFrame:RegisterEvent("PLAYER_LOGIN")
shortcutFrame:SetScript("OnEvent", function()
optionsPanel = CreateFrame("Frame", "RAY_OptionsPanel", UIParent)
optionsPanel.name = "RAY"
subOptionsPanel = CreateFrame("Frame", "RAY_SubOptionsPanel", optionsPanel)
subOptionsPanel.name = "Спеки и Комплекты"
subOptionsPanel.parent = "RAY"
local title = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 16, -14)
title:SetText("|cff00FFFFНастройки модификации RAY (Remember About Yourself)|r")
local mainCb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
mainCb:SetPoint("TOPLEFT", 16, -34)
local mainCbText = mainCb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
mainCbText:SetPoint("LEFT", mainCb, "RIGHT", 5, 1)
mainCbText:SetText("Включить отображение сообщений RAY на экране")
mainCb:SetScript("OnShow", function(self) self:SetChecked(RAY_Config.enabled) end)
mainCb:SetScript("OnClick", function(self)
RAY_Config.enabled = self:GetChecked() and true or false
if RAY_Config.enabled then
for _, e in ipairs({"UNIT_AURA", "UNIT_INVENTORY_CHANGED", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ACTIONBAR_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "ACTIVE_TALENT_GROUP_CHANGED", "ZONE_CHANGED_NEW_AREA"}) do engineEvents:RegisterEvent(e) end
CheckAllAuras()
else
engineEvents:UnregisterAllEvents()
text:SetText("") frame:Hide() animGroup:Stop()
end
end)
local dragCb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
dragCb:SetPoint("TOPLEFT", 415, -34)
local dragCbText = dragCb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dragCbText:SetPoint("LEFT", dragCb, "RIGHT", 5, 1) dragCbText:SetText("|cffFFFF00Move|r")
dragCb:SetScript("OnClick", function(self)
if self:GetChecked() then
frame:EnableMouse(true) dragBg:Show() dragBorder:Show()
text:SetText("|cff00FFFF[RAY]: Зажми ЛКМ\nи перетащи меня!|r")
if not frame:IsShown() then frame:Show() animGroup:Play() end
else
frame:EnableMouse(false) dragBg:Hide() dragBorder:Hide() animGroup:Stop() CheckAllAuras()
end
end)
local fontSlider = CreateFrame("Slider", "RAY_FontScaleSliderGlobal", optionsPanel, "OptionsSliderTemplate")
fontSlider:SetSize(110, 17) fontSlider:SetPoint("TOPLEFT", 525, -34) fontSlider:SetMinMaxValues(12, 36) fontSlider:SetValueStep(1)
local fsText = fontSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") fsText:SetPoint("BOTTOM", fontSlider, "TOP", 0, 4)
fontSlider:SetScript("OnShow", function(self) local cv = RAY_Config.fontSize or 24 self:SetValue(cv) fsText:SetText("Шрифт: " .. math.floor(cv)) end)
fontSlider:SetScript("OnValueChanged", function(self, value) local val = math.floor(value) fsText:SetText("Шрифт: " .. val) RAY_Config.fontSize = val frame:SetScale(val / 24) end)
local mainScroll = CreateFrame("ScrollFrame", "RAY_MainPageScroll", optionsPanel, "UIPanelScrollFrameTemplate")
mainScroll:SetPoint("TOPLEFT", 0, -85) mainScroll:SetPoint("BOTTOMRIGHT", -26, 6)
local mainChild = CreateFrame("Frame", nil, mainScroll)
mainChild:SetSize(640, 960) mainScroll:SetScrollChild(mainChild)
local subLine = mainChild:CreateTexture(nil, "BACKGROUND")
subLine:SetWidth(2) subLine:SetHeight(920) subLine:SetPoint("TOPLEFT", 245, 0) subLine:SetTexture(0.3, 0.3, 0.3, 0.5)
local leftHeader = mainChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
leftHeader:SetPoint("TOPLEFT", 10, 0) leftHeader:SetText("|cff44FF44БАФФЫ И ПРОКИ|r")
local rightHeader = mainChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rightHeader:SetPoint("TOPLEFT", 310, 0) rightHeader:SetText("|cffFF4444ДЕБАФФЫ|r")
local editCounter, dropCounter = 0, 0
local leftUI, rightUI
local function CreateColumn(isLeft, modeType, textColorCode)
local hOffset = isLeft and 10 or 310 editCounter = editCounter + 1
local editBox = CreateBlizzardEditBox(mainChild, hOffset, -25, 175, "RAY_NewEdit_" .. editCounter)
local elabel = mainChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
elabel:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 4, 2)
elabel:SetText(textColorCode .. "Название / ID эффекта (через '/' = ИЛИ):|r")
local btnOk = CreateFrame("Button", nil, mainChild, "UIPanelButtonTemplate")
btnOk:SetSize(42, 24) btnOk:SetPoint("LEFT", editBox, "RIGHT", 8, 0) btnOk:SetText("|cffFFFF00ОК|r")
dropCounter = dropCounter + 1
local dropDown = CreateFrame("Frame", "RAY_DropDown_" .. dropCounter, mainChild, "UIDropDownMenuTemplate")
dropDown:SetPoint("TOPLEFT", hOffset - 15, -55) dropDown:SetSize(110, 25)
local tempConfig = { onlyInCombat = false, zoneWorld = false, zoneParty = false, zoneRaid = false, target = (modeType == "DEBUFF" and "target" or "player"), isCooldown = false, isProc = false, isCombo = false, isWeaponText = false, isStackProgress = false, isHideCap = false }
local function GetActiveIndex() return (modeType == "BUFF") and selectedBuffIndex or selectedDebuffIndex end
local function CreateLocalCheckbox(label, yOffset, key, tText)
local cb = CreateFrame("CheckButton", nil, mainChild, "InterfaceOptionsCheckButtonTemplate")
cb:SetPoint("TOPLEFT", hOffset, -yOffset) cb:SetScale(0.85)
local t = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
t:SetPoint("LEFT", cb, "RIGHT", 5, 1) t:SetText(textColorCode .. label .. "|r") t:SetTextColor(1, 1, 1)
cb:SetScript("OnClick", function(self)
local idx = GetActiveIndex()
local val = self:GetChecked() and true or false
if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx][key] = val CheckAllAuras() else tempConfig[key] = val end
end)
SetTooltip(cb, tText) return cb
end
local cbCombat   = CreateLocalCheckbox("Включать только в бою", 115, "onlyInCombat", "Оповещать только во время боя.")
local cbWorld    = CreateLocalCheckbox("Отслеживать в открытом мире", 137, "zoneWorld", "Проверять в открытом мире.")
local cbParty    = CreateLocalCheckbox("Отслеживать в подземельях", 159, "zoneParty", "Проверять в инстах на 5 человек.")
local cbRaid     = CreateLocalCheckbox("Отслеживать в рейдовых зонах", 181, "zoneRaid", "Проверять в рейдах.")
local cbCooldown = CreateLocalCheckbox("Отслеживать готовность КД", 203, "isCooldown", "Включите строго для проверки КД (игнорирует баффы).")
local cbProc     = CreateLocalCheckbox("Это прок (активен до траты)", 225, "isProc", "Оповещение горит постоянно при максимальном капе стаков.")
local cbCombo    = CreateLocalCheckbox("Это серия приёмов (комбо-поинты)", 247, "isCombo", "Включите для отслеживания КП разбойника/друила.")
local cbWeapon   = CreateLocalCheckbox("Это чары инженерии / оружия", 269, "isWeaponText", "Универсальное отслеживание прожимных рук/плаща и чар на оружии.")
local cbProgress = CreateLocalCheckbox("Показывать набор стаков", 291, "isStackProgress", "Будет наглядно выводить текущий сбор стаков: (1/5), (2/5)...")
local cbHideCap  = CreateLocalCheckbox("Скрыть надпись при полном наборе", 313, "isHideCap", "Для эффектов типа Раскола брони. Исчезнет на 5/5 стаках.")
local sTimeName = "RAY_SliderTimeUnique_" .. editCounter
local sliderTime = CreateFrame("Slider", sTimeName, mainChild, "OptionsSliderTemplate")
sliderTime:SetSize(105, 17) sliderTime:SetPoint("TOPLEFT", hOffset + 4, -350) sliderTime:SetMinMaxValues(0, 60) sliderTime:SetValueStep(1)
local stText = sliderTime:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
stText:SetPoint("BOTTOM", sliderTime, "TOP", 0, 2) stText:SetText(textColorCode .. "Время (сек): 0|r")
local sStacksName = "RAY_SliderStacksUnique_" .. editCounter
local sliderStacks = CreateFrame("Slider", sStacksName, mainChild, "OptionsSliderTemplate")
sliderStacks:SetSize(105, 17) sliderStacks:SetPoint("LEFT", sliderTime, "RIGHT", 15, 0) sliderStacks:SetMinMaxValues(0, 10) sliderStacks:SetValueStep(1)
local ssText = sliderStacks:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ssText:SetPoint("BOTTOM", sliderStacks, "TOP", 0, 2) ssText:SetText(textColorCode .. "Порог стаков: 0|r")
sliderTime:SetScript("OnValueChanged", function(self, value) local val = math.floor(value) stText:SetText(textColorCode .. "Время (сек): " .. val .. "|r") local idx = GetActiveIndex() if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx].alertTime = val CheckAllAuras() end end)
sliderStacks:SetScript("OnValueChanged", function(self, value) local val = math.floor(value) ssText:SetText(textColorCode .. "Порог стаков: " .. val .. "|r") local idx = GetActiveIndex() if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx].minStacks = val CheckAllAuras() end end)
local listFrame = CreateFrame("Frame", nil, mainChild)
listFrame:SetSize(210, 110) listFrame:SetPoint("TOPLEFT", editBox, "TOPLEFT", 4, -385)
UIDropDownMenu_Initialize(dropDown, function()
local currentIdx = GetActiveIndex() local activeTarget = currentIdx and RAY_Config.spells[currentIdx].target or tempConfig.target local info = UIDropDownMenu_CreateInfo()
info.text = "Цель: Игрок" info.value = "player" info.checked = (activeTarget == "player") info.func = function() local ai = GetActiveIndex() if ai and RAY_Config.spells[ai] then RAY_Config.spells[ai].target = "player" else tempConfig.target = "player" end UIDropDownMenu_SetSelectedValue(dropDown, "player") UIDropDownMenu_SetText(dropDown, "Цель: Игрок") CheckAllAuras() CloseDropDownMenus() end UIDropDownMenu_AddButton(info)
info.text = "Цель: Тек. цель" info.value = "target" info.checked = (activeTarget == "target") info.func = function() local ai = GetActiveIndex() if ai and RAY_Config.spells[ai] then RAY_Config.spells[ai].target = "target" else tempConfig.target = "target" end UIDropDownMenu_SetSelectedValue(dropDown, "target") UIDropDownMenu_SetText(dropDown, "Цель: Тек. цель") CheckAllAuras() CloseDropDownMenus() end UIDropDownMenu_AddButton(info)
end)
btnOk:SetScript("OnClick", function()
local typedName = editBox:GetText() if not typedName or typedName == "" or typedName == " " then return end local idx = GetActiveIndex()
if idx and RAY_Config.spells[idx] then
local d = RAY_Config.spells[idx] d.name = typedName d.target = UIDropDownMenu_GetSelectedValue(dropDown) or d.target d.minStacks = math.floor(sliderStacks:GetValue()) d.alertTime = math.floor(sliderTime:GetValue()) d.onlyInCombat = cbCombat:GetChecked() and true or false d.zoneWorld = cbWorld:GetChecked() and true or false d.zoneParty = cbParty:GetChecked() and true or false d.zoneRaid = cbRaid:GetChecked() and true or false d.isCooldown = cbCooldown:GetChecked() and true or false d.isProc = cbProc:GetChecked() and true or false d.isCombo = cbCombo:GetChecked() and true or false d.isWeaponText = cbWeapon:GetChecked() and true or false d.isStackProgress = cbProgress:GetChecked() and true or false d.isHideCap = cbHideCap:GetChecked() and true or false
else
table.insert(RAY_Config.spells, { name = typedName, mode = modeType, target = UIDropDownMenu_GetSelectedValue(dropDown) or tempConfig.target, minStacks = math.floor(sliderStacks:GetValue()), alertTime = math.floor(sliderTime:GetValue()), onlyInCombat = cbCombat:GetChecked() and true or false, zoneWorld = cbWorld:GetChecked() and true or false, zoneParty = cbParty:GetChecked() and true or false, zoneRaid = cbRaid:GetChecked() and true or false, isCooldown = cbCooldown:GetChecked() and true or false, isProc = cbProc:GetChecked() and true or false, isCombo = cbCombo:GetChecked() and true or false, isWeaponText = cbWeapon:GetChecked() and true or false, isStackProgress = cbProgress:GetChecked() and true or false, isHideCap = cbHideCap:GetChecked() and true or false })
end
updateSpellLists() CheckAllAuras() editBox:SetText("") cbCombat:SetChecked(false) cbWorld:SetChecked(false) cbParty:SetChecked(false) cbRaid:SetChecked(false) cbCooldown:SetChecked(false) cbProc:SetChecked(false) cbCombo:SetChecked(false) cbWeapon:SetChecked(false) cbProgress:SetChecked(false) cbHideCap:SetChecked(false) if modeType == "BUFF" then selectBuff(nil) else selectDebuff(nil) end
end)
return { editBox = editBox, sliderTime = sliderTime, sliderStacks = sliderStacks, dropDown = dropDown, listFrame = listFrame, cbCombat = cbCombat, cbWorld = cbWorld, cbParty = cbParty, cbRaid = cbRaid, cbCooldown = cbCooldown, cbProc = cbProc, cbCombo = cbCombo, cbWeapon = cbWeapon, cbProgress = cbProgress, cbHideCap = cbHideCap, stText = stText, ssText = ssText }
end
leftUI = CreateColumn(true, "BUFF", "|cff44FF44")
rightUI = CreateColumn(false, "DEBUFF", "|cffFF4444")
selectBuff = function(index)
selectedBuffIndex = index for _, btn in ipairs(listButtonsBuff) do btn:UnlockHighlight() end
if index and RAY_Config.spells[index] then
local data = RAY_Config.spells[index] leftUI.editBox:SetText(data.name or "") UIDropDownMenu_SetSelectedValue(leftUI.dropDown, data.target or "player") UIDropDownMenu_SetText(leftUI.dropDown, data.target == "target" and "Цель: Тек. цель" or "Цель: Игрок") leftUI.sliderTime:SetValue(data.alertTime or 0) leftUI.sliderStacks:SetValue(data.minStacks or 0) leftUI.cbCombat:SetChecked(data.onlyInCombat == true) leftUI.cbWorld:SetChecked(data.zoneWorld == true) leftUI.cbParty:SetChecked(data.zoneParty == true) leftUI.cbRaid:SetChecked(data.zoneRaid == true) leftUI.cbCooldown:SetChecked(data.isCooldown == true) leftUI.cbProc:SetChecked(data.isProc == true) leftUI.cbCombo:SetChecked(data.isCombo == true) leftUI.cbWeapon:SetChecked(data.isWeaponText == true) leftUI.cbProgress:SetChecked(data.isStackProgress == true) leftUI.cbHideCap:SetChecked(data.isHideCap == true)
else
leftUI.editBox:SetText("") leftUI.sliderTime:SetValue(0) leftUI.sliderStacks:SetValue(0)
leftUI.cbCombat:SetChecked(false) leftUI.cbWorld:SetChecked(false) leftUI.cbParty:SetChecked(false) leftUI.cbRaid:SetChecked(false)
leftUI.cbCooldown:SetChecked(false) leftUI.cbProc:SetChecked(false) leftUI.cbCombo:SetChecked(false) leftUI.cbWeapon:SetChecked(false) leftUI.cbProgress:SetChecked(false) leftUI.cbHideCap:SetChecked(false)
UIDropDownMenu_SetSelectedValue(leftUI.dropDown, "player") UIDropDownMenu_SetText(leftUI.dropDown, "Цель: Игрок")
end
end
selectDebuff = function(index)
selectedDebuffIndex = index for _, btn in ipairs(listButtonsDebuff) do btn:UnlockHighlight() end
if index and RAY_Config.spells[index] then
local data = RAY_Config.spells[index] rightUI.editBox:SetText(data.name or "") UIDropDownMenu_SetSelectedValue(rightUI.dropDown, data.target or "target") UIDropDownMenu_SetText(rightUI.dropDown, data.target == "target" and "Цель: Тек. цель" or "Цель: Игрок") rightUI.sliderTime:SetValue(data.alertTime or 0) rightUI.sliderStacks:SetValue(data.minStacks or 0) rightUI.cbCombat:SetChecked(data.onlyInCombat == true) rightUI.cbWorld:SetChecked(data.zoneWorld == true) rightUI.cbParty:SetChecked(data.zoneParty == true) rightUI.cbRaid:SetChecked(data.zoneRaid == true) rightUI.cbCooldown:SetChecked(data.isCooldown == true) rightUI.cbProc:SetChecked(data.isProc == true) rightUI.cbCombo:SetChecked(data.isCombo == true) rightUI.cbWeapon:SetChecked(data.isWeaponText == true) rightUI.cbProgress:SetChecked(data.isStackProgress == true) rightUI.cbHideCap:SetChecked(data.isHideCap == true)
else
rightUI.editBox:SetText("") rightUI.sliderTime:SetValue(0) rightUI.sliderStacks:SetValue(0)
rightUI.cbCombat:SetChecked(false) rightUI.cbWorld:SetChecked(false) rightUI.cbParty:SetChecked(false) rightUI.cbRaid:SetChecked(false)
rightUI.cbCooldown:SetChecked(false) rightUI.cbProc:SetChecked(false) rightUI.cbCombo:SetChecked(false) rightUI.cbWeapon:SetChecked(false) rightUI.cbProgress:SetChecked(false) rightUI.cbHideCap:SetChecked(false)
UIDropDownMenu_SetSelectedValue(rightUI.dropDown, "target") UIDropDownMenu_SetText(rightUI.dropDown, "Цель: Тек. цель")
end
end
local function SpellButton_OnClick(self)
if self.isBuff then selectBuff(self.spellIndex) else selectDebuff(self.spellIndex) end
self:LockHighlight()
end
local function SpellDeleteButton_OnClick(self)
local parent = self:GetParent()
table.remove(RAY_Config.spells, parent.spellIndex)
if parent.isBuff then selectBuff(nil) else selectDebuff(nil) end
updateSpellLists() CheckAllAuras()
end
updateSpellLists = function()
for _, btn in ipairs(listButtonsBuff) do btn:Hide() end
for _, btn in ipairs(listButtonsDebuff) do btn:Hide() end
local bCount, dCount = 1, 1
for i, spellData in ipairs(RAY_Config.spells or {}) do
local isBuff = (spellData.mode == "BUFF")
local count = isBuff and bCount or dCount
local listButtons = isBuff and listButtonsBuff or listButtonsDebuff
local ui = isBuff and leftUI or rightUI
local btn = listButtons[count]
if not btn then
btn = CreateFrame("Button", nil, ui.listFrame)
btn:SetSize(210, 20)
btn:SetNormalFontObject("GameFontNormal")
btn:SetHighlightTexture("Interface\Buttons\UI-Listbox-Highlight")
local delBtn = CreateFrame("Button", nil, btn, "UIPanelCloseButton")
delBtn:SetSize(18, 18)
delBtn:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
btn.delBtn = delBtn
btn:SetScript("OnClick", SpellButton_OnClick)
btn.delBtn:SetScript("OnClick", SpellDeleteButton_OnClick)
listButtons[count] = btn
end
btn.spellIndex = i
btn.isBuff = isBuff
btn:ClearAllPoints()
btn:SetPoint("TOPLEFT", 0, -((count - 1) * 22))
btn:SetText(((isBuff and "|cff44FF44" or "|cffFF4444") .. (string.match(spellData.name, "[^|/]+") or "Пусто") .. "|r"))
btn:Show()
SetTooltip(btn.delBtn, "Удалить эту запись.")
if isBuff then bCount = bCount + 1 else dCount = dCount + 1 end
end
end
-- =========================================================================
-- Спеки, Стойки и Автоматика Экипировки
-- =========================================================================
local subScrollFrame = CreateFrame("ScrollFrame", "RAY_SubScrollContainer", subOptionsPanel, "UIPanelScrollFrameTemplate")
subScrollFrame:SetPoint("TOPLEFT", 0, -85) subScrollFrame:SetPoint("BOTTOMRIGHT", -26, 6)
local scrollChild = CreateFrame("Frame", nil, subScrollFrame)
scrollChild:SetSize(580, 920) subScrollFrame:SetScrollChild(scrollChild)
local subTitle = subOptionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
subTitle:SetPoint("TOPLEFT", 16, -14) subTitle:SetText("|cff00FFFFАвтоматика Спеков, Стоек и Комплектов Экипировки|r")
local subNotice = subOptionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
subNotice:SetPoint("TOPLEFT", 16, -34) subNotice:SetTextColor(1, 0.8, 0)
subNotice:SetText("ВАЖНО: Формат КД тринек: КД/ОкноПоказа (Например: '45/5' - КД 45 сек, показывать за 5 сек до конца)")
local radarCb = CreateFrame("CheckButton", "RAY_RadarDebugCheckboxUnique", subOptionsPanel, "InterfaceOptionsCheckButtonTemplate")
radarCb:SetPoint("TOPLEFT", 16, -54)
local radarCbText = radarCb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
radarCbText:SetPoint("LEFT", radarCb, "RIGHT", 5, 1) radarCbText:SetText("|cffFF5555RAY-Радар|r")
radarCb:SetScript("OnShow", function(self) self:SetChecked(RAY_Config.radarEnabled) end)
radarCb:SetScript("OnClick", function(self) RAY_Config.radarEnabled = self:GetChecked() end)
SetTooltip(radarCb, "Выводить в чат ID и названия всех получаемых аур.")
local hunterCb = CreateFrame("CheckButton", "RAY_BoxHunterCheckboxUnique", subOptionsPanel, "InterfaceOptionsCheckButtonTemplate")
hunterCb:SetPoint("LEFT", radarCbText, "RIGHT", 25, 0)
local hunterCbText = hunterCb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hunterCbText:SetPoint("LEFT", hunterCb, "RIGHT", 5, 1) hunterCbText:SetText("|cff00FF00Детектор Шкатулки|r")
hunterCb:SetScript("OnShow", function(self) self:SetChecked(RAY_Config.boxHunterEnabled) end)
hunterCb:SetScript("OnClick", function(self) RAY_Config.boxHunterEnabled = self:GetChecked() sylvanasAlertActive = false CheckAllAuras() end)
SetTooltip(hunterCb, "Включает сканирование заклинания Шкатулки Сильваны.")
local btnClear = CreateFrame("Button", nil, subOptionsPanel, "UIPanelButtonTemplate")
btnClear:SetSize(55, 22) btnClear:SetPoint("LEFT", hunterCbText, "RIGHT", 25, -1) btnClear:SetText("|cffFF3333Clear|r")
local nTex = btnClear:GetNormalTexture() if nTex then nTex:SetVertexColor(1, 0.2, 0.2, 0.9) end
btnClear:SetScript("OnClick", function() RAY_Config = nil ReloadUI() end)
local subLine2 = scrollChild:CreateTexture(nil, "BACKGROUND")
subLine2:SetWidth(2) subLine2:SetHeight(880) subLine2:SetPoint("TOPLEFT", 295, 0) subLine2:SetTexture(0.3, 0.3, 0.3, 0.5)
local subLeftHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal") subLeftHeader:SetPoint("TOPLEFT", 10, 0) subLeftHeader:SetText("|cff44FF44ПЕРВАЯ ВЕТКА (СПЕК 1)|r")
local subRightHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal") subRightHeader:SetPoint("TOPLEFT", 310, 0) subRightHeader:SetText("|cffFF4444ВТОРАЯ ВЕТКА (СПЕК 2)|r")
local function SubButton_OnClick(self)
local data = RAY_Config.specSettings[self.specNum][self.storageKey][self.itemIndex]
if type(data) == "table" then
self.activeIndices[self.storageKey] = self.itemIndex
for _, b in ipairs(listButtonsSub[self.specNum][self.storageKey]) do b:UnlockHighlight() end
self:LockHighlight()
if self.isIcd then
self.boxName:SetText(data.name or "") self.boxSec:SetText(data.seconds or "45")
else
self.editBox:SetText(data.name or "")
end
self.cbCombat:SetChecked(data.onlyInCombat == true) self.cbWorld:SetChecked(data.zoneWorld == true) self.cbParty:SetChecked(data.zoneParty == true) self.cbRaid:SetChecked(data.zoneRaid == true)
end
end
local function SubDeleteButton_OnClick(self)
local parent = self:GetParent()
table.remove(RAY_Config.specSettings[parent.specNum][parent.storageKey], parent.itemIndex)
parent.activeIndices[parent.storageKey] = nil
if parent.isIcd then parent.boxName:SetText("") parent.boxSec:SetText("") else parent.editBox:SetText("") end
RefreshLocalSubList(parent.specNum, parent.storageKey) CheckAllAuras()
end
RefreshLocalSubList = function(specNum, storageKey)
local pBlock = listButtonsSub[specNum][storageKey]
for _, b in ipairs(pBlock) do b:Hide() end
if not RAY_Config or not RAY_Config.specSettings or not RAY_Config.specSettings[specNum] or not RAY_Config.specSettings[specNum][storageKey] then return end
for idx, data in ipairs(RAY_Config.specSettings[specNum][storageKey]) do
local isIcd = (storageKey == "icds")
local textStr = type(data) == "table" and ((data.name or "Ошибка") .. (isIcd and (" ("..(data.seconds or "45").."с)") or "")) or tostring(data)
local btn = pBlock[idx]
if not btn then
btn = CreateFrame("Button", nil, pBlock.listFrame)
btn:SetSize(210, 20)
btn:SetNormalFontObject("GameFontNormal")
btn:SetHighlightTexture("Interface\Buttons\UI-Listbox-Highlight")
local del = CreateFrame("Button", nil, btn, "UIPanelCloseButton")
del:SetSize(18, 18)
del:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
btn.del = del
pBlock[idx] = btn
end
btn.specNum = specNum btn.storageKey = storageKey btn.itemIndex = idx btn.isIcd = isIcd
btn.activeIndices = pBlock.activeIndices btn.boxName = pBlock.boxName btn.boxSec = pBlock.boxSec btn.editBox = pBlock.editBox
btn.cbCombat = pBlock.cbCombat btn.cbWorld = pBlock.cbWorld btn.cbParty = pBlock.cbParty btn.cbRaid = pBlock.cbRaid
btn:SetScript("OnClick", SubButton_OnClick)
btn.del:SetScript("OnClick", SubDeleteButton_OnClick)
btn:ClearAllPoints()
btn:SetPoint("TOPLEFT", 0, -((idx - 1) * 22))
btn:SetText(textStr) btn:Show() SetTooltip(btn.del, "Удалить эту запись.")
if pBlock.activeIndices[storageKey] == idx then btn:LockHighlight() else btn:UnlockHighlight() end
end
end
local function CreateSubPageBlock(specNum, isLeft, headerColorCode)
local hOffsetSub = isLeft and 10 or 310 local activeIndices = { sets = nil, buffs = nil, icds = nil }
local function BuildInputFieldBlock(labelTxt, yBlock, storageKey, tText, isIcd)
local editBox, boxName, boxSec
if isIcd then
boxName = CreateBlizzardEditBox(scrollChild, hOffsetSub, yBlock - 20, 140, "RAY_SubIcdName_"..specNum..""..storageKey) SetTooltip(boxName, tText)
boxSec = CreateBlizzardEditBox(scrollChild, hOffsetSub + 145, yBlock - 20, 35, "RAY_SubIcdSec"..specNum..""..storageKey) boxSec:SetMaxLetters(7)
editBox = boxName
else
editBox = CreateBlizzardEditBox(scrollChild, hOffsetSub, yBlock - 20, 180, "RAY_SubInp"..specNum.."_"..storageKey) SetTooltip(editBox, tText)
end
local label = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") label:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 4, 2) label:SetText(headerColorCode .. labelTxt .. "|r")
local btnOk = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate") btnOk:SetSize(42, 24) btnOk:SetPoint("LEFT", isIcd and boxSec or editBox, "RIGHT", 8, 0) btnOk:SetText("|cffFFFF00ОК|r")
local function CreateSubCheckbox(lbl, yOffset, key)
local cb = CreateFrame("CheckButton", nil, scrollChild, "InterfaceOptionsCheckButtonTemplate") cb:SetPoint("TOPLEFT", hOffsetSub, yBlock - yOffset)
local t = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") t:SetPoint("LEFT", cb, "RIGHT", 5, 1) t:SetText(headerColorCode .. lbl .. "|r")
cb:SetScript("OnClick", function(self)
if RAY_Config and RAY_Config.specSettings and RAY_Config.specSettings[specNum] and RAY_Config.specSettings[specNum][storageKey] then
local idx = activeIndices[storageKey]
if idx and RAY_Config.specSettings[specNum][storageKey][idx] then
RAY_Config.specSettings[specNum][storageKey][idx][key] = self:GetChecked() and true or false
CheckAllAuras()
end
end
end)
cb:SetChecked(false) return cb
end
local cbCombat = CreateSubCheckbox("Включать только в бою", 50, "onlyInCombat")
local cbWorld  = CreateSubCheckbox("Отслеживать в открытом мире", 72, "zoneWorld")
local cbParty  = CreateSubCheckbox("Отслеживать в подземельях", 94, "zoneParty")
local cbRaid   = CreateSubCheckbox("Отслеживать в рейдовых зонах", 116, "zoneRaid")
local listFrame = CreateFrame("Frame", nil, scrollChild)
listFrame:SetSize(235, 85)
listFrame:SetPoint("TOPLEFT", editBox, "TOPLEFT", 4, -145)
listButtonsSub[specNum][storageKey].listFrame = listFrame
listButtonsSub[specNum][storageKey].activeIndices = activeIndices
listButtonsSub[specNum][storageKey].boxName = boxName
listButtonsSub[specNum][storageKey].boxSec = boxSec
listButtonsSub[specNum][storageKey].editBox = editBox
listButtonsSub[specNum][storageKey].cbCombat = cbCombat
listButtonsSub[specNum][storageKey].cbWorld = cbWorld
listButtonsSub[specNum][storageKey].cbParty = cbParty
listButtonsSub[specNum][storageKey].cbRaid = cbRaid
btnOk:SetScript("OnClick", function()
local txt = editBox:GetText() if not txt or txt == "" or txt == " " then return end
if not RAY_Config.specSettings[specNum][storageKey] then RAY_Config.specSettings[specNum][storageKey] = {} end
local activeIdx = activeIndices[storageKey]
local itemData = { name = txt, seconds = isIcd and (boxSec:GetText() or "45") or nil, onlyInCombat = cbCombat:GetChecked() and true or false, zoneWorld = cbWorld:GetChecked() and true or false, zoneParty = cbParty:GetChecked() and true or false, zoneRaid = cbRaid:GetChecked() and true or false }
if activeIdx and RAY_Config.specSettings[specNum][storageKey][activeIdx] then RAY_Config.specSettings[specNum][storageKey][activeIdx] = itemData else table.insert(RAY_Config.specSettings[specNum][storageKey], itemData) end
activeIndices[storageKey] = nil if isIcd then boxName:SetText("") boxSec:SetText("") else editBox:SetText("") end cbCombat:SetChecked(false) cbWorld:SetChecked(false) cbParty:SetChecked(false) cbRaid:SetChecked(false) RefreshLocalSubList(specNum, storageKey) CheckAllAuras()
end)
subOptionsPanel:HookScript("OnShow", function() activeIndices[storageKey] = nil if isIcd then boxName:SetText("") boxSec:SetText("") else editBox:SetText("") end RefreshLocalSubList(specNum, storageKey) end)
end
BuildInputFieldBlock("Комплект экипировки:", -25, "sets", "Введите название комплекта экипировки.", false)
BuildInputFieldBlock("Обязательная стойка / бафф:", -285, "buffs", "Введите название стойки или баффа.", false)
BuildInputFieldBlock("Имя ПРОКА триньки / КД:", -545, "icds", "Формат: КД/ОкноПоказа (например, 45/5)", true)
end
CreateSubPageBlock(1, true, "|cff44FF44")
CreateSubPageBlock(2, false, "|cffFF4444")
InterfaceOptions_AddCategory(optionsPanel)
InterfaceOptions_AddCategory(subOptionsPanel)
updateSpellLists()
end)
SLASH_RAY1 = "/ray"
SlashCmdList["RAY"] = function()
if optionsPanel then
InterfaceOptionsFrame_OpenToCategory(optionsPanel)
InterfaceOptionsFrame_OpenToCategory(optionsPanel)
end
end
