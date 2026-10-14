-- =========================================================================
-- 1. ИНИЦИАЛИЗАЦИЯ И РАЗДЕЛЬНОЕ СОХРАНЕНИЕ НАСТРОЕК ДЛЯ КАЖДОГО ПЕРСОНАЖА
-- =========================================================================
local addonName = "RAY"
local RAY_EventFrame = CreateFrame("Frame")

-- Глобальные константы интерфейса
local MAX_VISIBLE_HEIGHT = 115

local defaultSettings = {
    enabled = true,
    fontSize = 24,
    radarEnabled = false,
    spells = {},
    framePos = { point = "CENTER", x = 0, y = 150 },
    specSettings = {}
}

-- Инициализация структуры веток талантов
defaultSettings.specSettings = { sets = {}, buffs = {}, icds = {} }
defaultSettings.specSettings = { sets = {}, buffs = {}, icds = {} }

local optionsPanel, subOptionsPanel, selectedBuffIndex, selectedDebuffIndex
local listButtonsBuff, listButtonsDebuff, listButtonsSub = {}, {}, {}
local updateSpellLists, selectBuff, selectDebuff, CheckAllAuras
local activeICDTimers = {}

RAY_EventFrame:RegisterEvent("ADDON_LOADED")
RAY_EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
RAY_EventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not RAY_Config then 
            RAY_Config = defaultSettings 
        else
            if RAY_Config.enabled == nil then RAY_Config.enabled = true end
            if RAY_Config.fontSize == nil then RAY_Config.fontSize = 24 end
            if RAY_Config.radarEnabled == nil then RAY_Config.radarEnabled = false end
            if not RAY_Config.spells then RAY_Config.spells = {} end
            if not RAY_Config.framePos then 
                RAY_Config.framePos = { point = "CENTER", x = 0, y = 150 } 
            end
            if not RAY_Config.specSettings then 
                RAY_Config.specSettings = {}
            end
            if not RAY_Config.specSettings then
                RAY_Config.specSettings = { sets = {}, buffs = {}, icds = {} }
            end
            if not RAY_Config.specSettings then
                RAY_Config.specSettings = { sets = {}, buffs = {}, icds = {} }
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
    local p, _, _, x, y = self:GetPoint() 
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
    widget:SetScript("OnEnter", function(self) 
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT") 
        GameTooltip:SetText(uText, 1, 1, 1, nil, true) 
        GameTooltip:Show() 
    end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- =========================================================================
-- 3. УНИВЕРСАЛЬНЫЙ ДВИЖОК ПРОВЕРКИ СУЩНОСТЕЙ И ЖУРНАЛА БОЯ
-- =========================================================================
local function GetCurrentZoneType()
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid") then return instanceType end
    if (GetNumRaidMembers and GetNumRaidMembers() > 0) or (IsInRaid and IsInRaid()) then return "raid" end
    if (GetNumPartyMembers and GetNumPartyMembers() > 0) or (IsInGroup and IsInGroup()) then return "party" end
    return "world"
end

local function CheckSubRules(data, inCombat, currentZone)
    if not data then return true end
    if data.onlyInCombat and not inCombat then return false end
    if currentZone == "world" and data.zoneWorld == false then return false end
    if currentZone == "party" and data.zoneParty == false then return false end
    if currentZone == "raid" and data.zoneRaid == false then return false end
    return true
end

local function CheckEquipmentSetFull(setName)
    if not setName or setName == "" then return "OK" end
    local numSets = GetNumEquipmentSets() local foundName = nil
    for i = 1, numSets do local name = GetEquipmentSetInfo(i) if name and name:lower() == setName:lower() then foundName = name break end end
    if not foundName then return "NOT_FOUND" end
    local setItemIDs = GetEquipmentSetItemIDs(foundName) if not setItemIDs then return "NOT_FOUND" end
    for slotID = 1, 18 do
        local savedItemID = setItemIDs[slotID]
        if savedItemID and savedItemID > 1 and GetInventoryItemID("player", slotID) ~= savedItemID then return "PARTIAL" end
    end
    return "OK"
end

local function CheckWeaponEnchant(enchantName)
    local hasMain, mainExpiration, _, _, hasOff, offExpiration, _, _ = GetWeaponEnchantInfo()
    local nameLower = enchantName:lower()

    if hasMain and mainExpiration then
        local textScanFrame = CreateFrame("GameTooltip", "RAY_EnchantScannerTooltip", nil, "GameTooltipTemplate")
        textScanFrame:SetOwner(UIParent, "ANCHOR_NONE")
        textScanFrame:SetInventoryItem("player", 16)
        for i = 1, textScanFrame:NumLines() do
            local lineText = _G["RAY_EnchantScannerTooltipTextLeft"..i]
            if lineText and lineText:GetText() and lineText:GetText():lower():find(nameLower) then
                return true, 1, math.floor(mainExpiration / 1000)
            end
        end
    end

    if hasOff and offExpiration then
        local textScanFrame = CreateFrame("GameTooltip", "RAY_EnchantScannerTooltip2", nil, "GameTooltipTemplate")
        textScanFrame:SetOwner(UIParent, "ANCHOR_NONE")
        textScanFrame:SetInventoryItem("player", 17)
        for i = 1, textScanFrame:NumLines() do
            local lineText = _G["RAY_EnchantScannerTooltip2TextLeft"..i]
            if lineText and lineText:GetText() and lineText:GetText():lower():find(nameLower) then
                return true, 1, math.floor(offExpiration / 1000)
            end
        end
    end

    return false, 0, 0
end

local function FindAura(target, nameOrId, filter, isCombo, isWeaponText)
    local checkId = tonumber(nameOrId) 
    local nameLower = not checkId and nameOrId:lower() or nil
    
    if isCombo then
        local cp = GetComboPoints("player", "target")
        if cp and cp > 0 then return true, cp, 0 else return false, 0, 0 end
    end

    if isWeaponText and filter == "HELPFUL" and nameLower then
        local hasEnchant, fakeStacks, secondsLeft = CheckWeaponEnchant(nameOrId)
        if hasEnchant then return true, fakeStacks, secondsLeft end
    end

    for i = 1, 40 do
        local name, _, _, count, _, _, expirationTime, _, _, _, spellID = UnitAura(target, i, filter)
        if not name then break end
        if checkId and spellID == checkId then 
            local rem = expirationTime > 0 and math.max(0, math.floor(expirationTime - GetTime())) or 0
            return true, count or 0, rem
        elseif nameLower and name:lower() == nameLower then 
            local rem = expirationTime > 0 and math.max(0, math.floor(expirationTime - GetTime())) or 0
            return true, count or 0, rem
        end
    end
    return false, 0, 0
end

local function CheckAuraGroup(target, spellLine, filter, isCombo, isWeaponText)
    local active, currentStacks, minRemaining = false, 0, 999999
    for condition in string.gmatch(spellLine, "[^|/]+") do
        condition = condition:match("^%s*(.-)%s*$")
        local found, stacks, timeLeft = FindAura(target, condition, filter, isCombo, isWeaponText)
        if found then 
            active = true 
            currentStacks = math.max(currentStacks, stacks) 
            if timeLeft < minRemaining then minRemaining = timeLeft end 
        end
    end
    return active, currentStacks, minRemaining
end

CheckAllAuras = function()
    if (frame:IsMouseEnabled() and frame:IsShown()) or not RAY_Config or not RAY_Config.enabled then return end
    local uniqueAlerts, inCombat, currentZone, currentSpec, curTime = {}, UnitAffectingCombat("player"), GetCurrentZoneType(), GetActiveTalentGroup(), GetTime()
    
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
if endTime and endTime > curTime then uniqueAlerts["RAY: КД " .. data.name .. " (" .. math.ceil(endTime - curTime) .. " сек)"] = true end
end
end
end
end
for _, spellData in ipairs(RAY_Config.spells or {}) do
if spellData.name and spellData.name ~= "" and CheckSubRules(spellData, inCombat, currentZone) then
local target = spellData.target or "player"
if target ~= "target" or (UnitExists("target") and not UnitIsDead("target")) then
local filter = (spellData.mode == "DEBUFF") and "HARMFUL" or "HELPFUL"
local isActive, stacks, timeLeft = CheckAuraGroup(target, spellData.name, filter, spellData.isCombo, spellData.isWeaponText)
local needAlert, customReason = false, ""
local limitStacks = tonumber(spellData.minStacks) or 0
local userAlertTime = tonumber(spellData.alertTime) or 0
if spellData.isProc then
if isActive then
if limitStacks == 0 or (stacks >= limitStacks) then
if userAlertTime == 0 or (timeLeft <= userAlertTime) then
needAlert = true
local prefix = (spellData.isCombo) and " КП" or " ст"
local displayStacks = (stacks > 0) and (" (" .. stacks .. prefix .. ")") or ""
local displayTime = (userAlertTime > 0 and timeLeft > 0 and timeLeft <= 9000) and (" " .. timeLeft .. " сек") or ""
customReason = displayStacks .. displayTime
end
end
end
elseif spellData.isCooldown then
if GetSpellCooldown(spellData.name) == 0 and not isActive then needAlert = true end
else
if not isActive then
needAlert = true
else
if limitStacks > 0 and (stacks <= limitStacks) then
needAlert = true
local prefix = (spellData.isCombo) and " КП" or " ст"
customReason = " (Осталось: " .. stacks .. prefix .. ")"
elseif userAlertTime > 0 and timeLeft <= userAlertTime then
needAlert = true
customReason = " (" .. timeLeft .. " сек)"
end
end
end
if needAlert then
local displayName = string.match(spellData.name, "[^|/]+") or spellData.name
if spellData.isCombo then displayName = "Серия приёмов (КП)" end
uniqueAlerts[(spellData.mode == "DEBUFF" and "RAY: Наложи дебафф [" or spellData.isProc and "RAY: Прок! [" or spellData.isCooldown and "RAY: Готово! Прожми [" or "RAY: Обнови бафф [") .. displayName .. "]" .. customReason] = true
end
end
end
end
local alertText = ""
for k, _ in pairs(uniqueAlerts) do alertText = alertText .. (alertText ~= "" and "\n" or "") .. k end
if alertText ~= "" then text:SetText(alertText) if not frame:IsShown() then frame:Show() animGroup:Play() end else frame:Hide() animGroup:Stop() end
end
local combatLogFrame = CreateFrame("Frame")
combatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
combatLogFrame:SetScript("OnEvent", function(self, event, ...)
local subEvent, destName, spellID, spellName = select(2, ...), select(7, ...), select(9, ...), select(10, ...)
if subEvent == "SPELL_AURA_APPLIED" and destName == UnitName("player") and spellName then
if RAY_Config and RAY_Config.radarEnabled then DEFAULT_CHAT_FRAME:AddMessage("|cffFFFF00[RAY Радар]|r Поймана аура: |cff00FF00" .. tostring(spellName) .. "|r (ID: " .. tostring(spellID) .. ")") end
local currentSpec = GetActiveTalentGroup()
if RAY_Config.specSettings and RAY_Config.specSettings[currentSpec] and RAY_Config.specSettings[currentSpec].icds then
local combatSpellLower, combatSpellID = spellName:lower(), tostring(spellID)
for _, data in ipairs(RAY_Config.specSettings[currentSpec].icds) do
if type(data) == "table" and data.name and (combatSpellLower:find(data.name:lower()) or data.name:lower():find(combatSpellLower) or data.name == combatSpellID) then
activeICDTimers[data.name:lower()] = GetTime() + (tonumber(data.seconds) or 45) CheckAllAuras() break
end
end
end
end
end)
local engineEvents = CreateFrame("Frame")
for _, e in ipairs({"UNIT_AURA", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ACTIONBAR_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "ACTIVE_TALENT_GROUP_CHANGED", "EQUIPMENT_SETS_CHANGED"}) do engineEvents:RegisterEvent(e) end
engineEvents:SetScript("OnEvent", function(self, event, unit) if event == "UNIT_AURA" and unit ~= "player" and unit ~= "target" then return end CheckAllAuras() end)
local ticker = CreateFrame("Frame") local tTime = 0
ticker:SetScript("OnUpdate", function(self, elapsed) tTime = tTime + elapsed if tTime >= 0.4 then tTime = 0 CheckAllAuras() end end)
local function CreateBlizzardEditBox(parent, x, y, width, name)
local eb = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
eb:SetSize(width, 24) eb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y) eb:SetAutoFocus(false) eb:SetFontObject("ChatFontNormal") eb:SetTextInsets(4, 4, 0, 0)
return eb
end
-- =========================================================================
-- 4. ЕДИНЫЙ ЦЕНТР РЕГИСТРАЦИИ ИНТЕРФЕЙСА BLIZZARD (ОБЕ СТРАНИЦЫ ВМЕСТЕ)
-- =========================================================================
local shortcutFrame = CreateFrame("Frame") 
shortcutFrame:RegisterEvent("PLAYER_LOGIN")
shortcutFrame:SetScript("OnEvent", function()
    -- ИСПРАВЛЕHО: Родительские панели объявлены в самом верху, чтобы функции ниже их видели
    optionsPanel = CreateFrame("Frame", "RAY_OptionsPanel", UIParent) 
    optionsPanel.name = "RAY"
    
    subOptionsPanel = CreateFrame("Frame", "RAY_SubOptionsPanel", optionsPanel)
    subOptionsPanel.name = "Спеки и Комплекты" 
    subOptionsPanel.parent = "RAY"

    -- 4.1 НАСТРОЙКА СТРАНИЦЫ №1 (ГЛАВНАЯ С ПРОКРУТКОЙ)
    local title = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal") 
    title:SetPoint("TOPLEFT", 16, -14) 
    title:SetText("|cff00FFFFНастройки модификации RAY (Remember About Yourself)|r")
    
    local mainCb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate") 
    mainCb:SetPoint("TOPLEFT", 16, -34)
    local mainCbText = mainCb:CreateFontString(nil, "OVERLAY", "GameFontHighlight") 
    mainCbText:SetPoint("LEFT", mainCb, "RIGHT", 5, 1) 
    mainCbText:SetText("Включить отображение сообщений RAY на экране")
    mainCb:SetScript("OnShow", function(self) self:SetChecked(RAY_Config.enabled) end) 
    mainCb:SetScript("OnClick", function(self) RAY_Config.enabled = self:GetChecked() CheckAllAuras() end)

    local dragCb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate") 
    dragCb:SetPoint("TOPLEFT", 415, -34)
    local dragCbText = dragCb:CreateFontString(nil, "OVERLAY", "GameFontNormal") 
    dragCbText:SetPoint("LEFT", dragCb, "RIGHT", 5, 1) dragCbText:SetText("|cffFFFF00Move|r")
    dragCb:SetScript("OnClick", function(self) 
        if self:GetChecked() then frame:EnableMouse(true) dragBg:Show() dragBorder:Show() text:SetText("|cff00FFFF[RAY]: Зажми ЛКМ\nи перетащи меня!|r") if not frame:IsShown() then frame:Show() animGroup:Play() end 
        else frame:EnableMouse(false) dragBg:Hide() dragBorder:Hide() animGroup:Stop() CheckAllAuras() end 
    end)

    local fontSlider = CreateFrame("Slider", "RAY_FontScaleSliderGlobal", optionsPanel, "OptionsSliderTemplate") 
    fontSlider:SetSize(110, 17) fontSlider:SetPoint("TOPLEFT", 525, -34) fontSlider:SetMinMaxValues(12, 36) fontSlider:SetValueStep(1)
    local fsText = fontSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") fsText:SetPoint("BOTTOM", fontSlider, "TOP", 0, 4)
    fontSlider:SetScript("OnShow", function(self) local cv = RAY_Config.fontSize or 24 self:SetValue(cv) fsText:SetText("Шрифт: " .. math.floor(cv)) end)
    fontSlider:SetScript("OnValueChanged", function(self, value) local val = math.floor(value) fsText:SetText("Шрифт: " .. val) RAY_Config.fontSize = val frame:SetScale(val / 24) end)

    local mainScroll = CreateFrame("ScrollFrame", "RAY_MainPageScroll", optionsPanel, "UIPanelScrollFrameTemplate")
    mainScroll:SetPoint("TOPLEFT", 0, -85) mainScroll:SetPoint("BOTTOMRIGHT", -26, 6)
    
    local mainChild = CreateFrame("Frame", nil, mainScroll) 
    mainChild:SetSize(580, 920) mainScroll:SetScrollChild(mainChild)

    local subLine = mainChild:CreateTexture(nil, "BACKGROUND") 
    subLine:SetWidth(2) subLine:SetHeight(880) subLine:SetPoint("TOPLEFT", 245, 0) subLine:SetTexture(0.3, 0.3, 0.3, 0.5)
    
    local leftHeader = mainChild:CreateFontString(nil, "OVERLAY", "GameFontNormal") 
    leftHeader:SetPoint("TOPLEFT", 10, 0) leftHeader:SetText("|cff44FF44БАФФЫ И ПРОКИ|r")
    
    local rightHeader = mainChild:CreateFontString(nil, "OVERLAY", "GameFontNormal") 
    rightHeader:SetPoint("TOPLEFT", 265, 0) rightHeader:SetText("|cffFF4444ДЕБАФФЫ|r")
    
    local editCounter, dropCounter = 0, 0
    local function CreateColumn(isLeft, modeType, textColorCode)
        local hOffset = isLeft and 10 or 310 editCounter = editCounter + 1
        
        local editBox = CreateBlizzardEditBox(mainChild, hOffset, -25, 175, "RAY_NewEdit_" .. editCounter)
        local elabel = mainChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") 
        elabel:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 4, 2) elabel:SetText(textColorCode .. "Название / ID эффекта:|r")
        
        local btnOk = CreateFrame("Button", nil, mainChild, "UIPanelButtonTemplate") 
        btnOk:SetSize(42, 24) btnOk:SetPoint("LEFT", editBox, "RIGHT", 8, 0) btnOk:SetText("|cffFFFF00ОК|r")
        
        dropCounter = dropCounter + 1 
        local dropDown = CreateFrame("Frame", "RAY_DropDown_" .. dropCounter, mainChild, "UIDropDownMenuTemplate") 
        dropDown:SetPoint("TOPLEFT", hOffset - 15, -55) dropDown:SetSize(110, 25)
        
        local tempConfig = { onlyInCombat = true, zoneWorld = true, zoneParty = true, zoneRaid = true, target = (modeType == "DEBUFF" and "target" or "player"), isCooldown = false, isProc = false, isCombo = false, isWeaponText = false }
        local function GetActiveIndex() return (modeType == "BUFF") and selectedBuffIndex or selectedDebuffIndex end
        
        local function CreateLocalCheckbox(label, yOffset, key, tText)
            local cb = CreateFrame("CheckButton", nil, mainChild, "InterfaceOptionsCheckButtonTemplate") 
            cb:SetPoint("TOPLEFT", hOffset, -yOffset) cb:SetScale(0.85)
            local t = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") 
            t:SetPoint("LEFT", cb, "RIGHT", 5, 1) t:SetText(textColorCode .. label .. "|r")
            cb:SetScript("OnClick", function(self) 
                local idx = GetActiveIndex() 
                if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx][key] = self:GetChecked() CheckAllAuras() else tempConfig[key] = self:GetChecked() end 
            end)
            SetTooltip(cb, tText) return cb
        end
        
        local cbCombat   = CreateLocalCheckbox("Включать только в бою", 85, "onlyInCombat", "Оповещать только во время боя.")
        local cbWorld    = CreateLocalCheckbox("Отслеживать в открытом мире", 107, "zoneWorld", "Проверять в открытом мире.")
        local cbParty    = CreateLocalCheckbox("Отслеживать в подземельях", 129, "zoneParty", "Проверять в инстах на 5 человек.")
        local cbRaid     = CreateLocalCheckbox("Отслеживать в рейдовых зонах", 151, "zoneRaid", "Проверять в рейдах.")
        local cbCooldown = CreateLocalCheckbox("Отслеживать готовность КД", 173, "isCooldown", "Оповестит, когда способность выйдет из КД.")
        local cbProc     = CreateLocalCheckbox("Это прок (активен порог стаков)", 195, "isProc", "Включает логику накопления стаков (выведет уведомление при >= порога).")
        local cbCombo    = CreateLocalCheckbox("Это серия приёмов (комбо-поинты)", 217, "isCombo", "Включите для отслеживания КП разбойника/друида. Серия сработает при достижении порога стаков.")
        local cbWeapon   = CreateLocalCheckbox("Это чары на оружии (шаман/яды)", 239, "isWeaponText", "Включите для сканирования временных чар оружия (Неистовство ветра, Язык пламени, роговские яды). Пишите точное имя чарки!")
        
        local sTimeName = "RAY_SliderTimeUnique_" .. editCounter 
        local sliderTime = CreateFrame("Slider", sTimeName, mainChild, "OptionsSliderTemplate") 
        sliderTime:SetSize(105, 17) sliderTime:SetPoint("TOPLEFT", hOffset + 4, -280) sliderTime:SetMinMaxValues(0, 60) sliderTime:SetValueStep(1)
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
        listFrame:SetSize(210, 110) listFrame:SetPoint("TOPLEFT", editBox, "TOPLEFT", 4, -315)
        
        UIDropDownMenu_Initialize(dropDown, function()
            local currentIdx = GetActiveIndex() local activeTarget = currentIdx and RAY_Config.spells[currentIdx].target or tempConfig.target local info = UIDropDownMenu_CreateInfo()
            info.text = "Цель: Игрок" info.value = "player" info.checked = (activeTarget == "player") info.func = function() local ai = GetActiveIndex() if ai and RAY_Config.spells[ai] then RAY_Config.spells[ai].target = "player" else tempConfig.target = "player" end UIDropDownMenu_SetSelectedValue(dropDown, "player") UIDropDownMenu_SetText(dropDown, "Цель: Игрок") CheckAllAuras() CloseDropDownMenus() end UIDropDownMenu_AddButton(info)
info.text = "Цель: Таргет" info.value = "target" info.checked = (activeTarget == "target") info.func = function() local ai = GetActiveIndex() if ai and RAY_Config.spells[ai] then RAY_Config.spells[ai].target = "target" else tempConfig.target = "target" end UIDropDownMenu_SetSelectedValue(dropDown, "target") UIDropDownMenu_SetText(dropDown, "Цель: Таргет") CheckAllAuras() CloseDropDownMenus() end UIDropDownMenu_AddButton(info)
end)
btnOk:SetScript("OnClick", function()
local typedName = editBox:GetText() if not typedName or typedName == "" or typedName == " " then return end local idx = GetActiveIndex()
if idx and RAY_Config.spells[idx] then
local d = RAY_Config.spells[idx] d.name = typedName d.target = UIDropDownMenu_GetSelectedValue(dropDown) or d.target d.minStacks = math.floor(sliderStacks:GetValue()) d.alertTime = math.floor(sliderTime:GetValue()) d.onlyInCombat = cbCombat:GetChecked() d.zoneWorld = cbWorld:GetChecked() d.zoneParty = cbParty:GetChecked() d.zoneRaid = cbRaid:GetChecked() d.isCooldown = cbCooldown:GetChecked() d.isProc = cbProc:GetChecked() d.isCombo = cbCombo:GetChecked() d.isWeaponText = cbWeapon:GetChecked()
else
table.insert(RAY_Config.spells, { name = typedName, mode = modeType, target = UIDropDownMenu_GetSelectedValue(dropDown) or tempConfig.target, minStacks = math.floor(sliderStacks:GetValue()), alertTime = math.floor(sliderTime:GetValue()), onlyInCombat = cbCombat:GetChecked(), zoneWorld = cbWorld:GetChecked(), zoneParty = cbParty:GetChecked(), zoneRaid = cbRaid:GetChecked(), isCooldown = cbCooldown:GetChecked(), isProc = cbProc:GetChecked(), isCombo = cbCombo:GetChecked(), isWeaponText = cbWeapon:GetChecked() })
end
updateSpellLists() CheckAllAuras() editBox:SetText("") cbCombat:SetChecked(true) cbWorld:SetChecked(true) cbParty:SetChecked(true) cbRaid:SetChecked(true) cbCooldown:SetChecked(false) cbProc:SetChecked(false) cbCombo:SetChecked(false) cbWeapon:SetChecked(false) if modeType == "BUFF" then selectBuff(nil) else selectDebuff(nil) end
end)
return { editBox = editBox, sliderTime = sliderTime, sliderStacks = sliderStacks, dropDown = dropDown, listFrame = listFrame, cbCombat = cbCombat, cbWorld = cbWorld, cbParty = cbParty, cbRaid = cbRaid, cbCooldown = cbCooldown, cbProc = cbProc, cbCombo = cbCombo, cbWeapon = cbWeapon, stText = stText, ssText = ssText }
end
leftUI = CreateColumn(true, "BUFF", "|cff44FF44")
rightUI = CreateColumn(false, "DEBUFF", "|cffFF4444")
selectBuff = function(index)
selectedBuffIndex = index for _, btn in ipairs(listButtonsBuff) do btn:UnlockHighlight() end
if index and RAY_Config.spells[index] then
local data = RAY_Config.spells[index] leftUI.editBox:SetText(data.name or "") UIDropDownMenu_SetSelectedValue(leftUI.dropDown, data.target or "player") UIDropDownMenu_SetText(leftUI.dropDown, data.target == "target" and "Цель: Таргет" or "Цель: Игрок") leftUI.sliderTime:SetValue(data.alertTime or 0) leftUI.sliderStacks:SetValue(data.minStacks or 0) leftUI.cbCombat:SetChecked(data.onlyInCombat) leftUI.cbWorld:SetChecked(data.zoneWorld) leftUI.cbParty:SetChecked(data.zoneParty) leftUI.cbRaid:SetChecked(data.zoneRaid) leftUI.cbCooldown:SetChecked(data.isCooldown) leftUI.cbProc:SetChecked(data.isProc) leftUI.cbCombo:SetChecked(data.isCombo) leftUI.cbWeapon:SetChecked(data.isWeaponText)
else leftUI.editBox:SetText("") leftUI.sliderTime:SetValue(0) leftUI.sliderStacks:SetValue(0) leftUI.cbCombat:SetChecked(true) leftUI.cbWorld:SetChecked(true) leftUI.cbParty:SetChecked(true) leftUI.cbRaid:SetChecked(true) leftUI.cbCooldown:SetChecked(false) leftUI.cbProc:SetChecked(false) leftUI.cbCombo:SetChecked(false) leftUI.cbWeapon:SetChecked(false) UIDropDownMenu_SetSelectedValue(leftUI.dropDown, "player") UIDropDownMenu_SetText(leftUI.dropDown, "Цель: Игрок") end
end
selectDebuff = function(index)
selectedDebuffIndex = index for _, btn in ipairs(listButtonsDebuff) do btn:UnlockHighlight() end
if index and RAY_Config.spells[index] then
local data = RAY_Config.spells[index] rightUI.editBox:SetText(data.name or "") UIDropDownMenu_SetSelectedValue(rightUI.dropDown, data.target or "target") UIDropDownMenu_SetText(rightUI.dropDown, data.target == "target" and "Цель: Таргет" or "Цель: Игрок") rightUI.sliderTime:SetValue(data.alertTime or 0) rightUI.sliderStacks:SetValue(data.minStacks or 0) rightUI.cbCombat:SetChecked(data.onlyInCombat) rightUI.cbWorld:SetChecked(data.zoneWorld) rightUI.cbParty:SetChecked(data.zoneParty) rightUI.cbRaid:SetChecked(data.zoneRaid) rightUI.cbCooldown:SetChecked(data.isCooldown) rightUI.cbProc:SetChecked(data.isProc) rightUI.cbCombo:SetChecked(data.isCombo) rightUI.cbWeapon:SetChecked(data.isWeaponText)
else rightUI.editBox:SetText("") rightUI.sliderTime:SetValue(0) rightUI.sliderStacks:SetValue(0) rightUI.cbCombat:SetChecked(true) rightUI.cbWorld:SetChecked(true) rightUI.cbParty:SetChecked(true) rightUI.cbRaid:SetChecked(true) rightUI.cbCooldown:SetChecked(false) rightUI.cbProc:SetChecked(false) rightUI.cbCombo:SetChecked(false) rightUI.cbWeapon:SetChecked(false) UIDropDownMenu_SetSelectedValue(rightUI.dropDown, "target") UIDropDownMenu_SetText(rightUI.dropDown, "Цель: Таргет") end
end
updateSpellLists = function()
for _, btn in ipairs(listButtonsBuff) do btn:Hide() end for _, btn in ipairs(listButtonsDebuff) do btn:Hide() end
local bCount, dCount = 1, 1
for i, spellData in ipairs(RAY_Config.spells or {}) do
local isBuff = (spellData.mode == "BUFF") local count = isBuff and bCount or dCount local listButtons = isBuff and listButtonsBuff or listButtonsDebuff local ui = isBuff and leftUI or rightUI local btn = listButtons[count]
if not btn then btn = CreateFrame("Button", nil, ui.listFrame) btn:SetSize(210, 20) btn:SetNormalFontObject("GameFontNormal") btn:SetHighlightTexture("Interface\Buttons\UI-Listbox-Highlight") local delBtn = CreateFrame("Button", nil, btn, "UIPanelCloseButton") delBtn:SetSize(18, 18) delBtn:SetPoint("RIGHT", btn, "RIGHT", 0, 0) btn.delBtn = delBtn listButtons[count] = btn end
btn:ClearAllPoints() btn:SetPoint("TOPLEFT", 0, -((count - 1) * 22)) btn:SetText(((isBuff and "|cff44FF44" or "|cffFF4444") .. (string.match(spellData.name, "[^|/]+") or "Пусто") .. "|r")) btn:Show() SetTooltip(btn.delBtn, "Удалить эту запись.")
if isBuff then btn:SetScript("OnClick", function() selectBuff(i) btn:LockHighlight() end) else btn:SetScript("OnClick", function() selectDebuff(i) btn:LockHighlight() end) end
btn.delBtn:SetScript("OnClick", function() table.remove(RAY_Config.spells, i) if isBuff then selectBuff(nil) else selectDebuff(nil) end updateSpellLists() CheckAllAuras() end)
if isBuff then bCount = bCount + 1 else dCount = dCount + 1 end
end
end
-- 4.2 НАСТРОЙКА СТРАНИЦЫ №2 (СПЕКИ И КОМПЛЕКТЫ)
local scrollFrame = CreateFrame("ScrollFrame", "RAY_SubScrollContainer", subOptionsPanel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 0, -85) scrollFrame:SetPoint("BOTTOMRIGHT", -26, 6)
local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetSize(580, 920) scrollFrame:SetScrollChild(scrollChild)
local subTitle = subOptionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
subTitle:SetPoint("TOPLEFT", 16, -14) subTitle:SetText("|cff00FFFFАвтоматика Спеков, Стоек и Комплектов Экипировки|r")
local subNotice = subOptionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
subNotice:SetPoint("TOPLEFT", 16, -34) subNotice:SetTextColor(1, 0.8, 0) subNotice:SetText("ВАЖНО: Для КД тринек вводите имя БАФФА прока (напр. 'Сумеречное исступление')!")
local radarCb = CreateFrame("CheckButton", "RAY_RadarDebugCheckboxUnique", subOptionsPanel, "InterfaceOptionsCheckButtonTemplate")
radarCb:SetPoint("TOPLEFT", 16, -54)
local radarCbText = radarCb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
radarCbText:SetPoint("LEFT", radarCb, "RIGHT", 5, 1) radarCbText:SetText("|cffFF5555RAY-Радар|r")
radarCb:SetScript("OnShow", function(self) self:SetChecked(RAY_Config.radarEnabled) end) radarCb:SetScript("OnClick", function(self) RAY_Config.radarEnabled = self:GetChecked() end)
SetTooltip(radarCb, "[Инструмент разработчика]: выводить в чат ID и названия всех получаемых аур.")
local btnClear = CreateFrame("Button", nil, subOptionsPanel, "UIPanelButtonTemplate")
btnClear:SetSize(55, 22) btnClear:SetPoint("LEFT", radarCbText, "RIGHT", 15, -1) btnClear:SetText("|cffFF3333Clear|r")
local nTex = btnClear:GetNormalTexture() if nTex then nTex:SetVertexColor(1, 0.2, 0.2, 0.9) end btnClear:SetScript("OnClick", function() RAY_Config = nil ReloadUI() end)
SetTooltip(btnClear, "Очистить RAY-кэш и полностью сбросить все сохраненные настройки аддона до заводских.")
local subLine2 = scrollChild:CreateTexture(nil, "BACKGROUND")
subLine2:SetWidth(2) subLine2:SetHeight(880) subLine2:SetPoint("TOPLEFT", 295, 0) subLine2:SetTexture(0.3, 0.3, 0.3, 0.5)
local subLeftHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal") subLeftHeader:SetPoint("TOPLEFT", 10, 0) subLeftHeader:SetText("|cff44FF44ПЕРВАЯ ВЕТКА (СПЕК 1)|r")
local subRightHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal") subRightHeader:SetPoint("TOPLEFT", 310, 0) subRightHeader:SetText("|cffFF4444ВТОРАЯ ВЕТКА (СПЕК 2)|r")
local function CreateSubPageBlock(specNum, isLeft, headerColorCode)
local hOffsetSub = isLeft and 10 or 310 local activeIndices = { sets = nil, buffs = nil, icds = nil }
local function BuildInputFieldBlock(labelTxt, yBlock, storageKey, tText, isIcd)
local editBox, boxName, boxSec
if isIcd then
boxName = CreateBlizzardEditBox(scrollChild, hOffsetSub, yBlock - 20, 140, "RAY_SubIcdName_"..specNum) SetTooltip(boxName, tText)
boxSec = CreateBlizzardEditBox(scrollChild, hOffsetSub + 145, yBlock - 20, 35, "RAY_SubIcdSec_"..specNum) boxSec:SetNumeric(true) boxSec:SetMaxLetters(3)
editBox = boxName
else
editBox = CreateBlizzardEditBox(scrollChild, hOffsetSub, yBlock - 20, 180, "RAY_SubInp_"..specNum.."_"..storageKey) SetTooltip(editBox, tText)
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
RAY_Config.specSettings[specNum][storageKey][idx][key] = self:GetChecked()
CheckAllAuras()
end
end
end)
cb:SetChecked(true) return cb
end
local cbCombat = CreateSubCheckbox("Включать только в бою", 50, "onlyInCombat")
local cbWorld  = CreateSubCheckbox("Отслеживать в открытом мире", 72, "zoneWorld")
local cbParty  = CreateSubCheckbox("Отслеживать в подземельях", 94, "zoneParty")
local cbRaid   = CreateSubCheckbox("Отслеживать в рейдовых зонах", 116, "zoneRaid")
local listFrame = CreateFrame("Frame", nil, scrollChild) listFrame:SetSize(235, 85) listFrame:SetPoint("TOPLEFT", editBox, "TOPLEFT", 4, -145)
if not listButtonsSub[specNum] then listButtonsSub[specNum] = {} end listButtonsSub[specNum][storageKey] = {}
RefreshLocalSubList = function()
for _, b in ipairs(listButtonsSub[specNum][storageKey]) do b:Hide() end
if not RAY_Config or not RAY_Config.specSettings or not RAY_Config.specSettings[specNum] then return end
if not RAY_Config.specSettings[specNum][storageKey] then RAY_Config.specSettings[specNum][storageKey] = {} end
for idx, data in ipairs(RAY_Config.specSettings[specNum][storageKey]) do
local textStr = type(data) == "table" and ((data.name or "Ошибка") .. (isIcd and (" ("..(data.seconds or "45").."с)") or "")) or tostring(data)
local btn = listButtonsSub[specNum][storageKey][idx]
if not btn then
btn = CreateFrame("Button", nil, listFrame) btn:SetSize(215, 20) btn:SetNormalFontObject("GameFontNormal") btn:SetHighlightTexture("Interface\Buttons\UI-Listbox-Highlight")
local del = CreateFrame("Button", nil, btn, "UIPanelCloseButton") del:SetSize(18, 18) del:SetPoint("RIGHT", btn, "RIGHT", 0, 0) btn.del = del listButtonsSub[specNum][storageKey][idx] = btn
end
btn:ClearAllPoints() btn:SetPoint("TOPLEFT", 0, -((idx - 1) * 22)) btn:SetText(textStr) btn:Show() SetTooltip(btn.del, "Удалить эту запись.")
if activeIndices[storageKey] == idx then btn:LockHighlight() else btn:UnlockHighlight() end
btn:SetScript("OnClick", function()
activeIndices[storageKey] = idx for _, b in ipairs(listButtonsSub[specNum][storageKey]) do b:UnlockHighlight() end btn:LockHighlight()
local d = RAY_Config.specSettings[specNum][storageKey][idx] if type(d) == "table" then if isIcd then boxName:SetText(d.name or "") boxSec:SetText(d.seconds or "45") else editBox:SetText(d.name or "") end cbCombat:SetChecked(d.onlyInCombat) cbWorld:SetChecked(d.zoneWorld) cbParty:SetChecked(d.zoneParty) cbRaid:SetChecked(d.zoneRaid) end
end)
btn.del:SetScript("OnClick", function() table.remove(RAY_Config.specSettings[specNum][storageKey], idx) activeIndices[storageKey] = nil if isIcd then boxName:SetText("") boxSec:SetText("") else editBox:SetText("") end RefreshLocalSubList() CheckAllAuras() end)
end
end
btnOk:SetScript("OnClick", function()
local txt = editBox:GetText() if not txt or txt == "" or txt == " " then return end
if not RAY_Config.specSettings[specNum][storageKey] then RAY_Config.specSettings[specNum][storageKey] = {} end
local activeIdx = activeIndices[storageKey] local itemData = { name = txt, seconds = isIcd and (boxSec:GetText() or "45") or nil, onlyInCombat = cbCombat:GetChecked(), zoneWorld = cbWorld:GetChecked(), zoneParty = cbParty:GetChecked(), zoneRaid = cbRaid:GetChecked() }
if activeIdx and RAY_Config.specSettings[specNum][storageKey][activeIdx] then RAY_Config.specSettings[specNum][storageKey][activeIdx] = itemData else table.insert(RAY_Config.specSettings[specNum][storageKey], itemData) end
activeIndices[storageKey] = nil if isIcd then boxName:SetText("") boxSec:SetText("") else editBox:SetText("") end cbCombat:SetChecked(true) cbWorld:SetChecked(true) cbParty:SetChecked(true) cbRaid:SetChecked(true) RefreshLocalSubList() CheckAllAuras()
end)
subOptionsPanel:HookScript("OnShow", function() activeIndices[storageKey] = nil if isIcd then boxName:SetText("") boxSec:SetText("") else editBox:SetText("") end RefreshLocalSubList() end)
end
BuildInputFieldBlock("Комплект экипировки:", -25, "sets", "Введите название комплекта экипировки.", false)
BuildInputFieldBlock("Обязательная стойка / бафф:", -285, "buffs", "Введите название стойки или баффа.", false)
BuildInputFieldBlock("Имя ПРОКА триньки / КД:", -545, "icds", "Введите точное название баффа от триньки.", true)
end
CreateSubPageBlock(1, true, "|cff44FF44")
CreateSubPageBlock(2, false, "|cffFF4444")
-- ОФИЦИАЛЬHАЯ РЕГИСТРАЦИЯ КОМПОHЕНТОВ ПО ЦЕПОЧКЕ ВНУТРИ LOGIN БЛОКА
InterfaceOptions_AddCategory(optionsPanel)
InterfaceOptions_AddCategory(subOptionsPanel)
updateSpellLists()
end)
-- Слэш-команда
SLASH_RAY1 = "/ray"
SlashCmdList["RAY"] = function()
if optionsPanel then
InterfaceOptionsFrame_OpenToCategory(optionsPanel)
InterfaceOptionsFrame_OpenToCategory(optionsPanel)
end
end
