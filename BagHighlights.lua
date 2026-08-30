-- Ebon Affix Alert v1.3.0 bag highlighting
-- Bag-addon-specific visual adapters live here so the core stays focused on
-- affix tracking/alerting. Supported adapters:
--   * Blizzard default 3.3.5 bag frames
--   * Bagnon 2.13.3
--   * AdiBags (provided WoTLK 3.3.5 backport)
--   * OneBag3 (provided r131 WoTLK build)
--
-- Performance design:
--   * no OnUpdate loop
--   * reacts only when the active bag UI already repaints an item button
--   * skips Poor/Common items before any affix lookup
--   * creates textures lazily only for buttons that actually need a highlight
--   * reuses those textures for the lifetime of the bag button

EbonAffixAlertBagHighlights = EbonAffixAlertBagHighlights or {}
local M = EbonAffixAlertBagHighlights

local GLOW_TEXTURE = "Interface\\AddOns\\EbonAffixAlert\\Media\\CrystallineBagGlow"
local blizzardHooked = false
local bagnonHooked = false
local adibagsHooked = false
local onebag3Hooked = false
local activeAdapter = nil

-- Weak keys mean buttons disappear from this cache automatically if Bagnon
-- destroys them. The table exists only so tracking-option changes can refresh
-- already-visible Bagnon slots without forcing Bagnon to rebuild its window.
local bagnonButtons = setmetatable({}, { __mode = "k" })

-- Same idea for AdiBags: cache only button objects already surfaced by its
-- repaint message, and keep weak keys so released/recycled buttons do not
-- become permanent references owned by EAA.
local adibagsButtons = setmetatable({}, { __mode = "k" })

-- OneBag3 creates persistent slot frames for the live bags. Weak keys keep the
-- refresh cache from owning those frames and mirror the other addon adapters.
local onebag3Buttons = setmetatable({}, { __mode = "k" })

local function IsTrackedItemLink(link)
    if not link then return nil end

    -- Prefer the core link-aware matcher so Weapon source items use the exact
    -- same detection path as loot alerts, with a canonical-name fallback.
    if EbonAffixAlert_GetTrackedAffixForItemLink then
        return EbonAffixAlert_GetTrackedAffixForItemLink(link)
    end

    -- Compatibility fallback for an unexpectedly mixed module/core build.
    if EbonAffixAlert_IsItemNameTracked then
        local itemName = link:match("|h%[(.-)%]|h") or link:match("%[(.-)%]")
        if itemName then return EbonAffixAlert_IsItemNameTracked(itemName) end
    end

    return nil
end

local function GetOrCreateGlow(button)
    if not button then return nil end
    if button.eaaBagGlow then return button.eaaBagGlow end

    -- Broad outer halo: makes the slot immediately visible in a crowded bag.
    local outer = button:CreateTexture(nil,"OVERLAY")
    outer:SetTexture(GLOW_TEXTURE)
    outer:SetBlendMode("ADD")
    outer:SetPoint("TOPLEFT",button,"TOPLEFT",-9,9)
    outer:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",9,-9)
    outer:SetAlpha(0.90)
    outer:Hide()

    -- Crisp crystalline rim around the normal item-quality border.
    local rim = button:CreateTexture(nil,"OVERLAY")
    rim:SetTexture(GLOW_TEXTURE)
    rim:SetBlendMode("ADD")
    rim:SetPoint("TOPLEFT",button,"TOPLEFT",-4,4)
    rim:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",4,-4)
    rim:SetAlpha(1.00)
    rim:Hide()

    -- Faint inset copy. It puts a small amount of the crystalline light just
    -- inside the icon edge without tinting/washing out the whole item artwork.
    local inner = button:CreateTexture(nil,"OVERLAY")
    inner:SetTexture(GLOW_TEXTURE)
    inner:SetBlendMode("ADD")
    inner:SetPoint("TOPLEFT",button,"TOPLEFT",1,-1)
    inner:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-1,1)
    inner:SetAlpha(0.32)
    inner:Hide()

    local glow = { outer = outer, rim = rim, inner = inner }
    button.eaaBagGlow = glow
    return glow
end

local function HideGlow(button)
    local glow = button and button.eaaBagGlow
    if not glow then return end
    if glow.outer then glow.outer:Hide() end
    if glow.rim then glow.rim:Hide() end
    if glow.inner then glow.inner:Hide() end
end

