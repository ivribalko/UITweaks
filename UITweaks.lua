local addonName, addonTable = ...
local UITweaks = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
-- Skyriding uses Bonus Bar 5, which maps to action slots 121-132.
local SKYRIDING_BAR_SLOT_START = 121
local SKYRIDING_BAR_SLOT_COUNT = 12
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS or 10
local NEXT_QUEST_MACRO_NAME = "Quest Next"
local PREVIOUS_QUEST_MACRO_NAME = "Quest Prev"
local NEXT_QUEST_MACRO_ICON = "INV_Misc_Note_01"
local NEXT_QUEST_MACRO_BODY = "/uitnextquest"
local PREVIOUS_QUEST_MACRO_BODY = "/uitprevquest"
local gameTooltipUnitColor = rawget(_G, "GameTooltip_UnitColor")

local function applyTooltipUnitNameColor(unit)
    if not gameTooltipUnitColor then return end
    local r, g, b = gameTooltipUnitColor(unit)
    if not r then return end
    local nameLine = rawget(_G, "GameTooltipTextLeft1")
    if nameLine and nameLine.GetText and nameLine:GetText() then
        nameLine:SetTextColor(r, g, b)
    end
end

function UITweaks:OnInitialize()
    local options = type(require) == "function" and require("UITweaksOptions") or addonTable.Options
    self.auras = type(require) == "function" and require("UITweaksAuras") or addonTable.Auras
    self.debug = type(require) == "function" and require("UITweaksDebug") or addonTable.Debug
    self.db = LibStub("AceDB-3.0"):New("UITweaksDB", options.defaults, true)
    options.OnInitialize(self)
end

function UITweaks:OnEnable()
    self:RegisterChatCommand("uitnextquest", "HandleNextQuestSlashCommand")
    self:RegisterChatCommand("uitprevquest", "HandlePreviousQuestSlashCommand")
    self:ApplyQuestMarkerDistanceSetting()
    self:ApplyChatLineFade()
    self:ApplyChatFontSize()
    self:ApplyChatBackgroundAlpha()
    self:HookHelpTipFrames()
    self:ApplyBuffFrameHide()
    if self.db.profile.showActionButtonAuraTimers then
        self.auras.ApplyActionButtonAuraTimers(self)
    end
    self.debug.OnEnable(self)
    self:ApplyVisibilityState()
    self:UpdateObjectiveTrackerState()
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_LOGOUT")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("LOOT_OPENED")
    self:RegisterEvent("LOOT_CLOSED")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("PLAYER_SOFT_ENEMY_CHANGED")
    self:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED")
    self:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    self:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
    self:RegisterEvent("MODIFIER_STATE_CHANGED")
    self:RegisterEvent("UNIT_AURA")
    self:RegisterEvent("NAVIGATION_FRAME_CREATED")
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
    elseif addonName == "Blizzard_CooldownViewer" then
        self:EnsureCooldownViewerSettingsHooked()
    elseif addonName == "Blizzard_BuffFrame" then
        self:ApplyBuffFrameHide()
        if self.db.profile.showActionButtonAuraTimers then
            self.auras.ApplyActionButtonAuraTimers(self)
        end
        self:ApplyVisibilityState()
        self:ScheduleDelayedVisibilityUpdate(true)
    elseif addonName == "Blizzard_GroupLootHistory" then
        self:UpdateGroupLootHistoryVisibility()
    elseif addonName == "Blizzard_ActionBarController" or addonName == "Blizzard_ActionBar" then
        self:UpdateStanceButtonsVisibility()
        if self.db.profile.showActionButtonAuraTimers then
            self.auras.InitializeActionButtonAuraTimers(self)
        end
        self.auras.RequestActionButtonAuraRefresh(self, true)
    elseif addonName == "Blizzard_ObjectiveTracker" then
        self:UpdateObjectiveTrackerState()
    elseif addonName == "ConsolePort"
        or addonName == "ConsolePort_ActionBar"
        or addonName == "ConsolePortActionBar"
        or addonName == "ConsolePortGroupCrossbar"
        or addonName == "ConsolePort_GroupCrossbar"
    then
        self:UpdateConsolePortTempAbilityFrameVisibility()
        if addonName == "ConsolePort" then
            self.auras.RegisterConsolePortActionPageCallback(self)
        end
        if self.db.profile.showActionButtonAuraTimers then
            self.auras.InitializeActionButtonAuraTimers(self)
        end
        self.auras.RequestActionButtonAuraRefresh(self, true)
    end
