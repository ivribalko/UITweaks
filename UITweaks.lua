local addonName, addonTable = ...
local UITweaks = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
-- Skyriding uses Bonus Bar 5, which maps to action slots 121-132.
local SKYRIDING_BAR_SLOT_START = 121
local SKYRIDING_BAR_SLOT_COUNT = 12
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS or 10
local ABANDON_QUEST_MACRO_NAME = "Quest Abandon"
local NEXT_QUEST_MACRO_NAME = "Quest Next"
local PREVIOUS_QUEST_MACRO_NAME = "Quest Prev"
local NEXT_QUEST_MACRO_ICON = "INV_Misc_Note_01"
local ABANDON_QUEST_MACRO_BODY = "/uitabandonquest"
local NEXT_QUEST_MACRO_BODY = "/uitnextquest"
local PREVIOUS_QUEST_MACRO_BODY = "/uitprevquest"
local OBJECTIVE_TRACKER_FADE_DURATION = 0.25
local MINIMAP_SPEED_ZOOM_UPDATE_INTERVAL = 0.5
local MINIMAP_ZOOM_EASING_DURATION = 0.45
local SPEECH_BUBBLE_CVARS = {
    "chatBubbles",
    "chatBubblesParty",
    "chatBubblesRaid",
}

_G.UITweaks_OnAddonCompartmentClick = function()
    UITweaks:OpenOptionsPanel()
end

function UITweaks:OnInitialize()
    local options = type(require) == "function" and require("UITweaksOptions") or addonTable.Options
    self.consumables = type(require) == "function" and require("UITweaksConsumables") or addonTable.Consumables
    self.cooldownOverlay = type(require) == "function" and require("UITweaksCooldownOverlay") or addonTable.CooldownOverlay
    self.immersion = type(require) == "function" and require("UITweaksImmersion") or addonTable.Immersion
    self.consolePortBags = type(require) == "function" and require("UITweaksConsolePortBags") or addonTable.ConsolePortBags
    self.consolePortMovement = type(require) == "function" and require("UITweaksConsolePortMovement") or addonTable.ConsolePortMovement
    self.consolePortMenu = type(require) == "function" and require("UITweaksConsolePortMenu") or addonTable.ConsolePortMenu
    self.consolePortItemMenu = type(require) == "function" and require("UITweaksConsolePortItemMenu") or addonTable.ConsolePortItemMenu
    self.debug = type(require) == "function" and require("UITweaksDebug") or addonTable.Debug
    self.db = LibStub("AceDB-3.0"):New("UITweaksDB", options.defaults, true)
    options.OnInitialize(self)
end

function UITweaks:OnEnable()
    self:CreateMinimapButton()
    self:StartMinimapSpeedZoomMonitor()
    self:RegisterChatCommand("uitabandonquest", "HandleAbandonQuestSlashCommand")
    self:RegisterChatCommand("uitnextquest", "HandleNextQuestSlashCommand")
    self:RegisterChatCommand("uitprevquest", "HandlePreviousQuestSlashCommand")
    self:ApplyQuestMarkerDistanceSetting()
    self:ApplyChatFontSize()
    self:ApplyChatBackgroundAlpha()
    self:ApplySpeechBubbleVisibility()
    self:ApplyPartyAndRaidFrameScale()
    self:HookHelpTipFrames()
    self:ApplyTargetFrameAurasHide()
    self.consumables.ApplyInventoryConsumableHighlights(self)
    self.cooldownOverlay.Apply(self)
    self.immersion.Apply(self)
    self.consolePortBags.Apply(self)
    self.consolePortMovement.Apply(self)
    self.consolePortMenu.Apply(self)
    self.consolePortItemMenu.Apply(self)
    self.debug.OnEnable(self)
    self:ApplyVisibilityState()
    self:UpdateObjectiveTrackerState()
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_LOGOUT")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("MAIL_SHOW")
    self:RegisterEvent("BAG_OPEN")
    self:RegisterEvent("BAG_CLOSED")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("BAG_UPDATE_DELAYED")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("NAVIGATION_FRAME_CREATED")
    self:RegisterEvent("WEAPON_ENCHANT_CHANGED")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    if self.db.profile.showOptionsOnReload then
        C_Timer.After(1, function() self:OpenOptionsPanel() end)
    end
end

function UITweaks:SerializeBlockedActionEventArg(value)
    return self.debug.SerializeBlockedActionEventArg(value)
end

function UITweaks:AddBlockedActionEventDetail(eventName, sourceAddonName, ...)
    return self.debug.AddBlockedActionEventDetail(self, eventName, sourceAddonName, ...)
end

function UITweaks:GetBlockedActionEventDetailsText()
    return self.debug.GetBlockedActionEventDetailsText(self)
end

function UITweaks:GetBlockedActionDebugInfo()
    return self.debug.GetBlockedActionDebugInfo(self)
end

function UITweaks:EnsureBlockedActionDebugCopyFrame()
    return self.debug.EnsureBlockedActionDebugCopyFrame(self)
end

function UITweaks:ShowBlockedActionDebugCopyDialog()
    return self.debug.ShowBlockedActionDebugCopyDialog(self)
end

function UITweaks:EnsureBlockedActionCounterFrame()
    return self.debug.EnsureBlockedActionCounterFrame(self)
end

function UITweaks:UpdateBlockedActionCounterAnchor()
    return self.debug.UpdateBlockedActionCounterAnchor(self)
end

function UITweaks:UpdateBlockedActionCounterText()
    return self.debug.UpdateBlockedActionCounterText(self)
end

function UITweaks:UpdateBlockedActionEventTracking()
    return self.debug.UpdateBlockedActionEventTracking(self)
end

function UITweaks:UpdateBlockedActionCounterTracking()
    return self.debug.UpdateBlockedActionCounterTracking(self)
end

function UITweaks:EnsureAddonCpuUsageFrame()
    return self.debug.EnsureAddonCpuUsageFrame(self)
end

function UITweaks:UpdateAddonCpuUsageAnchor()
    return self.debug.UpdateAddonCpuUsageAnchor(self)
end

function UITweaks:UpdateAddonCpuUsageText()
    return self.debug.UpdateAddonCpuUsageText(self)
end

function UITweaks:UpdateAddonCpuUsageTracking()
    return self.debug.UpdateAddonCpuUsageTracking(self)
end

function UITweaks:EnsureTaintLogButtonFrame()
    return self.debug.EnsureTaintLogButtonFrame(self)
end

function UITweaks:UpdateTaintLogButtonAnchor()
    return self.debug.UpdateTaintLogButtonAnchor(self)
end

function UITweaks:UpdateTaintLogButtonText()
    return self.debug.UpdateTaintLogButtonText(self)
end

function UITweaks:UpdateTaintLogButtonTracking()
    return self.debug.UpdateTaintLogButtonTracking(self)
end

function UITweaks:HandleBlockedActionEvent(eventName, sourceAddonName, ...)
    return self.debug.HandleBlockedActionEvent(self, eventName, sourceAddonName, ...)
end

function UITweaks:ADDON_ACTION_BLOCKED(_, sourceAddonName, ...)
    return self.debug.ADDON_ACTION_BLOCKED(self, _, sourceAddonName, ...)
end

function UITweaks:ADDON_ACTION_FORBIDDEN(_, sourceAddonName, ...)
    return self.debug.ADDON_ACTION_FORBIDDEN(self, _, sourceAddonName, ...)
end

function UITweaks:NAVIGATION_FRAME_CREATED()
    self:EnsureAlwaysShowQuestDistanceHook()
end

