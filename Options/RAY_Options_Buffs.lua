-- Вынесено в функцию-конструктор, которая вызывается из главного файла при логине
function RAY_Engine.InitBuffsPage()
    local panelName, modeType, textColor, globalSelectedIndexRef, listButtonsRef = "RAY-buffs", "BUFF", PASTEL_BUFF, "selBuffIdxG", "listBtnBufG"
    _G[globalSelectedIndexRef] = nil
    _G[listButtonsRef] = listButtonsBuff

    -- ГЛАВНАЯ ПАНЕЛЬ
    local panel = CreateFrame("Frame", "RAY_Panel_"..panelName, optionsPanel) panel.name = panelName panel.parent = "RAY"
    local pTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") pTitle:SetPoint("TOPLEFT", 16, -14) pTitle:SetText(textColor.."Управление отслеживанием: "..panelName.."|r")
    
    local editBox = CreateBlizzardEditBox(panel, 16, -50, 240, "RAY_EBox_"..panelName)
    local elabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") elabel:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 2, 6) elabel:SetText("Название эффекта / ID способности:")
    local btnOk = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate") btnOk:SetSize(55, 25) btnOk:SetPoint("LEFT", editBox, "RIGHT", 8, 0) btnOk:SetText(PASTEL_YELLOW.."ОК|r")
    SetTooltip(btnOk, "Сохранить ауру в список спека.")

    local listHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal") listHeader:SetPoint("TOPLEFT", 16, -95) listHeader:SetText(PASTEL_GRAY .. "Список настроек спека:|r")

    local sFrame = CreateFrame("ScrollFrame", "RAY_Scroll_"..panelName, panel, "UIPanelScrollFrameTemplate") sFrame:SetPoint("TOPLEFT", 16, -120) sFrame:SetPoint("BOTTOMRIGHT", -28, 45)
    local listFrame = CreateFrame("Frame", nil, sFrame) listFrame:SetSize(340, 800) sFrame:SetScrollChild(listFrame)

    -- СОЗДАНИЕ МОДАЛЬНОГО ОКНА НАСТРОЕК
    local modal = CreateFrame("Frame", "RAY_MWin_"..panelName, InterfaceOptionsFrame)
    modal:SetSize(400, 560) modal:SetPoint("CENTER", InterfaceOptionsFrame, "CENTER", 80, 0) modal:Hide()
    
    modal:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    modal:SetBackdropColor(0, 0, 0, 1) -- Сплошной черный непрозрачный фон
    
    modal:SetMovable(true) modal:EnableMouse(true) modal:RegisterForDrag("LeftButton")
    modal:SetScript("OnDragStart", modal.StartMoving) modal:SetScript("OnDragStop", modal.StopMovingOrSizing)
    modal:SetFrameStrata("TOOLTIP")

    local mTitle = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") mTitle:SetPoint("TOPLEFT", 24, -20)
    local mClose = CreateFrame("Button", nil, modal, "UIPanelCloseButton") mClose:SetPoint("TOPRIGHT", -6, -6)
    mClose:SetScript("OnClick", function() modal:Hide() end)

    local colorBtn = CreateFrame("Button", nil, modal)
    local editTime, sliderStacks, specSlider, cbCombat, cbWorld, cbParty, cbRaid, cbCooldown, cbProc, cbWeapon, cbProgress, cbHideCap, cbExternal, cbSummon, cbOwnWindow
    
    local dropDown = CreateFrame("Frame", "RAY_VDrop_"..panelName, modal, "UIDropDownMenuTemplate") dropDown:SetPoint("TOPLEFT", 6, -55) dropDown:SetSize(150, 25)
    UIDropDownMenu_Initialize(dropDown, function()
        local info = UIDropDownMenu_CreateInfo() info.text = "Игрок" info.value = "player"
        info.func = function(self) UIDropDownMenu_SetSelectedValue(dropDown, self.value) UIDropDownMenu_SetText(dropDown, "Цель: Игрок") end
        UIDropDownMenu_AddButton(info)
        info = UIDropDownMenu_CreateInfo() info.text = "Текущая цель" info.value = "target"
        info.func = function(self) UIDropDownMenu_SetSelectedValue(dropDown, self.value) UIDropDownMenu_SetText(dropDown, "Цель: Тек. цель") end
        UIDropDownMenu_AddButton(info)
    end)
    SetTooltip(dropDown, "Указывает, на ком проверять наличие данного эффекта — на себе или на цели.")

    local tempConfig = { onlyInCombat = false, zoneWorld = false, zoneParty = false, zoneRaid = false, target = "player", isCooldown = false, isProc = false, isWeaponText = false, isStackProgress = false, isHideCap = false, isExternalOnly = false, isOwnWindow = false, isSummonObject = false, customSize = 24, color = { r = 0.5, g = 0.95, b = 0.8 } }
    local function GetActiveIndex() return _G[globalSelectedIndexRef] end
    local function SetActiveIndex(val) _G[globalSelectedIndexRef] = val end
    local currentY = -95

    local function AddVerticalCheckbox(label, tText, key)
        local cb = CreateFrame("CheckButton", nil, modal, "InterfaceOptionsCheckButtonTemplate") cb:SetPoint("TOPLEFT", 16, currentY) cb:SetScale(0.95)
        local t = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal") t:SetPoint("LEFT", cb, "RIGHT", 5, 1) t:SetText(textColor..label.."|r")
        cb:SetScript("OnClick", function(self) local idx = GetActiveIndex() local val = self:GetChecked() and true or false if idx then local currentSpec = GetActiveTalentGroup() or 1 if RAY_Config.specSettings[currentSpec].spells[idx] then RAY_Config.specSettings[currentSpec].spells[idx][key] = val if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end end else tempConfig[key] = val end end)
        SetTooltip(cb, tText) currentY = currentY - 26 return cb
    end

    cbCombat   = AddVerticalCheckbox("Включать только в бою", "Скрывает напоминание, если вы находитесь вне боя.", "onlyInCombat")
    cbWorld    = AddVerticalCheckbox("Отслеживать в открытом мире (соло)", "Включает отслеживание на каче и в открытом мире.", "zoneWorld")
    cbParty    = AddVerticalCheckbox("Отслеживать в подземельях (5 тел)", "Включает отслеживание в инстах на 5 человек.", "zoneParty")
    cbRaid     = AddVerticalCheckbox("Отслеживать в рейдовых зонах", "Включает отслеживание в рейдах (10/25 тел).", "zoneRaid")
    cbCooldown = AddVerticalCheckbox("Отслеживать готовность КД", "Триггер готовности: Оповещает, когда способность ГОТОВА к прожатию.", "isCooldown")
    cbProc     = AddVerticalCheckbox("Это прок (активен до траты)", "Триггер прока: Светится, пока бафф висит на вас, исчезает при спаде.", "isProc")
    cbWeapon   = AddVerticalCheckbox("Чары инженерии / оружия", "Специальный скан на наличие чарок на оружии или перчатках.", "isWeaponText")
    cbProgress = AddVerticalCheckbox("Показывать набор стаков", "Выводит текущее количество стаков относительно ползунка лимита (например, '2/4 ст').", "isStackProgress")
    cbHideCap  = AddVerticalCheckbox("Скрыть при полном капе стаков", "Прячет алерт, если вы набрали максимальный кап стаков.", "isHideCap")
    cbExternal = AddVerticalCheckbox("Внешняя аура (Обнаружение чужих)", "Отслеживает применение этой способности другими игроками.", "isExternalOnly")
    cbSummon   = AddVerticalCheckbox("Это призыв (Тотем/Горгулья)", "Триггер объектов: Прогрессирующий секундный таймер призывных существ.", "isSummonObject")
    
    currentY = currentY - 15
    specSlider = CreateFrame("Slider", "RAY_BuffsSliderSize", modal, "OptionsSliderTemplate") specSlider:SetSize(160, 16) specSlider:SetPoint("TOPLEFT", 20, currentY) specSlider:SetMinMaxValues(12, 48) specSlider:SetValueStep(1)
    local ssText = specSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") ssText:SetPoint("BOTTOMLEFT", specSlider, "TOPLEFT", 0, 4)
    specSlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value) ssText:SetText("Размер шрифта: " .. val) local idx = GetActiveIndex()
        if idx then local currentSpec = GetActiveTalentGroup() or 1 if RAY_Config.specSettings[currentSpec].spells[idx] then RAY_Config.specSettings[currentSpec].spells[idx].customSize = val if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end end else tempConfig.customSize = val end
    end)
    SetTooltip(specSlider, "Индивидуальный размер текста для данного оповещения.")
    
    local rowY = currentY - 40
    cbOwnWindow = CreateFrame("CheckButton", "RAY_BuffsOwnWinCheck", modal, "InterfaceOptionsCheckButtonTemplate") cbOwnWindow:SetSize(26, 26) cbOwnWindow:SetPoint("TOPLEFT", modal, "TOPLEFT", 20, rowY)
    local cbTextObj = _G[cbOwnWindow:GetName() .. "Text"] if cbTextObj then cbTextObj:SetText(textColor .. "Окно|r") cbTextObj:ClearAllPoints() cbTextObj:SetPoint("LEFT", cbOwnWindow, "RIGHT", 4, 1) end
    cbOwnWindow:SetScript("OnClick", function(self) local idx = GetActiveIndex() local val = self:GetChecked() and true or false if idx then local currentSpec = GetActiveTalentGroup() or 1 if RAY_Config.specSettings[currentSpec].spells[idx] then RAY_Config.specSettings[currentSpec].spells[idx].isOwnWindow = val if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end end else tempConfig.isOwnWindow = val end end)
    SetTooltip(cbOwnWindow, "Отвяждает алерт от общего фрейма и создает для него персональное перемещаемое окно.")
    
    colorBtn:SetSize(18, 18) colorBtn:SetPoint("TOPLEFT", modal, "TOPLEFT", 210, rowY - 2)
    local cTex = colorBtn:CreateTexture(nil, "BACKGROUND") cTex:SetAllPoints() cTex:SetTexture(0.5, 0.95, 0.8) colorBtn.tex = cTex
    local defaultColorBtn = CreateFrame("Button", nil, modal, "UIPanelButtonTemplate") defaultColorBtn:SetSize(130, 18) defaultColorBtn:SetPoint("LEFT", colorBtn, "RIGHT", 10, 0) defaultColorBtn:SetText("Цвет по умолчанию")
    SetTooltip(colorBtn, "Открыть палитру цветов для текста этого алерта.")
    SetTooltip(defaultColorBtn, "Сбросить цвет к стандартному бирюзовому.")
    
    currentY = rowY - 42
    editTime = CreateBlizzardEditBox(modal, 20, currentY, 110, "RAY_BuffsTimeBox")
    local etText = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") etText:SetPoint("BOTTOMLEFT", editTime, "TOPLEFT", 0, 4) etText:SetText("Порог времени (сек):")
    editTime:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText()) or 0 local idx = GetActiveIndex()
