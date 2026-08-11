-- Ebon Affix Alert v1.1.1
-- WoW 3.3.5a compatible core

-- General affixes: {name, fallback max rank}. Ebonhold API overrides rank when available.
local generalAffixes = {
    {"Arcane Mind",6},
    {"Armor Rend",6},
    {"Bulwark",6},
    {"Cold",6},
    {"Feral Grace",6},
    {"Fortified by Pain",6},
    {"Frost Breath",6},
    {"Frozen Pulse",6},
    {"Infinite Star",6},
    {"Iron Will",6},
    {"Ironhide",6},
    {"Keen Strikes",6},
    {"Living Tide",6},
    {"Mender's Surge",6},
    {"Overwhelming Force",6},
    {"Pet Power",6},
    {"Quick Instincts",6},
    {"Relentless Crits",6},
    {"Shield Block",6},
    {"Spell Mastery",4},
    {"Spirit Surge",6},
    {"Stalwart",6},
    {"Temporal Flux",6},
    {"Thick Hide",6},
    {"Wellspring",6}
}

local weaponAffixes = {
    "Affliction",
    "Azzinoth",
    "Bladestorm",
    "Bloodlust",
    "Clarity",
    "Concussion",
    "Decay",
    "Devastation",
    "Dissolution",
    "Execution",
    "Ferocity",
    "Fire Blast",
    "Flame Wrath",
    "Flurry",
    "Fortification",
    "Frailty",
    "Frost Arrow",
    "Fury",
    "Glaciation",
    "Hemorrhage",
    "Incineration",
    "Judgement",
    "Julie's Blessing",
    "Keeper's Sting",
    "Maiming",
    "Permafrost",
    "Pyromancy",
    "Rending",
    "Resurgence",
    "Shackling",
    "Shahram",
    "Speed",
    "Sulfuras",
    "Thunderfury",
    "Twin Shot",
    "Undead",
    "Val'anyr",
    "Vampirism",
    "Venom",
    "Vulnerability",
    "Wilds"
}

-- Rank labels used by the item-name matcher and settings grid.
local roman = {[1]="I",[2]="II",[3]="III",[4]="IV",[5]="V",[6]="VI",[7]="VII",[8]="VIII",[9]="IX",[10]="X"}

local romanToNumber = {
    I=1, II=2, III=3, IV=4, V=5, VI=6,
    VII=7, VIII=8, IX=9, X=10
}

local function GetConfiguredFallbackRank(affixName)
    local _, entry
    for _,entry in ipairs(generalAffixes) do
        if entry[1] == affixName then
            return entry[2]
        end
    end
    return 1
end

local function GetMaxRankForAffix(affixName)
    local serverEntry = serverAffixCatalog and serverAffixCatalog[affixName]
    if serverEntry and serverEntry.maxRank and serverEntry.maxRank > 0 then
        return serverEntry.maxRank
    end
    return GetConfiguredFallbackRank(affixName)
end

table.sort(generalAffixes, function(a,b)
    return string.lower(a[1]) < string.lower(b[1])
end)

table.sort(weaponAffixes, function(a,b)
    return string.lower(a) < string.lower(b)
end)

local panel
local minimapButton
local lootWindow
local interfaceOptionsPanel
local CreateInterfaceOptionsPanel
local UpdateMinimapEnabledVisual
local UpdateMinimapLootCount
local GetColoredLootHistoryCount
local ApplyAffixFilters
local generalChecks = {}
local generalRows = {}
local weaponChecks = {}
local weaponRows = {}
local lootHistory = {}
local filterText = ""
local trackedOnly = false
local affixIconCache = {}
local serverAffixCatalog = {}
local weaponProcDescriptionsStale = true
local iconRefreshFrame
local perfMonitorFrame
local perfMonitorEnabled = false
local bagSnapshot
local recentAlerts
local activeAlerts
local RefreshAffixIconsFromEbonhold
local RequestEbonholdAffixIcons
local ApplyAffixIconsToRows
local ShowAffixTooltip
local supportCopyWindow

local function EnsureDB()
    if type(EbonAffixAlertDB) ~= "table" then EbonAffixAlertDB = {} end
    if EbonAffixAlertDB.enabled == nil then EbonAffixAlertDB.enabled = true end

    if not EbonAffixAlertDB.v041DefaultsApplied then
        EbonAffixAlertDB.announceToRaidWarning = true
        EbonAffixAlertDB.alertSound = true
        EbonAffixAlertDB.v041DefaultsApplied = true
    end

    if EbonAffixAlertDB.announceToRaidWarning == nil then
        EbonAffixAlertDB.announceToRaidWarning = true
    end
    if EbonAffixAlertDB.alertSound == nil then
        EbonAffixAlertDB.alertSound = true
    end
    if EbonAffixAlertDB.debug == nil then EbonAffixAlertDB.debug = false end
    if EbonAffixAlertDB.uiStyle == nil then EbonAffixAlertDB.uiStyle = "Modern" end
    if EbonAffixAlertDB.uiStyle ~= "Modern" and EbonAffixAlertDB.uiStyle ~= "Fantasy" then
        EbonAffixAlertDB.uiStyle = "Modern"
    end
    if type(EbonAffixAlertDB.tracked) ~= "table" then EbonAffixAlertDB.tracked = {} end
    if type(EbonAffixAlertDB.affixIcons) ~= "table" then EbonAffixAlertDB.affixIcons = {} end
    if type(EbonAffixAlertDB.minimap) ~= "table" then
        EbonAffixAlertDB.minimap = { angle = 225, radius = 80 }
    end
    if EbonAffixAlertDB.minimap.show == nil then
        EbonAffixAlertDB.minimap.show = true
    end

    if type(EbonAffixAlertDB.lootWindow) ~= "table" then
        EbonAffixAlertDB.lootWindow = {}
    end
    if EbonAffixAlertDB.lootWindow.show == nil then
        EbonAffixAlertDB.lootWindow.show = false
    end
    if EbonAffixAlertDB.lootWindow.maxEntries == nil then
        EbonAffixAlertDB.lootWindow.maxEntries = 50
    end
    if EbonAffixAlertDB.lootWindow.width == nil then
        EbonAffixAlertDB.lootWindow.width = 300
    end
    if EbonAffixAlertDB.lootWindow.height == nil then
        EbonAffixAlertDB.lootWindow.height = 300
    end
    if EbonAffixAlertDB.lootWindow.transparent == nil then
        EbonAffixAlertDB.lootWindow.transparent = false
    end

    if type(EbonAffixAlertCharacterDB) ~= "table" then
        EbonAffixAlertCharacterDB = {}
    end
end

local function GKey(name, rank)
    return "GENERAL:" .. name .. ":" .. tostring(rank)
end

local function WKey(name)
    return "WEAPON:" .. name
end

local function GetEAAVersion()
    if GetAddOnMetadata then
        return GetAddOnMetadata("EbonAffixAlert","Version") or "1.1.1"
    end
    return "1.1.1"
end

-- Two lightweight skins; the selected style is saved in EbonAffixAlertDB.
local EAA_THEMES = {
    Modern = {
        frameBG = {0.03,0.04,0.09,1.00},
        frameBorder = {0.24,0.56,0.95,0.95},
        innerBG = {0.08,0.10,0.18,0.70},
        innerBorder = {0.44,0.30,0.88,0.55},
        headerBG = {0.07,0.09,0.20,0.92},
        cyan = {0.45,0.83,1.00},
        purple = {0.75,0.52,1.00},
        title = {0.90,0.95,1.00},
        text = {0.86,0.89,0.98},
        muted = {0.68,0.72,0.86},
        buttonBG = {0.08,0.12,0.23,0.94},
        buttonBorder = {0.30,0.56,0.96,0.88},
        buttonHoverBG = {0.11,0.17,0.30,0.96},
        buttonHoverBorder = {0.45,0.84,1.00,0.95},
        buttonPressedBG = {0.21,0.14,0.35,0.96},
        buttonPressedBorder = {0.78,0.56,1.00,0.95},
        accentAlpha = 0.95,
        accent2Alpha = 0.70
    },
    Fantasy = {
        frameBG = {0.055,0.035,0.030,1.00},
        frameBorder = {0.72,0.52,0.24,0.98},
        innerBG = {0.105,0.065,0.060,0.92},
        innerBorder = {0.46,0.30,0.16,0.90},
        headerBG = {0.115,0.055,0.055,0.98},
        cyan = {0.93,0.70,0.30},
        purple = {0.72,0.43,0.90},
        title = {1.00,0.91,0.68},
        text = {0.95,0.89,0.79},
        muted = {0.73,0.63,0.55},
        buttonBG = {0.14,0.085,0.075,0.98},
        buttonBorder = {0.64,0.44,0.20,0.96},
        buttonHoverBG = {0.21,0.11,0.10,0.99},
        buttonHoverBorder = {0.91,0.69,0.30,0.99},
        buttonPressedBG = {0.11,0.055,0.065,0.99},
        buttonPressedBorder = {0.73,0.46,0.88,0.99},
        accentAlpha = 0.82,
        accent2Alpha = 0.68
    }
}

local EAA_THEME = EAA_THEMES.Modern
local EAA_THEME_NAME = "Modern"
local EAA_MEDIA_PATH = "Interface\\AddOns\\EbonAffixAlert\\Media\\"
local eaaThemedFrames = {}
local eaaThemedInsets = {}
local eaaThemedButtons = {}
local eaaThemedChecks = {}
local eaaThemedText = {}

local function AddUnique(list,obj)
    local _,v
    for _,v in ipairs(list) do
        if v == obj then return end
    end
    table.insert(list,obj)
end

local function ApplyEAAFrameSkin(frame)
    AddUnique(eaaThemedFrames,frame)

    frame:SetBackdrop({
        bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Buttons\\WHITE8X8",
        tile=true, tileSize=16, edgeSize=(EAA_THEME_NAME == "Fantasy") and 2 or 1,
        insets={left=1,right=1,top=1,bottom=1}
    })

    if not frame.eaaHeader then
        frame.eaaHeader = frame:CreateTexture(nil,"BACKGROUND")
        frame.eaaHeader:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.eaaHeader:SetPoint("TOPLEFT",4,-4)
        frame.eaaHeader:SetPoint("TOPRIGHT",-4,-4)

        frame.eaaAccentA = frame:CreateTexture(nil,"BORDER")
        frame.eaaAccentA:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.eaaAccentA:SetHeight(2)

        frame.eaaAccentB = frame:CreateTexture(nil,"BORDER")
        frame.eaaAccentB:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.eaaAccentB:SetHeight(1)

        frame.eaaTitlePlaque = frame:CreateTexture(nil,"ARTWORK")
        frame.eaaTopLeftOrnament = frame:CreateTexture(nil,"ARTWORK")
        frame.eaaTopRightOrnament = frame:CreateTexture(nil,"ARTWORK")
        frame.eaaBottomLeftOrnament = frame:CreateTexture(nil,"ARTWORK")
        frame.eaaBottomRightOrnament = frame:CreateTexture(nil,"ARTWORK")

        frame.eaaBorderTop = frame:CreateTexture(nil,"OVERLAY")
        frame.eaaBorderBottom = frame:CreateTexture(nil,"OVERLAY")
        frame.eaaBorderLeft = frame:CreateTexture(nil,"OVERLAY")
        frame.eaaBorderRight = frame:CreateTexture(nil,"OVERLAY")

        frame.eaaBorderTop:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.eaaBorderBottom:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.eaaBorderLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.eaaBorderRight:SetTexture("Interface\\Buttons\\WHITE8X8")

        frame.eaaBorderTop:SetPoint("TOPLEFT",0,0)
        frame.eaaBorderTop:SetPoint("TOPRIGHT",0,0)
        frame.eaaBorderTop:SetHeight(2)

        frame.eaaBorderBottom:SetPoint("BOTTOMLEFT",0,0)
        frame.eaaBorderBottom:SetPoint("BOTTOMRIGHT",0,0)
        frame.eaaBorderBottom:SetHeight(2)

        frame.eaaBorderLeft:SetPoint("TOPLEFT",0,0)
        frame.eaaBorderLeft:SetPoint("BOTTOMLEFT",0,0)
        frame.eaaBorderLeft:SetWidth(2)

        frame.eaaBorderRight:SetPoint("TOPRIGHT",0,0)
        frame.eaaBorderRight:SetPoint("BOTTOMRIGHT",0,0)
        frame.eaaBorderRight:SetWidth(2)
    end

    local allowTransparency = frame:GetName() == "EbonAffixAlertLootWindow"
    local isTransparent = allowTransparency and frame.eaaTransparent
    local alphaScale = isTransparent and 0.28 or 1
    local borderScale = isTransparent and 0.62 or 1
    local useFantasyOrnaments = (EAA_THEME_NAME == "Fantasy") and (
        frame:GetName() == "EbonAffixAlertOptionsFrame" or frame:GetName() == "EbonAffixAlertLootWindow"
    )
    local useFantasyPlaque = useFantasyOrnaments and frame:GetName() == "EbonAffixAlertOptionsFrame"

    frame:SetBackdropColor(
        EAA_THEME.frameBG[1],EAA_THEME.frameBG[2],EAA_THEME.frameBG[3],
        EAA_THEME.frameBG[4] * alphaScale
    )
    frame:SetBackdropBorderColor(
        EAA_THEME.frameBorder[1],EAA_THEME.frameBorder[2],EAA_THEME.frameBorder[3],
        EAA_THEME.frameBorder[4] * borderScale
    )

    local explicitBorderAlpha = EAA_THEME.frameBorder[4] * (isTransparent and 0.78 or 1)
    local explicitBorderSize = (EAA_THEME_NAME == "Fantasy") and 3 or 2
    frame.eaaBorderTop:SetHeight(explicitBorderSize)
    frame.eaaBorderBottom:SetHeight(explicitBorderSize)
    frame.eaaBorderLeft:SetWidth(explicitBorderSize)
    frame.eaaBorderRight:SetWidth(explicitBorderSize)
    frame.eaaBorderTop:SetVertexColor(EAA_THEME.frameBorder[1],EAA_THEME.frameBorder[2],EAA_THEME.frameBorder[3],explicitBorderAlpha)
    frame.eaaBorderBottom:SetVertexColor(EAA_THEME.frameBorder[1],EAA_THEME.frameBorder[2],EAA_THEME.frameBorder[3],explicitBorderAlpha)
    frame.eaaBorderLeft:SetVertexColor(EAA_THEME.frameBorder[1],EAA_THEME.frameBorder[2],EAA_THEME.frameBorder[3],explicitBorderAlpha)
    frame.eaaBorderRight:SetVertexColor(EAA_THEME.frameBorder[1],EAA_THEME.frameBorder[2],EAA_THEME.frameBorder[3],explicitBorderAlpha)

    frame.eaaHeader:SetHeight((EAA_THEME_NAME == "Fantasy") and 38 or 32)
    frame.eaaHeader:SetVertexColor(
        EAA_THEME.headerBG[1],EAA_THEME.headerBG[2],EAA_THEME.headerBG[3],
        EAA_THEME.headerBG[4] * alphaScale
    )

    -- The explicit outer frame is the only top border; no extra accent strips.
    frame.eaaAccentA:ClearAllPoints()
    frame.eaaAccentB:ClearAllPoints()
    frame.eaaAccentA:Hide()
    frame.eaaAccentB:Hide()
    frame.eaaAccentA:SetWidth(0)
    frame.eaaAccentB:SetWidth(0)
    frame.eaaAccentA:SetVertexColor(0,0,0,0)
    frame.eaaAccentB:SetVertexColor(0,0,0,0)

    if useFantasyOrnaments then
        local ornamentAlpha = (isTransparent and 0.72 or 1)

        frame.eaaTopLeftOrnament:SetTexture(EAA_MEDIA_PATH .. "FantasyCornerTopLeft")
        frame.eaaTopLeftOrnament:ClearAllPoints()
        frame.eaaTopLeftOrnament:SetPoint("TOPLEFT",-22,20)
        frame.eaaTopLeftOrnament:SetWidth(58)
        frame.eaaTopLeftOrnament:SetHeight(58)
        frame.eaaTopLeftOrnament:SetAlpha(ornamentAlpha)
        frame.eaaTopLeftOrnament:Show()

        frame.eaaTopRightOrnament:SetTexture(EAA_MEDIA_PATH .. "FantasyCornerTopRight")
        frame.eaaTopRightOrnament:ClearAllPoints()
        frame.eaaTopRightOrnament:SetPoint("TOPRIGHT",22,20)
        frame.eaaTopRightOrnament:SetWidth(58)
        frame.eaaTopRightOrnament:SetHeight(58)
        frame.eaaTopRightOrnament:SetAlpha(ornamentAlpha)
        frame.eaaTopRightOrnament:Show()

        frame.eaaBottomLeftOrnament:SetTexture(EAA_MEDIA_PATH .. "FantasyCornerBottomLeft")
        frame.eaaBottomLeftOrnament:ClearAllPoints()
        frame.eaaBottomLeftOrnament:SetPoint("BOTTOMLEFT",-22,-20)
        frame.eaaBottomLeftOrnament:SetWidth(54)
        frame.eaaBottomLeftOrnament:SetHeight(54)
        frame.eaaBottomLeftOrnament:SetAlpha(ornamentAlpha * 0.92)
        frame.eaaBottomLeftOrnament:Show()

        frame.eaaBottomRightOrnament:SetTexture(EAA_MEDIA_PATH .. "FantasyCornerBottomRight")
        frame.eaaBottomRightOrnament:ClearAllPoints()
        frame.eaaBottomRightOrnament:SetPoint("BOTTOMRIGHT",22,-20)
        frame.eaaBottomRightOrnament:SetWidth(54)
        frame.eaaBottomRightOrnament:SetHeight(54)
        frame.eaaBottomRightOrnament:SetAlpha(ornamentAlpha * 0.92)
        frame.eaaBottomRightOrnament:Show()
    else
        frame.eaaTopLeftOrnament:Hide()
        frame.eaaTopRightOrnament:Hide()
        frame.eaaBottomLeftOrnament:Hide()
        frame.eaaBottomRightOrnament:Hide()
    end

    if useFantasyPlaque then
        frame.eaaTitlePlaque:SetTexture(EAA_MEDIA_PATH .. "FantasyTitlePlaque")
        frame.eaaTitlePlaque:ClearAllPoints()
        frame.eaaTitlePlaque:SetPoint("TOP",0,-2)
        frame.eaaTitlePlaque:SetWidth(240)
        frame.eaaTitlePlaque:SetHeight(48)
        frame.eaaTitlePlaque:SetAlpha(isTransparent and 0.75 or 1)
        frame.eaaTitlePlaque:Show()
    else
        frame.eaaTitlePlaque:Hide()
    end
end

local function UpdateEAAInset(f)
    local parent = f.eaaParent
    local transparent = parent and parent:GetName() == "EbonAffixAlertLootWindow" and parent.eaaTransparent
    local alphaScale = transparent and 0.18 or 1
    local borderScale = transparent and 0.42 or 1

    f:SetBackdropColor(
        EAA_THEME.innerBG[1],EAA_THEME.innerBG[2],EAA_THEME.innerBG[3],
        EAA_THEME.innerBG[4] * alphaScale
    )
    f:SetBackdropBorderColor(
        EAA_THEME.innerBorder[1],EAA_THEME.innerBorder[2],EAA_THEME.innerBorder[3],
        EAA_THEME.innerBorder[4] * borderScale
    )
end

local function CreateEAAInset(parent)
    local f = CreateFrame("Frame",nil,parent)
    f:SetBackdrop({
        bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Buttons\\WHITE8X8",
        tile=true, tileSize=16, edgeSize=1,
        insets={left=1,right=1,top=1,bottom=1}
    })
    f.eaaParent = parent
    AddUnique(eaaThemedInsets,f)
    UpdateEAAInset(f)
    return f
end

local function UpdateEAAButton(button)
    if not button.eaaFantasyTexture then
        button.eaaFantasyTexture = button:CreateTexture(nil,"BACKGROUND")
        button.eaaFantasyTexture:SetAllPoints(button)
    end

    if EAA_THEME_NAME == "Fantasy" then
        button:SetBackdropColor(0,0,0,0)
        button:SetBackdropBorderColor(0,0,0,0)
        button.eaaFantasyTexture:Show()
        if not button:IsEnabled() then
            button.eaaFantasyTexture:SetTexture(EAA_MEDIA_PATH .. "FantasyButtonNormal")
            button.eaaFantasyTexture:SetVertexColor(0.48,0.48,0.48,0.80)
        elseif button.eaaPushed then
            button.eaaFantasyTexture:SetTexture(EAA_MEDIA_PATH .. "FantasyButtonPressed")
            button.eaaFantasyTexture:SetVertexColor(1,1,1,1)
        elseif button.eaaHovered then
            button.eaaFantasyTexture:SetTexture(EAA_MEDIA_PATH .. "FantasyButtonHover")
            button.eaaFantasyTexture:SetVertexColor(1,1,1,1)
        else
            button.eaaFantasyTexture:SetTexture(EAA_MEDIA_PATH .. "FantasyButtonNormal")
            button.eaaFantasyTexture:SetVertexColor(1,1,1,1)
        end
    else
        button.eaaFantasyTexture:Hide()
        if not button:IsEnabled() then
            button:SetBackdropColor(0.08,0.09,0.12,0.55)
            button:SetBackdropBorderColor(0.30,0.32,0.38,0.50)
        elseif button.eaaPushed then
            local c,b = EAA_THEME.buttonPressedBG,EAA_THEME.buttonPressedBorder
            button:SetBackdropColor(c[1],c[2],c[3],c[4])
            button:SetBackdropBorderColor(b[1],b[2],b[3],b[4])
        elseif button.eaaHovered then
            local c,b = EAA_THEME.buttonHoverBG,EAA_THEME.buttonHoverBorder
            button:SetBackdropColor(c[1],c[2],c[3],c[4])
            button:SetBackdropBorderColor(b[1],b[2],b[3],b[4])
        else
            local c,b = EAA_THEME.buttonBG,EAA_THEME.buttonBorder
            button:SetBackdropColor(c[1],c[2],c[3],c[4])
            button:SetBackdropBorderColor(b[1],b[2],b[3],b[4])
        end
    end

    local fs = button:GetFontString()
    if fs then
        fs:SetTextColor(EAA_THEME.title[1],EAA_THEME.title[2],EAA_THEME.title[3])
    end
