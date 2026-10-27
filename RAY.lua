-- =========================================================================
-- 1. ИНИЦИАЛИЗАЦИЯ И РАЗДЕЛЬНОЕ СОХРАНЕНИЕ НАСТРОЕК
-- =========================================================================
local addonName = "RAY"
local RAY_EventFrame = CreateFrame("Frame")

local defaultSettings = {
    enabled = true,
    fontSize = 24,
    radarEnabled = false,
    boxHunterEnabled = true,
    spells = {},
    framePos = { point = "CENTER", x = 0, y = 150 },
    specSettings = {
        { sets = {}, buffs = {}, icds = {} },
        { sets = {}, buffs = {}, icds = {} }
    }
}

-- Глобальные переменные интерфейса
local optionsPanel, buffsPanel, debuffsPanel, setsPanel
local selectedBuffIndex, selectedDebuffIndex
local listButtonsBuff, listButtonsDebuff = {}, {}
local listButtonsSub = { 
    [1] = { sets = {}, buffs = {}, icds = {} }, 
    [2] = { sets = {}, buffs = {}, icds = {} } 
}
local updateSpellLists, selectBuff, selectDebuff, CheckAllAuras
local RefreshLocalSubList

-- Пул независимых окон для опции "Показать отдельным окном"
local customFramesPool = {}

-- Кэш и переменные состояния
local activeICDTimers = {}
local sylvanasAlertActive = false
local uniqueAlerts = {}
local alertStringTable = {}
local cachePlayerAuras = {}
local cacheTargetAuras = {}

-- Насыщенная палитра
local PASTEL_TITLE  = "|cff4ECCA3" -- Яркий бирюзово-зеленый
local PASTEL_BUFF   = "|cffA8FF35" -- Сочный салатовый
local PASTEL_DEBUFF = "|cffFF7676" -- Заметный мягкий красный
local PASTEL_YELLOW = "|cffFFD369" -- Теплый песочно-желтый
local PASTEL_GRAY   = "|cffEEEEEE" -- Почти белый / Светло-серый

-- Цвета для веток талантов
local COLOR_SPEC1   = "|cffD6A2E8" -- Нежно-фиолетовый
local COLOR_SPEC2   = "|cffFFB84C" -- Нежно-оранжевый

-- Статичные фреймы-сканеры
local textScanFrameMain = CreateFrame("GameTooltip", "RAY_EnchantScannerTooltipMain", nil, "GameTooltipTemplate")
textScanFrameMain:SetOwner(UIParent, "ANCHOR_NONE")

local function CreateBlizzardEditBox(parent, x, y, width, name)
    local eb = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    eb:SetSize(width, 24)
    eb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal")
    eb:SetTextInsets(4, 4, 0, 0)
    return eb
end

local function GetDefaultColor()
    return { r = 0.5, g = 0.95, b = 0.8 }
end

local function SetTooltip(widget, uText)
    widget:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT") GameTooltip:SetText(uText, 1, 1, 1, nil, true) GameTooltip:Show() end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

RAY_EventFrame:RegisterEvent("ADDON_LOADED")
RAY_EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
RAY_EventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if not RAY_Config then 
            RAY_Config = CopyTable(defaultSettings)
        else
            if RAY_Config.enabled == nil then RAY_Config.enabled = true end
            if RAY_Config.fontSize == nil then RAY_Config.fontSize = 24 end
            if RAY_Config.radarEnabled == nil then RAY_Config.radarEnabled = false end
            if RAY_Config.boxHunterEnabled == nil then RAY_Config.boxHunterEnabled = true end
            if not RAY_Config.spells then RAY_Config.spells = {} end
            if not RAY_Config.framePos then RAY_Config.framePos = { point = "CENTER", x = 0, y = 150 } end
            if not RAY_Config.specSettings then 
                RAY_Config.specSettings = CopyTable(defaultSettings.specSettings)
            else
                for i = 1, 2 do
                    if not RAY_Config.specSettings[i] then RAY_Config.specSettings[i] = { sets = {}, buffs = {}, icds = {} } end
                    if not RAY_Config.specSettings[i].sets then RAY_Config.specSettings[i].sets = {} end
                    if not RAY_Config.specSettings[i].buffs then RAY_Config.specSettings[i].buffs = {} end
                    if not RAY_Config.specSettings[i].icds then RAY_Config.specSettings[i].icds = {} end
                end
            end
        end
        
        for _, spell in ipairs(RAY_Config.spells or {}) do
            if not spell.color then spell.color = GetDefaultColor() end
        end

        if RAY_MainFrame and RAY_Config.framePos then
            RAY_MainFrame:ClearAllPoints()
            RAY_MainFrame:SetPoint(RAY_Config.framePos.point, UIParent, RAY_Config.framePos.point, RAY_Config.framePos.x, RAY_Config.framePos.y)
            RAY_MainFrame:SetScale((RAY_Config.fontSize or 24) / 24)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        DEFAULT_CHAT_FRAME:AddMessage(PASTEL_TITLE .. "RAY - Remember About Yourself|r загружен. Настройка: /ray")
    end
end)

-- =========================================================================
-- 2. СОЗДАНИЕ ГЛАВНОГО И ДОПОЛНИТЕЛЬНЫХ ОКН НА ЭКРАНЕ
-- =========================================================================
local function SetupDragAndPosition(f, configStorage)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) 
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint() 
        configStorage.framePos = { point = p, x = x, y = y } 
    end)
end

local frame = CreateFrame("Frame", "RAY_MainFrame", UIParent)
frame:SetSize(400, 60) 
frame:SetPoint("CENTER", 0, 150) 
SetupDragAndPosition(frame, RAY_Config or defaultSettings)
frame:Hide()

local dragBg, dragBorder = frame:CreateTexture(nil, "BACKGROUND"), frame:CreateTexture(nil, "OVERLAY")
dragBg:SetAllPoints() dragBg:SetTexture(0.1, 0.1, 0.1, 0.6) dragBg:Hide()
dragBorder:SetAllPoints() dragBorder:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border") dragBorder:Hide()

local text = frame:CreateFontString("RAY_MainFrameText", "OVERLAY", "GameFontNormalLarge")
text:SetPoint("CENTER", frame, "CENTER") text:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE") text:SetTextColor(0.5, 0.95, 0.8) text:SetJustifyH("CENTER")

