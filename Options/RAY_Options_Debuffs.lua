-- Вынесено в функцию-конструктор, которая вызывается из главного файла при логине
function RAY_Engine.InitDebuffsPage()
    local panelName, modeType, textColor, globalSelectedIndexRef, listButtonsRef = "RAY-debuffs", "DEBUFF", PASTEL_DEBUFF, "selDebIdxG", "listBtnDebG"
    _G[globalSelectedIndexRef] = nil
    _G[listButtonsRef] = listButtonsDebuff

    local panel = CreateFrame("Frame", "RAY_Panel_"..panelName, optionsPanel) panel.name = panelName panel.parent = "RAY"
    local sFrame = CreateFrame("ScrollFrame", "RAY_Scroll_"..panelName, panel, "UIPanelScrollFrameTemplate") sFrame:SetPoint("TOPLEFT", 8, -40) sFrame:SetPoint("BOTTOMRIGHT", -28, 8)
    local sChild = CreateFrame("Frame", nil, sFrame) sChild:SetSize(380, 1050) sFrame:SetScrollChild(sChild)
    local pTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") pTitle:SetPoint("TOPLEFT", 16, -14) pTitle:SetText(textColor.."Управление отслеживанием: "..panelName.."|r")
    local editBox = CreateBlizzardEditBox(sChild, 8, -30, 240, "RAY_EBox_"..panelName)
    local elabel = sChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") elabel:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 2, 6) elabel:SetText("Название эффекта / ID способности:")
    local btnOk = CreateFrame("Button", nil, sChild, "UIPanelButtonTemplate") btnOk:SetSize(55, 25) btnOk:SetPoint("LEFT", editBox, "RIGHT", 8, 0) btnOk:SetText(PASTEL_YELLOW.."ОК|r")
    SetTooltip(btnOk, "Сохранить ауру в текущий active спек.")
    
    local colorBtn = CreateFrame("Button", nil, sChild)
    local editTime, sliderStacks, specSlider, cbCombat, cbWorld, cbParty, cbRaid, cbCooldown, cbProc, cbWeapon, cbProgress, cbHideCap, cbExternal, cbSummon, cbOwnWindow
    
    local dropDown = CreateFrame("Frame", "RAY_VDrop_"..panelName, sChild, "UIDropDownMenuTemplate") dropDown:SetPoint("TOPLEFT", -2, -75) dropDown:SetSize(150, 25)
    UIDropDownMenu_Initialize(dropDown, function()
        local info = UIDropDownMenu_CreateInfo() info.text = "Игрок" info.value = "player"
        info.func = function(self) UIDropDownMenu_SetSelectedValue(dropDown, self.value) UIDropDownMenu_SetText(dropDown, "Цель: Игрок") end
        UIDropDownMenu_AddButton(info)
        info = UIDropDownMenu_CreateInfo() info.text = "Текущая цель" info.value = "target"
        info.func = function(self) UIDropDownMenu_SetSelectedValue(dropDown, self.value) UIDropDownMenu_SetText(dropDown, "Цель: Тек. цель") end
        UIDropDownMenu_AddButton(info)
    end)
    SetTooltip(dropDown, "Указывает, на ком проверять наличие данного эффекта — на себе или на цели.")
    
    local tempConfig = { onlyInCombat = false, zoneWorld = false, zoneParty = false, zoneRaid = false, target = "target", isCooldown = false, isProc = false, isWeaponText = false, isStackProgress = false, isHideCap = false, isExternalOnly = false, isOwnWindow = false, isSummonObject = false, customSize = 24, color = { r = 0.5, g = 0.95, b = 0.8 } }
    local function GetActiveIndex() return _G[globalSelectedIndexRef] end
    local function SetActiveIndex(val) _G[globalSelectedIndexRef] = val end
    local currentY = -120

    local function AddVerticalCheckbox(label, tText, key)
        local cb = CreateFrame("CheckButton", nil, sChild, "InterfaceOptionsCheckButtonTemplate") cb:SetPoint("TOPLEFT", 8, currentY) cb:SetScale(0.9)
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
    specSlider = CreateFrame("Slider", "RAY_VSlider" .. panelName, sChild, "OptionsSliderTemplate") specSlider:SetSize(180, 16) specSlider:SetPoint("TOPLEFT", 12, currentY) specSlider:SetMinMaxValues(12, 48) specSlider:SetValueStep(1)
    local ssText = specSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") ssText:SetPoint("BOTTOMLEFT", specSlider, "TOPLEFT", 0, 4)
    specSlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value) ssText:SetText("Размер шрифта: " .. val) local idx = GetActiveIndex()
        if idx then local currentSpec = GetActiveTalentGroup() or 1 if RAY_Config.specSettings[currentSpec].spells[idx] then RAY_Config.specSettings[currentSpec].spells[idx].customSize = val if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end end else tempConfig.customSize = val end
    end)
    SetTooltip(specSlider, "Индивидуальный размер текста для данного оповещения.")
    
    local rowY = currentY - 40
    cbOwnWindow = CreateFrame("CheckButton", "RAY_OwnWinCheck" .. panelName, sChild, "InterfaceOptionsCheckButtonTemplate") cbOwnWindow:SetSize(26, 26) cbOwnWindow:SetPoint("TOPLEFT", sChild, "TOPLEFT", 12, rowY)
    local cbTextObj = _G[cbOwnWindow:GetName() .. "Text"] if cbTextObj then cbTextObj:SetText(textColor .. "Окно|r") cbTextObj:ClearAllPoints() cbTextObj:SetPoint("LEFT", cbOwnWindow, "RIGHT", 4, 1) end
    cbOwnWindow:SetScript("OnClick", function(self) local idx = GetActiveIndex() local val = self:GetChecked() and true or false if idx then local currentSpec = GetActiveTalentGroup() or 1 if RAY_Config.specSettings[currentSpec].spells[idx] then RAY_Config.specSettings[currentSpec].spells[idx].isOwnWindow = val if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end end else tempConfig.isOwnWindow = val end end)
    SetTooltip(cbOwnWindow, "Отвяждает алерт от общего фрейма и создает для него персональное перемещаемое окно.")
    
    colorBtn:SetSize(18, 18) colorBtn:SetPoint("TOPLEFT", sChild, "TOPLEFT", 200, rowY - 2)
    local cTex = colorBtn:CreateTexture(nil, "BACKGROUND") cTex:SetAllPoints() cTex:SetTexture(0.5, 0.95, 0.8) colorBtn.tex = cTex
    local defaultColorBtn = CreateFrame("Button", nil, sChild, "UIPanelButtonTemplate") defaultColorBtn:SetSize(140, 18) defaultColorBtn:SetPoint("LEFT", colorBtn, "RIGHT", 45, 0) defaultColorBtn:SetText("Цвет по умолчанию")
    SetTooltip(colorBtn, "Открыть палитру цветов для текста этого алерта.")
    SetTooltip(defaultColorBtn, "Сбросить цвет к стандартному бирюзовому.")
    
    currentY = rowY - 42
    editTime = CreateBlizzardEditBox(sChild, 12, currentY, 110, "RAY_VTimeBox"..panelName)
    local etText = sChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") etText:SetPoint("BOTTOMLEFT", editTime, "TOPLEFT", 0, 4) etText:SetText("Порог времени (сек):")
    editTime:SetScript("OnTextChanged", function(self)
        local val = tonumber(self:GetText()) or 0 local idx = GetActiveIndex()
        if idx then local currentSpec = GetActiveTalentGroup() or 1 if RAY_Config.specSettings[currentSpec].spells[idx] then RAY_Config.specSettings[currentSpec].spells[idx].alertTime = val if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end end else tempConfig.alertTime = val end
    end)
    SetTooltip(editTime, "Запуск посекундного обратного отсчета. Начнет напоминать за X сек до окончания действия баффа/дебаффа.")
    
    sliderStacks = CreateFrame("Slider", "RAY_VStk"..panelName, sChild, "OptionsSliderTemplate") sliderStacks:SetSize(110, 16) sliderStacks:SetPoint("TOPLEFT", sChild, "TOPLEFT", 200, currentY) sliderStacks:SetMinMaxValues(0, 10) sliderStacks:SetValueStep(1)
    local ssText2 = sliderStacks:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") ssText2:SetPoint("BOTTOMLEFT", sliderStacks, "TOPLEFT", 0, 4)
    sliderStacks:SetScript("OnValueChanged", function(self, value) local val = math.floor(value) ssText2:SetText("Порог стаков: " .. val) local idx = GetActiveIndex() if idx then local currentSpec = GetActiveTalentGroup() or 1 if RAY_Config.specSettings[currentSpec].spells[idx] then RAY_Config.specSettings[currentSpec].spells[idx].minStacks = val if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end end else tempConfig.minStacks = val end end)
