function RAY_Engine.InitSetsPage()
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
                btn = CreateFrame("Button", nil, pBlock.listFrame) btn:SetSize(280, 22) btn:SetNormalFontObject("GameFontNormal") btn:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight")
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
                cbPet = CreateSubCheckbox("Это питомец", 180, "isPetTracker", "Включите, если это способность призыва питомца. Аддон будет напоминать о призыве, если питомца нет рядом.")
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
                
                -- ЗАЩИТА: Автоматическая безопасная инициализация таблиц
                if not RAY_Config.specSettings then RAY_Config.specSettings = {} end
                if not RAY_Config.specSettings[specNum] then RAY_Config.specSettings[specNum] = { spells = {}, sets = {}, buffs = {}, icds = {} } end
if not RAY_Config.specSettings[specNum][storageKey] then RAY_Config.specSettings[specNum][storageKey] = {} end
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
InterfaceOptions_AddCategory(setsPanel)
if BuildVerticalAuraPage_UpdateAll then BuildVerticalAuraPage_UpdateAll() end
end
-- Финальный инициализатор для применения структуры данных SavedVariables при входе
local loginCheck = CreateFrame("Frame")
loginCheck:RegisterEvent("PLAYER_LOGIN")
loginCheck:SetScript("OnEvent", function()
if type(RAY_Engine.RebuildSpellsLookup) == "function" then RAY_Engine.RebuildSpellsLookup() end
if RAY_Engine.CheckAllAuras then RAY_Engine.CheckAllAuras() end
end)