function UITweaks:ADDON_LOADED(_, addonName)
    if addonName == "Blizzard_HelpTip" then
        self:HookHelpTipFrames()
    elseif addonName == "Blizzard_CompactRaidFrames" then
        self:UpdateCompactRaidFrameManagerVisibility()
        self:ApplyPartyAndRaidFrameScale()
    elseif addonName == "Blizzard_GroupLootHistory" then
        self:UpdateGroupLootHistoryVisibility()
    elseif addonName == "Blizzard_ActionBarController" or addonName == "Blizzard_ActionBar" then
        self:UpdateStanceButtonsVisibility()
    elseif addonName == "Blizzard_ObjectiveTracker" then
        self:UpdateObjectiveTrackerState()
    elseif addonName == "Blizzard_TotemBar" then
        self:UpdateTotemFrameVisibility()
    elseif addonName == "Blizzard_CooldownViewer" or addonName == "ConsolePort_Bar" then
        self.cooldownOverlay.Apply(self)
    elseif addonName == "Immersion" then
        self.immersion.Apply(self)
    elseif addonName == "ConsolePort_Menu" or addonName == "Blizzard_Menu" then
        self.consolePortMenu.Apply(self)
    elseif addonName == "ConsolePort_Cursor" then
        self.consolePortBags.Apply(self)
    elseif addonName == "ConsolePort"
        or addonName == "ConsolePort_ActionBar"
        or addonName == "ConsolePortActionBar"
        or addonName == "ConsolePortGroupCrossbar"
        or addonName == "ConsolePort_GroupCrossbar"
    then
        self:UpdateConsolePortTempAbilityFrameVisibility()
        self:UpdateConsolePortCrosshairVisibility()
        self.consolePortMovement.Apply(self)
        self.consolePortItemMenu.Apply(self)
    end
end

function UITweaks:PLAYER_REGEN_DISABLED()
    if self:ShouldFadeObjectiveTracker() then
        self:FadeOutObjectiveTrackerIfNeeded()
    end
    self:UpdatePlayerAndTargetFrameOpacity(true)
    if self.minimapSpeedZoomTicker then self:UpdateMinimapZoomForPlayerSpeed() end
end

function UITweaks:PLAYER_REGEN_ENABLED()
    self:UpdatePlayerAndTargetFrameOpacity()
    if self.minimapSpeedZoomTicker then self:UpdateMinimapZoomForPlayerSpeed() end
    if self:ShouldFadeObjectiveTracker() then self:FadeInObjectiveTrackerIfNeeded(true) end
    if self.partyAndRaidFrameScalePending then self:ApplyPartyAndRaidFrameScale() end
    self.consolePortMenu.Apply(self)
    self.consumables.RequestInventoryConsumableRefresh(self, true)
end

function UITweaks:PLAYER_ENTERING_WORLD()
    self:ApplyVisibilityState()
    self:ApplyPartyAndRaidFrameScale()
    self:UpdateObjectiveTrackerState()
    if self:ShouldFadeObjectiveTracker() and not InCombatLockdown() then
        self:FadeInObjectiveTrackerIfNeeded(true)
    end
    self.consumables.RequestInventoryConsumableRefresh(self, true)
    if self.db.profile.consolePortBarSharing then
        self:RestoreConsolePortActionBarProfile()
    end
    self.skyridingBarActive = self:IsSkyridingBarActive()
    if self.db.profile.skyridingBarSharing then
        C_Timer.After(2, function() self:RestoreSkyridingBarLayout() end)
        self:StartSkyridingBarMonitor()
    end
    C_Timer.After(0.5, function() self.consumables.RequestInventoryConsumableRefresh(self, true) end)
end

function UITweaks:EDIT_MODE_LAYOUTS_UPDATED()
    self:ApplyPartyAndRaidFrameScale()
end

function UITweaks:ZONE_CHANGED_NEW_AREA()
    self:UpdateObjectiveTrackerState()
end

function UITweaks:BAG_UPDATE_DELAYED()
    self.consumables.RequestInventoryConsumableRefresh(self, true)
end

function UITweaks:BAG_OPEN()
    self.consolePortBags.Apply(self)
    C_Timer.After(0, function() self.consolePortBags.Apply(self) end)
    self.consumables.RequestInventoryConsumableRefresh(self, true)
end

function UITweaks:BAG_CLOSED()
    self.consumables.RequestInventoryConsumableRefresh(self, true)
end

function UITweaks:FocusMailboxOpenAllButton(attemptsRemaining)
    if not self.db.profile.focusMailboxOpenAllButton then return end

    local openAllButton = _G.OpenAllMail
    if openAllButton and openAllButton:IsShown() then
        -- Let ConsolePort's own mailbox scan choose this button, then reassert the
        -- focus after its deferred frame-stack updates have finished.
        openAllButton:SetAttribute("nodepriority", 1)

        local consolePort = _G.ConsolePort
        if consolePort and consolePort.SetCursorNodeIfActive then
            consolePort:SetCursorNodeIfActive(openAllButton)
        end
    end

    if attemptsRemaining > 1 then
        C_Timer.After(0, function()
            UITweaks:FocusMailboxOpenAllButton(attemptsRemaining - 1)
        end)
    end
end

function UITweaks:MAIL_SHOW()
    self:FocusMailboxOpenAllButton(4)
end

function UITweaks:PLAYER_EQUIPMENT_CHANGED()
    self.consumables.RequestInventoryConsumableRefresh(self, true)
end

function UITweaks:HandleNextQuestSlashCommand()
    self:SelectNextTrackedQuest()
end

function UITweaks:HandleAbandonQuestSlashCommand()
    self:AbandonSelectedTrackedQuest()
end

function UITweaks:HandlePreviousQuestSlashCommand()
    self:SelectPreviousTrackedQuest()
end

function UITweaks:PLAYER_LOGOUT()
    if self.db.profile.consolePortBarSharing then
        self:SaveConsolePortActionBarProfile()
    end
end

function UITweaks:PLAYER_TARGET_CHANGED()
    self:UpdatePlayerAndTargetFrameOpacity()
end

function UITweaks:UNIT_AURA(_, unit)
    if unit == "player" then
        self.consumables.RequestInventoryConsumableRefresh(self)
    end
end

function UITweaks:WEAPON_ENCHANT_CHANGED()
    self.consumables.RequestInventoryConsumableRefresh(self, true)
end