local animGroup = frame:CreateAnimationGroup()
local fadeOut = animGroup:CreateAnimation("Alpha") fadeOut:SetChange(-0.6) fadeOut:SetDuration(0.5) fadeOut:SetOrder(1)
local fadeIn = animGroup:CreateAnimation("Alpha") fadeIn:SetChange(0.6) fadeIn:SetDuration(0.5) fadeIn:SetOrder(2)
animGroup:SetLooping("REPEAT")

-- =========================================================================
-- 3. ДВИЖОК ПРОВЕРКИ АУР И СОСТОЯНИЙ
-- =========================================================================
local function GetCurrentZoneType()
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid") then return instanceType end
    if GetNumRaidMembers() > 0 then return "raid" end
    if GetNumPartyMembers() > 0 then return "party" end
    return "world"
end

local function CheckSubRules(data, inCombat, currentZone)
    if not data then return true end
    if data.zoneWorld == false and currentZone == "world" then return false end
    if data.zoneParty == false and currentZone == "party" then return false end
    if data.zoneRaid == false and currentZone == "raid" then return false end
    if data.onlyInCombat and not inCombat then return false end
    return true
end

local function CheckEquipmentSetFull(setName)
    if not setName or setName == "" then return "OK" end
    local numSets = GetNumEquipmentSets()
    local foundIndex = nil
    local setLower = setName:lower()
    
    for i = 1, numSets do 
        local name = GetEquipmentSetInfo(i)
        if name and name:lower() == setLower then 
            foundIndex = i 
            break 
        end 
    end
    
    if not foundIndex then return "NOT_FOUND" end
    
    local setItemIDs = GetEquipmentSetItemIDs(GetEquipmentSetInfo(foundIndex))
    if not setItemIDs then return "NOT_FOUND" end
    
    for slotID = 1, 18 do
        local savedItemID = setItemIDs[slotID]
        if savedItemID and savedItemID > 1 and GetInventoryItemID("player", slotID) ~= savedItemID then 
            return "PARTIAL" 
        end
    end
    return "OK"
end

local function CheckCustomGearEnchant(enchantName)
    local nameLower = enchantName:lower()
    local slotsToScan = { 16, 17, 10, 15 }
    for idx = 1, 4 do
        local slotID = slotsToScan[idx]
        local start, duration = GetInventoryItemCooldown("player", slotID)
        if start and start > 0 and duration and duration > 1.5 then 
            return true, 1, math.ceil(duration - (GetTime() - start))
        end
        textScanFrameMain:ClearLines()
        textScanFrameMain:SetInventoryItem("player", slotID)
        for i = 1, 30 do
            local lineText = _G["RAY_EnchantScannerTooltipMainTextLeft"..i]
            local txt = lineText and lineText:GetText()
            if txt and txt:lower():find(nameLower, 1, true) then
                if slotID == 16 or slotID == 17 then
                    local hasMain, mainExp, _, _, hasOff, offExp = GetWeaponEnchantInfo()
                    if slotID == 16 and hasMain and mainExp then return true, 1, math.floor(mainExp / 1000) end
                    if slotID == 17 and hasOff and offExp then return true, 1, math.floor(offExp / 1000) end
                else
                    return true, 1, 0
                end
            end
        end
    end
    return false, 0, 0
end

local function BuildAuraCache(target, cacheTable)
    wipe(cacheTable)
    for i = 1, 40 do
        local name, _, _, count, _, _, expirationTime, _, _, _, spellID = UnitAura(target, i, "HELPFUL")
        if not name then break end
        local rem = (expirationTime and expirationTime > 0) and math.max(0, math.floor(expirationTime - GetTime())) or 0
        local data = { count = count or 0, rem = rem, filter = "HELPFUL" }
        cacheTable[name:lower()] = data cacheTable[tostring(spellID)] = data
    end
    for i = 1, 40 do