end

function UITweaks:PLAYER_REGEN_DISABLED()
    self.inCombat = true
    if self:ShouldCollapseObjectiveTracker() then
        self:CollapseTrackerIfNeeded()
    end
    self:UpdatePlayerFrameVisibility()
    self:UpdateTargetFrameVisibility()
    self:UpdateDamageMeterVisibility()
    if self.db.profile.showSoftTargetTooltipOutOfCombat then GameTooltip:Hide() end
    if self.visibilityTimer then
        self.visibilityTimer:Cancel()
        self.visibilityTimer = nil
    end
    self.visibilityDelayActive = false
end

function UITweaks:PLAYER_REGEN_ENABLED()
    self.inCombat = false
    self:ScheduleDelayedVisibilityUpdate()
    if self.db.profile.showActionButtonAuraTimers then
        self.auras.OnCombatEnded(self)
    end
end

function UITweaks:PLAYER_ENTERING_WORLD()
    self.inCombat = false
    self:ApplyBuffFrameHide()
    self:ApplyVisibilityState()
    self:ScheduleDelayedVisibilityUpdate(true)
    if self.db.profile.consolePortBarSharing then
        self:RestoreConsolePortActionBarProfile()
    end
    self.skyridingBarActive = self:IsSkyridingBarActive()
    if self.db.profile.skyridingBarSharing then
        C_Timer.After(2, function() self:RestoreSkyridingBarLayout() end)
        self:StartSkyridingBarMonitor()
    end
    if self.db.profile.showActionButtonAuraTimers then
        C_Timer.After(0.3, function() self.auras.ReapplyManualHighlightsFromPlayerAuras(self) end)
    end
end

function UITweaks:HandleNextQuestSlashCommand()
    self:SelectNextTrackedQuest()
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
    self:UpdateTargetTooltip()
    self:UpdateTargetFrameVisibility()
    if self.db.profile.showActionButtonAuraTimers then
        self.auras.RequestActionButtonAuraRefresh(self)
    end
end

function UITweaks:ACTIONBAR_SLOT_CHANGED()
    self.auras.RequestActionButtonAuraRefresh(self)
end

function UITweaks:ACTIONBAR_PAGE_CHANGED()
    self.auras.RequestActionButtonAuraRefresh(self, true)
    self.auras.ScheduleReapplyManualHighlightsFromPlayerAuras(self)
end

function UITweaks:MODIFIER_STATE_CHANGED()
    self.auras.RequestActionButtonAuraRefresh(self, true)
    self.auras.ScheduleReapplyManualHighlightsFromPlayerAuras(self)
end

function UITweaks:UNIT_AURA(_, unit)
    if unit ~= "player" and unit ~= "target" then return end
    self.auras.RequestActionButtonAuraRefresh(self)
    if unit == "player" then
        self.auras.ScheduleReapplyManualHighlightsFromPlayerAuras(self)
    end
end

function UITweaks:PLAYER_SOFT_ENEMY_CHANGED()
    self:UpdateTargetTooltip()
end

function UITweaks:PLAYER_SOFT_INTERACT_CHANGED()
    self:UpdateTargetTooltip()
end

function UITweaks:LOOT_OPENED()
    self.lootTargetGUIDToClear = nil
    local targetGuid = UnitGUID and UnitGUID("target")
    if targetGuid and UnitIsDead and UnitIsDead("target") then
        self.lootTargetGUIDToClear = targetGuid
    end
    self:UpdateTargetTooltip(true)
end

function UITweaks:LOOT_CLOSED()
    local targetGuidToClear = self.lootTargetGUIDToClear
    self.lootTargetGUIDToClear = nil

    if targetGuidToClear
        and UnitGUID and UnitGUID("target") == targetGuidToClear
        and UnitIsDead and UnitIsDead("target")
        and not (InCombatLockdown and InCombatLockdown())
        and ClearTarget
    then
        ClearTarget()
    end

    self:UpdateTargetFrameVisibility()
    self:UpdateTargetTooltip()
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

