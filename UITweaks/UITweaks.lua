local addonName, addonTable = ...
local L = addonTable

local UITweaks = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0")

function UITweaks:OnInitialize()
    local options = {
        name = "UI Tweaks",
        type = "group",
        args = {
            say_hello = {
                type = "execute",
                name = "Say Hello",
                func = function()
                    print("Hello World")
                end,
            },
        },
    }

    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, "UI Tweaks")
end