end

local function SkinEAAButton(button)
    if button.eaaSkinned then
        UpdateEAAButton(button)
        return
    end

    AddUnique(eaaThemedButtons,button)

    local normal = button.GetNormalTexture and button:GetNormalTexture()
    local pushed = button.GetPushedTexture and button:GetPushedTexture()
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    local disabled = button.GetDisabledTexture and button:GetDisabledTexture()
    if normal then normal:SetAlpha(0) end
    if pushed then pushed:SetAlpha(0) end
    if highlight then highlight:SetAlpha(0) end
    if disabled then disabled:SetAlpha(0) end

    button:SetBackdrop({
        bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Buttons\\WHITE8X8",
        tile=true, tileSize=16, edgeSize=1,
        insets={left=1,right=1,top=1,bottom=1}
    })

    button:HookScript("OnEnter",function(self)
        self.eaaHovered = true
        UpdateEAAButton(self)
    end)
    button:HookScript("OnLeave",function(self)
        self.eaaHovered = nil
        self.eaaPushed = nil
        UpdateEAAButton(self)
    end)
    button:HookScript("OnMouseDown",function(self)
        self.eaaPushed = true
        UpdateEAAButton(self)
    end)
    button:HookScript("OnMouseUp",function(self)
        self.eaaPushed = nil
        UpdateEAAButton(self)
    end)
    button:HookScript("OnShow",UpdateEAAButton)

    local fs = button:GetFontString()
    if fs then fs:SetShadowOffset(1,-1) end

    button.eaaSkinned = true
    UpdateEAAButton(button)
end

local function UpdateEAACheckbox(check)
    if EAA_THEME_NAME == "Fantasy" then
        check:SetNormalTexture(EAA_MEDIA_PATH .. "FantasyRuneSocket")
        check:SetPushedTexture(EAA_MEDIA_PATH .. "FantasyRuneSocket")
        check:SetHighlightTexture(EAA_MEDIA_PATH .. "FantasyRuneChecked")
        local h = check:GetHighlightTexture()
        if h then h:SetAlpha(0.38) end
        check:SetCheckedTexture(EAA_MEDIA_PATH .. "FantasyRuneChecked")
        if check.SetDisabledCheckedTexture then
            check:SetDisabledCheckedTexture(EAA_MEDIA_PATH .. "FantasyRuneChecked")
        end
    else
        check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
        check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        if check.SetDisabledCheckedTexture then
            check:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
        end
    end
end

local function SkinEAACheckbox(check)
    AddUnique(eaaThemedChecks,check)
    UpdateEAACheckbox(check)
end

local function SetEAATextColor(fontString,color)
    if not fontString or not color then return end

    local role
    local key,value
    for key,value in pairs(EAA_THEME) do
        if value == color then
            role = key
            break
        end
    end

    if role then
        local _,entry
        local found = false
        for _,entry in ipairs(eaaThemedText) do
            if entry.object == fontString then
                entry.role = role
                found = true
                break
            end
        end
        if not found then
            table.insert(eaaThemedText,{object=fontString,role=role})
        end
    end

    fontString:SetTextColor(color[1],color[2],color[3])
end

local function CreateEAAAccentLine(parent)
    local line = parent:CreateTexture(nil,"ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetHeight(1)
    line.eaaAccentLine = true
    return line
end

local function ApplyLootHistoryTitleStyle()
    if not lootWindow or not lootWindow.title then return end

    lootWindow.title:SetText("Loot History")
    lootWindow.title:ClearAllPoints()
    lootWindow.title:SetPoint("TOPLEFT",20,-18)

    if EAA_THEME_NAME == "Fantasy" then
        -- Morpheus is a built-in WoW fantasy display font.
        lootWindow.title:SetFont("Fonts\\MORPHEUS.TTF",26,"OUTLINE")
        lootWindow.title:SetShadowOffset(1,-1)
    else
        lootWindow.title:SetFontObject(GameFontNormalLarge)
        lootWindow.title:SetShadowOffset(1,-1)
    end

    lootWindow.title:SetTextColor(EAA_THEME.title[1],EAA_THEME.title[2],EAA_THEME.title[3])
end

local function UpdateEAASearchStyle()
    if not panel or not panel.searchBox or not panel.searchLabel then return end

    local box = panel.searchBox
    local label = panel.searchLabel
    local boxName = box:GetName()
    local left = boxName and _G[boxName .. "Left"]
    local middle = boxName and _G[boxName .. "Middle"]
    local right = boxName and _G[boxName .. "Right"]

    if EAA_THEME_NAME == "Fantasy" then
        -- The stock InputBoxTemplate is too faint against the Fantasy panel,
        -- so replace its visible chrome with a stronger leather-and-bronze field.
        if left then left:Hide() end
        if middle then middle:Hide() end
        if right then right:Hide() end

        box:SetBackdrop({
            bgFile="Interface\\Buttons\\WHITE8X8",
            edgeFile="Interface\\Buttons\\WHITE8X8",
            tile=true, tileSize=16, edgeSize=2,
            insets={left=2,right=2,top=2,bottom=2}
        })
        box:SetBackdropColor(0.075,0.038,0.030,1.00)
        box:SetBackdropBorderColor(0.86,0.62,0.25,1.00)
        box:SetTextColor(1.00,0.94,0.80)
        box:SetHeight(24)
        if box.SetTextInsets then box:SetTextInsets(7,7,0,0) end

        -- High-contrast Fantasy label, drawn above the inset layer.
        label:SetFont("Fonts\\FRIZQT__.TTF",15,"OUTLINE")
        label:SetTextColor(1.00,0.95,0.68)
        label:SetShadowColor(0,0,0,1)
        label:SetShadowOffset(1,-1)
    else
        if left then left:Show() end
        if middle then middle:Show() end
        if right then right:Show() end

        box:SetBackdrop(nil)
        box:SetTextColor(EAA_THEME.text[1],EAA_THEME.text[2],EAA_THEME.text[3])
        box:SetHeight(20)
        if box.SetTextInsets then box:SetTextInsets(0,0,0,0) end

        label:SetFontObject(GameFontNormalSmall)
        label:SetTextColor(EAA_THEME.muted[1],EAA_THEME.muted[2],EAA_THEME.muted[3])
        label:SetShadowOffset(0,0)
    end
end

local function SetEAATheme(styleName)
    if styleName ~= "Modern" and styleName ~= "Fantasy" then styleName = "Modern" end
    EAA_THEME = EAA_THEMES[styleName]
    EAA_THEME_NAME = styleName

    if EbonAffixAlertDB then
        EbonAffixAlertDB.uiStyle = styleName
    end

    local _,frame,inset,button,check,entry
    for _,frame in ipairs(eaaThemedFrames) do ApplyEAAFrameSkin(frame) end
    for _,inset in ipairs(eaaThemedInsets) do UpdateEAAInset(inset) end
    for _,button in ipairs(eaaThemedButtons) do UpdateEAAButton(button) end
    for _,check in ipairs(eaaThemedChecks) do UpdateEAACheckbox(check) end

    for _,entry in ipairs(eaaThemedText) do
        local c = EAA_THEME[entry.role]
        if c then entry.object:SetTextColor(c[1],c[2],c[3]) end
    end

    ApplyLootHistoryTitleStyle()
    UpdateEAASearchStyle()

    if panel then
        if panel.alertsFantasyDivider then
            if styleName == "Fantasy" then panel.alertsFantasyDivider:Show() else panel.alertsFantasyDivider:Hide() end
        end
        if panel.interfaceFantasyDivider then
            if styleName == "Fantasy" then panel.interfaceFantasyDivider:Show() else panel.interfaceFantasyDivider:Hide() end
        end
        if panel.footerLine then
            if styleName == "Fantasy" then panel.footerLine:Hide() else panel.footerLine:Show() end
        end

        local _,rowInfo,wrow
        for _,rowInfo in ipairs(generalRows) do
            if rowInfo.fantasyStrip then
                if styleName == "Fantasy" and rowInfo.label:IsShown() then rowInfo.fantasyStrip:Show() else rowInfo.fantasyStrip:Hide() end
            end
        end
        for _,wrow in ipairs(weaponRows) do
            if wrow.fantasyStrip then
                if styleName == "Fantasy" and wrow.text:IsShown() then wrow.fantasyStrip:Show() else wrow.fantasyStrip:Hide() end
            end
        end
    end

    if panel and panel.styleDrop and panel.styleDrop.SetEAASelected then
        panel.styleDrop:SetEAASelected(styleName)
    end
end

local function PrintEAAVersion()

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ff99[EAA]|r Ebon Affix Alert v|cffffff00" .. GetEAAVersion() .. "|r"
    )
end

local function CountTableEntries(t)
    if type(t) ~= "table" then return 0 end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function CountTrackedSelections()
    if not EbonAffixAlertDB or type(EbonAffixAlertDB.tracked) ~= "table" then return 0 end
    return CountTableEntries(EbonAffixAlertDB.tracked)
end

local function FormatKB(kb)
    kb = tonumber(kb) or 0
    if kb >= 1024 then
        return string.format("%.2f MB", kb / 1024)
    end
    return string.format("%.1f KB", kb)
end

local function GetEAAPerfSnapshot()
    local memoryKB = 0
    local cpuMS = nil
    local addonIndex = nil

    if GetAddOnInfo then
        local i
        for i = 1, GetNumAddOns() do
            local name = GetAddOnInfo(i)
            if name == "EbonAffixAlert" then
                addonIndex = i
                break
            end
        end
    end

    if UpdateAddOnMemoryUsage then
        pcall(UpdateAddOnMemoryUsage)
    end
    if addonIndex and GetAddOnMemoryUsage then
        memoryKB = GetAddOnMemoryUsage(addonIndex) or 0
    end

    local scriptProfile = GetCVar and GetCVar("scriptProfile") or "0"
    if scriptProfile == "1" and UpdateAddOnCPUUsage and GetAddOnCPUUsage and addonIndex then
        pcall(UpdateAddOnCPUUsage)
        cpuMS = GetAddOnCPUUsage(addonIndex)
    end

    local cacheSummary = {
        icons = CountTableEntries(affixIconCache),
        persistedIcons = (EbonAffixAlertDB and EbonAffixAlertDB.affixIcons)
            and CountTableEntries(EbonAffixAlertDB.affixIcons) or 0,
        tracked = CountTrackedSelections(),
        lootHistory = #lootHistory,
        bagSnapshot = CountTableEntries(bagSnapshot),
        recentAlerts = CountTableEntries(recentAlerts),
        activeAlerts = #activeAlerts,
    }

    return memoryKB, cpuMS, scriptProfile, cacheSummary
end

local function PrintPerfSnapshot()
    local memoryKB, cpuMS, scriptProfile, c = GetEAAPerfSnapshot()

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ff99[EAA Perf]|r Memory: |cffffff00" .. FormatKB(memoryKB) .. "|r"
    )

    if cpuMS then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff33ff99[EAA Perf]|r CPU: |cffffff00"
            .. string.format("%.2f ms", cpuMS) .. "|r cumulative"
        )
    else
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff33ff99[EAA Perf]|r CPU: |cff888888Unavailable|r "
            .. "(scriptProfile is off; enable with /console scriptProfile 1 then /reload)"
        )
    end

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ff99[EAA Perf]|r Cache: icons=" .. c.icons
        .. ", persistedIcons=" .. c.persistedIcons
        .. ", tracked=" .. c.tracked
        .. ", lootHistory=" .. c.lootHistory
        .. ", bagSnapshot=" .. c.bagSnapshot
        .. ", recentAlerts=" .. c.recentAlerts
        .. ", activeAlerts=" .. c.activeAlerts
        .. ", serverCatalog=" .. CountTableEntries(serverAffixCatalog)
    )
end

local function SetPerfMonitor(enabled)
    perfMonitorEnabled = enabled and true or false

    if not perfMonitorFrame then
        perfMonitorFrame = CreateFrame("Frame")
    end

    if perfMonitorEnabled then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff33ff99[EAA]|r Performance monitor |cff00ff00ON|r "
            .. "(reports every 5 seconds). Use |cffffff00/eaa perf|r again to stop."
        )

        PrintPerfSnapshot()

        local elapsed = 0
        perfMonitorFrame:SetScript("OnUpdate",function(self,delta)
            elapsed = elapsed + delta
            if elapsed >= 5 then
                elapsed = 0
                PrintPerfSnapshot()
            end
        end)
    else
        perfMonitorFrame:SetScript("OnUpdate",nil)
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff33ff99[EAA]|r Performance monitor |cffff5555OFF|r."
        )
    end
end

local function TogglePerfMonitor()
    SetPerfMonitor(not perfMonitorEnabled)
end

local function ToggleScriptErrors()
    if not GetCVar or not SetCVar then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffff5555[EAA]|r This client does not expose GetCVar/SetCVar."
        )
        return
    end

    local current = GetCVar("scriptErrors")
    local enable = current ~= "1"
    SetCVar("scriptErrors", enable and "1" or "0")

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ff99[EAA]|r scriptErrors "
        .. (enable and "|cff00ff00ON|r." or "|cffff5555OFF|r.")
    )
end

local function PrintEAAStatus()
    local svc = _G.ExtractionService
    local learnedCount = 0

    if svc and type(svc.learnedAffixes) == "table" then
        learnedCount = #svc.learnedAffixes
    end

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ff99[EAA Status]|r Version: |cffffff00" .. GetEAAVersion() .. "|r"
        .. "  Tracking: "
        .. (EbonAffixAlertDB.enabled and "|cff00ff00Enabled|r" or "|cffff5555Disabled|r")
    )

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ff99[EAA Status]|r Tracked selections: " .. CountTrackedSelections()
        .. "  Loot history: " .. #lootHistory
        .. "  Active alerts: " .. #activeAlerts
    )

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ff99[EAA Status]|r ExtractionService: "
        .. (svc and "|cff00ff00available|r" or "|cffff5555unavailable|r")
        .. "  Server affix entries: " .. learnedCount
        .. "  Cached icons: " .. CountTableEntries(affixIconCache)
    )

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ff99[EAA Status]|r scriptErrors="
        .. tostring(GetCVar and GetCVar("scriptErrors") or "?")
        .. "  scriptProfile="
        .. tostring(GetCVar and GetCVar("scriptProfile") or "?")
    )
end

local function RescanEbonholdIcons()
    local before = CountTableEntries(affixIconCache)

    if _G.ExtractionService and ExtractionService.RequestLearnedAffixes then
        pcall(ExtractionService.RequestLearnedAffixes)
    end

    local refreshed = RefreshAffixIconsFromEbonhold()
    RequestEbonholdAffixIcons()

    local after = CountTableEntries(affixIconCache)
    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ff99[EAA]|r Affix icon rescan requested. Cached icons: "
        .. before .. " -> " .. after
        .. (refreshed and " (server data available now)." or " (waiting for server response).")
    )
end

local function ClearEAACache()
    local iconCount = CountTableEntries(affixIconCache)
    local persistedCount = 0
    local recentCount = CountTableEntries(recentAlerts)

    if EbonAffixAlertDB and type(EbonAffixAlertDB.affixIcons) == "table" then
        persistedCount = CountTableEntries(EbonAffixAlertDB.affixIcons)
        EbonAffixAlertDB.affixIcons = {}
    end

    for key in pairs(affixIconCache) do
        affixIconCache[key] = nil
    end

    if type(recentAlerts) == "table" then
        for key in pairs(recentAlerts) do
            recentAlerts[key] = nil
        end
    end

    ApplyAffixIconsToRows()

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ff99[EAA]|r Cache cleared: "
        .. iconCount .. " runtime icons, "
        .. persistedCount .. " persisted icons, "
        .. recentCount .. " recent-alert entries."
    )

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ff99[EAA]|r Bag ownership state and Loot History were preserved."
    )

    -- Re-populate icon data immediately after clearing disposable caches.
    RescanEbonholdIcons()
end

