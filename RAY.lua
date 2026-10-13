-- =========================================================================
-- 1. ИНИЦИАЛИЗАЦИЯ И РАЗДЕЛЬНОЕ СОХРАНЕНИЕ НАСТРОЕК ДЛЯ КАЖДОГО ПЕРСОНАЖА
-- =========================================================================
local addonName = "RAY"
local RAY_EventFrame = CreateFrame("Frame")

-- База данных теперь создается абсолютно пустой для каждого нового персонажа
local defaultSettings = {
    enabled = true,
    fontSize = 24, -- Здесь мы по-прежнему храним условный размер (24 = масштаб 1.0)
    spells = {},
    framePos = { point = "CENTER", x = 0, y = 150 }
}

local optionsPanel
local selectedBuffIndex = nil   
local selectedDebuffIndex = nil 
local listButtonsBuff = {}
local listButtonsDebuff = {}
local updateSpellLists, selectBuff, selectDebuff, CheckAllAuras

-- Переменная для хранения смещения кастомной невидимой прокрутки
local currentScrollOffset = 0
local totalContentHeight = 0
local MAX_VISIBLE_HEIGHT = 115 -- Жесткая высота окна списков

RAY_EventFrame:RegisterEvent("ADDON_LOADED")
RAY_EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
RAY_EventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not RAY_Config then
            RAY_Config = defaultSettings
        else
            if RAY_Config.enabled == nil then RAY_Config.enabled = true end
            if RAY_Config.fontSize == nil then RAY_Config.fontSize = 24 end
            if not RAY_Config.spells then RAY_Config.spells = {} end
            if not RAY_Config.framePos then 
                RAY_Config.framePos = { point = "CENTER", x = 0, y = 150 } 
            end
        end
        
        -- Восстановление позиции фрейма
        if RAY_MainFrame and RAY_Config.framePos then
            RAY_MainFrame:ClearAllPoints()
            RAY_MainFrame:SetPoint(RAY_Config.framePos.point, UIParent, RAY_Config.framePos.point, RAY_Config.framePos.x, RAY_Config.framePos.y)
            
            -- Применяем сохраненный масштаб к ФРЕЙМУ при загрузке игры
            local savedScale = (RAY_Config.fontSize or 24) / 24
            RAY_MainFrame:SetScale(savedScale)
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
    local point, _, _, x, y = self:GetPoint()
    RAY_Config.framePos.point = point
    RAY_Config.framePos.x = x
    RAY_Config.framePos.y = y
end)
frame:Hide()

local dragBg = frame:CreateTexture(nil, "BACKGROUND")
dragBg:SetAllPoints()
dragBg:SetTexture(0.1, 0.1, 0.1, 0.6)
dragBg:Hide()

local dragBorder = frame:CreateTexture(nil, "OVERLAY")
dragBorder:SetAllPoints()
dragBorder:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
dragBorder:Hide()

local text = frame:CreateFontString("RAY_MainFrameText", "OVERLAY", "GameFontNormalLarge")
text:SetPoint("CENTER", frame, "CENTER")
text:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE") 
text:SetTextColor(0, 1, 0.9) 
text:SetJustifyH("CENTER")

local animGroup = frame:CreateAnimationGroup()
local fadeOut = animGroup:CreateAnimation("Alpha")
fadeOut:SetChange(-0.6) fadeOut:SetDuration(0.5) fadeOut:SetOrder(1)
local fadeIn = animGroup:CreateAnimation("Alpha")
fadeIn:SetChange(0.6) fadeIn:SetDuration(0.5) fadeIn:SetOrder(2)
animGroup:SetLooping("REPEAT")

local function SetTooltip(widget, tooltipText)
    widget:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltipText, 1, 1, 1, nil, true)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
end

-- =========================================================================
-- 3. УНИВЕРСАЛЬНЫЙ ДВИЖОК ПРОВЕРКИ АУР И КУЛДАУНОВ
-- =========================================================================
local function GetCurrentZoneType()
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid") then return instanceType end
    if (GetNumRaidMembers and GetNumRaidMembers() > 0) or (IsInRaid and IsInRaid()) then return "raid" end
    if (GetNumPartyMembers and GetNumPartyMembers() > 0) or (IsInGroup and IsInGroup()) then return "party" end
    return "world"
end

