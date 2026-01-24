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
        collapseBuffFrame = false,
        hidePlayerFrameOutOfCombat = false,
        hideBackpackButton = false,
        hideDamageMeter = false,
        hideTargetFrameOutOfCombat = false,
        showTargetTooltipOutOfCombat = false,
        hideChatTabs = false,
        hideStanceButtons = false,
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

    if self.db.profile.chatFontOverrideEnabled then
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
    elseif self.defaultChatFonts then
        for index, frame in ipairs(frames) do
            local defaultFont = self.defaultChatFonts[index]
            if defaultFont and frame.SetFont then
                frame:SetFont(defaultFont.font, defaultFont.size, defaultFont.flags)
            end
        end
    end
end

function UITweaks:ApplyChatLineFade()
    local frames = getChatFrames()
    if self.db.profile.chatLineFadeEnabled then
        local seconds = sanitizeSeconds(self.db.profile.chatLineFadeSeconds) or defaultsProfile.chatLineFadeSeconds
        for _, frame in ipairs(frames) do
            if frame.SetTimeVisible then
                frame:SetTimeVisible(seconds)
            end
        end
    elseif self.defaultChatWindowTimeVisible then
        for index, frame in ipairs(frames) do
            local original = self.defaultChatWindowTimeVisible[index]
            if original and frame.SetTimeVisible then
                frame:SetTimeVisible(original)
            end
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
        self:ExpandTrackerIfNeeded(true)
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        self:CollapseTrackerIfNeeded()
    else
        self:ExpandTrackerIfNeeded()
    end
end

local function collapseBuffFrame()
    if not BuffFrame then return end
    if BuffFrame.CollapseAndExpandButton and BuffFrame.SetBuffsExpandedState then
        BuffFrame.CollapseAndExpandButton:SetChecked(true)
        BuffFrame.CollapseAndExpandButton:UpdateOrientation()
        BuffFrame:SetBuffsExpandedState(false)
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

function UITweaks:ApplyBuffFrameCollapse(retry)
    if not ensureBuffFrameLoaded() or not BuffFrame then
        if not retry and C_Timer and C_Timer.After then
            C_Timer.After(0.5, function()
                self:ApplyBuffFrameCollapse(true)
            end)
        end
        return
    end

    if self.db.profile.collapseBuffFrame then
        collapseBuffFrame()
    end
end

function UITweaks:UpdatePlayerFrameVisibility(forceShow)
    if not PlayerFrame then
        return
    end

    local inCombat = InCombatLockdown and InCombatLockdown()

    if not self.db.profile.hidePlayerFrameOutOfCombat then
        PlayerFrame:Show()
        return
    end

    if forceShow or inCombat then
        PlayerFrame:Show()
    else
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
        if UnitExists("target") or forceShow then
            frame:Show()
        end
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

    if self.db.profile.hideBackpackButton then
        bagBar:Hide()
    else
        bagBar:Show()
    end
end

function UITweaks:UpdateDamageMeterVisibility(forceShow)
    local frame = _G.DamageMeter
    if not frame then
        return
    end

    if self.db.profile.hideDamageMeter then
        if forceShow then
            frame:Show()
        else
            frame:Hide()
        end
    else
        frame:Show()
    end
end

function UITweaks:UpdateChatTabsVisibility()
    self.hiddenChatTabs = self.hiddenChatTabs or {}

    if self.db.profile.hideChatTabs then
        for i = 1, NUM_CHAT_WINDOWS do
            local tabName = "ChatFrame" .. i .. "Tab"
            local tab = _G[tabName]
            if tab and tab:IsShown() then
                tab:Hide()
                self.hiddenChatTabs[tabName] = true
            end
        end
    else
        for tabName in pairs(self.hiddenChatTabs) do
            local tab = _G[tabName]
            if tab then
                tab:Show()
            end
            self.hiddenChatTabs[tabName] = nil
        end
    end
end