local function ShowCopyTextWindow(titleText, bodyText)
    if not supportCopyWindow then
        local f = CreateFrame("Frame","EbonAffixAlertCopyWindow",UIParent)
        f:SetWidth(620)
        f:SetHeight(440)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        ApplyEAAFrameSkin(f)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart",function(self) self:StartMoving() end)
        f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)

        f.title = f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
        f.title:SetPoint("TOPLEFT",22,-20)
        SetEAATextColor(f.title,EAA_THEME.title)

        local close = CreateFrame("Button",nil,f,"UIPanelCloseButton")
        close:SetPoint("TOPRIGHT",-5,-5)

        local hint = f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT",22,-48)
        hint:SetText("Ctrl+A then Ctrl+C to copy the text below.")
        SetEAATextColor(hint,EAA_THEME.muted)
        local editInset = CreateEAAInset(f)
        editInset:SetPoint("TOPLEFT",18,-70)
        editInset:SetPoint("BOTTOMRIGHT",-22,46)

        local scroll = CreateFrame("ScrollFrame","EbonAffixAlertCopyScroll",f,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",20,-72)
        scroll:SetPoint("BOTTOMRIGHT",-36,48)

        local edit = CreateFrame("EditBox","EbonAffixAlertCopyEditBox",scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetTextColor(EAA_THEME.text[1],EAA_THEME.text[2],EAA_THEME.text[3])
        edit:SetFontObject("ChatFontNormal")
        edit:SetWidth(545)
        edit:SetTextInsets(4,4,4,4)
        edit:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
        edit:SetScript("OnTextChanged",function(self)
            -- WoW 3.3.5 EditBox has no GetStringHeight().
            -- Estimate content height from line count so the ScrollFrame can scroll.
            local text = self:GetText() or ""
            local lines = 1

            for _ in string.gmatch(text,"\n") do
                lines = lines + 1
            end

            self:SetHeight(math.max(320,(lines * 14) + 24))
        end)
        scroll:SetScrollChild(edit)

        local selectAll = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
        selectAll:SetWidth(90)
        selectAll:SetHeight(24)
        selectAll:SetPoint("BOTTOMLEFT",22,16)
        selectAll:SetText("Select All")
        SkinEAAButton(selectAll)
        selectAll:SetScript("OnClick",function()
            edit:SetFocus()
            edit:HighlightText()
        end)

        local done = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
        done:SetWidth(80)
        done:SetHeight(24)
        done:SetPoint("BOTTOMRIGHT",-22,16)
        done:SetText("Close")
        SkinEAAButton(done)
        done:SetScript("OnClick",function() f:Hide() end)

        f.edit = edit
        supportCopyWindow = f
    end

    supportCopyWindow.title:SetText(titleText or "EbonAffixAlert")
    supportCopyWindow.edit:SetText(bodyText or "")
    supportCopyWindow.edit:SetCursorPosition(0)
    supportCopyWindow:Show()
    supportCopyWindow.edit:SetFocus()
    supportCopyWindow.edit:HighlightText()
end

-- ---------------------------------------------------------------------------
-- Realm-wide update tracker (WoW 3.3.5a compatible)
--
-- Stock 3.3.5a has no realm-wide SendAddonMessage channel, so EAA uses a
-- hidden named chat channel. Only tiny version messages are sent. The channel
-- is removed from normal chat frames immediately after joining.
-- ---------------------------------------------------------------------------
local EAA_UPDATE_CHANNEL = "ebonaffixalert"
local EAA_UPDATE_WIRE_PREFIX = "EAAUPD1"
local EAA_RELEASES_URL = "https://github.com/Kebbie/EbonAffixAlert/releases"
local EAA_RELEASE_LINK = "|cff33ff33|Heaaupdate:releases|h[GitHub Releases]|h|r"
local EAA_UPDATE_SEND_DELAY = 0.20
local EAA_UPDATE_MAX_QUEUE = 20

local eaaUpdateChannelIndex = nil
local eaaUpdateJoined = false
local eaaUpdateQueue = {}
local eaaUpdateNextSend = 0
local eaaUpdateNudgeShown = false
local eaaHighestSeenVersion = nil
local eaaHighestSeenVersionInt = 0
local eaaUpdateSelfTestToken = nil
local eaaUpdateSelfTestEchoed = false
local eaaUpdateJoinStartedAt = nil
local eaaUpdateQuerySent = false

local function EAAParseVersion(ver)
    if type(ver) ~= "string" then return nil end
    local major,minor,patch = string.match(ver,"^%s*[vV]?(%d+)%.(%d+)%.(%d+)%s*$")
    major,minor,patch = tonumber(major),tonumber(minor),tonumber(patch)
    if not major or not minor or not patch then return nil end
    if major > 999 or minor > 999 or patch > 999 then return nil end
    return (major * 1000000) + (minor * 1000) + patch, major, minor, patch
end

local function EAAIsUpdateChannelName(name)
    return type(name) == "string"
        and string.find(string.lower(name),EAA_UPDATE_CHANNEL,1,true) ~= nil
end

local function EAAFindUpdateChannel()
    if not GetChannelList then return nil end
    local channels = { GetChannelList() }
    local i
    for i=1,#channels,2 do
        local idx = tonumber(channels[i])
        local name = channels[i+1]
        if idx and idx > 0 and EAAIsUpdateChannelName(name) then
            return idx
        end
    end
    return nil
end

local function EAAHideUpdateChannel()
    if not ChatFrame_RemoveChannel then return end
    local i
    for i=1,(NUM_CHAT_WINDOWS or 10) do
        local chat = _G["ChatFrame" .. i]
        if chat then
            ChatFrame_RemoveChannel(chat,EAA_UPDATE_CHANNEL)
        end
    end
end

local function EAAJoinUpdateChannel()
    if eaaUpdateJoined then return end
    eaaUpdateJoined = true
    eaaUpdateJoinStartedAt = GetTime()
    eaaUpdateChannelIndex = EAAFindUpdateChannel()
    if not eaaUpdateChannelIndex and JoinChannelByName then
        eaaUpdateChannelIndex = JoinChannelByName(EAA_UPDATE_CHANNEL)
    end
    EAAHideUpdateChannel()
end

local function EAAQueueUpdateMessage(msgType,payload)
    if not eaaUpdateJoined then EAAJoinUpdateChannel() end
    local wire = EAA_UPDATE_WIRE_PREFIX .. "|" .. tostring(msgType) .. "|" .. tostring(payload or "")
    if string.len(wire) > 240 then return end
    if #eaaUpdateQueue >= EAA_UPDATE_MAX_QUEUE then
        table.remove(eaaUpdateQueue,1)
    end
    table.insert(eaaUpdateQueue,wire)
end

local function EAAShowReleaseURL()
    ShowCopyTextWindow("EAA - GitHub Releases",EAA_RELEASES_URL)
end

-- 3.3.5's stock SetItemRef attempts to treat unknown custom links as item
-- hyperlinks and can error. Intercept only our eaaupdate link and forward every
-- other link untouched. This also chains safely with addons that wrap SetItemRef.
local eaaOriginalSetItemRef = SetItemRef
function SetItemRef(link,text,button,chatFrame)
    if type(link) == "string" and string.sub(link,1,10) == "eaaupdate:" then
        EAAShowReleaseURL()
        return
    end
    if eaaOriginalSetItemRef then
        return eaaOriginalSetItemRef(link,text,button,chatFrame)
    end
end

local function EAAConsiderPeerVersion(verStr,sender)
    local peerInt,peerMajor = EAAParseVersion(verStr)
    local myInt,myMajor = EAAParseVersion(GetEAAVersion())
    if not peerInt or not myInt then return end

    local me = UnitName and UnitName("player")
    if sender and me and sender == me then return end

    -- Lightweight spoof guard: accept current-major and next-major versions,
    -- but ignore absurd jumps advertised by an arbitrary chat-channel user.
    if peerMajor > (myMajor + 1) then return end

    if peerInt > eaaHighestSeenVersionInt then
        eaaHighestSeenVersionInt = peerInt
        eaaHighestSeenVersion = verStr
    end

    if peerInt > myInt then
        if eaaManualUpdateCheckActive then
            eaaManualUpdateCheckFoundNewer = true
        end

        if not eaaUpdateNudgeShown then
            eaaUpdateNudgeShown = true
            DEFAULT_CHAT_FRAME:AddMessage(
            "|cff33ff99[EAA]|r |cffffff00Update available: v"
            .. string.gsub(tostring(verStr),"^[vV]","")
            .. "|r (you have v" .. tostring(GetEAAVersion()) .. "). "
                .. EAA_RELEASE_LINK
            )
        end
    end
end

local function EAAStripUpdateChannelPrefix(msg)
    local text = tostring(msg or "")
    text = string.gsub(text,"|c%x%x%x%x%x%x%x%x","")
    text = string.gsub(text,"|r","")
    text = string.gsub(text,"^%s*%[[^%]]+%]%s*","")
    return text
end

local EAAProcessManualUpdateResult
local eaaUpdateFrame = CreateFrame("Frame")
eaaUpdateFrame:RegisterEvent("CHAT_MSG_CHANNEL")
eaaUpdateFrame:SetScript("OnEvent",function(self,event,text,sender,_,channelName,_,_,_,channelNumber)
    if event ~= "CHAT_MSG_CHANNEL" then return end
    if not EAAIsUpdateChannelName(channelName) then
        if not eaaUpdateChannelIndex or channelNumber ~= eaaUpdateChannelIndex then
            return
        end
    end

    local decoded = EAAStripUpdateChannelPrefix(text)
    local prefix,msgType,payload = string.match(decoded,"^([^|]+)|([^|]+)|(.*)$")
    if prefix ~= EAA_UPDATE_WIRE_PREFIX then return end

    if type(channelNumber) == "number" and channelNumber > 0 then
        if eaaUpdateChannelIndex ~= channelNumber then
            eaaUpdateChannelIndex = channelNumber
            EAAHideUpdateChannel()
        end
    end

    if msgType == "VERQ" then
        EAAConsiderPeerVersion(payload,sender)
        if sender and sender ~= (UnitName and UnitName("player")) then
            EAAQueueUpdateMessage("VERR",GetEAAVersion())
        end
    elseif msgType == "VERR" then
        EAAConsiderPeerVersion(payload,sender)
    elseif msgType == "RPNG" then
        if eaaUpdateSelfTestToken and payload == eaaUpdateSelfTestToken then
            eaaUpdateSelfTestEchoed = true
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cff33ff99[EAA]|r Realm update channel test: |cff00ff00OK|r (message echoed back)."
            )
        end
    end
end)

eaaUpdateFrame:SetScript("OnUpdate",function(self,delta)
    EAAProcessManualUpdateResult()

    if not eaaUpdateJoined then return end

    -- JoinChannelByName can return before GetChannelList reflects the final slot.
    if (not eaaUpdateChannelIndex or eaaUpdateChannelIndex <= 0)
        and eaaUpdateJoinStartedAt and GetTime() - eaaUpdateJoinStartedAt >= 1 then
        eaaUpdateChannelIndex = EAAFindUpdateChannel()
        EAAHideUpdateChannel()
    end

    -- Send one version query after the channel has had a moment to settle.
    if not eaaUpdateQuerySent and eaaUpdateJoinStartedAt
        and GetTime() - eaaUpdateJoinStartedAt >= 2 then
        eaaUpdateQuerySent = true
        EAAQueueUpdateMessage("VERQ",GetEAAVersion())
    end

    if #eaaUpdateQueue == 0 or GetTime() < eaaUpdateNextSend then return end

    -- Channel numbers renumber when other channels are left. Revalidate before
    -- every send so an old number can never dump protocol text into General.
    if eaaUpdateChannelIndex and eaaUpdateChannelIndex > 0 and GetChannelName then
        local _,liveName = GetChannelName(eaaUpdateChannelIndex)
        if not EAAIsUpdateChannelName(liveName) then
            eaaUpdateChannelIndex = EAAFindUpdateChannel()
            EAAHideUpdateChannel()
        end
    end

    -- Do not dequeue until the named channel has a confirmed live numeric index.
    -- SendChatMessage's CHANNEL target is an index on 3.3.5a; using a stale or
    -- missing index risks either losing the message or posting into another channel.
    if not eaaUpdateChannelIndex or eaaUpdateChannelIndex <= 0 then
        eaaUpdateChannelIndex = EAAFindUpdateChannel()
        if not eaaUpdateChannelIndex then return end
    end

    local wire = eaaUpdateQueue[1]
    local sent = pcall(SendChatMessage,wire,"CHANNEL",nil,eaaUpdateChannelIndex)
    if sent then
        table.remove(eaaUpdateQueue,1)
        eaaUpdateNextSend = GetTime() + EAA_UPDATE_SEND_DELAY
    else
        eaaUpdateChannelIndex = nil
    end
end)

local function EAAStartUpdateTracker()
    EAAJoinUpdateChannel()
end

local EAA_MANUAL_UPDATE_COOLDOWN = 5
local EAA_MANUAL_UPDATE_RESULT_DELAY = 1
local eaaLastManualUpdateCheck = -100
local eaaManualUpdateCheckActive = false
local eaaManualUpdateCheckFoundNewer = false
local eaaManualUpdateCheckEndsAt = 0

EAAProcessManualUpdateResult = function()
    if not eaaManualUpdateCheckActive then return end
    if GetTime() < eaaManualUpdateCheckEndsAt then return end

    eaaManualUpdateCheckActive = false

    -- Visible result resolves after one second. The Update Check button and
    -- slash command keep their independent five-second anti-spam cooldown.
    if not eaaManualUpdateCheckFoundNewer then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff33ff99[EAA]|r |cff00ff00EAA is up to date.|r No newer version was found."
        )
    end
end

local function EAARequestManualUpdateCheck()
    local now = GetTime()
    if now - eaaLastManualUpdateCheck < EAA_MANUAL_UPDATE_COOLDOWN then
        return false
    end

    eaaLastManualUpdateCheck = now
    eaaManualUpdateCheckActive = true
    eaaManualUpdateCheckFoundNewer = false
    eaaManualUpdateCheckEndsAt = now + EAA_MANUAL_UPDATE_RESULT_DELAY

    EAAJoinUpdateChannel()
    EAAQueueUpdateMessage("VERQ",GetEAAVersion())

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ff99[EAA]|r Checking the realm for newer EAA versions..."
    )
    return true
end

local function EAAPrintUpdateStatus()
    local idx = EAAFindUpdateChannel() or eaaUpdateChannelIndex
    local latest = eaaHighestSeenVersion and ("v" .. string.gsub(eaaHighestSeenVersion,"^[vV]","")) or "none seen"
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[EAA Update]|r Installed: |cffffff00v" .. GetEAAVersion() .. "|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[EAA Update]|r Realm channel: "
        .. (idx and ("|cff00ff00joined|r (#" .. tostring(idx) .. ")") or "|cffff5555not joined|r"))
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[EAA Update]|r Newest version seen: |cffffff00" .. latest .. "|r")
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[EAA Update]|r Releases: " .. EAA_RELEASE_LINK)
end

local function EAARunUpdateSelfTest()
    EAAJoinUpdateChannel()
    local idx = EAAFindUpdateChannel() or eaaUpdateChannelIndex
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[EAA]|r Realm update channel self-test. Joined: "
        .. (idx and "|cff00ff00yes|r" or "|cffff5555not yet|r")
        .. ", channel index: " .. tostring(idx or "unknown") .. ".")
    eaaUpdateSelfTestToken = tostring(GetTime())
    eaaUpdateSelfTestEchoed = false
    EAAQueueUpdateMessage("RPNG",eaaUpdateSelfTestToken)

    local wait = CreateFrame("Frame")
    local elapsed = 0
    wait:SetScript("OnUpdate",function(self,dt)
        elapsed = elapsed + dt
        if elapsed >= 3 then
            self:SetScript("OnUpdate",nil)
            if not eaaUpdateSelfTestEchoed then
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cff33ff99[EAA]|r Realm update channel test: no echo received in 3 seconds. "
                    .. "Try /reload or check whether all 10 chat-channel slots are already in use."
                )
            end
        end
    end)
end

local function BuildTrackedConfigExport()
    local lines = {
        "EbonAffixAlert Tracked Configuration",
        "EAA Version: " .. GetEAAVersion(),
        "",
        "[General]"
    }

    local _, entry, rank
    local generalCount = 0
    for _,entry in ipairs(generalAffixes) do
        local name = entry[1]
        local maxRank = GetMaxRankForAffix(name)
        local ranks = {}

        for rank=1,math.min(maxRank,10) do
            if EbonAffixAlertDB.tracked[GKey(name,rank)] then
                table.insert(ranks,roman[rank] or tostring(rank))
            end
        end

        if #ranks > 0 then
            table.insert(lines,name .. ": " .. table.concat(ranks,", "))
            generalCount = generalCount + 1
        end
    end

    if generalCount == 0 then
        table.insert(lines,"(none)")
    end

    table.insert(lines,"")
    table.insert(lines,"[Weapon]")

    local weaponCount = 0
    local _, name
    for _,name in ipairs(weaponAffixes) do
        if EbonAffixAlertDB.tracked[WKey(name)] then
            table.insert(lines,name)
            weaponCount = weaponCount + 1
        end
    end

    if weaponCount == 0 then
        table.insert(lines,"(none)")
    end

    return table.concat(lines,"\n")
end

local function BuildLoadedAddonList()
    if not GetNumAddOns or not GetAddOnInfo then
        return "(API unavailable)"
    end

    local items = {}
    local i
    for i=1,GetNumAddOns() do
        local name, title, notes, enabled, loadable, reason, security = GetAddOnInfo(i)
        local loaded = IsAddOnLoaded and IsAddOnLoaded(i)
        if loaded then
            local version = GetAddOnMetadata and GetAddOnMetadata(i,"Version")
            table.insert(items,name .. (version and ("@" .. version) or ""))
        end
    end

    table.sort(items)
    return #items > 0 and table.concat(items,", ") or "(none)"
end

