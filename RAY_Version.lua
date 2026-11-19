-- ============================================================
--  RAY Version Check (Private)
-- ============================================================

local RAY_addonVersion  = "8.5"
local RAY_requestPrefix = "RAY_HV_REQ"
local RAY_replyPrefix   = "RAY_HV_ANS"

local versionFrame = CreateFrame("Frame")
versionFrame:RegisterEvent("CHAT_MSG_ADDON")
versionFrame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if prefix == RAY_requestPrefix then
        local requester = (message and message ~= "") and message or sender or ""
        local replyChannel = channel
        if replyChannel ~= "RAID" and replyChannel ~= "PARTY" and replyChannel ~= "BATTLEGROUND" and replyChannel ~= "GUILD" then
            if GetNumRaidMembers() > 0 then replyChannel = "RAID"
            elseif GetNumPartyMembers() > 0 then replyChannel = "PARTY"
            else replyChannel = "GUILD" end
        end
        SendAddonMessage(RAY_replyPrefix, RAY_addonVersion .. "|" .. requester, replyChannel)
    end
end)
