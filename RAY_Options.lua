local shortcutFrame = CreateFrame("Frame")
local isSelfUpdating = false
local dragCbGlobal

local function CreateBlizzardEditBox(parent, x, y, width, name)
    local eb = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    eb:SetSize(width, 24) eb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y) eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal") eb:SetTextInsets(4, 4, 0, 0)
    return eb
end

local function SetTooltip(widget, uText)
    widget:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT") GameTooltip:SetText(uText, 1, 1, 1, nil, true) GameTooltip:Show() end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function ToggleRayMove(enable)
    if RAY_Config and enable and not RAY_Config.enabled then RAY_Config.enabled = true end
    local mainText = _G["RAY_MainFrameText"]
    if enable then
        if RAY_Engine.frame then RAY_Engine.frame:EnableMouse(true) end
        if RAY_Engine.dragBg then RAY_Engine.dragBg:Show() end
        if RAY_Engine.dragBorder then RAY_Engine.dragBorder:Show() end 
        if mainText then mainText:SetText(PASTEL_TITLE .. "[RAY]: Главное окно|r") end
        if RAY_Engine.frame and not RAY_Engine.frame:IsShown() then RAY_Engine.frame:Show() end
        
        local currentSpec = GetActiveTalentGroup() or 1
        local spells = RAY_Config.specSettings[currentSpec] and RAY_Config.specSettings[currentSpec].spells
        if spells then
            for i = 1, #spells do
                local spellData = spells[i]
                if spellData and spellData.name ~= "" and spellData.isOwnWindow then
                    local cf = GetOrCreateCustomFrame(spellData.name)
                    cf:EnableMouse(true) cf.bg:Show() cf.border:Show()
                    if cf.labelString then
                        cf.labelString:SetText("[Окно]: " .. (tostring(spellData.name):match("[^|/]+") or spellData.name))
                        cf.labelString:SetFont("Fonts\\FRIZQT__.TTF", spellData.customSize or 24, "OUTLINE")
                    end
                    local fKey = RAY_Engine.GetFrameKey(spellData.name)
                    if RAY_Config.customFramePositions and RAY_Config.customFramePositions[fKey] then 
                        local pos = RAY_Config.customFramePositions[fKey] 
                        cf:ClearAllPoints() cf:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y) 
                    end
                    if not cf:IsShown() then cf:Show() end
                end
            end
        end
    else
        if RAY_Engine.frame then RAY_Engine.frame:EnableMouse(false) end
        if RAY_Engine.dragBg then RAY_Engine.dragBg:Hide() end
        if RAY_Engine.dragBorder then RAY_Engine.dragBorder:Hide() end
        if mainText then mainText:SetText("") end 
        if RAY_Engine.frame then RAY_Engine.frame:Hide() end
        
        local currentSpec = GetActiveTalentGroup() or 1
        local spells = RAY_Config.specSettings[currentSpec] and RAY_Config.specSettings[currentSpec].spells
        if spells then
            for i = 1, #spells do
                local spellData = spells[i]
                if spellData and spellData.name then
                    local fKey = RAY_Engine.GetFrameKey(spellData.name)
                    local cf = RAY_Engine.customFramesPool[fKey]
                    if cf then cf:EnableMouse(false) cf.bg:Hide() cf.border:Hide() cf.labelString:SetText("") cf:Hide() end
                end
            end
        end
        if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end
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
    mainCb:SetScript("OnClick", function(self) RAY_Config.enabled = self:GetChecked() and true or false if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end end)
    SetTooltip(mainCb, "Глобальное включение или выключение работы аддона.")

    local dragCb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate") dragCb:SetPoint("TOPLEFT", 16, -95)
    local dragCbText = dragCb:CreateFontString(nil, "OVERLAY", "GameFontNormal") dragCbText:SetPoint("LEFT", dragCb, "RIGHT", 5, 1) dragCbText:SetText(PASTEL_YELLOW .. "Move|r")
    dragCbGlobal = dragCb
    dragCb:SetScript("OnShow", function(self) self:SetChecked(RAY_Engine.frame and RAY_Engine.frame:IsMouseEnabled() or false) end)
    dragCb:SetScript("OnClick", function(self) ToggleRayMove(self:GetChecked()) end)
    SetTooltip(dragCb, "Включает сетку перемещения главного и независимых окон аур. Перетаскивайте мышкой.")

    local radarCb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate") radarCb:SetPoint("TOPLEFT", 16, -135)
    local radarCbText = radarCb:CreateFontString(nil, "OVERLAY", "GameFontNormal") radarCbText:SetPoint("LEFT", radarCb, "RIGHT", 5, 1) radarCbText:SetText(PASTEL_DEBUFF .. "RAY-Radar|r")
    radarCb:SetScript("OnShow", function(self) self:SetChecked(RAY_Config.radarEnabled) end) radarCb:SetScript("OnClick", function(self) RAY_Config.radarEnabled = self:GetChecked() end)
    SetTooltip(radarCb, "Выводит в чат очищенную информацию о заклинаниях и их ID для удобства копирования.")

    local hunterCb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate") hunterCb:SetPoint("TOPLEFT", 16, -175)
    local hunterCbText = hunterCb:CreateFontString(nil, "OVERLAY", "GameFontNormal") hunterCbText:SetPoint("LEFT", hunterCb, "RIGHT", 5, 1) hunterCbText:SetText(PASTEL_BUFF .. "Box Detector|r")
    hunterCb:SetScript("OnShow", function(self) self:SetChecked(RAY_Config.boxHunterEnabled) end) hunterCb:SetScript("OnClick", function(self) RAY_Config.boxHunterEnabled = self:GetChecked() RAY_Engine.sylvanasAlertActive = false if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end end)
    SetTooltip(hunterCb, "Автоматическое обнаружение активации Музыкальной Шкатулки Сильваны в рейде.")

    local cpCb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate") cpCb:SetPoint("TOPLEFT", 16, -215)
    local cpCbText = cpCb:CreateFontString(nil, "OVERLAY", "GameFontNormal") cpCbText:SetPoint("LEFT", cpCb, "RIGHT", 5, 1) cpCbText:SetText("|cffFFD369Отслеживать Комбо-Поинты (КП)|r")
    cpCb:SetScript("OnShow", function(self) self:SetChecked(RAY_Config.comboTrackerEnabled == true) end)
    cpCb:SetScript("OnClick", function(self) RAY_Config.comboTrackerEnabled = self:GetChecked() and true or false if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end end)
    SetTooltip(cpCb, "Выводит яркое предупреждение о накоплении Комбо-Поинтов на вашей текущей цели.")

    local cpSlider = CreateFrame("Slider", "RAY_MainComboSlider", optionsPanel, "OptionsSliderTemplate") cpSlider:SetSize(180, 16) cpSlider:SetPoint("TOPLEFT", 40, -255) cpSlider:SetMinMaxValues(1, 5) cpSlider:SetValueStep(1)
    local cpSliderText = cpSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") cpSliderText:SetPoint("BOTTOMLEFT", cpSlider, "TOPLEFT", 0, 4)
    cpSlider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value) cpSliderText:SetText("Целевой порог КП: " .. val)
        if RAY_Config then RAY_Config.comboTrackerLimit = val if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end end
    end)
    cpSlider:SetScript("OnShow", function(self)
        if not RAY_Config.comboTrackerLimit then RAY_Config.comboTrackerLimit = 5 end
        self:SetValue(RAY_Config.comboTrackerLimit) cpSliderText:SetText("Целевой порог КП: " .. RAY_Config.comboTrackerLimit)
    end)
    SetTooltip(cpSlider, "Задает количество КП, при достижении которого начнется оповещение (например, 5 КП).")

    local btnClear = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate") btnClear:SetSize(140, 30) btnClear:SetPoint("TOPLEFT", 16, -305) btnClear:SetText("|cffFF7676Полный сброс|r")
    btnClear:SetScript("OnClick", function() RAY_Config = nil ReloadUI() end)
    SetTooltip(btnClear, "Полная очистка базы данных SavedVariables и перезагрузка интерфейса.")
    
    InterfaceOptions_AddCategory(optionsPanel)
    
    local function BuildVerticalAuraPage(panelName, modeType, textColor, globalSelectedIndexRef, listButtonsRef)
        local panel = CreateFrame("Frame", "RAY_Panel_"..panelName, optionsPanel) panel.name = panelName panel.parent = "RAY"
        local sFrame = CreateFrame("ScrollFrame", "RAY_Scroll_"..panelName, panel, "UIPanelScrollFrameTemplate") sFrame:SetPoint("TOPLEFT", 8, -40) sFrame:SetPoint("BOTTOMRIGHT", -28, 8)
        local sChild = CreateFrame("Frame", nil, sFrame) sChild:SetSize(380, 1050) sFrame:SetScrollChild(sChild)
        local pTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") pTitle:SetPoint("TOPLEFT", 16, -14) pTitle:SetText(textColor.."Управление отслеживанием: "..panelName.."|r")
        local editBox = CreateBlizzardEditBox(sChild, 8, -30, 240, "RAY_EBox_"..panelName)
        local elabel = sChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") elabel:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 2, 6) elabel:SetText("Название эффекта / ID способности:")