local function BuildBugReport()
    local wowVersion, wowBuild, wowDate, tocVersion
    if GetBuildInfo then
        wowVersion, wowBuild, wowDate, tocVersion = GetBuildInfo()
    end

    local svc = _G.ExtractionService
    local learnedCount = (svc and type(svc.learnedAffixes) == "table") and #svc.learnedAffixes or 0
    local ebonVersion = GetAddOnMetadata and GetAddOnMetadata("ProjectEbonhold","Version") or "unknown"
    local player = UnitName and UnitName("player") or "unknown"
    local realm = GetRealmName and GetRealmName() or "unknown"
    local locale = GetLocale and GetLocale() or "unknown"

    local memoryKB, cpuMS, scriptProfile, cache = GetEAAPerfSnapshot()

    local lines = {
        "=== EbonAffixAlert Bug Report ===",
        "EAA Version: " .. GetEAAVersion(),
        "EAA Enabled: " .. tostring(EbonAffixAlertDB.enabled),
        "Player: " .. tostring(player),
        "Realm: " .. tostring(realm),
        "Locale: " .. tostring(locale),
        "",
        "[Client]",
        "WoW Version: " .. tostring(wowVersion),
        "Build: " .. tostring(wowBuild),
        "Build Date: " .. tostring(wowDate),
        "TOC: " .. tostring(tocVersion),
        "scriptErrors: " .. tostring(GetCVar and GetCVar("scriptErrors") or "?"),
        "scriptProfile: " .. tostring(GetCVar and GetCVar("scriptProfile") or "?"),
        "UI Scale: " .. tostring(GetCVar and GetCVar("uiScale") or "?"),
        "",
        "[Project Ebonhold]",
        "ProjectEbonhold Version: " .. tostring(ebonVersion),
        "ExtractionService Available: " .. tostring(svc ~= nil),
        "learnedAffixes Entries: " .. tostring(learnedCount),
        "EAA Server Catalog Entries: " .. tostring(CountTableEntries(serverAffixCatalog)),
        "",
        "[EAA Runtime]",
        "Memory: " .. FormatKB(memoryKB),
        "CPU cumulative: " .. (cpuMS and string.format("%.2f ms",cpuMS) or "unavailable"),
        "Tracked selections: " .. tostring(CountTrackedSelections()),
        "Loot History entries: " .. tostring(#lootHistory),
        "Runtime icon cache: " .. tostring(cache.icons),
        "Persisted icon cache: " .. tostring(cache.persistedIcons),
        "Bag snapshot entries: " .. tostring(cache.bagSnapshot),
        "Recent-alert cache: " .. tostring(cache.recentAlerts),
        "Active alerts: " .. tostring(cache.activeAlerts),
        "Debug enabled: " .. tostring(EbonAffixAlertDB.debug),
        "Large alert enabled: " .. tostring(EbonAffixAlertDB.announceToRaidWarning),
        "Alert sound enabled: " .. tostring(EbonAffixAlertDB.alertSound),
        "Minimap shown: " .. tostring(EbonAffixAlertDB.minimap and EbonAffixAlertDB.minimap.show),
        "Loot History shown: " .. tostring(EbonAffixAlertDB.lootWindow and EbonAffixAlertDB.lootWindow.show),
        "",
        "[Loaded AddOns]",
        BuildLoadedAddonList(),
        "",
        BuildTrackedConfigExport()
    }

    return table.concat(lines,"\n")
end

local function ShowTrackedConfigExport()
    ShowCopyTextWindow("EAA - Export Tracked Configuration",BuildTrackedConfigExport())
end

local function ShowBugReport()
    ShowCopyTextWindow("EAA - Bug Report",BuildBugReport())
end

local PLACEHOLDER_AFFIX_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local function SetAffixIcon(affixName, texture)
    if not affixName or affixName == "" or not texture or texture == "" then return end
    affixIconCache[affixName] = texture
    if EbonAffixAlertDB and EbonAffixAlertDB.affixIcons then
        EbonAffixAlertDB.affixIcons[affixName] = texture
    end
end

local function GetAffixIcon(affixName)
    if affixIconCache[affixName] then
        return affixIconCache[affixName]
    end

    if EbonAffixAlertDB and EbonAffixAlertDB.affixIcons
        and EbonAffixAlertDB.affixIcons[affixName] then
        affixIconCache[affixName] = EbonAffixAlertDB.affixIcons[affixName]
        return affixIconCache[affixName]
    end

    return PLACEHOLDER_AFFIX_ICON
end

ApplyAffixIconsToRows = function()
    local _, rowInfo

    for _,rowInfo in ipairs(generalRows) do
        if rowInfo.icon then
            rowInfo.icon:SetTexture(GetAffixIcon(rowInfo.name))
        end
    end

    for _,rowInfo in ipairs(weaponRows) do
        if rowInfo.icon then
            rowInfo.icon:SetTexture(GetAffixIcon(rowInfo.name))
        end
    end
end

RefreshAffixIconsFromEbonhold = function()
    local svc = _G.ExtractionService
    if not svc or type(svc.learnedAffixes) ~= "table" or #svc.learnedAffixes == 0 then
        return false
    end

    local found = false
    local _, affix

    -- ExtractionService is authoritative for canonical names, icons and weaponOnly.
    for _,affix in ipairs(svc.learnedAffixes) do
        if type(affix.name) == "string" and affix.name ~= "" then
            local base, romanRank = string.match(affix.name,"^(.-)%s+([IVXLCivxlc]+)$")
            base = base or affix.name

            local entry = serverAffixCatalog[base] or {
                name = base,
                weaponOnly = affix.weaponOnly and true or false,
                maxRank = 0,
                ranks = {}
            }

            entry.ranks = entry.ranks or {}
            entry.weaponOnly = affix.weaponOnly and true or entry.weaponOnly

            if romanRank then
                local rank = romanToNumber[string.upper(romanRank)]
                if rank then
                    if rank > entry.maxRank then entry.maxRank = rank end
                    if affix.id then entry.ranks[rank] = affix.id end
                end
            elseif affix.id then
                entry.spellId = affix.id
            end

            if affix.id then
                entry.representativeSpellId = affix.id
            end

            serverAffixCatalog[base] = entry

            if affix.icon and affix.icon ~= "" then
                SetAffixIcon(base,affix.icon)
                found = true
            end
        end
    end

    -- Weapon spell IDs/descriptions may have changed with the server catalogue.
    weaponProcDescriptionsStale = true

    if found then
        ApplyAffixIconsToRows()
    end

    if panel and panel:IsShown() then
        -- Re-open/refresh settings to pick up newly published ranks.
        panel:Hide()
        panel:Show()
    end

    return true
end

local function GetAffixSpellId(affixName,rank)
    local entry = serverAffixCatalog[affixName]
    if not entry then return nil end

    if rank and entry.ranks and entry.ranks[rank] then
        return entry.ranks[rank]
    end

    if entry.weaponOnly and entry.spellId then
        return entry.spellId
    end

    if entry.ranks then
        for n=10,1,-1 do
            if entry.ranks[n] then return entry.ranks[n] end
        end
    end

    return entry.representativeSpellId
end

ShowAffixTooltip = function(anchor,affixName,rank)
    if not anchor or not affixName then return end

    local spellId = GetAffixSpellId(affixName,rank)
    GameTooltip:SetOwner(anchor,"ANCHOR_RIGHT")

    if spellId then
        local ok = pcall(function()
            GameTooltip:SetHyperlink("spell:" .. tostring(spellId))
        end)

        if ok then
            GameTooltip:Show()
            return
        end
    end

    GameTooltip:ClearLines()
    GameTooltip:AddLine(affixName,1,0.82,0)
    if not serverAffixCatalog[affixName] then
        GameTooltip:AddLine("Waiting for Project Ebonhold affix data.",0.75,0.75,0.75,true)
    else
        GameTooltip:AddLine("Spell tooltip unavailable for this affix.",0.75,0.75,0.75,true)
    end
    GameTooltip:Show()
end

RequestEbonholdAffixIcons = function()
    -- Project Ebonhold exposes the same request used by its own UI/addons.
    if _G.ExtractionService and ExtractionService.RequestLearnedAffixes then
        pcall(ExtractionService.RequestLearnedAffixes)
    end

    -- The response is asynchronous. Poll briefly after login so EAA updates
    -- as soon as learnedAffixes becomes available, then stop.
    if not iconRefreshFrame then
        iconRefreshFrame = CreateFrame("Frame")
    end

    local elapsed = 0
    local attempts = 0
    iconRefreshFrame:SetScript("OnUpdate",function(self,delta)
        elapsed = elapsed + delta
        if elapsed < 1 then return end
        elapsed = 0
        attempts = attempts + 1

        if RefreshAffixIconsFromEbonhold() or attempts >= 10 then
            self:SetScript("OnUpdate",nil)
        end
    end)
end

local function UpdateStatusText()
    if panel and panel.statusText then
        if EbonAffixAlertDB.enabled then
            panel.statusText:SetText("|cff00ff00Tracking Enabled|r")
            if panel.statusDot then
                panel.statusDot:SetVertexColor(0,1,0)
            end
        else
            panel.statusText:SetText("|cff888888Tracking Disabled|r")
            if panel.statusDot then
                panel.statusDot:SetVertexColor(0.45,0.45,0.45)
            end
        end
    end

    if UpdateMinimapEnabledVisual then
        UpdateMinimapEnabledVisual()
    end
end

local function RefreshChecks()
    local _, cb
    for _, cb in ipairs(generalChecks) do
        cb:SetChecked(EbonAffixAlertDB.tracked[cb.key] and 1 or nil)
    end
    for _, cb in ipairs(weaponChecks) do
        cb:SetChecked(EbonAffixAlertDB.tracked[cb.key] and 1 or nil)
    end
    if panel then
        panel.enableCheck:SetChecked(EbonAffixAlertDB.enabled and 1 or nil)
        panel.raidCheck:SetChecked(EbonAffixAlertDB.announceToRaidWarning and 1 or nil)
        panel.soundCheck:SetChecked(EbonAffixAlertDB.alertSound and 1 or nil)
        panel.minimapCheck:SetChecked(EbonAffixAlertDB.minimap.show and 1 or nil)
        panel.lootWindowCheck:SetChecked(EbonAffixAlertDB.lootWindow.show and 1 or nil)
    end
    UpdateStatusText()
    if ApplyAffixFilters then ApplyAffixFilters() end
end

local function CreatePanel()
    panel = CreateFrame("Frame", "EbonAffixAlertOptionsFrame", UIParent)
    panel:SetWidth(620)
    panel:SetHeight(550)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    ApplyEAAFrameSkin(panel)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local title = panel:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    title:SetPoint("TOP",0,-18)
    title:SetText("Ebon Affix Alert")
    SetEAATextColor(title,EAA_THEME.title)

    local contentInset = CreateEAAInset(panel)
    contentInset:SetPoint("TOPLEFT",20,-78)
    contentInset:SetPoint("BOTTOMRIGHT",-20,103)

    local footerInset = CreateEAAInset(panel)
    footerInset:SetPoint("BOTTOMLEFT",20,10)
    footerInset:SetPoint("BOTTOMRIGHT",-20,90)

    local close = CreateFrame("Button",nil,panel,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-5,-5)

    local styleLabel = panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    styleLabel:SetPoint("TOPLEFT",14,-18)
    styleLabel:SetText("Style:")
    SetEAATextColor(styleLabel,EAA_THEME.muted)

    -- Custom EAA style selector: avoids Blizzard UIDropDownMenu taint on 3.3.5a.
    local styleDrop = CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    styleDrop:SetWidth(112)
    styleDrop:SetHeight(25)
    styleDrop:SetPoint("TOPLEFT",65,-12)
    SkinEAAButton(styleDrop)

    local styleValue = styleDrop:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    styleValue:SetPoint("LEFT",12,0)
    styleValue:SetJustifyH("LEFT")
    styleValue:SetWidth(72)
    SetEAATextColor(styleValue,EAA_THEME.text)

    local styleArrow = styleDrop:CreateFontString(nil,"OVERLAY","GameFontNormal")
    styleArrow:SetPoint("RIGHT",-10,0)
    styleArrow:SetText("v")
    SetEAATextColor(styleArrow,EAA_THEME.cyan)

    local styleMenu = CreateFrame("Frame",nil,panel)
    styleMenu:SetWidth(112)
    styleMenu:SetHeight(54)
    styleMenu:SetPoint("TOPLEFT",styleDrop,"BOTTOMLEFT",0,-2)
    styleMenu:SetFrameStrata("DIALOG")
    styleMenu:SetFrameLevel(panel:GetFrameLevel() + 20)
    ApplyEAAFrameSkin(styleMenu)
    styleMenu:Hide()

    local modernChoice = CreateFrame("Button",nil,styleMenu,"UIPanelButtonTemplate")
    modernChoice:SetWidth(104)
    modernChoice:SetHeight(22)
    modernChoice:SetPoint("TOP",0,-4)
    modernChoice:SetText("Modern")
    SkinEAAButton(modernChoice)

    local fantasyChoice = CreateFrame("Button",nil,styleMenu,"UIPanelButtonTemplate")
    fantasyChoice:SetWidth(104)
    fantasyChoice:SetHeight(22)
    fantasyChoice:SetPoint("TOP",modernChoice,"BOTTOM",0,-2)
    fantasyChoice:SetText("Fantasy")
    SkinEAAButton(fantasyChoice)

    function styleDrop:SetEAASelected(styleName)
        if styleName ~= "Fantasy" then styleName = "Modern" end
        styleValue:SetText(styleName)
        styleMenu:Hide()
    end

    styleDrop:SetScript("OnClick",function()
        if styleMenu:IsShown() then styleMenu:Hide() else styleMenu:Show() end
    end)

    modernChoice:SetScript("OnClick",function()
        SetEAATheme("Modern")
        styleMenu:Hide()
    end)

    fantasyChoice:SetScript("OnClick",function()
        SetEAATheme("Fantasy")
        styleMenu:Hide()
    end)

    styleDrop:SetEAASelected(EbonAffixAlertDB.uiStyle or "Modern")
    panel.styleDrop = styleDrop

    local generalButton = CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    generalButton:SetWidth(100); generalButton:SetHeight(24)
    generalButton:SetPoint("TOPLEFT",25,-55)
    generalButton:SetText("General")
    SkinEAAButton(generalButton)

    local weaponButton = CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    weaponButton:SetWidth(100); weaponButton:SetHeight(24)
    weaponButton:SetPoint("LEFT",generalButton,"RIGHT",8,0)
    weaponButton:SetText("Weapon")
    SkinEAAButton(weaponButton)

    panel.statusText = panel:CreateFontString(nil,"OVERLAY","GameFontNormal")
    panel.statusText:SetPoint("TOP",8,-61)
    SetEAATextColor(panel.statusText,EAA_THEME.cyan)

    local statusDot = panel:CreateTexture(nil,"OVERLAY")
    statusDot:SetTexture("Interface\\Buttons\\WHITE8X8")
    statusDot:SetWidth(8)
    statusDot:SetHeight(8)
    statusDot:SetPoint("RIGHT",panel.statusText,"LEFT",-6,0)
    panel.statusDot = statusDot


    -- Keep the Filter label above themed inset/background frames so it cannot
    -- be visually dimmed by the Fantasy panel treatment.
    local searchLabelLayer = CreateFrame("Frame",nil,panel)
    searchLabelLayer:SetAllPoints(panel)
    searchLabelLayer:SetFrameLevel(panel:GetFrameLevel() + 20)
    searchLabelLayer:EnableMouse(false)

    local searchLabel = searchLabelLayer:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    searchLabel:SetPoint("TOPLEFT",28,-91)
    searchLabel:SetText("Filter:")
    SetEAATextColor(searchLabel,EAA_THEME.muted)
    panel.searchLabelLayer = searchLabelLayer

    local searchBox = CreateFrame("EditBox","EbonAffixAlertSearchBox",panel,"InputBoxTemplate")
    searchBox:SetWidth(210)
    searchBox:SetTextColor(EAA_THEME.text[1],EAA_THEME.text[2],EAA_THEME.text[3])
    searchBox:SetHeight(20)
    searchBox:SetPoint("LEFT",searchLabel,"RIGHT",10,0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(40)
    searchBox:SetScript("OnTextChanged",function(self)
        filterText = string.lower(self:GetText() or "")
        if ApplyAffixFilters then ApplyAffixFilters() end
    end)
    searchBox:SetScript("OnEscapePressed",function(self)
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEnterPressed",function(self)
        self:ClearFocus()
    end)
    panel.searchBox = searchBox
    panel.searchLabel = searchLabel
    UpdateEAASearchStyle()

    local trackedOnlyCheck = CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
    SkinEAACheckbox(trackedOnlyCheck)
    trackedOnlyCheck:SetWidth(24); trackedOnlyCheck:SetHeight(24)
    trackedOnlyCheck:SetPoint("LEFT",searchBox,"RIGHT",10,0)
    local trackedText = trackedOnlyCheck:CreateFontString(nil,"OVERLAY","GameFontNormal")
    trackedText:SetPoint("LEFT",trackedOnlyCheck,"RIGHT",2,0)
    trackedText:SetText("Tracked only")
    SetEAATextColor(trackedText,EAA_THEME.text)
    trackedOnlyCheck:SetScript("OnClick",function(self)
        trackedOnly = self:GetChecked() and true or false
        if ApplyAffixFilters then ApplyAffixFilters() end
    end)
    panel.trackedOnlyCheck = trackedOnlyCheck

    local generalPage = CreateFrame("Frame",nil,panel)
    generalPage:SetPoint("TOPLEFT",20,-146)
    generalPage:SetPoint("BOTTOMRIGHT",-20,105)

    local weaponPage = CreateFrame("Frame",nil,panel)
    weaponPage:SetPoint("TOPLEFT",20,-146)
    weaponPage:SetPoint("BOTTOMRIGHT",-20,105)

    local gs = CreateFrame("ScrollFrame","EAA_GeneralScroll",generalPage,"UIPanelScrollFrameTemplate")
    gs:SetPoint("TOPLEFT",0,0); gs:SetPoint("BOTTOMRIGHT",-28,0)
    local gc = CreateFrame("Frame","EAA_GeneralContent",gs)
    gc:SetWidth(550); gc:SetHeight(760)
    gs:SetScrollChild(gc)

    local ws = CreateFrame("ScrollFrame","EAA_WeaponScroll",weaponPage,"UIPanelScrollFrameTemplate")
    ws:SetPoint("TOPLEFT",0,0); ws:SetPoint("BOTTOMRIGHT",-28,0)
    local wc = CreateFrame("Frame","EAA_WeaponContent",ws)
    wc:SetWidth(550); wc:SetHeight(620)
    ws:SetScrollChild(wc)

    local colX = {155,195,235,275,315,355,395,435,475,515}
    local allX = 555
    local head = gc:CreateFontString(nil,"OVERLAY","GameFontNormal")
    head:SetPoint("TOPLEFT",4,-3)
    head:SetText("Affix")
    SetEAATextColor(head,EAA_THEME.cyan)

    local rank
    local rankHeaders = {}
    for rank=1,10 do
        local h = CreateFrame("Button",nil,gc)
        h:SetWidth(22)
        h:SetHeight(20)
        h:SetPoint("TOPLEFT",colX[rank],1)
        h.rank = rank

        local hText = h:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        hText:SetAllPoints(h)
        hText:SetJustifyH("CENTER")
        hText:SetText(roman[rank])
        SetEAATextColor(hText,EAA_THEME.purple)
        h.text = hText

        h:EnableMouse(true)
        h:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_TOP")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Rank " .. (roman[self.rank] or tostring(self.rank)),1,0.82,0)
            GameTooltip:AddLine("Click to track all General affixes available at this rank.",1,1,1,true)
            GameTooltip:AddLine("If every available affix at this rank is already tracked, clicking clears them all.",0.75,0.75,0.75,true)
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave",function() GameTooltip:Hide() end)
        h:SetScript("OnClick",function(self)
            local _, cb
            local availableCount = 0
            local trackedCount = 0

            for _,cb in ipairs(generalChecks) do
                if cb.affixRank == self.rank then
                    availableCount = availableCount + 1
                    if EbonAffixAlertDB.tracked[cb.key] then
                        trackedCount = trackedCount + 1
                    end
                end
            end

            local clearRank = availableCount > 0 and trackedCount == availableCount

            for _,cb in ipairs(generalChecks) do
                if cb.affixRank == self.rank then
                    if clearRank then
                        EbonAffixAlertDB.tracked[cb.key] = nil
                        cb:SetChecked(nil)
                    else
                        EbonAffixAlertDB.tracked[cb.key] = true
                        cb:SetChecked(1)
                    end
                end
            end

            if trackedOnly and ApplyAffixFilters then
                ApplyAffixFilters()
            end
        end)

        rankHeaders[rank] = h
        if rank > 6 then h:Hide() end
    end

    local allHead = gc:CreateFontString(nil,"OVERLAY","GameFontNormal")
    allHead:SetWidth(46)
    allHead:SetJustifyH("CENTER")
    allHead:SetPoint("TOPLEFT",allX,-3)
    allHead:SetText("All")
    SetEAATextColor(allHead,EAA_THEME.cyan)

    local rowY = -28
    local _, entry
    for _, entry in ipairs(generalAffixes) do
        local affixName = entry[1]
        local maxRank = GetMaxRankForAffix(affixName)

        local label = gc:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        label:SetWidth(132)
        label:SetJustifyH("LEFT")
        label:SetPoint("TOPLEFT",28,rowY)
        label:SetText(affixName)
        SetEAATextColor(label,EAA_THEME.text)

        local affixIcon = gc:CreateTexture(nil,"ARTWORK")
        affixIcon:SetWidth(18)
        affixIcon:SetHeight(18)
        affixIcon:SetPoint("TOPLEFT",4,rowY+3)
        affixIcon:SetTexture(GetAffixIcon(affixName))

        local fantasyStrip = gc:CreateTexture(nil,"BACKGROUND")
        fantasyStrip:SetTexture(EAA_MEDIA_PATH .. "FantasyLedgerStrip")
        fantasyStrip:SetPoint("TOPLEFT",0,rowY+3)
        fantasyStrip:SetWidth(548)
        fantasyStrip:SetHeight(25)
        fantasyStrip:SetAlpha(0.82)
        if EAA_THEME_NAME ~= "Fantasy" then fantasyStrip:Hide() end

        local rowChecks = {}
        local rowInfo = {
            name = affixName,
            label = label,
            icon = affixIcon,
            fantasyStrip = fantasyStrip,
            checks = rowChecks,
            buttons = {},
            y = rowY
        }
        local hover = CreateFrame("Frame",nil,gc)
        hover:SetWidth(148)
        hover:SetHeight(23)
        hover:SetPoint("TOPLEFT",0,rowY+4)
        hover:EnableMouse(true)
        hover.affixName = affixName
        hover:SetScript("OnEnter",function(self)
            ShowAffixTooltip(self,self.affixName,nil)
        end)
        hover:SetScript("OnLeave",function() GameTooltip:Hide() end)
        rowInfo.hoverFrame = hover

        table.insert(generalRows,rowInfo)

        for rank=1,10 do
            if rank <= maxRank then
                local cb = CreateFrame("CheckButton",nil,gc,"UICheckButtonTemplate")
                SkinEAACheckbox(cb)
                cb:SetWidth(22); cb:SetHeight(22)
                cb:SetPoint("TOPLEFT",colX[rank],rowY+5)
                cb.key = GKey(affixName,rank)
                cb.affixName = affixName
                cb.affixRank = rank
                cb:SetScript("OnEnter",function(self)
                    ShowAffixTooltip(self,self.affixName,self.affixRank)
                end)
                cb:SetScript("OnLeave",function() GameTooltip:Hide() end)
                cb:SetScript("OnClick",function(self)
                    if self:GetChecked() then
                        EbonAffixAlertDB.tracked[self.key] = true
                    else
                        EbonAffixAlertDB.tracked[self.key] = nil
                    end
                    if trackedOnly and ApplyAffixFilters then
                        ApplyAffixFilters()
                    end
                end)
                table.insert(generalChecks,cb)
                table.insert(rowChecks,cb)
            end
        end

        local allButton = CreateFrame("Button",nil,gc,"UIPanelButtonTemplate")
        allButton:SetWidth(46); allButton:SetHeight(20)
        allButton:SetPoint("TOPLEFT",allX,rowY+2)
        allButton.allDynamicX = allX
        allButton:SetText("All")
        SkinEAAButton(allButton)
        allButton.rowChecks = rowChecks
        allButton.affixName = affixName
        table.insert(rowInfo.buttons,allButton)
        allButton:SetScript("OnEnter",function(self)
            GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(self.affixName .. " - All Ranks",1,0.82,0)
            GameTooltip:AddLine("Click to track every available rank for this affix.",1,1,1,true)
            GameTooltip:AddLine("If every rank is already tracked, clicking clears them all.",0.75,0.75,0.75,true)
            GameTooltip:Show()
        end)
        allButton:SetScript("OnLeave",function() GameTooltip:Hide() end)
        allButton:SetScript("OnClick",function(self)
            local _, rowCB
            local allSelected = true

            for _,rowCB in ipairs(self.rowChecks) do
                if not EbonAffixAlertDB.tracked[rowCB.key] then
                    allSelected = false
                    break
                end
            end

            for _,rowCB in ipairs(self.rowChecks) do
                if allSelected then
                    EbonAffixAlertDB.tracked[rowCB.key] = nil
                    rowCB:SetChecked(nil)
                else
                    EbonAffixAlertDB.tracked[rowCB.key] = true
                    rowCB:SetChecked(1)
                end
            end

            if trackedOnly and ApplyAffixFilters then
                ApplyAffixFilters()
            end
        end)

        rowY = rowY - 27
    end

    local i, name
    for i,name in ipairs(weaponAffixes) do
        -- Use the % operator rather than math.mod; math.mod is nil in this client.
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)

        local cb = CreateFrame("CheckButton",nil,wc,"UICheckButtonTemplate")
        SkinEAACheckbox(cb)
        cb:SetWidth(22); cb:SetHeight(22)
        cb:SetPoint("TOPLEFT",3 + col*270,-5 - row*27)
        cb.key = WKey(name)

        local affixIcon = wc:CreateTexture(nil,"ARTWORK")
        affixIcon:SetWidth(18)
        affixIcon:SetHeight(18)
        affixIcon:SetPoint("LEFT",cb,"RIGHT",2,0)
        affixIcon:SetTexture(GetAffixIcon(name))

        local txt = cb:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        txt:SetPoint("LEFT",affixIcon,"RIGHT",4,0)
        txt:SetText(name)
        SetEAATextColor(txt,EAA_THEME.text)

        cb:SetScript("OnClick",function(self)
            if self:GetChecked() then
                EbonAffixAlertDB.tracked[self.key] = true
            else
                EbonAffixAlertDB.tracked[self.key] = nil
            end
            if trackedOnly and ApplyAffixFilters then
                ApplyAffixFilters()
            end
        end)
        local hover = CreateFrame("Frame",nil,wc)
        hover:SetWidth(215)
        hover:SetHeight(23)
        hover:SetPoint("LEFT",affixIcon,"LEFT",0,0)
        hover:EnableMouse(true)
        hover.affixName = name
        hover:SetScript("OnEnter",function(self)
            ShowAffixTooltip(self,self.affixName,nil)
        end)
        hover:SetScript("OnLeave",function() GameTooltip:Hide() end)

        local fantasyStrip = wc:CreateTexture(nil,"BACKGROUND")
        fantasyStrip:SetTexture(EAA_MEDIA_PATH .. "FantasyLedgerStrip")
        fantasyStrip:SetPoint("TOPLEFT",col*270,-3-row*27)
        fantasyStrip:SetWidth(258)
        fantasyStrip:SetHeight(25)
        fantasyStrip:SetAlpha(0.82)
        if EAA_THEME_NAME ~= "Fantasy" then fantasyStrip:Hide() end

        table.insert(weaponChecks,cb)
        table.insert(weaponRows,{
            name = name,
            fantasyStrip = fantasyStrip,
            check = cb,
            text = txt,
            icon = affixIcon,
            hoverFrame = hover,
            col = col,
            row = row
        })
    end



    local function RefreshGeneralRankControls()
        local highestRank = 1
        local _, rowInfo, rank

        for _,rowInfo in ipairs(generalRows) do
            local desiredMax = GetMaxRankForAffix(rowInfo.name)
            if desiredMax > 10 then desiredMax = 10 end
            if desiredMax > highestRank then highestRank = desiredMax end

            local existing = {}
            local _, cb
            for _,cb in ipairs(rowInfo.checks) do
                local n = tonumber(string.match(cb.key,":(%d+)$"))
                if n then existing[n] = cb end
            end

            for rank=1,desiredMax do
                if not existing[rank] then
                    local cb = CreateFrame("CheckButton",nil,gc,"UICheckButtonTemplate")
                    SkinEAACheckbox(cb)
                    cb:SetWidth(22); cb:SetHeight(22)
                    cb.key = GKey(rowInfo.name,rank)
                    cb.affixName = rowInfo.name
                    cb.affixRank = rank
                    cb:SetScript("OnEnter",function(self)
                        ShowAffixTooltip(self,self.affixName,self.affixRank)
                    end)
                    cb:SetScript("OnLeave",function() GameTooltip:Hide() end)
                    cb:SetScript("OnClick",function(self)
                        if self:GetChecked() then
                            EbonAffixAlertDB.tracked[self.key] = true
                        else
                            EbonAffixAlertDB.tracked[self.key] = nil
                        end
                        if trackedOnly and ApplyAffixFilters then ApplyAffixFilters() end
                    end)
                    table.insert(generalChecks,cb)
                    table.insert(rowInfo.checks,cb)
                end
            end
        end

        for rank=1,10 do
            if rankHeaders[rank] then
                if rank <= highestRank then rankHeaders[rank]:Show()
                else rankHeaders[rank]:Hide() end
            end
        end

        allHead:ClearAllPoints()
        allHead:SetPoint("TOPLEFT",colX[math.min(highestRank,10)] + 40,-3)

        for _,rowInfo in ipairs(generalRows) do
            for _,btn in ipairs(rowInfo.buttons) do
                btn.allDynamicX = colX[math.min(highestRank,10)] + 40
            end
        end
    end

    ApplyAffixFilters = function()
        local query = filterText or ""

        -- General list reflow.
        local visibleIndex = 0
        local _, rowInfo, cb, btn
        for _,rowInfo in ipairs(generalRows) do
            local matchesText = (query == "") or string.find(string.lower(rowInfo.name),query,1,true)
            local hasTracked = false
            for _,cb in ipairs(rowInfo.checks) do
                if EbonAffixAlertDB.tracked[cb.key] then
                    hasTracked = true
                    break
                end
            end
            local visible = matchesText and ((not trackedOnly) or hasTracked)

            if visible then
                visibleIndex = visibleIndex + 1
                local y = -28 - ((visibleIndex - 1) * 27)

                if rowInfo.fantasyStrip then
                    rowInfo.fantasyStrip:ClearAllPoints()
                    rowInfo.fantasyStrip:SetPoint("TOPLEFT",0,y+3)
                    if EAA_THEME_NAME == "Fantasy" then rowInfo.fantasyStrip:Show() else rowInfo.fantasyStrip:Hide() end
                end

                if rowInfo.hoverFrame then
                    rowInfo.hoverFrame:ClearAllPoints()
                    rowInfo.hoverFrame:SetPoint("TOPLEFT",0,y+4)
                    rowInfo.hoverFrame:Show()
                end

                rowInfo.icon:ClearAllPoints()
                rowInfo.icon:SetPoint("TOPLEFT",4,y+3)
                rowInfo.icon:Show()

                rowInfo.label:ClearAllPoints()
                rowInfo.label:SetPoint("TOPLEFT",28,y)
                rowInfo.label:Show()

                for _,cb in ipairs(rowInfo.checks) do
                    local rankNumber = tonumber(string.match(cb.key,":(%d+)$")) or 1
                    cb:ClearAllPoints()
                    cb:SetPoint("TOPLEFT",colX[rankNumber],y+5)
                    cb:Show()
                end

                for _,btn in ipairs(rowInfo.buttons) do
                    btn:ClearAllPoints()
                    btn:SetPoint("TOPLEFT",btn.allDynamicX or allX,y+2)
                    btn:Show()
                end
            else
                rowInfo.label:Hide()
                if rowInfo.icon then rowInfo.icon:Hide() end
                if rowInfo.hoverFrame then rowInfo.hoverFrame:Hide() end
                if rowInfo.fantasyStrip then rowInfo.fantasyStrip:Hide() end
                for _,cb in ipairs(rowInfo.checks) do cb:Hide() end
                for _,btn in ipairs(rowInfo.buttons) do btn:Hide() end
            end
        end
        gc:SetHeight(math.max(1,visibleIndex * 27 + 40))

        -- Weapon list reflow.
        visibleIndex = 0
        local _, wrow
        for _,wrow in ipairs(weaponRows) do
            local matchesText = (query == "") or string.find(string.lower(wrow.name),query,1,true)
            local hasTracked = EbonAffixAlertDB.tracked[wrow.check.key] and true or false
            local visible = matchesText and ((not trackedOnly) or hasTracked)

            if visible then
                local col = visibleIndex % 2
                local row = math.floor(visibleIndex / 2)
                if wrow.fantasyStrip then
                    wrow.fantasyStrip:ClearAllPoints()
                    wrow.fantasyStrip:SetPoint("TOPLEFT",col * 270,-3 - row * 27)
                    if EAA_THEME_NAME == "Fantasy" then wrow.fantasyStrip:Show() else wrow.fantasyStrip:Hide() end
                end
                wrow.check:ClearAllPoints()
                wrow.check:SetPoint("TOPLEFT",3 + col * 270,-5 - row * 27)
                wrow.check:Show()
                if wrow.icon then wrow.icon:Show() end
                if wrow.hoverFrame then
                    wrow.hoverFrame:ClearAllPoints()
                    wrow.hoverFrame:SetPoint("LEFT",wrow.icon,"LEFT",0,0)
                    wrow.hoverFrame:Show()
                end
                wrow.text:Show()
                visibleIndex = visibleIndex + 1
            else
                wrow.check:Hide()
                if wrow.icon then wrow.icon:Hide() end
                if wrow.hoverFrame then wrow.hoverFrame:Hide() end
                if wrow.fantasyStrip then wrow.fantasyStrip:Hide() end
                wrow.text:Hide()
            end
        end
        local weaponRowsVisible = math.ceil(visibleIndex / 2)
        wc:SetHeight(math.max(1,weaponRowsVisible * 27 + 35))
    end

    local function ShowGeneral()
        weaponPage:Hide()
        generalPage:Show()
        generalButton:Disable()
        weaponButton:Enable()
    end

    local function ShowWeapon()
        generalPage:Hide()
        weaponPage:Show()
        weaponButton:Disable()
        generalButton:Enable()
    end

    generalButton:SetScript("OnClick",ShowGeneral)
    weaponButton:SetScript("OnClick",ShowWeapon)

    local clearAll = CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    clearAll:SetWidth(90); clearAll:SetHeight(24)
    clearAll:SetPoint("TOPRIGHT",-28,-84)
    clearAll:SetText("Clear All")
    SkinEAAButton(clearAll)
    clearAll:SetScript("OnClick",function()
        EbonAffixAlertDB.tracked = {}
        RefreshChecks()
    end)

    local selectPage = CreateFrame("Button",nil,panel,"UIPanelButtonTemplate")
    selectPage:SetWidth(90); selectPage:SetHeight(24)
    selectPage:SetPoint("RIGHT",clearAll,"LEFT",0,0)
    selectPage:SetText("Select All")
    SkinEAAButton(selectPage)

    local currentPage = "general"
    selectPage:SetScript("OnClick",function()
        local _, cb
        if currentPage == "general" then
            for _,cb in ipairs(generalChecks) do
                EbonAffixAlertDB.tracked[cb.key] = true
                cb:SetChecked(1)
            end
        else
            for _,cb in ipairs(weaponChecks) do
                EbonAffixAlertDB.tracked[cb.key] = true
                cb:SetChecked(1)
            end
        end
    end)

    local oldShowGeneral = ShowGeneral
    local oldShowWeapon = ShowWeapon
    ShowGeneral = function()
        currentPage = "general"
        oldShowGeneral()
    end
    ShowWeapon = function()
        currentPage = "weapon"
        oldShowWeapon()
    end
    generalButton:SetScript("OnClick",ShowGeneral)
    weaponButton:SetScript("OnClick",ShowWeapon)

    local alertSection = panel:CreateFontString(nil,"OVERLAY","GameFontNormal")
    alertSection:SetPoint("BOTTOMLEFT",24,82)
    alertSection:SetText("Alerts")
    SetEAATextColor(alertSection,EAA_THEME.cyan)

    local interfaceSection = panel:CreateFontString(nil,"OVERLAY","GameFontNormal")
    interfaceSection:SetPoint("BOTTOMLEFT",300,82)
    interfaceSection:SetText("Interface")
    SetEAATextColor(interfaceSection,EAA_THEME.cyan)

    local alertsDivider = panel:CreateTexture(nil,"ARTWORK")
    alertsDivider:SetTexture(EAA_MEDIA_PATH .. "FantasyDivider")
    alertsDivider:SetPoint("LEFT",alertSection,"RIGHT",8,0)
    alertsDivider:SetWidth(160)
    alertsDivider:SetHeight(16)
    panel.alertsFantasyDivider = alertsDivider

    local interfaceDivider = panel:CreateTexture(nil,"ARTWORK")
    interfaceDivider:SetTexture(EAA_MEDIA_PATH .. "FantasyDivider")
    interfaceDivider:SetPoint("LEFT",interfaceSection,"RIGHT",8,0)
    interfaceDivider:SetWidth(142)
    interfaceDivider:SetHeight(16)
    panel.interfaceFantasyDivider = interfaceDivider

    if EAA_THEME_NAME ~= "Fantasy" then
        alertsDivider:Hide()
        interfaceDivider:Hide()
    end

    local footerLine = CreateEAAAccentLine(panel)
    panel.footerLine = footerLine
    footerLine:SetPoint("BOTTOMLEFT",20,94)
    footerLine:SetPoint("BOTTOMRIGHT",-20,94)

    local enable = CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
    SkinEAACheckbox(enable)
    enable:SetWidth(24); enable:SetHeight(24)
    enable:SetPoint("BOTTOMLEFT",24,57)
    local et = enable:CreateFontString(nil,"OVERLAY","GameFontNormal")
    et:SetPoint("LEFT",enable,"RIGHT",2,0)
    et:SetText("Enable loot tracking")
    SetEAATextColor(et,EAA_THEME.text)
    enable:SetScript("OnClick",function(self)
        EbonAffixAlertDB.enabled = self:GetChecked() and true or false
        UpdateStatusText()
    end)
    panel.enableCheck = enable

    local raid = CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
    SkinEAACheckbox(raid)
    raid:SetWidth(24); raid:SetHeight(24)
    raid:SetPoint("BOTTOMLEFT",24,32)
    local rt = raid:CreateFontString(nil,"OVERLAY","GameFontNormal")
    rt:SetPoint("LEFT",raid,"RIGHT",2,0)
    rt:SetText("Large on-screen alert")
    SetEAATextColor(rt,EAA_THEME.text)
    raid:SetScript("OnClick",function(self)
        EbonAffixAlertDB.announceToRaidWarning = self:GetChecked() and true or false
    end)
    panel.raidCheck = raid

    local sound = CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
    SkinEAACheckbox(sound)
    sound:SetWidth(24); sound:SetHeight(24)
    sound:SetPoint("BOTTOMLEFT",24,7)
    local st = sound:CreateFontString(nil,"OVERLAY","GameFontNormal")
    st:SetPoint("LEFT",sound,"RIGHT",2,0)
    st:SetText("Alert Sound")
    SetEAATextColor(st,EAA_THEME.text)
    sound:SetScript("OnClick",function(self)
        EbonAffixAlertDB.alertSound = self:GetChecked() and true or false
    end)
    panel.soundCheck = sound

    local minimapCheck = CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
    SkinEAACheckbox(minimapCheck)
    minimapCheck:SetWidth(24); minimapCheck:SetHeight(24)
    minimapCheck:SetPoint("BOTTOMLEFT",300,57)
    local mt = minimapCheck:CreateFontString(nil,"OVERLAY","GameFontNormal")
    mt:SetPoint("LEFT",minimapCheck,"RIGHT",2,0)
    mt:SetText("Show minimap icon")
    SetEAATextColor(mt,EAA_THEME.text)
    minimapCheck:SetScript("OnClick",function(self)
        EbonAffixAlertDB.minimap.show = self:GetChecked() and true or false
        if EbonAffixAlert_UpdateMinimapVisibility then
            EbonAffixAlert_UpdateMinimapVisibility()
        end
    end)
    panel.minimapCheck = minimapCheck

    local lootWindowCheck = CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
    SkinEAACheckbox(lootWindowCheck)
    lootWindowCheck:SetWidth(24); lootWindowCheck:SetHeight(24)
    lootWindowCheck:SetPoint("BOTTOMLEFT",300,32)
    local lwt = lootWindowCheck:CreateFontString(nil,"OVERLAY","GameFontNormal")
    lwt:SetPoint("LEFT",lootWindowCheck,"RIGHT",2,0)
    lwt:SetText("Show loot history window")
    SetEAATextColor(lwt,EAA_THEME.text)
    lootWindowCheck:SetScript("OnClick",function(self)
        EbonAffixAlertDB.lootWindow.show = self:GetChecked() and true or false
        if lootWindow then
            if EbonAffixAlertDB.lootWindow.show then
                lootWindow:Show()
            else
                lootWindow:Hide()
            end
        end
    end)
    panel.lootWindowCheck = lootWindowCheck

    RefreshGeneralRankControls()
    panel:SetScript("OnShow",function()
        SetEAATheme(EbonAffixAlertDB.uiStyle or "Modern")
        RefreshGeneralRankControls()
        RefreshChecks()
    end)
    ShowGeneral()
    panel:Hide()
