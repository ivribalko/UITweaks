local addonName, addonTable = ...
local L = addonTable
local UITweaks = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local defaults = {
    profile = {
        chatMessageFadeAfterOverride = false,
        chatMessageFadeAfterSeconds = 10,
        suppressTalentAlert = false,
        hideBuffFrame = false,
        hidePlayerFrameOutOfCombat = false,
        hideBackpackButton = false,
        hideDamageMeter = false,
        hidePetFrame = false,
        hideTargetFrameOutOfCombat = false,
        replaceTargetFrameWithTooltip = false,
        showSoftTargetTooltipOutOfCombat = false,
        hideChatTabs = false,
        hideChatMenuButton = false,
        transparentChatBackground = false,
        hideGroupLootHistoryFrame = false,
        hideStanceButtons = false,
        hideMicroMenuButtons = false,
        collapseObjectiveTrackerInRaids = false,
        collapseObjectiveTrackerInDungeons = false,
        collapseObjectiveTrackerEverywhereElse = false,
        combatVisibilityDelaySeconds = 5,
        showActionButtonAuraTimers = false,
        hideBlizzardCooldownViewer = false,
        showOptionsOnReload = false,
        chatFontOverrideEnabled = false,
        chatFontSize = 16,
        consolePortBarSharing = false,
        openConsolePortActionBarConfigOnReload = false,
        openCooldownViewerSettingsOnReload = false,
    },
}
local defaultsProfile = defaults.profile
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS or 10

local function sanitizeSeconds(value)
    local seconds = tonumber(value)
    if seconds and seconds > 0 then return seconds end
end

local function sanitizeFontSize(value)
    local size = tonumber(value)
    if size and size >= 8 and size <= 48 then return size end
end