SetTooltip(sliderStacks, "Целевой кап стаков для отображения (будет выводить динамику вроде '1/4', '2/4'...).")
currentY = currentY - 40
local listHeader = sChild:CreateFontString(nil, "OVERLAY", "GameFontNormal") listHeader:SetPoint("TOPLEFT", 8, currentY) listHeader:SetText(PASTEL_GRAY .. "Список настроек спека:|r")
currentY = currentY - 24
local listFrame = CreateFrame("Frame", nil, sChild) listFrame:SetSize(320, 200) listFrame:SetPoint("TOPLEFT", sChild, "TOPLEFT", 8, currentY)
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
btn = CreateFrame("Button", nil, listFrame) btn:SetSize(280, 22) btn:SetNormalFontObject("GameFontNormal") btn:SetHighlightTexture("Interface\Buttons\UI-Listbox-Highlight")
local del = CreateFrame("Button", nil, btn, "UIPanelCloseButton") del:SetSize(20, 20) del:SetPoint("RIGHT", btn, "RIGHT", -2, 0) btn.delBtn = del
btn:SetScript("OnClick", function(self)
if isSelfUpdating then return end SetActiveIndex(self.spellIndex) for _, b in ipairs(_G[listButtonsRef]) do b:UnlockHighlight() end self:LockHighlight()
local data = RAY_Config.specSettings[currentSpec].spells[self.spellIndex]
if data then
isSelfUpdating = true
editBox:SetText(tostring(data.name or "")) UIDropDownMenu_SetSelectedValue(dropDown, data.target or "target") UIDropDownMenu_SetText(dropDown, data.target == "target" and "Цель: Тек. цель" or "Цель: Игрок")
editTime:SetText(tostring(data.alertTime or 0)) sliderStacks:SetValue(data.minStacks or 0) cbCombat:SetChecked(data.onlyInCombat == true) cbWorld:SetChecked(data.zoneWorld == true) cbParty:SetChecked(data.zoneParty == true) cbRaid:SetChecked(data.zoneRaid == true) cbCooldown:SetChecked(data.isCooldown == true) cbProc:SetChecked(data.isProc == true) cbWeapon:SetChecked(data.isWeaponText == true) cbProgress:SetChecked(data.isStackProgress == true) cbHideCap:SetChecked(data.isHideCap == true) cbExternal:SetChecked(data.isExternalOnly == true) cbSummon:SetChecked(data.isSummonObject == true) cbOwnWindow:SetChecked(data.isOwnWindow == true) specSlider:SetValue(data.customSize or 24)
colorBtn.tex:SetVertexColor(data.color.r or 0.5, data.color.g or 0.95, data.color.b or 0.8) tempConfig.color = { r = data.color.r or 0.5, g = data.color.g or 0.95, b = data.color.b or 0.8 }
isSelfUpdating = false
end
end)
btn.delBtn:SetScript("OnClick", function(self)
local p = self:GetParent()
table.remove(RAY_Config.specSettings[currentSpec].spells, p.spellIndex) SetActiveIndex(nil)
isSelfUpdating = true editBox:SetText("") editTime:SetText("0") sliderStacks:SetValue(0) specSlider:SetValue(24) cbCombat:SetChecked(false) cbWorld:SetChecked(false) cbParty:SetChecked(false) cbRaid:SetChecked(false) cbCooldown:SetChecked(false) cbProc:SetChecked(false) cbWeapon:SetChecked(false) cbProgress:SetChecked(false) cbHideCap:SetChecked(false) cbExternal:SetChecked(false) cbSummon:SetChecked(false) cbOwnWindow:SetChecked(false) colorBtn.tex:SetVertexColor(0.5, 0.95, 0.8)
isSelfUpdating = false
RAY_Engine.RebuildSpellsLookup() if BuildVerticalAuraPage_UpdateAll then BuildVerticalAuraPage_UpdateAll() end if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end
end)
_G[listButtonsRef][count] = btn
end
btn.spellIndex = i btn:ClearAllPoints() btn:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, -((count - 1) * 26))
local rawName = tostring(spellData.name):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
local itemColor = spellData.color or { r = 0.5, g = 0.95, b = 0.8 }
local r = math.max(0, math.min(255, math.floor((itemColor.r or 0.5) * 255)))
local g = math.max(0, math.min(255, math.floor((itemColor.g or 0.95) * 255)))
local b = math.max(0, math.min(255, math.floor((itemColor.b or 0.8) * 255)))
btn:SetText(string.format("|cff%02x%02x%02x%s|r", r, g, b, string.match(rawName, "[^|/]+") or "Пусто")) btn:Show()
if GetActiveIndex() == i then btn:LockHighlight() else btn:UnlockHighlight() end count = count + 1
end
end
sChild:SetHeight(math.max(1000, math.abs(currentY) + (count * 26) + 50))
end
local function ColorCallback()
local r, g, b = ColorPickerFrame:GetColorRGB() colorBtn.tex:SetVertexColor(r, g, b) local idx = GetActiveIndex() if idx then local currentSpec = GetActiveTalentGroup() or 1 if RAY_Config.specSettings[currentSpec].spells[idx] then RAY_Config.specSettings[currentSpec].spells[idx].color = { r = r, g = g, b = b } end end tempConfig.color = { r = r, g = g, b = b } if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end LocalUpdateLists()
end
colorBtn:SetScript("OnClick", function() local idx = GetActiveIndex() local currentSpec = GetActiveTalentGroup() or 1 local current = (idx and RAY_Config.specSettings[currentSpec].spells[idx] and RAY_Config.specSettings[currentSpec].spells[idx].color) or tempConfig.color or { r = 0.5, g = 0.95, b = 0.8 } ColorPickerFrame.func = ColorCallback ColorPickerFrame.hasOpacity = false ColorPickerFrame:SetColorRGB(current.r or 0.5, current.g or 0.95, current.b or 0.8) ColorPickerFrame:SetFrameStrata("TOOLTIP") ColorPickerFrame:Hide() ColorPickerFrame:Show() end)
defaultColorBtn:SetScript("OnClick", function() local def = { r = 0.5, g = 0.95, b = 0.8 } colorBtn.tex:SetVertexColor(def.r, def.g, def.b) local idx = GetActiveIndex() if idx then local currentSpec = GetActiveTalentGroup() or 1 if RAY_Config.specSettings[currentSpec].spells[idx] then RAY_Config.specSettings[currentSpec].spells[idx].color = { r = def.r, g = def.g, b = def.b } end end tempConfig.color = { r = def.r, g = def.g, b = def.b } if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end LocalUpdateLists() end)
btnOk:SetScript("OnClick", function()
local txt = editBox:GetText() if not txt or txt == "" or txt == " " then return end local idx = GetActiveIndex() local cR, cG, cB = colorBtn.tex:GetVertexColor()
local item = { name = txt, mode = modeType, target = UIDropDownMenu_GetSelectedValue(dropDown) or tempConfig.target, minStacks = math.floor(sliderStacks:GetValue()), alertTime = tonumber(editTime:GetText()) or 0, onlyInCombat = cbCombat:GetChecked() and true or false, zoneWorld = cbWorld:GetChecked() and true or false, zoneParty = cbParty:GetChecked() and true or false, zoneRaid = cbRaid:GetChecked() and true or false, isCooldown = cbCooldown:GetChecked() and true or false, isProc = cbProc:GetChecked() and true or false, isWeaponText = cbWeapon:GetChecked() and true or false, isStackProgress = cbProgress:GetChecked() and true or false, isHideCap = cbHideCap:GetChecked() and true or false, isExternalOnly = cbExternal:GetChecked() and true or false, isSummonObject = cbSummon:GetChecked() and true or false, isOwnWindow = cbOwnWindow:GetChecked() and true or false, customSize = math.floor(specSlider:GetValue()), color = { r = cR, g = cG, b = cB } }
local currentSpec = GetActiveTalentGroup() or 1
-- ЗАЩИТА: Автоматическое создание таблиц, если база пустая
if not RAY_Config.specSettings then RAY_Config.specSettings = {} end
if not RAY_Config.specSettings[currentSpec] then RAY_Config.specSettings[currentSpec] = { spells = {}, sets = {}, buffs = {}, icds = {} } end
if not RAY_Config.specSettings[currentSpec].spells then RAY_Config.specSettings[currentSpec].spells = {} end
if idx and RAY_Config.specSettings[currentSpec].spells[idx] then RAY_Config.specSettings[currentSpec].spells[idx] = item else table.insert(RAY_Config.specSettings[currentSpec].spells, item) end
isSelfUpdating = true SetActiveIndex(nil) editBox:SetText("") editTime:SetText("0") sliderStacks:SetValue(0) specSlider:SetValue(24) cbCombat:SetChecked(false) cbWorld:SetChecked(false) cbParty:SetChecked(false) cbRaid:SetChecked(false) cbCooldown:SetChecked(false) cbProc:SetChecked(false) cbWeapon:SetChecked(false) cbProgress:SetChecked(false) cbHideCap:SetChecked(false) cbExternal:SetChecked(false) cbSummon:SetChecked(false) cbOwnWindow:SetChecked(false) colorBtn.tex:SetVertexColor(0.5, 0.95, 0.8)
isSelfUpdating = false RAY_Engine.RebuildSpellsLookup() if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end LocalUpdateLists() if BuildVerticalAuraPage_UpdateAll then BuildVerticalAuraPage_UpdateAll() end
end)
panel:HookScript("OnShow", function()
if isSelfUpdating then return end isSelfUpdating = true SetActiveIndex(nil) editBox:SetText("") editTime:SetText("0") sliderStacks:SetValue(0) specSlider:SetValue(24) cbCombat:SetChecked(false) cbWorld:SetChecked(false) cbParty:SetChecked(false) cbRaid:SetChecked(false) cbCooldown:SetChecked(false) cbProc:SetChecked(false) cbWeapon:SetChecked(false) cbProgress:SetChecked(false) cbHideCap:SetChecked(false) cbExternal:SetChecked(false) cbSummon:SetChecked(false) cbOwnWindow:SetChecked(false) colorBtn.tex:SetVertexColor(0.5, 0.95, 0.8) LocalUpdateLists() isSelfUpdating = false
end)
InterfaceOptions_AddCategory(panel)
updateDebuffsGlobalRef = LocalUpdateLists
if updateBuffsGlobalRef and updateDebuffsGlobalRef then
BuildVerticalAuraPage_UpdateAll = function() updateBuffsGlobalRef() updateDebuffsGlobalRef() end
end
end