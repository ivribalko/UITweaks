local addonName, addonTable = ...
local L = addonTable

local UITweaks = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

local defaults = {
    profile = {
        printOnLogin = false,
        chatLineFadeEnabled = false,
        chatLineFadeSeconds = 5,
    }
}

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

function UITweaks:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("UITweaksDB", defaults, true)

    local options = {
        name = "UI Tweaks",
        type = "group",
        args = {
            printOnLogin = {
                type = "toggle",
                name = "Print 'Hello World' on Login",
                desc = "If enabled, 'Hello World' will be printed to chat every time you log in.",
                get = function(info) return self.db.profile.printOnLogin end,
                set = function(info, val) self.db.profile.printOnLogin = val end,
                order = 1,
            },
            chatLineFadeEnabled = {
                type = "toggle",
                name = "Custom Chat Line Fade",
                desc = "Override how long chat lines remain visible before fading.",
                get = function() return self.db.profile.chatLineFadeEnabled end,
                set = function(_, val)
                    self.db.profile.chatLineFadeEnabled = val
                    self:ApplyChatLineFade()
                end,
                order = 2,
            },
            chatLineFadeSeconds = {
                type = "input",
                name = "Chat Line Lifetime (seconds)",
                desc = "Number of seconds a chat line stays before fading when the override is enabled.",
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
                order = 3,
            },
        },
    }

    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, "UI Tweaks")
end

function UITweaks:OnEnable()
    if self.db.profile.printOnLogin then
        print("Hello World")
    end

    self:CacheDefaultChatWindowTimes()
    self:ApplyChatLineFade()
end
