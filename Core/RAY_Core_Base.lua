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

-- Инициализация пулов и кэшей
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

-- Базовые утилиты
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

-- Динамическое создание независимых окон аур
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
    fstr:SetPoint("CENTER", cf, "CENTER") fstr:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
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

-- ============================================================================
-- ГЛАВНЫЙ ЦИКЛ ПРОВЕРКИ ВСЕХ ТРИГГЕРОВ (ОБЪЕДИНЯЕТ МОДУЛИ)
-- ============================================================================
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

    -- [Хардкод триггер]: Музыкальная шкатулка Сильваны
    if RAY_Engine.sylvanasAlertActive and RAY_Config.boxHunterEnabled then
        if curTime <= RAY_Engine.sylvanasAlertActive then
            RAY_Engine.uniqueAlerts["|cffFF5555[RAY Детектор]: Шкатулку завел!|r"] = true
        else RAY_Engine.sylvanasAlertActive = false end
    end

    -- [Триггер]: Комбо-Поинты
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

    -- Вызовы разделенных модулей логики ядра
    if RAY_Engine.ProcessSets then mainFrameFontSize = RAY_Engine.ProcessSets(activeProfile, inCombat, currentZone, curTime, mainFrameFontSize) end
    if RAY_Engine.ProcessBuffs then mainFrameFontSize = RAY_Engine.ProcessBuffs(activeProfile, inCombat, currentZone, curTime, mainFrameFontSize) end
    if RAY_Engine.ProcessDebuffs then mainFrameFontSize = RAY_Engine.ProcessDebuffs(activeProfile, inCombat, currentZone, curTime, mainFrameFontSize) end

    -- Отрисовка результатов на экране
    table.wipe(RAY_Engine.alertStringTable)
    for k in pairs(RAY_Engine.uniqueAlerts) do table.insert(RAY_Engine.alertStringTable, k) end
    local currentHash = RAY_Engine.BuildStateHash()
    if currentHash == RAY_Engine.Engine_lastDbgHash then return end
    RAY_Engine.Engine_lastDbgHash = currentHash
    
    if #RAY_Engine.alertStringTable > 0 then
        if RAY_Engine.text and RAY_Engine.text.SetText then
            RAY_Engine.text:SetText(table.concat(RAY_Engine.alertStringTable, "\n"))
            RAY_Engine.text:SetFont("Fonts\\FRIZQT__.TTF", mainFrameFontSize, "OUTLINE")
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
cf.labelString:SetFont("Fonts\FRIZQT__.TTF", cfData.size or 24, "OUTLINE")
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
-- Секундный таймер обновлений (Метроном)
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
-- Создание главного фрейма вывода текста
RAY_Engine.frame = CreateFrame("Frame", "RAY_MainFrame", UIParent)
RAY_Engine.frame:SetSize(400, 60) RAY_Engine.frame:SetPoint("CENTER", 0, 150) RAY_Engine.frame:Hide()
RAY_Engine.dragBg, RAY_Engine.dragBorder = RAY_Engine.frame:CreateTexture(nil, "BACKGROUND"), RAY_Engine.frame:CreateTexture(nil, "OVERLAY")
RAY_Engine.dragBg:SetAllPoints() RAY_Engine.dragBg:SetTexture(0.1, 0.1, 0.1, 0.6) RAY_Engine.dragBg:Hide()
RAY_Engine.dragBorder:SetAllPoints() RAY_Engine.dragBorder:SetTexture("Interface\Tooltips\UI-Tooltip-Border") RAY_Engine.dragBorder:Hide()
RAY_Engine.text = RAY_Engine.frame:CreateFontString("RAY_MainFrameText", "OVERLAY", "GameFontNormalLarge")
RAY_Engine.text:SetPoint("CENTER", RAY_Engine.frame, "CENTER") RAY_Engine.text:SetFont("Fonts\FRIZQT__.TTF", 24, "OUTLINE") RAY_Engine.text:SetTextColor(0.5, 0.95, 0.8) RAY_text = RAY_Engine.text
RAY_Engine.frame:SetScript("OnUpdate", function(self, elapsed)
if RAY_Engine.text and RAY_Engine.text:GetText() ~= "" and not self:IsMouseEnabled() then
local factor = (math.sin(GetTime() * 4) + 1) / 2
self:SetAlpha(0.4 + factor * 0.6)
else
self:SetAlpha(1.0)
end
end)
SetupDragAndPosition(RAY_Engine.frame)
-- Регистрация стандартных событий игрока
local engineEvents = CreateFrame("Frame")
engineEvents:RegisterEvent("ADDON_LOADED")
engineEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
engineEvents:RegisterEvent("UNIT_AURA")
engineEvents:RegisterEvent("UNIT_INVENTORY_CHANGED")
engineEvents:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
engineEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
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
if RAY_Engine.UpdateEquipmentSetsCache then RAY_Engine.UpdateEquipmentSetsCache() end
if RAY_Engine.UpdateCustomGearEnchantCache then RAY_Engine.UpdateCustomGearEnchantCache() end
RAY_Engine.Engine_lastDbgHash = ""
RAY_Engine.CheckAllAuras()
elseif event == "PLAYER_EQUIPMENT_CHANGED" or (event == "UNIT_INVENTORY_CHANGED" and arg1 == "player") or (event == "UNIT_AURA" and arg1 == "player") then
if RAY_Engine.UpdateEquipmentSetsCache then RAY_Engine.UpdateEquipmentSetsCache() end
if RAY_Engine.UpdateCustomGearEnchantCache then RAY_Engine.UpdateCustomGearEnchantCache() end
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
else
RAY_Engine.Engine_lastDbgHash = ""
RAY_Engine.CheckAllAuras()
end
end)
-- Перехват боевого лога (Combat Log Unfiltered)
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
-- Активация Музыкальной шкатулки Сильваны
if subEvent == "SPELL_CAST_SUCCESS" and spellID == 72007 then
RAY_Engine.sylvanasAlertActive = curTime + 6.0
RAY_Engine.Engine_lastDbgHash = ""
RAY_Engine.CheckAllAuras()
return
end
-- Логика отслеживания призывов (Гаргулья, не-тотемные существа)
if sourceGUID == playerGUID and (subEvent == "SPELL_CAST_SUCCESS" or subEvent == "SPELL_SUMMON") then
local summonNameLower = spellName and spellName:lower() or ""
if summonNameLower:find("тотем") or summonNameLower:find("totem") then
return
end
local spellData = RAY_Engine.spellsLookup[summonNameLower]
if spellData and spellData.isSummonObject then
local duration = tonumber(spellData.alertTime) or 30
if duration == 0 then duration = 30 end
RAY_Engine.activeSummonAlerts["non_totem_summon" .. summonNameLower] = {
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
-- Логика фиксации внутреннего КД аксессуаров (ICD триньки)
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