end

local function UpdateMinimapPosition()
    if not minimapButton then return end
    local angle = math.rad(EbonAffixAlertDB.minimap.angle or 225)
    local radius = EbonAffixAlertDB.minimap.radius or 80
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint(
        "CENTER",Minimap,"CENTER",
        math.cos(angle)*radius,
        math.sin(angle)*radius
    )
end

UpdateMinimapEnabledVisual = function()
    if not minimapButton or not minimapButton.icon then return end

    if EbonAffixAlertDB.enabled then
        minimapButton.icon:SetVertexColor(1,1,1)
        minimapButton.icon:SetAlpha(1)
    else
        -- Vertex tint + reduced alpha is reliable on the 3.3.5 client,
        -- whereas Texture:SetDesaturated is not consistently available.
        minimapButton.icon:SetVertexColor(0.45,0.45,0.45)
        minimapButton.icon:SetAlpha(0.55)
    end
end

function EbonAffixAlert_UpdateMinimapVisibility()
    if not minimapButton then return end
    if EbonAffixAlertDB.minimap.show then
        minimapButton:Show()
    else
        minimapButton:Hide()
    end
end

local function CreateMinimapButton()
    minimapButton = CreateFrame("Button","EbonAffixAlertMinimapButton",Minimap)
    minimapButton:SetWidth(32); minimapButton:SetHeight(32)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:RegisterForClicks("LeftButtonUp","RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")

    local icon = minimapButton:CreateTexture(nil,"BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
    icon:SetWidth(20); icon:SetHeight(20)
    icon:SetPoint("CENTER")
    minimapButton.icon = icon


    local border = minimapButton:CreateTexture(nil,"OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(54); border:SetHeight(54)
    border:SetPoint("TOPLEFT",0,0)


    minimapButton:SetScript("OnDragStart",function(self)
        if not IsControlKeyDown() then return end

        self.isDragging = true
        self:SetScript("OnUpdate",function()
            local mx,my = Minimap:GetCenter()
            local cx,cy = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()

            cx = cx / scale
            cy = cy / scale

            local dx = cx - mx
            local dy = cy - my
            local angle = math.deg(math.atan2(dy,dx))

            EbonAffixAlertDB.minimap.angle = angle
            UpdateMinimapPosition()
        end)
    end)

    minimapButton:SetScript("OnDragStop",function(self)
        self.isDragging = nil
        self:SetScript("OnUpdate",nil)
    end)

    minimapButton:SetScript("OnClick",function(self,button)
        if button == "LeftButton" and IsShiftKeyDown() then
            EbonAffixAlertDB.minimap.show = false
            self:Hide()
            if panel and panel.minimapCheck then
                panel.minimapCheck:SetChecked(nil)
            end
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cff33ff99[EAA]|r Minimap icon hidden. Use |cffffff00/eaa|r to configure and re-enable it."
            )
            return
        end

        if button == "RightButton" then
            EbonAffixAlertDB.enabled = not EbonAffixAlertDB.enabled
            UpdateStatusText()
            DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[EAA]|r Tracking "
                .. (EbonAffixAlertDB.enabled and "enabled." or "disabled."))
        else
            if panel:IsShown() then panel:Hide() else panel:Show() end
        end
    end)

    minimapButton:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:AddLine("Ebon Affix Alert")
        GameTooltip:AddLine("Left-click: Open settings",1,1,1)
        GameTooltip:AddLine("Right-click: Toggle tracking",1,1,1)
        GameTooltip:AddLine("Ctrl + drag: Move minimap icon",1,1,1)
        GameTooltip:AddLine("Shift-left-click: Hide minimap icon",1,1,1)
        GameTooltip:AddLine(
            "Loot history: " .. GetColoredLootHistoryCount(),
            1,1,1
        )
        GameTooltip:Show()
    end)
    minimapButton:SetScript("OnLeave",function() GameTooltip:Hide() end)

    UpdateMinimapPosition()
    EbonAffixAlert_UpdateMinimapVisibility()
    UpdateMinimapEnabledVisual()
    UpdateMinimapLootCount()
end

local function ExtractItemLink(message)
    if not message then return nil end
    return string.match(message,"(|c%x+|Hitem:.-|h%[.-%]|h|r)")
        or string.match(message,"(|Hitem:.-|h%[.-%]|h)")
end

local function ExtractDisplayedItemName(link)
    if not link then return nil end
    return string.match(link,"|h%[(.-)%]|h")
end

local function EndsWith(text,suffix)
    if not text or not suffix then return false end
    return string.sub(text,-string.len(suffix)) == suffix
end

-- Forward declaration: FindTrackedAffix is defined before the Weapon proc
-- scanner implementation below, so both functions must share this upvalue.
local FindTrackedWeaponAffixByProc

-- Match the displayed item suffix against the user's tracked selections.
local function FindTrackedAffix(itemName,itemLink)
    local _, entry, rank, name

    for _,entry in ipairs(generalAffixes) do
        local affixName = entry[1]
        local maxRank = GetMaxRankForAffix(affixName)
        for rank=maxRank,1,-1 do
            if EbonAffixAlertDB.tracked[GKey(affixName,rank)] then
                local itemAffixName = affixName

                -- Project Ebonhold displays the "Shield Block" affix on items
                -- simply as "Block", e.g. "Fists of the Sun of Block II".
                if affixName == "Shield Block" then
                    itemAffixName = "Block"
                end

                local suffix = " of " .. itemAffixName .. " " .. roman[rank]
                if EndsWith(itemName,suffix) then
                    return affixName,roman[rank],"General"
                end
            end
        end
    end

    -- Weapon affixes are identified from their proc text rather than from the
    -- displayed item name. Match the item's proc against Project Ebonhold's
    -- Weapon-affix spell descriptions.
    local procAffix = FindTrackedWeaponAffixByProc(itemLink)
    if procAffix then
        return procAffix,nil,"Weapon"
    end
end


-- ---------------------------------------------------------------------------
-- Weapon affix detection by proc description.
--
-- Project Ebonhold weapon affixes are often inherent effects on a normally
-- named weapon (for example "Heartseeker") rather than an "of Flurry" suffix.
-- In those cases the affix is represented by the item's proc text instead.
--
-- We use Ebonhold's authoritative Weapon affix spell IDs to read each affix's
-- spell description, normalize variable wording/numbers, then compare it with
-- "Chance on hit:" / "Chance to strike:" lines from the looted weapon tooltip.
-- ---------------------------------------------------------------------------