local function getChatFrames()
    local frames = {}
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]
        if frame then frames[#frames + 1] = frame end
    end
    return frames
end

local function getMainChatFrame()
    return _G.DEFAULT_CHAT_FRAME or _G["ChatFrame1"]
end

local function isCursorInsideFrame(frame)
    if not frame or not frame.IsVisible or not frame:IsVisible() then return false end
    if not frame.IsMouseOver then return false end
    return frame:IsMouseOver()
end

local function shouldAutoHideChatControlButtons(self)
    return self.db.profile.hideChatMenuButton
        or self.db.profile.hideChatChannelsButton
        or self.db.profile.hideSocialButton
end

function UITweaks:AreChatControlButtonsHovered()
    local frame = getMainChatFrame()
    if frame and isCursorInsideFrame(frame.buttonFrame) then
        return true
    end
    return isCursorInsideFrame(_G.ChatFrameMenuButton)
        or isCursorInsideFrame(_G.ChatFrameChannelButton)
        or isCursorInsideFrame(_G.QuickJoinToastButton)
end

function UITweaks:SetChatControlButtonsHoverPolling(enabled)
    if self.chatControlButtonsHoverTicker then
        self.chatControlButtonsHoverTicker:Cancel()
        self.chatControlButtonsHoverTicker = nil
    end
    self.chatControlButtonsHovered = enabled and self:AreChatControlButtonsHovered() or nil
    if not enabled then return end
    self.chatControlButtonsHoverTicker = C_Timer.NewTicker(0.1, function()
        local isHovered = UITweaks:AreChatControlButtonsHovered()
        if UITweaks.chatControlButtonsHovered ~= isHovered then
            UITweaks.chatControlButtonsHovered = isHovered
            UITweaks:UpdateChatControlButtonsVisibility()
        end
    end)
end

local function updateChatControlButtonVisibility(self, button, profileKey)
    if not button then return end
    if self.db.profile[profileKey] then
        if not button.UITweaksHooked then
            button:HookScript("OnShow", function()
                UITweaks:UpdateChatControlButtonsVisibility()
            end)
            button.UITweaksHooked = true
        end
        if self.chatControlButtonsHovered then
            button:Show()
        else
            button:Hide()
        end
    end
end

local function updateSocialButtonVisibility(self, button)
    if not button then return end
    if self.db.profile.hideSocialButton then
        if not button.UITweaksHooked then
            button:HookScript("OnShow", function()
                UITweaks:UpdateChatControlButtonsVisibility()
            end)
            button.UITweaksHooked = true
        end
        if self.chatControlButtonsHovered then
            button:SetAlpha(1)
            if button.EnableMouse then button:EnableMouse(true) end
        else
            -- Keep the frame shown so its associated toasts can still anchor and update.
            if button.Show then button:Show() end
            button:SetAlpha(0)
            if button.EnableMouse then button:EnableMouse(false) end
        end
    end
end

function UITweaks:ApplyChatFontSize()
    local frames = getChatFrames()
    if self.db.profile.chatFontOverrideEnabled then
        local size = self.db.profile.chatFontSize
        for _, frame in ipairs(frames) do
            if frame.SetFont then
                local font = frame.GetFont and select(1, frame:GetFont())
                local flags = frame.GetFont and select(3, frame:GetFont())
                if font then frame:SetFont(font, size, flags) end
            end
        end
    end
end

function UITweaks:ApplyChatBackgroundAlpha()
    if not SetChatWindowAlpha then return end
    if self.db.profile.transparentChatBackground then
        for i = 1, NUM_CHAT_WINDOWS do
            SetChatWindowAlpha(i, 0)
        end
    elseif GetChatWindowInfo then
        for i = 1, NUM_CHAT_WINDOWS do
            local _, _, _, _, _, alpha = GetChatWindowInfo(i)
            if alpha ~= nil then
                SetChatWindowAlpha(i, alpha <= 1 and alpha * 100 or alpha)
            end
        end
    end
end

function UITweaks:ApplySpeechBubbleVisibility()
    local savedValues = self.db.global.speechBubbleCVarValues
    if self.db.profile.hideAllSpeechBubbles then
        if not savedValues then
            savedValues = {}
            for _, cvarName in ipairs(SPEECH_BUBBLE_CVARS) do
                savedValues[cvarName] = GetCVar(cvarName)
            end
            self.db.global.speechBubbleCVarValues = savedValues
        end
        for _, cvarName in ipairs(SPEECH_BUBBLE_CVARS) do
            SetCVar(cvarName, "0")
        end
    elseif savedValues then
        for _, cvarName in ipairs(SPEECH_BUBBLE_CVARS) do
            local value = savedValues[cvarName]
            if value ~= nil then SetCVar(cvarName, value) end
        end
        self.db.global.speechBubbleCVarValues = nil
    end
end

function UITweaks:ApplyQuestMarkerDistanceSetting()
    self:EnsureAlwaysShowQuestDistanceHook()
    if self.db.profile.alwaysShowQuestMarkerDistance then
        self:ForceQuestDistanceText(rawget(_G, "SuperTrackedFrame"))
    end
end

local function cacheDistanceTextPoints(navFrame)
    if navFrame.uitOriginalDistanceTextPoints then return end
    local distanceText = navFrame.DistanceText
    local points = {}
    local numPoints = distanceText:GetNumPoints() or 0
    for index = 1, numPoints do
        local point, relativeTo, relativePoint, xOfs, yOfs = distanceText:GetPoint(index)
        points[index] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs,
        }
    end
    navFrame.uitOriginalDistanceTextPoints = points
end

local function restoreDistanceTextPoints(navFrame)
    local points = navFrame.uitOriginalDistanceTextPoints
    if not points then return end

    local distanceText = navFrame.DistanceText
    distanceText:ClearAllPoints()
    for _, pointData in ipairs(points) do
        distanceText:SetPoint(pointData.point, pointData.relativeTo, pointData.relativePoint, pointData.xOfs, pointData.yOfs)
    end
end

function UITweaks:UpdateQuestDistanceTextAnchor(navFrame)
    if not navFrame or not navFrame.DistanceText then return end

    cacheDistanceTextPoints(navFrame)

    local shouldMoveUp = false
    if navFrame.isClamped then
        local _, markerY = navFrame:GetCenter()
        local screenHalfY = (UIParent and UIParent:GetHeight() or 0) * 0.5
        shouldMoveUp = markerY and markerY < screenHalfY
    end

    if shouldMoveUp then
        if not navFrame.uitDistanceTextMovedUp then
            navFrame.DistanceText:ClearAllPoints()
            navFrame.DistanceText:SetPoint("BOTTOM", navFrame, "TOP", 0, -30)
            navFrame.uitDistanceTextMovedUp = true
        end
    elseif navFrame.uitDistanceTextMovedUp then
        restoreDistanceTextPoints(navFrame)
        navFrame.uitDistanceTextMovedUp = false
    end
end

function UITweaks:ForceQuestDistanceText(navFrame)
    if not self.db.profile.alwaysShowQuestMarkerDistance then return end
    if not navFrame or not navFrame.DistanceText then return end
    if not (C_Navigation and C_Navigation.GetDistance) then return end

    self:UpdateQuestDistanceTextAnchor(navFrame)

    local distance = math.floor(C_Navigation.GetDistance() + 0.5)
    local displayDistance = distance
    if AbbreviateNumbers and distance >= 1000 then
        displayDistance = AbbreviateNumbers(distance)
    end

    local text = tostring(displayDistance)
    if IN_GAME_NAVIGATION_RANGE then
        local ok, formatted = pcall(string.format, IN_GAME_NAVIGATION_RANGE, text)
        if ok then text = formatted end
    end

    navFrame.DistanceText:SetText(text)
    navFrame.DistanceText:SetShown(true)
end

function UITweaks:EnsureAlwaysShowQuestDistanceHook()
    local superTrackedFrame = rawget(_G, "SuperTrackedFrame")
    if superTrackedFrame and not self.alwaysShowQuestDistanceFrameHooked and superTrackedFrame.HookScript then
        superTrackedFrame:HookScript("OnUpdate", function(navFrame)
            UITweaks:ForceQuestDistanceText(navFrame)
        end)
        self.alwaysShowQuestDistanceFrameHooked = true
    end
end

function UITweaks:HideHelpTips()
    if self.db.profile.hideHelpTips and HelpTip then
        if HelpTip.HideAllSystem then HelpTip:HideAllSystem() end
        if HelpTip.HideAll then HelpTip:HideAll(UIParent) end
    end
end

function UITweaks:HookHelpTipFrames()
    self:EnsureHelpTipHooks()
    self:HideHelpTips()
end

function UITweaks:EnsureObjectiveTrackerLoaded()
    if ObjectiveTrackerFrame then return true end
    if UIParentLoadAddOn then
        local loaded = UIParentLoadAddOn("Blizzard_ObjectiveTracker")
        if loaded and ObjectiveTrackerFrame then return true end
    end
end

function UITweaks:ShouldFadeObjectiveTracker()
    return self.db.profile.fadeObjectiveTrackerInRaids
        or self.db.profile.fadeObjectiveTrackerInDungeons
        or self.db.profile.fadeObjectiveTrackerEverywhereElse
end

function UITweaks:ShouldFadeObjectiveTrackerHere()
    local inInstance, instanceType = IsInInstance()
    if inInstance and instanceType == "raid" then
        return self.db.profile.fadeObjectiveTrackerInRaids
    elseif inInstance and instanceType == "party" then
        return self.db.profile.fadeObjectiveTrackerInDungeons
    end
    return self.db.profile.fadeObjectiveTrackerEverywhereElse
end

function UITweaks:FadeOutObjectiveTrackerIfNeeded()
    if self:ShouldFadeObjectiveTrackerHere() and self:EnsureObjectiveTrackerLoaded() then
        UIFrameFadeOut(ObjectiveTrackerFrame, OBJECTIVE_TRACKER_FADE_DURATION, ObjectiveTrackerFrame:GetAlpha(), 0)
        self.objectiveTrackerFadedByAddon = true
    end