local btnOk = CreateFrame("Button", nil, sChild, "UIPanelButtonTemplate") btnOk:SetSize(55, 25) btnOk:SetPoint("LEFT", editBox, "RIGHT", 8, 0) btnOk:SetText(PASTEL_YELLOW.."ОК|r")
SetTooltip(btnOk, "Сохранить ауру в текущий активный спек.")
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
local tempConfig = { onlyInCombat = false, zoneWorld = false, zoneParty = false, zoneRaid = false, target = (modeType == "DEBUFF" and "target" or "player"), isCooldown = false, isProc = false, isWeaponText = false, isStackProgress = false, isHideCap = false, isExternalOnly = false, isOwnWindow = false, isSummonObject = false, customSize = 24, color = { r = 0.5, g = 0.95, b = 0.8 } }
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
SetTooltip(colorBtn, "Открыть палитьру цветов для текста этого алерта.")
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
btn = CreateFrame("Button", nil, listFrame) btn:SetSize(280, 22) btn:SetNormalFontObject("GameFontNormal") btn:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight")
local del = CreateFrame("Button", nil, btn, "UIPanelCloseButton") del:SetSize(20, 20) del:SetPoint("RIGHT", btn, "RIGHT", -2, 0) btn.delBtn = del
btn:SetScript("OnClick", function(self)
if isSelfUpdating then return end SetActiveIndex(self.spellIndex) for _, b in ipairs(_G[listButtonsRef]) do b:UnlockHighlight() end self:LockHighlight()
local data = RAY_Config.specSettings[currentSpec].spells[self.spellIndex]
if data then
isSelfUpdating = true
editBox:SetText(tostring(data.name or "")) UIDropDownMenu_SetSelectedValue(dropDown, data.target or "player") UIDropDownMenu_SetText(dropDown, data.target == "target" and "Цель: Тек. цель" or "Цель: Игрок")
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
RAY_Engine.RebuildSpellsLookup() BuildVerticalAuraPage_UpdateAll() if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end
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
if idx and RAY_Config.specSettings[currentSpec].spells[idx] then RAY_Config.specSettings[currentSpec].spells[idx] = item else table.insert(RAY_Config.specSettings[currentSpec].spells, item) end
isSelfUpdating = true SetActiveIndex(nil) editBox:SetText("") editTime:SetText("0") sliderStacks:SetValue(0) specSlider:SetValue(24) cbCombat:SetChecked(false) cbWorld:SetChecked(false) cbParty:SetChecked(false) cbRaid:SetChecked(false) cbCooldown:SetChecked(false) cbProc:SetChecked(false) cbWeapon:SetChecked(false) cbProgress:SetChecked(false) cbHideCap:SetChecked(false) cbExternal:SetChecked(false) cbSummon:SetChecked(false) cbOwnWindow:SetChecked(false) colorBtn.tex:SetVertexColor(0.5, 0.95, 0.8)
isSelfUpdating = false RAY_Engine.RebuildSpellsLookup() if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end LocalUpdateLists() if BuildVerticalAuraPage_UpdateAll then BuildVerticalAuraPage_UpdateAll() end
end)
panel:HookScript("OnShow", function()
if isSelfUpdating then return end isSelfUpdating = true SetActiveIndex(nil) editBox:SetText("") editTime:SetText("0") sliderStacks:SetValue(0) specSlider:SetValue(24) cbCombat:SetChecked(false) cbWorld:SetChecked(false) cbParty:SetChecked(false) cbRaid:SetChecked(false) cbCooldown:SetChecked(false) cbProc:SetChecked(false) cbWeapon:SetChecked(false) cbProgress:SetChecked(false) cbHideCap:SetChecked(false) cbExternal:SetChecked(false) cbSummon:SetChecked(false) cbOwnWindow:SetChecked(false) colorBtn.tex:SetVertexColor(0.5, 0.95, 0.8) LocalUpdateLists() isSelfUpdating = false
end)
InterfaceOptions_AddCategory(panel) return LocalUpdateLists
end
_G["selBuffIdxG"], _G["selDebIdxG"] = nil, nil
_G["listBtnBufG"], _G["listBtnDebG"] = listButtonsBuff, listButtonsDebuff
local updateBuffs = BuildVerticalAuraPage("RAY-buffs", "BUFF", PASTEL_BUFF, "selBuffIdxG", "listBtnBufG")
local updateDebuffs = BuildVerticalAuraPage("RAY-debuffs", "DEBUFF", PASTEL_DEBUFF, "selDebIdxG", "listBtnDebG")
BuildVerticalAuraPage_UpdateAll = function() updateBuffs() updateDebuffs() end
-- ============================================================================
-- ВКЛАДКА СЕТОВ И АВТОМАТИКИ СПЕКОВ
-- ============================================================================
setsPanel = CreateFrame("Frame", "RAY_Panel_Sets", optionsPanel) setsPanel.name = "RAY-sets" setsPanel.parent = "RAY"
local mainScroll = CreateFrame("ScrollFrame", "RAY_SetsScrollFrame", setsPanel, "UIPanelScrollFrameTemplate") mainScroll:SetPoint("TOPLEFT", 8, -40) mainScroll:SetPoint("BOTTOMRIGHT", -28, 8)
local scrollChild = CreateFrame("Frame", nil, mainScroll) scrollChild:SetSize(380, 1700) mainScroll:SetScrollChild(scrollChild)
local subTitle = setsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") subTitle:SetPoint("TOPLEFT", 16, -14) subTitle:SetText(PASTEL_TITLE .. "Автоматика Спеков, Стоек и Комплектов Экипировки|r")
local function SubButton_OnClick(self)
if not RAY_Config.specSettings or not RAY_Config.specSettings[self.specNum] then return end
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
if self.cbInvert then self.cbInvert:SetChecked(data.invert == true) end
if self.cbPet then self.cbPet:SetChecked(data.isPetTracker == true) end
end
end
local function SubDeleteButton_OnClick(self)
local parent = self:GetParent()
table.remove(RAY_Config.specSettings[parent.specNum][parent.storageKey], parent.itemIndex)
parent.activeIndices[parent.storageKey] = nil
if parent.isIcd then parent.boxName:SetText("") parent.boxSec:SetText("") else parent.editBox:SetText("") end
if parent.cbInvert then parent.cbInvert:SetChecked(false) end
if parent.cbPet then parent.cbPet:SetChecked(false) end
RefreshLocalSubList(parent.specNum, parent.storageKey) if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end
end
RefreshLocalSubList = function(specNum, storageKey)
local pBlock = listButtonsSub[specNum][storageKey]
for _, b in ipairs(pBlock) do b:Hide() end
if not RAY_Config or not RAY_Config.specSettings or not RAY_Config.specSettings[specNum] then return end
local dataSpec = RAY_Config.specSettings[specNum][storageKey]
if not dataSpec then return end
for idx, data in ipairs(dataSpec) do
local isIcd = (storageKey == "icds")
local btn = pBlock[idx]
if not btn then
btn = CreateFrame("Button", nil, pBlock.listFrame) btn:SetSize(280, 22) btn:SetNormalFontObject("GameFontNormal") btn:SetHighlightTexture("Interface\\Buttons\UI-Listbox-Highlight")
local del = CreateFrame("Button", nil, btn, "UIPanelCloseButton") del:SetSize(20, 20) del:SetPoint("RIGHT", btn, "RIGHT", -2, 0) btn.del = del pBlock[idx] = btn
end
btn.specNum = specNum btn.storageKey = storageKey btn.itemIndex = idx btn.isIcd = isIcd btn.activeIndices = pBlock.activeIndices btn.boxName = pBlock.boxName btn.boxSec = pBlock.boxSec btn.editBox = pBlock.editBox btn.cbCombat = pBlock.cbCombat btn.cbWorld = pBlock.cbWorld btn.cbParty = pBlock.cbParty btn.cbRaid = pBlock.cbRaid btn.cbInvert = pBlock.cbInvert btn.cbPet = pBlock.cbPet
btn:SetScript("OnClick", SubButton_OnClick) btn.del:SetScript("OnClick", SubDeleteButton_OnClick)
btn:ClearAllPoints() btn:SetPoint("TOPLEFT", 0, -((idx - 1) * 24))
local displayNameText = type(data) == "table" and (data.name or "Ошибка") or tostring(data)
if type(data) == "table" and data.invert then displayNameText = displayNameText .. " [Инверсия]" end
if type(data) == "table" and data.isPetTracker then displayNameText = displayNameText .. " [Питомец]" end
btn:SetText(displayNameText .. (isIcd and (" ("..(data.seconds or "45/5")..")") or "")) btn:Show()
if pBlock.activeIndices[storageKey] == idx then btn:LockHighlight() else btn:UnlockHighlight() end
end
end
local function CreateSubPageBlock(specNum, startY, headerColorCode, specTitle)
local hOffsetSub = 8 local activeIndices = { sets = nil, buffs = nil, icds = nil }
local blockHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") blockHeader:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", hOffsetSub, startY) blockHeader:SetText(headerColorCode..specTitle.."|r")
local function BuildInputFieldBlock(labelTxt, storageKey, tText, isIcd, blockOffsetIndex)
local blockTopY = startY - 30 - (blockOffsetIndex * 260)
local container = CreateFrame("Frame", "RAY_Spec" .. specNum .. "Block" .. storageKey, scrollChild) container:SetSize(360, 250) container:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", hOffsetSub, blockTopY)
local editBox, boxName, boxSec, cbInvert, cbPet
if isIcd then
boxName = CreateBlizzardEditBox(container, 0, -25, 160, "RAY_SIcdN"..specNum..""..storageKey) SetTooltip(boxName, "Введите имя баффа аксессуара.")
boxSec = CreateBlizzardEditBox(container, 175, -25, 60, "RAY_SIcdS"..specNum..""..storageKey) boxSec:SetMaxLetters(12) editBox = boxName
SetTooltip(boxSec, "Формат: ВремяКД/ЗаСколькоПоказать. Например, '45/10'.")
else
editBox = CreateBlizzardEditBox(container, 0, -25, 220, "RAY_SInp"..specNum..""..storageKey) SetTooltip(editBox, tText)
end
local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") label:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 2, 6) label:SetText(headerColorCode .. labelTxt .. "|r")
local btnOk = CreateFrame("Button", nil, container, "UIPanelButtonTemplate") btnOk:SetSize(45, 24) btnOk:SetPoint("LEFT", isIcd and boxSec or editBox, "RIGHT", 8, 0) btnOk:SetText(PASTEL_YELLOW.."ОК|r")
SetTooltip(btnOk, "Сохранить автоматизацию в этот спек.")
local function CreateSubCheckbox(lbl, innerY, key, tooltipText)
local cb = CreateFrame("CheckButton", nil, container, "InterfaceOptionsCheckButtonTemplate") cb:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -innerY) cb:SetScale(0.85)
local t = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") t:SetPoint("LEFT", cb, "RIGHT", 5, 1) t:SetText(headerColorCode .. lbl .. "|r")
cb:SetScript("OnClick", function(self)
if activeIndices[storageKey] and RAY_Config.specSettings[specNum][storageKey][activeIndices[storageKey]] then
RAY_Config.specSettings[specNum][storageKey][activeIndices[storageKey]][key] = self:GetChecked() and true or false if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end
end
end)
SetTooltip(cb, tooltipText)
return cb
end
local cbCombat = CreateSubCheckbox("Включать только в бою", 55, "onlyInCombat", "Проверять это правило только во время ведения боя.")
local cbWorld = CreateSubCheckbox("В открытом мире", 80, "zoneWorld", "Активировать правило в открытом мире.")
local cbParty = CreateSubCheckbox("В подземельях", 105, "zoneParty", "Активировать проверку правила в подземельях на 5 человек.")
local cbRaid = CreateSubCheckbox("В рейдовых зонах", 130, "zoneRaid", "Активировать проверку правила в рейдовых зонах.")
if storageKey == "buffs" then
cbInvert = CreateSubCheckbox("Инвертировать логику", 155, "invert", "Оповещать, если этот бафф/стойка НАХОДИТСЯ на вас (Выдаст алерт 'Сними [Название]').")
cbPet = CreateSubCheckbox("Это питомец", 180, "isPetTracker", "Включите, если это способность призыва питомца (Призыв беса, Воскрешение мертвых). Аддон будет напоминать о призыве, если питомца нет рядом.")
end
local listFrame = CreateFrame("Frame", nil, container) listFrame:SetSize(280, 85) listFrame:SetPoint("TOPLEFT", editBox, "TOPLEFT", 2, -(storageKey == "buffs" and 210 or 165))
listButtonsSub[specNum][storageKey].listFrame = listFrame
listButtonsSub[specNum][storageKey].activeIndices = activeIndices
listButtonsSub[specNum][storageKey].boxName = boxName
listButtonsSub[specNum][storageKey].boxSec = boxSec
listButtonsSub[specNum][storageKey].editBox = editBox
listButtonsSub[specNum][storageKey].cbCombat = cbCombat
listButtonsSub[specNum][storageKey].cbWorld = cbWorld
listButtonsSub[specNum][storageKey].cbParty = cbParty
listButtonsSub[specNum][storageKey].cbRaid = cbRaid
listButtonsSub[specNum][storageKey].cbInvert = cbInvert
listButtonsSub[specNum][storageKey].cbPet = cbPet
btnOk:SetScript("OnClick", function()
local txt = editBox:GetText() if not txt or txt == "" or txt == " " then return end
if not RAY_Config.specSettings then RAY_Config.specSettings = {} end
if not RAY_Config.specSettings[specNum] then RAY_Config.specSettings[specNum] = { spells = {}, sets = {}, buffs = {}, icds = {} } end
local activeIdx = activeIndices[storageKey]
local itemData = { name = txt, seconds = isIcd and (boxSec:GetText() or "45/5") or nil, onlyInCombat = cbCombat:GetChecked() and true or false, zoneWorld = cbWorld:GetChecked() and true or false, zoneParty = cbParty:GetChecked() and true or false, zoneRaid = cbRaid:GetChecked() and true or false, invert = cbInvert and cbInvert:GetChecked() and true or false, isPetTracker = cbPet and cbPet:GetChecked() and true or false }
if activeIdx and RAY_Config.specSettings[specNum][storageKey][activeIdx] then RAY_Config.specSettings[specNum][storageKey][activeIdx] = itemData else table.insert(RAY_Config.specSettings[specNum][storageKey], itemData) end
activeIndices[storageKey] = nil
if isIcd then boxName:SetText("") boxSec:SetText("") else editBox:SetText("") end
cbCombat:SetChecked(false) cbWorld:SetChecked(false) cbParty:SetChecked(false) cbRaid:SetChecked(false)
if cbInvert then cbInvert:SetChecked(false) end
if cbPet then cbPet:SetChecked(false) end
RefreshLocalSubList(specNum, storageKey) if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end
end)
end
BuildInputFieldBlock("Комплект экипировки:", "sets", "Введите ТОЧНОЕ название вашего комплекта вещей.", false, 0)
BuildInputFieldBlock("Стойка / Бафф:", "buffs", "Обязательная аура, присутствие или стойка (например, 'Власть льда').", false, 1)
BuildInputFieldBlock("Прок триньки / КД:", "icds", "Формат: ОбщееКД/ЗаСколькоПоказать.", true, 2)
end
CreateSubPageBlock(1, -15, COLOR_SPEC1, "ПЕРВАЯ ВЕТКА (СПЕК 1)")
CreateSubPageBlock(2, -830, COLOR_SPEC2, "ВТОРАЯ ВЕТКА (СПЕК 2)")
setsPanel:HookScript("OnShow", function()
RefreshLocalSubList(1, "sets") RefreshLocalSubList(1, "buffs") RefreshLocalSubList(1, "icds")
RefreshLocalSubList(2, "sets") RefreshLocalSubList(2, "buffs") RefreshLocalSubList(2, "icds")
end)
InterfaceOptions_AddCategory(setsPanel) BuildVerticalAuraPage_UpdateAll()
end)
local loginCheck = CreateFrame("Frame")
loginCheck:RegisterEvent("PLAYER_LOGIN")
loginCheck:SetScript("OnEvent", function()
if type(RAY_Engine.RebuildSpellsLookup) == "function" then RAY_Engine.RebuildSpellsLookup() end
if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end
end)
SLASH_RAY1 = "/ray"
SlashCmdList["RAY"] = function(msg)
if optionsPanel then InterfaceOptionsFrame_OpenToCategory(optionsPanel) InterfaceOptionsFrame_OpenToCategory(optionsPanel) end
end
SLASH_RAYMOVE1 = "/raymove"
SlashCmdList["RAYMOVE"] = function()
local nextMoveState = RAY_Engine.frame and not RAY_Engine.frame:IsMouseEnabled() or false
ToggleRayMove(nextMoveState)
if nextMoveState then
DEFAULT_CHAT_FRAME:AddMessage("|cff4ECCA3[RAY]:|r Режим перемещения окон |cffA8FF35ВКЛЮЧЕН|r.")
else
DEFAULT_CHAT_FRAME:AddMessage("|cff4ECCA3[RAY]:|r Режим перемещения окон |cffFF7676ВЫКЛЮЧЕН|r.")
end
end