local function ShowGlow(button,quality)
    local r,g,b = GetItemQualityColor(quality)
    local glow = GetOrCreateGlow(button)
    if not glow then return end

    if glow.outer then
        glow.outer:SetVertexColor(r or 1,g or 1,b or 1,1)
        glow.outer:Show()
    end
    if glow.rim then
        glow.rim:SetVertexColor(r or 1,g or 1,b or 1,1)
        glow.rim:Show()
    end
    if glow.inner then
        glow.inner:SetVertexColor(r or 1,g or 1,b or 1,1)
        glow.inner:Show()
    end
end

local function UpdateButtonFromItem(button,link,quality)
    if not button then return end

    if not EbonAffixAlertDB
        or not EbonAffixAlertDB.enabled
        or not EbonAffixAlertDB.bagHighlights then
        HideGlow(button)
        return
    end

    if not link then
        HideGlow(button)
        return
    end

    -- Some newly-cached fixed-source weapons can briefly have no quality value
    -- even though their item link is available. Fall back to GetItemInfo.
    if not quality and GetItemInfo then
        quality = select(3,GetItemInfo(link))
    end

    -- Ebonhold affixes do not drop on Poor/Common items. 2=Uncommon, 3=Rare,
    -- 4=Epic, 5=Legendary. Keep the cheap rarity gate before affix matching.
    if not quality or quality < 2 or quality > 5 then
        HideGlow(button)
        return
    end

    if not IsTrackedItemLink(link) then
        HideGlow(button)
        return
    end

    ShowGlow(button,quality)
end

local function UpdateButton(button,bag,slot)
    if not button then return end

    local link = GetContainerItemLink(bag,slot)
    local _,_,_,quality = GetContainerItemInfo(bag,slot)
    UpdateButtonFromItem(button,link,quality)
end

local function UpdateBlizzardFrame(frame)
    if not frame or not frame.GetName or not frame.GetID then return end
    local frameName = frame:GetName()
    if not frameName then return end

    local bag = frame:GetID()
    local size = frame.size or GetContainerNumSlots(bag) or 0
    local i
    for i=1,size do
        local button = _G[frameName .. "Item" .. i]
        if button then
            UpdateButton(button,bag,button:GetID())
        end
    end
end

-- ---------------------------------------------------------------------------
-- Active bag UI detection
-- ---------------------------------------------------------------------------
-- Select exactly one highlighting backend for the current UI session.
-- Addon-manager bag replacements are preferred over Blizzard's default bags.
-- This runs once during EAA initialization after addons have loaded.
local function DetectActiveAdapter()
    if activeAdapter then return activeAdapter end

    if IsAddOnLoaded and IsAddOnLoaded("AdiBags") then
        activeAdapter = "ADIBAGS"
    elseif IsAddOnLoaded and IsAddOnLoaded("Bagnon") then
        activeAdapter = "BAGNON"
    elseif IsAddOnLoaded and IsAddOnLoaded("OneBag3") then
        activeAdapter = "ONEBAG3"
    else
        activeAdapter = "BLIZZARD"
    end

    return activeAdapter
end

-- ---------------------------------------------------------------------------
-- Blizzard adapter
-- ---------------------------------------------------------------------------
local function InitializeBlizzardAdapter()
    if blizzardHooked then return end
    if not hooksecurefunc or not ContainerFrame_Update then return end

    blizzardHooked = true
    hooksecurefunc("ContainerFrame_Update",function(frame)
        UpdateBlizzardFrame(frame)
    end)
end

