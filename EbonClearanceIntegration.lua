-- Ebon Affix Alert - EbonClearance integration
-- Keeps EbonClearance's per-character Keep List synchronized with the items
-- currently present in bags that match EAA's tracked affix selection.
--
-- EbonClearance's public runtime namespace is private to its own addon files,
-- so this compatibility layer uses the SavedVariables schema exposed by the
-- installed EbonClearance build. It owns only entries stamped with the "eaa"
-- auto-protection tag and never removes manual or other EbonClearance entries.

EbonAffixAlertEbonClearance = EbonAffixAlertEbonClearance or {}
local M = EbonAffixAlertEbonClearance

local EAA_AUTO_TAG = "eaa"
local initialized = false

local function IsEbonClearanceAvailable()
    return IsAddOnLoaded
        and IsAddOnLoaded("EbonClearance")
        and type(EbonClearanceDB) == "table"
end

local function GetCharacterKey()
    return (UnitName("player") or "Unknown") .. "-" .. (GetRealmName() or "Unknown")
end

local function GetCharacterDB()
    if not IsEbonClearanceAvailable() then return nil end

    -- EbonClearance v2.34+ stores live per-character list data here while
    -- retaining the old top-level fields as a migration/downgrade snapshot.
    if type(EbonClearanceDB.chars) == "table" then
        local charDB = EbonClearanceDB.chars[GetCharacterKey()]
        if type(charDB) == "table" then
            return charDB
        end
        -- Do not manufacture EbonClearance's character namespace ourselves;
        -- its own EnsureDB migration owns that schema. A later bag event will
        -- retry after EbonClearance has initialized it.
        return nil
    end

    -- Compatibility fallback for older EbonClearance database layouts.
    return EbonClearanceDB
end

local function ItemIDFromLink(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

local function IsConflictingListEntry(charDB,itemID)
    if not charDB or not itemID then return false end
    if charDB.whitelist and charDB.whitelist[itemID] then return true end
    if charDB.deleteList and charDB.deleteList[itemID] then return true end
    if EbonClearanceAccountDB
        and EbonClearanceAccountDB.whitelist
        and EbonClearanceAccountDB.whitelist[itemID] then
        return true
    end
    return false
end

local function RefreshKeepPanel()
    local panel = _G["EbonClearanceOptionsBlacklist"]
    if panel and panel.listUI and panel.listUI.Refresh then
        panel.listUI:Refresh()
    end
end

local function DebugSummary(added,removed,conflicts)
    if not EbonAffixAlertDB or not EbonAffixAlertDB.debug then return end
    if (added or 0) == 0 and (removed or 0) == 0 and (conflicts or 0) == 0 then return end
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff66ccff[EAA Debug]|r EbonClearance Keep sync: +"
        .. tostring(added or 0)
        .. " -" .. tostring(removed or 0)
        .. " conflicts=" .. tostring(conflicts or 0)
    )
end

local function BuildDesiredFromLinks(links)
    local desired = {}
    if not EbonAffixAlertDB
        or EbonAffixAlertDB.enabled == false
        or EbonAffixAlertDB.ebonClearanceKeep == false then
        return desired
    end
    if type(EbonAffixAlert_GetTrackedAffixForItemLink) ~= "function" then
        return desired
    end

    if type(links) ~= "table" then return desired end
    local _,link
    for _,link in pairs(links) do
        if link and EbonAffixAlert_GetTrackedAffixForItemLink(link) then
            local itemID = ItemIDFromLink(link)
            if itemID then desired[itemID] = true end
        end
    end
    return desired
end

local function ApplyDesired(desired)
    local charDB = GetCharacterDB()
    if not charDB then return end

    if type(charDB.blacklist) ~= "table" then charDB.blacklist = {} end
    if type(charDB.blacklistAuto) ~= "table" then charDB.blacklistAuto = {} end

    local keep = charDB.blacklist
    local auto = charDB.blacklistAuto
    local added,removed,conflicts = 0,0,0

    local itemID
    for itemID in pairs(desired) do
        if not keep[itemID] then
            if IsConflictingListEntry(charDB,itemID) then
                -- Match EbonClearance's own cross-list safety rule: never
                -- silently create Keep/Sell/Delete conflicts.
                conflicts = conflicts + 1
            else
                keep[itemID] = true
                auto[itemID] = EAA_AUTO_TAG
                added = added + 1
            end
        end
        -- If the item was already manually kept, or was auto-kept by one of
        -- EbonClearance's own systems, do not claim ownership of that entry.
    end

    -- Remove only entries that EAA itself previously created. If EbonClearance
    -- has since promoted the provenance to another tag (e.g. "equipped"), the
    -- entry is preserved because it now has an independent reason to remain.
    for itemID in pairs(auto) do
        if auto[itemID] == EAA_AUTO_TAG and not desired[itemID] then
            auto[itemID] = nil
            if keep[itemID] then
                keep[itemID] = nil
                removed = removed + 1
            end
        end
    end

    if added > 0 or removed > 0 then
        RefreshKeepPanel()
    end
    DebugSummary(added,removed,conflicts)
end

function M.SyncFromLinks(links)
    if not initialized or not IsEbonClearanceAvailable() then return end
    ApplyDesired(BuildDesiredFromLinks(links))
end

function M.Sync()
    if not initialized or not IsEbonClearanceAvailable() then return end

    local links = {}
    local bag,slot
    for bag=0,4 do
        local slots = GetContainerNumSlots(bag) or 0
        for slot=1,slots do
            local link = GetContainerItemLink(bag,slot)
            if link then
                -- The key is only for dedupe; each distinct rendered item link
                -- is retained so random-affix instances are evaluated correctly.
                links[link] = link
            end
        end
    end
    ApplyDesired(BuildDesiredFromLinks(links))
end

function M.Initialize()
    if initialized then return end
    initialized = true
    M.Sync()
end
