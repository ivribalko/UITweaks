local addonName, addonTable = ...
local L = addonTable

local UITweaks = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local defaults = {
    profile = {
        chatLineFadeEnabled = false,
        chatLineFadeSeconds = 5,
        suppressTalentAlert = false,
        collapseObjectiveTrackerInCombat = false,
        hideBuffFrame = false,
        hidePlayerFrameOutOfCombat = false,
        hideBackpackButton = false,
        hideDamageMeter = false,
        hideTargetFrameOutOfCombat = false,
        showTargetTooltipOutOfCombat = false,
        hideChatTabs = false,
        hideChatMenuButton = false,
        hideStanceButtons = false,
        collapseObjectiveTrackerOnlyInstances = false,
        visibilityDelaySeconds = 5,
        showOptionsOnReload = false,
        chatFontOverrideEnabled = false,
        chatFontSize = 16,
    }
}
local defaultsProfile = defaults.profile

local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS or 10

local function sanitizeSeconds(value)
    local seconds = tonumber(value)
    if seconds and seconds > 0 then
        return seconds
    end
end

local function sanitizeFontSize(value)
    local size = tonumber(value)
    if size and size >= 8 and size <= 48 then
        return size
    end
end

local function getChatFrames()
    local frames = {}
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]
        if frame then
            table.insert(frames, frame)
        end
    end
    return frames
end

function UITweaks:CacheDefaultChatWindowTimes()
    if self.defaultChatWindowTimeVisible then
        return
    end

    self.defaultChatWindowTimeVisible = {}
    for index, frame in ipairs(getChatFrames()) do
        if frame.GetTimeVisible then
            self.defaultChatWindowTimeVisible[index] = frame:GetTimeVisible()
        end
    end
end

function UITweaks:CacheDefaultChatFonts()
    if self.defaultChatFonts then
        return
    end

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

function UITweaks:ApplyChatFontSize()
    self:CacheDefaultChatFonts()
    local frames = getChatFrames()

    if not self.db.profile.chatFontOverrideEnabled then
        return
    end

    local size = sanitizeFontSize(self.db.profile.chatFontSize) or defaultsProfile.chatFontSize
    for index, frame in ipairs(frames) do
        if frame.SetFont then
            local defaultFont = self.defaultChatFonts[index]
            local font = defaultFont and defaultFont.font or (frame.GetFont and select(1, frame:GetFont()))
            local flags = defaultFont and defaultFont.flags or (frame.GetFont and select(3, frame:GetFont()))
            if font then
                frame:SetFont(font, size, flags)
            end
        end
    end
end

function UITweaks:ApplyChatLineFade()
    local frames = getChatFrames()
    if not self.db.profile.chatLineFadeEnabled then
        return
    end

    local seconds = sanitizeSeconds(self.db.profile.chatLineFadeSeconds) or defaultsProfile.chatLineFadeSeconds
    for _, frame in ipairs(frames) do
        if frame.SetTimeVisible then
            frame:SetTimeVisible(seconds)
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
    if UITweaks.db and UITweaks.db.profile.suppressTalentAlert then
        frame:Hide()
    end
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
        if loaded and ObjectiveTrackerFrame then
            return true
        end
    end
end

function UITweaks:IsObjectiveTrackerCollapsed()
    if ObjectiveTrackerFrame then
        if ObjectiveTrackerFrame.IsCollapsed then
            return ObjectiveTrackerFrame:IsCollapsed()
        elseif ObjectiveTrackerFrame.collapsed ~= nil then
            return ObjectiveTrackerFrame.collapsed
        end
    end
end

function UITweaks:CollapseTrackerIfNeeded()
    if not self.db.profile.collapseObjectiveTrackerInCombat then
        return
    end

    if self.db.profile.collapseObjectiveTrackerOnlyInstances then
        local inInstance, instanceType = IsInInstance()
        if not (inInstance and (instanceType == "party" or instanceType == "raid")) then
            return
        end
    end

    if not self:EnsureObjectiveTrackerLoaded() then
        return
    end

    if not self:IsObjectiveTrackerCollapsed() then
        collapseObjectiveTracker()
        self.trackerCollapsedByAddon = true
    else
        self.trackerCollapsedByAddon = false
    end
end

function UITweaks:ExpandTrackerIfNeeded(force)
    if not self:EnsureObjectiveTrackerLoaded() then
        return
    end

    if force or self.trackerCollapsedByAddon then
        expandObjectiveTracker()
        self.trackerCollapsedByAddon = false
    end
end

function UITweaks:UpdateObjectiveTrackerState()
    if not self.db.profile.collapseObjectiveTrackerInCombat then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        self:CollapseTrackerIfNeeded()
    else
        self:ExpandTrackerIfNeeded()
    end
