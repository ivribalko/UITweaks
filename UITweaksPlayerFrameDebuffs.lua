local addonName, addonTable = ...
local PlayerFrameDebuffs = {}

if addonTable then
    addonTable.PlayerFrameDebuffs = PlayerFrameDebuffs
end

local MAX_DEBUFFS = 3
local DEBUFF_SIZE = 18
local TEST_COLOR_DURATION = 2.1
local TEST_DEBUFF_TYPES = { "Magic", "Curse", "Disease", "Poison", "Bleed" }

local function getPlayerHealthBar()
    local content = _G.PlayerFrame and _G.PlayerFrame.PlayerFrameContent
    local main = content and content.PlayerFrameContentMain
    local healthBars = main and main.HealthBarsContainer
    return healthBars and healthBars.HealthBar
end

local function anchorToPlayerFrameContent(frame, healthBar)
    local main = _G.PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
    local playerName = _G.PlayerName
    local manaBar = main.ManaBarArea and main.ManaBarArea.ManaBar

    frame:ClearAllPoints()
    if playerName and manaBar then
        frame:SetPoint("TOPLEFT", playerName, "TOPLEFT", -4, 0)
        frame:SetPoint("BOTTOMRIGHT", manaBar, "BOTTOMRIGHT")
    else
        frame:SetAllPoints(healthBar)
    end
end

local function createVisualOverlay(healthBar, frameLevel)
    local overlay = CreateFrame("Frame", nil, _G.PlayerFrame)
    anchorToPlayerFrameContent(overlay, healthBar)
    overlay:SetFrameLevel(frameLevel)

    overlay.Background = overlay:CreateTexture(nil, "BACKGROUND")
    overlay.Background:SetAllPoints()

    overlay.Gradient = overlay:CreateTexture(nil, "ARTWORK")
    overlay.Gradient:SetAtlas("_RaidFrame-Dispel-Highlight-Horizontal")
    overlay.Gradient:SetAllPoints()
    overlay.Gradient:SetBlendMode("ADD")

    overlay.Border = overlay:CreateTexture(nil, "OVERLAY")
    overlay.Border:SetAtlas("RaidFrame-DispelHighlight")
    overlay.Border:SetAllPoints()

    overlay.Label = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    overlay.Label:SetPoint("CENTER")
    overlay.Label:SetShadowOffset(1, -1)
    overlay:Hide()
    return overlay
end

local function setOverlayAppearance(overlay, label, debuffType)
    local color = AuraUtil.GetAuraBorderColor(debuffType)
    local red, green, blue = color:GetRGB()
    overlay.Background:SetColorTexture(red, green, blue, 0.45)
    overlay.Gradient:SetVertexColor(red, green, blue, 1)
    overlay.Border:SetVertexColor(red, green, blue, 1)
    overlay.Label:SetText(label)
    overlay:Show()
end

function PlayerFrameDebuffs.UpdateVisibility(self)
    local shown = self.db.profile.showRaidFrameDebuffsOnPlayerFrame
    if self.playerFrameRaidDebuffsContainer then
        self.playerFrameRaidDebuffsContainer:SetShown(shown)
    end
end

function PlayerFrameDebuffs.TestColors(self)
    local overlay = self.playerFrameDebuffTestOverlay
    if not overlay then return end

    self.playerFrameDebuffTestGeneration = (self.playerFrameDebuffTestGeneration or 0) + 1
    local generation = self.playerFrameDebuffTestGeneration

    local function showColor(index)
        if generation ~= self.playerFrameDebuffTestGeneration then return end
        local debuffType = TEST_DEBUFF_TYPES[index]
        if not debuffType then
            overlay:Hide()
            return
        end

        setOverlayAppearance(overlay, debuffType, debuffType)
        C_Timer.After(TEST_COLOR_DURATION, function()
            showColor(index + 1)
        end)
    end

    showColor(1)
end

function PlayerFrameDebuffs.Apply(self)
    if self.playerFrameRaidDebuffsContainer then
        PlayerFrameDebuffs.UpdateVisibility(self)
        return
    end

    local playerFrame = _G.PlayerFrame
    local healthBar = getPlayerHealthBar()
    if not playerFrame or not healthBar or not C_UnitAuras or not C_UnitAuras.AddPrivateAuraAnchor then return end

    local container = CreateFrame("Frame", "UITweaksPlayerFrameRaidDebuffs", playerFrame)
    anchorToPlayerFrameContent(container, healthBar)
    container:SetFrameLevel(healthBar:GetFrameLevel() + 10)
    container:SetAttribute("max-buffs", 0)
    container:SetAttribute("max-debuffs", MAX_DEBUFFS)
    container:SetAttribute("max-dispel-debuffs", 1)
    container:SetAttribute("aura-organization-type", Enum.RaidAuraOrganizationType.Legacy)
    container:SetAttribute("always-hide-duration", true)
    container:SetAttribute("set-aura-size-to-icon-size", true)
    container:SetAttribute("display-larger-role-specific-debuffs", true)
    container:SetAttribute("dispel-indicator-overlay-type", Enum.RaidDispelOverlayType.UseDebuffColor)
    container:SetAttribute("dispel-indicator-overlay-animation", true)
    container:SetAttribute("show-big-defensive", false)
    container:SetAttribute("big-defensive-size", DEBUFF_SIZE)
    container:SetAttribute("power-bar-used-height", 0)
    container:SetAttribute("group-type", CompactRaidGroupTypeEnum.Party)
    container:SetAttribute("display-only-dispellable-debuffs", false)
    container:SetAttribute("ignore-buffs", true)
    container:SetAttribute("ignore-debuffs", false)
    container:SetAttribute("ignore-dispel-debuffs", false)
    container:SetAttribute("dispel-indicator-option", Enum.RaidDispelDisplayType.DisplayAll)
    container:SetAttribute("debuff-size", DEBUFF_SIZE)
    container:SetAttribute("buff-size", DEBUFF_SIZE)
    container:SetAttribute("debuff-border-scale", 1)
    container:SetAttribute("buff-border-scale", 1)

    local iconAnchor = {
        point = "BOTTOMLEFT",
        relativeTo = container,
        relativePoint = "BOTTOMLEFT",
        offsetX = 0,
        offsetY = 0,
    }
    container.UITweaksPrivateAuraAnchorID = C_UnitAuras.AddPrivateAuraAnchor({
        unitToken = "player",
        auraIndex = 1,
        parent = container,
        showCooldownFrame = true,
        showCooldownEdge = false,
        showCountdownNumbers = false,
        showDispelIcon = false,
        isContainer = true,
        iconInfo = {
            iconAnchor = iconAnchor,
            iconWidth = DEBUFF_SIZE,
            iconHeight = DEBUFF_SIZE,
            borderScale = 1,
        },
        durationAnchor = nil,
    })

    self.playerFrameRaidDebuffsContainer = container
    self.playerFrameDebuffTestOverlay = createVisualOverlay(healthBar, healthBar:GetFrameLevel() + 240)
    PlayerFrameDebuffs.UpdateVisibility(self)
end

if type(require) == "function" then
    return PlayerFrameDebuffs
end
