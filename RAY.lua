-- 1. Инициализация главного фрейма RAY и слоя текста
local frame = CreateFrame("Frame", "RAY_MainFrame", UIParent)
frame:SetSize(600, 250)
frame:SetPoint("CENTER", 0, 150) -- Центр экрана, чуть выше середины

local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
text:SetPoint("CENTER", frame, "CENTER")
text:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE") 

-- УСТАНОВЛЕН ЯРКО-БИРЮЗОВЫЙ ЦВЕТ ТЕКСТА (R=0, G=1, B=0.9)
text:SetTextColor(0, 1, 0.9) 
text:SetJustifyH("CENTER")

-- Изначально полностью скрываем фрейм
frame:Hide()

-- Анимация мигания (работает только тогда, когда надпись выведена на экран)
local fadeSpeed = 3.5
local timeElapsed = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    timeElapsed = timeElapsed + elapsed
    local alpha = 0.3 + 0.7 * math.sin(timeElapsed * fadeSpeed)
    text:SetAlpha(alpha)
end)

-- Функция определения типа зоны (Мир / Пати / Рейд)
local function GetCurrentZoneType()
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid") then
        return instanceType
    end
    if GetNumRaidMembers() > 0 then return "raid" end
    if GetNumPartyMembers() > 0 then return "party" end
    return "world"
end

-- ИСПРАВЛЕНО: База данных SpellID для Оружия языка пламени Шамана (все ранги)
local FLAMETONGUE_SPELL_IDS = {
    ["8024"]  = true, -- Ранг 1
    ["8027"]  = true, -- Ранг 2
    ["8030"]  = true, -- Ранг 3
    ["16339"] = true, -- Ранг 4
    ["16341"] = true, -- Ранг 5
    ["16342]"] = true, -- Ранг 6
    ["25489"] = true, -- Ранг 7
    ["25490"] = true, -- Ранг 8
    ["58785"] = true, -- Ранг 9
    ["58790"] = true, -- Ранг 10 (макс. ранг Лич Кинг)
}

-- ИСПРАВЛЕНО: База данных SpellID всех печатей Паладина в 3.3.5a
local PALADIN_SEAL_IDS = {
    ["20154"] = true, -- Печать праведности (Seal of Righteousness)
    ["20271"] = true, -- Печать справедливости (Seal of Justice)
    ["20166"] = true, -- Печать мудрости (Seal of Wisdom)
    ["20165"] = true, -- Печать света (Seal of Light)
    ["31801"] = true, -- Печать мщения (Seal of Vengeance)
    ["20375"] = true, -- Печать повиновения (Seal of Command)
    ["53736"] = true, -- Печать порчи (Seal of Corruption)
}