function UITweaks:SetChatFadeHoverPolling(enabled)
    if self.chatFadeHoverTicker then
        self.chatFadeHoverTicker:Cancel()
        self.chatFadeHoverTicker = nil
    end
    self.mainChatFrameHovered = nil
    if not enabled then return end
    self.chatFadeHoverTicker = C_Timer.NewTicker(0.1, function()
        local frame = getMainChatFrame()
        if not frame then return end
        local isCursorInside = isCursorInsideFrame(frame)
        if UITweaks.mainChatFrameHovered ~= isCursorInside then
            if frame.SetFading then frame:SetFading(not isCursorInside) end
            if frame.ResetFadeTimer then frame:ResetFadeTimer() end
            UITweaks.mainChatFrameHovered = isCursorInside
        end
    end)
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

function UITweaks:ApplyChatLineFade()
    local frame = getMainChatFrame()
    self:SetChatFadeHoverPolling(self.db.profile.chatMessageFadeAfterOverride)
    if self.db.profile.chatMessageFadeAfterOverride then
        local seconds = self.db.profile.chatMessageFadeAfterSeconds
        if not frame then return end
        if frame.SetTimeVisible then frame:SetTimeVisible(seconds) end
        if frame.SetFading then frame:SetFading(true) end
        if frame.ResetFadeTimer then frame:ResetFadeTimer() end
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

local function collapseObjectiveTracker()
    if ObjectiveTrackerFrame and ObjectiveTrackerFrame.SetCollapsed then
        ObjectiveTrackerFrame:SetCollapsed(true)
    elseif ObjectiveTrackerFrame and ObjectiveTrackerFrame.Collapse then
        ObjectiveTrackerFrame:Collapse()
    elseif ObjectiveTracker_Collapse then
        ObjectiveTracker_Collapse()
    end
end

local function expandObjectiveTracker()
    if ObjectiveTrackerFrame and ObjectiveTrackerFrame.SetCollapsed then
        ObjectiveTrackerFrame:SetCollapsed(false)
    elseif ObjectiveTrackerFrame and ObjectiveTrackerFrame.Expand then
        ObjectiveTrackerFrame:Expand()
    elseif ObjectiveTracker_Expand then
        ObjectiveTracker_Expand()
    end
end

function UITweaks:EnsureObjectiveTrackerLoaded()
    if ObjectiveTrackerFrame and (ObjectiveTrackerFrame.SetCollapsed or ObjectiveTrackerFrame.Collapse) then
        return true
    end
    if UIParentLoadAddOn then
        local loaded = UIParentLoadAddOn("Blizzard_ObjectiveTracker")
        if loaded and ObjectiveTrackerFrame then return true end
    end
end

function UITweaks:IsObjectiveTrackerCollapsed()
    if ObjectiveTrackerFrame then
        if ObjectiveTrackerFrame.IsCollapsed then return ObjectiveTrackerFrame:IsCollapsed() end
        if ObjectiveTrackerFrame.collapsed ~= nil then return ObjectiveTrackerFrame.collapsed end
    end
end

function UITweaks:ShouldCollapseObjectiveTracker()
    return self.db.profile.collapseObjectiveTrackerInRaids
        or self.db.profile.collapseObjectiveTrackerInDungeons
        or self.db.profile.collapseObjectiveTrackerEverywhereElse
end

function UITweaks:CollapseTrackerIfNeeded()
    if self:ShouldCollapseObjectiveTracker() then
        local shouldCollapse = true
        local inInstance, instanceType = IsInInstance()
        if inInstance and instanceType == "raid" then
            shouldCollapse = self.db.profile.collapseObjectiveTrackerInRaids
        elseif inInstance and instanceType == "party" then
            shouldCollapse = self.db.profile.collapseObjectiveTrackerInDungeons
        else
            shouldCollapse = self.db.profile.collapseObjectiveTrackerEverywhereElse
        end
        if shouldCollapse and self:EnsureObjectiveTrackerLoaded() then
            if not self:IsObjectiveTrackerCollapsed() then
                collapseObjectiveTracker()
                self.trackerCollapsedByAddon = true
            else
                self.trackerCollapsedByAddon = false
            end
        end
    end
end

