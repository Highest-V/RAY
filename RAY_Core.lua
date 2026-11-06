RAY_addonName = "RAY"
RAY_Engine = {}

PASTEL_TITLE  = "|cff4ECCA3"
PASTEL_BUFF   = "|cffA8FF35"
PASTEL_DEBUFF = "|cffFF7676"
PASTEL_YELLOW = "|cffFFD369"
PASTEL_GRAY   = "|cffEEEEEE"

COLOR_SPEC1   = "|cffD6A2E8"
COLOR_SPEC2   = "|cffFFB84C"

RAY_defaultSettings = {
    enabled = true,
    fontSize = 24,
    radarEnabled = false,
    boxHunterEnabled = true,
    comboTrackerEnabled = true,
    comboTrackerLimit = 5,
    framePos = { point = "CENTER", x = 0, y = 150 },
    customFramePositions = {},
    specSettings = {
    [1] = { spells = {}, sets = {}, buffs = {}, icds = {}, pets = {} },
    [2] = { spells = {}, sets = {}, buffs = {}, icds = {}, pets = {} }
    }
}

-- Изолированные контейнеры данных
RAY_Engine.customFramesPool      = {}
RAY_Engine.activeSummonAlerts    = {}
RAY_Engine.activeICDTimers       = {}
RAY_Engine.uniqueAlerts          = {}
RAY_Engine.alertStringTable      = {}
RAY_Engine.customAlertsByWindow  = {}
RAY_Engine.spellsLookup          = {} 
RAY_Engine.spellsCleanNameCache  = {}
RAY_Engine.spellsFrameKeyCache   = {}
RAY_Engine.cachedEnchantStatus   = {}
RAY_Engine.cachedEquipmentStatus = {}
RAY_Engine.sylvanasAlertActive   = false
RAY_Engine.Engine_lastDbgHash    = ""

optionsPanel, setsPanel = nil, nil
listButtonsBuff, listButtonsDebuff = {}, {}
listButtonsSub = { 
    [1] = { sets = {}, buffs = {}, icds = {} }, 
    [2] = { sets = {}, buffs = {}, icds = {} } 
}

function RAY_Engine.GetCachedHexColor(c)
    if not c then return "ffffff" end
    return string.format("%02x%02x%02x", math.floor((c.r or 1) * 255), math.floor((c.g or 1) * 255), math.floor((c.b or 1) * 255))
end

function RAY_Engine.GetDefaultColor() return { r = 0.5, g = 0.95, b = 0.8 } end

function RAY_Engine.CleanSpellName(name)
    if not name then return "" end
    if RAY_Engine.spellsCleanNameCache[name] then return RAY_Engine.spellsCleanNameCache[name] end
    local lowerName = string.lower(tostring(name))
    local clean = lowerName:gsub("%s+[ivxlcdm]+%s*$", ""):gsub("%s*%d+$", ""):gsub("%s*$", ""):match("^%s*(.-)%s*$") or ""
    RAY_Engine.spellsCleanNameCache[name] = clean
    return clean
end