local function hookStanceButtons()
    local stanceBar = _G.StanceBar
    if stanceBar and not stanceBar.UITweaksHooked then
        stanceBar:HookScript("OnShow", function(frame)
            if UITweaks.db and UITweaks.db.profile.hideStanceButtons then
                frame:Hide()
            end
        end)
        stanceBar.UITweaksHooked = true
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

    local stanceBar = _G.StanceBar
    local hide = self.db.profile.hideStanceButtons

    if stanceBar then
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

    if self.db.profile.showTargetTooltipOutOfCombat and UnitExists("target") and not (InCombatLockdown and InCombatLockdown()) then
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
        self.visibilityTimer = C_Timer.NewTimer(5, function()
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

    local function toggleOption(key, name, desc, order, onSet)
        return {
            type = "toggle",
            name = name,
            desc = desc,
            width = "full",
            order = order,
            get = getOption(key),
            set = setOption(key, onSet),
        }
    end

    local function numberOption(key, name, desc, order, sanitizer, errorText, onSet, disabledKey)
        return {
            type = "input",
            name = name,
            desc = desc,
            width = "half",
            order = order,
            get = function()
                return tostring(self.db.profile[key])
            end,
            set = function(_, val)
                local value = sanitizer(val)
                if value then
                    self.db.profile[key] = value
                    if onSet then
                        onSet(value)
                    end
                end
            end,
            validate = function(_, value)
                if sanitizer(value) then
                    return true
                end
                return errorText
            end,
            disabled = function()
                return disabledKey and not self.db.profile[disabledKey]
            end,
        }
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
                        "Override Chat Line Fade",
                        "Enable a custom duration for how long chat lines remain visible before fading.",
                        1,
                        function()
                            self:ApplyChatLineFade()
                        end
                    ),
                    chatLineFadeSeconds = numberOption(
                        "chatLineFadeSeconds",
                        "Fade Seconds",
                        "Number of seconds a chat line stays before fading when the override is enabled.",
                        2,
                        sanitizeSeconds,
                        "Enter a positive number of seconds.",
                        function()
                            self:ApplyChatLineFade()
                        end,
                        "chatLineFadeEnabled"
                    ),
                    chatFontOverrideEnabled = toggleOption(
                        "chatFontOverrideEnabled",
                        "Override Chat Font Size",
                        "Enable a custom chat window font size for all tabs.",
                        3,
                        function()
                            self:ApplyChatFontSize()
                        end
                    ),
                    chatFontSize = numberOption(
                        "chatFontSize",
                        "Font Size (8-48)",
                        "Font size to use when the override is enabled.",
                        4,
                        sanitizeFontSize,
                        "Enter a number between 8 and 48.",
                        function()
                            self:ApplyChatFontSize()
                        end,
                        "chatFontOverrideEnabled"
                    ),
                    hideChatTabs = toggleOption(
                        "hideChatTabs",
                        "Hide Chat Tabs",
                        "Hide chat tab titles while leaving the windows visible.",
                        5,
                        function()
                            self:UpdateChatTabsVisibility()
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
            collapseBuffFrame = toggleOption(
                "collapseBuffFrame",
                "Collapse Player Buffs (WIP)",
                "Collapse the default player buff frame UI (work in progress).",
                3,
                function()
                    self:ApplyBuffFrameCollapse()
                end
            ),
            combatVisibility = {
                type = "group",
                name = "Combat Visibility (5s Delay)",
                inline = true,
                order = 4,
                args = {
                    hidePlayerFrameOutOfCombat = toggleOption(
                        "hidePlayerFrameOutOfCombat",
                        "Hide Player Frame Out of Combat",
                        "Hide the player unit frame outside combat and restore it five seconds after leaving combat (shares the delay with the damage meter/objective tracker).",
                        1,
                        function()
                            self:UpdatePlayerFrameVisibility(true)
                            self:ScheduleDelayedVisibilityUpdate()
                        end
                    ),
                    hideTargetFrameOutOfCombat = toggleOption(
                        "hideTargetFrameOutOfCombat",
                        "Hide Target Frame Out of Combat",
                        "Hide the target unit frame outside combat and restore it five seconds after leaving combat (shares the delay with the other frame options).",
                        2,
                        function()
                            self:UpdateTargetFrameVisibility(true)
                            self:ScheduleDelayedVisibilityUpdate()
                        end
                    ),
                    hideDamageMeter = toggleOption(
                        "hideDamageMeter",
                        "Hide Damage Meter Out of Combat",
                        "Hide the built-in damage meter frame five seconds after you leave combat (shares the delay with the player frame/objective tracker).",
                        3,
                        function()
                            self:UpdateDamageMeterVisibility()
                        end
                    ),
                    collapseObjectiveTrackerInCombat = toggleOption(
                        "collapseObjectiveTrackerInCombat",
                        "Collapse Objective Tracker In Combat",
                        "Collapse the quest/objective tracker during combat and re-expand it five seconds after combat ends (shares the delay with the damage meter/player frame).",
                        4,
                        function()
                            self:UpdateObjectiveTrackerState()
                        end
                    ),
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
    self:ApplyBuffFrameCollapse()
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
        self:ApplyBuffFrameCollapse()
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
    self:ApplyBuffFrameCollapse()
    self:ApplyVisibilityState(true)
    self:ScheduleDelayedVisibilityUpdate()
end

function UITweaks:PLAYER_TARGET_CHANGED()
    self:UpdateTargetTooltip(true)
    self:UpdateTargetFrameVisibility()
end