function UITweaks:ExpandTrackerIfNeeded(force)
    if self:EnsureObjectiveTrackerLoaded() then
        if force or self.trackerCollapsedByAddon then
            expandObjectiveTracker()
            self.trackerCollapsedByAddon = false
        end
    end
end

function UITweaks:UpdateObjectiveTrackerState()
    if self:ShouldCollapseObjectiveTracker() then
        if InCombatLockdown and InCombatLockdown() then
            self:CollapseTrackerIfNeeded()
        else
            self:ExpandTrackerIfNeeded()
        end
    end
end

local function setBuffFrameAlpha(alpha)
    if BuffFrame then
        BuffFrame:SetAlpha(alpha)
        BuffFrame:Show()
        if BuffFrame.CollapseAndExpandButton then
            BuffFrame.CollapseAndExpandButton:SetAlpha(alpha)
            BuffFrame.CollapseAndExpandButton:Show()
        end
    end
end

local function setBuffFrameHoverPolling(enabled)
    if not BuffFrame then return end
    if BuffFrame.UITweaksHoverTicker then
        BuffFrame.UITweaksHoverTicker:Cancel()
        BuffFrame.UITweaksHoverTicker = nil
    end
    if not enabled then return end

    BuffFrame.UITweaksHoverTicker = C_Timer.NewTicker(0.1, function()
        if not (UITweaks.db and UITweaks.db.profile.hideBuffFrame and BuffFrame) then return end
        local overBuffs = BuffFrame:IsMouseOver()
        local overButton = BuffFrame.CollapseAndExpandButton and BuffFrame.CollapseAndExpandButton:IsMouseOver()
        if overBuffs or overButton then
            setBuffFrameAlpha(1)
        else
            setBuffFrameAlpha(0)
        end
    end)
end

local function ensureBuffFrameLoaded()
    if BuffFrame then return true end
    if UIParentLoadAddOn then
        local loaded = UIParentLoadAddOn("Blizzard_BuffFrame")
        if loaded and BuffFrame then return true end
    end
end

function UITweaks:ApplyBuffFrameHide(retry)
    if ensureBuffFrameLoaded() and BuffFrame then
        if self.db.profile.hideBuffFrame then
            if not BuffFrame.UITweaksHooked then
                -- Keep the buff frame faded out after UI refreshes.
                BuffFrame:HookScript("OnShow", function()
                    if UITweaks.db and UITweaks.db.profile.hideBuffFrame then
                        setBuffFrameAlpha(0)
                    end
                end)
                BuffFrame.UITweaksHooked = true
            end
            setBuffFrameHoverPolling(true)
            setBuffFrameAlpha(0)
        else
            setBuffFrameHoverPolling(false)
            setBuffFrameAlpha(1)
        end
    elseif not retry then
        C_Timer.After(0.5, function() self:ApplyBuffFrameHide(true) end)
    end
end

local function UpdateCombatFrameVisibility(frame, profileKey, stateDriver, delayStateDriver)
    if not frame then return end
    if UITweaks.db and UITweaks.db.profile and UITweaks.db.profile[profileKey] then
        if not frame.UITweaksHooked then
            -- Keep frames hidden outside combat when addons try to show them.
            frame:HookScript("OnShow", function(shownFrame)
                if UITweaks.db and UITweaks.db.profile and UITweaks.db.profile[profileKey] then
                    if not (InCombatLockdown and InCombatLockdown()) and not UITweaks.visibilityDelayActive then
                        shownFrame:Hide()
                    end
                end
            end)
            frame.UITweaksHooked = true
        end
        if RegisterStateDriver then
            if not (InCombatLockdown and InCombatLockdown()) then
                local driver = UITweaks.visibilityDelayActive and delayStateDriver or stateDriver
                if driver then
                    RegisterStateDriver(frame, "visibility", driver)
                end
            end
        end
        if not (InCombatLockdown and InCombatLockdown()) and not UITweaks.visibilityDelayActive then
            frame:Hide()
        end
    end
end

local function setPlayerFrameAlpha(alpha)
    if not PlayerFrame then return end
    PlayerFrame:SetAlpha(alpha)
    PlayerFrame:Show()
end