function RAY_Engine.GetFrameKey(spellName)
    if RAY_Engine.spellsFrameKeyCache[spellName] then return RAY_Engine.spellsFrameKeyCache[spellName] end
    local key = spellName:gsub("%s", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    RAY_Engine.spellsFrameKeyCache[spellName] = key
    return key
end

function RAY_Engine.GetCurrentZoneType()
    local inInstance, instanceType = IsInInstance() 
    if inInstance and (instanceType == "party" or instanceType == "raid") then return instanceType end
    local numRaid = GetNumRaidMembers and GetNumRaidMembers() or 0 
    local numParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    if numRaid > 0 then return "raid" end 
    if numParty > 0 then return "party" end 
    return "world"
end

function RAY_Engine.CheckSubRules(data, inCombat, currentZone)
    if not data then return true end 
    if data.zoneWorld == false and currentZone == "world" then return false end
    if data.zoneParty == false and currentZone == "party" then return false end 
    if data.zoneRaid == false and currentZone == "raid" then return false end
    if data.onlyInCombat and not inCombat then return false end
    return true
end

function RAY_Engine.BuildStateHash()
    local hash = #RAY_Engine.alertStringTable
    for i = 1, #RAY_Engine.alertStringTable do hash = hash + #RAY_Engine.alertStringTable[i] end
    for k, v in pairs(RAY_Engine.customAlertsByWindow) do hash = hash + #k + #v.text end
    return tostring(hash)
end

function RAY_Engine.RebuildSpellsLookup()
    wipe(RAY_Engine.spellsLookup)
    if not RAY_Config or not RAY_Config.specSettings then return end
    local currentSpec = GetActiveTalentGroup() or 1
    local profile = RAY_Config.specSettings[currentSpec]
    if profile and profile.spells then
        for i = 1, #profile.spells do
            local spellData = profile.spells[i]
            if spellData and spellData.name and spellData.name ~= "" then
                local lowerName = RAY_Engine.CleanSpellName(spellData.name)
                RAY_Engine.spellsLookup[lowerName] = spellData
                RAY_Engine.GetFrameKey(spellData.name)
                for subName in string.gmatch(spellData.name:lower(), "[^|/]+") do
                    subName = RAY_Engine.CleanSpellName(subName)
                    if subName ~= "" then RAY_Engine.spellsLookup[subName] = spellData end
                end
            end
        end
    end
end

local textScanFrameMain = CreateFrame("GameTooltip", "RAY_EnchantScannerTooltipMain", nil, "GameTooltipTemplate")
textScanFrameMain:SetOwner(UIParent, "ANCHOR_NONE")

function RAY_Engine.UpdateCustomGearEnchantCache()
    wipe(RAY_Engine.cachedEnchantStatus)
    local slotsToScan = { 10, 15, 16, 17 }
    for idx = 1, 4 do
        local slotID = slotsToScan[idx]
        textScanFrameMain:ClearLines() 
        textScanFrameMain:SetInventoryItem("player", slotID)
        for i = 1, 15 do
            local lineText = _G["RAY_EnchantScannerTooltipMainTextLeft"..i] 
            local txt = lineText and lineText:GetText()
            if txt then
                RAY_Engine.cachedEnchantStatus[slotID] = RAY_Engine.cachedEnchantStatus[slotID] or {}
                table.insert(RAY_Engine.cachedEnchantStatus[slotID], txt:lower())
            end
        end
    end
end

function RAY_Engine.GetEnchantCooldownOrStatus(enchantName)
    local targetClean = RAY_Engine.CleanSpellName(enchantName)
    if targetClean == "" then return false end
    local slots = { 10, 15, 16, 17 }
    for i = 1, #slots do
        local slotID = slots[i]
        local cache = RAY_Engine.cachedEnchantStatus[slotID]
        if cache then
            for j = 1, #cache do
                if cache[j]:find(targetClean, 1, true) then
                    if slotID == 10 then
                        local start, duration = GetInventoryItemCooldown("player", 10)
                        if start and start > 0 and duration > 1.5 then return false end
                    else
                        local hasMain, mainExp, _, _, hasOff, offExp = GetWeaponEnchantInfo()
                        if slotID == 16 and (not hasMain or mainExp == 0) then return false end
                        if slotID == 17 and (not hasOff or offExp == 0) then return false end
                    end
                    return true
                end
            end
        end
    end
    return false
end

function RAY_Engine.UpdateEquipmentSetsCache()
    wipe(RAY_Engine.cachedEquipmentStatus)
    if not RAY_Config or not RAY_Config.enabled then return end
    local currentSpec = GetActiveTalentGroup() or 1
    local configData = RAY_Config.specSettings and RAY_Config.specSettings[currentSpec]
    if not configData or not configData.sets then return end
    local numSets = GetNumEquipmentSets()
    
    for i = 1, #configData.sets do
        local set = configData.sets[i]
        if set and set.name and set.name ~= "" then
            local finalStatus = "NOT_FOUND"
            
            -- Разделяем строку по знакам / или | для логики ИЛИ/ИЛИ
            for subSetName in string.gmatch(set.name, "[^|/]+") do
                subSetName = subSetName:match("^%s*(.-)%s*$") -- Очищаем от пробелов по краям
                if subSetName ~= "" then
                    local foundIndex = nil
                    local setLower = subSetName:lower()
                    
                    for s = 1, numSets do
                        local name = GetEquipmentSetInfo(s)
                        if name and name:lower() == setLower then foundIndex = s break end
                    end
                    
                    if foundIndex then
                        local setItemIDs = GetEquipmentSetItemIDs(GetEquipmentSetInfo(foundIndex))
                        local currentSubStatus = "OK"
                        if setItemIDs then
                            for slotID = 1, 18 do
                                local savedItemID = setItemIDs[slotID]
                                if savedItemID and savedItemID > 1 and GetInventoryItemID("player", slotID) ~= savedItemID then
                                    currentSubStatus = "PARTIAL" 
                                    break
                                end
                            end
                        else 
                            currentSubStatus = "NOT_FOUND" 
                        end
                        
                        -- Если хотя бы один комплект из списка одет полностью (OK), 
                        -- то общее правило считается выполненным
                        if currentSubStatus == "OK" then
                            finalStatus = "OK"
                            break
                        elseif currentSubStatus == "PARTIAL" and finalStatus ~= "OK" then
                            finalStatus = "PARTIAL"
                        end
                    end
                end
            end
            
            RAY_Engine.cachedEquipmentStatus[set.name] = finalStatus
        end
    end
end


function RAY_Engine.FindAuraDirect(target, nameOrId)
    local searchKey = RAY_Engine.CleanSpellName(nameOrId)
    if searchKey == "" then return false, 0, 0, nil end
    local curTime = GetTime()
    for f = 1, 2 do
        local filter = (f == 1) and "HELPFUL" or "HARMFUL"
        for i = 1, 40 do
            local name, _, _, count, _, _, expirationTime, caster, _, _, spellID = UnitAura(target, i, filter)
            if not name then break end
            if RAY_Engine.CleanSpellName(name) == searchKey or tostring(spellID) == searchKey then
                local rem = (expirationTime and expirationTime > 0) and (expirationTime - curTime) or 0
                local actualStacks = (count and count > 0) and count or 1
                return true, actualStacks, rem, caster
            end
        end
    end
    return false, 0, 0, nil
end

function RAY_Engine.CheckAuraGroupDirect(target, spellLine)
    local active, currentStacks, minRemaining, lastCaster = false, 0, 999999, nil
    for condition in string.gmatch(spellLine, "[^|/]+") do
        condition = condition:match("^%s*(.-)%s*$")
        local found, stacks, timeLeft, caster = RAY_Engine.FindAuraDirect(target, condition)
        if found then
            active = true
            currentStacks = math.max(currentStacks, stacks)
            if timeLeft < minRemaining then minRemaining = timeLeft end
            if caster then lastCaster = caster end
        end
    end
    return active, currentStacks, minRemaining, lastCaster
end

function RAY_Engine.IsTotemActiveInGame(totemName)
    local lowerName = RAY_Engine.CleanSpellName(totemName)
    for i = 1, 4 do
        local haveTotem, name = GetTotemInfo(i)
        if haveTotem and name and RAY_Engine.CleanSpellName(name):find(lowerName, 1, true) then return true end
    end
    return false
end

function RAY_Engine.GetCasterColoredName(casterUnit)
if not casterUnit then return "Напарник" end
local name = UnitName(casterUnit) or casterUnit
local _, class = UnitClass(casterUnit)
if class and RAID_CLASS_COLORS[class] then
local c = RAID_CLASS_COLORS[class]
return string.format("|cff%02x%02x%02x%s|r", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255), name)
end
return name
end
function GetOrCreateCustomFrame(spellName)
local frameKey = RAY_Engine.GetFrameKey(spellName)
if RAY_Engine.customFramesPool[frameKey] then return RAY_Engine.customFramesPool[frameKey] end
local cf = CreateFrame("Frame", "RAY_CustomFrame_" .. frameKey, UIParent)
cf:SetSize(400, 50) cf:SetPoint("CENTER", 0, 50) cf:SetMovable(true) cf:RegisterForDrag("LeftButton")
cf:SetScript("OnDragStart", function(self) self:StartMoving() end)
cf:SetScript("OnDragStop", function(self)
self:StopMovingOrSizing()
local p, _, rp, x, y = self:GetPoint()
if not RAY_Config.customFramePositions then RAY_Config.customFramePositions = {} end
RAY_Config.customFramePositions[frameKey] = { point = p, x = x, y = y }
end)
cf.bg = cf:CreateTexture(nil, "BACKGROUND") cf.bg:SetAllPoints() cf.bg:SetTexture(0.1, 0.1, 0.1, 0.6) cf.bg:Hide()
cf.border = cf:CreateTexture(nil, "OVERLAY") cf.border:SetAllPoints() cf.border:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border") cf.border:Hide()
local fstr = cf:CreateFontString("RAY_CustomFS" .. frameKey, "OVERLAY", "GameFontNormalLarge")
fstr:SetPoint("CENTER", cf, "CENTER") fstr:SetFont("Fonts\\Fonts\\FRIZQT.TTF", 24, "OUTLINE")
cf.labelString = fstr
cf:SetScript("OnUpdate", function(self, elapsed)
if self.labelString and self.labelString:GetText() ~= "" and not self:IsMouseEnabled() then
local factor = (math.sin(GetTime() * 4) + 1) / 2
self:SetAlpha(0.4 + factor * 0.6)
else
self:SetAlpha(1.0)
end
end)
cf:Hide()
RAY_Engine.customFramesPool[frameKey] = cf
return cf
end
local function SetupDragAndPosition(f)
f:SetMovable(true) f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function(self) self:StartMoving() end)
f:SetScript("OnDragStop", function(self)
self:StopMovingOrSizing()
local p, _, rp, x, y = self:GetPoint()
if RAY_Config then RAY_Config.framePos = { point = p, x = x, y = y } end
end)
end
RAY_Engine.CheckAllAuras = function()
if not RAY_Config or RAY_Config.enabled == false then
if RAY_Engine.text then RAY_Engine.text:SetText("") end
if RAY_Engine.frame then RAY_Engine.frame:Hide() end
for _, cf in pairs(RAY_Engine.customFramesPool) do
if cf and cf.labelString then cf.labelString:SetText("") end
if cf then cf:Hide() end
end
return
end
if RAY_Engine.frame and RAY_Engine.frame:IsMouseEnabled() and RAY_Engine.frame:IsShown() then return end
local inCombat, currentZone, currentSpec, curTime = UnitAffectingCombat("player"), RAY_Engine.GetCurrentZoneType(), (GetActiveTalentGroup() or 1), GetTime()
wipe(RAY_Engine.uniqueAlerts)
wipe(RAY_Engine.customAlertsByWindow)
local mainFrameFontSize = RAY_Config.fontSize or 24
if RAY_Engine.sylvanasAlertActive and RAY_Config.boxHunterEnabled then
if curTime <= RAY_Engine.sylvanasAlertActive then
RAY_Engine.uniqueAlerts["|cffFF5555[RAY Детектор]: Шкатулку завел!|r"] = true
else RAY_Engine.sylvanasAlertActive = false end
end
if RAY_Config.comboTrackerEnabled then
if UnitExists("target") and not UnitIsDead("target") then
local cp = GetComboPoints("player", "target")
local targetLimit = RAY_Config.comboTrackerLimit or 5
if cp and cp > 0 then
RAY_Engine.uniqueAlerts["|cff" .. ((cp >= targetLimit) and "FF0000" or "FFD369") .. "Серия приёмов: [" .. cp .. " / 5 КП]|r"] = true
end
end
end
local activeProfile = RAY_Config.specSettings and RAY_Config.specSettings[currentSpec]
if not activeProfile then return end
local activeSpells = activeProfile.spells or {}
local currentActiveTotems = {}
-- 1. Скан слотов тотемов (Только чистое время жизни)
for slot = 1, 4 do
local haveTotem, totemName, startTime, duration = GetTotemInfo(slot)
if haveTotem and totemName and totemName ~= "" then
local cleanTName = RAY_Engine.CleanSpellName(totemName)
for i = 1, #activeSpells do
local spellData = activeSpells[i]
if spellData and spellData.isSummonObject and RAY_Engine.CleanSpellName(spellData.name) == cleanTName then
if not spellData.isCooldown then
local endTime = (startTime > 0) and (startTime + duration) or (curTime + duration)
if duration == 0 or duration > 90000 then endTime = curTime + 300 end
local storageKey = "totem_slot_" .. slot
currentActiveTotems[storageKey] = true
RAY_Engine.activeSummonAlerts[storageKey] = {
endTime = endTime,
spellName = totemName,
color = spellData.color,
customSize = spellData.customSize,
isOwnWindow = spellData.isOwnWindow,
configKey = spellData.name,
isRealTotem = true
}
end
end
end
end
end
for key, data in pairs(RAY_Engine.activeSummonAlerts) do
if data.isRealTotem and not currentActiveTotems[key] then
RAY_Engine.activeSummonAlerts[key] = nil
end
end
-- 2. Отрисовка призывов существ
for key, data in pairs(RAY_Engine.activeSummonAlerts) do
local stillExists = true
if data.isRealTotem then
stillExists = RAY_Engine.IsTotemActiveInGame(data.spellName)
else
stillExists = (curTime < data.endTime)
end
if stillExists then
local rem = math.max(0, math.ceil(data.endTime - curTime))
if rem > 0 then
local displaySpellName = tostring(data.spellName):gsub("%s+[IVXLCDM]+%s*$", ""):gsub("%s*$", "")
local msg = "[Призыв]: [" .. displaySpellName .. "] " .. rem .. " сек"
local hex = RAY_Engine.GetCachedHexColor(data.color)
local fKey = RAY_Engine.GetFrameKey(data.configKey)
local cf = RAY_Engine.customFramesPool[fKey]
if cf and cf.cooldown then cf.cooldown:Hide() end
if RAY_Engine.frame and RAY_Engine.frame.cooldown then RAY_Engine.frame.cooldown:Hide() end
if data.isOwnWindow then
RAY_Engine.customAlertsByWindow[fKey] = { text = "|cff" .. hex .. msg .. "|r", color = data.color or RAY_Engine.GetDefaultColor(), size = data.customSize }
else
RAY_Engine.uniqueAlerts["|cff" .. hex .. msg .. "|r"] = true
if data.customSize and data.customSize > mainFrameFontSize then mainFrameFontSize = data.customSize end
end
else
RAY_Engine.activeSummonAlerts[key] = nil
end
else
RAY_Engine.activeSummonAlerts[key] = nil
end
end
if activeProfile.sets then
for i = 1, #activeProfile.sets do
local set = activeProfile.sets[i]
if set and set.name ~= "" and RAY_Engine.CheckSubRules(set, inCombat, currentZone) then
local status = RAY_Engine.cachedEquipmentStatus[set.name] or "OK"
if status == "NOT_FOUND" then RAY_Engine.uniqueAlerts["RAY: Комплект [" .. set.name .. "] не найден!"] = true
elseif status == "PARTIAL" then RAY_Engine.uniqueAlerts["RAY: Комплект [" .. set.name .. "] не полон!"] = true end
end
end
end
if activeProfile.buffs then
for i = 1, #activeProfile.buffs do
local buff = activeProfile.buffs[i]
if buff and buff.name ~= "" and RAY_Engine.CheckSubRules(buff, inCombat, currentZone) then
local hasAura = false

