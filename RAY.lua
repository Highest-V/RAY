-- =========================================================================
-- 1. ИНИЦИАЛИЗАЦИЯ И РАЗДЕЛЬНОЕ СОХРАНЕНИЕ НАСТРОЕК ДЛЯ КАЖДОГО ПЕРСОНАЖА
-- =========================================================================
local addonName = "RAY"
local RAY_EventFrame = CreateFrame("Frame")

-- База данных теперь создается абсолютно пустой для каждого нового персонажа
local defaultSettings = {
    spells = {}
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
        -- Используется переменная SavedVariablesPerCharacter из вашего .toc
        if not RAY_Config then
            RAY_Config = defaultSettings
        else
            if not RAY_Config.spells then RAY_Config.spells = defaultSettings.spells end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FFFFRAY - Remember About Yourself|r загружен. Настройка: /ray")
    end
end)

-- =========================================================================
-- 2. СОЗДАНИЕ ГЛАВНОГО ИНДИКАТОРА НА ЭКРАНЕ
-- =========================================================================
local frame = CreateFrame("Frame", "RAY_MainFrame", UIParent)
frame:SetSize(600, 250)
frame:SetPoint("CENTER", 0, 150)
frame:Hide()

local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
text:SetPoint("CENTER", frame, "CENTER")
text:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE") 
text:SetTextColor(0, 1, 0.9) 
text:SetJustifyH("CENTER")