function UITweaks:SetPlayerFrameHoverPolling(enabled)
    if self.playerFrameHoverTicker then
        self.playerFrameHoverTicker:Cancel()
        self.playerFrameHoverTicker = nil
    end
    if not enabled then return end
    self.playerFrameHoverTicker = C_Timer.NewTicker(0.1, function()
        if not (UITweaks.db and UITweaks.db.profile.hidePlayerFrameOutOfCombat and PlayerFrame) then return end
        if UITweaks.inCombat then return end
        if UITweaks.visibilityDelayActive then
            setPlayerFrameAlpha(1)
            return
        end
        if PlayerFrame:IsMouseOver() then
            setPlayerFrameAlpha(1)
        else
            setPlayerFrameAlpha(0)
        end
    end)
end

function UITweaks:UpdatePlayerFrameVisibility()
    if not PlayerFrame then return end
    if self.db.profile.hidePlayerFrameOutOfCombat then
        if not PlayerFrame.UITweaksPlayerFrameHooked then
            PlayerFrame:HookScript("OnShow", function(frame)
                if not (UITweaks.db and UITweaks.db.profile.hidePlayerFrameOutOfCombat) then return end
                if UITweaks.inCombat or UITweaks.visibilityDelayActive or frame:IsMouseOver() then
                    frame:SetAlpha(1)
                else
                    frame:SetAlpha(0)
                end
            end)
            PlayerFrame.UITweaksPlayerFrameHooked = true
        end
        if RegisterStateDriver then
            RegisterStateDriver(PlayerFrame, "visibility", "show")
        end
        self:SetPlayerFrameHoverPolling(true)
        if self.inCombat then
            setPlayerFrameAlpha(1)
        elseif self.visibilityDelayActive then
            setPlayerFrameAlpha(1)
        elseif PlayerFrame:IsMouseOver() then
            setPlayerFrameAlpha(1)
        else
            setPlayerFrameAlpha(0)
        end
    else
        self:SetPlayerFrameHoverPolling(false)
        setPlayerFrameAlpha(1)
    end
end

function UITweaks:UpdateTargetFrameVisibility()
    UpdateCombatFrameVisibility(_G.TargetFrame, "hideTargetFrameOutOfCombat", "[combat,@target,exists] show; hide",
        "[@target,exists] show; hide")
end

function UITweaks:UpdateBackpackButtonVisibility()
    if self.bagsBarHoverTicker then
        self.bagsBarHoverTicker:Cancel()
        self.bagsBarHoverTicker = nil
    end
    if not self.db.profile.hideBackpackButton then
        if _G.BagsBar then
            _G.BagsBar:SetAlpha(1)
            _G.BagsBar:Show()
        end
        return
    end
    if _G.BagsBar then
        _G.BagsBar:SetAlpha(0)
        _G.BagsBar:Show()
    end
    if _G.BagsBar then
        self.bagsBarHoverTicker = C_Timer.NewTicker(0.1, function()
            if not (UITweaks.db and UITweaks.db.profile.hideBackpackButton and _G.BagsBar) then return end
            if _G.BagsBar:IsMouseOver() then
                _G.BagsBar:SetAlpha(1)
            else
                _G.BagsBar:SetAlpha(0)
            end
        end)
    end
end

function UITweaks:UpdateDamageMeterVisibility(retry)
    if self.damageMeterHoverTicker then
        self.damageMeterHoverTicker:Cancel()
        self.damageMeterHoverTicker = nil
    end
    if not _G.DamageMeter then
        if not retry then
            C_Timer.After(0.5, function() self:UpdateDamageMeterVisibility(true) end)
        end
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        _G.DamageMeter:SetAlpha(1)
        _G.DamageMeter:Show()
        return
    end
    if self.visibilityDelayActive then
        _G.DamageMeter:SetAlpha(1)
        _G.DamageMeter:Show()
        return
    end
    if not self.db.profile.hideDamageMeter then
        _G.DamageMeter:SetAlpha(1)
        _G.DamageMeter:Show()
        return
    end
    if not _G.DamageMeter.UITweaksHooked then
        _G.DamageMeter:HookScript("OnShow", function(frame)
            if UITweaks.db and UITweaks.db.profile.hideDamageMeter
                and not (InCombatLockdown and InCombatLockdown()) then
                frame:SetAlpha(0)
            end
        end)
        _G.DamageMeter.UITweaksHooked = true
    end
    _G.DamageMeter:SetAlpha(0)
    _G.DamageMeter:Show()
    if _G.DamageMeter then
        self.damageMeterHoverTicker = C_Timer.NewTicker(0.1, function()
            if not (UITweaks.db and UITweaks.db.profile.hideDamageMeter and _G.DamageMeter) then return end
            if InCombatLockdown and InCombatLockdown() then
                _G.DamageMeter:SetAlpha(1)
                return
            end
            if UITweaks.visibilityDelayActive then
                _G.DamageMeter:SetAlpha(1)
                return
            end
            if _G.DamageMeter:IsMouseOver() then
                _G.DamageMeter:SetAlpha(1)
            else
                _G.DamageMeter:SetAlpha(0)
            end
        end)
    end
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
    if not button then return end
    if self.db.profile.hideChatMenuButton then
        if not button.UITweaksHooked then
            -- Keep the menu button hidden even when UI code shows it.
            button:HookScript("OnShow", function(frame)
                if UITweaks.db and UITweaks.db.profile.hideChatMenuButton then
                    frame:Hide()
                end
            end)
            button.UITweaksHooked = true
        end
        button:Hide()
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