local function GetItemCooldownByName(itemName)
    if not itemName or itemName == "" then return 0 end
    local nameLower = itemName:lower()
    
    if nameLower:find("ускорител") or nameLower:find("перчат") or nameLower:find("гипер") or nameLower:find("hyper") then
        local start, duration = GetInventoryItemCooldown("player", 10)
        if start and start > 0 and duration > 1.5 then return (start + duration) - GetTime() end
        return 0
    end

    for _, slot in ipairs({13, 14}) do
        local start, duration = GetInventoryItemCooldown("player", slot)
        if start and start > 0 and duration > 1.5 then return (start + duration) - GetTime() end
    end

    local checkId = tonumber(itemName)
    local start, duration
    if checkId then start, duration = GetSpellCooldown(checkId) else start, duration = GetSpellCooldown(itemName) end
    if start and start > 0 and duration > 1.5 then return (start + duration) - GetTime() end

    return 0
end

local function FindAura(target, nameOrId, filter)
    local checkId = tonumber(nameOrId)
    local nameLower = not checkId and nameOrId:lower() or nil

    if target == "player" and nameLower and filter == "HELPFUL" then
        local hasMainHand, mainHandExpiration, _, _, hasOffHand, offHandExpiration = GetWeaponEnchantInfo()
        if hasMainHand and (nameLower:find("пламен") or nameLower:find("flametongue") or nameLower:find("неистовств") or nameLower:find("windfury") or nameLower:find("земли") or nameLower:find("earthliving") or nameLower:find("ледян") or nameLower:find("frostbrand")) then
            return true, 0, GetTime() + (mainHandExpiration / 1000)
        end
        if hasOffHand and (nameLower:find("пламен") or nameLower:find("flametongue") or nameLower:find("неистовств") or nameLower:find("windfury") or nameLower:find("земли") or nameLower:find("earthliving") or nameLower:find("ледян") or nameLower:find("frostbrand")) then
            return true, 0, GetTime() + (offHandExpiration / 1000)
        end
    end

    for i = 1, 40 do
        local name, _, _, count, _, _, expirationTime, _, _, _, spellID = UnitAura(target, i, filter)
        if not name then break end
        if checkId then
            if spellID == checkId then return true, count or 0, expirationTime or 0 end
        else
            if name:lower() == nameLower then return true, count or 0, expirationTime or 0 end
        end
    end
    return false, 0, 0
end

local function CheckAuraGroup(target, spellLine, filter)
    local active, currentStacks, minRemaining = false, 0, 999999
    for condition in string.gmatch(spellLine, "[^|/]+") do
        condition = condition:match("^%s*(.-)%s*$")
        local found, stacks, expTime = FindAura(target, condition, filter)
        if found then
            active = true
            currentStacks = math.max(currentStacks, stacks)
            local timeLeft = expTime > 0 and (expTime - GetTime()) or 999999
            if timeLeft < minRemaining then minRemaining = timeLeft end
        end
    end
    return active, currentStacks, minRemaining
end

CheckAllAuras = function()
    if frame:IsMouseEnabled() and frame:IsShown() then return end

    if not RAY_Config or not RAY_Config.enabled or not RAY_Config.spells then 
        if frame:IsShown() then frame:Hide() animGroup:Stop() end
        return 
    end

    local uniqueAlerts = {}
    local inCombat = UnitAffectingCombat("player")
    local currentZone = GetCurrentZoneType()

    for _, spellData in ipairs(RAY_Config.spells) do
        if spellData.name and spellData.name ~= "" then
            local allowed = true
            if spellData.onlyInCombat and not inCombat then allowed = false end
            if currentZone == "world" and spellData.zoneWorld == false then allowed = false end
            if currentZone == "party" and spellData.zoneParty == false then allowed = false end
            if currentZone == "raid" and spellData.zoneRaid == false then allowed = false end

            if allowed then
                local target = spellData.target or "player"
                if target ~= "target" or (UnitExists("target") and not UnitIsDead("target")) then
                    local filter = (spellData.mode == "DEBUFF") and "HARMFUL" or "HELPFUL"
                    
                    local cdLeft = GetItemCooldownByName(spellData.name)
                    local isActive, stacks, timeLeft = CheckAuraGroup(target, spellData.name, filter)

                    local needAlert = false
                    local customReason = ""

                    if spellData.isProc then
                        if isActive then
                            needAlert = true
                            if spellData.alertTime and spellData.alertTime > 0 and timeLeft <= spellData.alertTime then
                                customReason = " (" .. math.ceil(timeLeft) .. " сек)"
                            end
                        end
                    elseif spellData.isCooldown then
                        if cdLeft and cdLeft > 0 then needAlert = false
