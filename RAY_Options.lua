local shortcutFrame = CreateFrame("Frame")
local isSelfUpdating = false
local dragCbGlobal

function ToggleRayMove(enable)
    if RAY_Config and enable and not RAY_Config.enabled then
        RAY_Config.enabled = true
    end

    local mainText = _G["RAY_MainFrameText"]

    if enable then
        RAY_MainFrame:EnableMouse(true) 
        dragBg:Show() 
        dragBorder:Show() 
        if mainText and type(mainText.SetText) == "function" then
            mainText:SetText(PASTEL_TITLE .. "[RAY]: Главное окно|r")
        end
        if not RAY_MainFrame:IsShown() then RAY_MainFrame:Show() animGroup:Play() end
        
        for i = 1, #RAY_Config.spells do
            local spellData = RAY_Config.spells[i]
            if spellData and spellData.name ~= "" and spellData.isOwnWindow then
                local cleanName = tostring(spellData.name):match("[^|/]+") or spellData.name
                local cf = GetOrCreateCustomFrame(spellData.name)
                cf:EnableMouse(true) cf.bg:Show() cf.border:Show()
                
                if cf.labelString then
                    cf.labelString:SetText("[Окно]: " .. cleanName)
                    cf.labelString:SetFont("Fonts\\FRIZQT__.TTF", spellData.customSize or 24, "OUTLINE")
                end
                
                local frameKey = spellData.name:gsub("%s", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                if RAY_Config.customFramePositions and RAY_Config.customFramePositions[frameKey] then 
                    local pos = RAY_Config.customFramePositions[frameKey] 
                    cf:ClearAllPoints() 
                    cf:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y) 
                end
                if not cf:IsShown() then cf:Show() cf.anim:Play() end
            end
        end
    else
        RAY_MainFrame:EnableMouse(false) 
        dragBg:Hide() 
        dragBorder:Hide() 
        animGroup:Stop()
        if mainText and type(mainText.SetText) == "function" then mainText:SetText("") end
        RAY_MainFrame:Hide()
        
        for i = 1, #RAY_Config.spells do
            local spellData = RAY_Config.spells[i]
            if spellData and spellData.name then
                local frameKey = spellData.name:gsub("%s", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                local cf = customFramesPool[frameKey]
                if cf then
                    cf:EnableMouse(false) cf.bg:Hide() cf.border:Hide() cf.anim:Stop()
                    cf.labelString:SetText("")
                    cf:Hide()
                end
            end
        end
        CheckAllAuras()
    end
    
    if dragCbGlobal then dragCbGlobal:SetChecked(enable) end
end

shortcutFrame:RegisterEvent("PLAYER_LOGIN")
shortcutFrame:SetScript("OnEvent", function()
    optionsPanel = CreateFrame("Frame", "RAY_MainOptionsPanel", UIParent) optionsPanel.name = "RAY"
    local title = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") title:SetPoint("TOPLEFT", 16, -16) title:SetText(PASTEL_TITLE .. "Модификация RAY (Remember About Yourself)|r")
    
    local mainCb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate") mainCb:SetPoint("TOPLEFT", 16, -55)
    local mainCbText = mainCb:CreateFontString(nil, "OVERLAY", "GameFontHighlight") mainCbText:SetPoint("LEFT", mainCb, "RIGHT", 5, 1) mainCbText:SetText("RAY-оповещения")
    mainCb:SetScript("OnShow", function(self) self:SetChecked(RAY_Config.enabled) end)
    mainCb:SetScript("OnClick", function(self) RAY_Config.enabled = self:GetChecked() and true or false CheckAllAuras() end)
    SetTooltip(mainCb, "Включение или полное отключение отображения всех аур и предупреждений мода RAY.")
    
    local dragCb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate") dragCb:SetPoint("TOPLEFT", 16, -95)
    local dragCbText = dragCb:CreateFontString(nil, "OVERLAY", "GameFontNormal") dragCbText:SetPoint("LEFT", dragCb, "RIGHT", 5, 1) dragCbText:SetText(PASTEL_YELLOW .. "Move|r")
    dragCbGlobal = dragCb
    
    dragCb:SetScript("OnShow", function(self) self:SetChecked(RAY_MainFrame:IsMouseEnabled()) end)
    dragCb:SetScript("OnClick", function(self) ToggleRayMove(self:GetChecked()) end)
    SetTooltip(dragCb, "Режим перемещения окон аур мышкой по экрану. (Можно переключать через /raymove)")
    
    local radarCb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate") radarCb:SetPoint("TOPLEFT", 16, -135)
    local radarCbText = radarCb:CreateFontString(nil, "OVERLAY", "GameFontNormal") radarCbText:SetPoint("LEFT", radarCb, "RIGHT", 5, 1) radarCbText:SetText(PASTEL_DEBUFF .. "RAY-Radar|r")
    radarCb:SetScript("OnShow", function(self) self:SetChecked(RAY_Config.radarEnabled) end) radarCb:SetScript("OnClick", function(self) RAY_Config.radarEnabled = self:GetChecked() end)
    SetTooltip(radarCb, "Включает подробное логирование применяемых тотемов, горгулий и аур напрямую в чат.")
    
    local hunterCb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate") hunterCb:SetPoint("TOPLEFT", 16, -175)
    local hunterCbText = hunterCb:CreateFontString(nil, "OVERLAY", "GameFontNormal") hunterCbText:SetPoint("LEFT", hunterCb, "RIGHT", 5, 1) hunterCbText:SetText(PASTEL_BUFF .. "Box Detector|r")
    hunterCb:SetScript("OnShow", function(self) self:SetChecked(RAY_Config.boxHunterEnabled) end) hunterCb:SetScript("OnClick", function(self) RAY_Config.boxHunterEnabled = self:GetChecked() sylvanasAlertActive = false CheckAllAuras() end)
    SetTooltip(hunterCb, "Автоматически вычисляет игрока, запустившего Шкатулку Сильваны.")

    local cpCb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate") cpCb:SetPoint("TOPLEFT", 16, -215)
    local cpCbText = cpCb:CreateFontString(nil, "OVERLAY", "GameFontNormal") cpCbText:SetPoint("LEFT", cpCb, "RIGHT", 5, 1) cpCbText:SetText("|cffFFD369Отслеживать Комбо-Поинты (КП)|r")
    cpCb:SetScript("OnShow", function(self) self:SetChecked(RAY_Config.comboTrackerEnabled == true) end)
    cpCb:SetScript("OnClick", function(self) RAY_Config.comboTrackerEnabled = self:GetChecked() and true or false CheckAllAuras() end)
    SetTooltip(cpCb, "Автоматический сквозной вывод серии приёмов для разбойников и друидов (котов) в текстовом формате без создания отдельных правил.")
    
    local cpSlider = CreateFrame("Slider", "RAY_MainComboSlider", optionsPanel, "OptionsSliderTemplate") cpSlider:SetSize(180, 16) cpSlider:SetPoint("TOPLEFT", 40, -255) cpSlider:SetMinMaxValues(1, 5) cpSlider:SetValueStep(1)
    local cpSliderText = cpSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") cpSliderText:SetPoint("BOTTOMLEFT", cpSlider, "TOPLEFT", 0, 4)
    cpSlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value)
        cpSliderText:SetText("Целевой порог КП: " .. val)
        if RAY_Config then RAY_Config.comboTrackerLimit = val CheckAllAuras() end
    end)
    cpSlider:SetScript("OnShow", function(self)
        if not RAY_Config.comboTrackerLimit then RAY_Config.comboTrackerLimit = 5 end
        self:SetValue(RAY_Config.comboTrackerLimit)
        cpSliderText:SetText("Целевой порог КП: " .. RAY_Config.comboTrackerLimit)
    end)
    SetTooltip(cpSlider, "Количество комбо-поинтов, при наборе которого индикатор загорится ярко-красным цветом.")

    local btnClear = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate") btnClear:SetSize(140, 30) btnClear:SetPoint("TOPLEFT", 16, -305) btnClear:SetText("|cffFF7676Полный сброс|r")
    btnClear:SetScript("OnClick", function() RAY_Config = nil ReloadUI() end) SetTooltip(btnClear, "Полностью стирает базу данных аддона RAY и перезагружает интерфейс.")
    InterfaceOptions_AddCategory(optionsPanel)
    
    local function BuildVerticalAuraPage(panelName, modeType, textColor, globalSelectedIndexRef, listButtonsRef)
        local panel = CreateFrame("Frame", "RAY_Panel_"..panelName, optionsPanel) panel.name = panelName panel.parent = "RAY"
        local sFrame = CreateFrame("ScrollFrame", "RAY_Scroll_"..panelName, panel, "UIPanelScrollFrameTemplate") sFrame:SetPoint("TOPLEFT", 8, -40) sFrame:SetPoint("BOTTOMRIGHT", -28, 8)
        local sChild = CreateFrame("Frame", nil, sFrame) sChild:SetSize(380, 1050) sFrame:SetScrollChild(sChild)
        local pTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") pTitle:SetPoint("TOPLEFT", 16, -14) pTitle:SetText(textColor.."Управление отслеживанием: "..panelName.."|r")
        local editBox = CreateBlizzardEditBox(sChild, 8, -30, 240, "RAY_EBox_"..panelName)
        local elabel = sChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") elabel:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 2, 6) elabel:SetText("Название эффекта / ID способности (через '/' = ИЛИ):")
        local btnOk = CreateFrame("Button", nil, sChild, "UIPanelButtonTemplate") btnOk:SetSize(55, 25) btnOk:SetPoint("LEFT", editBox, "RIGHT", 8, 0) btnOk:SetText(PASTEL_YELLOW.."ОК|r")
        
        local colorBtn = CreateFrame("Button", nil, sChild)
        local editTime, sliderStacks, specSlider, cbCombat, cbWorld, cbParty, cbRaid, cbCooldown, cbProc, cbWeapon, cbProgress, cbHideCap, cbExternal, cbSummon, cbOwnWindow
        
        local dropDown = CreateFrame("Frame", "RAY_VDrop_"..panelName, sChild, "UIDropDownMenuTemplate") dropDown.Point = function() end dropDown:SetPoint("TOPLEFT", -2, -75) dropDown:SetSize(150, 25)
        UIDropDownMenu_Initialize(dropDown, function()
            local info = UIDropDownMenu_CreateInfo() 
            info.text = "Игрок" 
            info.value = "player" 
            info.func = function(self) UIDropDownMenu_SetSelectedValue(dropDown, self.value) UIDropDownMenu_SetText(dropDown, "Цель: Игрок") end 
            UIDropDownMenu_AddButton(info)
            info = UIDropDownMenu_CreateInfo()
            info.text = "Текущая цель" 
info.value = "target"
info.func = function(self) UIDropDownMenu_SetSelectedValue(dropDown, self.value) UIDropDownMenu_SetText(dropDown, "Цель: Тек. цель") end
UIDropDownMenu_AddButton(info)
end)
local tempConfig = { onlyInCombat = false, zoneWorld = false, zoneParty = false, zoneRaid = false, target = (modeType == "DEBUFF" and "target" or "player"), isCooldown = false, isProc = false, isWeaponText = false, isStackProgress = false, isHideCap = false, isExternalOnly = false, isOwnWindow = false, isSummonObject = false, customSize = 24, color = GetDefaultColor() }
local function GetActiveIndex() return _G[globalSelectedIndexRef] end
local function SetActiveIndex(val) _G[globalSelectedIndexRef] = val end
local currentY = -120
local function AddVerticalCheckbox(label, tText, key)
local cb = CreateFrame("CheckButton", nil, sChild, "InterfaceOptionsCheckButtonTemplate") cb:SetPoint("TOPLEFT", 8, currentY) cb:SetScale(0.9)
local t = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal") t:SetPoint("LEFT", cb, "RIGHT", 5, 1) t:SetText(textColor..label.."|r")
cb:SetScript("OnClick", function(self) local idx = GetActiveIndex() local val = self:GetChecked() and true or false if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx][key] = val CheckAllAuras() else tempConfig[key] = val end end)
SetTooltip(cb, tText) currentY = currentY - 26 return cb
end
cbCombat   = AddVerticalCheckbox("Включать только в бою", "Показывать предупреждение исключительно в бою.", "onlyInCombat")
cbWorld    = AddVerticalCheckbox("Отслеживать в открытом мире (соло)", "Проверять условия в открытых локациях.", "zoneWorld")
cbParty    = AddVerticalCheckbox("Отслеживать в подземельях (5 тел)", "Проверять условия в инстах на 5 человек.", "zoneParty")
cbRaid     = AddVerticalCheckbox("Отслеживать в рейдовых зонах", "Проверять условия внутри рейдовых подземелий.", "zoneRaid")
cbCooldown = AddVerticalCheckbox("Отслеживать готовность КД", "Строгая проверка готовности кулатауна кнопки, игнорируя наличие баффа.", "isCooldown")
cbProc     = AddVerticalCheckbox("Это прок (активен до траты)", "Оповещение будет гореть постоянно, пока эффект присутствует на персонаже.", "isProc")
cbWeapon   = AddVerticalCheckbox("Чары инженерии / оружия", "Сканировать внутренние проки оружия, чар и инженерных гаджетов.", "isWeaponText")
cbProgress = AddVerticalCheckbox("Показывать набор стаков", "Выводить на экран текущий набор стаков, например (2/5).", "isStackProgress")
cbHideCap  = AddVerticalCheckbox("Скрыть при полном капе стаков", "Прятать текст оповещения, когда набран максимальный кап стаков.", "isHideCap")
cbExternal = AddVerticalCheckbox("Внешняя аура (Только чужие)", "Аддон молчит, но как только КТО-ТО ДРУГОЙ наложит на вас этот эффект — выведет сообщение.", "isExternalOnly")
cbSummon   = AddVerticalCheckbox("Это призыв (Тотем/Горгулья)", "Включает перехват физических объектов в мире. Текст будет гореть на экране, пока объект существует.", "isSummonObject")
currentY = currentY - 15
specSlider = CreateFrame("Slider", "RAY_VSlider" .. panelName, sChild, "OptionsSliderTemplate") specSlider:SetSize(180, 16) specSlider:SetPoint("TOPLEFT", 12, currentY) specSlider:SetMinMaxValues(12, 48) specSlider:SetValueStep(1)
local ssText = specSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") ssText:SetPoint("BOTTOMLEFT", specSlider, "TOPLEFT", 0, 4)
specSlider:SetScript("OnValueChanged", function(self, value)
local val = math.floor(value)
ssText:SetText("Размер шрифта: " .. val)
local idx = GetActiveIndex()
if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx].customSize = val CheckAllAuras() else tempConfig.customSize = val end
end)
local rowY = currentY - 40
cbOwnWindow = CreateFrame("CheckButton", "RAY_OwnWinCheck" .. panelName, sChild, "InterfaceOptionsCheckButtonTemplate") cbOwnWindow:SetSize(26, 26) cbOwnWindow:SetPoint("TOPLEFT", sChild, "TOPLEFT", 12, rowY)
local cbTextObj = _G[cbOwnWindow:GetName() .. "Text"] if cbTextObj then cbTextObj:SetText(textColor .. "Окно|r") cbTextObj:ClearAllPoints() cbTextObj:SetPoint("LEFT", cbOwnWindow, "RIGHT", 4, 1) end
cbOwnWindow:SetScript("OnClick", function(self) local idx = GetActiveIndex() local val = self:GetChecked() and true or false if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx].isOwnWindow = val CheckAllAuras() else tempConfig.isOwnWindow = val end end)
SetTooltip(cbOwnWindow, "Вывести данное оповещение в отдельное независимое окно.")
colorBtn:SetSize(18, 18) colorBtn:SetPoint("TOPLEFT", sChild, "TOPLEFT", 200, rowY - 2)
local cTex = colorBtn:CreateTexture(nil, "BACKGROUND") cTex:SetAllPoints() cTex:SetTexture(0.5, 0.95, 0.8) colorBtn.tex = cTex
local border = colorBtn:CreateTexture(nil, "BORDER") border:SetPoint("TOPLEFT", -1, 1) border:SetPoint("BOTTOMRIGHT", 1, -1) border:SetTexture(0.5, 0.5, 0.5, 0.8)
local colorLbl = colorBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") colorLbl:SetPoint("LEFT", colorBtn, "RIGHT", 6, 1) colorLbl:SetText("Палитра")
local defaultColorBtn = CreateFrame("Button", nil, sChild, "UIPanelButtonTemplate") defaultColorBtn:SetSize(140, 18) defaultColorBtn:SetPoint("LEFT", colorLbl, "RIGHT", 12, 0) defaultColorBtn:SetText("Цвет по умолчанию")
SetTooltip(defaultColorBtn, "Вернуть исходный базовый цвет для этой надписи.")
currentY = rowY - 42
editTime = CreateBlizzardEditBox(sChild, 12, currentY, 110, "RAY_VTimeBox"..panelName)
local etText = sChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") etText:SetPoint("BOTTOMLEFT", editTime, "TOPLEFT", 0, 4) etText:SetText("Порог времени (сек):")
editTime:SetScript("OnTextChanged", function(self)
local txt = self:GetText() or "0"
local val = tonumber(txt) or 0
local idx = GetActiveIndex()
if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx].alertTime = val CheckAllAuras() else tempConfig.alertTime = val end
end)
sliderStacks = CreateFrame("Slider", "RAY_VStk"..panelName, sChild, "OptionsSliderTemplate") sliderStacks:SetSize(110, 16) sliderStacks:SetPoint("TOPLEFT", sChild, "TOPLEFT", 200, currentY) sliderStacks:SetMinMaxValues(0, 10) sliderStacks:SetValueStep(1)
local ssText2 = sliderStacks:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") ssText2:SetPoint("BOTTOMLEFT", sliderStacks, "TOPLEFT", 0, 4)
sliderStacks:SetScript("OnValueChanged", function(self, value) local val = math.floor(value) ssText2:SetText("Порог стаков: " .. val) local idx = GetActiveIndex() if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx].minStacks = val CheckAllAuras() else tempConfig.minStacks = val end end)
currentY = currentY - 40
local listHeader = sChild:CreateFontString(nil, "OVERLAY", "GameFontNormal") listHeader:SetPoint("TOPLEFT", 8, currentY) listHeader:SetText(PASTEL_GRAY .. "Список сохраненных настроек:|r")
currentY = currentY - 24
local listFrame = CreateFrame("Frame", nil, sChild) listFrame:SetSize(320, 200) listFrame:SetPoint("TOPLEFT", sChild, "TOPLEFT", 8, currentY)
local function LocalUpdateLists()
for _, b in ipairs(_G[listButtonsRef]) do b:Hide() b:SetText("") end local count = 1
for i = 1, #RAY_Config.spells do
local spellData = RAY_Config.spells[i]
if spellData and spellData.mode == modeType then
local buttonsList = _G[listButtonsRef] local btn = buttonsList[count]
if not btn then
btn = CreateFrame("Button", nil, listFrame) btn:SetSize(280, 22) btn:SetNormalFontObject("GameFontNormal") btn:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight")
local del = CreateFrame("Button", nil, btn, "UIPanelCloseButton") del:SetSize(20, 20) del:SetPoint("RIGHT", btn, "RIGHT", -2, 0) btn.delBtn = del
btn:SetScript("OnClick", function(self)
if isSelfUpdating then return end
SetActiveIndex(self.spellIndex) for _, b in ipairs(_G[listButtonsRef]) do b:UnlockHighlight() end self:LockHighlight()
if RAY_Config.spells[self.spellIndex] then
local data = RAY_Config.spells[self.spellIndex]
isSelfUpdating = true
editBox:SetText(tostring(data.name or "")) UIDropDownMenu_SetSelectedValue(dropDown, data.target or "player") UIDropDownMenu_SetText(dropDown, data.target == "target" and "Цель: Тек. цель" or "Цель: Игрок")
editTime:SetText(tostring(data.alertTime or 0)) sliderStacks:SetValue(data.minStacks or 0) cbCombat:SetChecked(data.onlyInCombat == true) cbWorld:SetChecked(data.zoneWorld == true) cbParty:SetChecked(data.zoneParty == true) cbRaid:SetChecked(data.zoneRaid == true) cbCooldown:SetChecked(data.isCooldown == true) cbProc:SetChecked(data.isProc == true) cbWeapon:SetChecked(data.isWeaponText == true) cbProgress:SetChecked(data.isStackProgress == true) cbHideCap:SetChecked(data.isHideCap == true) cbExternal:SetChecked(data.isExternalOnly == true) cbSummon:SetChecked(data.isSummonObject == true) cbOwnWindow:SetChecked(data.isOwnWindow == true) specSlider:SetValue(data.customSize or 24)
colorBtn.tex:SetVertexColor(data.color.r, data.color.g, data.color.b) tempConfig.color = { r = data.color.r, g = data.color.g, b = data.color.b }
isSelfUpdating = false
end
end)
btn.delBtn:SetScript("OnClick", function(self)
local p = self:GetParent() table.remove(RAY_Config.spells, p.spellIndex) SetActiveIndex(nil)
isSelfUpdating = true
editBox:SetText("") editTime:SetText("0") sliderStacks:SetValue(0) specSlider:SetValue(24) cbCombat:SetChecked(false) cbWorld:SetChecked(false) cbParty:SetChecked(false) cbRaid:SetChecked(false) cbCooldown:SetChecked(false) cbProc:SetChecked(false) cbWeapon:SetChecked(false) cbProgress:SetChecked(false) cbHideCap:SetChecked(false) cbExternal:SetChecked(false) cbSummon:SetChecked(false) cbOwnWindow:SetChecked(false) colorBtn.tex:SetVertexColor(0.5, 0.95, 0.8) UIDropDownMenu_SetSelectedValue(dropDown, modeType == "DEBUFF" and "target" or "player") UIDropDownMenu_SetText(dropDown, modeType == "DEBUFF" and "Цель: Тек. цель" or "Цель: Игрок")
isSelfUpdating = false
RebuildSpellsLookup() updateSpellLists() CheckAllAuras()
end)
buttonsList[count] = btn
end
btn.spellIndex = i btn:ClearAllPoints() btn:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, -((count - 1) * 26))
local rawName = tostring(spellData.name):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
local cleanName = string.match(rawName, "[^|/]+") or "Пусто"
local itemColor = spellData.color or GetDefaultColor()
local r = math.max(0, math.min(255, math.floor(itemColor.r * 255)))
local g = math.max(0, math.min(255, math.floor(itemColor.g * 255)))
local b = math.max(0, math.min(255, math.floor(itemColor.b * 255)))
btn:SetText(string.format("|cff%02x%02x%02x%s|r", r, g, b, cleanName)) btn:Show() if GetActiveIndex() == i then btn:LockHighlight() else btn:UnlockHighlight() end count = count + 1
end
end
sChild:SetHeight(math.max(1000, math.abs(currentY) + (count * 26) + 50))
end
local function ColorCallback()
local r, g, b = ColorPickerFrame:GetColorRGB() colorBtn.tex:SetVertexColor(r, g, b) local idx = GetActiveIndex() if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx].color = { r = r, g = g, b = b } end tempConfig.color = { r = r, g = g, b = b } CheckAllAuras() LocalUpdateLists()
end
colorBtn:SetScript("OnClick", function() local idx = GetActiveIndex() local current = (idx and RAY_Config.spells[idx] and RAY_Config.spells[idx].color) or tempConfig.color or GetDefaultColor() ColorPickerFrame.func = ColorCallback ColorPickerFrame.hasOpacity = false ColorPickerFrame:SetColorRGB(current.r, current.g, current.b) ColorPickerFrame:SetFrameStrata("TOOLTIP") ColorPickerFrame:Hide() ColorPickerFrame:Show() end)
defaultColorBtn:SetScript("OnClick", function() local def = GetDefaultColor() colorBtn.tex:SetVertexColor(def.r, def.g, def.b) local idx = GetActiveIndex() if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx].color = { r = def.r, g = def.g, b = def.b } end tempConfig.color = { r = def.r, g = def.g, b = def.b } CheckAllAuras() LocalUpdateLists() end)
btnOk:SetScript("OnClick", function()
local txt = editBox:GetText() if not txt or txt == "" or txt == " " then return end local idx = GetActiveIndex() local cR, cG, cB = colorBtn.tex:GetVertexColor() local finalColor = { r = cR, g = cG, b = cB } local selectedVal = UIDropDownMenu_GetSelectedValue(dropDown) or tempConfig.target
local item = { name = txt, mode = modeType, target = selectedVal, minStacks = math.floor(sliderStacks:GetValue()), alertTime = tonumber(editTime:GetText()) or 0, onlyInCombat = cbCombat:GetChecked() and true or false, zoneWorld = cbWorld:GetChecked() and true or false, zoneParty = cbParty:GetChecked() and true or false, zoneRaid = cbRaid:GetChecked() and true or false, isCooldown = cbCooldown:GetChecked() and true or false, isProc = cbProc:GetChecked() and true or false, isWeaponText = cbWeapon:GetChecked() and true or false, isStackProgress = cbProgress:GetChecked() and true or false, isHideCap = cbHideCap:GetChecked() and true or false, isExternalOnly = cbExternal:GetChecked() and true or false, isSummonObject = cbSummon:GetChecked() and true or false, isOwnWindow = cbOwnWindow:GetChecked() and true or false, customSize = math.floor(specSlider:GetValue()), color = finalColor }
if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx] = item else table.insert(RAY_Config.spells, item) end
isSelfUpdating = true
SetActiveIndex(nil) editBox:SetText("") editTime:SetText("0") sliderStacks:SetValue(0) specSlider:SetValue(24) cbCombat:SetChecked(false) cbWorld:SetChecked(false) cbParty:SetChecked(false) cbRaid:SetChecked(false) cbCooldown:SetChecked(false) cbProc:SetChecked(false) cbWeapon:SetChecked(false) cbProgress:SetChecked(false) cbHideCap:SetChecked(false) cbExternal:SetChecked(false) cbSummon:SetChecked(false) cbOwnWindow:SetChecked(false) colorBtn.tex:SetVertexColor(0.5, 0.95, 0.8) UIDropDownMenu_SetSelectedValue(dropDown, modeType == "DEBUFF" and "target" or "player") UIDropDownMenu_SetText(dropDown, modeType == "DEBUFF" and "Цель: Тек. цель" or "Цель: Игрок")
isSelfUpdating = false
RebuildSpellsLookup() CheckAllAuras() LocalUpdateLists() if updateSpellLists then updateSpellLists() end
end)
panel:HookScript("OnShow", function()
if isSelfUpdating then return end
isSelfUpdating = true
SetActiveIndex(nil) editBox:SetText("") editTime:SetText("0") sliderStacks:SetValue(0) specSlider:SetValue(24) cbCombat:SetChecked(false) cbWorld:SetChecked(false) cbParty:SetChecked(false) cbRaid:SetChecked(false) cbCooldown:SetChecked(false) cbProc:SetChecked(false) cbWeapon:SetChecked(false) cbProgress:SetChecked(false) cbHideCap:SetChecked(false) cbExternal:SetChecked(false) cbSummon:SetChecked(false) cbOwnWindow:SetChecked(false) colorBtn.tex:SetVertexColor(0.5, 0.95, 0.8) UIDropDownMenu_SetSelectedValue(dropDown, modeType == "DEBUFF" and "target" or "player") UIDropDownMenu_SetText(dropDown, modeType == "DEBUFF" and "Цель: Тек. цель" or "Цель: Игрок") LocalUpdateLists()
isSelfUpdating = false
end)
InterfaceOptions_AddCategory(panel) return LocalUpdateLists
end
_G["selBuffIdxG"], _G["selDebIdxG"] = nil, nil
_G["listBtnBufG"], _G["listBtnDebG"] = listButtonsBuff, listButtonsDebuff
local updateBuffs = BuildVerticalAuraPage("RAY-buffs", "BUFF", PASTEL_BUFF, "selBuffIdxG", "listBtnBufG")
local updateDebuffs = BuildVerticalAuraPage("RAY-debuffs", "DEBUFF", PASTEL_DEBUFF, "selDebIdxG", "listBtnDebG")
updateSpellLists = function() updateBuffs() updateDebuffs() end
setsPanel = CreateFrame("Frame", "RAY_Panel_Sets", optionsPanel)
setsPanel.name = "RAY-sets" setsPanel.parent = "RAY"
local mainScroll = CreateFrame("ScrollFrame", "RAY_SetsScrollFrame", setsPanel, "UIPanelScrollFrameTemplate")
mainScroll:SetPoint("TOPLEFT", 8, -40) mainScroll:SetPoint("BOTTOMRIGHT", -28, 8)
local scrollChild = CreateFrame("Frame", nil, mainScroll)
scrollChild:SetSize(380, 1700) mainScroll:SetScrollChild(scrollChild)
local subTitle = setsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
subTitle:SetPoint("TOPLEFT", 16, -14) subTitle:SetText(PASTEL_TITLE .. "Автоматика Спеков, Стоек и Комплектов Экипировки|r")
local function SubButton_OnClick(self)
local data = RAY_Config.specSettings[self.specNum][self.storageKey][self.itemIndex]
if type(data) == "table" then
self.activeIndices[self.storageKey] = self.itemIndex
for _, b in ipairs(listButtonsSub[self.specNum][self.storageKey]) do b:UnlockHighlight() end
self:LockHighlight()
if self.isIcd then
if self.boxName then self.boxName:SetText(data.name or "") end
if self.boxSec then self.boxSec:SetText(data.seconds or "45/5") end
else
if self.editBox then self.editBox:SetText(data.name or "") end
end
self.cbCombat:SetChecked(data.onlyInCombat == true) self.cbWorld:SetChecked(data.zoneWorld == true) self.cbParty:SetChecked(data.zoneParty == true) self.cbRaid:SetChecked(data.zoneRaid == true)
end
end
local function SubDeleteButton_OnClick(self)
local parent = self:GetParent() table.remove(RAY_Config.specSettings[parent.specNum][parent.storageKey], parent.itemIndex)
parent.activeIndices[parent.storageKey] = nil
if parent.isIcd then
if parent.boxName then parent.boxName:SetText("") end
if parent.boxSec then parent.boxSec:SetText("") end
else
if parent.editBox then parent.editBox:SetText("") end
end
RefreshLocalSubList(parent.specNum, parent.storageKey) CheckAllAuras()
end
RefreshLocalSubList = function(specNum, storageKey)
local pBlock = listButtonsSub[specNum][storageKey]
for _, b in ipairs(pBlock) do b:Hide() end
if not RAY_Config or not RAY_Config.specSettings or not RAY_Config.specSettings[specNum] or not RAY_Config.specSettings[specNum][storageKey] then return end
for idx, data in ipairs(RAY_Config.specSettings[specNum][storageKey]) do
local isIcd = (storageKey == "icds")
local textStr = type(data) == "table" and ((data.name or "Ошибка") .. (isIcd and (" ("..(data.seconds or "45/5").."s)") or "")) or tostring(data)
local btn = pBlock[idx]
if not btn then
btn = CreateFrame("Button", nil, pBlock.listFrame) btn:SetSize(280, 22) btn:SetNormalFontObject("GameFontNormal") btn:SetHighlightTexture("Interface\\Buttons\UI-Listbox-Highlight")
local del = CreateFrame("Button", nil, btn, "UIPanelCloseButton") del:SetSize(20, 20) del:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
btn.del = del pBlock[idx] = btn
end
btn.specNum = specNum btn.storageKey = storageKey btn.itemIndex = idx btn.isIcd = isIcd btn.activeIndices = pBlock.activeIndices btn.boxName = pBlock.boxName btn.boxSec = pBlock.boxSec btn.editBox = pBlock.editBox btn.cbCombat = pBlock.cbCombat btn.cbWorld = pBlock.cbWorld btn.cbParty = pBlock.cbParty btn.cbRaid = pBlock.cbRaid
btn:SetScript("OnClick", SubButton_OnClick) btn.del:SetScript("OnClick", SubDeleteButton_OnClick)
btn:ClearAllPoints() btn:SetPoint("TOPLEFT", 0, -((idx - 1) * 24)) btn:SetText(textStr) btn:Show()
if pBlock.activeIndices[storageKey] == idx then btn:LockHighlight() else btn:UnlockHighlight() end
end
end
local function CreateSubPageBlock(specNum, startY, headerColorCode, specTitle)
local hOffsetSub = 8
local activeIndices = { sets = nil, buffs = nil, icds = nil }
local blockHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
blockHeader:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", hOffsetSub, startY) blockHeader:SetText(headerColorCode..specTitle.."|r")
local function BuildInputFieldBlock(labelTxt, storageKey, tText, isIcd, blockOffsetIndex)
local blockTopY = startY - 30 - (blockOffsetIndex * 240)
local container = CreateFrame("Frame", "RAY_Spec" .. specNum .. "Block" .. storageKey, scrollChild)
container:SetSize(360, 230) container:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", hOffsetSub, blockTopY)
local editBox, boxName, boxSec
if isIcd then
boxName = CreateBlizzardEditBox(container, 0, -25, 160, "RAY_SIcdN"..specNum..""..storageKey) SetTooltip(boxName, tText)
boxSec = CreateBlizzardEditBox(container, 175, -25, 65, "RAY_SIcdS"..specNum..""..storageKey) boxSec:SetMaxLetters(10)
editBox = boxName
else
editBox = CreateBlizzardEditBox(container, 0, -25, 220, "RAY_SInp"..specNum..""..storageKey) SetTooltip(editBox, tText)
end
local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 2, 6) label:SetText(headerColorCode .. labelTxt .. "|r")
local btnOk = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
btnOk:SetSize(45, 24) btnOk:SetPoint("LEFT", isIcd and boxSec or editBox, "RIGHT", 8, 0) btnOk:SetText(PASTEL_YELLOW.."ОК|r")
-- Добавление текстовой подсказки формата секунд трини
if isIcd then
local helperText = container:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
helperText:SetPoint("TOPLEFT", boxSec, "BOTTOMLEFT", 0, -4)
helperText:SetText("Формат: ВнутрКД / ОкноЗамера (напр. 45/5)")
end
local function CreateSubCheckbox(lbl, innerY, key)
local cb = CreateFrame("CheckButton", nil, container, "InterfaceOptionsCheckButtonTemplate")
cb:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -innerY) cb:SetScale(0.85)
local t = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
t:SetPoint("LEFT", cb, "RIGHT", 5, 1) t:SetText(headerColorCode .. lbl .. "|r")
cb:SetScript("OnClick", function(self)
if RAY_Config and RAY_Config.specSettings and RAY_Config.specSettings[specNum] and RAY_Config.specSettings[specNum][storageKey] then
local idx = activeIndices[storageKey]
if idx and RAY_Config.specSettings[specNum][storageKey][idx] then
RAY_Config.specSettings[specNum][storageKey][idx][key] = self:GetChecked() and true or false
CheckAllAuras()
end
end
end)
return cb
end
local cbCombat = CreateSubCheckbox("Включать только в бою", 55, "onlyInCombat")
local cbWorld = CreateSubCheckbox("В открытом мире", 80, "zoneWorld")
local cbParty = CreateSubCheckbox("В подземельях", 105, "zoneParty")
local cbRaid = CreateSubCheckbox("В рейдовых зонах", 130, "zoneRaid")
local listFrame = CreateFrame("Frame", nil, container)
listFrame:SetSize(280, 85) listFrame:SetPoint("TOPLEFT", editBox, "TOPLEFT", 2, -165)
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
local itemData = { name = txt, seconds = isIcd and (boxSec:GetText() or "45/5") or nil, onlyInCombat = cbCombat:GetChecked() and true or false, zoneWorld = cbWorld:GetChecked() and true or false, zoneParty = cbParty:GetChecked() and true or false, zoneRaid = cbRaid:GetChecked() and true or false }
if activeIdx and RAY_Config.specSettings[specNum][storageKey][activeIdx] then RAY_Config.specSettings[specNum][storageKey][activeIdx] = itemData else table.insert(RAY_Config.specSettings[specNum][storageKey], itemData) end
activeIndices[storageKey] = nil
if isIcd then
if boxName then boxName:SetText("") end
if boxSec then boxSec:SetText("") end
else
if editBox then editBox:SetText("") end
end
cbCombat:SetChecked(false) cbWorld:SetChecked(false) cbParty:SetChecked(false) cbRaid:SetChecked(false)
RefreshLocalSubList(specNum, storageKey) CheckAllAuras()
end)
end
BuildInputFieldBlock("Комплект экипировки:", "sets", "Название вашего комплекта экипировки in-game.", false, 0)
BuildInputFieldBlock("Стойка / Бафф:", "buffs", "Обязательная aura или боевая стойка класса.", false, 1)
BuildInputFieldBlock("Прок триньки / КД:", "icds", "Формат: КД/ОкноПоказа (например, 45/5)", true, 2)
end
CreateSubPageBlock(1, -15, COLOR_SPEC1, "ПЕРВАЯ ВЕТКА (СПЕК 1)")
CreateSubPageBlock(2, -775, COLOR_SPEC2, "ВТОРАЯ ВЕТКА (СПЕК 2)")
setsPanel:HookScript("OnShow", function()
RefreshLocalSubList(1, "sets") RefreshLocalSubList(1, "buffs") RefreshLocalSubList(1, "icds")
RefreshLocalSubList(2, "sets") RefreshLocalSubList(2, "buffs") RefreshLocalSubList(2, "icds")
end)
InterfaceOptions_AddCategory(setsPanel)
updateSpellLists()
end)
local loginCheck = CreateFrame("Frame")
loginCheck:RegisterEvent("PLAYER_LOGIN")
loginCheck:SetScript("OnEvent", function()
if type(RebuildSpellsLookup) == "function" then RebuildSpellsLookup() end
if type(CheckAllAuras) == "function" then CheckAllAuras() end
end)
SLASH_RAY1 = "/ray"
SlashCmdList["RAY"] = function(msg)
if optionsPanel then
InterfaceOptionsFrame_OpenToCategory(optionsPanel)
InterfaceOptionsFrame_OpenToCategory(optionsPanel)
end
end
SLASH_RAYMOVE1 = "/raymove"
SlashCmdList["RAYMOVE"] = function()
local nextMoveState = not RAY_MainFrame:IsMouseEnabled()
ToggleRayMove(nextMoveState)
if nextMoveState then
DEFAULT_CHAT_FRAME:AddMessage("|cff4ECCA3[RAY]:|r Режим перемещения окон |cffA8FF35ВКЛЮЧЕН|r. Наберите /raymove чтобы зафиксировать окна.")
else
DEFAULT_CHAT_FRAME:AddMessage("|cff4ECCA3[RAY]:|r Режим перемещения окон |cffFF7676ВЫКЛЮЧЕН|r. Все окна зафиксированы.")
end
end