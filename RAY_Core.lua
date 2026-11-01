local addonName = "RAY"
local RAY_EventFrame = CreateFrame("Frame")

local defaultSettings = {
    enabled = true,
    fontSize = 24,
    radarEnabled = false,
    boxHunterEnabled = true,
    comboTrackerEnabled = true,
    comboTrackerLimit = 5,
    spells = {},
    framePos = { point = "CENTER", x = 0, y = 150 },
    specSettings = {
        [1] = { sets = {}, buffs = {}, icds = {} },
        [2] = { sets = {}, buffs = {}, icds = {} }
    }
}

optionsPanel, buffsPanel, debuffsPanel, setsPanel = nil, nil, nil, nil
selectedBuffIndex, selectedDebuffIndex = nil, nil
listButtonsBuff, listButtonsDebuff = {}, {}
listButtonsSub = { 
    [1] = { sets = {}, buffs = {}, icds = {} }, 
    [2] = { sets = {}, buffs = {}, icds = {} } 
}
updateSpellLists, selectBuff, selectDebuff, CheckAllAuras = nil, nil, nil, nil
RefreshLocalSubList = nil

customFramesPool = {}
local activeICDTimers = {}
activeSummonAlerts = {}
local sylvanasAlertActive = false
local sylvanasAlertActivePlayer = nil
local uniqueAlerts = {}
local alertStringTable = {}
local customAlertsByWindow = {}
spellsLookup = {} 

PASTEL_TITLE  = "|cff4ECCA3"
PASTEL_BUFF   = "|cffA8FF35"
PASTEL_DEBUFF = "|cffFF7676"
PASTEL_YELLOW = "|cffFFD369"
PASTEL_GRAY   = "|cffEEEEEE"

COLOR_SPEC1   = "|cffD6A2E8"
COLOR_SPEC2   = "|cffFFB84C"

local cachedColorsHex = {}
local function GetCachedHexColor(c)
    if not c then return "ffffff" end
    local key = string.format("%.2f%.2f%.2f", c.r, c.g, c.b)
    if not cachedColorsHex[key] then
        cachedColorsHex[key] = string.format("%02x%02x%02x", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255))
    end
    return cachedColorsHex[key]
end

function GetDefaultColor()
    return { r = 0.5, g = 0.95, b = 0.8 }
end

function CleanSpellName(name)
    if not name then return "" end
    local lowerName = string.lower(tostring(name))
    return lowerName:gsub("%s+[ivxlcdm]+%s*$", ""):gsub("%s*%d+$", ""):gsub("%s*$", ""):match("^%s*(.-)%s*$") or ""
end

function RebuildSpellsLookup()
    wipe(spellsLookup)
    if RAY_Config and RAY_Config.spells then
        for i = 1, #RAY_Config.spells do
            local spellData = RAY_Config.spells[i]
            if spellData and spellData.name and spellData.name ~= "" then
                local lowerName = CleanSpellName(spellData.name)
                spellsLookup[lowerName] = spellData
                for subName in string.gmatch(spellData.name:lower(), "[^|/]+") do
                    subName = CleanSpellName(subName)
                    if subName ~= "" then
                        spellsLookup[subName] = spellData
                    end
                end
            end
        end
    end
end

function GetCurrentZoneType()
    local inInstance, instanceType = IsInInstance() 
    if inInstance and (instanceType == "party" or instanceType == "raid") then return instanceType end
    local numRaid = GetNumRaidMembers and GetNumRaidMembers() or 0 
    local numParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    if numRaid > 0 then return "raid" end 
    if numParty > 0 then return "party" end 
    return "world"
end

function CheckSubRules(data, inCombat, currentZone)
    if not data then return true end 
    if data.zoneWorld == false and currentZone == "world" then return false end
    if data.zoneParty == false and currentZone == "party" then return false end 
    if data.zoneRaid == false and currentZone == "raid" then return false end
    if data.onlyInCombat and not inCombat then return false end
    return true
end

function IsTotemActiveInGame(totemName)
    local lowerName = CleanSpellName(totemName)
    for i = 1, 4 do
        local haveTotem, name = GetTotemInfo(i)
        if haveTotem and name and CleanSpellName(name):find(lowerName, 1, true) then 
            return true 
        end
    end
    return false