-- Verified original/vanilla weapon proc wording used as EAA's primary Weapon-affix signatures.
-- Numeric tuning is intentionally omitted because multiple source weapons can share the same affix
-- with different damage, healing, duration, rating, or percentage values.
-- Ebonhold's live affix descriptions remain the fallback for future affixes.
local VERIFIED_WEAPON_PROC_TEXT = {
    ["Affliction"] = "Chance on hit: Sends a shadowy bolt at the enemy causing Shadow damage.",
    ["Azzinoth"] = "Chance on hit: Calls forth an Ember of Azzinoth to protect you in battle for a short period of time.",
    ["Bladestorm"] = "Chance on hit: You attack all nearby enemies causing weapon damage.",
    ["Bloodlust"] = "Chance on hit: Increases your haste rating.",
    ["Clarity"] = "Chance on hit: Restores mana.",
    ["Concussion"] = "Chance on hit: Stuns target.",
    ["Decay"] = "Chance on hit: Corrupts the target, causing damage over time.",
    ["Devastation"] = "Chance on hit: Increases the critical strike rating of your next attack.",
    ["Dissolution"] = "Chance on hit: Corrosive acid deals Nature damage and lowers target's armor.",
    ["Execution"] = "Chance on hit: Wounds the target for damage.",
    ["Ferocity"] = "Chance on hit: Increases attack power.",
    ["Fire Blast"] = "Equip: Chance to strike your ranged target with a Fire Blast for Fire damage.",
    ["Flame Wrath"] = "Chance on hit: Envelops the caster with a Fire shield and shoots a ring of fire dealing damage to nearby enemies.",
    ["Flurry"] = "Chance on hit: Grants an extra attack on your next swing.",
    ["Fortification"] = "Chance on hit: Increases Defense.",
    ["Frailty"] = "Chance on hit: Lowers all attributes of target.",
    ["Frost Arrow"] = "Equip: Chance to strike your target with a Frost Arrow for Frost damage.",
    ["Fury"] = "Chance on hit: Chance on melee attack to gain Energy or Rage.",
    ["Glaciation"] = "Chance on hit: Launches a bolt of frost at the enemy causing Frost damage and slowing movement speed.",
    ["Hemorrhage"] = "Chance on hit: Wounds the target causing them to bleed for damage over time.",
    ["Incineration"] = "Chance on hit: Blasts a target for Fire damage.",
    ["Judgement"] = "Chance on hit: Smites an enemy for Holy damage.",
    ["Julie's Blessing"] = "Chance on hit: Heals wielder over time.",
    ["Keeper's Sting"] = "Equip: Chance to strike your ranged target with Keeper's Sting for Nature damage.",
    ["Maiming"] = "Chance on hit: Delivers a fatal wound for damage.",
    ["Permafrost"] = "Chance on hit: Blasts a target for Frost damage.",
    ["Pyromancy"] = "Chance on hit: Hurls a fiery ball that causes Fire damage and additional damage over time.",
    ["Rending"] = "Chance on hit: Punctures target's armor lowering it.",
    ["Resurgence"] = "Chance on hit: Increases Strength.",
    ["Shackling"] = "Chance on hit: Disarms target's weapon.",
    ["Shahram"] = "Chance on hit: Summons the infernal spirit of Shahram.",
    ["Speed"] = "Chance on hit: Increases run speed.",
    ["Sulfuras"] = "Chance on hit: Hurls a fiery ball that causes Fire damage and additional damage over time.",
    ["Thunderfury"] = "Chance on hit: Blasts your enemy with lightning, dealing Nature damage and jumping to nearby enemies. Each jump reduces Nature resistance. Your primary target is also consumed by a cyclone, slowing its attack speed.",
    ["Undead"] = "Chance on hit: Increases attack power against Undead.",
    ["Val'anyr"] = "Your healing spells have a chance to cause Blessing of Ancient Kings allowing your heals to shield the target absorbing damage.",
    ["Vampirism"] = "Chance on hit: Steals life from target enemy.",
    ["Venom"] = "Chance on hit: Poisons target for Nature damage over time.",
    ["Vulnerability"] = "Chance on hit: Spell damage taken by target increased.",
    ["Wilds"] = "Chance on hit: Blasts a target for Nature damage.",
}

local weaponProcDescriptions = {}
local weaponItemScanTooltip
local weaponSpellScanTooltip

local EAA_WEAPON_EQUIP_LOCS = {
    INVTYPE_WEAPON = true,
    INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_HOLDABLE = true,
    INVTYPE_RANGED = true,
    INVTYPE_RANGEDRIGHT = true,
    INVTYPE_THROWN = true
}

local function NormalizeWeaponProcText(text)
    if type(text) ~= "string" then return "" end

    text = string.lower(text)
    text = string.gsub(text,"|c%x%x%x%x%x%x%x%x","")
    text = string.gsub(text,"|r","")
    text = string.gsub(text,"^%s+","")

    -- Item tooltips normally prefix the same underlying spell text with one
    -- of these phrases. Remove it so the item and spell descriptions compare.
    text = string.gsub(text,"^equip%s*:%s*","")
    text = string.gsub(text,"^chance on hit%s*:?%s*","")
    text = string.gsub(text,"^chance to strike[^:]-:?%s*","")

    -- Spell descriptions can contain variable references and numeric values
    -- which may be resolved differently in the item tooltip.
    text = string.gsub(text,"%$[%a]+","")
    text = string.gsub(text,"%d+%.?%d*","")
    text = string.gsub(text,"[%s%.,;:!?]+"," ")
    text = string.gsub(text,"^%s+","")
    text = string.gsub(text,"%s+$","")

    return text
end

-- Produce a second comparison form that tolerates very small wording
-- differences between the Ebonhold spell tooltip and the generated item proc.
-- Examples include "Smite" vs "Smites" and harmless article/conjunction
-- differences such as "an" vs "and". We keep meaningful nouns/verbs/damage
-- school words so unrelated proc effects still do not compare equal.
local function NormalizeWeaponProcForMatch(text)
    text = NormalizeWeaponProcText(text)
    if text == "" then return "" end

    local words = {}
    local word
    for word in string.gmatch(text,"%S+") do
        -- Ignore low-information glue words which are prone to small tooltip
        -- wording/typo differences.
        if word ~= "a" and word ~= "an" and word ~= "and" and word ~= "the" then
            -- Light stemming for common third-person verb wording:
            -- "smites" -> "smite", "increases" -> "increase", etc.
            if string.len(word) > 4 and string.sub(word,-1) == "s" then
                word = string.sub(word,1,-2)
            end
            table.insert(words,word)
        end
    end

    return table.concat(words," ")
end


-- Break normalized proc text into meaningful content words. We deliberately
-- ignore generic glue/wrapper terms which appear in Ebonhold's affix-book
-- descriptions ("allow you to engrave...", "chance to...", etc.).
local WEAPON_PROC_STOP_WORDS = {
    ["a"]=true, ["an"]=true, ["and"]=true, ["the"]=true, ["to"]=true,
    ["of"]=true, ["for"]=true, ["with"]=true, ["your"]=true, ["you"]=true,
    ["this"]=true, ["that"]=true, ["it"]=true, ["on"]=true, ["in"]=true,
    ["any"]=true, ["have"]=true, ["has"]=true, ["can"]=true, ["will"]=true,
    ["chance"]=true, ["affix"]=true, ["engrave"]=true, ["engraved"]=true,
    ["weapon"]=true, ["equippable"]=true, ["spell"]=true, ["ability"]=true,
    ["abilities"]=true, ["scale"]=true, ["scales"]=true, ["hit"]=true
}

local function WeaponProcWordSet(text)
    local normalized = NormalizeWeaponProcForMatch(text)
    local set = {}
    local count = 0
    local word

    for word in string.gmatch(normalized,"%S+") do
        if not WEAPON_PROC_STOP_WORDS[word] and string.len(word) >= 3 then
            if not set[word] then
                set[word] = true
                count = count + 1
            end
        end
    end

    return set,count
end

-- Score how much of the actual item proc's meaningful vocabulary appears in
-- the Ebonhold affix description. The item proc is intentionally the reference:
-- Ebonhold descriptions can contain lots of extra instructional text.
local function ScoreWeaponProcMatch(itemProcText,affixDescription)
    local itemWords,itemCount = WeaponProcWordSet(itemProcText)
    local descWords = WeaponProcWordSet(affixDescription)

    if itemCount == 0 then return 0,0,0 end

    local matched = 0
    local word
    for word in pairs(itemWords) do
        if descWords[word] then
            matched = matched + 1
        end
    end

    return matched / itemCount, matched, itemCount
end

local function LooksLikeWeaponProcLine(text)
    if type(text) ~= "string" then return false end
    local lower = string.lower(text)
    lower = string.gsub(lower,"^|c%x%x%x%x%x%x%x%x","")
    lower = string.gsub(lower,"^%s+","")

    return string.find(lower,"^chance on hit") ~= nil
        or string.find(lower,"^chance to strike") ~= nil
        or string.find(lower,"^equip%s*:%s*chance to strike") ~= nil
end

local function EnsureWeaponSpellScanTooltip()
    if weaponSpellScanTooltip then return weaponSpellScanTooltip end

    weaponSpellScanTooltip = CreateFrame(
        "GameTooltip",
        "EAAWeaponAffixSpellScanTooltip",
        nil,
        "GameTooltipTemplate"
    )
    weaponSpellScanTooltip:SetOwner(WorldFrame,"ANCHOR_NONE")
    return weaponSpellScanTooltip
end

local function EnsureWeaponItemScanTooltip()
    if weaponItemScanTooltip then return weaponItemScanTooltip end

    weaponItemScanTooltip = CreateFrame(
        "GameTooltip",
        "EAAWeaponAffixItemScanTooltip",
        nil,
        "GameTooltipTemplate"
    )
    weaponItemScanTooltip:SetOwner(WorldFrame,"ANCHOR_NONE")
    return weaponItemScanTooltip
end

local function GetWeaponAffixSpellDescription(spellId)
    if not spellId then return nil end

    local tip = EnsureWeaponSpellScanTooltip()
    if not tip then return nil end

    tip:SetOwner(WorldFrame,"ANCHOR_NONE")
    tip:ClearLines()

    local ok = pcall(function()
        tip:SetHyperlink("spell:" .. tostring(spellId))
    end)
    if not ok then return nil end

    local numLines = tip:NumLines() or 0
    if numLines < 2 then return nil end

    local parts = {}
    local i
    for i=2,numLines do
        local lineObj = _G["EAAWeaponAffixSpellScanTooltipTextLeft" .. i]
        local lineText = lineObj and lineObj.GetText and lineObj:GetText()
        if lineText and lineText ~= "" then
            table.insert(parts,lineText)
        end
    end

    if #parts == 0 then return nil end
    return table.concat(parts," ")
end


local function BuildWeaponAffixDescriptionExport()
    local svc = _G.ExtractionService

    if not svc or type(svc.learnedAffixes) ~= "table" or #svc.learnedAffixes == 0 then
        return table.concat({
            "=== EAA Weapon Affix Description Export ===",
            "EAA Version: " .. tostring(GetEAAVersion()),
            "",
            "Project Ebonhold ExtractionService.learnedAffixes is not currently available.",
            "Try /eaa rescanIcons, wait a moment, then run /eaa weaponAffixes again."
        },"\n")
    end

    local entries = {}
    local seen = {}
    local _,affix

    for _,affix in ipairs(svc.learnedAffixes) do
        if affix and affix.weaponOnly
            and type(affix.name) == "string"
            and affix.name ~= ""
            and affix.id
            and not seen[affix.name] then

            seen[affix.name] = true

            local rawDescription = GetWeaponAffixSpellDescription(affix.id)
            local normalized = NormalizeWeaponProcForMatch(rawDescription or "")

            table.insert(entries,{
                name = affix.name,
                id = affix.id,
                description = rawDescription or "(description unavailable)",
                normalized = normalized ~= "" and normalized or "(unavailable)"
            })
        end
    end

    table.sort(entries,function(a,b)
        return string.lower(a.name) < string.lower(b.name)
    end)

    local lines = {
        "=== EAA Weapon Affix Description Export ===",
        "EAA Version: " .. tostring(GetEAAVersion()),
        "Source: Project Ebonhold ExtractionService.learnedAffixes",
        "Weapon affixes found: " .. tostring(#entries),
        "",
        "Paste this entire export into ChatGPT for proc-matching review.",
        ""
    }

    local _,entry
    for _,entry in ipairs(entries) do
        table.insert(lines,"[" .. entry.name .. "]")
        table.insert(lines,"Spell ID: " .. tostring(entry.id))
        table.insert(lines,"Description: " .. tostring(entry.description))
        table.insert(lines,"Normalized: " .. tostring(entry.normalized))
        local verifiedProc = VERIFIED_WEAPON_PROC_TEXT[entry.name]
        table.insert(lines,"Verified Original Proc: " .. tostring(verifiedProc or "(not built in)"))
        table.insert(lines,"")
    end

    return table.concat(lines,"\n")
end

local function ShowWeaponAffixDescriptionExport()
    ShowCopyTextWindow(
        "EAA - Weapon Affix API Descriptions",
        BuildWeaponAffixDescriptionExport()
    )
end


local verifiedWeaponProcSignatures = nil

local function BuildVerifiedWeaponProcSignatures()
    verifiedWeaponProcSignatures = {}

    local affixName,procText
    for affixName,procText in pairs(VERIFIED_WEAPON_PROC_TEXT) do
        local normalized = NormalizeWeaponProcForMatch(procText)
        if normalized ~= "" then
            verifiedWeaponProcSignatures[affixName] = {
                raw = procText,
                normalized = normalized
            }
        end
    end
end

local function FindVerifiedWeaponAffixByProcLine(lineText)
    if not lineText or lineText == "" then return nil end
    if not verifiedWeaponProcSignatures then
        BuildVerifiedWeaponProcSignatures()
    end

    local bestName = nil
    local bestScore = 0
    local bestMatched = 0

    local affixName,data
    for affixName,data in pairs(verifiedWeaponProcSignatures) do
        -- Only identify affixes that currently exist in Ebonhold's live/fallback
        -- catalog AND are actually tracked by the user.
        local catalogEntry = serverAffixCatalog[affixName]
        if catalogEntry and catalogEntry.weaponOnly
            and EbonAffixAlertDB.tracked[WKey(affixName)] then

            local score,matched,total = ScoreWeaponProcMatch(lineText,data.raw)

            if EbonAffixAlertDB.debug then
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cff66ccff[EAA Debug]|r Verified compare " .. tostring(affixName)
                    .. ": " .. tostring(matched) .. "/" .. tostring(total)
                    .. " (" .. string.format("%.0f",score * 100) .. "%)"
                )
            end

            -- Verified source text is much stronger than the Ebonhold-description
            -- fallback. Require at least 2 meaningful words for short vanilla
            -- procs, and 75% of the source proc vocabulary.
            if matched >= 2 and score >= 0.75 then
                if score > bestScore
                    or (score == bestScore and matched > bestMatched) then
                    bestName = affixName
                    bestScore = score
                    bestMatched = matched
                end
            end
        end
    end

    if EbonAffixAlertDB.debug and bestName then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff66ccff[EAA Debug]|r Verified Weapon proc matched: "
            .. tostring(bestName)
        )
    end

    return bestName
end

local function BuildWeaponProcDescriptionCache()
    weaponProcDescriptions = {}
    weaponProcDescriptionsStale = false

    local name, entry
    for name,entry in pairs(serverAffixCatalog) do
        if entry and entry.weaponOnly and entry.spellId then
            local desc = GetWeaponAffixSpellDescription(entry.spellId)
            local normalized = NormalizeWeaponProcText(desc)
            local matchNormalized = NormalizeWeaponProcForMatch(desc)
            if normalized ~= "" and string.len(normalized) >= 12 and matchNormalized ~= "" then
                weaponProcDescriptions[name] = {
                    raw = desc,
                    normalized = normalized,
                    matchNormalized = matchNormalized
                }
            end
        end
    end
end

local function IsWeaponItemLink(link)
    if not link or not GetItemInfo then return false end

    local _,_,_,_,_,_,_,_,equipLoc = GetItemInfo(link)
    if not equipLoc then
        -- Item info can occasionally be uncached at the instant loot chat fires.
        -- In that case we allow the tooltip scan rather than creating a false
        -- negative; the strict proc-line matching below still protects us.
        return true
    end

    return EAA_WEAPON_EQUIP_LOCS[equipLoc] and true or false
end

FindTrackedWeaponAffixByProc = function(link)
    if not link or not IsWeaponItemLink(link) then return nil end

    if weaponProcDescriptionsStale then
        BuildWeaponProcDescriptionCache()
    end
    if not next(weaponProcDescriptions) then
        if EbonAffixAlertDB and EbonAffixAlertDB.debug then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cff66ccff[EAA Debug]|r Weapon proc cache is empty; "
                .. "Ebonhold affix spell data may not be available yet."
            )
        end
        return nil
    end

    local tip = EnsureWeaponItemScanTooltip()
    if not tip then return nil end

    tip:SetOwner(WorldFrame,"ANCHOR_NONE")
    tip:ClearLines()

    local ok = pcall(function()
        tip:SetHyperlink(link)
    end)
    if not ok then return nil end

    local numLines = tip:NumLines() or 0
    if numLines == 0 then return nil end

    local bestName
    local bestLength = 0
    local i, affixName, descNorm

    for i=1,numLines do
        local lineObj = _G["EAAWeaponAffixItemScanTooltipTextLeft" .. i]
        local lineText = lineObj and lineObj.GetText and lineObj:GetText()

        local isKnownValanyrLine = lineText and string.find(
            string.lower(lineText),
            "blessing of ancient kings",
            1,
            true
        ) ~= nil

        if lineText and lineText ~= ""
            and (LooksLikeWeaponProcLine(lineText) or isKnownValanyrLine) then
            local lineMatchNorm = NormalizeWeaponProcForMatch(lineText)

            if EbonAffixAlertDB.debug then
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cff66ccff[EAA Debug]|r Weapon proc line: " .. tostring(lineText)
                )
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cff66ccff[EAA Debug]|r Normalized proc: " .. tostring(lineMatchNorm)
                )
            end

            -- PRIMARY: compare against the built-in verified original weapon
            -- proc table. This avoids relying on Ebonhold's sometimes-redesigned
            -- extraction description.
            local verifiedAffix = FindVerifiedWeaponAffixByProcLine(lineText)
            if verifiedAffix then
                return verifiedAffix
            end

            -- FALLBACK: for newly-added/future Ebonhold Weapon affixes that are
            -- not yet present in the verified table, compare against Ebonhold's
            -- live affix spell description using the tolerant word-overlap logic.
            if lineMatchNorm ~= "" then
                local bestScore = 0
                local bestMatched = 0
                local bestTotal = 0

                for affixName,descData in pairs(weaponProcDescriptions) do
                    if not VERIFIED_WEAPON_PROC_TEXT[affixName]
                        and EbonAffixAlertDB.tracked[WKey(affixName)] then

                        local rawDesc = descData and descData.raw or ""
                        local score, matchedWords, totalWords =
                            ScoreWeaponProcMatch(lineText,rawDesc)

                        if EbonAffixAlertDB.debug then
                            DEFAULT_CHAT_FRAME:AddMessage(
                                "|cff66ccff[EAA Debug]|r Fallback compare " .. tostring(affixName)
                                .. ": " .. tostring(matchedWords) .. "/" .. tostring(totalWords)
                                .. " (" .. string.format("%.0f",score * 100) .. "%)"
                            )
                        end

                        if matchedWords >= 3 and score >= 0.75 then
                            if score > bestScore
                                or (score == bestScore and matchedWords > bestMatched) then
                                bestName = affixName
                                bestScore = score
                                bestMatched = matchedWords
                                bestTotal = totalWords
                                bestLength = matchedWords
                            end
                        end
                    end
                end

                if EbonAffixAlertDB.debug and bestName then
                    DEFAULT_CHAT_FRAME:AddMessage(
                        "|cff66ccff[EAA Debug]|r Fallback Weapon affix match: "
                        .. tostring(bestName) .. " (" .. tostring(bestMatched)
                        .. "/" .. tostring(bestTotal) .. " words)"
                    )
                end
            end
        end
    end

    if bestName then
        if EbonAffixAlertDB.debug then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cff66ccff[EAA Debug]|r Weapon proc matched: "
                .. tostring(bestName) .. " on " .. tostring(link)
            )
        end
        return bestName
    end

    return nil
end

local function IsPlayerLoot(message,playerField)
    local playerName = UnitName("player")
    if playerField and playerName and playerField == playerName then
        return true
    end

    if message and (
        string.find(message,"^You receive loot:")
        or string.find(message,"^You receive item:")
        or string.find(message,"^You create:")
    ) then
        return true
    end

    return false
end



GetColoredLootHistoryCount = function()
    local count = #lootHistory

    if count < 10 then
        return "|cff00ff00" .. tostring(count) .. "|r"
    elseif count < 25 then
        return "|cffffff00" .. tostring(count) .. "|r"
    else
        return "|cffff8000" .. tostring(count) .. "|r"
    end
end

UpdateMinimapLootCount = function()
    -- Count is now displayed in the minimap tooltip rather than overlaid
    -- on the minimap button itself.
end

