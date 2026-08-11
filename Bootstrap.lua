-- Ebon Affix Alert v1.1.2 bootstrap

EbonAffixAlertMainLoaded = false

SLASH_EBONAFFIXALERT1 = "/eaa"
SLASH_EBONAFFIXALERT2 = "/ebonaffix"

SlashCmdList["EBONAFFIXALERT"] = function(msg)
    msg = string.lower(msg or "")

    if not EbonAffixAlertMainLoaded then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[EAA]|r Main addon has not completed loading.")
        DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[EAA]|r Use /console scriptErrors 1 then /reload and send the error.")
        return
    end

    if EbonAffixAlert_HandleSlash then
        EbonAffixAlert_HandleSlash(msg)
    end
end
