-- ============================================================
--  RAY Version Check
--  Слушаем RAY_vers -> отвечаем my_RAY_vers со своей версией
-- ============================================================

RAY_addonVersion = "8.0"
RAY_requestPrefix = "RAY_vers"
RAY_replyPrefix   = "my_RAY_vers"

local versionFrame = CreateFrame("Frame")

versionFrame:RegisterEvent("CHAT_MSG_ADDON")
versionFrame:SetScript("OnEvent", function(self, event, ...)
    local prefix, message, channel, sender = ...
    if prefix == RAY_requestPrefix then
        SendAddonMessage(RAY_replyPrefix, RAY_addonVersion, "GUILD")
    end
end)