local function getMicroMenuButtons()
    local buttons = {}
    local function addButtonsFromParent(parent)
        if not (parent and parent.GetChildren) then return end
        local children = { parent:GetChildren() }
        for _, child in ipairs(children) do
            if child and child.IsObjectType and child:IsObjectType("Button") then
                buttons[#buttons + 1] = child
            elseif child and child.GetChildren then
                addButtonsFromParent(child)
            end
        end
    end
    local parent = _G.MicroMenuContainer or _G.MicroButtonAndBagsBar or _G.MicroMenu
    addButtonsFromParent(parent)
    return buttons
end

function UITweaks:UpdateMicroMenuVisibility()
    for _, button in ipairs(getMicroMenuButtons()) do
        local name = button and button.GetName and button:GetName() or ""
        if self.db.profile.hideMicroMenuButtons and name ~= "QueueStatusButton" then
            if not button.UITweaksHooked then
                button:HookScript("OnShow", function(btn)
                    if UITweaks.db and UITweaks.db.profile.hideMicroMenuButtons then
                        local btnName = btn and btn.GetName and btn:GetName() or ""
                        if btnName ~= "QueueStatusButton" then
                            btn:Hide()
                        end
                    end
                end)
                button.UITweaksHooked = true
            end
            button:Hide()
        end
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

function UITweaks:GetTargetTooltipUnit()
    local unit
    if self.db.profile.showSoftTargetTooltipOutOfCombat then
        if UnitExists("softenemy") then unit = "softenemy" end
        if not unit and UnitExists("softfriend") then unit = "softfriend" end
        if not unit and UnitExists("softinteract") then unit = "softinteract" end
    end
    return unit
end

function UITweaks:UpdateTargetTooltip(forceHide)
    if not GameTooltip then
        return
    end

    if forceHide
        or not self.db.profile.showSoftTargetTooltipOutOfCombat
        or (InCombatLockdown and InCombatLockdown())
    then
        GameTooltip:Hide()
        return
    end

    local unit = self:GetTargetTooltipUnit()
    if unit then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
        GameTooltip:SetUnit(unit)
        applyTooltipUnitNameColor(unit)
    else
        GameTooltip:Hide()
    end
end

function UITweaks:HasDelayedVisibilityFeatures()
    return self.db.profile.hideDamageMeter
        or self.db.profile.hidePlayerFrameOutOfCombat
        or self.db.profile.hideTargetFrameOutOfCombat
        or self:ShouldCollapseObjectiveTracker()
        or self.db.profile.showSoftTargetTooltipOutOfCombat
end

function UITweaks:ApplyDelayedVisibility()
    if self.db.profile.hideDamageMeter then
        self:UpdateDamageMeterVisibility()
    end
    if self.db.profile.hidePlayerFrameOutOfCombat then self:UpdatePlayerFrameVisibility() end
    if self.db.profile.hideTargetFrameOutOfCombat then self:UpdateTargetFrameVisibility() end
    if self:ShouldCollapseObjectiveTracker() then self:ExpandTrackerIfNeeded(true) end
    if self.db.profile.showSoftTargetTooltipOutOfCombat then self:UpdateTargetTooltip() end
end

function UITweaks:ScheduleDelayedVisibilityUpdate(skipDelay)
    if self.visibilityTimer then
        self.visibilityTimer:Cancel()
        self.visibilityTimer = nil
    end
    self.visibilityDelayActive = false
    if self:HasDelayedVisibilityFeatures() then
        local delay = tonumber(self.db.profile.combatVisibilityDelaySeconds)
        if skipDelay and not (InCombatLockdown and InCombatLockdown()) then
            self:ApplyDelayedVisibility()
        elseif delay <= 0 then
            self:ApplyDelayedVisibility()
        else
            self.visibilityDelayActive = true
            self:UpdatePlayerFrameVisibility()
            self:UpdateTargetFrameVisibility()
            self.visibilityTimer = C_Timer.NewTimer(delay, function()
                if not InCombatLockdown or not InCombatLockdown() then
                    self.visibilityDelayActive = false
                    self:ApplyDelayedVisibility()
                end
            end)
        end
    end
end

function UITweaks:OpenOptionsPanel()
    if InterfaceOptionsFrame_OpenToCategory and self.optionsFrame then
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    elseif AceConfigDialog then
        AceConfigDialog:Open(addonName)
        if AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[addonName] then
            self:EnsureReloadButtonForFrame(AceConfigDialog.OpenFrames[addonName])
        end
    end
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

function UITweaks:OpenMacroPanel()
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

function UITweaks:EnsureAddMacroForNextQuestInTracker()
    local getMacroIndexByName = _G["GetMacroIndexByName"]
    local createMacro = _G["CreateMacro"]
    local editMacro = _G["EditMacro"]
    local getMacroInfo = _G["GetMacroInfo"]
    local getNumMacros = _G["GetNumMacros"]
    if not (getMacroIndexByName and createMacro and editMacro and getMacroInfo and getNumMacros) then
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

    local hasNextMacro = ensureMacro(NEXT_QUEST_MACRO_NAME, NEXT_QUEST_MACRO_BODY)
    local hasPreviousMacro = ensureMacro(PREVIOUS_QUEST_MACRO_NAME, PREVIOUS_QUEST_MACRO_BODY)
    if hasNextMacro or hasPreviousMacro then
        self:OpenMacroPanel()
    end
    return hasNextMacro and hasPreviousMacro
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

function UITweaks:OpenCooldownViewerSettings()
    local loadAddOn = C_AddOns and C_AddOns.LoadAddOn or UIParentLoadAddOn
    if loadAddOn then
        local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_CooldownViewer"))
            or (IsAddOnLoaded and IsAddOnLoaded("Blizzard_CooldownViewer"))
        if not isLoaded then
            loadAddOn("Blizzard_CooldownViewer")
        end
    end
    local settingsFrame = _G.CooldownViewerSettings
    if settingsFrame and settingsFrame.Show then
        self:EnsureCooldownViewerSettingsHooked()
        settingsFrame:Show()
        self.auras.SelectCooldownViewerBuffsTab(self)
        C_Timer.After(0, function()
            self.auras.SelectCooldownViewerBuffsTab(self)
        end)
    end
end

function UITweaks:SelectCooldownViewerBuffsTab()
    return self.auras.SelectCooldownViewerBuffsTab(self)
end

function UITweaks:EnsureCooldownViewerMoveAllButton()
    return self.auras.EnsureCooldownViewerMoveAllButton(self)
end

function UITweaks:MoveCooldownViewerNotDisplayedToTracked()
    return self.auras.MoveCooldownViewerNotDisplayedToTracked(self)
end

function UITweaks:EnsureCooldownViewerSettingsHooked()
    return self.auras.EnsureCooldownViewerSettingsHooked(self)
end

function UITweaks:ApplyVisibilityState()
    self:UpdatePlayerFrameVisibility()
    self:UpdateTargetFrameVisibility()
    self:UpdateDamageMeterVisibility()
    self:UpdateTargetTooltip()
    self:UpdateChatTabsVisibility()
    self:UpdateChatMenuButtonVisibility()
    self:UpdateConsolePortTempAbilityFrameVisibility()
    self:UpdateGroupLootHistoryVisibility()
    self:UpdateMicroMenuVisibility()
    self:UpdateStanceButtonsVisibility()
    self:UpdateBackpackButtonVisibility()
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