end

function UITweaks:FadeInObjectiveTrackerIfNeeded(force)
    if self:EnsureObjectiveTrackerLoaded() then
        if force or self.objectiveTrackerFadedByAddon then
            UIFrameFadeIn(ObjectiveTrackerFrame, OBJECTIVE_TRACKER_FADE_DURATION, ObjectiveTrackerFrame:GetAlpha(), 1)
            self.objectiveTrackerFadedByAddon = false
        end
    end
end

function UITweaks:UpdateObjectiveTrackerState()
    if self:ShouldFadeObjectiveTracker() then
        if InCombatLockdown and InCombatLockdown() then
            if self:ShouldFadeObjectiveTrackerHere() then
                self:FadeOutObjectiveTrackerIfNeeded()
            else
                self:FadeInObjectiveTrackerIfNeeded()
            end
        else
            self:FadeInObjectiveTrackerIfNeeded()
        end
    end
end

function UITweaks:GetPlayerAndTargetFrameAlpha(forceInCombat)
    local inCombat = forceInCombat or (InCombatLockdown and InCombatLockdown())
    local opacityKey = inCombat
        and "playerAndTargetFrameOpacityInCombat"
        or "playerAndTargetFrameOpacityOutOfCombat"
    return (tonumber(self.db.profile[opacityKey]) or 100) / 100
end

function UITweaks:UpdatePlayerCastingBarFadeAnimationAlpha(frame, alpha)
    if frame.FadeOutAnim then
        local fadeAnimation = frame.FadeOutAnim:GetAnimations()
        if fadeAnimation then
            fadeAnimation:SetFromAlpha(alpha)
            fadeAnimation:SetToAlpha(0)
        end
    end

    if frame.HoldFadeOutAnim then
        local holdAnimation, fadeAnimation = frame.HoldFadeOutAnim:GetAnimations()
        if holdAnimation then
            holdAnimation:SetFromAlpha(alpha)
            holdAnimation:SetToAlpha(alpha)
        end
        if fadeAnimation then
            fadeAnimation:SetFromAlpha(alpha)
            fadeAnimation:SetToAlpha(0)
        end
    end
end

function UITweaks:UpdatePlayerAndTargetFrameOpacity(forceInCombat)
    local alpha = self:GetPlayerAndTargetFrameAlpha(forceInCombat)
    local playerCastingBar = _G.PlayerCastingBarFrame

    if playerCastingBar and not self.playerCastingBarOpacityHooked then
        -- Blizzard restores the cast bar to full alpha whenever a cast starts.
        hooksecurefunc(playerCastingBar, "ApplyAlpha", function(frame, blizzardAlpha)
            local effectiveAlpha = blizzardAlpha * UITweaks:GetPlayerAndTargetFrameAlpha()
            frame:SetAlpha(effectiveAlpha)
            UITweaks:UpdatePlayerCastingBarFadeAnimationAlpha(frame, effectiveAlpha)
            if frame.additionalFadeWidgets then
                for widget in pairs(frame.additionalFadeWidgets) do
                    widget:SetAlpha(effectiveAlpha)
                end
            end
        end)
        self.playerCastingBarOpacityHooked = true
    end

    if PlayerFrame then PlayerFrame:SetAlpha(alpha) end
    if playerCastingBar then
        playerCastingBar:SetAlpha(alpha)
        self:UpdatePlayerCastingBarFadeAnimationAlpha(playerCastingBar, alpha)
    end
    if _G.TargetFrame then _G.TargetFrame:SetAlpha(alpha) end
end

function UITweaks:ApplyTargetFrameAurasHide()
    if not self.db.profile.hideTargetFrameAuras or not _G.TargetFrame then return end

    _G.TargetFrame.maxBuffs = 0
    _G.TargetFrame.maxDebuffs = 0
    _G.TargetFrame:UpdateAuras()
end

function UITweaks:UpdateChatTabsVisibility()
    self.hiddenChatTabs = self.hiddenChatTabs or {}
    if self.chatTabsHoverTicker then
        self.chatTabsHoverTicker:Cancel()
        self.chatTabsHoverTicker = nil
    end
    local function isChatWindowActive(index, tab)
        if FCF_IsChatWindowIndexActive then
            return FCF_IsChatWindowIndexActive(index)
        end
        if tab and tab.IsShown then
            return tab:IsShown()
        end
        return false
    end
    for i = 1, NUM_CHAT_WINDOWS do
        local tabName = "ChatFrame" .. i .. "Tab"
        local tab = _G[tabName]
        if tab and not tab.UITweaksHooked then
            -- Keep tabs faded out even when hover/OnShow tries to reveal them.
            tab:HookScript("OnShow", function(frame)
                if UITweaks.db and UITweaks.db.profile.hideChatTabs then
                    frame:SetAlpha(0)
                end
            end)
            tab.UITweaksHooked = true
        end
        if tab then
            if self.db.profile.hideChatTabs then
                if isChatWindowActive(i, tab) then
                    tab:SetAlpha(0)
                    self.hiddenChatTabs[tabName] = true
                end
            else
                tab:SetAlpha(1)
                self.hiddenChatTabs[tabName] = nil
            end
        end
    end
    if self.db.profile.hideChatTabs then
        self.chatTabsHoverTicker = C_Timer.NewTicker(0.1, function()
            if not (UITweaks.db and UITweaks.db.profile.hideChatTabs) then return end
            for i = 1, NUM_CHAT_WINDOWS do
                local tab = _G["ChatFrame" .. i .. "Tab"]
                if tab and isChatWindowActive(i, tab) then
                    if tab:IsMouseOver() then
                        tab:SetAlpha(1)
                    else
                        tab:SetAlpha(0)
                    end
                end
            end
        end)
    end
end

function UITweaks:UpdateChatMenuButtonVisibility()
    local button = _G.ChatFrameMenuButton
    updateChatControlButtonVisibility(self, button, "hideChatMenuButton")
end

function UITweaks:UpdateChatChannelsButtonVisibility()
    local button = _G.ChatFrameChannelButton
    updateChatControlButtonVisibility(self, button, "hideChatChannelsButton")
end

function UITweaks:UpdateSocialButtonVisibility()
    local button = _G.QuickJoinToastButton
    updateSocialButtonVisibility(self, button)
end

function UITweaks:UpdateChatControlButtonsVisibility()
    self:SetChatControlButtonsHoverPolling(shouldAutoHideChatControlButtons(self))
    self:UpdateChatMenuButtonVisibility()
    self:UpdateChatChannelsButtonVisibility()
    self:UpdateSocialButtonVisibility()
end

function UITweaks:UpdateCompactRaidFrameManagerVisibility()
    local frame = _G.CompactRaidFrameManager
    if not frame or not self.db.profile.hideCompactRaidFrameManager then return end
    if not frame.UITweaksHooked then
        frame:HookScript("OnShow", function(shownFrame)
            if UITweaks.db and UITweaks.db.profile.hideCompactRaidFrameManager then
                shownFrame:Hide()
            end
        end)
        frame.UITweaksHooked = true
    end
    frame:Hide()
end

function UITweaks:ApplyPartyAndRaidFrameScale()
    local scalePercent = self.db.profile.partyAndRaidFrameScale
    if not scalePercent or scalePercent >= 100 then return end
    if InCombatLockdown and InCombatLockdown() then
        self.partyAndRaidFrameScalePending = true
        return
    end

    self.partyAndRaidFrameScalePending = nil
    local scale = scalePercent / 100
    if _G.CompactPartyFrame then
        _G.CompactPartyFrame:SetScale(scale)
    end
    if _G.CompactRaidFrameContainer then
        _G.CompactRaidFrameContainer:SetScale(scale)
    end
end