-- 2. Универсальная логика проверки списка баффов и дебаффов цели
local function CheckBuffs()
    if not RAY_Config or not RAY_Config.enabled then
        frame:Hide()
        return
    end

    -- Проверка зон контроля
    local currentZone = GetCurrentZoneType()
    if currentZone == "world" and not RAY_Config.zoneWorld then frame:Hide() return end
    if currentZone == "party" and not RAY_Config.zoneParty then frame:Hide() return end
    if currentZone == "raid" and not RAY_Config.zoneRaid then frame:Hide() return end

    -- Проверка общего статуса боя (если стоит галочка в настройках)
    local inCombat = UnitAffectingCombat("player")
    if RAY_Config.onlyInCombat and not inCombat then
        frame:Hide()
        return
    end

    -- Если список настроек пуст
    if not RAY_Config.spells or #RAY_Config.spells == 0 then
        frame:Hide()
        return
    end

    -- Опрашиваем слоты оружия из API (для Шамана)
    local mhActive, _, _, _, ohActive, _, _, _ = GetWeaponEnchantInfo()

    -- Сбор всех обычных баффов по ИМЕНИ и по SpellID
    local activeBuffs = {}
    local activeSpellIDs = {}
    local isAnySealActive = false
    local sealTimeLeft = 0
    
    for i = 1, 40 do
        local name, _, _, _, _, _, expirationTime, _, _, _, spellID = UnitBuff("player", i)
        if not name then break end
        local nameLower = name:lower()
        activeBuffs[nameLower] = true
        if spellID then
            local spellIDStr = tostring(spellID)
            activeSpellIDs[spellIDStr] = true
            if PALADIN_SEAL_IDS[spellIDStr] then 
                isAnySealActive = true 
                if expirationTime and expirationTime > 0 then
                    sealTimeLeft = expirationTime - GetTime()
                end
            end
        end
        if nameLower:find("печать") or nameLower:find("seal") then 
            isAnySealActive = true 
            if expirationTime and expirationTime > 0 and sealTimeLeft == 0 then
                sealTimeLeft = expirationTime - GetTime()
            end
        end
    end

    local alertText = "" 

    -- Перебираем добавленные заклинания
    for index, spellName in ipairs(RAY_Config.spells) do
        if spellName and spellName ~= "" then
            local spellLower = spellName:lower()
            local isBuffActive = false
            local customAlert = nil

            -- ==================== ЛОГИКА ДЛЯ ВАРА: РАСКОЛ БРОНИ ====================
            if spellLower:find("раскол брони") or spellLower:find("sunder armor") then
                -- Отслеживаем строго в бою и при наличии живой вражеской цели [C]
                if inCombat and UnitExists("target") and not UnitIsDead("target") and UnitCanAttack("player", "target") then
                    local name, _, _, count, _, _, expirationTime = UnitDebuff("target", spellName)
                    
                    if name then
                        count = count or 1
                        local timeLeft = expirationTime > 0 and (expirationTime - GetTime()) or 30
                        
                        if count < 5 then
                            -- Стаков меньше 5 — постоянное напоминание [C]
                            isBuffActive = false
                            customAlert = "RAY: На цель нужен Раскол брони! (Стаков: " .. count .. "/5)"
                        else
                            -- Стаков 5 — напоминаем только за 5 секунд до спада дебаффа [C]
                            if timeLeft <= 5 then
                                isBuffActive = false
                                customAlert = "RAY: Обнови Раскол брони! (Осталось: " .. math.floor(timeLeft) .. " сек)"
                            else
                                isBuffActive = true
                            end
                        end
                    else
                        -- Дебаффа вообще нет на цели — постоянное напоминание [C]
                        isBuffActive = false
                        customAlert = "RAY: На цель нужен Раскол брони! (Нет стаков)"
                    end
                else
                    isBuffActive = true -- Если не в бою или нет врага в таргете — скрываем напоминание [C]
                end

            -- ==================== ЛОГИКА ДЛЯ ПАЛАДИНА ====================
            elseif spellLower:find("печать") or spellLower:find("seal") then
                if isAnySealActive then
                    if sealTimeLeft > 0 and sealTimeLeft <= 300 then
                        -- До спада осталось 5 минут (300 сек) или меньше
                        isBuffActive = false
                        local minutes = math.ceil(sealTimeLeft / 60)
                        customAlert = "RAY: Обнови " .. spellName .. "! (Осталось: " .. minutes .. " мин)"
                    else
                        isBuffActive = true
                    end
                else
                    isBuffActive = false
                end
            
            -- ==================== ЛОГИКА ДЛЯ ШАМАНА ====================
            else
                local isWindOrEarth = (spellLower:find("неистовств") or spellLower:find("земли") or spellLower:find("windfury") or spellLower:find("earthliving"))
                local isFireOrFrost = (spellLower:find("пламен") or spellLower:find("клейм") or spellLower:find("flametongue") or spellLower:find("frostbrand"))

                if isWindOrEarth then
                    isBuffActive = (mhActive == 1 or mhActive == true or (type(mhActive) == "number" and mhActive > 0))
                elseif isFireOrFrost then
                    local leftHandActive = (ohActive == 1 or ohActive == true or (type(ohActive) == "number" and ohActive > 0))
                    local idBackup = false
                    for id in pairs(FLAMETONGUE_SPELL_IDS) do
                        if activeSpellIDs[id] then idBackup = true break end
                    end
                    local auraBackup = (activeBuffs[spellLower] == true or activeBuffs["язык пламени"] == true)
                    isBuffActive = leftHandActive or idBackup or auraBackup
                else
                    isBuffActive = (activeBuffs[spellLower] == true)
                end
            end

            -- Если бафф/дебафф отсутствует — добавляем строку в список
            if not isBuffActive then
                local currentMessage = customAlert or ("RAY: Вспомни о " .. spellName .. "!")
                if alertText == "" then
                    alertText = currentMessage
                else
                    alertText = alertText .. "\n" .. currentMessage
                end
            end
        end
    end

    -- Вывод сформированного списка на экран
    if alertText ~= "" then
        text:SetText(alertText)
        frame:Show()
    else
        frame:Hide()
    end
