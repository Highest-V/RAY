-- Вынесено в функцию-конструктор, которая вызывается из главного файла при логине
function RAY_Engine.InitSetsPage()
    setsPanel = CreateFrame("Frame", "RAY_Panel_Sets", optionsPanel) setsPanel.name = "RAY-sets" setsPanel.parent = "RAY"
    local mainScroll = CreateFrame("ScrollFrame", "RAY_SetsScrollFrame", setsPanel, "UIPanelScrollFrameTemplate") mainScroll:SetPoint("TOPLEFT", 8, -40) mainScroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local scrollChild = CreateFrame("Frame", nil, mainScroll) scrollChild:SetSize(380, 1050) mainScroll:SetScrollChild(scrollChild)
    local subTitle = setsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") subTitle:SetPoint("TOPLEFT", 16, -14) subTitle:SetText(PASTEL_TITLE .. "Автоматика Спеков, Стоек и Комплектов Экипировки|r")
    
    -- ГЛОБАЛЬНОЕ МОДАЛЬНОЕ ОКНО ДЛЯ ВСЕХ БЛОКОВ СЕТОВ
    local modal = CreateFrame("Frame", "RAY_MWin_SetsGlobal", InterfaceOptionsFrame)
    modal:SetSize(400, 480) modal:SetPoint("CENTER", InterfaceOptionsFrame, "CENTER", 80, 0) modal:Hide()
    modal:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    modal:SetBackdropColor(0, 0, 0, 1) -- Сплошной черный фон
    modal:SetMovable(true) modal:EnableMouse(true) modal:RegisterForDrag("LeftButton")
    modal:SetScript("OnDragStart", modal.StartMoving) modal:SetScript("OnDragStop", modal.StopMovingOrSizing)
    modal:SetFrameStrata("TOOLTIP")

    local mTitle = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") mTitle:SetPoint("TOPLEFT", 24, -20)
    local mClose = CreateFrame("Button", nil, modal, "UIPanelCloseButton") mClose:SetPoint("TOPRIGHT", -6, -6)
    mClose:SetScript("OnClick", function() modal:Hide() end)

    -- Элементы управления внутри модального окна
    local currentY = -60
    local function CreateModalCheckbox(lbl, key, tooltipText)
        local cb = CreateFrame("CheckButton", nil, modal, "InterfaceOptionsCheckButtonTemplate") cb:SetPoint("TOPLEFT", 24, currentY) cb:SetScale(0.95)
        local t = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal") t:SetPoint("LEFT", cb, "RIGHT", 5, 1) t:SetText(lbl)
        cb:SetScript("OnClick", function(self)
            if modal.specNum and modal.storageKey and modal.itemIndex then
                local data = RAY_Config.specSettings[modal.specNum][modal.storageKey][modal.itemIndex]
                if data then data[key] = self:GetChecked() and true or false if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end end
            end
        end)
        SetTooltip(cb, tooltipText) currentY = currentY - 28 return cb
    end

    local cbCombat = CreateModalCheckbox("Включать только в бою", "onlyInCombat", "Проверять это правило только во время ведения боя.")
    local cbWorld  = CreateModalCheckbox("В открытом мире", "zoneWorld", "Активировать правило в открытом мире.")
    local cbParty  = CreateModalCheckbox("В подземельях", "zoneParty", "Активировать проверку правила в подземельях на 5 человек.")
    local cbRaid   = CreateModalCheckbox("В рейдовых зонах", "zoneRaid", "Активировать проверку правила в рейдовых зонах.")
    local cbInvert = CreateModalCheckbox("Инвертировать логику", "invert", "Оповещать, если этот бафф/стойка НАХОДИТСЯ на вас.")
    local cbPet    = CreateModalCheckbox("Это питомец", "isPetTracker", "Аддон будет напоминать о призыве, если питомца нет рядом.")

    -- Дополнительное поле для КД тринкетов (seconds) в модальном окне
    local icdEditLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") icdEditLabel:SetPoint("TOPLEFT", 24, currentY - 10) icdEditLabel:SetText("Время КД / За сколько показать:")
    local icdEditBox = CreateBlizzardEditBox(modal, 24, currentY - 25, 120, "RAY_SetsMWinIcdSec")
    icdEditBox:SetScript("OnTextChanged", function(self, isUserInput)
        if not isUserInput then return end
        if modal.specNum and modal.storageKey and modal.itemIndex and modal.storageKey == "icds" then
            local data = RAY_Config.specSettings[modal.specNum][modal.storageKey][modal.itemIndex]
            if data then data.seconds = self:GetText() or "45/5" if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end end
        end
    end)
    SetTooltip(icdEditBox, "Формат: ВремяКД/ЗаСколькоПоказать. Например, '45/10'.")

    -- Функция для открытия модалки и заполнения её данными
    local function OpenSetsModal(specNum, storageKey, idx, headerColorCode)
        local data = RAY_Config.specSettings[specNum][storageKey][idx]
        if not data then return end
        
        modal.specNum = specNum modal.storageKey = storageKey modal.itemIndex = idx
        mTitle:SetText(headerColorCode .. (data.name or "Настройка") .. "|r")
        
        cbCombat:SetChecked(data.onlyInCombat == true)
        cbWorld:SetChecked(data.zoneWorld == true)
        cbParty:SetChecked(data.zoneParty == true)
        cbRaid:SetChecked(data.zoneRaid == true)
        
        if storageKey == "buffs" then cbInvert:Show() cbPet:Show() else cbInvert:Hide() cbPet:Hide() end
        if cbInvert:IsShown() then cbInvert:SetChecked(data.invert == true) end
        if cbPet:IsShown() then cbPet:SetChecked(data.isPetTracker == true) end
        
        if storageKey == "icds" then icdEditLabel:Show() icdEditBox:Show() icdEditBox:SetText(data.seconds or "45/5") else icdEditLabel:Hide() icdEditBox:Hide() end
        
        modal:Show()
    end

    local function SubButton_OnClick(self)
        OpenSetsModal(self.specNum, self.storageKey, self.itemIndex, self.headerColorCode)
    end

    local function SubDeleteButton_OnClick(self)
        local parent = self:GetParent()
        table.remove(RAY_Config.specSettings[parent.specNum][parent.storageKey], parent.itemIndex)
        modal:Hide()
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
                btn = CreateFrame("Button", nil, pBlock.listFrame) btn:SetSize(280, 22) btn:SetNormalFontObject("GameFontNormal")
                
                local hl = btn:CreateTexture(nil, "HIGHLIGHT")
                hl:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
                hl:SetBlendMode("ADD") hl:SetVertexColor(1, 0.8, 0, 0.4) hl:SetAllPoints(btn)
                btn:SetHighlightTexture(hl)

                local activeTex = btn:CreateTexture(nil, "OVERLAY")
                activeTex:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
                activeTex:SetBlendMode("ADD") activeTex:SetVertexColor(1, 0.8, 0, 0.3) activeTex:SetAllPoints(btn)
                activeTex:Hide() btn.goldSelect = activeTex

                local del = CreateFrame("Button", nil, btn, "UIPanelCloseButton") del:SetSize(20, 20) del:SetPoint("RIGHT", btn, "RIGHT", -2, 0) btn.del = del pBlock[idx] = btn
            end
            btn.specNum = specNum btn.storageKey = storageKey btn.itemIndex = idx btn.headerColorCode = pBlock.headerColorCode
            btn:SetScript("OnClick", SubButton_OnClick) btn.del:SetScript("OnClick", SubDeleteButton_OnClick)
            btn:ClearAllPoints() btn:SetPoint("TOPLEFT", 0, -((idx - 1) * 24))
            
            local displayNameText = type(data) == "table" and (data.name or "Ошибка") or tostring(data)
            if type(data) == "table" and data.invert then displayNameText = displayNameText .. " [Инверсия]" end
            if type(data) == "table" and data.isPetTracker then displayNameText = displayNameText .. " [Питомец]" end
            btn:SetText(displayNameText .. (isIcd and (" ("..(data.seconds or "45/5")..")") or "")) btn:Show()
            
            if modal:IsShown() and modal.specNum == specNum and modal.storageKey == storageKey and modal.itemIndex == idx then btn.goldSelect:Show() else btn.goldSelect:Hide() end
        end
    end

    local function CreateSubPageBlock(specNum, startY, headerColorCode, specTitle)
        local hOffsetSub = 8
        local blockHeader = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") blockHeader:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", hOffsetSub, startY) blockHeader:SetText(headerColorCode..specTitle.."|r")
        
        local function BuildInputFieldBlock(labelTxt, storageKey, tText, isIcd, blockOffsetIndex)
            local blockTopY = startY - 30 - (blockOffsetIndex * 155) -- Сильно уменьшили шаг Y, так как галочек на экране больше нет!
            local container = CreateFrame("Frame", "RAY_Spec" .. specNum .. "Block" .. storageKey, scrollChild) container:SetSize(360, 140) container:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", hOffsetSub, blockTopY)
            
            local editBox = CreateBlizzardEditBox(container, 0, -25, 220, "RAY_SInp"..specNum..""..storageKey) SetTooltip(editBox, tText)
            local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") label:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 2, 6) label:SetText(headerColorCode .. labelTxt .. "|r")
            local btnOk = CreateFrame("Button", nil, container, "UIPanelButtonTemplate") btnOk:SetSize(45, 24) btnOk:SetPoint("LEFT", editBox, "RIGHT", 8, 0) btnOk:SetText(PASTEL_YELLOW.."ОК|r")
    SetTooltip(btnOk, "Сохранить автоматизацию в этот спек.")
    
    local listFrame = CreateFrame("Frame", nil, container) 
    listFrame:SetSize(280, 75) 
    listFrame:SetPoint("TOPLEFT", editBox, "TOPLEFT", 2, -35)
    
    listButtonsSub[specNum][storageKey].listFrame = listFrame
    listButtonsSub[specNum][storageKey].headerColorCode = headerColorCode
    
    btnOk:SetScript("OnClick", function()
        local txt = editBox:GetText() 
        if not txt or txt == "" or txt == " " then return end
        
        local cleanText = txt:gsub("^%s*(.-)%s*$", "%1")
        local spellID = tonumber(cleanText)
        
        if spellID then
            local spellName = GetSpellInfo(spellID)
            if spellName then txt = spellName end
        end
        
        if not RAY_Config.specSettings then 
            RAY_Config.specSettings = {} 
        end
        if not RAY_Config.specSettings[specNum] then 
            RAY_Config.specSettings[specNum] = { spells = {}, sets = {}, buffs = {}, icds = {} } 
        end
        if not RAY_Config.specSettings[specNum][storageKey] then 
            RAY_Config.specSettings[specNum][storageKey] = {} 
        end
        
        local itemData = { 
            name = txt, 
            seconds = isIcd and "45/5" or nil, 
            onlyInCombat = false, 
            zoneWorld = true, 
            zoneParty = true, 
            zoneRaid = true, 
            invert = false, 
            isPetTracker = false 
        }
        
        table.insert(RAY_Config.specSettings[specNum][storageKey], itemData)
        local insertedIndex = #RAY_Config.specSettings[specNum][storageKey]
        editBox:SetText("")
        
        RefreshLocalSubList(specNum, storageKey) 
        if RAY_Engine.CheckAllAuras then 
            RAY_Engine.CheckAllAuras() 
        end
        
        -- АВТОМАТИКА: Сразу открываем черное окно для свежедобавленной настройки
        OpenSetsModal(specNum, storageKey, insertedIndex, headerColorCode)
    end)