local function ensureGroupLootHistoryLoaded()
    if _G.GroupLootHistoryFrame then return true end
    local loadAddOn = C_AddOns and C_AddOns.LoadAddOn or UIParentLoadAddOn
    if loadAddOn then
        local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_GroupLootHistory"))
            or (IsAddOnLoaded and IsAddOnLoaded("Blizzard_GroupLootHistory"))
        if not isLoaded then
            loadAddOn("Blizzard_GroupLootHistory")
        end
    end
    return _G.GroupLootHistoryFrame ~= nil
end

function UITweaks:UpdateGroupLootHistoryVisibility()
    if not ensureGroupLootHistoryLoaded() then return end
    local frame = _G.GroupLootHistoryFrame
    if not frame then return end
    if self.db.profile.hideGroupLootHistoryFrame then
        if not frame.UITweaksHooked then
            frame:HookScript("OnShow", function(shownFrame)
                if UITweaks.db and UITweaks.db.profile.hideGroupLootHistoryFrame then
                    shownFrame:Hide()
                end
            end)
            frame.UITweaksHooked = true
        end
        frame:Hide()
    end
end

function UITweaks:UpdateConsolePortTempAbilityFrameVisibility()
    local frame = _G.ConsolePortTempAbilityFrame
    if not frame then return end
    if self.db.profile.hideConsolePortTempAbilityFrame then
        if not frame.UITweaksHooked then
            frame:HookScript("OnShow", function(shownFrame)
                if UITweaks.db and UITweaks.db.profile.hideConsolePortTempAbilityFrame then
                    shownFrame:Hide()
                end
            end)
            frame.UITweaksHooked = true
        end
        frame:Hide()
    end
end

function UITweaks:UpdateConsolePortCrosshairVisibility()
    if not self.db.profile.onlyShowConsolePortCrosshairInCombat then return end
    local frame = _G.ConsolePortCrosshair
    if not frame or not frame:GetScript("OnUpdate") or frame.UITweaksCombatVisibilityDriver then return end
    RegisterStateDriver(frame, "visibility", "[combat] show; hide")
    frame.UITweaksCombatVisibilityDriver = true
end

local function ensureTotemBarLoaded()
    if _G.TotemFrame then return true end
    local loadAddOn = C_AddOns and C_AddOns.LoadAddOn or UIParentLoadAddOn
    if loadAddOn then
        local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_TotemBar"))
            or (IsAddOnLoaded and IsAddOnLoaded("Blizzard_TotemBar"))
        if not isLoaded then
            loadAddOn("Blizzard_TotemBar")
        end
    end
    return _G.TotemFrame ~= nil
end

function UITweaks:UpdateTotemFrameVisibility()
    if not ensureTotemBarLoaded() then return end
    local frame = _G.TotemFrame
    if not frame then return end
    if self.db.profile.hideTotemFrame then
        if not frame.UITweaksHooked then
            frame:HookScript("OnShow", function(shownFrame)
                if UITweaks.db and UITweaks.db.profile.hideTotemFrame then
                    shownFrame:Hide()
                end
            end)
            frame.UITweaksHooked = true
        end
        frame:Hide()
    end
end

