local addonName, addonTable = ...
local L = addonTable
local UITweaks = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local defaults = {
    profile = {
        chatMessageFadeAfterOverride = false,
        chatMessageFadeAfterSeconds = 5,
        suppressTalentAlert = false,
        collapseObjectiveTrackerInCombat = false,
        hideBuffFrame = false,
        hidePlayerFrameOutOfCombat = false,
        hideBackpackButton = false,
        hideDamageMeter = false,
        hideTargetFrameOutOfCombat = false,
        replaceTargetFrameWithTooltip = false,
        showSoftTargetTooltipOutOfCombat = false,
        hideChatTabs = false,
        hideChatMenuButton = false,
        hideStanceButtons = false,
        hideMicroMenuButtons = false,
        collapseObjectiveTrackerOnlyInstances = false,
        combatVisibilityDelaySeconds = 5,
        showOptionsOnReload = false,
        chatFontOverrideEnabled = false,
        chatFontSize = 16,
        consolePortBarSharing = false,
        openConsolePortActionBarConfigOnReload = false,
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

function UITweaks:ApplyChatLineFade()
    local frames = getChatFrames()
    if self.db.profile.chatMessageFadeAfterOverride then
        local seconds = sanitizeSeconds(self.db.profile.chatMessageFadeAfterSeconds) or defaultsProfile.chatMessageFadeAfterSeconds
        for _, frame in ipairs(frames) do
            if frame.SetTimeVisible then frame:SetTimeVisible(seconds) end
        end
    end
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

function UITweaks:CollapseTrackerIfNeeded()
    if self.db.profile.collapseObjectiveTrackerInCombat then
        local shouldCollapse = true
        if self.db.profile.collapseObjectiveTrackerOnlyInstances then
            local inInstance, instanceType = IsInInstance()
            if not (inInstance and (instanceType == "party" or instanceType == "raid")) then
                shouldCollapse = false
            end
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
    if self.db.profile.collapseObjectiveTrackerInCombat then
        if InCombatLockdown and InCombatLockdown() then
            self:CollapseTrackerIfNeeded()
        else
            self:ExpandTrackerIfNeeded()
        end
    end
end

local function hideBuffFrame()
    if BuffFrame then
        BuffFrame:Hide()
        if BuffFrame.CollapseAndExpandButton then
            BuffFrame.CollapseAndExpandButton:Hide()
        end
    end
end

local function ensureBuffFrameLoaded()
    if BuffFrame then return true end
    if UIParentLoadAddOn then
        local loaded = UIParentLoadAddOn("Blizzard_BuffFrame")
        if loaded and BuffFrame then return true end
    end
end

function UITweaks:ApplyBuffFrameHide(retry)
    if ensureBuffFrameLoaded() and BuffFrame and self.db.profile.hideBuffFrame then
        if not BuffFrame.UITweaksHooked then
            -- Keep the buff frame hidden after UI refreshes.
            BuffFrame:HookScript("OnShow", function()
                if UITweaks.db and UITweaks.db.profile.hideBuffFrame then hideBuffFrame() end
            end)
            BuffFrame.UITweaksHooked = true
        end
        hideBuffFrame()
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
    if _G.BagsBar and self.db.profile.hideBackpackButton then _G.BagsBar:Hide() end
end

function UITweaks:UpdateDamageMeterVisibility()
    if _G.DamageMeter and self.db.profile.hideDamageMeter then _G.DamageMeter:Hide() end
end

function UITweaks:UpdateChatTabsVisibility()
    self.hiddenChatTabs = self.hiddenChatTabs or {}
    for i = 1, NUM_CHAT_WINDOWS do
        local tabName = "ChatFrame" .. i .. "Tab"
        local tab = _G[tabName]
        if tab and not tab.UITweaksHooked then
            -- Keep tabs hidden even when hover/OnShow tries to reveal them.
            tab:HookScript("OnShow", function(frame)
                if UITweaks.db and UITweaks.db.profile.hideChatTabs then
                    frame:Hide()
                end
            end)
            tab:HookScript("OnEnter", function(frame)
                if UITweaks.db and UITweaks.db.profile.hideChatTabs then
                    frame:Hide()
                end
            end)
            tab.UITweaksHooked = true
        end
        if tab and tab:IsShown() and self.db.profile.hideChatTabs then
            tab:Hide()
            self.hiddenChatTabs[tabName] = true
        end
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
                    btn:Hide()
                end
            end)
            button.UITweaksHooked = true
        end
    end
end

function UITweaks:UpdateStanceButtonsVisibility()
    hookStanceButtons()
    local hide = self.db.profile.hideStanceButtons
    if hide then
        for _, stanceBar in ipairs(getStanceBars()) do
            if RegisterStateDriver and UnregisterStateDriver then
                -- Force-hide stance bar to avoid mount/combat refresh flashes.
                RegisterStateDriver(stanceBar, "visibility", "hide")
            end
            stanceBar:Hide()
        end
        local numButtons = NUM_STANCE_SLOTS or NUM_SHAPESHIFT_SLOTS or 10
        for i = 1, numButtons do
            local button = _G["StanceButton" .. i] or _G["ShapeshiftButton" .. i]
            if button then button:Hide() end
        end
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
        or self.db.profile.collapseObjectiveTrackerInCombat
        or self.db.profile.replaceTargetFrameWithTooltip
end

function UITweaks:ApplyDelayedVisibility()
    if self.db.profile.hideDamageMeter then
        if _G.DamageMeter then _G.DamageMeter:Hide() end
    end
    if self.db.profile.hidePlayerFrameOutOfCombat then self:UpdatePlayerFrameVisibility() end
    if self.db.profile.hideTargetFrameOutOfCombat then self:UpdateTargetFrameVisibility() end
    if self.db.profile.collapseObjectiveTrackerInCombat then self:ExpandTrackerIfNeeded(true) end
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
            chatSettings = {
                type = "group",
                name = "Chat",
                inline = true,
                order = 1,
                args = {
                    chatMessageFadeAfterOverride = toggleOption(
                        "chatMessageFadeAfterOverride",
                        "Chat Message Fade Override",
                        "Enable a custom duration for how long chat messages remain visible before fading.",
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
                        1.1,
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
                    chatFontOverrideEnabled = toggleOption(
                        "chatFontOverrideEnabled",
                        "Chat Font Size Override",
                        "Enable a custom chat window font size for all tabs.",
                        2,
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
                        2.1,
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
                    hideChatTabs = toggleOption(
                        "hideChatTabs",
                        "Hide Chat Tabs",
                        "Hide chat tab titles while leaving the windows visible.",
                        3,
                        function()
                            self:UpdateChatTabsVisibility()
                        end
                    ),
                    hideChatMenuButton = toggleOption(
                        "hideChatMenuButton",
                        "Hide Chat Bubble Button",
                        "Hide the chat button with the speech bubble icon.",
                        3.1,
                        function()
                            self:UpdateChatMenuButtonVisibility()
                        end
                    ),
                },
            },
            alerts = {
                type = "group",
                name = "Alerts",
                inline = true,
                order = 8,
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
            combatVisibility = {
                type = "group",
                name = "Combat",
                inline = true,
                order = 4,
                args = {
                    combatVisibilityDelaySeconds = rangeOption(
                        "combatVisibilityDelaySeconds",
                        "Delay Seconds",
                        "Delay before restoring frames after combat ends.",
                        0,
                        0,
                        20,
                        1,
                        function()
                            self:ScheduleDelayedVisibilityUpdate()
                        end
                    ),
                    hidePlayerFrameOutOfCombat = toggleOption(
                        "hidePlayerFrameOutOfCombat",
                        "Hide Player Frame Out of Combat",
                        "Hide the player unit frame outside combat and restore it after the shared delay.",
                        1,
                        function()
                            self:UpdatePlayerFrameVisibility()
                            self:ScheduleDelayedVisibilityUpdate()
                        end
                    ),
                    hideTargetFrameOutOfCombat = toggleOption(
                        "hideTargetFrameOutOfCombat",
                        "Hide Target Frame Out of Combat",
                        "Hide the target unit frame outside combat and restore it after the shared delay.",
                        2,
                        function()
                            self:UpdateTargetFrameVisibility()
                            self:ScheduleDelayedVisibilityUpdate()
                        end
                    ),
                    hideDamageMeter = toggleOption(
                        "hideDamageMeter",
                        "Hide Damage Meter Out of Combat",
                        "Hide the built-in damage meter frame after you leave combat (shares the delay with the player frame/objective tracker).",
                        3,
                        function()
                            self:UpdateDamageMeterVisibility()
                        end
                    ),
                    replaceTargetFrameWithTooltip = toggleOption(
                        "replaceTargetFrameWithTooltip",
                        "Replace Target Frame With Tooltip Out of Combat",
                        "Show the target tooltip when the target frame is not shown out of combat (useful for quest info like how many to kill).",
                        3.1,
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
                        3.2,
                        function(val)
                            if not val then
                                GameTooltip:Hide()
                            end
                        end
                    ),
                    objectiveTrackerVisibility = {
                        type = "group",
                        name = "Objective Tracker",
                        inline = true,
                        order = 4,
                        args = {
                            collapseObjectiveTrackerInCombat = toggleOption(
                                "collapseObjectiveTrackerInCombat",
                                "Collapse In Combat",
                                "Collapse the quest/objective tracker during combat and re-expand it after combat ends (shares the delay with the damage meter/player frame).",
                                0,
                                function()
                                    self:UpdateObjectiveTrackerState()
                                end,
                                nil,
                                "auto"
                            ),
                            collapseObjectiveTrackerOnlyInstances = {
                                type = "toggle",
                                name = "Only In Dungeons/Raids",
                                desc = "Only collapse the objective tracker while in dungeon or raid instances.",
                                width = "auto",
                                order = 1,
                                get = function()
                                    return self.db.profile.collapseObjectiveTrackerOnlyInstances
                                end,
                                set = function(_, val)
                                    self.db.profile.collapseObjectiveTrackerOnlyInstances = val
                                    self:UpdateObjectiveTrackerState()
                                end,
                                disabled = function()
                                    return not self.db.profile.collapseObjectiveTrackerInCombat
                                end,
                            },
                        },
                    },
                },
            },
            framesVisibility = {
                type = "group",
                name = "Frames",
                inline = true,
                order = 6,
                args = {
                    hideBuffFrame = toggleOption(
                        "hideBuffFrame",
                        "Hide Buff Frame",
                        "Hide the default player buff frame UI.",
                        1,
                        function()
                            self:ApplyBuffFrameHide()
                        end
                    ),
                    hideStanceButtons = toggleOption(
                        "hideStanceButtons",
                        "Hide Stance Buttons",
                        "Hide the Blizzard stance bar/buttons when you don't need them.",
                        2,
                        function()
                            self:UpdateStanceButtonsVisibility()
                        end
                    ),
                    hideBackpackButton = toggleOption(
                        "hideBackpackButton",
                        "Hide Bags Bar",
                        "Hide the entire Blizzard Bags Bar next to the action bars.",
                        3,
                        function()
                            self:UpdateBackpackButtonVisibility()
                        end
                    ),
                    hideMicroMenuButtons = toggleOption(
                        "hideMicroMenuButtons",
                        "Hide Micro Menu Buttons",
                        "Hide all micro menu buttons except the Dungeon Finder eye.",
                        4,
                        function()
                            self:UpdateMicroMenuVisibility()
                        end
                    ),
                },
            },
            consolePortSettings = {
                type = "group",
                name = "ConsolePort",
                inline = true,
                order = 7,
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
                order = 9,
                args = {
                    showOptionsOnReload = toggleOption(
                        "showOptionsOnReload",
                        "Open This Settings Menu on Reload/Login",
                        "Re-open the UI Tweaks options panel after /reload or login (useful for development).",
                        1
                    ),
                    openConsolePortActionBarConfigOnReload = toggleOption(
                        "openConsolePortActionBarConfigOnReload",
                        "Open ConsolePort Action Bar Config on Reload/Login",
                        "Open the ConsolePort action bar configuration window automatically after reload or login.",
                        2,
                        nil,
                        function()
                            return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                        end
                    ),
                    reloadUI = {
                        type = "execute",
                        name = "Reload",
                        desc = "Reload the interface to immediately apply changes.",
                        width = "full",
                        func = function() ReloadUI() end,
                        order = 3,
                    },
                },
            },
        },
    }
    AceConfig:RegisterOptionsTable(addonName, options)
    self.optionsFrame = AceConfigDialog:AddToBlizOptions(addonName, "UI Tweaks")
end

function UITweaks:OnEnable()
    self:CacheDefaultChatWindowTimes()
    self:ApplyChatLineFade()
    self:ApplyChatFontSize()
    self:HookTalentAlertFrames()
    self:ApplyBuffFrameHide()
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
    elseif addonName == "Blizzard_BuffFrame" then
        self:ApplyBuffFrameHide()
        self:ApplyVisibilityState()
        self:ScheduleDelayedVisibilityUpdate(true)
    elseif addonName == "Blizzard_ActionBarController" or addonName == "Blizzard_ActionBar" then
        self:UpdateStanceButtonsVisibility()
    elseif addonName == "Blizzard_ObjectiveTracker" then
        self:UpdateObjectiveTrackerState()
    end
end

function UITweaks:PLAYER_REGEN_DISABLED()
    if self.db.profile.collapseObjectiveTrackerInCombat then
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
