local shortcutFrame = CreateFrame("Frame")
isSelfUpdating = false
dragCbGlobal = nil

-- Общие вспомогательные функции для всех окон настроек
function CreateBlizzardEditBox(parent, x, y, width, name)
    local eb = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    eb:SetSize(width, 24) eb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y) eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal") eb:SetTextInsets(4, 4, 0, 0)
    return eb
end

-- Всплывающие подсказки
function SetTooltip(widget, uText)
    widget:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT") GameTooltip:SetText(uText, 1, 1, 1, nil, true) GameTooltip:Show() end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Перемещение окон (/raymove)
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

-- Регистрация главной панели в Blizzard Options
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
    
    -- Оповещаем другие модули, что базовая панель создана, можно строить вкладки
    if RAY_Engine.InitBuffsPage then RAY_Engine.InitBuffsPage() end
    if RAY_Engine.InitDebuffsPage then RAY_Engine.InitDebuffsPage() end
    if RAY_Engine.InitSetsPage then RAY_Engine.InitSetsPage() end
end)

-- Регистрация слеш-команд
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