local function getChatFrames()
    local frames = {}
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]
        if frame then frames[#frames + 1] = frame end
    end
    return frames
end

local function hookChatFrameHover(frame)
    if frame.UITweaksHoverHooked then return end
    frame:HookScript("OnEnter", function(chatFrame)
        if UITweaks.db and UITweaks.db.profile.chatMessageFadeAfterOverride then
            if chatFrame.SetFading then chatFrame:SetFading(false) end
            if chatFrame.ResetFadeTimer then chatFrame:ResetFadeTimer() end
        end
    end)
    frame:HookScript("OnLeave", function(chatFrame)
        if UITweaks.db and UITweaks.db.profile.chatMessageFadeAfterOverride then
            if chatFrame.SetFading then chatFrame:SetFading(true) end
            if chatFrame.ResetFadeTimer then chatFrame:ResetFadeTimer() end
        end
    end)
    frame.UITweaksHoverHooked = true
end

function UITweaks:CacheDefaultChatWindowTimes()
    if not self.defaultChatWindowTimeVisible then
        self.defaultChatWindowTimeVisible = {}
        for index, frame in ipairs(getChatFrames()) do
            if frame.GetTimeVisible then self.defaultChatWindowTimeVisible[index] = frame:GetTimeVisible() end
        end
    end
end

function UITweaks:CacheDefaultChatFonts()
    if not self.defaultChatFonts then
        self.defaultChatFonts = {}
        for index, frame in ipairs(getChatFrames()) do
            if frame.GetFont then
                local font, size, flags = frame:GetFont()
                self.defaultChatFonts[index] = {
                    font = font,
                    size = size,
                    flags = flags,
                }
            end
        end
    end
end

function UITweaks:ApplyChatFontSize()
    self:CacheDefaultChatFonts()
    local frames = getChatFrames()
    if self.db.profile.chatFontOverrideEnabled then
        local size = sanitizeFontSize(self.db.profile.chatFontSize) or defaultsProfile.chatFontSize
        for index, frame in ipairs(frames) do
            if frame.SetFont then
                local defaultFont = self.defaultChatFonts[index]
                local font = defaultFont and defaultFont.font or (frame.GetFont and select(1, frame:GetFont()))
                local flags = defaultFont and defaultFont.flags or (frame.GetFont and select(3, frame:GetFont()))
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

function UITweaks:ApplyChatLineFade()
    local frames = getChatFrames()
    if self.db.profile.chatMessageFadeAfterOverride then
        local seconds = sanitizeSeconds(self.db.profile.chatMessageFadeAfterSeconds) or defaultsProfile.chatMessageFadeAfterSeconds
        for _, frame in ipairs(frames) do
            if frame.SetTimeVisible then frame:SetTimeVisible(seconds) end
            if frame.SetFading then frame:SetFading(true) end
            hookChatFrameHover(frame)
        end
    end
end

function UITweaks:EnsureActionButtonAuraTimersLoaded()
    if self.ApplyActionButtonAuraTimers then return true end
    if C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("UITweaks_Auras")
    elseif LoadAddOn then
        LoadAddOn("UITweaks_Auras")
    end
    return self.ApplyActionButtonAuraTimers ~= nil
end

local talentAlertFrameNames = {
    "TalentMicroButtonAlert",
    "PlayerSpellsMicroButtonAlert",
}
local talentAlertFrameLookup = {}
for _, name in ipairs(talentAlertFrameNames) do
    talentAlertFrameLookup[name] = true
end
local suppressedTalentTextMatchers = {
    function(text)
        return text and text:lower():find("unspent talent points", 1, true)
    end,
}

local function hideTalentAlertOnShow(frame)
    if UITweaks.db and UITweaks.db.profile.suppressTalentAlert then frame:Hide() end
end

function UITweaks:HookTalentAlertFrames()
    self:EnsureTalentAlertHooks()
    for _, frameName in ipairs(talentAlertFrameNames) do
        local frame = _G[frameName]
        if frame then
            if not frame.UITweaksHooked then
                frame:HookScript("OnShow", hideTalentAlertOnShow)
                frame.UITweaksHooked = true
            end
            if self.db.profile.suppressTalentAlert then
                frame:Hide()
            end
        end
    end
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
    if not (BuffFrame and C_Timer and C_Timer.NewTicker) then return end
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
    elseif not retry and C_Timer and C_Timer.After then
        C_Timer.After(0.5, function() self:ApplyBuffFrameHide(true) end)
    end
end

local function UpdateCombatFrameVisibility(frame, profileKey, stateDriver, delayStateDriver)
    if frame and UITweaks.db and UITweaks.db.profile and UITweaks.db.profile[profileKey] then
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

function UITweaks:UpdatePlayerFrameVisibility()
    UpdateCombatFrameVisibility(PlayerFrame, "hidePlayerFrameOutOfCombat", "[combat] show; hide", "show")
end

function UITweaks:UpdateTargetFrameVisibility()
    UpdateCombatFrameVisibility(_G.TargetFrame, "hideTargetFrameOutOfCombat", "[combat,@target,exists] show; hide", "[@target,exists] show; hide")
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
    if _G.BagsBar and C_Timer and C_Timer.NewTicker then
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
        if not retry and C_Timer and C_Timer.After then
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
    if _G.DamageMeter and C_Timer and C_Timer.NewTicker then
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
    if self.db.profile.hideChatTabs and C_Timer and C_Timer.NewTicker then
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
    if _G.ChatFrameMenuButton and self.db.profile.hideChatMenuButton then
        if not _G.ChatFrameMenuButton.UITweaksHooked then
            -- Keep the menu button hidden even when UI code shows it.
            _G.ChatFrameMenuButton:HookScript("OnShow", function(frame)
                if UITweaks.db and UITweaks.db.profile.hideChatMenuButton then
                    frame:Hide()
                end
            end)
            _G.ChatFrameMenuButton.UITweaksHooked = true
        end
        _G.ChatFrameMenuButton:Hide()
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
    if self.db.profile.hideGroupLootHistoryFrame and ensureGroupLootHistoryLoaded() then
        local frame = _G.GroupLootHistoryFrame
        if frame then
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
end

function UITweaks:UpdatePetFrameVisibility()
    if self.db.profile.hidePetFrame and _G.PetFrame then
        local frame = _G.PetFrame
        if not frame.UITweaksHooked then
            frame:HookScript("OnShow", function(shownFrame)
                if UITweaks.db and UITweaks.db.profile.hidePetFrame then
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
    if self.db.profile.hideMicroMenuButtons then
        for _, button in ipairs(getMicroMenuButtons()) do
            local name = button and button.GetName and button:GetName() or ""
            if name ~= "QueueStatusButton" then
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
            stanceBar:Show()
        end
    end
    for _, button in ipairs(getStanceButtons()) do
        if button then
            button:SetAlpha(alpha)
            button:Show()
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
    if C_Timer and C_Timer.NewTicker then
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
end

function UITweaks:GetTargetTooltipUnit()
    local unit
    if UnitExists("target") then unit = "target" end
    if not unit and self.db.profile.showSoftTargetTooltipOutOfCombat then
        if UnitExists("softenemy") then unit = "softenemy" end
        if not unit and UnitExists("softfriend") then unit = "softfriend" end
        if not unit and UnitExists("softinteract") then unit = "softinteract" end
    end
    return unit
end

function UITweaks:UpdateTargetTooltip(forceHide)
    if GameTooltip and self.db.profile.replaceTargetFrameWithTooltip then
        if forceHide then
            GameTooltip:Hide()
            return
        end
        local unit = self:GetTargetTooltipUnit()
        local targetFrameShown = _G.TargetFrame and _G.TargetFrame.IsShown and _G.TargetFrame:IsShown()
        if unit and not targetFrameShown then
            GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
            GameTooltip:SetUnit(unit)
        elseif forceHide or not unit or targetFrameShown then
            GameTooltip:Hide()
        end
    end
end

function UITweaks:HasDelayedVisibilityFeatures()
    return self.db.profile.hideDamageMeter
        or self.db.profile.hidePlayerFrameOutOfCombat
        or self.db.profile.hideTargetFrameOutOfCombat
        or self:ShouldCollapseObjectiveTracker()
        or self.db.profile.replaceTargetFrameWithTooltip
end

function UITweaks:ApplyDelayedVisibility()
    if self.db.profile.hideDamageMeter then
        self:UpdateDamageMeterVisibility()
    end
    if self.db.profile.hidePlayerFrameOutOfCombat then self:UpdatePlayerFrameVisibility() end
    if self.db.profile.hideTargetFrameOutOfCombat then self:UpdateTargetFrameVisibility() end
    if self:ShouldCollapseObjectiveTracker() then self:ExpandTrackerIfNeeded(true) end
    if self.db.profile.replaceTargetFrameWithTooltip then self:UpdateTargetTooltip() end
end

function UITweaks:ScheduleDelayedVisibilityUpdate(skipDelay)
    if self.visibilityTimer then
        self.visibilityTimer:Cancel()
        self.visibilityTimer = nil
    end
    self.visibilityDelayActive = false
    if self:HasDelayedVisibilityFeatures() then
        if C_Timer and C_Timer.NewTimer then
            local delay = tonumber(self.db.profile.combatVisibilityDelaySeconds)
            if not delay or delay < 0 then delay = defaultsProfile.combatVisibilityDelaySeconds end
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
    if type(parent) == "table" then
        if parent.frame and parent.frame.GetObjectType then
            parent = parent.frame
        elseif parent.content and parent.content.GetObjectType then
            parent = parent.content
        end
    end

    if not (parent and parent.GetObjectType and parent:IsObjectType("Frame")) then
        return
    end
    if not parent or not CreateFrame then return end

    self.reloadButtons = self.reloadButtons or {}
    if self.reloadButtons[parent] then return self.reloadButtons[parent] end

    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetText("Reload")
    button:SetSize(120, 22)
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, -16)
    button:SetScript("OnClick", function() ReloadUI() end)
    button:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText("Reload the interface to immediately apply changes.")
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    button:Hide()

    self.reloadButtons[parent] = button
    parent:HookScript("OnShow", function() button:Show() end)
    parent:HookScript("OnHide", function() button:Hide() end)
    if parent:IsShown() then
        button:Show()
    end

    return button
end

function UITweaks:EnsureReloadButton()
    local parent = InterfaceOptionsFramePanelContainer or InterfaceOptionsFrame or self.optionsFrame
    local button = self:EnsureReloadButtonForFrame(parent)
    if not (button and self.optionsFrame) then return end

    self.optionsFrame:HookScript("OnShow", function() button:Show() end)
    self.optionsFrame:HookScript("OnHide", function() button:Hide() end)
    if self.optionsFrame:IsShown() then
        button:Show()
    else
        button:Hide()
    end
end

function UITweaks:GetConsolePortBarEnv()
    local relaTable = LibStub("RelaTable", true)
    if not relaTable then return end
    return relaTable("ConsolePort_Bar")
end

function UITweaks:GetConsolePortActionBarLoadout()
    local configFrame = _G.ConsolePortActionBarConfig
    if not configFrame then
        self:OpenConsolePortActionBarConfig()
        configFrame = _G.ConsolePortActionBarConfig
    end
    return configFrame
        and configFrame.SettingsContainer
        and configFrame.SettingsContainer.ScrollChild
        and configFrame.SettingsContainer.ScrollChild.Loadout
end

function UITweaks:SaveConsolePortActionBarProfile()
    local loadout = self:GetConsolePortActionBarLoadout()
    if not (loadout and loadout.OnSave) then
        return
    end
    loadout:OnSave({
        name = "UITweaksProfile",
        desc = "Saved by UI Tweaks",
    }, true, true)
    self:CloseConsolePortActionBarConfigIfNotPinned()
end

function UITweaks:RestoreConsolePortActionBarProfile()
    local env = self:GetConsolePortBarEnv()
    if not env then
        return
    end
    local preset = env("Presets/UITweaksProfile")
    if type(preset) ~= "table" then
        return
    end
    local loadout = self:GetConsolePortActionBarLoadout()
    if loadout and loadout.OnLoadPreset then
        loadout:OnLoadPreset(preset)
    end
    self:CloseConsolePortActionBarConfigIfNotPinned()
end

function UITweaks:OpenConsolePortActionBarConfig()
    if self.consolePortActionBarConfigOpened then return end
    local loadAddOn = C_AddOns and C_AddOns.LoadAddOn or UIParentLoadAddOn
    if loadAddOn then
        local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort_Bar"))
            or (IsAddOnLoaded and IsAddOnLoaded("ConsolePort_Bar"))
        if not isLoaded then
            loadAddOn("ConsolePort_Bar")
        end
    end
    local relaTable = LibStub("RelaTable", true)
    if not relaTable then return end
    local env = relaTable("ConsolePort_Bar")
    if not env or not env.TriggerEvent then return end
    env:TriggerEvent("OnConfigToggle")
    if _G.ConsolePortActionBarConfig then
        _G.ConsolePortActionBarConfig:Show()
    end
    self.consolePortActionBarConfigOpened = true
end

function UITweaks:OpenCooldownViewerSettings()
    if self.cooldownViewerSettingsOpened then return end
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
        settingsFrame:Show()
        self.cooldownViewerSettingsOpened = true
        self:EnsureCooldownViewerSettingsHooked()
        self:QueueCooldownViewerSettingsMove()
    end
end

local function getFrameText(frame)
    if not frame then return nil end
    if frame.GetText then return frame:GetText() end
    local textRegion = frame.Text or frame.Label or frame.Title
    if textRegion and textRegion.GetText then
        return textRegion:GetText()
    end
    return nil
end

local function traverseFrames(root, visitor)
    if not root or not root.GetChildren then return end
    local children = { root:GetChildren() }
    for _, child in ipairs(children) do
        if visitor(child) then return true end
        if traverseFrames(child, visitor) then return true end
    end
    return false
end

function UITweaks:FindCooldownViewerPanelByTitle(root, title)
    local match = nil
    traverseFrames(root, function(frame)
        local text = getFrameText(frame)
        if text == title then
            match = frame:GetParent()
            return true
        end
        return false
    end)
    return match
end

function UITweaks:ClickCooldownViewerButtonsByLabel(root, labels)
    local clicked = 0
    traverseFrames(root, function(frame)
        if clicked > 200 then return true end
        if frame.GetObjectType and frame:GetObjectType() == "Button" and frame.Click then
            local text = getFrameText(frame)
            if text and labels[text] then
                if frame.IsEnabled and not frame:IsEnabled() then
                    return false
                end
                frame:Click()
                clicked = clicked + 1
            end
        end
        return false
    end)
    return clicked
end

function UITweaks:SelectCooldownViewerBuffsTab()
    local settingsFrame = _G.CooldownViewerSettings
    if not settingsFrame then return end
    local tab = settingsFrame.AurasTab
    if not settingsFrame.SetDisplayMode then return end
    settingsFrame:SetDisplayMode((tab and tab.displayMode) or "auras")
    if settingsFrame.UpdateTabs then settingsFrame:UpdateTabs() end
end

function UITweaks:MoveCooldownViewerNotDisplayedToTracked()
    local settingsFrame = _G.CooldownViewerSettings
    if not settingsFrame then return end

    self:SelectCooldownViewerBuffsTab()

    local notDisplayedPanel = self:FindCooldownViewerPanelByTitle(settingsFrame, "Not Displayed")
    if not notDisplayedPanel then return end

    local clicked = self:ClickCooldownViewerButtonsByLabel(notDisplayedPanel, {
        ["Track"] = true,
        ["Add"] = true,
        ["Move"] = true,
        ["Display"] = true,
        ["Track All"] = true,
        ["Add All"] = true,
    })
    if clicked > 0 then
        self.cooldownViewerNotDisplayedMoved = true
    end
end

function UITweaks:QueueCooldownViewerSettingsMove()
    if self.cooldownViewerNotDisplayedMoved then return end
    if not C_Timer or not C_Timer.After then
        self:MoveCooldownViewerNotDisplayedToTracked()
        return
    end
    C_Timer.After(0, function()
        self:SelectCooldownViewerBuffsTab()
        self:MoveCooldownViewerNotDisplayedToTracked()
    end)
end

function UITweaks:EnsureCooldownViewerSettingsHooked()
    if self.cooldownViewerSettingsHooked then return end
    local settingsFrame = _G.CooldownViewerSettings
    if not settingsFrame or not settingsFrame.HookScript then return end
    settingsFrame:HookScript("OnShow", function()
        self:SelectCooldownViewerBuffsTab()
        self:QueueCooldownViewerSettingsMove()
    end)
    self.cooldownViewerSettingsHooked = true
end

function UITweaks:CloseConsolePortActionBarConfigIfNotPinned()
    if self.db.profile.openConsolePortActionBarConfigOnReload then
        return
    end
    if _G.ConsolePortActionBarConfig and _G.ConsolePortActionBarConfig:IsShown() then
        _G.ConsolePortActionBarConfig:Hide()
    end
end

function UITweaks:ApplyVisibilityState()
    self:UpdatePlayerFrameVisibility()
    self:UpdateTargetFrameVisibility()
    self:UpdateDamageMeterVisibility()
    self:UpdateTargetTooltip()
    self:UpdateChatTabsVisibility()
    self:UpdateChatMenuButtonVisibility()
    self:UpdateGroupLootHistoryVisibility()
    self:UpdatePetFrameVisibility()
    self:UpdateMicroMenuVisibility()
    self:UpdateStanceButtonsVisibility()
    self:UpdateBackpackButtonVisibility()
end

function UITweaks:EnsureTalentAlertHooks()
    if not self.microButtonAlertHooked and MainMenuMicroButton_ShowMicroAlert then
        hooksecurefunc("MainMenuMicroButton_ShowMicroAlert", function(alertFrame)
            if UITweaks.db and UITweaks.db.profile.suppressTalentAlert then
                if alertFrame and talentAlertFrameLookup[alertFrame:GetName() or ""] then
                    alertFrame:Hide()
                end
            end
        end)
        self.microButtonAlertHooked = true
    end
    if HelpTip and not self.helpTipHooked then
        hooksecurefunc(HelpTip, "Show", function(_, owner, info)
            if UITweaks.db and UITweaks.db.profile.suppressTalentAlert then
                local text = info and info.text
                if text then
                    for _, matcher in ipairs(suppressedTalentTextMatchers) do
                        if matcher(text) then
                            HelpTip:Hide(owner, info.text)
                            break
                        end
                    end
                end
            end
        end)
        self.helpTipHooked = true
    end
end

function UITweaks:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("UITweaksDB", defaults, true)
    local function getOption(key)
        return function()
            return self.db.profile[key]
        end
    end
    local function setOption(key, onSet)
        return function(_, val)
            self.db.profile[key] = val
            if onSet then
                onSet(val)
            end
        end
    end
    local function toggleOption(key, name, desc, order, onSet, disabledKey, width)
        local option = {
            type = "toggle",
            name = name,
            desc = desc,
            order = order,
            get = getOption(key),
            set = setOption(key, onSet),
            disabled = function()
                if type(disabledKey) == "function" then
                    return disabledKey()
                end
                return disabledKey and not self.db.profile[disabledKey]
            end,
        }
        if width ~= "auto" then option.width = width or "full" end
        return option
    end
    local function rangeOption(key, name, desc, order, minValue, maxValue, step, onSet, disabledKey, width)
        local option = {
            type = "range",
            name = name,
            desc = desc,
            order = order,
            min = minValue,
            max = maxValue,
            step = step,
            get = function() return self.db.profile[key] end,
            set = function(_, val) self.db.profile[key] = val if onSet then onSet(val) end end,
            disabled = function()
                if type(disabledKey) == "function" then
                    return disabledKey()
                end
                return disabledKey and not self.db.profile[disabledKey]
            end,
        }
        if width ~= "auto" then option.width = width or "full" end
        return option
    end
    local options = {
        name = "UI Tweaks",
        type = "group",
        args = {
            alerts = {
                type = "group",
                name = "Alerts",
                inline = true,
                order = 1,
                args = {
                    suppressTalentAlert = toggleOption(
                        "suppressTalentAlert",
                        "Hide Unspent Talent Alert",
                        "Prevent the 'You have unspent talent points' reminder from popping up.",
                        1,
                        function()
                            self:HookTalentAlertFrames()
                        end
                    ),
                },
            },
            actionTimers = {
                type = "group",
                name = "Button Auras",
                inline = true,
                order = 2,
                args = {
                    hideBlizzardCooldownViewer = toggleOption(
                        "hideBlizzardCooldownViewer",
                        "Hide Blizzard Cooldown Viewers",
                        "Set the Buff Bar, Buff Icon, Essential, and Utility cooldown viewer alpha to zero.",
                        1,
                        function()
                            if self:EnsureActionButtonAuraTimersLoaded() then
                                self:ApplyActionButtonAuraTimers()
                            end
                        end,
                        "showActionButtonAuraTimers"
                    ),
                    showActionButtonAuraTimers = toggleOption(
                        "showActionButtonAuraTimers",
                        "Show Action Button Aura Timers",
                        "Show buffs and debuffs timer (how long it will last) on action buttons.",
                        2,
                        function()
                            if self:EnsureActionButtonAuraTimersLoaded() then
                                self:ApplyActionButtonAuraTimers()
                            end
                        end
                    ),
                },
            },
            chatSettings = {
                type = "group",
                name = "Chat",
                inline = true,
                order = 3,
                args = {
                    chatMessageFadeAfterOverride = toggleOption(
                        "chatMessageFadeAfterOverride",
                        "Auto-Hide Chat Messages",
                        "Auto-Hide chat messages after a custom duration and reveal them on mouse over.",
                        1,
                        function()
                            self:ApplyChatLineFade()
                        end,
                        nil,
                        1.2
                    ),
                    chatMessageFadeAfterSeconds = rangeOption(
                        "chatMessageFadeAfterSeconds",
                        "Fade After Seconds",
                        "Number of seconds a chat message stays before fading when the override is enabled.",
                        2,
                        1,
                        60,
                        1,
                        function()
                            self:ApplyChatLineFade()
                        end,
                        function()
                            return not self.db.profile.chatMessageFadeAfterOverride
                        end,
                        1.8
                    ),
                    hideChatTabs = toggleOption(
                        "hideChatTabs",
                        "Auto-Hide Chat Tabs",
                        "Auto-Hide chat tab titles until you mouse over them.",
                        3,
                        function()
                            self:UpdateChatTabsVisibility()
                        end
                    ),
                    chatFontOverrideEnabled = toggleOption(
                        "chatFontOverrideEnabled",
                        "Set Chat Font Size",
                        "Enable a custom chat window font size for all tabs.",
                        4,
                        function()
                            self:ApplyChatFontSize()
                        end,
                        nil,
                        1.2
                    ),
                    chatFontSize = rangeOption(
                        "chatFontSize",
                        "Font Size",
                        "Font size to use when the override is enabled.",
                        5,
                        8,
                        48,
                        1,
                        function()
                            self:ApplyChatFontSize()
                        end,
                        function()
                            return not self.db.profile.chatFontOverrideEnabled
                        end,
                        1.8
                    ),
                    hideChatMenuButton = toggleOption(
                        "hideChatMenuButton",
                        "Hide Chat Bubble Button",
                        "Hide the chat button with the speech bubble icon.",
                        6,
                        function()
                            self:UpdateChatMenuButtonVisibility()
                        end
                    ),
                    transparentChatBackground = toggleOption(
                        "transparentChatBackground",
                        "Transparent Chat Background",
                        "Set the chat background alpha to zero.",
                        7,
                        function()
                            self:ApplyChatBackgroundAlpha()
                        end
                    ),
                },
            },
            combatVisibility = {
                type = "group",
                name = "Combat",
                inline = true,
                order = 4,
                args = {
                    combatVisibilityDelaySeconds = rangeOption(
                        "combatVisibilityDelaySeconds",
                        "Delay After Combat Seconds",
                        "Delay after combat seconds before restoring frames.",
                        1,
                        0,
                        20,
                        1,
                        function()
                            self:ScheduleDelayedVisibilityUpdate()
                        end
                    ),
                    hideDamageMeter = toggleOption(
                        "hideDamageMeter",
                        "Auto-Hide Damage Meter Out of Combat",
                        "Auto-Hide the built-in damage meter frame after combat until you mouse over it.",
                        2,
                        function()
                            self:UpdateDamageMeterVisibility()
                        end
                    ),
                    objectiveTrackerVisibility = {
                        type = "group",
                        name = "Collapse Objective Tracker",
                        inline = true,
                        order = 3,
                        args = {
                            collapseObjectiveTrackerInRaids = {
                                type = "toggle",
                                name = "In Raids",
                                desc = "Collapse the objective tracker in combat while in raid instances.",
                                width = "auto",
                                order = 1,
                                get = function()
                                    return self.db.profile.collapseObjectiveTrackerInRaids
                                end,
                                set = function(_, val)
                                    self.db.profile.collapseObjectiveTrackerInRaids = val
                                    self:UpdateObjectiveTrackerState()
                                end,
                            },
                            collapseObjectiveTrackerInDungeons = {
                                type = "toggle",
                                name = "In Dungeons",
                                desc = "Collapse the objective tracker in combat while in dungeon instances.",
                                width = "auto",
                                order = 2,
                                get = function()
                                    return self.db.profile.collapseObjectiveTrackerInDungeons
                                end,
                                set = function(_, val)
                                    self.db.profile.collapseObjectiveTrackerInDungeons = val
                                    self:UpdateObjectiveTrackerState()
                                end,
                            },
                            collapseObjectiveTrackerEverywhereElse = {
                                type = "toggle",
                                name = "Everywhere Else",
                                desc = "Collapse the objective tracker in combat everywhere else (open world, scenarios, PvP, etc.).",
                                width = "auto",
                                order = 3,
                                get = function()
                                    return self.db.profile.collapseObjectiveTrackerEverywhereElse
                                end,
                                set = function(_, val)
                                    self.db.profile.collapseObjectiveTrackerEverywhereElse = val
                                    self:UpdateObjectiveTrackerState()
                                end,
                            },
                        },
                    },
                    hidePlayerFrameOutOfCombat = toggleOption(
                        "hidePlayerFrameOutOfCombat",
                        "Hide Player Frame Out of Combat",
                        "Hide the player unit frame outside combat and restore it after the delay.",
                        4,
                        function()
                            self:UpdatePlayerFrameVisibility()
                            self:ScheduleDelayedVisibilityUpdate()
                        end
                    ),
                    hideTargetFrameOutOfCombat = toggleOption(
                        "hideTargetFrameOutOfCombat",
                        "Hide Target Frame Out of Combat",
                        "Hide the target unit frame outside combat and restore it after the delay.",
                        5,
                        function()
                            self:UpdateTargetFrameVisibility()
                            self:ScheduleDelayedVisibilityUpdate()
                        end
                    ),
                    replaceTargetFrameWithTooltip = toggleOption(
                        "replaceTargetFrameWithTooltip",
                        "Replace Target Frame With Tooltip Out of Combat",
                        "Show the target tooltip when the target frame is not shown out of combat (useful for quest info like how many to kill).",
                        6,
                        function(val)
                            if not val then
                                GameTooltip:Hide()
                            end
                        end
                    ),
                    showSoftTargetTooltipOutOfCombat = toggleOption(
                        "showSoftTargetTooltipOutOfCombat",
                        "Show Tooltip For Soft (Action) Target Out of Combat",
                        "Also display the ConsolePort soft (action) target's tooltip while out of combat.",
                        7,
                        function(val)
                            if not val then
                                GameTooltip:Hide()
                            end
                        end
                    ),
                },
            },
            framesVisibility = {
                type = "group",
                name = "Frames",
                inline = true,
                order = 6,
                args = {
                    hideBackpackButton = toggleOption(
                        "hideBackpackButton",
                        "Auto-Hide Bags Bar",
                        "Auto-Hide the Blizzard Bags Bar until you mouse over it.",
                        1,
                        function()
                            self:UpdateBackpackButtonVisibility()
                        end
                    ),
                    hideBuffFrame = toggleOption(
                        "hideBuffFrame",
                        "Auto-Hide Buff Frame",
                        "Auto-Hide the default player buff frame until you mouse over it.",
                        2,
                        function()
                            self:ApplyBuffFrameHide()
                        end
                    ),
                    hideStanceButtons = toggleOption(
                        "hideStanceButtons",
                        "Auto-Hide Stance Buttons",
                        "Auto-Hide the Blizzard stance bar/buttons until you mouse over them.",
                        3,
                        function()
                            self:UpdateStanceButtonsVisibility()
                        end
                    ),
                    hideGroupLootHistoryFrame = toggleOption(
                        "hideGroupLootHistoryFrame",
                        "Hide Group Loot History",
                        "Hide the group loot history frame.",
                        4,
                        function()
                            self:UpdateGroupLootHistoryVisibility()
                        end
                    ),
                    hideMicroMenuButtons = toggleOption(
                        "hideMicroMenuButtons",
                        "Hide Micro Menu Buttons",
                        "Hide all micro menu buttons except the Dungeon Finder eye.",
                        5,
                        function()
                            self:UpdateMicroMenuVisibility()
                        end
                    ),
                    hidePetFrame = toggleOption(
                        "hidePetFrame",
                        "Hide Pet Frame",
                        "Hide the pet unit frame.",
                        6,
                        function()
                            self:UpdatePetFrameVisibility()
                        end
                    ),
                },
            },
            consolePortSettings = {
                type = "group",
                name = "ConsolePort",
                inline = true,
                order = 5,
                args = {
                    consolePortBarSharing = toggleOption(
                        "consolePortBarSharing",
                        "Share ConsolePort Action Bar Settings For All Characters",
                        "Warning: This will overwrite your ConsolePort UI settings. When enabled, UI Tweaks saves your current ConsolePort action bar layout in ConsolePort's own presets as \"UITweaksProfile\" every time you log out, then restores that same preset automatically the next time you log in on any character. This keeps your ConsolePort action bar layout, optional bar settings, and action page logic consistent across characters without any manual export/import.",
                        1,
                        nil,
                        function()
                            return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                        end
                    ),
                },
            },
            service = {
                type = "group",
                name = "Service",
                inline = true,
                order = 7,
                args = {
                    openConsolePortActionBarConfigOnReload = toggleOption(
                        "openConsolePortActionBarConfigOnReload",
                        "Open ConsolePort Action Bar Config on Reload/Login",
                        "Open the ConsolePort action bar configuration window automatically after reload or login.",
                        1,
                        nil,
                        function()
                            return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                        end
                    ),
                    openCooldownViewerSettingsOnReload = toggleOption(
                        "openCooldownViewerSettingsOnReload",
                        "Open Cooldown Viewer Settings on Reload/Login",
                        "Open the Cooldown Viewer settings window on Buffs tab after reload or login.",
                        2
                    ),
                    showOptionsOnReload = toggleOption(
                        "showOptionsOnReload",
                        "Open This Settings Menu on Reload/Login",
                        "Re-open the UI Tweaks options panel after /reload or login (useful for development).",
                        3
                    ),
                },
            },
        },
    }
    AceConfig:RegisterOptionsTable(addonName, options)
    self.optionsFrame = AceConfigDialog:AddToBlizOptions(addonName, "UI Tweaks")
    self:EnsureReloadButton()
end

function UITweaks:OnEnable()
    self:CacheDefaultChatWindowTimes()
    self:ApplyChatLineFade()
    self:ApplyChatFontSize()
    self:ApplyChatBackgroundAlpha()
    self:HookTalentAlertFrames()
    self:ApplyBuffFrameHide()
    if self.db.profile.showActionButtonAuraTimers then
        if self:EnsureActionButtonAuraTimersLoaded() then
            self:ApplyActionButtonAuraTimers()
        end
    end
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
    if self.db.profile.openConsolePortActionBarConfigOnReload then
        self:OpenConsolePortActionBarConfig()
    end
    if self.db.profile.openCooldownViewerSettingsOnReload then
        self:OpenCooldownViewerSettings()
    end
    if self.db.profile.showOptionsOnReload then
        if C_Timer and C_Timer.After then
            C_Timer.After(1, function() self:OpenOptionsPanel() end)
        else
            self:OpenOptionsPanel()
        end
    end
end

function UITweaks:ADDON_LOADED(event, addonName)
    if addonName == "Blizzard_TalentUI" or addonName == "Blizzard_PlayerSpells" then
        self:HookTalentAlertFrames()
    elseif addonName == "Blizzard_CooldownViewer" then
        self:EnsureCooldownViewerSettingsHooked()
        if self.db.profile.openCooldownViewerSettingsOnReload then
            self:OpenCooldownViewerSettings()
        end
    elseif addonName == "Blizzard_BuffFrame" then
        self:ApplyBuffFrameHide()
        if self.db.profile.showActionButtonAuraTimers then
            if self:EnsureActionButtonAuraTimersLoaded() then
                self:ApplyActionButtonAuraTimers()
            end
        end
        self:ApplyVisibilityState()
        self:ScheduleDelayedVisibilityUpdate(true)
    elseif addonName == "Blizzard_GroupLootHistory" then
        self:UpdateGroupLootHistoryVisibility()
    elseif addonName == "Blizzard_ActionBarController" or addonName == "Blizzard_ActionBar" then
        self:UpdateStanceButtonsVisibility()
        if self.db.profile.showActionButtonAuraTimers then
            if self:EnsureActionButtonAuraTimersLoaded() then
                self:BuildActionButtonCache()
                self:RefreshActionButtonAuraOverlays()
            end
        end
    elseif addonName == "Blizzard_ObjectiveTracker" then
        self:UpdateObjectiveTrackerState()
    elseif addonName == "ConsolePort"
        or addonName == "ConsolePort_ActionBar"
        or addonName == "ConsolePortActionBar"
        or addonName == "ConsolePortGroupCrossbar"
        or addonName == "ConsolePort_GroupCrossbar"
    then
        if self.db.profile.showActionButtonAuraTimers then
            if self:EnsureActionButtonAuraTimersLoaded() then
                self:BuildActionButtonCache()
                self:RefreshActionButtonAuraOverlays()
            end
        end
    end
end

function UITweaks:PLAYER_REGEN_DISABLED()
    if self:ShouldCollapseObjectiveTracker() then
        self:CollapseTrackerIfNeeded()
    end
    self:UpdatePlayerFrameVisibility()
    self:UpdateTargetFrameVisibility()
    self:UpdateDamageMeterVisibility()
    if self.db.profile.replaceTargetFrameWithTooltip then GameTooltip:Hide() end
    if self.visibilityTimer then
        self.visibilityTimer:Cancel()
        self.visibilityTimer = nil
    end
    self.visibilityDelayActive = false
end

function UITweaks:PLAYER_REGEN_ENABLED()
    self:ScheduleDelayedVisibilityUpdate()
end

function UITweaks:PLAYER_ENTERING_WORLD()
    self:ApplyBuffFrameHide()
    self:ApplyVisibilityState()
    self:ScheduleDelayedVisibilityUpdate(true)
    if self.db.profile.openConsolePortActionBarConfigOnReload then
        self:OpenConsolePortActionBarConfig()
    end
    if self.db.profile.openCooldownViewerSettingsOnReload then
        self:OpenCooldownViewerSettings()
    end
    if self.db.profile.consolePortBarSharing then
        self:RestoreConsolePortActionBarProfile()
    end
end

function UITweaks:PLAYER_LOGOUT()
    if self.db.profile.consolePortBarSharing then
        self:SaveConsolePortActionBarProfile()
    end
end

function UITweaks:PLAYER_TARGET_CHANGED()
    self:UpdateTargetTooltip()
    self:UpdateTargetFrameVisibility()
end

function UITweaks:PLAYER_SOFT_ENEMY_CHANGED()
    self:UpdateTargetTooltip()
end

function UITweaks:PLAYER_SOFT_INTERACT_CHANGED()
    self:UpdateTargetTooltip()
end

function UITweaks:LOOT_OPENED()
    self:UpdateTargetTooltip(true)
end

function UITweaks:LOOT_CLOSED()
    self:UpdateTargetTooltip()
end