local function getStanceBars()
    local bars = {}
    if _G.StanceBar then bars[#bars + 1] = _G.StanceBar end
    if _G.ShapeshiftBarFrame and _G.ShapeshiftBarFrame ~= _G.StanceBar then
        bars[#bars + 1] = _G.ShapeshiftBarFrame
    end
    return bars
end

local function getStanceButtons()
    local buttons = {}
    local numButtons = NUM_STANCE_SLOTS or NUM_SHAPESHIFT_SLOTS or 10
    for i = 1, numButtons do
        local button = _G["StanceButton" .. i] or _G["ShapeshiftButton" .. i]
        if button then buttons[#buttons + 1] = button end
    end
    return buttons
end

local function setStanceAlpha(alpha)
    for _, stanceBar in ipairs(getStanceBars()) do
        if stanceBar then
            stanceBar:SetAlpha(alpha)
        end
    end
    for _, button in ipairs(getStanceButtons()) do
        if button then
            button:SetAlpha(alpha)
        end
    end
end

local function hookStanceButtons()
    for _, stanceBar in ipairs(getStanceBars()) do
        if stanceBar and not stanceBar.UITweaksHooked then
            -- Prevent stance bar reappearing when attack while on a mount refreshes action bars.
            stanceBar.UITweaksHooked = true
        end
    end
    local numButtons = NUM_STANCE_SLOTS or NUM_SHAPESHIFT_SLOTS or 10
    for i = 1, numButtons do
        local button = _G["StanceButton" .. i] or _G["ShapeshiftButton" .. i]
        if button and not button.UITweaksHooked then
            button:HookScript("OnShow", function(btn)
                if UITweaks.db and UITweaks.db.profile.hideStanceButtons then
                    btn:SetAlpha(0)
                end
            end)
            button.UITweaksHooked = true
        end
    end
end

function UITweaks:UpdateStanceButtonsVisibility()
    hookStanceButtons()
    if self.stanceBarHoverTicker then
        self.stanceBarHoverTicker:Cancel()
        self.stanceBarHoverTicker = nil
    end
    if not self.db.profile.hideStanceButtons then
        setStanceAlpha(1)
        return
    end
    setStanceAlpha(0)
    self.stanceBarHoverTicker = C_Timer.NewTicker(0.1, function()
        if not (UITweaks.db and UITweaks.db.profile.hideStanceButtons) then return end
        local hovered = false
        for _, stanceBar in ipairs(getStanceBars()) do
            if stanceBar and stanceBar:IsMouseOver() then
                hovered = true
                break
            end
        end
        if not hovered then
            for _, button in ipairs(getStanceButtons()) do
                if button and button:IsMouseOver() then
                    hovered = true
                    break
                end
            end
        end
        if hovered then
            setStanceAlpha(1)
        else
            setStanceAlpha(0)
        end
    end)
end

function UITweaks:OpenOptionsPanel()
    if Settings and Settings.OpenToCategory and self.optionsCategoryID then
        Settings.OpenToCategory(self.optionsCategoryID)
    elseif InterfaceOptionsFrame_OpenToCategory and self.optionsFrame then
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    elseif AceConfigDialog then
        AceConfigDialog:Open(addonName)
        if AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[addonName] then
            self:EnsureReloadButtonForFrame(AceConfigDialog.OpenFrames[addonName])
        end
    end
end

function UITweaks:CloseOptionsPanel()
    local settingsPanel = _G.SettingsPanel
    if settingsPanel and settingsPanel:IsShown() and settingsPanel.Close then
        settingsPanel:Close(true)
        return
    end

    local interfaceOptionsFrame = _G.InterfaceOptionsFrame
    if interfaceOptionsFrame and interfaceOptionsFrame:IsShown() then
        if _G.HideUIPanel then
            _G.HideUIPanel(interfaceOptionsFrame)
        else
            interfaceOptionsFrame:Hide()
        end
        return
    end

    if AceConfigDialog then
        AceConfigDialog:Close(addonName)
    end
end

function UITweaks:EaseMinimapZoomTo(desiredZoom)
    local startingZoom = Minimap:GetZoom()
    self.minimapSpeedZoomTarget = desiredZoom
    self.minimapSpeedZoomAnimationID = (self.minimapSpeedZoomAnimationID or 0) + 1
    local animationID = self.minimapSpeedZoomAnimationID

    if startingZoom == desiredZoom then
        self.minimapSpeedZoomLevel = desiredZoom
        return
    end

    local direction = desiredZoom > startingZoom and 1 or -1
    local stepCount = math.abs(desiredZoom - startingZoom)
    for step = 1, stepCount do
        local progress = step / stepCount
        local easedTime = math.acos(1 - (2 * progress)) / math.pi
        local zoomLevel = startingZoom + (direction * step)
        C_Timer.After(MINIMAP_ZOOM_EASING_DURATION * easedTime, function()
            if self.minimapSpeedZoomAnimationID ~= animationID then return end
            if not self.db.profile.adjustMinimapZoomBasedOnPlayerSpeed then return end

            self.minimapSpeedZoomLevel = zoomLevel
            Minimap:SetZoom(zoomLevel)
        end)
    end
end

function UITweaks:UpdateMinimapZoomForPlayerSpeed()
    local maximumZoom = math.max(0, Minimap:GetZoomLevels() - 1)
    local walkRunZoom = math.floor((maximumZoom * 0.6) + 0.5)
    local desiredZoom
    if InCombatLockdown() then
        desiredZoom = walkRunZoom
    else
        local isFlying = IsFlying("player")
        if issecretvalue and issecretvalue(isFlying) then return end

        local currentSpeed
        if not isFlying then
            currentSpeed = GetUnitSpeed("player")
            if issecretvalue and issecretvalue(currentSpeed) then return end
            if type(currentSpeed) ~= "number" then return end
        end

        if isFlying then
            desiredZoom = 0
        elseif currentSpeed < 0.5 then
            desiredZoom = maximumZoom
        else
            desiredZoom = walkRunZoom
        end
    end

    if desiredZoom == self.minimapSpeedZoomTarget then return end
    self:EaseMinimapZoomTo(desiredZoom)
end

function UITweaks:StartMinimapSpeedZoomMonitor()
    if self.minimapSpeedZoomTicker or not self.db.profile.adjustMinimapZoomBasedOnPlayerSpeed then return end
    self.minimapSpeedZoomLevel = nil
    self.minimapSpeedZoomTarget = nil
    self:UpdateMinimapZoomForPlayerSpeed()
    self.minimapSpeedZoomTicker = C_Timer.NewTicker(MINIMAP_SPEED_ZOOM_UPDATE_INTERVAL, function()
        self:UpdateMinimapZoomForPlayerSpeed()
    end)
end

function UITweaks:StopMinimapSpeedZoomMonitor()
    if self.minimapSpeedZoomTicker then
        self.minimapSpeedZoomTicker:Cancel()
        self.minimapSpeedZoomTicker = nil
    end
    self.minimapSpeedZoomAnimationID = (self.minimapSpeedZoomAnimationID or 0) + 1
    self.minimapSpeedZoomLevel = nil
    self.minimapSpeedZoomTarget = nil
end

function UITweaks:UpdateMinimapButtonPosition()
    local angle = math.rad(self.db.profile.minimapPos)
    local radius = (Minimap:GetWidth() / 2) + 6
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function UITweaks:UpdateMinimapButtonDragPosition()
    local cursorX, cursorY = GetCursorPosition()
    local minimapX, minimapY = Minimap:GetCenter()
    local scale = UIParent:GetEffectiveScale()
    local angle = math.deg(math.atan2((cursorY / scale) - minimapY, (cursorX / scale) - minimapX))
    self.db.profile.minimapPos = angle % 360
    self:UpdateMinimapButtonPosition()
end

function UITweaks:CreateMinimapButton()
    if self.minimapButton then return end

    local dataBroker = LibStub("LibDataBroker-1.1", true)
    local iconLibrary = LibStub("LibDBIcon-1.0", true)
    if dataBroker and iconLibrary then
        local launcher = dataBroker:NewDataObject(addonName, {
            type = "launcher",
            icon = "Interface\\AddOns\\UITweaks\\icon64.tga",
            OnClick = function(_, mouseButton)
                if mouseButton == "LeftButton" then self:OpenOptionsPanel() end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("Stock UI Tweaks")
                tooltip:AddLine("Left-click to open settings.", 1, 1, 1)
                tooltip:AddLine("Drag to move this button.", 1, 1, 1)
            end,
        })
        iconLibrary:Register(addonName, launcher, self.db.profile)
        self.minimapButton = iconLibrary:GetMinimapButton(addonName)
        return
    end

    local button = CreateFrame("Button", "UITweaksMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(24, 24)
    background:SetPoint("CENTER")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\UITweaks\\icon64.tga")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    highlight:SetSize(24, 24)
    highlight:SetPoint("CENTER")

    button:SetScript("OnMouseDown", function() button.wasDragged = false end)
    button:SetScript("OnClick", function()
        if not button.wasDragged then self:OpenOptionsPanel() end
    end)
    button:SetScript("OnDragStart", function()
        button.wasDragged = true
        button:SetScript("OnUpdate", function() self:UpdateMinimapButtonDragPosition() end)
    end)
    button:SetScript("OnDragStop", function()
        button:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText("Stock UI Tweaks")
        GameTooltip:AddLine("Left-click to open settings.", 1, 1, 1)
        GameTooltip:AddLine("Drag to move this button.", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.minimapButton = button
    self:UpdateMinimapButtonPosition()
end

function UITweaks:EnsureReloadButtonForFrame(parent)
    return self.debug.EnsureReloadButtonForFrame(self, parent)
end

function UITweaks:EnsureReloadButton()
    return self.debug.EnsureReloadButton(self)
end

function UITweaks:EnsureBottomLeftReloadButton()
    return self.debug.EnsureBottomLeftReloadButton(self)
end

function UITweaks:GetWatchedQuestIDs()
    local watchedQuestIDs = {}
    local questLog = _G["C_QuestLog"]
    if not (questLog and questLog.GetNumQuestWatches and questLog.GetQuestIDForQuestWatchIndex) then
        return watchedQuestIDs
    end
    local watchCount = questLog.GetNumQuestWatches() or 0
    for watchIndex = 1, watchCount do
        local questID = questLog.GetQuestIDForQuestWatchIndex(watchIndex)
        if questID then
            watchedQuestIDs[#watchedQuestIDs + 1] = questID
        end
    end

    if not self:EnsureObjectiveTrackerLoaded() then
        return watchedQuestIDs
    end

    local trackerOrderedQuestIDs = {}
    local trackerModuleNames = {
        "CampaignQuestObjectiveTracker",
        "QuestObjectiveTracker",
    }
    for _, moduleName in ipairs(trackerModuleNames) do
        local module = _G[moduleName]
        if module and module.BuildQuestWatchInfos then
            for _, questWatchInfo in ipairs(module:BuildQuestWatchInfos()) do
                local quest = questWatchInfo.quest
                local questID = quest and quest.GetID and quest:GetID()
                if questID then
                    trackerOrderedQuestIDs[#trackerOrderedQuestIDs + 1] = questID
                end
            end
        end
    end

    if #trackerOrderedQuestIDs > 0 then
        return trackerOrderedQuestIDs
    end
    return watchedQuestIDs
end

function UITweaks:GetSuperTrackedQuestID()
    local superTrack = _G["C_SuperTrack"]
    local getSuperTrackedQuestID = _G["GetSuperTrackedQuestID"]
    if superTrack and superTrack.GetSuperTrackedQuestID then
        return superTrack.GetSuperTrackedQuestID()
    end
    if getSuperTrackedQuestID then
        return getSuperTrackedQuestID()
    end
end

function UITweaks:SetSuperTrackedQuestID(questID)
    local superTrack = _G["C_SuperTrack"]
    local setSuperTrackedQuestID = _G["SetSuperTrackedQuestID"]
    if superTrack and superTrack.SetSuperTrackedQuestID then
        superTrack.SetSuperTrackedQuestID(questID)
    elseif setSuperTrackedQuestID then
        setSuperTrackedQuestID(questID)
    end
end

function UITweaks:SelectNextTrackedQuest()
    local watchedQuestIDs = self:GetWatchedQuestIDs()
    if #watchedQuestIDs == 0 then
        return
    end
    local activeQuestID = self:GetSuperTrackedQuestID()
    local activeIndex
    for index, questID in ipairs(watchedQuestIDs) do
        if questID == activeQuestID then
            activeIndex = index
            break
        end
    end
    local nextIndex = activeIndex and (activeIndex + 1) or 1
    if nextIndex > #watchedQuestIDs then
        nextIndex = 1
    end
    self:SetSuperTrackedQuestID(watchedQuestIDs[nextIndex])
end

function UITweaks:SelectPreviousTrackedQuest()
    local watchedQuestIDs = self:GetWatchedQuestIDs()
    if #watchedQuestIDs == 0 then
        return
    end
    local activeQuestID = self:GetSuperTrackedQuestID()
    local activeIndex
    for index, questID in ipairs(watchedQuestIDs) do
        if questID == activeQuestID then
            activeIndex = index
            break
        end
    end
    local previousIndex = activeIndex and (activeIndex - 1) or #watchedQuestIDs
    if previousIndex < 1 then
        previousIndex = #watchedQuestIDs
    end
    self:SetSuperTrackedQuestID(watchedQuestIDs[previousIndex])
end

local function buildAbandonItemNames(items)
    if items then
        local itemNames = {}
        local item = Item:CreateFromItemID(0)

        for _, itemID in ipairs(items) do
            item:SetItemID(itemID)
            local itemName = item:GetItemName()
            if itemName then
                table.insert(itemNames, itemName)
            end
        end

        if #itemNames > 0 then
            return table.concat(itemNames, ", ")
        end
    end

    return nil
end

function UITweaks:AbandonSelectedTrackedQuest()
    local questID = self:GetSuperTrackedQuestID()
    if not questID then
        return false
    end

    local canAbandonQuest = C_QuestLog and C_QuestLog.CanAbandonQuest
    if not canAbandonQuest or not canAbandonQuest(questID) then
        return false
    end

    local oldSelectedQuest = C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest() or nil
    if C_QuestLog.SetSelectedQuest then
        C_QuestLog.SetSelectedQuest(questID)
    end
    if C_QuestLog.SetAbandonQuest then
        C_QuestLog.SetAbandonQuest()
    end

    local items = C_QuestLog.GetAbandonQuestItems and buildAbandonItemNames(C_QuestLog.GetAbandonQuestItems()) or nil
    local abandonQuestID = C_QuestLog.GetAbandonQuest and C_QuestLog.GetAbandonQuest() or questID
    local title = QuestUtils_GetQuestName and QuestUtils_GetQuestName(abandonQuestID)
    if items then
        StaticPopup_Hide("ABANDON_QUEST")
        StaticPopup_Show("ABANDON_QUEST_WITH_ITEMS", title, items)
    else
        StaticPopup_Hide("ABANDON_QUEST_WITH_ITEMS")
        StaticPopup_Show("ABANDON_QUEST", title)
    end

    if C_QuestLog.SetSelectedQuest then
        C_QuestLog.SetSelectedQuest(oldSelectedQuest)
    end
    return true
end

function UITweaks:OpenMacroPanel()
    self:CloseOptionsPanel()

    local showMacroFrame = _G["ShowMacroFrame"]
    if showMacroFrame then
        showMacroFrame()
        return
    end

    local cAddOns = _G["C_AddOns"]
    local isAddOnLoaded = _G["IsAddOnLoaded"]
    local loadAddOn = (cAddOns and cAddOns.LoadAddOn) or _G["UIParentLoadAddOn"]
    local loaded = (cAddOns and cAddOns.IsAddOnLoaded and cAddOns.IsAddOnLoaded("Blizzard_MacroUI"))
        or (isAddOnLoaded and isAddOnLoaded("Blizzard_MacroUI"))
    if not loaded and loadAddOn then
        loadAddOn("Blizzard_MacroUI")
    end

    local macroFrame = _G["MacroFrame"]
    local showUIPanel = _G["ShowUIPanel"]
    if macroFrame and showUIPanel then
        showUIPanel(macroFrame)
    elseif macroFrame and macroFrame.Show then
        macroFrame:Show()
    end
end

function UITweaks:EnsureQuestTrackerMacros()
    local getMacroIndexByName = _G["GetMacroIndexByName"]
    local createMacro = _G["CreateMacro"]
    local editMacro = _G["EditMacro"]
    local getMacroInfo = _G["GetMacroInfo"]
    local getNumMacros = _G["GetNumMacros"]
    if not (getMacroIndexByName and createMacro and editMacro and getMacroInfo and getNumMacros) then
        self:OpenMacroPanel()
        return false
    end

    local function ensureMacro(name, body)
        local existingMacroIndex = getMacroIndexByName(name)
        if existingMacroIndex and existingMacroIndex > 0 then
            local _, _, macroBody = getMacroInfo(existingMacroIndex)
            if macroBody ~= body then
                editMacro(existingMacroIndex, name, NEXT_QUEST_MACRO_ICON, body)
            end
            return true
        end

        local globalMacroCount = select(1, getNumMacros()) or 0
        local maxGlobalMacros = _G["MAX_ACCOUNT_MACROS"] or 120
        if globalMacroCount >= maxGlobalMacros then
            return false
        end

        createMacro(name, NEXT_QUEST_MACRO_ICON, body, false)
        return true
    end

    local hasAbandonMacro = ensureMacro(ABANDON_QUEST_MACRO_NAME, ABANDON_QUEST_MACRO_BODY)
    local hasNextMacro = ensureMacro(NEXT_QUEST_MACRO_NAME, NEXT_QUEST_MACRO_BODY)
    local hasPreviousMacro = ensureMacro(PREVIOUS_QUEST_MACRO_NAME, PREVIOUS_QUEST_MACRO_BODY)
    self:OpenMacroPanel()
    return hasAbandonMacro and hasNextMacro and hasPreviousMacro
end

function UITweaks:UpdateBottomLeftReloadButton()
    return self.debug.UpdateBottomLeftReloadButton(self)
end

function UITweaks:GetConsolePortBarEnv()
    local relaTable = LibStub("RelaTable", true)
    if not relaTable then return end
    return relaTable("ConsolePort_Bar")
end

local function shallowCopyTable(src)
    if type(src) ~= "table" then return end
    local out = {}
    for key, value in pairs(src) do
        out[key] = value
    end
    return out
end

function UITweaks:IsConsolePortPresetEmpty(preset)
    return type(preset) ~= "table" or next(preset) == nil
end

function UITweaks:EnsureConsolePortBarLoaded()
    local loadAddOn = C_AddOns and C_AddOns.LoadAddOn or UIParentLoadAddOn
    if loadAddOn then
        local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort_Bar"))
            or (IsAddOnLoaded and IsAddOnLoaded("ConsolePort_Bar"))
        if not isLoaded then
            loadAddOn("ConsolePort_Bar")
        end
    end
    return (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort_Bar"))
        or (IsAddOnLoaded and IsAddOnLoaded("ConsolePort_Bar"))
end

function UITweaks:GetConsolePortPreset(name)
    if not self.consolePortPresetCache then
        self:CacheConsolePortPresets()
    end
    if self.consolePortPresetCache and self.consolePortPresetCache[name] then
        return self.consolePortPresetCache[name]
    end
    local env = self:GetConsolePortBarEnv()
    if not env then return end
    local preset = env("Presets/" .. name)
    if type(preset) ~= "table" then return end
    if not self.consolePortPresetCache then
        self.consolePortPresetCache = {}
    end
    self.consolePortPresetCache[name] = preset
    return preset
end

function UITweaks:CacheConsolePortPresets()
    local env = self:GetConsolePortBarEnv()
    if not env then return end
    local presets = env("Presets")
    if type(presets) ~= "table" then return end
    self.consolePortPresetCache = shallowCopyTable(presets) or {}
end

function UITweaks:RefreshConsolePortPresetCache()
    self.consolePortPresetCache = nil
    self:CacheConsolePortPresets()
end

function UITweaks:HasConsolePortPreset(name)
    local preset = self:GetConsolePortPreset(name)
    if self:IsConsolePortPresetEmpty(preset) then return false end
    return true
end

function UITweaks:GetConsolePortActionBarLoadout(allowOpen)
    if self.consolePortActionBarLoadout then
        local loadout = self.consolePortActionBarLoadout
        if loadout and (loadout.OnSave or loadout.OnLoadPreset) then
            return loadout
        end
    end
    local configFrame = _G.ConsolePortActionBarConfig
    if not configFrame then
        if not allowOpen then
            return
        end
        self:OpenConsolePortActionBarConfig(false)
        configFrame = _G.ConsolePortActionBarConfig
    end
    local loadout = configFrame
        and configFrame.SettingsContainer
        and configFrame.SettingsContainer.ScrollChild
        and configFrame.SettingsContainer.ScrollChild.Loadout
    if loadout and (loadout.OnSave or loadout.OnLoadPreset) then
        self.consolePortActionBarLoadout = loadout
    end
    return loadout
end

function UITweaks:SaveConsolePortActionBarProfileAs(name, desc)
    local loadout = self:GetConsolePortActionBarLoadout(true)
    if not (loadout and loadout.OnSave) then
        return
    end
    loadout:OnSave({
        name = name,
        desc = desc,
    }, true, true)
    self:RefreshConsolePortPresetCache()
end

function UITweaks:SaveConsolePortActionBarProfile()
    self:SaveConsolePortActionBarProfileAs("UITweaksProfile", "Saved by Stock UI Tweaks")
end

function UITweaks:RestoreConsolePortActionBarProfileFrom(name)
    local preset = self:GetConsolePortPreset(name)
    if self:IsConsolePortPresetEmpty(preset) then return false end
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    if not self:GetConsolePortActionBarLoadout(true) then
        return false
    end
    local loadout = self.consolePortActionBarLoadout
    if loadout and loadout.OnLoadPreset then
        loadout:OnLoadPreset(preset)
    end
    return true
end

function UITweaks:RestoreConsolePortActionBarProfile()
    return self:RestoreConsolePortActionBarProfileFrom("UITweaksProfile")
end

function UITweaks:OpenConsolePortActionBarConfig(show)
    if not self:EnsureConsolePortBarLoaded() then
        return
    end
    local relaTable = LibStub("RelaTable", true)
    if not relaTable then return end
    local env = relaTable("ConsolePort_Bar")
    if not env or not env.TriggerEvent then return end
    env:TriggerEvent("OnConfigToggle")
    env:TriggerEvent("OnConfigToggle", true)

    local configFrame = _G.ConsolePortActionBarConfig
    if not configFrame and _G.ConsolePort then
        local cp = _G.ConsolePort
        if cp.ToggleConfig then
            cp:ToggleConfig()
        elseif cp.ToggleConfigFrame then
            cp:ToggleConfigFrame()
        end
        configFrame = _G.ConsolePortActionBarConfig
    end

    if configFrame then
        if show ~= false then
            configFrame:Show()
        end
        return
    end
end

function UITweaks:SaveSkyridingBarLayout()
    local layout = {}
    for index = 1, SKYRIDING_BAR_SLOT_COUNT do
        local slot = SKYRIDING_BAR_SLOT_START + index - 1
        local actionType, actionID, subType = GetActionInfo(slot)
        if actionType then
            layout[index] = {
                type = actionType,
                id = actionID,
                subType = subType,
            }
        else
            layout[index] = false
        end
    end
    if not next(layout) then return end
    local hasAny = false
    for _, entry in pairs(layout) do
        if entry then
            hasAny = true
            break
        end
    end
    if not hasAny then return end
    self.db.global.skyridingBarLayout = layout
end

local function clearActionSlot(slot)
    if ClearAction then
        ClearAction(slot)
        return
    end
    if PickupAction and ClearCursor then
        PickupAction(slot)
        ClearCursor()
    end
end

local function placeActionIntoSlot(slot, entry)
    if not entry or entry == false then return end
    local actionType = entry.type
    local actionID = entry.id
    if not actionType or not actionID then return false end

    if actionType == "spell" then
        if C_Spell and C_Spell.PickupSpell then
            C_Spell.PickupSpell(actionID)
        end
    elseif actionType == "item" and PickupItem then
        PickupItem(actionID)
    elseif actionType == "macro" and PickupMacro then
        PickupMacro(actionID)
    elseif actionType == "equipmentset" and C_EquipmentSet and C_EquipmentSet.PickupEquipmentSet then
        C_EquipmentSet.PickupEquipmentSet(actionID)
    else
        return
    end

    if PlaceAction then
        PlaceAction(slot)
    end
    if ClearCursor then
        ClearCursor()
    end

    local placedType, placedID = GetActionInfo(slot)
    return placedType == actionType and placedID == actionID
end

local function isSavedActionAvailable(entry)
    if not entry or entry == false then return false end
    local actionType = entry.type
    local actionID = entry.id
    if not actionType or not actionID then return false end

    if actionType == "spell" then
        if (IsSpellKnown and IsSpellKnown(actionID)) or (IsPlayerSpell and IsPlayerSpell(actionID)) then
            return true
        end
        if IsUsableSpell and IsUsableSpell(actionID) then
            return true
        end
        if C_Spell and C_Spell.IsSpellUsable and C_Spell.IsSpellUsable(actionID) then
            return true
        end
        return false
    elseif actionType == "item" then
        if C_Item and C_Item.DoesItemExist then
            return C_Item.DoesItemExist(actionID)
        end
        return GetItemInfo and GetItemInfo(actionID) ~= nil
    elseif actionType == "macro" and GetMacroInfo then
        return GetMacroInfo(actionID) ~= nil
    elseif actionType == "equipmentset" and C_EquipmentSet and C_EquipmentSet.GetEquipmentSetInfo then
        return C_EquipmentSet.GetEquipmentSetInfo(actionID) ~= nil
    end

    return false
end

function UITweaks:RestoreSkyridingBarLayout()
    local layout = self.db.global.skyridingBarLayout
    if not layout or not next(layout) then return end
    for index = 1, SKYRIDING_BAR_SLOT_COUNT do
        local slot = SKYRIDING_BAR_SLOT_START + index - 1
        local entry = layout[index]
        if entry and entry ~= false and isSavedActionAvailable(entry) then
            clearActionSlot(slot)
            placeActionIntoSlot(slot, entry)
        end
    end
end

function UITweaks:ApplyVisibilityState()
    self:UpdatePlayerAndTargetFrameOpacity()
    self:UpdateChatTabsVisibility()
    self:UpdateChatControlButtonsVisibility()
    self:UpdateConsolePortTempAbilityFrameVisibility()
    self:UpdateConsolePortCrosshairVisibility()
    self:UpdateCompactRaidFrameManagerVisibility()
    self:UpdateGroupLootHistoryVisibility()
    self:UpdateStanceButtonsVisibility()
    self:UpdateTotemFrameVisibility()
end

function UITweaks:EnsureHelpTipHooks()
    if HelpTip and not self.helpTipShowHooked then
        hooksecurefunc(HelpTip, "Show", function(_, owner, info)
            if not (UITweaks.db and UITweaks.db.profile and UITweaks.db.profile.hideHelpTips) then return end
            if HelpTip.HideAllSystem then HelpTip:HideAllSystem() end
            if HelpTip.HideAll then HelpTip:HideAll(owner or UIParent) end
            if HelpTip.Hide and info and info.text then
                HelpTip:Hide(owner, info.text)
            end
        end)
        self.helpTipShowHooked = true
    end
end

function UITweaks:IsSkyridingBarActive()
    if IsMounted and IsMounted() then
        return true
    end
    return false
end

function UITweaks:StartSkyridingBarMonitor()
    if self.skyridingBarTicker then return end
    self.skyridingBarTicker = C_Timer.NewTicker(0.5, function()
        self:UpdateSkyridingBarSaveState()
    end)
end

function UITweaks:StopSkyridingBarMonitor()
    if self.skyridingBarTicker then
        self.skyridingBarTicker:Cancel()
        self.skyridingBarTicker = nil
    end
end

function UITweaks:UpdateSkyridingBarSaveState()
    local wasActive = self.skyridingBarActive
    local isActive = self:IsSkyridingBarActive()
    self.skyridingBarActive = isActive
    if wasActive and not isActive and self.db.profile.skyridingBarSharing then
        self:SaveSkyridingBarLayout()
    end
end