local function RefreshLootWindow()
    if not lootWindow or not lootWindow.rows or not lootWindow.scrollContent then return end

    local width = lootWindow:GetWidth()
    local height = lootWindow:GetHeight()

    local contentWidth = math.max(190, width - 58)
    lootWindow.scrollContent:SetWidth(contentWidth)

    local narrowMode = width < 380
    local rowHeight

    if narrowMode then
        rowHeight = 38
        if lootWindow.headerAffix then lootWindow.headerAffix:Hide() end
        if lootWindow.headerItem then
            lootWindow.headerItem:ClearAllPoints()
            lootWindow.headerItem:SetPoint("TOPLEFT",20,-54)
            lootWindow.headerItem:SetText("Looted Item / Tracked Affix")
        end
    else
        rowHeight = 22
        if lootWindow.headerAffix then lootWindow.headerAffix:Show() end
        if lootWindow.headerItem then
            lootWindow.headerItem:ClearAllPoints()
            lootWindow.headerItem:SetPoint("TOPLEFT",20,-54)
            lootWindow.headerItem:SetText("Item")
        end
    end

    local total = #lootHistory
    local contentHeight = math.max(height - 118, total * rowHeight + 4)
    lootWindow.scrollContent:SetHeight(contentHeight)

    local i
    for i = 1, #lootWindow.rows do
        local row = lootWindow.rows[i]
        row:SetHeight(rowHeight)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",0,-((i-1)*rowHeight))
        row:SetWidth(contentWidth)

        row.item:ClearAllPoints()
        row.affix:ClearAllPoints()
        row.affixIcon:ClearAllPoints()

        if narrowMode then
            -- Give long item names the full width and put the affix beneath.
            row.item:SetWidth(contentWidth)
            row.item:SetPoint("TOPLEFT",0,-1)
            row.item:SetJustifyH("LEFT")
            row.item:SetWordWrap(false)

            row.affixIcon:SetWidth(16)
            row.affixIcon:SetHeight(16)
            row.affixIcon:SetPoint("TOPLEFT",0,-18)

            row.affix:SetWidth(math.max(80,contentWidth-20))
            row.affix:SetPoint("TOPLEFT",20,-19)
            row.affix:SetJustifyH("LEFT")
            row.affix:SetTextColor(EAA_THEME.purple[1],EAA_THEME.purple[2],EAA_THEME.purple[3])
        else
            local affixWidth = math.max(115, math.floor(contentWidth * 0.34))
            local itemWidth = math.max(150, contentWidth - affixWidth - 12)

            row.item:SetWidth(itemWidth)
            row.item:SetPoint("LEFT",0,0)
            row.item:SetTextColor(EAA_THEME.text[1],EAA_THEME.text[2],EAA_THEME.text[3])
            row.item:SetJustifyH("LEFT")
            row.item:SetWordWrap(false)

            row.affixIcon:SetWidth(16)
            row.affixIcon:SetHeight(16)
            row.affixIcon:SetPoint("LEFT",row.item,"RIGHT",8,0)

            row.affix:SetWidth(math.max(75,affixWidth-20))
            row.affix:SetPoint("LEFT",row.affixIcon,"RIGHT",4,0)
            row.affix:SetJustifyH("LEFT")
            row.affix:SetTextColor(EAA_THEME.purple[1],EAA_THEME.purple[2],EAA_THEME.purple[3])
        end

        row.affixIcon:Hide()
        row:Hide()
    end

    local rowIndex = 1
    for i = total, 1, -1 do
        local entry = lootHistory[i]
        local row = lootWindow.rows[rowIndex]
        if not row then break end

        row.historyIndex = i
        row.itemLink = entry.link
        row.item:SetText(entry.link or entry.itemName or "Unknown item")
        row.affixIcon:SetTexture(GetAffixIcon(entry.affixName or ""))
        row.affixIcon:Show()

        if narrowMode then
            row.affix:SetText("Affix: " .. (entry.affixText or ""))
        else
            row.affix:SetText(entry.affixText or "")
        end

        row:Show()
        rowIndex = rowIndex + 1
    end

    lootWindow.countText:SetText(
        tostring(total) .. (total == 1 and " item" or " items")
    )
    UpdateMinimapLootCount()

    if lootWindow.scrollFrame then
        lootWindow.scrollFrame:SetVerticalScroll(0)
    end
end

local function ClearLootHistory()
    lootHistory = {}
    RefreshLootWindow()
    UpdateMinimapLootCount()
end

-- Loot History is session-only and stores only successful tracked matches.
local function AddLootHistoryEntry(link,itemName,affixName,rank)
    local affixText = affixName .. (rank and (" " .. rank) or "")

    table.insert(lootHistory,{
        link = link,
        itemName = itemName,
        affixText = affixText,
        affixName = affixName
    })

    local maxEntries = EbonAffixAlertDB.lootWindow.maxEntries or 50
    while #lootHistory > maxEntries do
        table.remove(lootHistory,1)
    end

    RefreshLootWindow()
end

local function CreateLootWindow()
    lootWindow = CreateFrame("Frame","EbonAffixAlertLootWindow",UIParent)
    lootWindow:SetWidth(EbonAffixAlertDB.lootWindow.width or 300)
    lootWindow:SetHeight(EbonAffixAlertDB.lootWindow.height or 300)
    lootWindow:SetPoint("CENTER",UIParent,"CENTER",280,20)
    lootWindow:SetFrameStrata("DIALOG")
    ApplyEAAFrameSkin(lootWindow)
    lootWindow:EnableMouse(true)
    lootWindow:SetMovable(true)
    lootWindow:SetResizable(true)
    lootWindow:SetMinResize(250,220)
    lootWindow:SetMaxResize(760,600)
    lootWindow:RegisterForDrag("LeftButton")
    lootWindow:SetScript("OnDragStart",function(self)
        if not self.isResizing then
            self:StartMoving()
        end
    end)
    lootWindow:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing()
    end)

    local title = lootWindow:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    title:SetPoint("TOPLEFT",20,-18)
    title:SetText("Loot History")
    SetEAATextColor(title,EAA_THEME.title)
    lootWindow.title = title
    ApplyLootHistoryTitleStyle()

    local close = CreateFrame("Button",nil,lootWindow,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-5,-5)
    close:SetScript("OnClick",function()
        lootWindow:Hide()
        EbonAffixAlertDB.lootWindow.show = false
        if panel and panel.lootWindowCheck then
            panel.lootWindowCheck:SetChecked(nil)
        end
    end)

    lootWindow.countText = lootWindow:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    lootWindow.countText:SetPoint("TOPRIGHT",-42,-24)
    lootWindow.countText:SetText("0 items")
    SetEAATextColor(lootWindow.countText,EAA_THEME.muted)

    local clear = CreateFrame("Button",nil,lootWindow,"UIPanelButtonTemplate")
    clear:SetWidth(70); clear:SetHeight(22)
    clear:SetPoint("BOTTOMRIGHT",-32,16)
    clear:SetText("Clear")
    SkinEAAButton(clear)
    clear:SetScript("OnClick",ClearLootHistory)

    local hint = lootWindow:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT",20,48)
    hint:SetText("Newest first - up to 50 entries")
    SetEAATextColor(hint,EAA_THEME.muted)
    lootWindow.hint = hint

    local transparentCheck = CreateFrame("CheckButton",nil,lootWindow,"UICheckButtonTemplate")
    SkinEAACheckbox(transparentCheck)
    transparentCheck:SetWidth(24)
    transparentCheck:SetHeight(24)
    transparentCheck:SetPoint("BOTTOMLEFT",16,11)

    local transparentText = transparentCheck:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    transparentText:SetPoint("LEFT",transparentCheck,"RIGHT",2,0)
    transparentText:SetText("Transparency")
    SetEAATextColor(transparentText,EAA_THEME.text)

    transparentCheck:SetScript("OnClick",function(self)
        EbonAffixAlertDB.lootWindow.transparent = self:GetChecked() and true or false
        lootWindow.eaaTransparent = EbonAffixAlertDB.lootWindow.transparent
        ApplyEAAFrameSkin(lootWindow)
        if lootWindow.historyInset then UpdateEAAInset(lootWindow.historyInset) end
    end)
    lootWindow.transparentCheck = transparentCheck

    local headerItem = lootWindow:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    headerItem:SetPoint("TOPLEFT",20,-54)
    headerItem:SetText("Item")
    SetEAATextColor(headerItem,EAA_THEME.cyan)
    lootWindow.headerItem = headerItem

    local headerAffix = lootWindow:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    headerAffix:SetPoint("TOPRIGHT",-42,-54)
    headerAffix:SetText("Tracked Affix")
    SetEAATextColor(headerAffix,EAA_THEME.cyan)
    lootWindow.headerAffix = headerAffix

    local line = CreateEAAAccentLine(lootWindow)
    line:SetPoint("TOPLEFT",18,-70)
    line:SetPoint("TOPRIGHT",-18,-70)

    -- Scrollable history area.
    local historyInset = CreateEAAInset(lootWindow)
    historyInset:SetPoint("TOPLEFT",18,-76)
    historyInset:SetPoint("BOTTOMRIGHT",-20,70)
    lootWindow.historyInset = historyInset

    local scroll = CreateFrame("ScrollFrame","EbonAffixAlertLootScroll",lootWindow,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",18,-76)
    scroll:SetPoint("BOTTOMRIGHT",-32,80)
    lootWindow.scrollFrame = scroll

    local content = CreateFrame("Frame","EbonAffixAlertLootScrollContent",scroll)
    content:SetWidth(420)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    lootWindow.scrollContent = content

    lootWindow.rows = {}

    local i
    for i = 1,50 do
        local row = CreateFrame("Frame",nil,content)
        row:SetHeight(22)
        row:SetPoint("TOPLEFT",0,-((i-1)*22))
        row:EnableMouse(true)

        row:SetScript("OnMouseUp",function(self,button)
            if button == "RightButton" then
                if self.historyIndex and lootHistory[self.historyIndex] then
                    table.remove(lootHistory,self.historyIndex)
                    RefreshLootWindow()
                end
                return
            end

            if button == "LeftButton" and IsShiftKeyDown() and self.itemLink then
                if ChatEdit_GetActiveWindow and ChatEdit_InsertLink then
                    local editBox = ChatEdit_GetActiveWindow()
                    if editBox then
                        ChatEdit_InsertLink(self.itemLink)
                    else
                        ChatFrame_OpenChat(self.itemLink)
                    end
                else
                    ChatFrame_OpenChat(self.itemLink)
                end
            end
        end)

        row:SetScript("OnEnter",function(self)
            if self.itemLink then
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.itemLink)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Shift-click: Link in chat",0.8,0.8,0.8)
                GameTooltip:AddLine("Right-click: Remove from history",0.8,0.8,0.8)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)

        row.item = row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        row.item:SetJustifyH("LEFT")
        row.item:SetPoint("LEFT",0,0)

        row.affixIcon = row:CreateTexture(nil,"ARTWORK")
        row.affixIcon:SetWidth(16)
        row.affixIcon:SetHeight(16)

        row.affix = row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        row.affix:SetJustifyH("LEFT")

        table.insert(lootWindow.rows,row)
    end

    -- Bottom-right resize grip.
    local resize = CreateFrame("Button",nil,lootWindow)
    resize:SetWidth(22)
    resize:SetHeight(22)
    resize:SetPoint("BOTTOMRIGHT",-5,5)

    local resizeTex = resize:CreateTexture(nil,"OVERLAY")
    resizeTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeTex:SetAllPoints(resize)

    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    resize:SetScript("OnMouseDown",function(self,button)
        if button == "LeftButton" then
            lootWindow.isResizing = true
            lootWindow:StartSizing("BOTTOMRIGHT")
        end
    end)

    resize:SetScript("OnMouseUp",function(self,button)
        if button == "LeftButton" then
            lootWindow:StopMovingOrSizing()
            lootWindow.isResizing = nil

            EbonAffixAlertDB.lootWindow.width = lootWindow:GetWidth()
            EbonAffixAlertDB.lootWindow.height = lootWindow:GetHeight()
            RefreshLootWindow()
        end
    end)

    resize:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_LEFT")
        GameTooltip:AddLine("Resize Loot History")
        GameTooltip:AddLine("Drag the corner to resize",1,1,1)
        GameTooltip:Show()
    end)
    resize:SetScript("OnLeave",function() GameTooltip:Hide() end)

    lootWindow:SetScript("OnSizeChanged",function(self,width,height)
        if EbonAffixAlertDB and EbonAffixAlertDB.lootWindow then
            EbonAffixAlertDB.lootWindow.width = width
            EbonAffixAlertDB.lootWindow.height = height
        end
        RefreshLootWindow()
    end)

    lootWindow:SetScript("OnShow",function()
        lootWindow.eaaTransparent = EbonAffixAlertDB.lootWindow.transparent and true or false
        if lootWindow.transparentCheck then
            lootWindow.transparentCheck:SetChecked(lootWindow.eaaTransparent and 1 or nil)
        end
        ApplyEAAFrameSkin(lootWindow)
        ApplyLootHistoryTitleStyle()
        if lootWindow.historyInset then UpdateEAAInset(lootWindow.historyInset) end
        RefreshLootWindow()
    end)

    lootWindow.eaaTransparent = EbonAffixAlertDB.lootWindow.transparent and true or false
    if lootWindow.transparentCheck then
        lootWindow.transparentCheck:SetChecked(lootWindow.eaaTransparent and 1 or nil)
    end
    ApplyEAAFrameSkin(lootWindow)
    ApplyLootHistoryTitleStyle()
    if lootWindow.historyInset then UpdateEAAInset(lootWindow.historyInset) end

    if EbonAffixAlertDB.lootWindow.show then
        lootWindow:Show()
    else
        lootWindow:Hide()
    end
end

bagSnapshot = {}
recentAlerts = {}
    weaponProcDescriptions = {}
    weaponProcDescriptionsStale = true
local suppressBagAlertsUntil = 0
local pendingSnapshotRefresh = nil

local function CleanupRecentAlerts()
    local now = GetTime()
    local key, when
    for key, when in pairs(recentAlerts) do
        if now - when > 2 then
            recentAlerts[key] = nil
        end
    end
end


activeAlerts = {}
local alertPool = {}
local lastGeneralAlertSound = -100

local ALERT_LIFETIME = 8
local ALERT_FADE_START = 6.5
local ALERT_SPACING = 34
local ALERT_TOP_Y = -170
local MAX_VISIBLE_ALERTS = 8

local function AcquireAlertFrame()
    local frame = table.remove(alertPool)

    if not frame then
        frame = CreateFrame("Frame",nil,UIParent)
        frame:SetWidth(760)
        frame:SetHeight(32)
        frame:SetFrameStrata("HIGH")

        frame.text = frame:CreateFontString(nil,"OVERLAY","GameFontNormalHuge")
        frame.text:SetPoint("CENTER")
        frame.text:SetTextColor(1,0.15,0.15)
        frame.text:SetShadowOffset(1,-1)
    end

    frame:SetAlpha(1)
    frame:Show()
    return frame
end

local function ReleaseAlertFrame(frame)
    frame:Hide()
    frame:ClearAllPoints()
    frame:SetAlpha(1)
    frame.elapsed = nil
    frame.text:SetText("")
    table.insert(alertPool,frame)
end

local function RepositionActiveAlerts()
    local i, entry

    -- Newest alert is index 1 and remains at the top.
    -- Older alerts move down one row whenever a new alert arrives.
    for i,entry in ipairs(activeAlerts) do
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint(
            "TOP",
            UIParent,
            "TOP",
            0,
            ALERT_TOP_Y - ((i - 1) * ALERT_SPACING)
        )
    end
end

local function PlayGeneralAlertSound()
    local now = GetTime()

    -- Protect the standard Raid Warning sound from rapid repeat spam.
    -- Multiple alerts inside this 0.5 second window still display normally.
    if now - lastGeneralAlertSound < 0.5 then
        return
    end

    lastGeneralAlertSound = now

    local ok = pcall(PlaySoundFile,"Sound\\Interface\\RaidWarning.wav")
    if not ok then
        pcall(PlaySound,"RaidWarning")
    end
end

local function PlayWeaponAlertSound()
    -- Weapon alerts retain their distinct sound and play immediately.
    local ok = pcall(PlaySoundFile,"Sound\\Spells\\SimonGame_Visual_GameTick.wav")
    if not ok then
        PlayGeneralAlertSound()
    end
end

local function AddStackedAlert(text,isWeapon)
    -- Sound occurs immediately when the loot is detected, not after any
    -- previous on-screen alert has expired.
    if EbonAffixAlertDB.alertSound then
        if isWeapon then
            PlayWeaponAlertSound()
        else
            PlayGeneralAlertSound()
        end
    end

    if not EbonAffixAlertDB.announceToRaidWarning then
        return
    end

    local frame = AcquireAlertFrame()
    frame.text:SetText(text)

    local entry = {
        frame = frame,
        elapsed = 0,
        isWeapon = isWeapon and true or false
    }

    table.insert(activeAlerts,1,entry)

    -- Avoid an unbounded wall of text if an extreme loot burst occurs.
    if #activeAlerts > MAX_VISIBLE_ALERTS then
        local removed = table.remove(activeAlerts,#activeAlerts)
        ReleaseAlertFrame(removed.frame)
    end

    RepositionActiveAlerts()
end

local alertUpdateFrame = CreateFrame("Frame")
alertUpdateFrame:SetScript("OnUpdate",function(self,delta)
    if #activeAlerts == 0 then return end

    local changed = false
    local i = #activeAlerts

    while i >= 1 do
        local entry = activeAlerts[i]
        entry.elapsed = entry.elapsed + delta

        if entry.elapsed >= ALERT_LIFETIME then
            table.remove(activeAlerts,i)
            ReleaseAlertFrame(entry.frame)
            changed = true
        else
            if entry.elapsed > ALERT_FADE_START then
                local alpha = (ALERT_LIFETIME - entry.elapsed)
                    / (ALERT_LIFETIME - ALERT_FADE_START)

                if alpha < 0 then alpha = 0 end
                entry.frame:SetAlpha(alpha)
            else
                entry.frame:SetAlpha(1)
            end
        end

        i = i - 1
    end

    if changed then
        RepositionActiveAlerts()
    end
end)

local function RunTestAlert(isWeapon)
    local affixText

    if isWeapon then
        affixText = "Weapon Affix Test"
    else
        affixText = "General Affix Test"
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[EAA]|r Test alert: "..affixText)

    AddStackedAlert(
        "Tracked affix looted: "..affixText,
        isWeapon
    )
end

local function AlertForLink(link, source)
    if not link then return false end

    local itemName = ExtractDisplayedItemName(link)
    if not itemName then return false end

    local affixName,rank,affixType = FindTrackedAffix(itemName,link)
    if not affixName then return false end

    CleanupRecentAlerts()
    local alertKey = itemName
    local now = GetTime()
    if recentAlerts[alertKey] and now - recentAlerts[alertKey] < 2 then
        return false
    end
    recentAlerts[alertKey] = now

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff33ff99[EAA]|r Tracked affix looted: "
        .. link .. " |cffffff00("
        .. affixName .. (rank and (" "..rank) or "") .. ")|r"
    )

    AddLootHistoryEntry(link,itemName,affixName,rank)

    if EbonAffixAlertDB.announceToRaidWarning or EbonAffixAlertDB.alertSound then
        AddStackedAlert(
            "Tracked affix looted: "..affixName..(rank and (" "..rank) or ""),
            affixType == "Weapon"
        )
    end

    if EbonAffixAlertDB.debug then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff66ccff[EAA Debug]|r Alert source="..tostring(source)
        )
    end

    return true
end


-- Newly acquired weapons can enter the bags before WoW has finished building
-- their full tooltip. Keep a very small retry queue so proc-based Weapon affix
-- detection gets another chance once the "Chance on hit/strike" line exists.
local pendingWeaponRetries = {}
local WEAPON_RETRY_DELAYS = { 0.25, 0.75, 1.50 }

local function HasTrackedWeaponAffixes()
    local _, name
    for _,name in ipairs(weaponAffixes) do
        if EbonAffixAlertDB.tracked[WKey(name)] then
            return true
        end
    end
    return false
end

local function QueueWeaponAffixRetry(link)
    if not link or not EbonAffixAlertDB or not EbonAffixAlertDB.enabled then return end
    if not HasTrackedWeaponAffixes() then return end
    if not IsWeaponItemLink(link) then return end

    -- If this item already alerted via CHAT_MSG_LOOT, BAG_UPDATE may see the
    -- same acquisition a moment later. Do not create a redundant retry queue.
    local itemName = ExtractDisplayedItemName(link)
    if itemName then
        CleanupRecentAlerts()
        local when = recentAlerts[itemName]
        if when and GetTime() - when < 2 then
            return
        end
    end

    local entry = pendingWeaponRetries[link]
    if entry then
        -- Keep the existing schedule; one retry chain per exact item link is enough.
        return
    end

    pendingWeaponRetries[link] = {
        link = link,
        elapsed = 0,
        nextAttempt = 1
    }

    if EbonAffixAlertDB.debug then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff66ccff[EAA Debug]|r Weapon affix not identified immediately; "
            .. "queued tooltip retries for " .. tostring(link)
        )
    end
end

local weaponRetryFrame = CreateFrame("Frame")
weaponRetryFrame:SetScript("OnUpdate",function(self,delta)
    if not next(pendingWeaponRetries) then return end

    local link, entry
    for link,entry in pairs(pendingWeaponRetries) do
        entry.elapsed = entry.elapsed + delta

        local delay = WEAPON_RETRY_DELAYS[entry.nextAttempt]
        if delay and entry.elapsed >= delay then
            if EbonAffixAlertDB and EbonAffixAlertDB.debug then
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cff66ccff[EAA Debug]|r Weapon tooltip retry "
                    .. tostring(entry.nextAttempt) .. "/" .. tostring(#WEAPON_RETRY_DELAYS)
                    .. ": " .. tostring(link)
                )
            end

            local alerted = AlertForLink(link,"WEAPON_TOOLTIP_RETRY_" .. tostring(entry.nextAttempt))
            if alerted then
                pendingWeaponRetries[link] = nil
            else
                entry.nextAttempt = entry.nextAttempt + 1
                if not WEAPON_RETRY_DELAYS[entry.nextAttempt] then
                    if EbonAffixAlertDB and EbonAffixAlertDB.debug then
                        DEFAULT_CHAT_FRAME:AddMessage(
                            "|cff66ccff[EAA Debug]|r Weapon tooltip retries exhausted: "
                            .. tostring(link)
                        )
                    end
                    pendingWeaponRetries[link] = nil
                end
            end
        end
    end
end)