end

function SetTooltip(widget, uText)
    widget:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT") GameTooltip:SetText(uText, 1, 1, 1, nil, true) GameTooltip:Show() end)
    widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function CreateBlizzardEditBox(parent, x, y, width, name)
    local eb = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    eb:SetSize(width, 24)
    eb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    eb:SetAutoFocus(false)
    eb:SetFontObject("ChatFontNormal")
    eb:SetTextInsets(4, 4, 0, 0)
    return eb
end

function GetCasterColoredName(casterUnit)
    if not casterUnit then return "Напарник" end
    local name = UnitName(casterUnit) or casterUnit
    local _, class = UnitClass(casterUnit)
    if class and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return string.format("|cff%02x%02x%02x%s|r", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255), name)
    end
    return name
end

local textScanFrameMain = CreateFrame("GameTooltip", "RAY_EnchantScannerTooltipMain", nil, "GameTooltipTemplate")
textScanFrameMain:SetOwner(UIParent, "ANCHOR_NONE")

local cachedEnchantStatus = {}
local function UpdateCustomGearEnchantCache()
    wipe(cachedEnchantStatus)
    local slotsToScan = { 10, 15, 16, 17 }
    for idx = 1, 4 do
        local slotID = slotsToScan[idx]
        textScanFrameMain:ClearLines() 
        textScanFrameMain:SetInventoryItem("player", slotID)
        for i = 1, 15 do
            local lineText = _G["RAY_EnchantScannerTooltipMainTextLeft"..i] 
            local txt = lineText and lineText:GetText()
            if txt then
                cachedEnchantStatus[slotID] = cachedEnchantStatus[slotID] or {}
                table.insert(cachedEnchantStatus[slotID], txt:lower())
            end
        end
    end
end

-- ИЗОЛИРОВАННЫЙ КУБИК 1: ПРОВЕРКА ЧАР НА КОНКРЕТНОМ ОРУЖИИ (ПРАВОЕ / ЛЕВОЕ)
local function GetEnchantCooldownOrStatus(enchantName)
    local nameLower = enchantName:lower()
    
    if nameLower:find("гипер") or nameLower:find("ускор") or nameLower:find("перчат") then
        local start, duration = GetInventoryItemCooldown("player", 10)
        if start and start > 0 and duration > 1.5 then
            return true, 1, math.ceil(duration - (GetTime() - start)), nil
        end
        return false, 0, 0, nil
    end

    local hasMain, mainExp, _, _, hasOff, offExp = GetWeaponEnchantInfo()
    local cleanReq = CleanSpellName(enchantName)
    
    local isWindfuryRule = (cleanReq:find("неистовство") or cleanReq:find("ветер") or nameLower:find("windfury"))
    local isFlametongueRule = (cleanReq:find("язык") or cleanReq:find("пламен") or nameLower:find("flametongue"))
    
    -- Проверка строго по названию чарки, чтобы они не гасили друг друга ложно
    if isWindfuryRule then
        if hasMain and mainExp then return true, 1, math.max(0, math.ceil(mainExp / 1000)), nil end
    end
    
    if isFlametongueRule then
        if hasOff and offExp then return true, 1, math.max(0, math.ceil(offExp / 1000)), nil end
    end
    
    return false, 0, 0, nil
end

local cachedEquipmentStatus = {}
local function UpdateEquipmentSetsCache()
    wipe(cachedEquipmentStatus)
    if not RAY_Config or not RAY_Config.enabled then return end
    local currentSpec = GetActiveTalentGroup() or 1
    if not RAY_Config.specSettings or not RAY_Config.specSettings[currentSpec] then return end
    local configData = RAY_Config.specSettings[currentSpec]
    if not configData.sets then return end
    local numSets = GetNumEquipmentSets()
    for i = 1, 10 do
        local set = configData.sets[i]
        if set and set.name and set.name ~= "" then
            local foundIndex = nil
            local setLower = set.name:lower()
            for s = 1, numSets do
                local name = GetEquipmentSetInfo(s)
                if name and name:lower() == setLower then foundIndex = s break end
            end
            if not foundIndex then
                cachedEquipmentStatus[set.name] = "NOT_FOUND"
            else
                local setItemIDs = GetEquipmentSetItemIDs(GetEquipmentSetInfo(foundIndex))
                local status = "OK"
                if setItemIDs then
                    for slotID = 1, 18 do
                        local savedItemID = setItemIDs[slotID]
                        if savedItemID and savedItemID > 1 and GetInventoryItemID("player", slotID) ~= savedItemID then
                            status = "PARTIAL"
                            break
                        end
                    end
                else
                    status = "NOT_FOUND"
                end
                cachedEquipmentStatus[set.name] = status
            end
        end
    end