end

-- 3. Регистрация игровых триггеров
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("UNIT_AURA")                      
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")         
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")    
frame:RegisterEvent("PLAYER_REGEN_DISABLED")          
frame:RegisterEvent("PLAYER_REGEN_ENABLED")           
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")          
frame:RegisterEvent("PLAYER_TARGET_CHANGED")          -- Срабатывает при смене цели [C]

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local arg1 = ...
        if arg1 == "RAY" then
            if not RAY_Config then
                RAY_Config = { enabled = true, spells = {}, onlyInCombat = false, zoneWorld = true, zoneParty = true, zoneRaid = true }
            end
        end
    else
        if event == "UNIT_AURA" or event == "UNIT_INVENTORY_CHANGED" then
            local arg1 = ...
            if arg1 ~= "player" then return end
        end
        CheckBuffs()
    end
end)

-- Обновление таймингов дебаффов в бою (0.5 сек для Раскола брони)
local ticker = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    timeElapsed = timeElapsed + elapsed
    local alpha = 0.3 + 0.7 * math.sin(timeElapsed * fadeSpeed)
    text:SetAlpha(alpha)

    if UnitAffectingCombat("player") then
        ticker = ticker + elapsed
        if ticker >= 0.5 then
            ticker = 0
            CheckBuffs()
        end
    end
end)

-- 4. Панель настроек модификации
local settingsPanel = CreateFrame("Frame", "RAY_SettingsPanel", UIParent)
settingsPanel.name = "RAY"

local title = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("|cff00ffccRAY|r - Настройки")