elseif not isActive then needAlert = true end
else
if not isActive then
needAlert = true
else
if spellData.minStacks and spellData.minStacks > 0 and stacks < spellData.minStacks then
needAlert = true
customReason = " (" .. stacks .. "/" .. spellData.minStacks .. " ст)"
end
if spellData.alertTime and spellData.alertTime > 0 and timeLeft <= spellData.alertTime then
needAlert = true
customReason = " (" .. math.ceil(timeLeft) .. " сек)"
end
end
end
if needAlert then
local displayName = string.match(spellData.name, "[^|/]+") or spellData.name
local alertLine = ""
if spellData.mode == "DEBUFF" then
alertLine = "RAY: Наложи дебафф [" .. displayName .. "]" .. customReason
else
if spellData.isProc then
alertLine = "RAY: Прок! [" .. displayName .. "]" .. customReason
elseif spellData.isCooldown then
alertLine = "RAY: Готово! Прожми [" .. displayName .. "]" .. customReason
else
alertLine = "RAY: Обнови бафф [" .. displayName .. "]" .. customReason
end
end
uniqueAlerts[alertLine] = true
end
end
end
end
end
local alertText = ""
for k, _ in pairs(uniqueAlerts) do
if alertText ~= "" then alertText = alertText .. "\n" end
alertText = alertText .. k
end
if alertText ~= "" then
text:SetText(alertText)
if not frame:IsShown() then frame:Show() animGroup:Play() end
else
frame:Hide() animGroup:Stop()
end
end
local engineEvents = CreateFrame("Frame")
engineEvents:RegisterEvent("UNIT_AURA")
engineEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
engineEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
engineEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
engineEvents:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
engineEvents:RegisterEvent("BAG_UPDATE_COOLDOWN")
engineEvents:SetScript("OnEvent", function(self, event, unit)
if event == "UNIT_AURA" and unit ~= "player" and unit ~= "target" then return end
CheckAllAuras()
end)
local ticker = CreateFrame("Frame")
local tTime = 0
ticker:SetScript("OnUpdate", function(self, elapsed)
tTime = tTime + elapsed
if tTime >= 0.4 then tTime = 0 CheckAllAuras() end
end)
-- =========================================================================
-- 4. ГРАФИЧЕСКИЙ ИНТЕРФЕЙС НАСТРОЕК (СТРОГО БЕЗ ИСПОЛЬЗОВАНИЯ _G)
-- =========================================================================
local shortcutFrame = CreateFrame("Frame")
shortcutFrame:RegisterEvent("PLAYER_LOGIN")
shortcutFrame:SetScript("OnEvent", function()
optionsPanel = CreateFrame("Frame", "RAY_OptionsPanel", UIParent)
optionsPanel.name = "RAY"
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
SetTooltip(mainCb, "Полностью включает или отключает вывод любых текстовых предупреждений аддона на экран.")
local dragCb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
dragCb:SetPoint("TOPLEFT", 415, -34)
local dragCbText = dragCb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dragCbText:SetPoint("LEFT", dragCb, "RIGHT", 5, 1)
dragCbText:SetText("|cffFFFF00Move|r")
dragCb:SetScript("OnClick", function(self)
if self:GetChecked() then
frame:EnableMouse(true)
dragBg:Show()
dragBorder:Show()
text:SetText("|cff00FFFF[RAY]: Зажми ЛКМ\nи перетащи меня!|r")
if not frame:IsShown() then frame:Show() animGroup:Play() end
else
frame:EnableMouse(false)
dragBg:Hide()
dragBorder:Hide()
animGroup:Stop()
CheckAllAuras()
end
end)
SetTooltip(dragCb, "Включает тестовую полупрозрачную рамку индикатора на экране. Зажмите её левой кнопкой мыши (ЛКМ), чтобы переместить в удобное место.")
-- Ползунок масштабирует фрейм целиком (SetScale)
local fontSlider = CreateFrame("Slider", "RAY_FontScaleSliderGlobal", optionsPanel, "OptionsSliderTemplate")
fontSlider:SetSize(110, 17)
fontSlider:SetPoint("TOPLEFT", 525, -34)
fontSlider:SetMinMaxValues(12, 36)
fontSlider:SetValueStep(1)
local fsText = fontSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
fsText:SetPoint("BOTTOM", fontSlider, "TOP", 0, 4)
if RAY_FontScaleSliderGlobalLow then RAY_FontScaleSliderGlobalLow:Hide() end
if RAY_FontScaleSliderGlobalHigh then RAY_FontScaleSliderGlobalHigh:Hide() end
fontSlider:SetScript("OnShow", function(self)
local currentVal = RAY_Config.fontSize or 24
self:SetValue(currentVal)
fsText:SetText("Шрифт: " .. math.floor(currentVal))
end)
fontSlider:SetScript("OnValueChanged", function(self, value)
local val = math.floor(value)
fsText:SetText("Шрифт: " .. val)
RAY_Config.fontSize = val
-- Меняем масштаб самого ФРЕЙМА-контейнера
local currentScale = val / 24
frame:SetScale(currentScale)
if dragCb:GetChecked() then
text:SetText("|cff00FFFF[RAY]: Зажми ЛКМ\nи перетащи меня!|r")
end
end)
SetTooltip(fontSlider, "Изменяет размер всплывающего текста предупреждений на экране.")
local line = optionsPanel:CreateTexture(nil, "BACKGROUND")
line:SetWidth(2)
line:SetHeight(355)
line:SetPoint("TOPLEFT", 305, -65)
line:SetTexture(0.3, 0.3, 0.3, 0.5)
local leftHeader = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
leftHeader:SetPoint("TOPLEFT", 16, -65)
leftHeader:SetText("|cff44FF44БАФФЫ И ПРОКИ|r")
local rightHeader = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rightHeader:SetPoint("TOPLEFT", 320, -65)
rightHeader:SetText("|cffFF4444ДЕБАФФЫ|r")
local editCounter, sliderCounter, cbCounter, dropCounter = 0, 0, 0, 0
local leftUI, rightUI
local function CreateColumn(isLeft, modeType, textColorCode)
local offsetX = isLeft and 16 or 320
editCounter = editCounter + 1
local editBox = CreateFrame("EditBox", "RAY_NewEdit_" .. editCounter, optionsPanel, "InputBoxTemplate")
editBox:SetSize(190, 25)
editBox:SetPoint("TOPLEFT", offsetX, -105)
editBox:SetAutoFocus(false)
local elabel = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
elabel:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 0, 2)
elabel:SetText(textColorCode .. "Название / ID (Используйте '/' для Или):|r")
local btnOk = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
btnOk:SetSize(45, 24)
btnOk:SetPoint("LEFT", editBox, "RIGHT", 5, 0)
btnOk:SetText("|cffFFFF00ОК|r")
local normalTex = btnOk:GetNormalTexture()   if normalTex then normalTex:SetVertexColor(1, 0.1, 0.1, 0.9) end
local pushTex = btnOk:GetPushedTexture()     if pushTex then pushTex:SetVertexColor(0.6, 0, 0, 1) end
local highTex = btnOk:GetHighlightTexture()   if highTex then highTex:SetVertexColor(1, 0.3, 0.3, 0.4) end
dropCounter = dropCounter + 1
local dropDown = CreateFrame("Frame", "RAY_DropDown_" .. dropCounter, optionsPanel, "UIDropDownMenuTemplate")
dropDown:SetPoint("TOPLEFT", offsetX - 15, -145)
UIDropDownMenu_SetWidth(dropDown, 110)
if isLeft then
SetTooltip(dropDown, "Выбор цели для проверки положительного баффа, аур, прока, спелла, эффекта аксессуара или предмета.")
else
SetTooltip(dropDown, "Выбор цели для проверки отрицательного дебаффа, аур, спелла, эффекта или предмета.")
end
local tempConfig = { onlyInCombat = true, zoneWorld = true, zoneParty = true, zoneRaid = true, target = (modeType == "DEBUFF" and "target" or "player"), isCooldown = false, isProc = false }
local function GetActiveIndex()
return (modeType == "BUFF") and selectedBuffIndex or selectedDebuffIndex
end
local function CreateLocalCheckbox(label, yOffset, key, tooltipText)
cbCounter = cbCounter + 1
local cb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
cb:SetPoint("TOPLEFT", offsetX, yOffset)
local cbTxt = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cbTxt:SetPoint("LEFT", cb, "RIGHT", 5, 1)
cbTxt:SetText(textColorCode .. label .. "|r")
cb:SetScript("OnClick", function(self)
local idx = GetActiveIndex()
if idx and RAY_Config.spells[idx] then
RAY_Config.spells[idx][key] = self:GetChecked()
CheckAllAuras()
else
tempConfig[key] = self:GetChecked()
end
end)
SetTooltip(cb, tooltipText)
return cb, cbTxt
end
local cbCombat, cbCombatTxt, cbWorld, cbWorldTxt, cbParty, cbPartyTxt, cbRaid, cbRaidTxt, cbCooldown, cbCooldownTxt, cbProc, cbProcTxt
if isLeft then
cbCombat, cbCombatTxt   = CreateLocalCheckbox("Включать только в бою", -175, "onlyInCombat", "Если включено, аддон будет проверять этот положительный бафф, ауру, прок, спелл или предмет только во время боя.")
cbWorld, cbWorldTxt    = CreateLocalCheckbox("Отслеживать в открытом мире", -195, "zoneWorld", "Проверять этот положительный бафф, ауру, прок, спелл или предмет при нахождении в локациях открытого мира.")
cbParty, cbPartyTxt    = CreateLocalCheckbox("Отслеживать в подземельях", -217, "zoneParty", "Проверять этот положительный бафф, ауру, прок, спелл или предмет, когда вы находитесь в подземелье на 5 человек.")
cbRaid, cbRaidTxt     = CreateLocalCheckbox("Отслеживать в рейдовых зонах", -239, "zoneRaid", "Проверять этот положительный бафф, ауру, прок, спелл или предмет внутри рейдовых подземелий.")
cbCooldown, cbCooldownTxt = CreateLocalCheckbox("Отслеживать готовность КД", -261, "isCooldown", "Оповестит, когда завершится внутреннее или обычное КД способности, аксессуара, инженерной чарки или предмета.")
cbProc, cbProcTxt     = CreateLocalCheckbox("Это прок (активен)", -283, "isProc", "Изменяет логику: выводить текст на экран только тогда, когда этот положительный бафф, аура, прок или эффект предмета АКТИВЕH на цели.")
else
cbCombat, cbCombatTxt   = CreateLocalCheckbox("Включать только в бою", -175, "onlyInCombat", "Если включено, аддон будет проверять этот дебафф, ауру, спелл или отрицательный эффект только во время боя.")
cbWorld, cbWorldTxt    = CreateLocalCheckbox("Отслеживать в открытом мире", -195, "zoneWorld", "Проверять этот дебафф, ауру, спелл или отрицательный эффект при нахождении в локациях открытого мира.")
cbParty, cbPartyTxt    = CreateLocalCheckbox("Отслеживать в подземельях", -217, "zoneParty", "Проверять этот дебафф, ауру, спелл или отрицательный эффект, когда вы находитесь в подземелье на 5 человек.")
cbRaid, cbRaidTxt     = CreateLocalCheckbox("Отслеживать в рейдовых зонах", -239, "zoneRaid", "Проверять этот дебафф, ауру, спелл или отрицательный эффект внутри рейдовых подземелий.")
cbCooldown, cbCooldownTxt = CreateLocalCheckbox("Отслеживать готовность КД", -261, "isCooldown", "Оповестит, когда завершится КД способности или предмета, накладывающего этот дебафф.")
cbProc, cbProcTxt     = CreateLocalCheckbox("Это прок (активен)", -283, "isProc", "Изменяет логику: выводить текст на экран только тогда, когда этот дебафф, аура, спелл или эффект нахождения предмета АКТИВЕH на цели.")
end
local sliderCounter = 0
sliderCounter = sliderCounter + 1
local sTimeName = "RAY_SliderTimeUnique_" .. editCounter .. "_" .. sliderCounter
local sliderTime = CreateFrame("Slider", sTimeName, optionsPanel, "OptionsSliderTemplate")
sliderTime:SetSize(110, 17)
sliderTime:SetPoint("TOPLEFT", offsetX, -325)
sliderTime:SetMinMaxValues(0, 30)
sliderTime:SetValueStep(1)
local stText = sliderTime:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
stText:SetPoint("BOTTOM", sliderTime, "TOP", 0, 2) stText:SetText(textColorCode .. "Время (сек): 0|r")
if _G[sTimeName.."Low"] then _G[sTimeName.."Low"]:Hide() end
if _G[sTimeName.."High"] then _G[sTimeName.."High"]:Hide() end
if isLeft then
SetTooltip(sliderTime, "Начнет предупреждать об обновлении положительного баффа, ауры, прока, спелла или предмета заранее за указанное количество секунд.")
else
SetTooltip(sliderTime, "Начнет предупреждать об обновлении дебаффа, ауры, спелла или эффекта предмета заранее за указанное количество секунд.")
end
sliderCounter = sliderCounter + 1
local sStacksName = "RAY_SliderStacksUnique_" .. editCounter .. "_" .. sliderCounter
local sliderStacks = CreateFrame("Slider", sStacksName, optionsPanel, "OptionsSliderTemplate")
sliderStacks:SetSize(110, 17)
sliderStacks:SetPoint("LEFT", sliderTime, "RIGHT", 15, 0)
sliderStacks:SetMinMaxValues(0, 5)
sliderStacks:SetValueStep(1)
local ssText = sliderStacks:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ssText:SetPoint("BOTTOM", sliderStacks, "TOP", 0, 2) ssText:SetText(textColorCode .. "Стаки: 0|r")
if _G[sStacksName.."Low"] then _G[sStacksName.."Low"]:Hide() end
if _G[sStacksName.."High"] then _G[sStacksName.."High"]:Hide() end
if isLeft then
SetTooltip(sliderStacks, "Подавать сигнал, если количество накопленных стаков (зарядов) данного положительного баффа, прока или спелла меньше выбранного значения.")
else
SetTooltip(sliderStacks, "Подавать сигнал, если количество накопленных стаков (зарядов) данного дебаффа или спелла на цели меньше выбранного значения.")
end
sliderTime:SetScript("OnValueChanged", function(self, value)
local val = math.floor(value)
stText:SetText(textColorCode .. "Время (сек): " .. val .. "|r")
local idx = GetActiveIndex()
if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx].alertTime = val CheckAllAuras() end
end)
sliderStacks:SetScript("OnValueChanged", function(self, value)
local val = math.floor(value)
ssText:SetText(textColorCode .. "Стаки: " .. val .. "|r")
local idx = GetActiveIndex()
if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx].minStacks = val CheckAllAuras() end
end)
local scrollContent = CreateFrame("Frame", nil, optionsPanel)
scrollContent:SetSize(250, MAX_VISIBLE_HEIGHT)
scrollContent:SetPoint("TOPLEFT", offsetX, -350)
UIDropDownMenu_Initialize(dropDown, function()
local currentIdx = GetActiveIndex()
local activeTarget = "player"
if currentIdx and RAY_Config.spells[currentIdx] then
activeTarget = RAY_Config.spells[currentIdx].target or "player"
else
activeTarget = tempConfig.target
end
local info = UIDropDownMenu_CreateInfo()
info.text = "Цель: Игрок"
info.value = "player"
info.checked = (activeTarget == "player")
info.func = function(self)
local activeIdx = GetActiveIndex()
if activeIdx and RAY_Config.spells[activeIdx] then RAY_Config.spells[activeIdx].target = "player" else tempConfig.target = "player" end
UIDropDownMenu_SetSelectedValue(dropDown, "player")
UIDropDownMenu_SetText(dropDown, "Цель: Игрок")
CheckAllAuras()
CloseDropDownMenus()
end
UIDropDownMenu_AddButton(info)
info.text = "Цель: Таргет"
info.value = "target"
info.checked = (activeTarget == "target")
info.func = function(self)
local activeIdx = GetActiveIndex()
if activeIdx and RAY_Config.spells[activeIdx] then RAY_Config.spells[activeIdx].target = "target" else tempConfig.target = "target" end
UIDropDownMenu_SetSelectedValue(dropDown, "target")
UIDropDownMenu_SetText(dropDown, "Цель: Таргет")
CheckAllAuras()
CloseDropDownMenus()
end
UIDropDownMenu_AddButton(info)
end)
editBox:SetScript("OnTextChanged", function(self, userInput)
if userInput then
local idx = GetActiveIndex()
if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx].name = self:GetText() updateSpellLists() CheckAllAuras() end
end
end)
btnOk:SetScript("OnClick", function()
local typedName = editBox:GetText()
if not typedName or typedName == "" or typedName == " " then return end
local idx = GetActiveIndex()
if idx and RAY_Config.spells[idx] then
local data = RAY_Config.spells[idx]
data.name = typedName
data.target = UIDropDownMenu_GetSelectedValue(dropDown) or data.target
data.minStacks = math.floor(sliderStacks:GetValue())
data.alertTime = math.floor(sliderTime:GetValue())
data.onlyInCombat = cbCombat:GetChecked()
data.zoneWorld = cbWorld:GetChecked()
data.zoneParty = cbParty:GetChecked()
data.zoneRaid = cbRaid:GetChecked()
data.isCooldown = cbCooldown:GetChecked()
data.isProc = cbProc:GetChecked()
else
table.insert(RAY_Config.spells, {
name = typedName, mode = modeType, target = UIDropDownMenu_GetSelectedValue(dropDown) or tempConfig.target,
minStacks = math.floor(sliderStacks:GetValue()), alertTime = math.floor(sliderTime:GetValue()),
onlyInCombat = cbCombat:GetChecked(), zoneWorld = cbWorld:GetChecked(), zoneParty = cbParty:GetChecked(), zoneRaid = cbRaid:GetChecked(),
isCooldown = cbCooldown:GetChecked(), isProc = cbProc:GetChecked()
})
end
updateSpellLists() CheckAllAuras()
editBox:SetText("")
if modeType == "BUFF" then selectBuff(nil) else selectDebuff(nil) end
end)
return { editBox = editBox, sliderTime = sliderTime, sliderStacks = sliderStacks, dropDown = dropDown, scrollContent = scrollContent, cbCombat = cbCombat, cbWorld = cbWorld, cbParty = cbParty, cbRaid = cbRaid, cbCooldown = cbCooldown, cbProc = cbProc, stText = stText, ssText = ssText }
end
leftUI = CreateColumn(true, "BUFF", "|cff44FF44")
rightUI = CreateColumn(false, "DEBUFF", "|cffFF4444")
selectBuff = function(index)
selectedBuffIndex = index
for _, btn in ipairs(listButtonsBuff) do btn:UnlockHighlight() end
if index and RAY_Config.spells[index] then
local data = RAY_Config.spells[index]
local script = leftUI.editBox:GetScript("OnTextChanged")
leftUI.editBox:SetScript("OnTextChanged", nil) leftUI.editBox:SetText(data.name or "") leftUI.editBox:SetScript("OnTextChanged", script)
UIDropDownMenu_SetSelectedValue(leftUI.dropDown, data.target or "player")
UIDropDownMenu_SetText(leftUI.dropDown, data.target == "target" and "Цель: Таргет" or "Цель: Игрок")
leftUI.sliderTime:SetValue(data.alertTime or 0) leftUI.sliderStacks:SetValue(data.minStacks or 0)
leftUI.cbCombat:SetChecked(data.onlyInCombat) leftUI.cbWorld:SetChecked(data.zoneWorld) leftUI.cbParty:SetChecked(data.zoneParty) leftUI.cbRaid:SetChecked(data.zoneRaid)
leftUI.cbCooldown:SetChecked(data.isCooldown) leftUI.cbProc:SetChecked(data.isProc)
else
leftUI.editBox:SetText("") leftUI.sliderTime:SetValue(0) leftUI.sliderStacks:SetValue(0)
leftUI.cbCombat:SetChecked(true) leftUI.cbWorld:SetChecked(true) leftUI.cbParty:SetChecked(true) leftUI.cbRaid:SetChecked(true) leftUI.cbCooldown:SetChecked(false) leftUI.cbProc:SetChecked(false)
UIDropDownMenu_SetSelectedValue(leftUI.dropDown, "player") UIDropDownMenu_SetText(leftUI.dropDown, "Цель: Игрок")
end
end
selectDebuff = function(index)
selectedDebuffIndex = index
for _, btn in ipairs(listButtonsDebuff) do btn:UnlockHighlight() end
if index and RAY_Config.spells[index] then
local data = RAY_Config.spells[index]
local script = rightUI.editBox:GetScript("OnTextChanged")
rightUI.editBox:SetScript("OnTextChanged", nil) rightUI.editBox:SetText(data.name or "") rightUI.editBox:SetScript("OnTextChanged", script)
UIDropDownMenu_SetSelectedValue(rightUI.dropDown, data.target or "target")
UIDropDownMenu_SetText(rightUI.dropDown, data.target == "target" and "Цель: Таргет" or "Цель: Игрок")
rightUI.sliderTime:SetValue(data.alertTime or 0) rightUI.sliderStacks:SetValue(data.minStacks or 0)
rightUI.cbCombat:SetChecked(data.onlyInCombat) rightUI.cbWorld:SetChecked(data.zoneWorld) rightUI.cbParty:SetChecked(data.zoneParty) rightUI.cbRaid:SetChecked(data.zoneRaid)
rightUI.cbCooldown:SetChecked(data.isCooldown) rightUI.cbProc:SetChecked(data.isProc)
else
rightUI.editBox:SetText("") rightUI.sliderTime:SetValue(0) rightUI.sliderStacks:SetValue(0)
rightUI.cbCombat:SetChecked(true) rightUI.cbWorld:SetChecked(true) rightUI.cbParty:SetChecked(true) rightUI.cbRaid:SetChecked(true)
rightUI.cbCooldown:SetChecked(false) rightUI.cbProc:SetChecked(false)
UIDropDownMenu_SetSelectedValue(rightUI.dropDown, "target") UIDropDownMenu_SetText(rightUI.dropDown, "Цель: Таргет")
end
end
-- =========================================================================
-- 5. ОБНОВЛЕННЫЙ РЕНДЕР СПИСКОВ С НЕВИДИМЫМ КЛИППИНГОМ КНОПОК
-- =========================================================================
updateSpellLists = function()
for _, btn in ipairs(listButtonsBuff) do btn:Hide() end
for _, btn in ipairs(listButtonsDebuff) do btn:Hide() end
local buffCount, debuffCount = 1, 1
for i, spellData in ipairs(RAY_Config.spells) do
local isBuff = (spellData.mode == "BUFF")
-- ИСПРАВЛЕНО: Убрана опечатка склейки "isBuff group"
local count = isBuff and buffCount or debuffCount
local listButtons = isBuff and listButtonsBuff or listButtonsDebuff
local ui = isBuff and leftUI or rightUI
local btn = listButtons[count]
if not btn then
btn = CreateFrame("Button", nil, ui.scrollContent)
btn:SetSize(230, 20)
btn:SetNormalFontObject("GameFontNormal")
btn:SetHighlightTexture("Interface\Buttons\UI-Listbox-Highlight")
local delBtn = CreateFrame("Button", nil, btn, "UIPanelCloseButton")
delBtn:SetSize(18, 18) delBtn:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
delBtn:GetNormalTexture():SetTexCoord(0, 1, 0, 1)
btn.delBtn = delBtn
listButtons[count] = btn
end
local yPos = -((count - 1) * 22) + currentScrollOffset
btn:ClearAllPoints()
btn:SetPoint("TOPLEFT", 5, yPos)
local displayName = string.match(spellData.name, "[^|/]+") or "Пусто"
btn:SetText((isBuff and "|cff44FF44" or "|cffFF4444") .. displayName .. "|r")
if yPos > 0 or yPos < -(MAX_VISIBLE_HEIGHT - 18) then
btn:Hide()
else
btn:Show()
end
if isBuff then
if selectedBuffIndex == i then btn:LockHighlight() else btn:UnlockHighlight() end
btn:SetScript("OnClick", function() selectBuff(i) btn:LockHighlight() end)
else
if selectedDebuffIndex == i then btn:LockHighlight() else btn:UnlockHighlight() end
btn:SetScript("OnClick", function() selectDebuff(i) btn:LockHighlight() end)
end
btn.delBtn:SetScript("OnClick", function()
table.remove(RAY_Config.spells, i)
if isBuff then selectBuff(nil) else selectDebuff(nil) end
updateSpellLists() CheckAllAuras()
end)
if isBuff then buffCount = buffCount + 1 else debuffCount = debuffCount + 1 end
end
local maxItems = math.max(buffCount - 1, debuffCount - 1)
totalContentHeight = maxItems * 22
end
optionsPanel:EnableMouseWheel(true)
optionsPanel:SetScript("OnMouseWheel", function(self, delta)
local scrollStep = 22
currentScrollOffset = currentScrollOffset - (delta * scrollStep)
local maxScrollLimit = totalContentHeight - MAX_VISIBLE_HEIGHT
if maxScrollLimit < 0 then maxScrollLimit = 0 end
if currentScrollOffset < 0 then
currentScrollOffset = 0
elseif currentScrollOffset > maxScrollLimit then
currentScrollOffset = maxScrollLimit
end
updateSpellLists()
end)
optionsPanel:SetScript("OnShow", function()
currentScrollOffset = 0
selectBuff(nil)
selectDebuff(nil)
updateSpellLists()
dragCb:SetChecked(frame:IsMouseEnabled())
CheckAllAuras()
end)
optionsPanel:SetScript("OnHide", function()
CheckAllAuras()
end)
InterfaceOptions_AddCategory(optionsPanel)
end)
-- Слэш-команда
SLASH_RAY1 = "/ray"
SlashCmdList["RAY"] = function()
if optionsPanel then
InterfaceOptionsFrame_OpenToCategory(optionsPanel)
InterfaceOptionsFrame_OpenToCategory(optionsPanel)
end
end