local animGroup = frame:CreateAnimationGroup()
local fadeOut = animGroup:CreateAnimation("Alpha")
fadeOut:SetChange(-0.6)
fadeOut:SetDuration(0.5)
fadeOut:SetOrder(1)
local fadeIn = animGroup:CreateAnimation("Alpha")
fadeIn:SetChange(0.6)
fadeIn:SetDuration(0.5)
fadeIn:SetOrder(2)
animGroup:SetLooping("REPEAT")

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
    if not RAY_Config or not RAY_Config.spells then return end

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
-- 4. ГРАФИЧЕСКИЙ ИНТЕРФЕЙС НАСТРОЕК (БЕЗОПАСНАЯ НЕВИДИМАЯ ПРОКРУТКА)
-- =========================================================================
local shortcutFrame = CreateFrame("Frame")
shortcutFrame:RegisterEvent("PLAYER_LOGIN")
shortcutFrame:SetScript("OnEvent", function()
optionsPanel = CreateFrame("Frame", "RAY_OptionsPanel", UIParent)
optionsPanel.name = "RAY"
local title = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", 16, -14)
title:SetText("|cff00FFFFНастройки модификации RAY (Remember About Yourself)|r")
local mainCbName = "RAY_MainEnableCB"
local mainCb = CreateFrame("CheckButton", mainCbName, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
mainCb:SetPoint("TOPLEFT", 16, -34)
_G[mainCbName .. "Text"]:SetText("Включить отображение сообщений RAY на экране")
mainCb:SetScript("OnShow", function(self) self:SetChecked(RAY_Config.enabled) end)
mainCb:SetScript("OnClick", function(self) RAY_Config.enabled = self:GetChecked() CheckAllAuras() end)
local line = optionsPanel:CreateTexture(nil, "BACKGROUND")
line:SetWidth(2)
line:SetHeight(445)
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
-- ИСПРАВЛЕНО: Корректно увеличиваем счётчик editCounter, убирая опечатку в имени переменной
editCounter = editCounter + 1
local editBox = CreateFrame("EditBox", "RAY_NewEdit_" .. editCounter, optionsPanel, "InputBoxTemplate")
editBox:SetSize(200, 25)
editBox:SetPoint("TOPLEFT", offsetX, -105)
editBox:SetAutoFocus(false)
local elabel = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
elabel:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 0, 2)
elabel:SetText(textColorCode .. "Название / ID (Используйте '/' для Или):|r")
local btnOk = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
btnOk:SetSize(40, 24)
btnOk:SetPoint("LEFT", editBox, "RIGHT", 5, 0)
btnOk:SetText("|cffFFFFFF|r|cffFFFF00ОК|r")
local tex = btnOk:CreateTexture()
tex:SetTexture(0.5, 0.1, 0.1, 0.8)
btnOk:SetNormalTexture(tex)
dropCounter = dropCounter + 1
local dropDown = CreateFrame("Frame", "RAY_DropDown_" .. dropCounter, optionsPanel, "UIDropDownMenuTemplate")
dropDown:SetPoint("TOPLEFT", offsetX - 15, -145)
UIDropDownMenu_SetWidth(dropDown, 100)
local tempConfig = { onlyInCombat = true, zoneWorld = true, zoneParty = true, zoneRaid = true, target = (modeType == "DEBUFF" and "target" or "player"), isCooldown = false, isProc = false }
local function GetActiveIndex()
return (modeType == "BUFF") and selectedBuffIndex or selectedDebuffIndex
end
local function CreateLocalCheckbox(label, yOffset, key)
cbCounter = cbCounter + 1
local name = "RAY_LocalCB_" .. cbCounter
local cb = CreateFrame("CheckButton", name, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
cb:SetPoint("TOPLEFT", offsetX, yOffset)
_G[name .. "Text"]:SetText(textColorCode .. label .. "|r")
cb:SetScript("OnClick", function(self)
local idx = GetActiveIndex()
if idx and RAY_Config.spells[idx] then
RAY_Config.spells[idx][key] = self:GetChecked()
CheckAllAuras()
else
tempConfig[key] = self:GetChecked()
end
end)
return cb
end
local cbCombat   = CreateLocalCheckbox("Включать только в бою", -175, "onlyInCombat")
local cbWorld    = CreateLocalCheckbox("Отслеживать в открытом мире", -195, "zoneWorld")
local cbParty    = CreateLocalCheckbox("Отслеживать в подземельях (Пати)", -217, "zoneParty")
local cbRaid     = CreateLocalCheckbox("Отслеживать в рейдовых зонах", -239, "zoneRaid")
local cbCooldown = CreateLocalCheckbox("Отслеживать готовность КД", -261, "isCooldown")
local cbProc     = CreateLocalCheckbox("Это прок (оповещать, когда активен)", -283, "isProc")
sliderCounter = sliderCounter + 1
local sTimeName = "RAY_NewTime_" .. sliderCounter
local sliderTime = CreateFrame("Slider", sTimeName, optionsPanel, "OptionsSliderTemplate")
sliderTime:SetSize(125, 17)
sliderTime:SetPoint("TOPLEFT", offsetX, -325)
sliderTime:SetMinMaxValues(0, 30)
sliderTime:SetValueStep(1)
_G[sTimeName .. "Text"]:SetText(textColorCode .. "Время (сек): 0|r")
_G[sTimeName .. "Low"]:SetText("0")
_G[sTimeName .. "High"]:SetText("30")
sliderCounter = sliderCounter + 1
local sStacksName = "RAY_NewStacks_" .. sliderCounter
local sliderStacks = CreateFrame("Slider", sStacksName, optionsPanel, "OptionsSliderTemplate")
sliderStacks:SetSize(125, 17)
sliderStacks:SetPoint("LEFT", sliderTime, "RIGHT", 20, 0)
sliderStacks:SetMinMaxValues(0, 5)
sliderStacks:SetValueStep(1)
_G[sStacksName .. "Text"]:SetText(textColorCode .. "Стаки: 0|r")
_G[sStacksName .. "Low"]:SetText("0")
_G[sStacksName .. "High"]:SetText("5")
local scrollContent = CreateFrame("Frame", nil, optionsPanel)
scrollContent:SetSize(250, MAX_VISIBLE_HEIGHT)
scrollContent:SetPoint("TOPLEFT", offsetX, -350)
UIDropDownMenu_Initialize(dropDown, function()
local idx = GetActiveIndex()
local currentTarget = "player"
if idx and RAY_Config.spells[idx] then currentTarget = RAY_Config.spells[idx].target or "player" else currentTarget = tempConfig.target end
local info = UIDropDownMenu_CreateInfo()
info.text = "Цель: Игрок"; info.value = "player"; info.checked = (currentTarget == "player")
info.func = function(self)
local activeIdx = GetActiveIndex()
if activeIdx and RAY_Config.spells[activeIdx] then RAY_Config.spells[activeIdx].target = "player" else tempConfig.target = "player" end
UIDropDownMenu_SetSelectedValue(dropDown, "player")
UIDropDownMenu_SetText(dropDown, "Цель: Игрок")
CheckAllAuras()
end
UIDropDownMenu_AddButton(info)
info.text = "Цель: Таргет"; info.value = "target"; info.checked = (currentTarget == "target")
info.func = function(self)
local activeIdx = GetActiveIndex()
if activeIdx and RAY_Config.spells[activeIdx] then RAY_Config.spells[activeIdx].target = "target" else tempConfig.target = "target" end
UIDropDownMenu_SetSelectedValue(dropDown, "target")
UIDropDownMenu_SetText(dropDown, "Цель: Таргет")
CheckAllAuras()
end
UIDropDownMenu_AddButton(info)
end)
sliderTime:SetScript("OnValueChanged", function(self, value)
local val = math.floor(value)
_G[self:GetName() .. "Text"]:SetText(textColorCode .. "Время (сек): " .. val .. "|r")
local idx = GetActiveIndex()
if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx].alertTime = val CheckAllAuras() end
end)
sliderStacks:SetScript("OnValueChanged", function(self, value)
local val = math.floor(value)
_G[self:GetName() .. "Text"]:SetText(textColorCode .. "Стаки: " .. val .. "|r")
local idx = GetActiveIndex()
if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx].minStacks = val CheckAllAuras() end
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
table.insert(RAY_Config.spells, {
name = typedName, mode = modeType, target = UIDropDownMenu_GetSelectedValue(dropDown) or tempConfig.target,
minStacks = math.floor(sliderStacks:GetValue()), alertTime = math.floor(sliderTime:GetValue()),
onlyInCombat = cbCombat:GetChecked(), zoneWorld = cbWorld:GetChecked(), zoneParty = cbParty:GetChecked(), zoneRaid = cbRaid:GetChecked(),
isCooldown = cbCooldown:GetChecked(), isProc = cbProc:GetChecked()
})
updateSpellLists() CheckAllAuras()
editBox:SetText("")
if modeType == "BUFF" then selectBuff(nil) else selectDebuff(nil) end
end)
return { editBox = editBox, sliderTime = sliderTime, sliderStacks = sliderStacks, dropDown = dropDown, scrollContent = scrollContent, cbCombat = cbCombat, cbWorld = cbWorld, cbParty = cbParty, cbRaid = cbRaid, cbCooldown = cbCooldown, cbProc = cbProc }
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
rightUI.cbCombat:SetChecked(true) rightUI.cbWorld:SetChecked(true) rightUI.cbParty:SetChecked(true) rightUI.cbRaid:SetChecked(true) rightUI.cbCooldown:SetChecked(false) rightUI.cbProc:SetChecked(false)
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
-- Сверхточный математический клиппинг
if yPos > 0 or yPos < -(MAX_VISIBLE_HEIGHT - 18) then
btn:Hide()
else
btn:Show()
end
local actualIndex = i
if isBuff then
if selectedBuffIndex == actualIndex then btn:LockHighlight() else btn:UnlockHighlight() end
btn:SetScript("OnClick", function() selectBuff(actualIndex) btn:LockHighlight() end)
else
if selectedDebuffIndex == actualIndex then btn:LockHighlight() else btn:UnlockHighlight() end
btn:SetScript("OnClick", function() selectDebuff(actualIndex) btn:LockHighlight() end)
end
btn.delBtn:SetScript("OnClick", function()
table.remove(RAY_Config.spells, actualIndex)
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
optionsPanel:SetScript("OnShow", function() currentScrollOffset = 0 selectBuff(nil) selectDebuff(nil) updateSpellLists() end)
if InterfaceOptions_AddCategory then
InterfaceOptions_AddCategory(optionsPanel)
else
local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, "RAY")
Settings.RegisterAddOnCategory(category)
end
end)
-- Слэш-команда
SLASH_RAY1 = "/ray"
SlashCmdList["RAY"] = function()
if optionsPanel then
if InterfaceOptionsFrame_OpenToCategory then
InterfaceOptionsFrame_OpenToCategory(optionsPanel)
InterfaceOptionsFrame_OpenToCategory(optionsPanel)
else
Settings.OpenToCategory(optionsPanel.name)
end
end
end