if idx then local currentSpec = GetActiveTalentGroup() or 1 if RAY_Config.specSettings[currentSpec].spells[idx] then RAY_Config.specSettings[currentSpec].spells[idx].alertTime = val if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end end else tempConfig.alertTime = val end
end)
SetTooltip(editTime, "Запуск посекундного обратного отсчета. Начнет напоминать за X сек до окончания действия баффа/дебаффа.")
sliderStacks = CreateFrame("Slider", "RAY_BuffsInterStk", modal, "OptionsSliderTemplate") sliderStacks:SetSize(140, 16) sliderStacks:SetPoint("TOPLEFT", modal, "TOPLEFT", 210, currentY) sliderStacks:SetMinMaxValues(0, 10) sliderStacks:SetValueStep(1)
local ssText2 = sliderStacks:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") ssText2:SetPoint("BOTTOMLEFT", sliderStacks, "TOPLEFT", 0, 4)
sliderStacks:SetScript("OnValueChanged", function(self, value) local val = math.floor(value) ssText2:SetText("Порог стаков: " .. val) local idx = GetActiveIndex() if idx then local currentSpec = GetActiveTalentGroup() or 1 if RAY_Config.specSettings[currentSpec].spells[idx] then RAY_Config.specSettings[currentSpec].spells[idx].minStacks = val if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end end else tempConfig.minStacks = val end end)
SetTooltip(sliderStacks, "Целевой кап стаков для отображения (будет выводить динамику вроде '1/4', '2/4'...).")
local function LocalUpdateLists()
for _, b in ipairs(_G[listButtonsRef]) do b:Hide() end local count = 1
local currentSpec = GetActiveTalentGroup() or 1
local spells = RAY_Config.specSettings and RAY_Config.specSettings[currentSpec] and RAY_Config.specSettings[currentSpec].spells
if not spells then return end
for i = 1, #spells do
local spellData = spells[i]
if spellData and spellData.mode == modeType then
local btn = _G[listButtonsRef][count]
if not btn then
btn = CreateFrame("Button", nil, listFrame) btn:SetSize(310, 24) btn:SetNormalFontObject("GameFontNormal")
local hl = btn:CreateTexture(nil, "HIGHLIGHT")
hl:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
hl:SetBlendMode("ADD") hl:SetVertexColor(1, 0.8, 0, 0.4) hl:SetAllPoints(btn)
btn:SetHighlightTexture(hl)
local activeTex = btn:CreateTexture(nil, "OVERLAY")
activeTex:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
activeTex:SetBlendMode("ADD") activeTex:SetVertexColor(1, 0.8, 0, 0.3) activeTex:SetAllPoints(btn)
activeTex:Hide() btn.goldSelect = activeTex
local del = CreateFrame("Button", nil, btn, "UIPanelCloseButton") del:SetSize(18, 18) del:SetPoint("RIGHT", btn, "RIGHT", -2, 0) btn.delBtn = del
btn:SetScript("OnClick", function(self)
if isSelfUpdating then return end SetActiveIndex(self.spellIndex)
for _, b in ipairs(_G[listButtonsRef]) do if b.goldSelect then b.goldSelect:Hide() end end
if self.goldSelect then self.goldSelect:Show() end
local data = RAY_Config.specSettings[currentSpec].spells[self.spellIndex]
if data then
isSelfUpdating = true
mTitle:SetText(textColor .. (string.match(tostring(data.name), "[^|/]+") or data.name) .. "|r")
UIDropDownMenu_SetSelectedValue(dropDown, data.target or "player") UIDropDownMenu_SetText(dropDown, data.target == "target" and "Цель: Тек. цель" or "Цель: Игрок")
editTime:SetText(tostring(data.alertTime or 0)) sliderStacks:SetValue(data.minStacks or 0) cbCombat:SetChecked(data.onlyInCombat == true) cbWorld:SetChecked(data.zoneWorld == true) cbParty:SetChecked(data.zoneParty == true) cbRaid:SetChecked(data.zoneRaid == true) cbCooldown:SetChecked(data.isCooldown == true) cbProc:SetChecked(data.isProc == true) cbWeapon:SetChecked(data.isWeaponText == true) cbProgress:SetChecked(data.isStackProgress == true) cbHideCap:SetChecked(data.isHideCap == true) cbExternal:SetChecked(data.isExternalOnly == true) cbSummon:SetChecked(data.isSummonObject == true) cbOwnWindow:SetChecked(data.isOwnWindow == true) specSlider:SetValue(data.customSize or 24)
local c = data.color or { r = 0.5, g = 0.95, b = 0.8 }
colorBtn.tex:SetVertexColor(c.r or 0.5, c.g or 0.95, c.b or 0.8) tempConfig.color = { r = c.r or 0.5, g = c.g or 0.95, b = c.b or 0.8 }
isSelfUpdating = false
modal:Show()
end
end)
btn.delBtn:SetScript("OnClick", function(self)
local p = self:GetParent()
table.remove(RAY_Config.specSettings[currentSpec].spells, p.spellIndex) SetActiveIndex(nil) modal:Hide()
RAY_Engine.RebuildSpellsLookup() if BuildVerticalAuraPage_UpdateAll then BuildVerticalAuraPage_UpdateAll() end if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end
LocalUpdateLists()
end)
_G[listButtonsRef][count] = btn
end
btn.spellIndex = i btn:ClearAllPoints() btn:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 4, -((count - 1) * 26))
local rawName = tostring(spellData.name):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
local itemColor = spellData.color or { r = 0.5, g = 0.95, b = 0.8 }
local r = (itemColor.r or 0.5) * 255
local g = (itemColor.g or 0.95) * 255
local b = (itemColor.b or 0.8) * 255
btn:SetText(string.format("|cff%02x%02x%02x%s|r", r, g, b, string.match(rawName, "[^|/]+") or "Пусто")) btn:Show()
if GetActiveIndex() == i then btn.goldSelect:Show() else btn.goldSelect:Hide() end count = count + 1
end
end
listFrame:SetHeight(count * 26 + 20)
end
local function ColorCallback()
local r, g, b = ColorPickerFrame:GetColorRGB() colorBtn.tex:SetVertexColor(r, g, b) local idx = GetActiveIndex() if idx then local currentSpec = GetActiveTalentGroup() or 1 if RAY_Config.specSettings[currentSpec].spells[idx] then RAY_Config.specSettings[currentSpec].spells[idx].color = { r = r, g = g, b = b } end end tempConfig.color = { r = r, g = g, b = b } if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end LocalUpdateLists()
end
colorBtn:SetScript("OnClick", function() local idx = GetActiveIndex() local currentSpec = GetActiveTalentGroup() or 1 local current = (idx and RAY_Config.specSettings[currentSpec].spells[idx] and RAY_Config.specSettings[currentSpec].spells[idx].color) or tempConfig.color or { r = 0.5, g = 0.95, b = 0.8 } ColorPickerFrame.func = ColorCallback ColorPickerFrame.hasOpacity = false ColorPickerFrame:SetColorRGB(current.r or 0.5, current.g or 0.95, current.b or 0.8) ColorPickerFrame:SetFrameStrata("TOOLTIP") ColorPickerFrame:Hide() ColorPickerFrame:Show() end)
defaultColorBtn:SetScript("OnClick", function() local def = { r = 0.5, g = 0.95, b = 0.8 } colorBtn.tex:SetVertexColor(def.r, def.g, def.b) local idx = GetActiveIndex() if idx then local currentSpec = GetActiveTalentGroup() or 1 if RAY_Config.specSettings[currentSpec].spells[idx] then RAY_Config.specSettings[currentSpec].spells[idx].color = { r = def.r, g = def.g, b = def.b } end end tempConfig.color = { r = def.r, g = def.g, b = def.b } if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end LocalUpdateLists() end)
btnOk:SetScript("OnClick", function()
local txt = editBox:GetText() if not txt or txt == "" or txt == " " then return end
local cleanText = txt:gsub("^%s*(.-)%s*$", "%1")
local spellID = tonumber(cleanText)
if spellID then
local spellName = GetSpellInfo(spellID)
if spellName then txt = spellName end
end
local item = { name = txt, mode = modeType, target = "player", minStacks = 0, alertTime = 0, onlyInCombat = false, zoneWorld = true, zoneParty = true, zoneRaid = true, isCooldown = false, isProc = false, isWeaponText = false, isStackProgress = false, isHideCap = false, isExternalOnly = false, isSummonObject = false, isOwnWindow = false, customSize = 24, color = { r = 0.5, g = 0.95, b = 0.8 } }
local currentSpec = GetActiveTalentGroup() or 1
if not RAY_Config.specSettings then RAY_Config.specSettings = {} end
if not RAY_Config.specSettings[currentSpec] then RAY_Config.specSettings[currentSpec] = { spells = {}, sets = {}, buffs = {}, icds = {} } end
if not RAY_Config.specSettings[currentSpec].spells then RAY_Config.specSettings[currentSpec].spells = {} end
table.insert(RAY_Config.specSettings[currentSpec].spells, item)
local newIndex = #RAY_Config.specSettings[currentSpec].spells -- Находим индекс добавленного спелла
editBox:SetText("")
RAY_Engine.RebuildSpellsLookup()
LocalUpdateLists()
if BuildVerticalAuraPage_UpdateAll then BuildVerticalAuraPage_UpdateAll() end
if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end
-- АВТОМАТИКА: Сразу же симулируем клик по новому спеллу, чтобы открыть окно настроек
SetActiveIndex(newIndex)
mTitle:SetText(textColor .. (string.match(tostring(item.name), "[^|/]+") or item.name) .. "|r")
UIDropDownMenu_SetSelectedValue(dropDown, item.target or "player") UIDropDownMenu_SetText(dropDown, item.target == "target" and "Цель: Тек. цель" or "Цель: Игрок")
editTime:SetText(tostring(item.alertTime or 0)) sliderStacks:SetValue(item.minStacks or 0) cbCombat:SetChecked(item.onlyInCombat == true) cbWorld:SetChecked(item.zoneWorld == true) cbParty:SetChecked(item.zoneParty == true) cbRaid:SetChecked(item.zoneRaid == true) cbCooldown:SetChecked(item.isCooldown == true) cbProc:SetChecked(item.isProc == true) cbWeapon:SetChecked(item.isWeaponText == true) cbProgress:SetChecked(item.isStackProgress == true) cbHideCap:SetChecked(item.isHideCap == true) cbExternal:SetChecked(item.isExternalOnly == true) cbSummon:SetChecked(item.isSummonObject == true) cbOwnWindow:SetChecked(item.isOwnWindow == true) specSlider:SetValue(item.customSize or 24)
colorBtn.tex:SetVertexColor(item.color.r or 0.5, item.color.g or 0.95, item.color.b or 0.8) tempConfig.color = { r = item.color.r or 0.5, g = item.color.g or 0.95, b = item.color.b or 0.8 }
modal:Show()
end)
panel:HookScript("OnShow", function() modal:Hide() SetActiveIndex(nil) editBox:SetText("") LocalUpdateLists() end)
panel:HookScript("OnHide", function() modal:Hide() end)
InterfaceOptions_AddCategory(panel)
updateBuffsGlobalRef = LocalUpdateLists
end