end

local function hideBuffFrame()
    if not BuffFrame then
        return
    end
    BuffFrame:Hide()
    if BuffFrame.CollapseAndExpandButton then
        BuffFrame.CollapseAndExpandButton:Hide()
    end
end

local function ensureBuffFrameLoaded()
    if BuffFrame then
        return true
    end

    if UIParentLoadAddOn then
        local loaded = UIParentLoadAddOn("Blizzard_BuffFrame")
        if loaded and BuffFrame then
            return true
        end
    end
end

function UITweaks:ApplyBuffFrameHide(retry)
    if not ensureBuffFrameLoaded() or not BuffFrame then
        if not retry and C_Timer and C_Timer.After then
            C_Timer.After(0.5, function()
                self:ApplyBuffFrameHide(true)
            end)
        end
        return
    end

    if self.db.profile.hideBuffFrame then
        if BuffFrame and not BuffFrame.UITweaksHooked then
            -- Keep the buff frame hidden after UI refreshes.
            BuffFrame:HookScript("OnShow", function()
                if UITweaks.db and UITweaks.db.profile.hideBuffFrame then
                    hideBuffFrame()
                end
            end)
            BuffFrame.UITweaksHooked = true
        end
        hideBuffFrame()
    end
end

function UITweaks:UpdatePlayerFrameVisibility(forceShow)
    if not PlayerFrame then
        return
    end

    if not self.db.profile.hidePlayerFrameOutOfCombat then
        return
    end

    if not PlayerFrame.UITweaksHooked then
        -- Keep the player frame hidden when addons or quest updates try to show it.
        PlayerFrame:HookScript("OnShow", function(frame)
            if UITweaks.db and UITweaks.db.profile.hidePlayerFrameOutOfCombat then
                if not (InCombatLockdown and InCombatLockdown()) then
                    frame:Hide()
                end
            end
        end)
        PlayerFrame.UITweaksHooked = true
    end

    if RegisterStateDriver then
        if InCombatLockdown and InCombatLockdown() then
            return
        end
        RegisterStateDriver(PlayerFrame, "visibility", "[combat] show; hide")
    end
    if not (InCombatLockdown and InCombatLockdown()) then
        PlayerFrame:Hide()
    end
end

function UITweaks:UpdateTargetFrameVisibility(forceShow)
    local frame = _G.TargetFrame
    if not frame then
        return
    end

    local inCombat = InCombatLockdown and InCombatLockdown()

    if not self.db.profile.hideTargetFrameOutOfCombat then
        return
    end

    if forceShow or inCombat then
        if UnitExists("target") or forceShow then
            frame:Show()
        end
    else
        frame:Hide()
    end
end

function UITweaks:UpdateBackpackButtonVisibility()
    local bagBar = _G.BagsBar
    if not bagBar then
        return
    end

    if not self.db.profile.hideBackpackButton then
        return
    end

    bagBar:Hide()
end

function UITweaks:UpdateDamageMeterVisibility(forceShow)
    local frame = _G.DamageMeter
    if not frame then
        return
    end

    if not self.db.profile.hideDamageMeter then
        return
    end

    if forceShow then
        frame:Show()
    else
        frame:Hide()
    end
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
    if not self.db.profile.hideChatMenuButton then
        return
    end

    local button = _G.ChatFrameMenuButton
    if not button then
        return
    end

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

local function getStanceBars()
    local bars = {}
    local stanceBar = _G.StanceBar
    local shapeshiftBar = _G.ShapeshiftBarFrame
    if stanceBar then
        table.insert(bars, stanceBar)
    end
    if shapeshiftBar and shapeshiftBar ~= stanceBar then
        table.insert(bars, shapeshiftBar)
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

    if not hide then
        return
    end

    for _, stanceBar in ipairs(getStanceBars()) do
        if RegisterStateDriver and UnregisterStateDriver then
            if hide then
                -- Force-hide stance bar to avoid mount/combat refresh flashes.
                RegisterStateDriver(stanceBar, "visibility", "hide")
            else
                UnregisterStateDriver(stanceBar, "visibility")
            end
        end
        if hide then
            stanceBar:Hide()
        else
            stanceBar:Show()
        end
    end

    local numButtons = NUM_STANCE_SLOTS or NUM_SHAPESHIFT_SLOTS or 10
    for i = 1, numButtons do
        local button = _G["StanceButton" .. i] or _G["ShapeshiftButton" .. i]
        if button then
            if hide then
                button:Hide()
            else
                button:Show()
            end
        end
    end
end

