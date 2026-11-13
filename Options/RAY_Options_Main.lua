local shortcutFrame = CreateFrame("Frame")
isSelfUpdating = false
dragCbGlobal = nil

function CreateBlizzardEditBox(parent, x, y, width, name)
    local eb = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    eb:SetSize(width, 24) eb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y) eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal") eb:SetTextInsets(4, 4, 0, 0)
    return eb
end

-- Всплывающие подсказки с гарантированным выталкиванием на самый верхний слой
function SetTooltip(widget, uText)
    widget:SetScript("OnEnter", function(self) 
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT") 
        GameTooltip:SetText(uText, 1, 1, 1, nil, true) 
        -- Динамически поднимаем подсказку над уровнем кнопки, на которую навели
        GameTooltip:SetFrameLevel(self:GetFrameLevel() + 5)
        GameTooltip:Show() 
    end)
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

        -- Поддержка отдельных окон РЛ-Радара при /raymove
        if RAY_Config.radarSpells then
            for i = 1, #RAY_Config.radarSpells do
                local rData = RAY_Config.radarSpells[i]
                if rData and rData.name ~= "" and rData.isOwnWindow then
                    local fKey = "Radar_" .. RAY_Engine.GetFrameKey(rData.name)
                    local cf = GetOrCreateCustomFrame(fKey)
                    cf:EnableMouse(true) cf.bg:Show() cf.border:Show()
                    if cf.labelString then
                        cf.labelString:SetText("[Радар]: " .. (tostring(rData.name):match("[^|/]+") or rData.name))
                        cf.labelString:SetFont("Fonts\\FRIZQT__.TTF", rData.customSize or 24, "OUTLINE")
                    end
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

        -- Скрытие окон РЛ-Радара при выключении /raymove
        if RAY_Config.radarSpells then
            for i = 1, #RAY_Config.radarSpells do
                local rData = RAY_Config.radarSpells[i]
                if rData and rData.name then
                    local fKey = "Radar_" .. RAY_Engine.GetFrameKey(rData.name)
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

    -- КНОПКА "НАСТРОИТЬ РАДАР" И ДВУХУРОВНЕВЫЕ МОДАЛЬНЫЕ ОКНА
    local btnConfigRadar = CreateFrame("Button", "RAY_BtnConfigRadar", optionsPanel, "UIPanelButtonTemplate")
    btnConfigRadar:SetSize(135, 24)
    btnConfigRadar:SetPoint("LEFT", radarCbText, "RIGHT", 16, 0)
    btnConfigRadar:SetText(PASTEL_YELLOW .. "Настроить радар|r")
    SetTooltip(btnConfigRadar, "Открывает фильтр РЛ-Радара для отслеживания важных способностей по журналу боя (тотемы, гимны, сейвы, сбития кастов) с выводом на экран. Функция в первую очередь полезна рейд-лидерам.")

    -- МОДАЛЬНОЕ ОКНО 1: СПИСОК СПЕЛЛОВ РАДАРА
    local radarListModal = CreateFrame("Frame", "RAY_RadarListModal", InterfaceOptionsFrame)
    radarListModal:SetSize(380, 440)
    radarListModal:SetPoint("CENTER", InterfaceOptionsFrame, "CENTER", 40, 0)
    radarListModal:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    radarListModal:SetBackdropColor(0, 0, 0, 1)
    radarListModal:SetMovable(true)
    radarListModal:EnableMouse(true)
    radarListModal:RegisterForDrag("LeftButton")
    radarListModal:SetScript("OnDragStart", radarListModal.StartMoving)
    radarListModal:SetScript("OnDragStop", radarListModal.StopMovingOrSizing)
    radarListModal:SetFrameStrata("TOOLTIP")
    radarListModal:Hide()

    local rListTitle = radarListModal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rListTitle:SetPoint("TOPLEFT", 22, -18)
    rListTitle:SetText(PASTEL_TITLE .. "Настройка РЛ-Радара|r")

    local rListClose = CreateFrame("Button", nil, radarListModal, "UIPanelCloseButton")
    rListClose:SetPoint("TOPRIGHT", -6, -6)

    local rEditLabel = radarListModal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rEditLabel:SetPoint("TOPLEFT", 22, -50)
    rEditLabel:SetText("Название способности или ID:")

    local rEditBox = CreateBlizzardEditBox(radarListModal, 22, -68, 255, "RAY_RadarInputBox")
    local rBtnOk = CreateFrame("Button", nil, radarListModal, "UIPanelButtonTemplate")
    rBtnOk:SetSize(55, 24)
    rBtnOk:SetPoint("LEFT", rEditBox, "RIGHT", 8, 0)
    rBtnOk:SetText(PASTEL_YELLOW .. "ОК|r")
    SetTooltip(rBtnOk, "Добавить способность в фильтр радара.")

    local rScroll = CreateFrame("ScrollFrame", "RAY_RadarScrollFrame", radarListModal, "UIPanelScrollFrameTemplate")
    rScroll:SetPoint("TOPLEFT", 20, -108)
    rScroll:SetPoint("BOTTOMRIGHT", -32, 20)
    local rScrollChild = CreateFrame("Frame", nil, rScroll)
    rScrollChild:SetSize(310, 600)
    rScroll:SetScrollChild(rScrollChild)

    -- МОДАЛЬНОЕ ОКНО 2: НАСТРОЙКИ КОНКРЕТНОГО СПЕЛЛА (строго поверх Окна 1)
    local radarItemModal = CreateFrame("Frame", "RAY_RadarItemModal", radarListModal)
    radarItemModal:SetSize(340, 310)
    radarItemModal:SetPoint("CENTER", radarListModal, "CENTER", 35, -15)
    radarItemModal:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    radarItemModal:SetBackdropColor(0.03, 0.03, 0.03, 1)
    radarItemModal:SetMovable(true)
    radarItemModal:EnableMouse(true)
    radarItemModal:RegisterForDrag("LeftButton")
    radarItemModal:SetScript("OnDragStart", radarItemModal.StartMoving)
    radarItemModal:SetScript("OnDragStop", radarItemModal.StopMovingOrSizing)
    radarItemModal:SetFrameStrata("TOOLTIP")
    radarItemModal:SetFrameLevel(radarListModal:GetFrameLevel() + 10)
    radarItemModal:Hide()

    local rItemTitle = radarItemModal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rItemTitle:SetPoint("TOPLEFT", 22, -18)

    local rItemClose = CreateFrame("Button", nil, radarItemModal, "UIPanelCloseButton")
    rItemClose:SetPoint("TOPRIGHT", -6, -6)
    rItemClose:SetFrameLevel(radarItemModal:GetFrameLevel() + 5)
    rItemClose:SetScript("OnClick", function() radarItemModal:Hide() end)

    rListClose:SetScript("OnClick", function()
        radarItemModal:Hide()
        radarListModal:Hide()
    end)

    local selectedRadarIdx = nil
    local radarListButtons = {}

    -- 1. Чекбокс "Включать только в бою"
    local rCbCombat = CreateFrame("CheckButton", "RAY_RadarCbCombat", radarItemModal, "InterfaceOptionsCheckButtonTemplate")
    rCbCombat:SetPoint("TOPLEFT", 20, -52)
    rCbCombat:SetScale(0.95)
    rCbCombat:SetFrameLevel(radarItemModal:GetFrameLevel() + 5)
    local rCbCombatText = rCbCombat:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rCbCombatText:SetPoint("LEFT", rCbCombat, "RIGHT", 5, 1)
    rCbCombatText:SetText(PASTEL_BUFF .. "Включать только в бою|r")
    rCbCombat:SetScript("OnClick", function(self)
        if selectedRadarIdx and RAY_Config.radarSpells[selectedRadarIdx] then
            RAY_Config.radarSpells[selectedRadarIdx].onlyInCombat = self:GetChecked() and true or false
        end
    end)
    SetTooltip(rCbCombat, "Блокирует срабатывание вне боя (например, в Даларане).")

    -- 2. Чекбокс "Окно"
    local rCbWindow = CreateFrame("CheckButton", "RAY_RadarCbWindow", radarItemModal, "InterfaceOptionsCheckButtonTemplate")
    rCbWindow:SetPoint("TOPLEFT", 20, -82)
    rCbWindow:SetScale(0.95)
    rCbWindow:SetFrameLevel(radarItemModal:GetFrameLevel() + 5)
    local rCbWindowText = rCbWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rCbWindowText:SetPoint("LEFT", rCbWindow, "RIGHT", 5, 1)
    rCbWindowText:SetText(PASTEL_BUFF .. "Окно (отдельный фрейм)|r")
    rCbWindow:SetScript("OnClick", function(self)
        if selectedRadarIdx and RAY_Config.radarSpells[selectedRadarIdx] then
            RAY_Config.radarSpells[selectedRadarIdx].isOwnWindow = self:GetChecked() and true or false
        end
    end)
    SetTooltip(rCbWindow, "Выводит оповещение в отдельное окно, которое можно двигать через /raymove.")

    -- 3. Ползунок "Размер шрифта"
    local rSliderSize = CreateFrame("Slider", "RAY_RadarSliderSize", radarItemModal, "OptionsSliderTemplate")
    rSliderSize:SetSize(180, 16)
    rSliderSize:SetPoint("TOPLEFT", 24, -130)
    rSliderSize:SetMinMaxValues(12, 48)
    rSliderSize:SetValueStep(1)
    rSliderSize:SetFrameLevel(radarItemModal:GetFrameLevel() + 5)
    local rSliderText = rSliderSize:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rSliderText:SetPoint("BOTTOMLEFT", rSliderSize, "TOPLEFT", 0, 4)
    rSliderSize:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value)
        rSliderText:SetText("Размер шрифта: " .. val)
        if selectedRadarIdx and RAY_Config.radarSpells[selectedRadarIdx] then
            RAY_Config.radarSpells[selectedRadarIdx].customSize = val
        end
    end)
    SetTooltip(rSliderSize, "Размер текста оповещения на экране.")

    -- 4. Выбор цвета
    local rColorBtn = CreateFrame("Button", nil, radarItemModal)
    rColorBtn:SetSize(20, 20)
    rColorBtn:SetPoint("TOPLEFT", 24, -170)
    rColorBtn:SetFrameLevel(radarItemModal:GetFrameLevel() + 5)
    local rColorTex = rColorBtn:CreateTexture(nil, "BACKGROUND")
    rColorTex:SetAllPoints()
    rColorTex:SetTexture(0.5, 0.95, 0.8)
    rColorBtn.tex = rColorTex

    local rDefColorBtn = CreateFrame("Button", nil, radarItemModal, "UIPanelButtonTemplate")
    rDefColorBtn:SetSize(135, 20)
    rDefColorBtn:SetPoint("LEFT", rColorBtn, "RIGHT", 10, 0)
    rDefColorBtn:SetText("Цвет по умолчанию")
    rDefColorBtn:SetFrameLevel(radarItemModal:GetFrameLevel() + 5)
    SetTooltip(rColorBtn, "Выбрать цвет текста оповещения.")

    -- 5. Длительность показа (сек)
    local rDurLabel = radarItemModal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rDurLabel:SetPoint("TOPLEFT", 24, -210)
    rDurLabel:SetText("Длительность показа алерта (сек):")
    local rDurBox = CreateBlizzardEditBox(radarItemModal, 24, -228, 100, "RAY_RadarDurBox")
    rDurBox:SetFrameLevel(radarItemModal:GetFrameLevel() + 5)
    rDurBox:SetScript("OnTextChanged", function(self, isUserInput)
        if not isUserInput then return end
        if selectedRadarIdx and RAY_Config.radarSpells[selectedRadarIdx] then
            local val = tonumber(self:GetText()) or 5
            if val < 1 then val = 1 end
            RAY_Config.radarSpells[selectedRadarIdx].duration = val
        end
    end)
    SetTooltip(rDurBox, "Сколько секунд предупреждение будет висеть на экране после применения способности.")


    local function RefreshRadarList()
        for _, b in ipairs(radarListButtons) do b:Hide() end
        if not RAY_Config.radarSpells then RAY_Config.radarSpells = {} end
        for i = 1, #RAY_Config.radarSpells do
            local item = RAY_Config.radarSpells[i]
            local btn = radarListButtons[i]
            if not btn then
                btn = CreateFrame("Button", nil, rScrollChild)
                btn:SetSize(295, 24)
                btn:SetNormalFontObject("GameFontNormal")
                local hl = btn:CreateTexture(nil, "HIGHLIGHT")
                hl:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
                hl:SetBlendMode("ADD") hl:SetVertexColor(1, 0.8, 0, 0.4) hl:SetAllPoints(btn)
                btn:SetHighlightTexture(hl)

                local del = CreateFrame("Button", nil, btn, "UIPanelCloseButton")
                del:SetSize(18, 18) del:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
                btn.delBtn = del
                radarListButtons[i] = btn
            end
            btn.rIdx = i
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", rScrollChild, "TOPLEFT", 2, -((i - 1) * 26))
            local c = item.color or { r = 0.5, g = 0.95, b = 0.8 }
            local tag = item.onlyInCombat and " [Бой]" or ""
            btn:SetText(string.format("|cff%02x%02x%02x%s|r|cffAAAAAA%s|r", c.r * 255, c.g * 255, c.b * 255, item.name, tag))

            btn:SetScript("OnClick", function(self)
                selectedRadarIdx = self.rIdx
                local d = RAY_Config.radarSpells[selectedRadarIdx]
                if d then
                    rItemTitle:SetText(PASTEL_YELLOW .. d.name .. "|r")
                    rCbCombat:SetChecked(d.onlyInCombat == true)
                    rCbWindow:SetChecked(d.isOwnWindow == true)
                    rSliderSize:SetValue(d.customSize or 24)
                    rDurBox:SetText(tostring(d.duration or 5))
                    local col = d.color or { r = 0.5, g = 0.95, b = 0.8 }
                    rColorTex:SetVertexColor(col.r, col.g, col.b)
                    radarItemModal:Show()
                end
            end)

            btn.delBtn:SetScript("OnClick", function(self)
                local idx = self:GetParent().rIdx
                table.remove(RAY_Config.radarSpells, idx)
                if selectedRadarIdx == idx then radarItemModal:Hide() selectedRadarIdx = nil end
                if RAY_Engine.RebuildRadarLookup then RAY_Engine.RebuildRadarLookup() end
                RefreshRadarList()
            end)
            btn:Show()
        end
        rScrollChild:SetHeight(#RAY_Config.radarSpells * 26 + 20)
    end

    rColorBtn:SetScript("OnClick", function()
        if not selectedRadarIdx or not RAY_Config.radarSpells[selectedRadarIdx] then return end
        local cur = RAY_Config.radarSpells[selectedRadarIdx].color or { r = 0.5, g = 0.95, b = 0.8 }
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            rColorTex:SetVertexColor(r, g, b)
            if selectedRadarIdx and RAY_Config.radarSpells[selectedRadarIdx] then
                RAY_Config.radarSpells[selectedRadarIdx].color = { r = r, g = g, b = b }
                RefreshRadarList()
            end
        end
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame:SetColorRGB(cur.r, cur.g, cur.b)
        ColorPickerFrame:SetFrameStrata("TOOLTIP")
        ColorPickerFrame:SetFrameLevel(radarItemModal:GetFrameLevel() + 15)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end)

    rDefColorBtn:SetScript("OnClick", function()
        local def = { r = 0.5, g = 0.95, b = 0.8 }
        rColorTex:SetVertexColor(def.r, def.g, def.b)
        if selectedRadarIdx and RAY_Config.radarSpells[selectedRadarIdx] then
            RAY_Config.radarSpells[selectedRadarIdx].color = def
            RefreshRadarList()
        end
    end)

    rBtnOk:SetScript("OnClick", function()
        local txt = rEditBox:GetText()
        if not txt or txt:match("^%s*$") then return end
        local cleanText = txt:gsub("^%s*(.-)%s*$", "%1")
        local spellID = tonumber(cleanText)
        if spellID then
            local spellName = GetSpellInfo(spellID)
            if spellName then cleanText = spellName end
        end

        if not RAY_Config.radarSpells then RAY_Config.radarSpells = {} end
        local newItem = {
            name = cleanText,
            onlyInCombat = true,
            isOwnWindow = false,
            customSize = 24,
            duration = 5,
            color = { r = 0.5, g = 0.95, b = 0.8 }
        }
        table.insert(RAY_Config.radarSpells, newItem)
        selectedRadarIdx = #RAY_Config.radarSpells
        rEditBox:SetText("")

        if RAY_Engine.RebuildRadarLookup then RAY_Engine.RebuildRadarLookup() end
        RefreshRadarList()

        -- Автооткрытие второго окна настроек для свежедобавленного спелла
        rItemTitle:SetText(PASTEL_YELLOW .. newItem.name .. "|r")
        rCbCombat:SetChecked(true)
        rCbWindow:SetChecked(false)
        rSliderSize:SetValue(24)
        rDurBox:SetText("5")
        rColorTex:SetVertexColor(0.5, 0.95, 0.8)
        radarItemModal:Show()
    end)

    btnConfigRadar:SetScript("OnClick", function()
        radarItemModal:Hide()
        RefreshRadarList()
        radarListModal:Show()
    end)

    optionsPanel:HookScript("OnHide", function()
        radarItemModal:Hide()
        radarListModal:Hide()
    end)

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

    local btnClear = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    btnClear:SetSize(140, 30)
    btnClear:SetPoint("TOPLEFT", 16, -305)
    btnClear:SetText("|cffFF7676Полный сброс|r")
    btnClear:SetScript("OnClick", function() 
        RAY_Config = nil 
        ReloadUI() 
    end)
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
    if optionsPanel then 
        InterfaceOptionsFrame_OpenToCategory(optionsPanel) 
        InterfaceOptionsFrame_OpenToCategory(optionsPanel) 
    end
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