local cbEnabled = CreateFrame("CheckButton", "RAY_CBEnabled", settingsPanel, "InterfaceOptionsCheckButtonTemplate")
cbEnabled:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
_G[cbEnabled:GetName() .. "Text"]:SetText("Включить аддон RAY")
cbEnabled:SetScript("OnClick", function(self) if RAY_Config then RAY_Config.enabled = self:GetChecked() CheckBuffs() end end)
local cbCombat = CreateFrame("CheckButton", "RAY_CBCombat", settingsPanel, "InterfaceOptionsCheckButtonTemplate")
cbCombat:SetPoint("TOPLEFT", cbEnabled, "BOTTOMLEFT", 0, -5)
_G[cbCombat:GetName() .. "Text"]:SetText("Показывать напоминание только в бою")
cbCombat:SetScript("OnClick", function(self) if RAY_Config then RAY_Config.onlyInCombat = self:GetChecked() CheckBuffs() end end)
local zoneLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
zoneLabel:SetPoint("TOPLEFT", cbCombat, "BOTTOMLEFT", 0, -10)
zoneLabel:SetText("Где отслеживать:")
local cbWorld = CreateFrame("CheckButton", "RAY_CBWorld", settingsPanel, "InterfaceOptionsCheckButtonTemplate")
cbWorld:SetPoint("TOPLEFT", zoneLabel, "BOTTOMLEFT", 0, -5)
_G[cbWorld:GetName() .. "Text"]:SetText("В мире")
cbWorld:SetScript("OnClick", function(self) if RAY_Config then RAY_Config.zoneWorld = self:GetChecked() CheckBuffs() end end)
local cbParty = CreateFrame("CheckButton", "RAY_CBParty", settingsPanel, "InterfaceOptionsCheckButtonTemplate")
cbParty:SetPoint("LEFT", cbWorld, "RIGHT", 70, 0)
_G[cbParty:GetName() .. "Text"]:SetText("В пати")
cbParty:SetScript("OnClick", function(self) if RAY_Config then RAY_Config.zoneParty = self:GetChecked() CheckBuffs() end end)
local cbRaid = CreateFrame("CheckButton", "RAY_CBRaid", settingsPanel, "InterfaceOptionsCheckButtonTemplate")
cbRaid:SetPoint("LEFT", cbParty, "RIGHT", 70, 0)
_G[cbRaid:GetName() .. "Text"]:SetText("В рейде")
cbRaid:SetScript("OnClick", function(self) if RAY_Config then RAY_Config.zoneRaid = self:GetChecked() CheckBuffs() end end)
local ebLabel = settingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
ebLabel:SetPoint("TOPLEFT", cbWorld, "BOTTOMLEFT", 0, -15)
ebLabel:SetText("Добавить заклинание для отслеживания:")
local editBox = CreateFrame("EditBox", "RAY_EditBox", settingsPanel, "InputBoxTemplate")
editBox:SetSize(200, 20)
editBox:SetPoint("TOPLEFT", ebLabel, "BOTTOMLEFT", 5, -5)
editBox:SetAutoFocus(false)
local addButton = CreateFrame("Button", "RAY_AddButton", settingsPanel, "UIPanelButtonTemplate")
addButton:SetSize(80, 22)
addButton:SetPoint("LEFT", editBox, "RIGHT", 5, 0)
addButton:SetText("Добавить")
local listFrame = CreateFrame("Frame", "RAY_ListFrame", settingsPanel)
listFrame:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", -5, -25)
listFrame:SetSize(350, 200)
local spellRows = {}
local function UpdateVisualList()
for i = 1, #spellRows do if spellRows[i] then spellRows[i]:Hide() end end
if not RAY_Config or not RAY_Config.spells then return end
for i, spellName in ipairs(RAY_Config.spells) do
if not spellRows[i] then
local row = CreateFrame("Frame", nil, listFrame)
row:SetSize(350, 24)
local txt = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
txt:SetPoint("LEFT", 5, 0)
row.text = txt
local delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
delBtn:SetSize(20, 20) delBtn:SetText("X") delBtn:SetPoint("RIGHT", -5, 0)
row.delBtn = delBtn
spellRows[i] = row
end
local currentRow = spellRows[i]
currentRow.text:SetText(spellName)
currentRow.delBtn:SetScript("OnClick", function()
if RAY_Config and RAY_Config.spells then table.remove(RAY_Config.spells, i) UpdateVisualList() CheckBuffs() end
end)
if i == 1 then currentRow:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 0, 0)
else currentRow:SetPoint("TOPLEFT", spellRows[i-1], "BOTTOMLEFT", 0, -2) end
currentRow:Show()
end
end
local function AddSpellAction()
if not RAY_Config or not RAY_Config.spells then return end
local name = editBox:GetText()
if name and name ~= "" then
local exists = false
for _, v in ipairs(RAY_Config.spells) do if v == name then exists = true break end end
if not exists then
table.insert(RAY_Config.spells, name)
editBox:SetText("") editBox:ClearFocus() UpdateVisualList() CheckBuffs()
end
end
end
addButton:SetScript("OnClick", AddSpellAction)
editBox:SetScript("OnEnterPressed", AddSpellAction)
settingsPanel.refresh = function()
if not RAY_Config then return end
cbEnabled:SetChecked(RAY_Config.enabled)
cbCombat:SetChecked(RAY_Config.onlyInCombat)
cbWorld:SetChecked(RAY_Config.zoneWorld)
cbParty:SetChecked(RAY_Config.zoneParty)
cbRaid:SetChecked(RAY_Config.zoneRaid)
UpdateVisualList()
end
InterfaceOptions_AddCategory(settingsPanel)
-- 5. СЛЕШ-КОМАНДА
SLASH_RAY1 = "/ray"
SlashCmdList["RAY"] = function()
InterfaceOptionsFrame_OpenToCategory(settingsPanel)
InterfaceOptionsFrame_OpenToCategory(settingsPanel)
end