function UITweaks:UpdateTargetTooltip(forceHide)
    if not GameTooltip then
        return
    end

    if not self.db.profile.showTargetTooltipOutOfCombat then
        return
    end

    if UnitExists("target") and not (InCombatLockdown and InCombatLockdown()) then
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
        GameTooltip:SetUnit("target")
    elseif forceHide or not UnitExists("target") then
        GameTooltip:Hide()
    end
end

function UITweaks:HasDelayedVisibilityFeatures()
    return self.db.profile.hideDamageMeter
        or self.db.profile.hidePlayerFrameOutOfCombat
        or self.db.profile.hideTargetFrameOutOfCombat
        or self.db.profile.collapseObjectiveTrackerInCombat
        or self.db.profile.showTargetTooltipOutOfCombat
end

function UITweaks:ApplyDelayedVisibility()
    if self.db.profile.hideDamageMeter then
        local frame = _G.DamageMeter
        if frame then
            frame:Hide()
        end
    end

    if self.db.profile.hidePlayerFrameOutOfCombat then
        self:UpdatePlayerFrameVisibility()
    end

    if self.db.profile.hideTargetFrameOutOfCombat then
        self:UpdateTargetFrameVisibility()
    end

    if self.db.profile.collapseObjectiveTrackerInCombat then
        self:ExpandTrackerIfNeeded(true)
    end

    if self.db.profile.showTargetTooltipOutOfCombat then
        self:UpdateTargetTooltip()
    end
end

function UITweaks:ScheduleDelayedVisibilityUpdate()
    if self.visibilityTimer then
        self.visibilityTimer:Cancel()
        self.visibilityTimer = nil
    end

    if not self:HasDelayedVisibilityFeatures() then
        return
    end

    if C_Timer and C_Timer.NewTimer then
        local delay = self.db.profile.visibilityDelaySeconds or defaultsProfile.visibilityDelaySeconds
        self.visibilityTimer = C_Timer.NewTimer(delay, function()
            if not InCombatLockdown or not InCombatLockdown() then
                self:ApplyDelayedVisibility()
            end
        end)
    end
end

function UITweaks:OpenOptionsPanel()
    if InterfaceOptionsFrame_OpenToCategory and self.optionsFrame then
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
        return
    end

    if AceConfigDialog then
        AceConfigDialog:Open(addonName)
    end
end

function UITweaks:ApplyVisibilityState(forceShow)
    self:UpdatePlayerFrameVisibility(forceShow)
    self:UpdateTargetFrameVisibility(forceShow)
    self:UpdateDamageMeterVisibility(forceShow)
    self:UpdateTargetTooltip()
    self:UpdateChatTabsVisibility()
    self:UpdateChatMenuButtonVisibility()
    self:UpdateStanceButtonsVisibility()
    self:UpdateBackpackButtonVisibility()
end