-- Snapshot total ownership across bags and equipped slots.
--
-- Do NOT key ownership by the entire rendered hyperlink. On some 3.3.5a
-- clients the same item can be returned with cosmetic/link-format differences
-- after a bag refresh. That makes an already-owned item look like a brand-new
-- key. Instead use the stable item-string payload through the unique-id field
-- and ignore trailing link/display metadata.
local function GetStableItemIdentity(link)
    if not link then return nil end

    local itemString = string.match(link,"item:([-%d:]+)")
    if not itemString then
        return tostring(link)
    end

    local fields = {}
    local value
    for value in string.gmatch(itemString,"([^:]+)") do
        table.insert(fields,value)
    end

    -- 3.3.5 item links are:
    -- itemId:enchant:gem1:gem2:gem3:gem4:suffix:uniqueId:level:...
    -- Keep through uniqueId. This preserves random-suffix/affix identity and
    -- distinguishes separate item instances, while ignoring trailing fields
    -- that can vary with client/link context.
    local keep = math.min(#fields,8)
    local parts = {}
    local i
    for i=1,keep do
        parts[i] = fields[i]
    end

    return table.concat(parts,":")
end

local function AddSnapshotItem(snapshot,links,link,count)
    if not link then return end

    local key = GetStableItemIdentity(link)
    if not key then return end

    snapshot[key] = (snapshot[key] or 0) + (count or 1)

    -- Keep one current hyperlink for tooltip scanning / user-facing alerts.
    if not links[key] then
        links[key] = link
    end
end

local function CaptureBagSnapshot()
    -- Track TOTAL quantity owned across bags + equipped slots.
    -- Looting increases the total; moving/equipping/unequipping does not.
    local snapshot = {}
    local links = {}
    local bag, slot

    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link then
                local _, count = GetContainerItemInfo(bag, slot)
                AddSnapshotItem(snapshot,links,link,count or 1)
            end
        end
    end

    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link then
            AddSnapshotItem(snapshot,links,link,1)
        end
    end

    return snapshot, links
end

local bagSnapshotLinks = {}

local function RefreshBagBaseline()
    local current, links = CaptureBagSnapshot()
    bagSnapshot = current
    bagSnapshotLinks = links
end

local function CheckBagChanges()
    local current, currentLinks = CaptureBagSnapshot()

    -- During login/teleport/world transitions, bag APIs can temporarily report
    -- an incomplete inventory and then repopulate it. Refresh the baseline but
    -- never treat those repopulated items as loot.
    if GetTime() < suppressBagAlertsUntil then
        bagSnapshot = current
        bagSnapshotLinks = currentLinks
        return
    end

    if not EbonAffixAlertDB.enabled then
        bagSnapshot = current
        bagSnapshotLinks = currentLinks
        return
    end

    local key, currentCount
    for key, currentCount in pairs(current) do
        local oldCount = bagSnapshot[key] or 0

        -- Only treat the item as newly acquired if the TOTAL quantity of this
        -- stable item identity increased. Moving/rearranging it leaves the
        -- total unchanged and therefore cannot trigger an alert.
        if currentCount > oldCount then
            local link = currentLinks[key]

            if EbonAffixAlertDB.debug then
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cff66ccff[EAA Debug]|r Total owned count increased: "
                    .. tostring(key)
                    .. " (" .. tostring(oldCount)
                    .. " -> " .. tostring(currentCount) .. ")"
                )
            end

            if link then
                local alerted = AlertForLink(link, "INVENTORY_COUNT_INCREASE")
                if not alerted then
                    QueueWeaponAffixRetry(link)
                end
            end
        end
    end

    bagSnapshot = current
    bagSnapshotLinks = currentLinks
end

-- BAG_UPDATE can fire once for the source bag and again for the destination
-- bag during a move/equip/mail transaction. Reading the inventory between those
-- events can produce a temporary lower count, followed by the original count.
-- Debounce the event stream so EAA compares only after the transaction settles.
local EAA_BAG_UPDATE_DEBOUNCE = 0.25
local bagUpdateDebounceFrame = CreateFrame("Frame")
local bagUpdatePending = false
local bagUpdateElapsed = 0

local function ScheduleBagChangeCheck()
    bagUpdatePending = true
    bagUpdateElapsed = 0
    bagUpdateDebounceFrame:Show()
end

bagUpdateDebounceFrame:SetScript("OnUpdate",function(self,delta)
    if not bagUpdatePending then
        self:Hide()
        return
    end

    bagUpdateElapsed = bagUpdateElapsed + delta
    if bagUpdateElapsed < EAA_BAG_UPDATE_DEBOUNCE then return end

    bagUpdatePending = false
    bagUpdateElapsed = 0
    self:Hide()
    CheckBagChanges()
end)
bagUpdateDebounceFrame:Hide()

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("BAG_UPDATE")

frame:SetScript("OnEvent",function(self,event,...)
    if event == "PLAYER_LOGIN" then
        EnsureDB()
        SetEAATheme(EbonAffixAlertDB.uiStyle or "Modern")

        -- Seed runtime cache from icons learned during earlier sessions.
        local savedName, savedTexture
        for savedName,savedTexture in pairs(EbonAffixAlertDB.affixIcons) do
            affixIconCache[savedName] = savedTexture
        end

        CreatePanel()
        CreateMinimapButton()
        CreateLootWindow()
        CreateInterfaceOptionsPanel()
        ApplyAffixIconsToRows()
        RequestEbonholdAffixIcons()
        RefreshBagBaseline()
        suppressBagAlertsUntil = GetTime() + 4

        EbonAffixAlertMainLoaded = true
        EAAStartUpdateTracker()

        local loginMessageFrame = CreateFrame("Frame")
        local elapsed = 0
        loginMessageFrame:SetScript("OnUpdate",function(self,delta)
            elapsed = elapsed + delta
            if elapsed >= 4 then
                self:SetScript("OnUpdate",nil)
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cff33ff99[EAA]|r "
                    .. (EbonAffixAlertDB.enabled and "|cff00ff00Enabled|r" or "|cffff5555Disabled|r")
                    .. " - Use |cffffff00/eaa|r to configure."
                )
            end
        end)

        if not EbonAffixAlertCharacterDB.firstRunShown then
            EbonAffixAlertCharacterDB.firstRunShown = true
            panel:Show()
        end
        return
    end

    if event == "SPELLS_CHANGED" then
        RefreshAffixIconsFromEbonhold()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        -- Suppress inventory-count alerts while the client rebuilds bag state
        -- after login, zoning or teleporting.
        suppressBagAlertsUntil = GetTime() + 4

        bagUpdatePending = false
        bagUpdateElapsed = 0
        bagUpdateDebounceFrame:Hide()

        if not pendingSnapshotRefresh then
            pendingSnapshotRefresh = CreateFrame("Frame")
        end

        local elapsed = 0
        pendingSnapshotRefresh:SetScript("OnUpdate",function(self,delta)
            elapsed = elapsed + delta
            if elapsed >= 2 then
                self:SetScript("OnUpdate",nil)
                RefreshBagBaseline()

                if EbonAffixAlertDB and EbonAffixAlertDB.debug then
                    DEFAULT_CHAT_FRAME:AddMessage(
                        "|cff66ccff[EAA Debug]|r Inventory baseline refreshed after world transition."
                    )
                end
            end
        end)
        return
    end

    if event == "CHAT_MSG_LOOT" then
        if not EbonAffixAlertDB or not EbonAffixAlertDB.enabled then return end

        local message,_,_,_,playerField = ...

        if EbonAffixAlertDB.debug then
            DEFAULT_CHAT_FRAME:AddMessage(
                "|cff66ccff[EAA Debug]|r CHAT_MSG_LOOT fired: "..tostring(message)
                .." playerField="..tostring(playerField)
            )
        end

        if not IsPlayerLoot(message,playerField) then return end

        local link = ExtractItemLink(message)
        if link then
            AlertForLink(link, "CHAT_MSG_LOOT")
        end
        return
    end

    if event == "BAG_UPDATE" then
        if EbonAffixAlertDB and EbonAffixAlertDB.debug then
            DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[EAA Debug]|r BAG_UPDATE fired; ownership check scheduled.")
        end
        ScheduleBagChangeCheck()
        return
    end
end)

CreateInterfaceOptionsPanel = function()
    interfaceOptionsPanel = CreateFrame("Frame","EbonAffixAlertInterfaceOptions",UIParent)
    interfaceOptionsPanel.name = "EbonAffixAlert"

    local scroll = CreateFrame(
        "ScrollFrame",
        "EbonAffixAlertInterfaceOptionsScroll",
        interfaceOptionsPanel,
        "UIPanelScrollFrameTemplate"
    )
    scroll:SetPoint("TOPLEFT",8,-8)
    scroll:SetPoint("BOTTOMRIGHT",-30,8)

    local content = CreateFrame("Frame","EbonAffixAlertInterfaceOptionsContent",scroll)
    content:SetWidth(390)
    content:SetHeight(1100)
    scroll:SetScrollChild(content)

    local title = content:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    title:SetPoint("TOPLEFT",18,-18)
    title:SetText("EbonAffixAlert")
    SetEAATextColor(title,EAA_THEME.title)

    local version = content:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    version:SetPoint("LEFT",title,"RIGHT",10,0)
    version:SetText("v" .. GetEAAVersion())
    SetEAATextColor(version,EAA_THEME.purple)

    local welcome = content:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    welcome:SetPoint("TOPLEFT",18,-52)
    welcome:SetWidth(330)
    welcome:SetJustifyH("LEFT")
    welcome:SetWordWrap(true)
    welcome:SetText(
        "Welcome to EbonAffixAlert - tracks Project Ebonhold affixes you care about "
        .. "and alerts you when matching gear is looted."
    )
    SetEAATextColor(welcome,EAA_THEME.text)

    local description = content:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    description:SetPoint("TOPLEFT",18,-104)
    description:SetWidth(330)
    description:SetJustifyH("LEFT")
    description:SetWordWrap(true)
    description:SetText(
        "Configure tracked General and Weapon affixes, alert behaviour, minimap controls "
        .. "and Loot History from the main EAA settings window."
    )
    SetEAATextColor(description,EAA_THEME.muted)

    local enable = CreateFrame("CheckButton",nil,content,"UICheckButtonTemplate")
    SkinEAACheckbox(enable)
    enable:SetWidth(24)
    enable:SetHeight(24)
    enable:SetPoint("TOPLEFT",18,-158)

    local enableText = enable:CreateFontString(nil,"OVERLAY","GameFontNormal")
    enableText:SetPoint("LEFT",enable,"RIGHT",2,0)
    enableText:SetText("Enable EbonAffixAlert")
    SetEAATextColor(enableText,EAA_THEME.text)

    enable:SetScript("OnClick",function(self)
        EbonAffixAlertDB.enabled = self:GetChecked() and true or false
        UpdateStatusText()
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cff33ff99[EAA]|r "
            .. (EbonAffixAlertDB.enabled and "|cff00ff00Enabled|r" or "|cffff5555Disabled|r")
        )
    end)
    interfaceOptionsPanel.enableCheck = enable

    local commandsTitle = content:CreateFontString(nil,"OVERLAY","GameFontNormal")
    commandsTitle:SetPoint("TOPLEFT",18,-204)
    commandsTitle:SetText("Commands")
    SetEAATextColor(commandsTitle,EAA_THEME.cyan)

    local commandsHint = content:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    commandsHint:SetPoint("TOPLEFT",18,-226)
    commandsHint:SetWidth(330)
    commandsHint:SetJustifyH("LEFT")
    commandsHint:SetWordWrap(true)
    commandsHint:SetText("Every EAA chat command is also available here:")
    SetEAATextColor(commandsHint,EAA_THEME.muted)

    local commands = {
        { label = "Open Settings", cmd = "", desc = "/eaa - open or close the main settings window." },
        { label = "General Alert", cmd = "alert", desc = "/eaa alert - test the normal tracked-affix alert." },
        { label = "Weapon Alert", cmd = "wepalert", desc = "/eaa wepAlert - test the weapon-affix alert." },
        { label = "Loot History", cmd = "loot", desc = "/eaa loot - show or hide the Loot History window." },
        { label = "Version", cmd = "version", desc = "/eaa version - print the installed EAA version." },
        { label = "Update Check", cmd = "updatecheck", desc = "Check the realm update channel again for a newer EAA release. 5-second cooldown.", updateCheck = true },
    }

    local cursorY = -260
    local _, entry

    for _,entry in ipairs(commands) do
        local button = CreateFrame("Button",nil,content,"UIPanelButtonTemplate")
        button:SetWidth(150)
        button:SetHeight(26)
        button:SetPoint("TOPLEFT",18,cursorY)
        button:SetText(entry.label)
        SkinEAAButton(button)
        button.command = entry.cmd
        button.isUpdateCheck = entry.updateCheck and true or false

        if button.isUpdateCheck then
            button:SetScript("OnClick",function(self)
                if not EAARequestManualUpdateCheck() then return end

                self:Disable()
                self.eaaCooldownRemaining = EAA_MANUAL_UPDATE_COOLDOWN
                self:SetText("Update Check (5s)")
                self:SetScript("OnUpdate",function(btn,elapsed)
                    btn.eaaCooldownRemaining = btn.eaaCooldownRemaining - elapsed
                    if btn.eaaCooldownRemaining <= 0 then
                        btn.eaaCooldownRemaining = nil
                        btn:SetScript("OnUpdate",nil)
                        btn:SetText("Update Check")
                        btn:Enable()
                        return
                    end

                    local seconds = math.ceil(btn.eaaCooldownRemaining)
                    btn:SetText("Update Check (" .. tostring(seconds) .. "s)")
                end)
            end)
        else
            button:SetScript("OnClick",function(self)
                EbonAffixAlert_HandleSlash(self.command)
            end)
        end

        local desc = content:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT",18,cursorY-30)
        desc:SetWidth(320)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        desc:SetText(entry.desc)

        cursorY = cursorY - 68
    end

    local supportTitle = content:CreateFontString(nil,"OVERLAY","GameFontNormal")
    supportTitle:SetPoint("TOPLEFT",18,cursorY-4)
    supportTitle:SetText("Support")
    SetEAATextColor(supportTitle,EAA_THEME.cyan)
    cursorY = cursorY - 34

    local exportButton = CreateFrame("Button",nil,content,"UIPanelButtonTemplate")
    exportButton:SetWidth(170)
    exportButton:SetHeight(26)
    exportButton:SetPoint("TOPLEFT",18,cursorY)
    exportButton:SetText("Export Tracked Config")
    SkinEAAButton(exportButton)
    exportButton:SetScript("OnClick",ShowTrackedConfigExport)

    local exportDesc = content:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    exportDesc:SetPoint("TOPLEFT",18,cursorY-30)
    exportDesc:SetWidth(320)
    exportDesc:SetJustifyH("LEFT")
    exportDesc:SetWordWrap(true)
    exportDesc:SetText("Creates selectable text showing exactly which affixes and ranks are tracked.")
    SetEAATextColor(exportDesc,EAA_THEME.muted)
    cursorY = cursorY - 76

    local diagnosticsTitle = content:CreateFontString(nil,"OVERLAY","GameFontNormal")
    diagnosticsTitle:SetPoint("TOPLEFT",18,cursorY-4)
    diagnosticsTitle:SetText("Diagnostics")
    SetEAATextColor(diagnosticsTitle,EAA_THEME.cyan)
    cursorY = cursorY - 30

    local diagnosticsHint = content:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    diagnosticsHint:SetPoint("TOPLEFT",18,cursorY)
    diagnosticsHint:SetWidth(330)
    diagnosticsHint:SetJustifyH("LEFT")
    diagnosticsHint:SetWordWrap(true)
    diagnosticsHint:SetText(
        "Troubleshooting and runtime information. These controls are non-destructive."
    )
    SetEAATextColor(diagnosticsHint,EAA_THEME.muted)
    cursorY = cursorY - 50

    local diagnostics = {
        { label = "Debug", cmd = "debug", desc = "/eaa debug - toggle detailed loot/event diagnostics." },
        { label = "Performance", cmd = "perf", desc = "/eaa perf - toggle 5-second memory/CPU/cache reporting." },
        { label = "Script Errors", cmd = "scripterrors", desc = "/eaa scriptErrors - toggle WoW Lua error popups." },
        { label = "Status", cmd = "status", desc = "/eaa status - print a one-time EAA health summary." },
        { label = "Rescan Icons", cmd = "rescanicons", desc = "/eaa rescanIcons - re-request Ebonhold affix/icon data." },
        { label = "Clear Cache", cmd = "clearcache", desc = "/eaa clearCache - clear EAA icon/runtime caches safely." },
        { label = "Bug Report", cmd = "bugreport", desc = "/eaa bugReport - open a selectable troubleshooting report to copy and share." },
    }

    local _, dentry
    for _,dentry in ipairs(diagnostics) do
        local button = CreateFrame("Button",nil,content,"UIPanelButtonTemplate")
        button:SetWidth(150)
        button:SetHeight(26)
        button:SetPoint("TOPLEFT",18,cursorY)
        button:SetText(dentry.label)
        SkinEAAButton(button)
        button.command = dentry.cmd
        button:SetScript("OnClick",function(self)
            EbonAffixAlert_HandleSlash(self.command)
        end)

        local desc = content:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT",18,cursorY-30)
        desc:SetWidth(320)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        desc:SetText(dentry.desc)

        cursorY = cursorY - 68
    end

    content:SetHeight(math.abs(cursorY) + 40)

    interfaceOptionsPanel:SetScript("OnShow",function()
        if EbonAffixAlertDB then
            enable:SetChecked(EbonAffixAlertDB.enabled and 1 or nil)
            version:SetText("v" .. GetEAAVersion())
        end
    end)

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(interfaceOptionsPanel)
    end
end

function EbonAffixAlert_HandleSlash(msg)
    msg = string.gsub(msg or "","^%s*(.-)%s*$","%1")

    if msg == "bugreport" or msg == "bug" then
        ShowBugReport()
        return
    elseif msg == "exportconfig" or msg == "export" then
        ShowTrackedConfigExport()
        return
    elseif msg == "weaponaffixes" or msg == "wepaffixes" or msg == "weaponexport" then
        ShowWeaponAffixDescriptionExport()
        return
    elseif msg == "version" or msg == "ver" then
        PrintEAAVersion()
        return
    elseif msg == "update" or msg == "updatecheck" then
        EAARequestManualUpdateCheck()
        return
    elseif msg == "updatestatus" then
        EAAPrintUpdateStatus()
        return
    elseif msg == "updatetest" or msg == "realmtest" then
        EAARunUpdateSelfTest()
        return
    elseif msg == "perf" then
        TogglePerfMonitor()
        return
    elseif msg == "scripterrors" then
        ToggleScriptErrors()
        return
    elseif msg == "status" or msg == "diag" then
        PrintEAAStatus()
        return
    elseif msg == "rescanicons" or msg == "icons" then
        RescanEbonholdIcons()
        return
    elseif msg == "clearcache" or msg == "cache" then
        ClearEAACache()
        return
    elseif msg == "loot" then
        EbonAffixAlertDB.lootWindow.show = not EbonAffixAlertDB.lootWindow.show
        if EbonAffixAlertDB.lootWindow.show then
            lootWindow:Show()
        else
            lootWindow:Hide()
        end
        if panel and panel.lootWindowCheck then
            panel.lootWindowCheck:SetChecked(EbonAffixAlertDB.lootWindow.show and 1 or nil)
        end
        return
    elseif msg == "alert" or msg == "test" then
        RunTestAlert(false)
        return
    elseif msg == "wepalert" then
        RunTestAlert(true)
        return
    elseif msg == "debug" then
        EbonAffixAlertDB.debug = not EbonAffixAlertDB.debug
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[EAA]|r Debug "
            .. (EbonAffixAlertDB.debug and "ON" or "OFF"))
        return
    elseif msg == "on" then
        EbonAffixAlertDB.enabled = true
        UpdateStatusText()
        if interfaceOptionsPanel and interfaceOptionsPanel.enableCheck then
            interfaceOptionsPanel.enableCheck:SetChecked(1)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[EAA]|r |cff00ff00Enabled|r.")
        return
    elseif msg == "off" then
        EbonAffixAlertDB.enabled = false
        UpdateStatusText()
        if interfaceOptionsPanel and interfaceOptionsPanel.enableCheck then
            interfaceOptionsPanel.enableCheck:SetChecked(nil)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[EAA]|r |cffff5555Disabled|r.")
        return
    end

    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end
