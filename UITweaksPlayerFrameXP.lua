local addonName, addonTable = ...
local PlayerFrameXP = {}

if addonTable then
    addonTable.PlayerFrameXP = PlayerFrameXP
end

local XP_TEXT_WIDTH = 30
local XP_AND_LEVEL_TEXT_WIDTH = 42
local NAME_TO_XP_SPACING = 4

local function shouldShowXPProgress()
    return _G.PlayerFrame.unit == "player"
        and GameRulesUtil.CanShowExperienceBar()
        and UnitXPMax("player") > 0
end

function PlayerFrameXP.Update(self)
    local xpText = self.playerFrameXPText
    if not xpText then return end

    if not shouldShowXPProgress() then
        xpText:Hide()
        _G.PlayerName:SetWidth(self.playerFrameXPOriginalNameWidth)
        return
    end

    local currentXP = UnitXP("player")
    local maximumXP = UnitXPMax("player")
    local percentage = math.floor((currentXP / maximumXP) * 100)
    if _G.PlayerLevelText:IsShown() then
        xpText:SetWidth(XP_TEXT_WIDTH)
        xpText:SetFormattedText("%d%%", percentage)
        _G.PlayerName:SetWidth(self.playerFrameXPNameWidth)
    else
        xpText:SetWidth(XP_AND_LEVEL_TEXT_WIDTH)
        xpText:SetFormattedText("%d%% %d", percentage, UnitLevel("player"))
        _G.PlayerName:SetWidth(self.playerFrameXPNameAndLevelWidth)
    end
    xpText:Show()
end

function PlayerFrameXP.Apply(self)
    if self.playerFrameXPText or not self.db.profile.showXPProgressOnPlayerFrame then return end

    local playerFrame = _G.PlayerFrame
    local playerName = _G.PlayerName
    local playerLevel = _G.PlayerLevelText
    local main = playerFrame.PlayerFrameContent.PlayerFrameContentMain

    local xpText = main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall", 1)
    xpText:SetWidth(XP_TEXT_WIDTH)
    xpText:SetHeight(12)
    xpText:SetPoint("RIGHT", playerLevel, "LEFT", -NAME_TO_XP_SPACING, 0)
    xpText:SetJustifyH("RIGHT")
    xpText:SetTextColor(1, 0.82, 0)
    xpText:Hide()

    self.playerFrameXPText = xpText
    self.playerFrameXPOriginalNameWidth = playerName:GetWidth()
    self.playerFrameXPNameWidth = math.max(
        self.playerFrameXPOriginalNameWidth - XP_TEXT_WIDTH - NAME_TO_XP_SPACING,
        20
    )
    self.playerFrameXPNameAndLevelWidth = math.max(
        self.playerFrameXPOriginalNameWidth - XP_AND_LEVEL_TEXT_WIDTH - NAME_TO_XP_SPACING,
        20
    )

    local eventFrame = CreateFrame("Frame", nil, playerFrame)
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_LEVEL_CHANGED")
    eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
    eventFrame:SetScript("OnEvent", function()
        PlayerFrameXP.Update(self)
    end)
    self.playerFrameXPEventFrame = eventFrame

    hooksecurefunc("PlayerFrame_UpdateRolesAssigned", function()
        PlayerFrameXP.Update(self)
    end)
    hooksecurefunc("PlayerFrame_ToPlayerArt", function()
        PlayerFrameXP.Update(self)
    end)
    hooksecurefunc("PlayerFrame_ToVehicleArt", function()
        PlayerFrameXP.Update(self)
    end)

    PlayerFrameXP.Update(self)
end

if type(require) == "function" then
    return PlayerFrameXP
end