function UITweaks:EnsureTalentAlertHooks()
    if not self.microButtonAlertHooked and MainMenuMicroButton_ShowMicroAlert then
        hooksecurefunc("MainMenuMicroButton_ShowMicroAlert", function(alertFrame)
            if not (UITweaks.db and UITweaks.db.profile.suppressTalentAlert) then
                return
            end
            if alertFrame and talentAlertFrameLookup[alertFrame:GetName() or ""] then
                alertFrame:Hide()
            end
        end)
        self.microButtonAlertHooked = true
    end

    if HelpTip and not self.helpTipHooked then
        hooksecurefunc(HelpTip, "Show", function(_, owner, info)
            if not (UITweaks.db and UITweaks.db.profile.suppressTalentAlert) then
                return
            end
            local text = info and info.text
            if not text then
                return
            end
            for _, matcher in ipairs(suppressedTalentTextMatchers) do
                if matcher(text) then
                    HelpTip:Hide(owner, info.text)
                    break
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
                return disabledKey and not self.db.profile[disabledKey]
            end,
        }

        if width ~= "auto" then
            option.width = width or "full"
        end

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
            get = function()
                return self.db.profile[key]
            end,
            set = function(_, val)
                self.db.profile[key] = val
                if onSet then
                    onSet(val)
                end
            end,
            disabled = function()
                return disabledKey and not self.db.profile[disabledKey]
            end,
        }

        if width ~= "auto" then
            option.width = width or "full"
        end

        return option
    end

    local options = {
        name = "UI Tweaks",
        type = "group",
        args = {
            chatSettings = {
                type = "group",
                name = "Chat Settings",
                inline = true,
                order = 1,
                args = {
                    chatLineFadeEnabled = toggleOption(
                        "chatLineFadeEnabled",
                        "Chat Line Fade Override",
                        "Enable a custom duration for how long chat lines remain visible before fading.",
                        1,
                        function()
                            self:ApplyChatLineFade()
                        end,
                        nil,
                        1.2
                    ),
                    chatLineFadeSeconds = rangeOption(
                        "chatLineFadeSeconds",
                        "Fade Seconds",
                        "Number of seconds a chat line stays before fading when the override is enabled.",
                        1.1,
                        1,
                        60,
                        1,
                        function()
                            self:ApplyChatLineFade()
                        end,
                        "chatLineFadeEnabled",
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
                        "chatFontOverrideEnabled",
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
                        "Hide Chat Menu Button",
                        "Hide the chat menu button with the speech bubble icon.",
                        3.1,
                        function()
                            self:UpdateChatMenuButtonVisibility()
                        end
                    ),
                },
            },
            suppressTalentAlert = toggleOption(
                "suppressTalentAlert",
                "Hide Talent Alert",
                "Prevent the 'You have unspent talent points' reminder from popping up.",
                2,
                function()
                    self:HookTalentAlertFrames()
                end
            ),
            hideBuffFrame = toggleOption(
                "hideBuffFrame",
                "Hide Buff Frame",
                "Hide the default player buff frame UI.",
                3,
                function()
                    self:ApplyBuffFrameHide()
                end
            ),
            combatVisibility = {
                type = "group",
                name = "Combat Visibility",
                inline = true,
                order = 4,
                args = {
                    visibilityDelaySeconds = rangeOption(
                        "visibilityDelaySeconds",
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
                            self:UpdatePlayerFrameVisibility(true)
                            self:ScheduleDelayedVisibilityUpdate()
                        end
                    ),
                    hideTargetFrameOutOfCombat = toggleOption(
                        "hideTargetFrameOutOfCombat",
                        "Hide Target Frame Out of Combat",
                        "Hide the target unit frame outside combat and restore it after the shared delay.",
                        2,
                        function()
                            self:UpdateTargetFrameVisibility(true)
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
                            collapseObjectiveTrackerOnlyInstances = toggleOption(
                                "collapseObjectiveTrackerOnlyInstances",
                                "Only In Dungeons/Raids",
                                "Only collapse the objective tracker while in dungeon or raid instances.",
                                1,
                                function()
                                    self:UpdateObjectiveTrackerState()
                                end,
                                "collapseObjectiveTrackerInCombat",
                                "auto"
                            ),
                        },
                    },
                },
            },
            showTargetTooltipOutOfCombat = toggleOption(
                "showTargetTooltipOutOfCombat",
                "Show Tooltip For Selected Target",
                "Automatically display the currently selected target's tooltip while out of combat.",
                5,
                function(val)
                    if not val then
                        GameTooltip:Hide()
                    end
                end
            ),
            hideStanceButtons = toggleOption(
                "hideStanceButtons",
                "Hide Stance Buttons",
                "Hide the Blizzard stance bar/buttons when you don't need them.",
                6,
                function()
                    self:UpdateStanceButtonsVisibility()
                end
            ),
            hideBackpackButton = toggleOption(
                "hideBackpackButton",
                "Hide Bags Bar",
                "Hide the entire Blizzard Bags Bar next to the action bars.",
                7,
                function()
                    self:UpdateBackpackButtonVisibility()
                end
            ),
            showOptionsOnReload = toggleOption(
                "showOptionsOnReload",
                "Show These Options on Reload",
                "Re-open the UI Tweaks options panel after /reload (useful for development).",
                8
            ),
            reloadUI = {
                type = "execute",
                name = "Reload UI",
                desc = "Reload the interface to immediately apply changes.",
                width = "full",
                func = function()
                    ReloadUI()
                end,
                order = 9,
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
    self:ApplyVisibilityState(true)
    self:UpdateObjectiveTrackerState()
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")

    if self.db.profile.showOptionsOnReload then
        if C_Timer and C_Timer.After then
            C_Timer.After(1, function()
                self:OpenOptionsPanel()
            end)
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
        self:ApplyVisibilityState(true)
        self:ScheduleDelayedVisibilityUpdate()
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
    self:UpdatePlayerFrameVisibility(true)
    self:UpdateTargetFrameVisibility(true)
    self:UpdateDamageMeterVisibility(true)
    if self.db.profile.showTargetTooltipOutOfCombat then
        GameTooltip:Hide()
    end
    if self.visibilityTimer then
        self.visibilityTimer:Cancel()
        self.visibilityTimer = nil
    end
end

function UITweaks:PLAYER_REGEN_ENABLED()
    self:ScheduleDelayedVisibilityUpdate()
end

function UITweaks:PLAYER_ENTERING_WORLD()
    self:ApplyBuffFrameHide()
    self:ApplyVisibilityState(true)
    self:ScheduleDelayedVisibilityUpdate()
end

function UITweaks:PLAYER_TARGET_CHANGED()
    self:UpdateTargetTooltip(true)
    self:UpdateTargetFrameVisibility()
end
