local addonName, addonTable = ...
local L = addonTable

local UITweaks = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

local defaults = {
    profile = {
        printOnLogin = false,
    }
}

function UITweaks:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("UITweaksDB", defaults, true)

    local options = {
        name = "UI Tweaks",
        type = "group",
        args = {
            general = {
                type = "group",
                name = "General",
                args = {
                    printOnLogin = {
                        type = "toggle",
                        name = "Print 'Hello World' on Login",
                        desc = "If enabled, 'Hello World' will be printed to chat every time you log in.",
                        get = function(info) return self.db.profile.printOnLogin end,
                        set = function(info, val) self.db.profile.printOnLogin = val end,
                        order = 1,
                    },
                    say_hello = {
                        type = "execute",
                        name = "Say Hello Now",
                        desc = "Prints 'Hello World' to chat immediately.",
                        func = function()
                            print("Hello World")
                        end,
                        order = 2,
                    },
                },
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
end
