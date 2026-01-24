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
    }
}

local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS or 10

local function sanitizeSeconds(value)
    local seconds = tonumber(value)
    if seconds and seconds > 0 then
        return seconds
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
            chatLineFadeEnabled = {
                type = "toggle",
                name = "Custom Chat Line Fade",
                desc = "Override how long chat lines remain visible before fading.",
                width = "full",
                get = function() return self.db.profile.chatLineFadeEnabled end,
                set = function(_, val)
                    self.db.profile.chatLineFadeEnabled = val
                    self:ApplyChatLineFade()
                end,
                order = 1,
            },
            chatLineFadeSeconds = {
                type = "input",
                name = "Chat Line Lifetime (seconds)",
                desc = "Number of seconds a chat line stays before fading when the override is enabled.",
                width = "full",
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
            reloadUI = {
                type = "execute",
                name = "Reload UI",
                desc = "Reload the interface to immediately apply changes.",
                width = "full",
                func = function()
                    ReloadUI()
                end,
                order = 4,
            },
        },
    }

    AceConfig:RegisterOptionsTable(addonName, options)
    self.optionsFrame = AceConfigDialog:AddToBlizOptions(addonName, "UI Tweaks")
end

function UITweaks:OnEnable()
    self:CacheDefaultChatWindowTimes()
    self:ApplyChatLineFade()
    self:HookTalentAlertFrames()
    self:RegisterEvent("ADDON_LOADED")

    if C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            self:OpenOptionsPanel()
        end)
    else
        self:OpenOptionsPanel()
    end
end

function UITweaks:ADDON_LOADED(event, addonName)
    if addonName == "Blizzard_TalentUI" or addonName == "Blizzard_PlayerSpells" then
        self:HookTalentAlertFrames()
    end
end