end

    BuildInputFieldBlock("Комплект экипировки:", "sets", "Введите ТОЧНОЕ название вашего комплекта вещей.", false, 0)
    BuildInputFieldBlock("Стойка / Бафф:", "buffs", "Обязательная аура, присутствие или стойка (например, 'Власть льда').", false, 1)
    BuildInputFieldBlock("Прок триньки / КД:", "icds", "Введите имя баффа аксессуара для отслеживания его ICD.", true, 2)
end

CreateSubPageBlock(1, -15, COLOR_SPEC1, "ПЕРВАЯ ВЕТКА (СПЕК 1)")
CreateSubPageBlock(2, -500, COLOR_SPEC2, "ВТОРАЯ ВЕТКА (СПЕК 2)") -- Компактно сдвинули Ветку 2 вверх

setsPanel:HookScript("OnShow", function()
    modal:Hide()
    RefreshLocalSubList(1, "sets") 
    RefreshLocalSubList(1, "buffs") 
    RefreshLocalSubList(1, "icds")
    
    RefreshLocalSubList(2, "sets") 
    RefreshLocalSubList(2, "buffs") 
    RefreshLocalSubList(2, "icds")
end)

setsPanel:HookScript("OnHide", function() 
    modal:Hide() 
end)

InterfaceOptions_AddCategory(setsPanel)

if BuildVerticalAuraPage_UpdateAll then 
    BuildVerticalAuraPage_UpdateAll() 
end
end

-- Финальный инициализатор для применения структуры данных SavedVariables при входе
local loginCheck = CreateFrame("Frame")
loginCheck:RegisterEvent("PLAYER_LOGIN")
loginCheck:SetScript("OnEvent", function()
    if type(RAY_Engine.RebuildSpellsLookup) == "function" then 
        RAY_Engine.RebuildSpellsLookup() 
    end
    if RAY_Engine.CheckAllAuras then 
        RAY_Engine.CheckAllAuras() 
    end
end)