local name, _, _, count, _, _, expirationTime, _, _, _, spellID = UnitAura(target, i, "HARMFUL")
if not name then break end
local rem = (expirationTime and expirationTime > 0) and math.max(0, math.floor(expirationTime - GetTime())) or 0
local data = { count = count or 0, rem = rem, filter = "HARMFUL" }
cacheTable[name:lower()] = data cacheTable[tostring(spellID)] = data
end
end
local function FindAuraCached(target, nameOrId, filter, isCombo, isWeaponText)
if isCombo then local cp = GetComboPoints("player", "target") if cp and cp > 0 then return true, cp, 0 else return false, 0, 0 end end
if isWeaponText then local hasEnchant, fakeStacks, secondsLeft = CheckCustomGearEnchant(nameOrId) return hasEnchant, fakeStacks, secondsLeft end
local cache = (target == "target") and cacheTargetAuras or cachePlayerAuras
local aura = cache[tostring(nameOrId):lower()]
if aura and aura.filter == filter then return true, aura.count, aura.rem end
return false, 0, 0
end
local function CheckAuraGroup(target, spellLine, filter, isCombo, isWeaponText)
local active, currentStacks, minRemaining = false, 0, 999999
for condition in string.gmatch(spellLine, "[^|/]+") do
condition = condition:match("^%s*(.-)%s*$")
local found, stacks, timeLeft = FindAuraCached(target, condition, filter, isCombo, isWeaponText)
if found then active = true currentStacks = math.max(currentStacks, stacks) if timeLeft < minRemaining then minRemaining = timeLeft end end
end
return active, currentStacks, minRemaining
end
local engineEvents = CreateFrame("Frame")
CheckAllAuras = function()
if not RAY_Config or RAY_Config.enabled == false then
text:SetText("") frame:Hide() animGroup:Stop()
for fKey, cf in pairs(customFramesPool) do
cf.text:SetText("") cf:Hide() cf.anim:Stop()
end
engineEvents:UnregisterAllEvents() return
end
if frame:IsMouseEnabled() and frame:IsShown() then return end
local inCombat = UnitAffectingCombat("player")
local currentZone = GetCurrentZoneType()
local currentSpec = GetActiveTalentGroup() or 1
local curTime = GetTime()
wipe(uniqueAlerts) local customAlertsByWindow = {}
BuildAuraCache("player", cachePlayerAuras)
if UnitExists("target") and not UnitIsDead("target") then BuildAuraCache("target", cacheTargetAuras) else wipe(cacheTargetAuras) end
if sylvanasAlertActive and RAY_Config.boxHunterEnabled then
if curTime <= sylvanasAlertActive then
uniqueAlerts["|cffFF5555[RAY Детектор]: Шкатулку завел -> " .. tostring(sylvanasAlertActivePlayer or "Неизвестно") .. "!|r"] = true
else
sylvanasAlertActive = false sylvanasAlertActivePlayer = nil
end
end
if RAY_Config.specSettings and RAY_Config.specSettings[currentSpec] then
local configData = RAY_Config.specSettings[currentSpec]
if configData.sets then
for i = 1, 10 do
local set = configData.sets[i]
if set and set.name and set.name ~= "" and CheckSubRules(set, inCombat, currentZone) then
local status = CheckEquipmentSetFull(set.name)
if status == "NOT_FOUND" then uniqueAlerts["RAY: Комплект [" .. set.name .. "] не найден!"] = true
elseif status == "PARTIAL" then uniqueAlerts["RAY: Комплект [" .. set.name .. "] не полн!"] = true end
end
end
end
if configData.buffs then
for i = 1, 10 do
local buff = configData.buffs[i]
if buff and buff.name and buff.name ~= "" and CheckSubRules(buff, inCombat, currentZone) and not CheckAuraGroup("player", buff.name, "HELPFUL", false, false) then
uniqueAlerts["RAY: Включи [" .. buff.name .. "]!"] = true
end
end
end
if configData.icds then
for i = 1, 10 do
local data = configData.icds[i]
if data and data.name and data.name ~= "" and CheckSubRules(data, inCombat, currentZone) then
local endTime = activeICDTimers[data.name:lower()]
local isAuraActive = CheckAuraGroup("player", data.name, "HELPFUL", false, false)
if not isAuraActive and endTime and endTime > curTime then
local remainingCD = endTime - curTime
local baseCD, alertWindow = tostring(data.seconds or "45"):match("([^/]+)/?([^/])")
alertWindow = tonumber(alertWindow) or 0
if alertWindow == 0 or remainingCD <= alertWindow then uniqueAlerts["RAY: КД " .. data.name .. " (" .. math.ceil(remainingCD) .. " сек)"] = true end
end
end
end
end
end
for i = 1, 100 do
local spellData = RAY_Config.spells[i]
if spellData and spellData.name and spellData.name ~= "" and CheckSubRules(spellData, inCombat, currentZone) then
local limitStacks = tonumber(spellData.minStacks) or 0
local userAlertTime = tonumber(spellData.alertTime) or 0
local prefix = (spellData.isCombo) and " КП" or " ст"
if spellData.isCooldown then
local start, duration = GetSpellCooldown(spellData.name)
if not (start and start > 0 and duration and duration > 1.5) then
local displayName = string.match(spellData.name, "[^|/]+") or spellData.name
local msg = "RAY: Готово! Прожми [" .. displayName .. "]"
if spellData.isOwnWindow then customAlertsByWindow[spellData.name] = { text = msg, color = spellData.color, size = spellData.customSize } else uniqueAlerts[msg] = true end
end
else
local target = spellData.target or "player"
if target ~= "target" or (UnitExists("target") and not UnitIsDead("target")) then
local filter = (spellData.mode == "DEBUFF") and "HARMFUL" or "HELPFUL"
local isActive, stacks, timeLeft = CheckAuraGroup(target, spellData.name, filter, spellData.isCombo, spellData.isWeaponText)
if not isActive and spellData.isProc and IsUsableSpell(spellData.name) then isActive = true stacks = 0 timeLeft = 9999 end
local needAlert, customReason = false, ""
if not isActive then
if spellData.isStackProgress and limitStacks > 0 then needAlert = true customReason = " (0/" .. limitStacks .. prefix .. ")"
elseif not spellData.isProc and not spellData.isCombo then needAlert = true end
else
if spellData.isHideCap and limitStacks > 0 and (stacks >= limitStacks) then
if userAlertTime > 0 and timeLeft <= userAlertTime then needAlert = true customReason = " (" .. timeLeft .. " сек)" end
elseif spellData.isStackProgress and limitStacks > 0 then
if stacks < limitStacks then needAlert = true customReason = " (" .. stacks .. "/" .. limitStacks .. prefix .. ")" end
else
if limitStacks > 0 and (stacks <= limitStacks) then needAlert = true customReason = " (Осталось: " .. stacks .. prefix .. ")"
elseif userAlertTime > 0 and timeLeft <= userAlertTime then needAlert = true customReason = " (" .. timeLeft .. " сек)"
elseif spellData.isProc or spellData.isCombo then
needAlert = true
local displayStacks = (stacks > 0 and limitStacks > 0) and (" (" .. stacks .. prefix .. ")") or ""
local displayTime = (userAlertTime > 0 and timeLeft <= userAlertTime and timeLeft < 9000) and (" " .. timeLeft .. " сек") or ""
customReason = displayStacks .. displayTime
end
end
end
if limitStacks == 0 then customReason = string.gsub(customReason, "%s%(.-ст%)%s*", ""):gsub("%s*%(Осталось:.-%)%s*", "") end
if needAlert then
local displayName = string.match(spellData.name, "[^|/]+") or spellData.name
if spellData.isCombo then displayName = "Серия приёмов (КП)" end
local msg = (spellData.mode == "DEBUFF" and "RAY: Наложи дебафф [" or spellData.isProc and "RAY: Прок! [" or "RAY: Обнови бафф [") .. displayName .. "]" .. customReason
if spellData.isOwnWindow then customAlertsByWindow[spellData.name] = { text = msg, color = spellData.color, size = spellData.customSize } else uniqueAlerts[msg] = true end
end
end
end
end
end
wipe(alertStringTable)
for k, _ in pairs(uniqueAlerts) do table.insert(alertStringTable, k) end
if #alertStringTable > 0 then
text:SetText(table.concat(alertStringTable, "\n"))
local gSize = RAY_Config.fontSize or 24 text:SetFont("Fonts\FRIZQT__.TTF", gSize, "OUTLINE")
if not frame:IsShown() then frame:Show() animGroup:Play() end
else
frame:Hide() animGroup:Stop()
end
for fWindowKey, cf in pairs(customFramesPool) do
local data = customAlertsByWindow[fWindowKey]
if data then
cf.text:SetText(data.text) local c = data.color or GetDefaultColor() cf.text:SetTextColor(c.r, c.g, c.b)
local sz = data.size or 24 cf.text:SetFont("Fonts\FRIZQT__.TTF", sz, "OUTLINE")
if not cf:IsShown() then cf:Show() cf.anim:Play() end
else
if not cf:IsMouseEnabled() then cf:Hide() cf.anim:Stop() end
end
end
end
-- =========================================================================
-- СОБЫТИЯ КОМБАТА И ДЕТЕКТОР ШКАТУЛОК
-- =========================================================================
local combatLogFrame = CreateFrame("Frame")
combatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
combatLogFrame:SetScript("OnEvent", function(self, event, ...)
local subEvent, sourceName, destName, spellID, spellName = select(2, ...), select(4, ...), select(7, ...), select(9, ...), select(10, ...)
if subEvent == "SPELL_AURA_APPLIED" and spellName and type(spellName) == "string" then
if RAY_Config and RAY_Config.radarEnabled then
DEFAULT_CHAT_FRAME:AddMessage("|cffFFD369[RAY Радар]|r |cffA8FF35" .. tostring(sourceName or "Неизвестно") .. "|r применил: |cff4ECCA3" .. tostring(spellName) .. "|r (" .. tostring(spellID) .. ")")
end
if destName == UnitName("player") then
local currentSpec = GetActiveTalentGroup() or 1
if RAY_Config.specSettings and RAY_Config.specSettings[currentSpec] and RAY_Config.specSettings[currentSpec].icds then
local combatSpellLower, combatSpellID = spellName:lower(), tostring(spellID)
for i = 1, 10 do
local data = RAY_Config.specSettings[currentSpec].icds[i]
if data and type(data) == "table" and data.name then
local nameLower = data.name:lower()
if nameLower == combatSpellLower or nameLower == combatSpellID then
local baseCD = tostring(data.seconds or "45"):match("([^/]+)")
activeICDTimers[nameLower] = GetTime() + (tonumber(baseCD) or 45) CheckAllAuras() break
end
end
end
end
end
end
end)
local sylvanasHunterFrame = CreateFrame("Frame")
sylvanasHunterFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
sylvanasHunterFrame:SetScript("OnEvent", function(_, event, unit, spellName)
if not RAY_Config or not RAY_Config.boxHunterEnabled then return end
if event == "UNIT_SPELLCAST_SUCCEEDED" and spellName == "Плач высокорожденных" then
if UnitInRaid(unit) or UnitInParty(unit) or unit == "player" then
local joker = UnitName(unit) or "Кто-то в рейде" sylvanasAlertActive = GetTime() + 7 sylvanasAlertActivePlayer = joker
DEFAULT_CHAT_FRAME:AddMessage("RAY Детектор: Обнаружена шкатулка Сильваны! Шутник: " .. joker)
local msgText = "[RAY Детектор]: Игрок " .. joker .. " запустил Шкатулку Сильваны!"
if GetNumRaidMembers() > 0 then SendChatMessage(msgText, "RAID") elseif GetNumPartyMembers() > 0 then SendChatMessage(msgText, "PARTY") end
if IsInGuild() then SendChatMessage(msgText, "OFFICER") end CheckAllAuras()
end
end
end)
for _, e in ipairs({"UNIT_AURA", "UNIT_INVENTORY_CHANGED", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ACTIONBAR_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "ACTIVE_TALENT_GROUP_CHANGED", "ZONE_CHANGED_NEW_AREA"}) do
engineEvents:RegisterEvent(e)
end
engineEvents:SetScript("OnEvent", function() CheckAllAuras() end)
-- =========================================================================
-- 4. ЕДИНЫЙ ЦЕНТР РЕГИСТРАЦИИ ИНТЕРФЕЙСА BLIZZARD
-- =========================================================================
local shortcutFrame = CreateFrame("Frame")
shortcutFrame:RegisterEvent("PLAYER_LOGIN")
shortcutFrame:SetScript("OnEvent", function()
optionsPanel = CreateFrame("Frame", "RAY_MainOptionsPanel", UIParent)
optionsPanel.name = "RAY"
local title = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16) title:SetText(PASTEL_TITLE .. "Модификация RAY (Remember About Yourself)|r")
local mainCb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
mainCb:SetPoint("TOPLEFT", 16, -55)
local mainCbText = mainCb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
mainCbText:SetPoint("LEFT", mainCb, "RIGHT", 5, 1) mainCbText:SetText("RAY-оповещения")
mainCb:SetScript("OnShow", function(self) self:SetChecked(RAY_Config.enabled) end)
mainCb:SetScript("OnClick", function(self) RAY_Config.enabled = self:GetChecked() and true or false CheckAllAuras() end)
SetTooltip(mainCb, "Включение или полное отключение отображения всех аур и предупреждений мода RAY на вашем экране.")
local dragCb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
dragCb:SetPoint("TOPLEFT", 16, -95)
local dragCbText = dragCb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dragCbText:SetPoint("LEFT", dragCb, "RIGHT", 5, 1) dragCbText:SetText(PASTEL_YELLOW .. "Move|r")
dragCb:SetScript("OnClick", function(self)
local enabled = self:GetChecked()
if enabled then
frame:EnableMouse(true) dragBg:Show() dragBorder:Show() text:SetText(PASTEL_TITLE .. "[RAY]: Главное окно|r")
if not frame:IsShown() then frame:Show() animGroup:Play() end
for fDragKey, cf in pairs(customFramesPool) do
cf:EnableMouse(true) cf.bg:Show() cf.border:Show() cf.text:SetText("[Окно]: " .. fDragKey)
if not cf:IsShown() then cf:Show() cf.anim:Play() end
end
else
frame:EnableMouse(false) dragBg:Hide() dragBorder:Hide() animGroup:Stop()
for fDragHideKey, cf in pairs(customFramesPool) do cf:EnableMouse(false) cf.bg:Hide() cf.border:Hide() cf.anim:Stop() end
CheckAllAuras()
end
end)
SetTooltip(dragCb, "Режим перемещения окон. Включает видимые границы и позволяет перетаскивать мышкой главное и независимые окна аур в любое место экрана.")
local radarCb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
radarCb:SetPoint("TOPLEFT", 16, -135)
local radarCbText = radarCb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
radarCbText:SetPoint("LEFT", radarCb, "RIGHT", 5, 1) radarCbText:SetText(PASTEL_DEBUFF .. "RAY-Radar|r")
radarCb:SetScript("OnShow", function(self) self:SetChecked(RAY_Config.radarEnabled) end)
radarCb:SetScript("OnClick", function(self) RAY_Config.radarEnabled = self:GetChecked() end)
SetTooltip(radarCb, "Включает подробное логирование всех применяемых вокруг вас аур, заклинаний и баффов напрямую в окно главного чата.")
local hunterCb = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
hunterCb:SetPoint("TOPLEFT", 16, -175)
local hunterCbText = hunterCb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
hunterCbText:SetPoint("LEFT", hunterCb, "RIGHT", 5, 1) hunterCbText:SetText(PASTEL_BUFF .. "Box Detector|r")
hunterCb:SetScript("OnShow", function(self) self:SetChecked(RAY_Config.boxHunterEnabled) end)
hunterCb:SetScript("OnClick", function(self) RAY_Config.boxHunterEnabled = self:GetChecked() sylvanasAlertActive = false CheckAllAuras() end)
SetTooltip(hunterCb, "Детектор Шкатулки Сильваны. Автоматически вычисляет игрока, запустившего 'Плач высокорожденных', пишет имя шутника в чат и дублирует оповещение в каналы.")
local btnClear = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
btnClear:SetSize(140, 30) btnClear:SetPoint("TOPLEFT", 16, -225) btnClear:SetText("|cffFF7676Полный сброс|r")
btnClear:SetScript("OnClick", function() RAY_Config = nil ReloadUI() end)
SetTooltip(btnClear, "Внимание! Полностью стирает всю базу данных ваших сохраненных настроек, профилей аур и перезагружает игровой интерфейс.")
InterfaceOptions_AddCategory(optionsPanel)
-- СБОРКА СТРАНИЦ БАФФОВ И ДЕБАФФОВ
local function BuildVerticalAuraPage(panelName, modeType, textColor, globalSelectedIndexRef, listButtonsRef)
local panel = CreateFrame("Frame", "RAY_Panel_"..panelName, optionsPanel)
panel.name = panelName panel.parent = "RAY"
local sFrame = CreateFrame("ScrollFrame", "RAY_Scroll_"..panelName, panel, "UIPanelScrollFrameTemplate")
sFrame:SetPoint("TOPLEFT", 8, -40) sFrame:SetPoint("BOTTOMRIGHT", -28, 8)
local sChild = CreateFrame("Frame", nil, sFrame)
sChild:SetSize(380, 1050) sFrame:SetScrollChild(sChild)
local pTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
pTitle:SetPoint("TOPLEFT", 16, -14) pTitle:SetText(textColor.."Управление отслеживанием: "..panelName.."|r")
local editBox = CreateBlizzardEditBox(sChild, 8, -30, 240, "RAY_EBox_"..panelName)
local elabel = sChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
elabel:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 2, 6) elabel:SetText("Название эффекта / ID способности (через '/' = ИЛИ):")
local btnOk = CreateFrame("Button", nil, sChild, "UIPanelButtonTemplate")
btnOk:SetSize(55, 25) btnOk:SetPoint("LEFT", editBox, "RIGHT", 8, 0) btnOk:SetText(PASTEL_YELLOW.."ОК|r")
local dropDown = CreateFrame("Frame", "RAY_VDrop_"..panelName, sChild, "UIDropDownMenuTemplate")
dropDown:SetPoint("TOPLEFT", -2, -75) dropDown:SetSize(150, 25)
local tempConfig = { onlyInCombat = false, zoneWorld = false, zoneParty = false, zoneRaid = false, target = (modeType == "DEBUFF" and "target" or "player"), isCooldown = false, isProc = false, isCombo = false, isWeaponText = false, isStackProgress = false, isHideCap = false, isOwnWindow = false, customSize = 24, color = GetDefaultColor() }
local function GetActiveIndex() return _G[globalSelectedIndexRef] end
local function SetActiveIndex(val) _G[globalSelectedIndexRef] = val end
local currentY = -120
local function AddVerticalCheckbox(label, tText, key)
local cb = CreateFrame("CheckButton", nil, sChild, "InterfaceOptionsCheckButtonTemplate")
cb:SetPoint("TOPLEFT", 8, currentY) cb:SetScale(0.9)
local t = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
t:SetPoint("LEFT", cb, "RIGHT", 5, 1) t:SetText(textColor..label.."|r")
cb:SetScript("OnClick", function(self)
local idx = GetActiveIndex() local val = self:GetChecked() and true or false
if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx][key] = val CheckAllAuras() else tempConfig[key] = val end
end)
SetTooltip(cb, tText)
currentY = currentY - 28
return cb
end
local cbCombat   = AddVerticalCheckbox("Включать только в бою", "Показывать предупреждение исключительно в бою.", "onlyInCombat")
local cbWorld    = AddVerticalCheckbox("Отслеживать в открытом мире", "Проверять условия в открытых локациях.", "zoneWorld")
local cbParty    = AddVerticalCheckbox("Отслеживать в подземельях (5ппл)", "Проверять в подземельях.", "zoneParty")
local cbRaid     = AddVerticalCheckbox("Отслеживать в рейдовых зонах", "Проверять в рейдах.", "zoneRaid")
local cbCooldown = AddVerticalCheckbox("Отслеживать готовность КД", "Строгая проверка КД кнопки, игнорируя наличие баффа.", "isCooldown")
local cbProc     = AddVerticalCheckbox("Это прок (активен до траты)", "Оповещение будет гореть постоянно, пока эффект висит.", "isProc")
local cbCombo    = AddVerticalCheckbox("Это комбо-поинты (КП)", "Специфично для серий приёмов Друидов/Разбойников.", "isCombo")
local cbWeapon   = AddVerticalCheckbox("Чары инженерии / оружия", "Сканировать внутренние проки оружия и чар.", "isWeaponText")
local cbProgress = AddVerticalCheckbox("Показывать набор стаков", "Выводить на экран цифры стаков, например (2/5).", "isStackProgress")
local cbHideCap  = AddVerticalCheckbox("Скрыть при полном капе стаков", "Прятать текст, когда набран максимум стаков.", "isHideCap")
currentY = currentY - 20
local specSlider = CreateFrame("Slider", "RAY_VSlider_"..panelName, sChild, "OptionsSliderTemplate")
specSlider:SetSize(180, 16) specSlider:SetPoint("TOPLEFT", 12, currentY) specSlider:SetMinMaxValues(12, 48) specSlider:SetValueStep(1)
local ssText = specSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") ssText:SetPoint("BOTTOMLEFT", specSlider, "TOPLEFT", 0, 4)
specSlider:SetScript("OnValueChanged", function(self, value)
local val = math.floor(value) ssText:SetText("Размер шрифта: " .. val)
local idx = GetActiveIndex() if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx].customSize = val CheckAllAuras() else tempConfig.customSize = val end
end)
-- ИДЕАЛЬНОЕ ЖЕСТКОЕ ПОЗИЦИОНИРОВАНИЕ НА ОТДЕЛЬНОЙ СТРОКЕ (Полная ликвидация прыжков координат)
local rowY = -455
local cbOwnWindow = CreateFrame("CheckButton", "RAY_OwnWinCheck_"..panelName, sChild, "InterfaceOptionsCheckButtonTemplate")
cbOwnWindow:SetSize(26, 26)
cbOwnWindow:SetPoint("TOPLEFT", sChild, "TOPLEFT", 12, rowY)
local cbTextObj = _G[cbOwnWindow:GetName() .. "Text"]
if cbTextObj then
cbTextObj:SetText(textColor .. "Окно|r")
cbTextObj:ClearAllPoints()
cbTextObj:SetPoint("LEFT", cbOwnWindow, "RIGHT", 4, 1)
end
cbOwnWindow:SetScript("OnClick", function(self)
local idx = GetActiveIndex() local val = self:GetChecked() and true or false
if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx].isOwnWindow = val CheckAllAuras() else tempConfig.isOwnWindow = val end
end)
SetTooltip(cbOwnWindow, "Вывести данное оповещение в отдельное независимое окно, которое можно свободно двигать в режиме /move.")
local colorBtn = CreateFrame("Button", nil, sChild)
colorBtn:SetSize(18, 18)
-- Устанавливаем ровно рядом: отступ 110 пикселей по оси X вправо от чекбокса
colorBtn:SetPoint("TOPLEFT", sChild, "TOPLEFT", 110, rowY - 4)
local cTex = colorBtn:CreateTexture(nil, "BACKGROUND") cTex:SetAllPoints() cTex:SetTexture(0.5, 0.95, 0.8) colorBtn.tex = cTex
local border = colorBtn:CreateTexture(nil, "BORDER") border:SetPoint("TOPLEFT", -1, 1) border:SetPoint("BOTTOMRIGHT", 1, -1) border:SetTexture(0.5, 0.5, 0.5, 0.8)
local colorLbl = colorBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") colorLbl:SetPoint("LEFT", colorBtn, "RIGHT", 6, 1) colorLbl:SetText("Палитра")
local function ColorCallback()
local r, g, b = ColorPickerFrame:GetColorRGB() colorBtn.tex:SetVertexColor(r, g, b)
local idx = GetActiveIndex() if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx].color = { r = r, g = g, b = b } CheckAllAuras() else tempConfig.color = { r = r, g = g, b = b } end
end
colorBtn:SetScript("OnClick", function()
local idx = GetActiveIndex() local current = (idx and RAY_Config.spells[idx] and RAY_Config.spells[idx].color) or tempConfig.color or GetDefaultColor()
ColorPickerFrame.func = ColorCallback ColorPickerFrame.hasOpacity = false ColorPickerFrame:SetColorRGB(current.r, current.g, current.b)
ColorPickerFrame:SetFrameStrata("TOOLTIP")
ColorPickerFrame:Hide() ColorPickerFrame:Show()
end)
SetTooltip(colorBtn, "Открыть стандартную палитру цветов Blizzard для настройки окраски текста этой ауры.")
-- ПОЛЗУНКИ СДВИНУТЫ ЕЩЕ НИЖЕ С ЖЕСТКИМ ШАГОМ ОТ СТРОКИ ДЕЙСТВИЙ
currentY = rowY - 40
local sliderTime = CreateFrame("Slider", "RAY_VTime_"..panelName, sChild, "OptionsSliderTemplate")
sliderTime:SetSize(110, 16) sliderTime:SetPoint("TOPLEFT", 12, currentY) sliderTime:SetMinMaxValues(0, 300) sliderTime:SetValueStep(1)
local stText = sliderTime:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") stText:SetPoint("BOTTOMLEFT", sliderTime, "TOPLEFT", 0, 4)
sliderTime:SetScript("OnValueChanged", function(self, value) local val = math.floor(value) stText:SetText("Время (сек): " .. val) local idx = GetActiveIndex() if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx].alertTime = val CheckAllAuras() end end)
local sliderStacks = CreateFrame("Slider", "RAY_VStk_"..panelName, sChild, "OptionsSliderTemplate")
sliderStacks:SetSize(110, 16) sliderStacks:SetPoint("TOPLEFT", sChild, "TOPLEFT", 160, currentY)
local ssText2 = sliderStacks:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") ssText2:SetPoint("BOTTOMLEFT", sliderStacks, "TOPLEFT", 0, 4)
sliderStacks:SetScript("OnValueChanged", function(self, value) local val = math.floor(value) ssText2:SetText("Порог стаков: " .. val) local idx = _G[globalSelectedIndexRef] if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx].minStacks = val CheckAllAuras() end end)
currentY = currentY - 45
local listHeader = sChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
listHeader:SetPoint("TOPLEFT", 8, currentY) listHeader:SetText(PASTEL_GRAY .. "Список сохраненных настроек:|r")
currentY = currentY - 24
local listFrame = CreateFrame("Frame", nil, sChild)
listFrame:SetSize(320, 200) listFrame:SetPoint("TOPLEFT", 8, currentY)
UIDropDownMenu_Initialize(dropDown, function()
local currentIdx = GetActiveIndex() local activeTarget = currentIdx and RAY_Config.spells[currentIdx].target or tempConfig.target local info = UIDropDownMenu_CreateInfo()
info.text = "Цель: Игрок" info.value = "player" info.checked = (activeTarget == "player") info.func = function() local ai = GetActiveIndex() if ai and RAY_Config.spells[ai] then RAY_Config.spells[ai].target = "player" else tempConfig.target = "player" end UIDropDownMenu_SetSelectedValue(dropDown, "player") UIDropDownMenu_SetText(dropDown, "Цель: Игрок") CheckAllAuras() CloseDropDownMenus() end UIDropDownMenu_AddButton(info)
info.text = "Цель: Тек. цель" info.value = "target" info.checked = (activeTarget == "target") info.func = function() local ai = GetActiveIndex() if ai and RAY_Config.spells[ai] then RAY_Config.spells[ai].target = "target" else tempConfig.target = "target" end UIDropDownMenu_SetSelectedValue(dropDown, "target") UIDropDownMenu_SetText(dropDown, "Цель: Тек. цель") CheckAllAuras() CloseDropDownMenus() end UIDropDownMenu_AddButton(info)
end)
local function SetFields(data)
if data then
editBox:SetText(data.name or "") UIDropDownMenu_SetSelectedValue(dropDown, data.target or "player") UIDropDownMenu_SetText(dropDown, data.target == "target" and "Цель: Тек. цель" or "Цель: Игрок") sliderTime:SetValue(data.alertTime or 0) sliderStacks:SetValue(data.minStacks or 0) cbCombat:SetChecked(data.onlyInCombat == true) cbWorld:SetChecked(data.zoneWorld == true) cbParty:SetChecked(data.zoneParty == true) cbRaid:SetChecked(data.zoneRaid == true) cbCooldown:SetChecked(data.isCooldown == true) cbProc:SetChecked(data.isProc == true) cbCombo:SetChecked(data.isCombo == true) cbWeapon:SetChecked(data.isWeaponText == true) cbProgress:SetChecked(data.isStackProgress == true) cbHideCap:SetChecked(data.isHideCap == true) cbOwnWindow:SetChecked(data.isOwnWindow == true) specSlider:SetValue(data.customSize or 24) local c = data.color or GetDefaultColor() colorBtn.tex:SetVertexColor(c.r, c.g, c.b)
else
editBox:SetText("") sliderTime:SetValue(0) sliderStacks:SetValue(0) specSlider:SetValue(24) cbCombat:SetChecked(false) cbWorld:SetChecked(false) cbParty:SetChecked(false) cbRaid:SetChecked(false) cbCooldown:SetChecked(false) cbProc:SetChecked(false) cbCombo:SetChecked(false) cbWeapon:SetChecked(false) cbProgress:SetChecked(false) cbHideCap:SetChecked(false) cbOwnWindow:SetChecked(false) local c = GetDefaultColor() colorBtn.tex:SetVertexColor(c.r, c.g, c.b) UIDropDownMenu_SetSelectedValue(dropDown, modeType == "DEBUFF" and "target" or "player") UIDropDownMenu_SetText(dropDown, modeType == "DEBUFF" and "Цель: Тек. цель" or "Цель: Игрок")
end
end
local function ListButton_OnClick(self)
SetActiveIndex(self.spellIndex) for _, b in ipairs(_G[listButtonsRef]) do b:UnlockHighlight() end
self:LockHighlight() SetFields(RAY_Config.spells[self.spellIndex])
end
local function ListDelete_OnClick(self)
local p = self:GetParent() table.remove(RAY_Config.spells, p.spellIndex)
SetActiveIndex(nil) SetFields(nil) updateSpellLists() CheckAllAuras()
end
local function LocalUpdateLists()
for _, b in ipairs(_G[listButtonsRef]) do b:Hide() end local count = 1
for i, spellData in ipairs(RAY_Config.spells or {}) do
if spellData.mode == modeType then
local buttonsList = _G[listButtonsRef] local btn = buttonsList[count]
if not btn then
btn = CreateFrame("Button", nil, listFrame) btn:SetSize(280, 22) btn:SetNormalFontObject("GameFontNormal") btn:SetHighlightTexture("Interface\Buttons\UI-Listbox-Highlight")
local del = CreateFrame("Button", nil, btn, "UIPanelCloseButton") del:SetSize(20, 20) del:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
btn.delBtn = del btn:SetScript("OnClick", ListButton_OnClick) btn.delBtn:SetScript("OnClick", ListDelete_OnClick) buttonsList[count] = btn
end
btn.spellIndex = i btn:ClearAllPoints() btn:SetPoint("TOPLEFT", 0, -((count - 1) * 26))
btn:SetText(textColor .. (string.match(spellData.name, "[^|/]+") or "Пусто") .. "|r") btn:Show()
if GetActiveIndex() == i then btn:LockHighlight() else btn:UnlockHighlight() end count = count + 1
end
end
local totalHeight = math.abs(currentY) + (count * 26) + 50
sChild:SetHeight(math.max(1000, totalHeight))
end
btnOk:SetScript("OnClick", function()
local txt = editBox:GetText() if not txt or txt == "" or txt == " " then return end
local idx = GetActiveIndex() local finalColor = (idx and RAY_Config.spells[idx] and RAY_Config.spells[idx].color) or tempConfig.color or GetDefaultColor()
local item = { name = txt, mode = modeType, target = UIDropDownMenu_GetSelectedValue(dropDown) or tempConfig.target, minStacks = math.floor(sliderStacks:GetValue()), alertTime = math.floor(sliderTime:GetValue()), onlyInCombat = cbCombat:GetChecked() and true or false, zoneWorld = cbWorld:GetChecked() and true or false, zoneParty = cbParty:GetChecked() and true or false, zoneRaid = cbRaid:GetChecked() and true or false, isCooldown = cbCooldown:GetChecked() and true or false, isProc = cbProc:GetChecked() and true or false, isCombo = cbCombo:GetChecked() and true or false, isWeaponText = cbWeapon:GetChecked() and true or false, isStackProgress = cbProgress:GetChecked() and true or false, isHideCap = cbHideCap:GetChecked() and true or false, isOwnWindow = cbOwnWindow:GetChecked() and true or false, customSize = math.floor(specSlider:GetValue()), color = finalColor }
if idx and RAY_Config.spells[idx] then RAY_Config.spells[idx] = item else table.insert(RAY_Config.spells, item) end
SetActiveIndex(nil) SetFields(nil) LocalUpdateLists() CheckAllAuras()
end)
panel:HookScript("OnShow", function() SetActiveIndex(nil) SetFields(nil) LocalUpdateLists() end)
InterfaceOptions_AddCategory(panel) return LocalUpdateLists
end
_G["selBuffIdxG"] = nil _G["selDebIdxG"] = nil
_G["listBtnBufG"] = listButtonsBuff _G["listBtnDebG"] = listButtonsDebuff
local updateBuffs = BuildVerticalAuraPage("RAY-buffs", "BUFF", PASTEL_BUFF, "selBuffIdxG", "listBtnBufG")
local updateDebuffs = BuildVerticalAuraPage("RAY-debuffs", "DEBUFF", PASTEL_DEBUFF, "selDebIdxG", "listBtnDebG")
updateSpellLists = function() updateBuffs() updateDebuffs() end
-- 3. СТРАНИЦА НАСТРОЕК КОМПЛЕКТОВ И ВЕТОК (RAY-sets)
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
if self.isIcd then self.boxName:SetText(data.name or "") self.boxSec:SetText(data.seconds or "45") else self.editBox:SetText(data.name or "") end
self.cbCombat:SetChecked(data.onlyInCombat == true) self.cbWorld:SetChecked(data.zoneWorld == true) self.cbParty:SetChecked(data.zoneParty == true) self.cbRaid:SetChecked(data.zoneRaid == true)
end
end
local function SubDeleteButton_OnClick(self)
local parent = self:GetParent() table.remove(RAY_Config.specSettings[parent.specNum][parent.storageKey], parent.itemIndex)
parent.activeIndices[parent.storageKey] = nil
if parent.isIcd then parent.boxName:SetText("") parent.boxSec:SetText("") else parent.editBox:SetText("") end
RefreshLocalSubList(parent.specNum, parent.storageKey) CheckAllAuras()
end
RefreshLocalSubList = function(specNum, storageKey)
local pBlock = listButtonsSub[specNum][storageKey]
for _, b in ipairs(pBlock) do b:Hide() end
if not RAY_Config or not RAY_Config.specSettings or not RAY_Config.specSettings[specNum] or not RAY_Config.specSettings[specNum][storageKey] then return end
for idx, data in ipairs(RAY_Config.specSettings[specNum][storageKey]) do
local isIcd = (storageKey == "icds")
local textStr = type(data) == "table" and ((data.name or "Ошибка") .. (isIcd and (" ("..(data.seconds or "45").."с)") or "")) or tostring(data)
local btn = pBlock[idx]
if not btn then
btn = CreateFrame("Button", nil, pBlock.listFrame) btn:SetSize(280, 22) btn:SetNormalFontObject("GameFontNormal") btn:SetHighlightTexture("Interface\Buttons\UI-Listbox-Highlight")
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
local container = CreateFrame("Frame", "RAY_Spec"..specNum.."Block_"..storageKey, scrollChild)
container:SetSize(360, 230)
container:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", hOffsetSub, blockTopY)
local editBox, boxName, boxSec
if isIcd then
boxName = CreateBlizzardEditBox(container, 0, -25, 160, "RAY_SIcdN_"..specNum..""..storageKey) SetTooltip(boxName, tText)
boxSec = CreateBlizzardEditBox(container, 175, -25, 45, "RAY_SIcdS"..specNum..""..storageKey) boxSec:SetMaxLetters(7)
editBox = boxName
else
editBox = CreateBlizzardEditBox(container, 0, -25, 220, "RAY_SInp"..specNum.."_"..storageKey) SetTooltip(editBox, tText)
end
local label = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 2, 6) label:SetText(headerColorCode .. labelTxt .. "|r")
local btnOk = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
btnOk:SetSize(45, 24) btnOk:SetPoint("LEFT", isIcd and boxSec or editBox, "RIGHT", 8, 0) btnOk:SetText(PASTEL_YELLOW.."ОК|r")
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
local cbWorld  = CreateSubCheckbox("В открытом мире", 80, "zoneWorld")
local cbParty  = CreateSubCheckbox("В подземельях", 105, "zoneParty")
local cbRaid   = CreateSubCheckbox("В рейдовых зонах", 130, "zoneRaid")
local listFrame = CreateFrame("Frame", nil, container)
listFrame:SetSize(280, 85)
listFrame:SetPoint("TOPLEFT", editBox, "TOPLEFT", 2, -165)
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
local itemData = { name = txt, seconds = isIcd and (boxSec:GetText() or "45") or nil, onlyInCombat = cbCombat:GetChecked() and true or false, zoneWorld = cbWorld:GetChecked() and true or false, zoneParty = cbParty:GetChecked() and true or false, zoneRaid = cbRaid:GetChecked() and true or false }
if activeIdx and RAY_Config.specSettings[specNum][storageKey][activeIdx] then RAY_Config.specSettings[specNum][storageKey][activeIdx] = itemData else table.insert(RAY_Config.specSettings[specNum][storageKey], itemData) end
activeIndices[storageKey] = nil
if isIcd then boxName:SetText("") boxSec:SetText("") else editBox:SetText("") end
cbCombat:SetChecked(false) cbWorld:SetChecked(false) cbParty:SetChecked(false) cbRaid:SetChecked(false)
RefreshLocalSubList(specNum, storageKey) CheckAllAuras()
end)
end
BuildInputFieldBlock("Комплект экипировки:", "sets", "Название вашего комплекта экипировки в игре.", false, 0)
BuildInputFieldBlock("Стойка / Бафф:", "buffs", "Обязательная aura или боевая стойка класса.", false, 1)
BuildInputFieldBlock("Прок триньки / КД:", "icds", "Формат: КД/ОкноПоказа (например, 45/5)", true, 2)
end
CreateSubPageBlock(1, -15, COLOR_SPEC1, "ПЕРВАЯ ВЕТКА (СПЕК 1)")
CreateSubPageBlock(2, -775, COLOR_SPEC2, "ВТОРАЯ ВЕТКА (СПЕК 2)")
setsPanel:HookScript("OnShow", function()
RefreshLocalSubList(1, "sets")
RefreshLocalSubList(1, "buffs")
RefreshLocalSubList(1, "icds")
RefreshLocalSubList(2, "sets")
RefreshLocalSubList(2, "buffs")
RefreshLocalSubList(2, "icds")
end)
InterfaceOptions_AddCategory(setsPanel)
updateSpellLists()
end)
SLASH_RAY1 = "/ray"
SlashCmdList["RAY"] = function()
if optionsPanel then
InterfaceOptionsFrame_OpenToCategory(optionsPanel)
InterfaceOptionsFrame_OpenToCategory(optionsPanel)
end
end