if buff.isPetTracker then
    -- Логика для питомца: если пет существует и не мертв, то всё ок
    if UnitExists("pet") and not UnitIsDead("pet") then
        hasAura = true
    end
else
    -- Обычная логика аур и стоек воина
    hasAura = RAY_Engine.CheckAuraGroupDirect("player", buff.name)
    if not hasAura then
        local currentFormIndex = GetShapeshiftForm()
        if currentFormIndex and currentFormIndex > 0 then
            local _, formName = GetShapeshiftFormInfo(currentFormIndex)
            if formName and RAY_Engine.CleanSpellName(formName) == RAY_Engine.CleanSpellName(buff.name) then
                hasAura = true
            end
        end
    end
end

if buff.invert then
if hasAura then RAY_Engine.uniqueAlerts["|cffFF7676RAY: Сними [" .. buff.name .. "]!|r"] = true end
else
if not hasAura then 
    local displayName = buff.isPetTracker and buff.name or buff.name
    RAY_Engine.uniqueAlerts["|cffA8FF35RAY: Призови [" .. displayName .. "]!|r"] = true 
end
end
end
end
end
if activeProfile.icds then
for i = 1, #activeProfile.icds do
local data = activeProfile.icds[i]
if data and data.name ~= "" and RAY_Engine.CheckSubRules(data, inCombat, currentZone) then
local endTime = RAY_Engine.activeICDTimers[data.name:lower()]
if endTime and endTime > curTime then
local remainingCD = endTime - curTime
local _, alertWindow = tostring(data.seconds or "45"):match("([^/]+)/?([^/]*)")
alertWindow = tonumber(alertWindow) or 10
if remainingCD <= alertWindow then
RAY_Engine.uniqueAlerts["RAY: КД " .. data.name .. " (" .. math.ceil(remainingCD) .. " сек)"] = true
end
end
end
end
end
if activeSpells then
for i = 1, #activeSpells do
local spellData = activeSpells[i]
if spellData and spellData.name ~= "" and RAY_Engine.CheckSubRules(spellData, inCombat, currentZone) then
if not spellData.isSummonObject then
local limitStacks, userAlertTime, prefix = (tonumber(spellData.minStacks) or 0), (tonumber(spellData.alertTime) or 0), " ст"
local hexColor = RAY_Engine.GetCachedHexColor(spellData.color)
local finalRGBColor = spellData.color or RAY_Engine.GetDefaultColor()
local needAlert, customReason = false, ""
local msgTypeCustom = nil
if spellData.isWeaponText then
if spellData.isCooldown then
local start, duration = GetInventoryItemCooldown("player", 10)
local isCurrentlyOnCooldown = start and start > 0 and duration > 1.5
needAlert = not isCurrentlyOnCooldown
else
needAlert = not RAY_Engine.GetEnchantCooldownOrStatus(spellData.name)
end
elseif spellData.isCooldown then
local start, duration = GetSpellCooldown(spellData.name)
local isCurrentlyOnCooldown = start and start > 0 and duration > 1.5
needAlert = (not isCurrentlyOnCooldown and not RAY_Engine.CheckAuraGroupDirect("player", spellData.name))
else
local target = spellData.target or "player"
local isActive, stacks, timeLeft, caster = RAY_Engine.CheckAuraGroupDirect(target, spellData.name)
-- Проверка на кап стаков (Окрашивание в красный цвет)
local isAtMaxCap = false
if isActive and limitStacks > 0 then
if stacks >= limitStacks then
isAtMaxCap = true
hexColor = "FF0000"
finalRGBColor = { r = 1, g = 0, b = 0 }
end
end
if spellData.isExternalOnly then
if isActive and caster and caster ~= "player" and caster ~= "vehicle" then
needAlert = true
msgTypeCustom = "[Обнаружен спелл]: " .. RAY_Engine.GetCasterColoredName(caster) .. " -> "
end
else
if spellData.isProc then
if isActive or (IsUsableSpell(spellData.name) and inCombat) then
needAlert = true
local displayTime = ""
if timeLeft > 0 and timeLeft < 3600 then
if userAlertTime > 0 and timeLeft <= userAlertTime then
displayTime = " " .. math.ceil(timeLeft) .. " сек"
elseif userAlertTime == 0 then
displayTime = " " .. math.ceil(timeLeft) .. " сек"
end
end
customReason = (spellData.isStackProgress and limitStacks > 0) and (" (" .. stacks .. "/" .. limitStacks .. prefix .. ")" .. displayTime) or displayTime
end
else
if not isActive then
needAlert = true
if limitStacks > 0 then customReason = " (0/" .. limitStacks .. prefix .. ")" end
else
if spellData.isStackProgress and limitStacks > 0 and (stacks < limitStacks) then
needAlert = true
customReason = " (" .. stacks .. "/" .. limitStacks .. prefix .. ")"
elseif userAlertTime > 0 then
if timeLeft <= userAlertTime then
needAlert = true
customReason = ((limitStacks > 0) and (" (" .. stacks .. "/" .. limitStacks .. prefix .. ") ") or "") .. math.ceil(timeLeft) .. " сек"
end
else
-- ОБРАБОТКА КАПА СТАКОВ И СКРЫТИЯ БАФФОВ
if isAtMaxCap then
if not spellData.isHideCap then
needAlert = true -- Висит на экране красным цветом
local displayTime = (timeLeft > 0 and timeLeft < 3600) and (" " .. math.ceil(timeLeft) .. " сек") or ""
customReason = " (" .. stacks .. "/" .. limitStacks .. prefix .. ")" .. displayTime
else
needAlert = false -- Скрываем, так как стоит галочка скрыть
end
else
-- Если стаков нет / кап не полный, но бафф висит и порог времени равен 0 — скрываем надпись (база)
needAlert = false
end
end
end
end
end
end
if needAlert then
local displayName = string.match(spellData.name, "[^|/]+") or spellData.name
local msgType = (spellData.mode == "DEBUFF") and "RAY: Дебафф [" or "RAY: Обнови бафф ["
if spellData.target == "target" and spellData.mode == "DEBUFF" then msgType = "RAY: Наложи дебафф [" end
if spellData.isProc then msgType = "RAY: Прок! [" end
if spellData.isWeaponText then msgType = "RAY: Чарка [" end
if spellData.isCooldown then msgType = "RAY: Готово! Прожми [" end
if spellData.isExternalOnly then msgType = msgTypeCustom or "RAY: " end
local msg = (spellData.isCooldown or spellData.isExternalOnly or (spellData.isWeaponText and spellData.isCooldown)) and (msgType .. displayName .. "]") or (msgType .. displayName .. "]" .. customReason)
if spellData.isOwnWindow then
RAY_Engine.customAlertsByWindow[RAY_Engine.GetFrameKey(spellData.name)] = { text = "|cff" .. hexColor .. msg .. "|r", color = finalRGBColor, size = spellData.customSize }
else
RAY_Engine.uniqueAlerts["|cff" .. hexColor .. msg .. "|r"] = true
if spellData.customSize and spellData.customSize > mainFrameFontSize then mainFrameFontSize = spellData.customSize end
end
end
end
end
end
end
table.wipe(RAY_Engine.alertStringTable)
for k in pairs(RAY_Engine.uniqueAlerts) do table.insert(RAY_Engine.alertStringTable, k) end
local currentHash = RAY_Engine.BuildStateHash()
if currentHash == RAY_Engine.Engine_lastDbgHash then return end
RAY_Engine.Engine_lastDbgHash = currentHash
if #RAY_Engine.alertStringTable > 0 then
if RAY_Engine.text and RAY_Engine.text.SetText then
RAY_Engine.text:SetText(table.concat(RAY_Engine.alertStringTable, "\n"))
RAY_Engine.text:SetFont("Fonts\\Fonts\\FRIZQT__.TTF", mainFrameFontSize, "OUTLINE")
end
if RAY_Engine.frame and not RAY_Engine.frame:IsShown() then RAY_Engine.frame:Show() end
else
if RAY_Engine.frame and not RAY_Engine.frame:IsMouseEnabled() then RAY_Engine.frame:Hide() end
end
for fWindowKey, cfData in pairs(RAY_Engine.customAlertsByWindow) do
local cf = RAY_Engine.customFramesPool[fWindowKey]
if not cf then cf = GetOrCreateCustomFrame(fWindowKey) end
if cf and cf.labelString then
cf.labelString:SetText(cfData.text)
cf.labelString:SetTextColor(cfData.color.r, cfData.color.g, cfData.color.b)
cf.labelString:SetFont("Fonts\\Fonts\\FRIZQT__.TTF", cfData.size or 24, "OUTLINE")
if RAY_Config and RAY_Config.customFramePositions and RAY_Config.customFramePositions[fWindowKey] then
local pos = RAY_Config.customFramePositions[fWindowKey]
cf:ClearAllPoints() cf:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
end
if not cf:IsShown() then cf:Show() end
end
end
for poolKey, cf in pairs(RAY_Engine.customFramesPool) do
if not RAY_Engine.customAlertsByWindow[poolKey] and cf and not cf:IsMouseEnabled() then
cf.labelString:SetText("") cf:Hide()
end
end
end
local metronomeFrame = CreateFrame("Frame")
local lastTickTime = 0
metronomeFrame:SetScript("OnUpdate", function(self, elapsed)
local now = GetTime()
if (now - lastTickTime) >= 1.0 then
lastTickTime = now
if RAY_Config and RAY_Config.enabled then
RAY_Engine.Engine_lastDbgHash = ""
RAY_Engine.CheckAllAuras()
end
end
end)
RAY_Engine.frame = CreateFrame("Frame", "RAY_MainFrame", UIParent)
RAY_Engine.frame:SetSize(400, 60) RAY_Engine.frame:SetPoint("CENTER", 0, 150) RAY_Engine.frame:Hide()
RAY_Engine.dragBg, RAY_Engine.dragBorder = RAY_Engine.frame:CreateTexture(nil, "BACKGROUND"), RAY_Engine.frame:CreateTexture(nil, "OVERLAY")
RAY_Engine.dragBg:SetAllPoints() RAY_Engine.dragBg:SetTexture(0.1, 0.1, 0.1, 0.6) RAY_Engine.dragBg:Hide()
RAY_Engine.dragBorder:SetAllPoints() RAY_Engine.dragBorder:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border") RAY_Engine.dragBorder:Hide()
RAY_Engine.text = RAY_Engine.frame:CreateFontString("RAY_MainFrameText", "OVERLAY", "GameFontNormalLarge")
RAY_Engine.text:SetPoint("CENTER", RAY_Engine.frame, "CENTER") RAY_Engine.text:SetFont("Fonts\\Fonts\\FRIZQT__.TTF", 24, "OUTLINE") RAY_Engine.text:SetTextColor(0.5, 0.95, 0.8) RAY_text = RAY_Engine.text
RAY_Engine.frame:SetScript("OnUpdate", function(self, elapsed)
if RAY_Engine.text and RAY_Engine.text:GetText() ~= "" and not self:IsMouseEnabled() then
local factor = (math.sin(GetTime() * 4) + 1) / 2
self:SetAlpha(0.4 + factor * 0.6)
else
self:SetAlpha(1.0)
end
end)
SetupDragAndPosition(RAY_Engine.frame)
local engineEvents = CreateFrame("Frame")
engineEvents:RegisterEvent("ADDON_LOADED")
engineEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
engineEvents:RegisterEvent("UNIT_AURA")
engineEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
engineEvents:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
engineEvents:RegisterEvent("UNIT_INVENTORY_CHANGED")
engineEvents:RegisterEvent("PLAYER_TOTEM_UPDATE")
engineEvents:RegisterEvent("UNIT_COMBO_POINTS")
engineEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
engineEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
engineEvents:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
engineEvents:RegisterEvent("SPELL_UPDATE_COOLDOWN")
engineEvents:SetScript("OnEvent", function(self, event, arg1, ...)
if event == "ADDON_LOADED" and arg1 == RAY_addonName then
if not RAY_Config then RAY_Config = CopyTable(RAY_defaultSettings) end
if RAY_Engine.frame and RAY_Config.framePos then
RAY_Engine.frame:ClearAllPoints()
RAY_Engine.frame:SetPoint(RAY_Config.framePos.point, UIParent, RAY_Config.framePos.point, RAY_Config.framePos.x, RAY_Config.framePos.y)
end
RAY_Engine.RebuildSpellsLookup()
elseif event == "PLAYER_ENTERING_WORLD" then
DEFAULT_CHAT_FRAME:AddMessage("|cff4ECCA3RAY - Remember About Yourself|r |cffffffffНастройка /ray. Перемещение /raymove.|r")
local activeSpec = GetActiveTalentGroup() or 1
local specColor = (activeSpec == 1) and COLOR_SPEC1 or COLOR_SPEC2
DEFAULT_CHAT_FRAME:AddMessage(PASTEL_TITLE .. "[RAY Загрузка]:|r Profile initialized: Spec " .. specColor .. activeSpec .. "|r")
RAY_Engine.RebuildSpellsLookup()
RAY_Engine.UpdateEquipmentSetsCache()
RAY_Engine.UpdateCustomGearEnchantCache()
RAY_Engine.Engine_lastDbgHash = ""
RAY_Engine.CheckAllAuras()
elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
RAY_Engine.UpdateEquipmentSetsCache()
RAY_Engine.UpdateCustomGearEnchantCache()
RAY_Engine.Engine_lastDbgHash = ""
RAY_Engine.CheckAllAuras()
elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
local activeSpec = GetActiveTalentGroup() or 1
local specColor = (activeSpec == 1) and COLOR_SPEC1 or COLOR_SPEC2
DEFAULT_CHAT_FRAME:AddMessage(PASTEL_TITLE .. "[RAY Смена Спека]:|r Profile switched to Spec " .. specColor .. activeSpec .. "|r")
wipe(RAY_Engine.activeSummonAlerts)
wipe(RAY_Engine.activeICDTimers)
RAY_Engine.RebuildSpellsLookup()
RAY_Engine.Engine_lastDbgHash = ""
RAY_Engine.CheckAllAuras()
elseif event == "UNIT_AURA" or event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_TOTEM_UPDATE" then
RAY_Engine.Engine_lastDbgHash = ""
RAY_Engine.CheckAllAuras()
else
RAY_Engine.Engine_lastDbgHash = ""
RAY_Engine.CheckAllAuras()
end
end)
local combatLogFrame = CreateFrame("Frame")
combatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
combatLogFrame:SetScript("OnEvent", function(self, event, ...)
local timestamp, subEvent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellID, spellName = ...
local playerGUID = UnitGUID("player")
local curTime = GetTime()
if RAY_Config and RAY_Config.radarEnabled then
if sourceGUID == playerGUID or destGUID == playerGUID then
if subEvent:find("AURA") or subEvent:find("CAST") or subEvent:find("SUMMON") then
if spellID and spellName then
print(string.format("|cff4ECCA3[RAY-Radar]:|r |cffffffff%s|r [|cffFFD369ID: %d|r] (Type: %s)", spellName, spellID, subEvent))
end
end
end
end
if subEvent == "SPELL_CAST_SUCCESS" and spellID == 72007 then
RAY_Engine.sylvanasAlertActive = curTime + 6.0
RAY_Engine.Engine_lastDbgHash = ""
RAY_Engine.CheckAllAuras()
return
end
-- Восстановленный перехват лога боя для не-тотемных существ
if sourceGUID == playerGUID and (subEvent == "SPELL_CAST_SUCCESS" or subEvent == "SPELL_SUMMON") then
local summonNameLower = spellName and spellName:lower() or ""
local spellData = RAY_Engine.spellsLookup[summonNameLower]
if spellData and spellData.isSummonObject then
local cleanSName = RAY_Engine.CleanSpellName(spellName)
local isSystemTotem = false
-- Проверяем, не перехватывается ли этот призыв через слоты тотемов
local currentSpec = GetActiveTalentGroup() or 1
local spells = RAY_Config.specSettings[currentSpec] and RAY_Config.specSettings[currentSpec].spells or {}
for i = 1, #spells do
if spells[i].isSummonObject and RAY_Engine.CleanSpellName(spells[i].name) == cleanSName and not spells[i].isCooldown then
-- Если это тотем в слотах, лог боя игнорируем, чтобы не двоилось
for slot = 1, 4 do
local _, tName = GetTotemInfo(slot)
if tName and RAY_Engine.CleanSpellName(tName) == cleanSName then
isSystemTotem = true
break
end
end
end
end
if not isSystemTotem then
local duration = tonumber(spellData.alertTime) or 30
if duration == 0 then duration = 30 end
RAY_Engine.activeSummonAlerts["non_totem_summon_" .. summonNameLower] = {
endTime = curTime + duration,
spellName = spellName,
color = spellData.color or RAY_Engine.GetDefaultColor(),
customSize = spellData.customSize or 24,
isOwnWindow = spellData.isOwnWindow or false,
configKey = spellData.name,
isRealTotem = false
}
RAY_Engine.Engine_lastDbgHash = ""
RAY_Engine.CheckAllAuras()
end
end
end
if destGUID == playerGUID and subEvent == "SPELL_AURA_APPLIED" then
local currentSpec = GetActiveTalentGroup() or 1
if RAY_Config and RAY_Config.specSettings and RAY_Config.specSettings[currentSpec] and RAY_Config.specSettings[currentSpec].icds then
local combatSpellLower = spellName:lower()
local configData = RAY_Config.specSettings[currentSpec].icds
for i = 1, #configData do
local data = configData[i]
if data and data.name and data.name:lower() == combatSpellLower then
local parsedSeconds = tostring(data.seconds or "45"):match("([^/]+)")
RAY_Engine.activeICDTimers[combatSpellLower] = curTime + (tonumber(parsedSeconds) or 45)
RAY_Engine.Engine_lastDbgHash = ""
RAY_Engine.CheckAllAuras()
break
end
end
end
end
end)