end

local function FindAuraDirect(target, nameOrId)
    local searchKey = CleanSpellName(nameOrId)
    if searchKey == "" then return false, 0, 0, nil end
    local curTime = GetTime()
    
    for i = 1, 40 do
        local name, _, _, count, _, _, expirationTime, caster, _, _, spellID = UnitAura(target, i, "HELPFUL")
        if not name then break end
        if CleanSpellName(name) == searchKey or tostring(spellID) == searchKey then
            local rem = (expirationTime and expirationTime > 0) and (expirationTime - curTime) or 0
            if expirationTime == 0 then rem = 0 end 
            return true, (count and count > 0) and count or 1, rem, caster
        end
    end
    for i = 1, 40 do
        local name, _, _, count, _, _, expirationTime, caster, _, _, spellID = UnitAura(target, i, "HARMFUL")
        if not name then break end
        if CleanSpellName(name) == searchKey or tostring(spellID) == searchKey then
            local rem = (expirationTime and expirationTime > 0) and (expirationTime - curTime) or 0
            if expirationTime == 0 then rem = 0 end 
            return true, (count and count > 0) and count or 1, rem, caster
        end
    end
    
    return false, 0, 0, nil
end

local function CheckAuraGroupDirect(target, spellLine)
local active, currentStacks, minRemaining, lastCaster = false, 0, 999999, nil
for condition in string.gmatch(spellLine, "[^|/]+") do
condition = condition:match("^%s*(.-)%s*$")
local found, stacks, timeLeft, caster = FindAuraDirect(target, condition)
if found then
active = true
currentStacks = math.max(currentStacks, stacks)
if timeLeft < minRemaining then minRemaining = timeLeft end
if caster then lastCaster = caster end
end
end
return active, currentStacks, minRemaining, lastCaster
end
function GetOrCreateCustomFrame(spellName)
local frameKey = spellName:gsub("%s", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
if customFramesPool[frameKey] then return customFramesPool[frameKey] end
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
local fsName = "RAY_CustomFS" .. frameKey
local fstr = cf:CreateFontString(fsName, "OVERLAY", "GameFontNormalLarge")
fstr:SetPoint("CENTER", cf, "CENTER")
fstr:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
cf.labelString = fstr
cf.anim = cf:CreateAnimationGroup()
local fOut = cf.anim:CreateAnimation("Alpha") fOut:SetChange(-0.5) fOut:SetDuration(0.5) fOut:SetOrder(1)
local fIn = cf.anim:CreateAnimation("Alpha") fIn:SetChange(0.5) fIn:SetDuration(0.5) fIn:SetOrder(2)
cf.anim:SetLooping("REPEAT") cf:Hide()
customFramesPool[frameKey] = cf
return cf
end
local SetupDragAndPosition = function(f, configStorage)
f:SetMovable(true) f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function(self) self:StartMoving() end)
f:SetScript("OnDragStop", function(self)
self:StopMovingOrSizing()
local p, _, rp, x, y = self:GetPoint()
if RAY_Config then RAY_Config.framePos = { point = p, x = x, y = y } end
end)
end
CheckAllAuras = function()
if not RAY_Config or RAY_Config.enabled == false then
if text then text:SetText("") end
if frame then frame:Hide() end
if animGroup then animGroup:Stop() end
for fKey, cf in pairs(customFramesPool) do
if cf and cf.labelString then cf.labelString:SetText("") end
if cf then cf:Hide() end
end
return
end
if frame and frame:IsMouseEnabled() and frame:IsShown() then return end
local inCombat, currentZone, currentSpec, curTime = UnitAffectingCombat("player"), GetCurrentZoneType(), (GetActiveTalentGroup() or 1), GetTime()
wipe(uniqueAlerts)
wipe(customAlertsByWindow)
local mainFrameFontSize = RAY_Config.fontSize or 24
if sylvanasAlertActive and RAY_Config.boxHunterEnabled then
if curTime <= sylvanasAlertActive then
uniqueAlerts["|cffFF5555[RAY Детектор]: Шкатулку завел!|r"] = true
else
sylvanasAlertActive = false
end
end
if RAY_Config.comboTrackerEnabled then
if UnitExists("target") and not UnitIsDead("target") then
local cp = GetComboPoints("player", "target")
local targetLimit = RAY_Config.comboTrackerLimit or 5
if cp and cp > 0 then
local cpColorCode = "|cffFFD369"
if cp >= targetLimit then cpColorCode = "|cffFF0000" end
uniqueAlerts[cpColorCode .. "Серия приёмов: [" .. cp .. " / 5 КП]|r"] = true
end
end
end
for k, v in pairs(activeSummonAlerts) do
if v.isRealTotem then activeSummonAlerts[k] = nil end
end
for slot = 1, 4 do
local haveTotem, totemName, startTime, duration = GetTotemInfo(slot)
if haveTotem and totemName and totemName ~= "" then
local cleanTName = CleanSpellName(totemName)
for i = 1, #RAY_Config.spells do
local spellData = RAY_Config.spells[i]
if spellData and spellData.name and spellData.isSummonObject and CleanSpellName(spellData.name) == cleanTName then
local endTime = (startTime > 0) and (startTime + duration) or (curTime + duration)
if duration == 0 or duration > 90000 then endTime = curTime + 300 end
activeSummonAlerts["player_totem" .. slot] = { endTime = endTime, spellName = totemName, color = spellData.color, customSize = spellData.customSize, isOwnWindow = spellData.isOwnWindow, configKey = spellData.name, isRealTotem = true }
end
end
else
activeSummonAlerts["player_totem" .. slot] = nil
end
end
for nameOrId, data in pairs(activeSummonAlerts) do
local stillExists = data.isRealTotem and IsTotemActiveInGame(data.spellName) or (curTime < data.endTime)
if stillExists then
local rem = math.ceil(data.endTime - curTime)
if rem < 0 then rem = 0 end
local displaySpellName = tostring(data.spellName):gsub("%s+[IVXLCDM]+%s*$", ""):gsub("%s*$", "")
local msg = "[Призыв]: [" .. displaySpellName .. "]"
if rem > 0 and rem < 9000 then msg = msg .. " (" .. rem .. " сек)" end
local hex = GetCachedHexColor(data.color)
if data.isOwnWindow then
local winKey = data.configKey:gsub("%s", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
customAlertsByWindow[winKey] = { text = "|cff" .. hex .. msg .. "|r", color = data.color or GetDefaultColor(), size = data.customSize }
else
uniqueAlerts["|cff" .. hex .. msg .. "|r"] = true
if data.customSize and data.customSize > mainFrameFontSize then mainFrameFontSize = data.customSize end
end
else
activeSummonAlerts[nameOrId] = nil
end
end
if RAY_Config.specSettings and RAY_Config.specSettings[currentSpec] then
local configData = RAY_Config.specSettings[currentSpec]
if configData.sets then
for i = 1, #configData.sets do
local set = configData.sets[i]
if set and set.name ~= "" and CheckSubRules(set, inCombat, currentZone) then
local status = cachedEquipmentStatus[set.name] or "OK"
if status == "NOT_FOUND" then uniqueAlerts["RAY: Комплект [" .. set.name .. "] не найден!"] = true
elseif status == "PARTIAL" then uniqueAlerts["RAY: Комплект [" .. set.name .. "] не полн!"] = true end
end
end
end
if configData.buffs then
for i = 1, #configData.buffs do
local buff = configData.buffs[i]
if buff and buff.name ~= "" and CheckSubRules(buff, inCombat, currentZone) and not CheckAuraGroupDirect("player", buff.name) then
uniqueAlerts["RAY: Включи [" .. buff.name .. "]!"] = true
end
end
end
if configData.icds then
for i = 1, #configData.icds do
local data = configData[i]
if data and data.name ~= "" and CheckSubRules(data, inCombat, currentZone) then
local endTime = activeICDTimers[data.name:lower()]
if endTime and endTime > curTime then
local remainingCD = endTime - curTime
local _, alertWindow = tostring(data.seconds or "45"):match("([^/]+)/?([^/]*)")
alertWindow = tonumber(alertWindow) or 0
if alertWindow == 0 or remainingCD <= alertWindow then
uniqueAlerts["RAY: КД " .. data.name .. " (" .. math.ceil(remainingCD) .. " сек)"] = true
end
end
end
end
end
end
for i = 1, #RAY_Config.spells do
local spellData = RAY_Config.spells[i]
if spellData and spellData.name ~= "" and CheckSubRules(spellData, inCombat, currentZone) then
if not spellData.isSummonObject then
local limitStacks, userAlertTime, prefix = (tonumber(spellData.minStacks) or 0), (tonumber(spellData.alertTime) or 0), " ст"
local hexColor = GetCachedHexColor(spellData.color)
local finalRGBColor = spellData.color or GetDefaultColor()
local needAlert, customReason = false, ""
-- КУБИК 1: ЧАРЫ ОРУЖИЯ И ИНЖЕНЕРИИ (ГАСНУТ СРАЗУ, ЕСЛИ ЧАРКА ЕСТЬ)
if spellData.isWeaponText then
local isWeaponActive = GetEnchantCooldownOrStatus(spellData.name)
if not isWeaponActive then
needAlert = true
customReason = ""
else
needAlert = false
end
-- КУБИК 2: ЭТО КД (СВЕТИТСЯ ТОЛЬКО КОГДА СПОСОБНОСТЬ ПОЛНОСТЬЮ ГОТОВА)
elseif spellData.isCooldown then
local isCurrentlyOnCooldown = false
local start, duration = GetSpellCooldown(spellData.name)
if start and start > 0 and duration > 1.5 then
isCurrentlyOnCooldown = true
end
local isActiveOnPlayer = CheckAuraGroupDirect("player", spellData.name)
if not isCurrentlyOnCooldown and not isActiveOnPlayer then
needAlert = true
customReason = ""
else
needAlert = false -- Кнопка на КД или эффект висит — аддон ПОЛНОСТЬЮ И ЖЕЛЕЗНО МОЛЧИТ!
end
-- КУБИК 3: ОБЫЧНЫЕ БАФФЫ И ДЕБАФФЫ (Раскол, Доспехи, Щиты)
else
local target = spellData.target or "player"
local isActive, stacks, timeLeft, caster = CheckAuraGroupDirect(target, spellData.name)
if isActive and limitStacks > 0 and (stacks >= limitStacks) then
hexColor = "FF0000"
finalRGBColor = { r = 1, g = 0, b = 0 }
end
if spellData.isExternalOnly then
if isActive and caster and caster ~= "player" and caster ~= "vehicle" then
needAlert = true
local cName = GetCasterColoredName(caster)
msgTypeCustom = "[Обнаружен спелл]: " .. cName .. " -> "
customReason = ""
end
else
if spellData.isProc then
local systemUsable = IsUsableSpell(spellData.name)
if isActive or (systemUsable and inCombat) then
needAlert = true
local displayTime = (timeLeft > 0 and userAlertTime > 0) and (" " .. timeLeft .. " сек") or ""
customReason = (stacks > 1 or limitStacks > 0) and (" (" .. stacks .. prefix .. ")" .. displayTime) or displayTime
else
needAlert = false
end
else
if not isActive then
needAlert = true
if limitStacks > 0 then customReason = " (0/" .. limitStacks .. prefix .. ")" end
else
if spellData.isStackProgress and limitStacks > 0 and (stacks < limitStacks) then
needAlert = true
customReason = " (" .. stacks .. "/" .. limitStacks .. prefix .. ")"
timeLeft = 9999
elseif userAlertTime > 0 then
if timeLeft <= userAlertTime then
needAlert = true
local displayStacks = (limitStacks > 0) and (" (" .. stacks .. "/" .. limitStacks .. prefix .. ") ") or ""
customReason = displayStacks .. math.ceil(timeLeft) .. " сек"
else
needAlert = false
end
else
if spellData.isHideCap and limitStacks > 0 and (stacks >= limitStacks) then
needAlert = false
else
needAlert = true
local displayStacks = (limitStacks > 0) and (" (" .. stacks .. "/" .. limitStacks .. prefix .. ")") or ""
local displayTime = (timeLeft > 0 and timeLeft < 3600) and (" " .. math.ceil(timeLeft) .. " сек") or ""
customReason = displayStacks .. displayTime
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
local msg = ""
if spellData.isCooldown then
msg = msgType .. displayName .. "]"
elseif spellData.isExternalOnly then
msg = msgType .. "[" .. displayName .. "]"
else
msg = msgType .. displayName .. "]" .. customReason
end
if spellData.isOwnWindow then
local winKey = spellData.name:gsub("%s", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
customAlertsByWindow[winKey] = { text = "|cff" .. hexColor .. msg .. "|r", color = finalRGBColor, size = spellData.customSize }
else
uniqueAlerts["|cff" .. hexColor .. msg .. "|r"] = true
if spellData.customSize and spellData.customSize > mainFrameFontSize then mainFrameFontSize = spellData.customSize end
end
end
end
end
end
for poolKey, _ in pairs(activeSummonAlerts) do
if not poolKey:find("player_totem") and curTime >= activeSummonAlerts[poolKey].endTime then
activeSummonAlerts[poolKey] = nil
end
end
wipe(alertStringTable)
for k in pairs(uniqueAlerts) do table.insert(alertStringTable, k) end
if #alertStringTable > 0 then
if text then
text:SetText(table.concat(alertStringTable, "\n"))
text:SetFont("Fonts\\FRIZQT__.TTF", mainFrameFontSize, "OUTLINE")
end
if frame and not frame:IsShown() then frame:Show() animGroup:Play() end
else
if frame and not frame:IsMouseEnabled() then frame:Hide() animGroup:Stop() end
end
for fWindowKey, cfData in pairs(customAlertsByWindow) do
local frameKey = fWindowKey:gsub("%s", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
local cf = customFramesPool[frameKey]
if not cf then cf = GetOrCreateCustomFrame(fWindowKey) end
if cf and cf.labelString then
cf.labelString:SetText(cfData.text)
cf.labelString:SetTextColor(cfData.color.r, cfData.color.g, cfData.color.b)
cf.labelString:SetFont("Fonts\\FRIZQT__.TTF", cfData.size or 24, "OUTLINE")
if RAY_Config and RAY_Config.customFramePositions and RAY_Config.customFramePositions[frameKey] then
local pos = RAY_Config.customFramePositions[frameKey]
cf:ClearAllPoints()
cf:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
end
if not cf:IsShown() then cf:Show() cf.anim:Play() end
end
end
for poolKey, cf in pairs(customFramesPool) do
local cleanPoolKey = poolKey:gsub("%s", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
if not customAlertsByWindow[cleanPoolKey] and cf and not cf:IsMouseEnabled() then
cf.labelString:SetText("")
cf:Hide()
cf.anim:Stop()
end
end
end
frame = CreateFrame("Frame", "RAY_MainFrame", UIParent)
frame:SetSize(400, 60) frame:SetPoint("CENTER", 0, 150) frame:Hide()
dragBg, dragBorder = frame:CreateTexture(nil, "BACKGROUND"), frame:CreateTexture(nil, "OVERLAY")
dragBg:SetAllPoints() dragBg:SetTexture(0.1, 0.1, 0.1, 0.6) dragBg:Hide()
dragBorder:SetAllPoints() dragBorder:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border") dragBorder:Hide()
text = frame:CreateFontString("RAY_MainFrameText", "OVERLAY", "GameFontNormalLarge")
text:SetPoint("CENTER", frame, "CENTER") text:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE") text:SetTextColor(0.5, 0.95, 0.8) text:SetJustifyH("CENTER")
animGroup = frame:CreateAnimationGroup()
local fadeOut = animGroup:CreateAnimation("Alpha") fadeOut:SetChange(-0.6) fadeOut:SetDuration(0.5) fadeOut:SetOrder(1)
local fadeIn = animGroup:CreateAnimation("Alpha") fadeIn:SetChange(0.6) fadeIn:SetDuration(0.5) fadeIn:SetOrder(2)
animGroup:SetLooping("REPEAT")
RAY_EventFrame:RegisterEvent("ADDON_LOADED")
RAY_EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
RAY_EventFrame:SetScript("OnEvent", function(self, event, arg1)
if event == "ADDON_LOADED" and arg1 == addonName then
if not RAY_Config then RAY_Config = CopyTable(defaultSettings) end
if frame and RAY_Config.framePos then
frame:ClearAllPoints()
frame:SetPoint(RAY_Config.framePos.point, UIParent, RAY_Config.framePos.point, RAY_Config.framePos.x, RAY_Config.framePos.y)
end
SetupDragAndPosition(frame, RAY_Config)
RebuildSpellsLookup()
elseif event == "PLAYER_ENTERING_WORLD" then
DEFAULT_CHAT_FRAME:AddMessage((PASTEL_TITLE or "") .. "RAY - Remember About Yourself. Настройка: /ray общие, /raymove перемещение фреймов")
RebuildSpellsLookup()
UpdateEquipmentSetsCache()
UpdateCustomGearEnchantCache()
CheckAllAuras()
end
end)
local elapsedSummonTime = 0
summonUpdateFrame = CreateFrame("Frame")
summonUpdateFrame:SetScript("OnUpdate", function(self, elapsed)
if not RAY_Config or not RAY_Config.enabled then return end
local elapsedAura = (elapsedSummonTime or 0) + elapsed
if elapsedAura >= 0.25 then
elapsedSummonTime = 0
CheckAllAuras()
else
elapsedSummonTime = elapsedAura
end
end)
isTimerActive = true
local engineEvents = CreateFrame("Frame")
engineEvents:RegisterEvent("UNIT_AURA")
engineEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
engineEvents:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
engineEvents:RegisterEvent("UNIT_INVENTORY_CHANGED")
engineEvents:RegisterEvent("PLAYER_TOTEM_UPDATE")
engineEvents:RegisterEvent("UNIT_COMBO_POINTS")
engineEvents:SetScript("OnEvent", function(self, event, ...)
if event == "PLAYER_EQUIPMENT_CHANGED" then
local t = 0
local f = CreateFrame("Frame")
f:SetScript("OnUpdate", function(s, el)
t = t + el
if t >= 0.1 then
UpdateEquipmentSetsCache()
CheckAllAuras()
s:SetScript("OnUpdate", nil)
end
end)
else
CheckAllAuras()
end
end)
local combatLogFrame = CreateFrame("Frame")
combatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
combatLogFrame:SetScript("OnEvent", function(self, event, ...)
local _, subEvent, sourceGUID, _, _, destGUID, destName, _, spellID, spellName = ...
local playerGUID = UnitGUID("player")
if sourceGUID == playerGUID and (subEvent == "SPELL_CAST_SUCCESS" or subEvent == "SPELL_SUMMON") then
local summonNameLower = spellName and spellName:lower() or ""
local spellData = spellsLookup[summonNameLower]
if (summonNameLower:find("зеркал") or summonNameLower:find("изображ") or summonNameLower:find("копии") or summonNameLower:find("горгул")) and not summonNameLower:find("тотем") then
local duration = spellData and tonumber(spellData.alertTime) or 30
if duration == 0 then duration = 30 end
activeSummonAlerts["player_summon" .. summonNameLower] = {
endTime = GetTime() + duration,
spellName = spellName,
color = spellData and spellData.color or GetDefaultColor(),
customSize = spellData and spellData.customSize or 24,
isOwnWindow = spellData and spellData.isOwnWindow or false,
configKey = spellData and spellData.name or spellName,
isRealTotem = false
}
CheckAllAuras()
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
activeICDTimers[combatSpellLower] = GetTime() + (tonumber(parsedSeconds) or 45)
CheckAllAuras()
break
end
end
end
end
end)