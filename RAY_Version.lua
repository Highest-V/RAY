-- ============================================================
--  RAY Version Check (Private)
-- ============================================================

local RAY_addonVersion  = "8.4"
local RAY_requestPrefix = "RAY_HV_REQ"
local RAY_replyPrefix   = "RAY_HV_ANS"

local versionFrame = CreateFrame("Frame")
versionFrame:RegisterEvent("CHAT_MSG_ADDON")
versionFrame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if prefix == RAY_requestPrefix then
        local replyChannel = (channel == "RAID" or channel == "PARTY" or channel == "BATTLEGROUND" or channel == "GUILD") and channel or "GUILD"
        SendAddonMessage(RAY_replyPrefix, RAY_addonVersion, replyChannel)
    end
end)