-- ---------------------------------------------------------------------------
-- Bagnon 2.13.3 adapter
-- ---------------------------------------------------------------------------
-- Verified against the user's installed Bagnon 2.13.3 source:
--   * the item class is Bagnon.ItemSlot (not Bagnon.Item)
--   * ItemSlot:Update() repaints each visible item button
--   * GetBag() returns the live bag ID
--   * GetID() is the slot number
--   * GetItem() returns the link already resolved by Bagnon
--   * GetItemSlotInfo() returns quality alongside that link
--
-- Hooking ItemSlot:Update() keeps EAA fully event-driven. Bagnon itself calls
-- Update() from its bag/item events, so EAA adds no polling or OnUpdate loop.
local function SamePlayerName(a,b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    a = a:match("^[^-]+") or a
    b = b:match("^[^-]+") or b
    return a:lower() == b:lower()
end

local function IsCurrentBagnonPlayer(button)
    if not button or type(button.GetPlayer) ~= "function" then return true end

    local ok,player = pcall(button.GetPlayer,button)
    if not ok or not player then return true end

    local current = UnitName and UnitName("player")
    return current and SamePlayerName(player,current)
end

local function UpdateBagnonButton(button)
    if not button then return end
    bagnonButtons[button] = true

    if type(button.GetBag) ~= "function"
        or type(button.GetID) ~= "function"
        or type(button.GetItem) ~= "function" then
        HideGlow(button)
        return
    end

    local ok,bag = pcall(button.GetBag,button)
    if not ok or type(bag) ~= "number" then
        HideGlow(button)
        return
    end

    -- ItemSlot is shared by inventory, bank, keyring and cached-character
    -- displays. Only the current character's normal bags should glow.
    local maxBag = NUM_BAG_SLOTS or 4
    if bag < 0 or bag > maxBag or not IsCurrentBagnonPlayer(button) then
        HideGlow(button)
        return
    end

    local slot = button:GetID()
    if type(slot) ~= "number" or slot < 1 then
        HideGlow(button)
        return
    end

    -- Use Bagnon's own already-resolved item data instead of asking the
    -- container API to rediscover the same slot. This is both cheaper and
    -- robust when Bagnon recycles Blizzard ContainerFrame item buttons.
    local link = button:GetItem()
    local quality
    if type(button.GetItemSlotInfo) == "function" then
        local infoOK,_,_,_,q = pcall(button.GetItemSlotInfo,button)
        if infoOK then quality = q end
    end

    UpdateButtonFromItem(button,link,quality)
end

local function InitializeBagnonAdapter()
    if bagnonHooked then return end
    if not hooksecurefunc then return end
    if type(Bagnon) ~= "table"
        or type(Bagnon.ItemSlot) ~= "table"
        or type(Bagnon.ItemSlot.Update) ~= "function" then
        return
    end

    bagnonHooked = true
    hooksecurefunc(Bagnon.ItemSlot,"Update",function(button)
        UpdateBagnonButton(button)
    end)
end

-- ---------------------------------------------------------------------------
-- AdiBags adapter
-- ---------------------------------------------------------------------------
-- Verified against the user-supplied WoTLK 3.3.5 AdiBags source.
--
-- widgets/ItemButton.lua stores:
--   button.bag
--   button.slot
--   button.itemLink
-- and sends:
--   addon:SendMessage("AdiBags_UpdateButton", self)
-- at the end of every ItemButton:Update().
--
-- Registering for that existing AceEvent message gives EAA a clean,
-- event-driven integration without reaching into AdiBags' local button class
-- and without adding an OnUpdate/polling loop.
local function UpdateAdiBagsButton(button)
    if not button then return end
    adibagsButtons[button] = true

    local bag = button.bag
    local slot = button.slot

    if type(bag) ~= "number" or type(slot) ~= "number" then
        HideGlow(button)
        return
    end

    -- AdiBags uses the same item button class for bank/keyring containers.
    -- Highlight only the live inventory bags 0-4.
    local maxBag = NUM_BAG_SLOTS or 4
    if bag < 0 or bag > maxBag then
        HideGlow(button)
        return
    end

    local link = button.itemLink
    if not link and type(button.GetItemLink) == "function" then
        link = button:GetItemLink()
    end
    if not link then
        link = GetContainerItemLink(bag,slot)
    end

    local quality
    if link and GetItemInfo then
        quality = select(3,GetItemInfo(link))
    end

    UpdateButtonFromItem(button,link,quality)
end

local function InitializeAdiBagsAdapter()
    if adibagsHooked then return end
    if not LibStub then return end

    -- AdiBags' addon object is intentionally not guaranteed to be a global in
    -- release builds, so discover it through AceAddon instead.
    local aceAddon = LibStub("AceAddon-3.0",true)
    local aceEvent = LibStub("AceEvent-3.0",true)
    if not aceAddon or not aceEvent then return end

    local adi = aceAddon:GetAddon("AdiBags",true)
    if not adi then return end

    -- Embed AceEvent only once so this module can subscribe to AdiBags' own
    -- AdiBags_UpdateButton message.
    aceEvent:Embed(M)
    -- AceEvent function-reference callbacks receive (message, ...).
    -- They do NOT prepend the registered object as a first argument.
    M:RegisterMessage("AdiBags_UpdateButton",function(message,button)
        UpdateAdiBagsButton(button)
    end)

    adibagsHooked = true
end

local function RefreshAdiBagsVisible()
    local button
    for button in pairs(adibagsButtons) do
        if button and button.IsShown and button:IsShown() then
            UpdateAdiBagsButton(button)
        end
    end
end

-- ---------------------------------------------------------------------------
-- OneBag3 adapter
-- ---------------------------------------------------------------------------
-- Verified against the user-supplied OneBag3 r131 source.
--
-- OneCore creates each inventory slot with ContainerFrameItemButtonTemplate and
-- stores it as OneBag3.frame.slots["bag:slot"]. OneBag3's BAG_UPDATE path calls
-- OneCore:UpdateBag(bag), which then repaints that bag with
-- ContainerFrame_Update(self.frame.bags[bag]).
--
-- EAA hooks OneBag3:UpdateBag() itself and decorates only that bag's slot
-- buttons after OneBag3 has finished its normal update. No polling is added.
local function UpdateOneBag3Slot(button,bag,slot)
    if not button then return end
    onebag3Buttons[button] = true
    UpdateButton(button,bag,slot)
end

local function UpdateOneBag3Bag(onebag,bag)
    if not onebag or type(bag) ~= "number" then return end

    local maxBag = NUM_BAG_SLOTS or 4
    if bag < 0 or bag > maxBag then return end

    local frame = onebag.frame
    if not frame or not frame.bags or not frame.bags[bag] then return end

    local bagFrame = frame.bags[bag]
    local size = bagFrame.size or GetContainerNumSlots(bag) or 0
    local slot
    for slot=1,size do
        local button
        if type(onebag.GetSlot) == "function" then
            button = onebag:GetSlot(bag,slot)
        elseif bagFrame.slots then
            button = bagFrame.slots[slot]
        end

        if button then
            UpdateOneBag3Slot(button,bag,slot)
        end
    end
end

local function InitializeOneBag3Adapter()
    if onebag3Hooked then return end
    if not hooksecurefunc or not LibStub then return end

    local aceAddon = LibStub("AceAddon-3.0",true)
    if not aceAddon then return end

    local onebag = aceAddon:GetAddon("OneBag3",true)
    if not onebag or type(onebag.UpdateBag) ~= "function" then return end

    onebag3Hooked = true
    hooksecurefunc(onebag,"UpdateBag",function(self,bag)
        UpdateOneBag3Bag(self,bag)
    end)

    -- If the OneBag window is already open when EAA initializes, populate the
    -- current visible buttons immediately rather than waiting for BAG_UPDATE.
    if onebag.frame and onebag.frame.IsShown and onebag.frame:IsShown() then
        local bag
        for bag=0,(NUM_BAG_SLOTS or 4) do
            UpdateOneBag3Bag(onebag,bag)
        end
    end
end

local function RefreshOneBag3Visible()
    local button
    for button in pairs(onebag3Buttons) do
        if button and button.IsShown and button:IsShown() then
            local parent = button:GetParent()
            local bag = parent and parent.GetID and parent:GetID()
            local slot = button.GetID and button:GetID()
            if type(bag) == "number" and type(slot) == "number" then
                UpdateOneBag3Slot(button,bag,slot)
            end
        end
    end
end

local function RefreshBlizzardVisible()
    local i
    for i=1,(NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame:IsShown() then
            UpdateBlizzardFrame(frame)
        end
    end
end

local function RefreshBagnonVisible()
    local button
    for button in pairs(bagnonButtons) do
        if button and button.IsShown and button:IsShown() then
            UpdateBagnonButton(button)
        end
    end
end

function M.RefreshVisible()
    local adapter = DetectActiveAdapter()

    if adapter == "ADIBAGS" then
        RefreshAdiBagsVisible()
    elseif adapter == "BAGNON" then
        RefreshBagnonVisible()
    elseif adapter == "ONEBAG3" then
        RefreshOneBag3Visible()
    else
        RefreshBlizzardVisible()
    end
end

function M.Initialize()
    local adapter = DetectActiveAdapter()

    if adapter == "ADIBAGS" then
        InitializeAdiBagsAdapter()
    elseif adapter == "BAGNON" then
        InitializeBagnonAdapter()
    elseif adapter == "ONEBAG3" then
        InitializeOneBag3Adapter()
    else
        InitializeBlizzardAdapter()
    end

    M.RefreshVisible()
end
