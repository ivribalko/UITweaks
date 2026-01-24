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
        showTargetTooltipOutOfCombat = false,
        hideChatTabs = false,
        hideStanceButtons = false,
        showOptionsOnReload = false,
        chatFontOverrideEnabled = false,
        chatFontSize = 16,
    }
}

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
        local size = sanitizeFontSize(self.db.profile.chatFontSize) or defaults.profile.chatFontSize
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
        local seconds = sanitizeSeconds(self.db.profile.chatLineFadeSeconds) or defaults.profile.chatLineFadeSeconds
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

function UITweaks:SetSuppressTalentAlert(enabled)
    self.db.profile.suppressTalentAlert = enabled
    self:HookTalentAlertFrames()
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

function UITweaks:SetCollapseObjectiveTrackerInCombat(enabled)
    self.db.profile.collapseObjectiveTrackerInCombat = enabled
    self:UpdateObjectiveTrackerState()
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
    return self.db.profile.hideDamageMeter or self.db.profile.hidePlayerFrameOutOfCombat or self.db.profile.collapseObjectiveTrackerInCombat
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

    if self.db.profile.collapseObjectiveTrackerInCombat then
        self:ExpandTrackerIfNeeded()
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

    local options = {
        name = "UI Tweaks",
        type = "group",
        args = {
            chatLineFade = {
                type = "group",
                name = "Chat Line Fade",
                inline = true,
                order = 1,
                args = {
                    chatLineFadeEnabled = {
                        type = "toggle",
                        name = "Enable",
                        desc = "Override how long chat lines remain visible before fading.",
                        width = "half",
                        get = function() return self.db.profile.chatLineFadeEnabled end,
                        set = function(_, val)
                            self.db.profile.chatLineFadeEnabled = val
                            self:ApplyChatLineFade()
                        end,
                        order = 1,
                    },
                    chatLineFadeSeconds = {
                        type = "input",
                        name = "Seconds",
                        desc = "Number of seconds a chat line stays before fading when the override is enabled.",
                        width = "half",
                        get = function()
                            return tostring(self.db.profile.chatLineFadeSeconds)
                        end,
                        set = function(_, val)
                            local seconds = sanitizeSeconds(val)
                            if seconds then
                                self.db.profile.chatLineFadeSeconds = seconds
                                self:ApplyChatLineFade()
                            end
                        end,
                        validate = function(_, value)
                            if sanitizeSeconds(value) then
                                return true
                            end
                            return "Enter a positive number of seconds."
                        end,
                        disabled = function()
                            return not self.db.profile.chatLineFadeEnabled
                        end,
                        order = 2,
                    },
                },
            },
            chatFontSizeGroup = {
                type = "group",
                name = "Chat Font Size",
                inline = true,
                order = 2,
                args = {
                    chatFontOverrideEnabled = {
                        type = "toggle",
                        name = "Enable",
                        desc = "Override the chat window font size for all tabs.",
                        width = "half",
                        get = function()
                            return self.db.profile.chatFontOverrideEnabled
                        end,
                        set = function(_, val)
                            self.db.profile.chatFontOverrideEnabled = val
                            self:ApplyChatFontSize()
                        end,
                        order = 1,
                    },
                    chatFontSize = {
                        type = "input",
                        name = "Font Size",
                        desc = "Font size to use when the override is enabled (8-48).",
                        width = "half",
                        get = function()
                            return tostring(self.db.profile.chatFontSize)
                        end,
                        set = function(_, val)
                            local size = sanitizeFontSize(val)
                            if size then
                                self.db.profile.chatFontSize = size
                                self:ApplyChatFontSize()
                            end
                        end,
                        validate = function(_, value)
                            if sanitizeFontSize(value) then
                                return true
                            end
                            return "Enter a number between 8 and 48."
                        end,
                        disabled = function()
                            return not self.db.profile.chatFontOverrideEnabled
                        end,
                        order = 2,
                    },
                },
            },
            suppressTalentAlert = {
                type = "toggle",
                name = "Hide Talent Alert",
                desc = "Prevent the 'You have unspent talent points' reminder from popping up.",
                width = "full",
                get = function()
                    return self.db.profile.suppressTalentAlert
                end,
                set = function(_, val)
                    self:SetSuppressTalentAlert(val)
                end,
                order = 3,
            },
            collapseBuffFrame = {
                type = "toggle",
                name = "Collapse Player Buffs (WIP)",
                desc = "Collapse the default player buff frame UI (work in progress).",
                width = "full",
                get = function()
                    return self.db.profile.collapseBuffFrame
                end,
                set = function(_, val)
                    self.db.profile.collapseBuffFrame = val
                    self:ApplyBuffFrameCollapse()
                end,
                order = 4,
            },
            hidePlayerFrameOutOfCombat = {
                type = "toggle",
                name = "Hide Player Frame Out of Combat",
                desc = "Hide the player unit frame when you are not in combat.",
                width = "full",
                get = function()
                    return self.db.profile.hidePlayerFrameOutOfCombat
                end,
                set = function(_, val)
                    self.db.profile.hidePlayerFrameOutOfCombat = val
                    self:UpdatePlayerFrameVisibility(true)
                    self:ScheduleDelayedVisibilityUpdate()
                end,
                order = 5,
            },
            hideDamageMeter = {
                type = "toggle",
                name = "Hide Damage Meter Out of Combat with a Delay",
                desc = "Hide the built-in damage meter frame five seconds after you leave combat, with a delay before hiding.",
                width = "full",
                get = function()
                    return self.db.profile.hideDamageMeter
                end,
                set = function(_, val)
                    self.db.profile.hideDamageMeter = val
                    self:UpdateDamageMeterVisibility()
                end,
                order = 6,
            },
            showTargetTooltipOutOfCombat = {
                type = "toggle",
                name = "Show Tooltip For Selected Target",
                desc = "Automatically display the currently selected target's tooltip while out of combat.",
                width = "full",
                get = function()
                    return self.db.profile.showTargetTooltipOutOfCombat
                end,
                set = function(_, val)
                    self.db.profile.showTargetTooltipOutOfCombat = val
                    if not val then
                        GameTooltip:Hide()
                    end
                end,
                order = 7,
            },
            hideChatTabs = {
                type = "toggle",
                name = "Hide Chat Tabs",
                desc = "Hide chat tab titles while leaving the windows visible.",
                width = "full",
                get = function()
                    return self.db.profile.hideChatTabs
                end,
                set = function(_, val)
                    self.db.profile.hideChatTabs = val
                    self:UpdateChatTabsVisibility()
                end,
                order = 8,
            },
            hideStanceButtons = {
                type = "toggle",
                name = "Hide Stance Buttons",
                desc = "Hide the Blizzard stance bar/buttons when you don't need them.",
                width = "full",
                get = function()
                    return self.db.profile.hideStanceButtons
                end,
                set = function(_, val)
                    self.db.profile.hideStanceButtons = val
                    self:UpdateStanceButtonsVisibility()
                end,
                order = 9,
            },
            hideBackpackButton = {
                type = "toggle",
                name = "Hide Bags Bar",
                desc = "Hide the entire Blizzard Bags Bar next to the action bars.",
                width = "full",
                get = function()
                    return self.db.profile.hideBackpackButton
                end,
                set = function(_, val)
                    self.db.profile.hideBackpackButton = val
                    self:UpdateBackpackButtonVisibility()
                end,
                order = 10,
            },
            collapseObjectiveTrackerInCombat = {
                type = "toggle",
                name = "Collapse Objective Tracker In Combat",
                desc = "Collapse the quest/objective tracker during combat and expand afterwards.",
                width = "full",
                get = function()
                    return self.db.profile.collapseObjectiveTrackerInCombat
                end,
                set = function(_, val)
                    self:SetCollapseObjectiveTrackerInCombat(val)
                end,
                order = 11,
            },
            showOptionsOnReload = {
                type = "toggle",
                name = "Show These Options on Reload",
                desc = "Re-open the UI Tweaks options panel after /reload (useful for development).",
                width = "full",
                get = function()
                    return self.db.profile.showOptionsOnReload
                end,
                set = function(_, val)
                    self.db.profile.showOptionsOnReload = val
                end,
                order = 12,
            },
            reloadUI = {
                type = "execute",
                name = "Reload UI",
                desc = "Reload the interface to immediately apply changes.",
                width = "full",
                func = function()
                    ReloadUI()
                end,
                order = 13,
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
    self:UpdatePlayerFrameVisibility(true)
    self:UpdateDamageMeterVisibility()
    self:UpdateTargetTooltip()
    self:UpdateChatTabsVisibility()
    self:UpdateStanceButtonsVisibility()
    self:UpdateBackpackButtonVisibility()
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
        self:UpdatePlayerFrameVisibility(true)
        self:UpdateDamageMeterVisibility()
        self:UpdateTargetTooltip()
        self:UpdateChatTabsVisibility()
        self:UpdateBackpackButtonVisibility()
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
    self:UpdateTargetTooltip()
end

function UITweaks:PLAYER_ENTERING_WORLD()
    self:ApplyBuffFrameCollapse()
    self:UpdatePlayerFrameVisibility(true)
    self:UpdateDamageMeterVisibility()
    self:UpdateTargetTooltip()
    self:UpdateChatTabsVisibility()
    self:UpdateStanceButtonsVisibility()
    self:UpdateBackpackButtonVisibility()
    self:ScheduleDelayedVisibilityUpdate()
end

function UITweaks:PLAYER_TARGET_CHANGED()
    self:UpdateTargetTooltip(true)
end
