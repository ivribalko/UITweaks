local addonName, addonTable = ...
local Options = {}
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

if addonTable then
    addonTable.Options = Options
end

Options.defaults = {
    profile = {
        hideHelpTips = false,
        hideAddonMinimapIcons = false,
        hideBuffFrame = false,
        hidePlayerFrameOutOfCombat = false,
        hideBackpackButton = false,
        hideDamageMeter = false,
        hideTargetFrameOutOfCombat = false,
        showSoftTargetTooltipOutOfCombat = false,
        hideChatTabs = false,
        hideChatMenuButton = false,
        hideChatChannelsButton = false,
        hideSocialButton = false,
        transparentChatBackground = false,
        hideGroupLootHistoryFrame = false,
        hideStanceButtons = false,
        hideTotemFrame = false,
        hideMicroMenuButtons = false,
        collapseObjectiveTrackerInRaids = false,
        collapseObjectiveTrackerInDungeons = false,
        collapseObjectiveTrackerEverywhereElse = false,
        combatVisibilityDelaySeconds = 5,
        showOptionsOnReload = false,
        showReloadButtonBottomLeft = false,
        showBlockedInterfaceActionCount = false,
        showAddonCpuUsage = false,
        showTaintLogButton = false,
        chatFontOverrideEnabled = false,
        chatFontSize = 16,
        hideConsolePortTempAbilityFrame = false,
        consolePortBarSharing = false,
        skyridingBarSharing = false,
        alwaysShowQuestMarkerDistance = false,
        highlightActiveConsumablesInInventory = false,
    },
    global = {
        skyridingBarLayout = {},
    },
}

function Options.OnInitialize(self)
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
        name = "Stock UI Tweaks",
        type = "group",
        args = {
            chatSettings = {
                type = "group",
                name = "Chat",
                inline = true,
                order = 1,
                args = {
                    hideChatTabs = toggleOption(
                        "hideChatTabs",
                        "Auto-Hide Chat Tabs",
                        "Auto-Hide chat tab titles until you mouse over them. Set Options -> Social -> New Whispers: In-line to prevent new tabs from appearing.",
                        1,
                        function()
                            self:UpdateChatTabsVisibility()
                        end
                    ),
                    chatFontOverrideEnabled = toggleOption(
                        "chatFontOverrideEnabled",
                        "Set Chat Font Size",
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
                        3,
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
                        "Auto-hide the chat button with the speech bubble icon until you mouse over the chat buttons area.",
                        4,
                        function()
                            self:UpdateChatControlButtonsVisibility()
                        end
                    ),
                    hideChatChannelsButton = toggleOption(
                        "hideChatChannelsButton",
                        "Hide Chat Channels Button",
                        "Auto-hide the chat button that opens the channel list until you mouse over the chat buttons area.",
                        5,
                        function()
                            self:UpdateChatControlButtonsVisibility()
                        end
                    ),
                    hideSocialButton = toggleOption(
                        "hideSocialButton",
                        "Hide Social Button",
                        "Auto-hide the social button next to the chat frame until you mouse over the chat buttons area.",
                        6,
                        function()
                            self:UpdateChatControlButtonsVisibility()
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
                order = 2,
                args = {
                    combatVisibilityDelaySeconds = rangeOption(
                        "combatVisibilityDelaySeconds",
                        "Delay Restoring Out of Combat",
                        "Delay before restoring frames after combat end for set seconds.",
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
                        "Hide the player unit frame outside combat.",
                        4,
                        function()
                            self:UpdatePlayerFrameVisibility()
                            self:ScheduleDelayedVisibilityUpdate()
                        end
                    ),
                    hideTargetFrameOutOfCombat = toggleOption(
                        "hideTargetFrameOutOfCombat",
                        "Hide Target Frame Out of Combat",
                        "Hide the target unit frame outside combat.",
                        5,
                        function()
                            self:UpdateTargetFrameVisibility()
                            self:ScheduleDelayedVisibilityUpdate()
                        end
                    ),
                    showSoftTargetTooltipOutOfCombat = toggleOption(
                        "showSoftTargetTooltipOutOfCombat",
                        "Show Tooltip For Soft (Action) Target Out of Combat",
                        "Display the ConsolePort soft (action) target's tooltip while out of combat. Useful to check if the target is related to any active quests.",
                        6,
                        function(val)
                            if not val then
                                GameTooltip:Hide()
                            end
                        end
                    ),
                },
            },
            consolePortSettings = {
                type = "group",
                name = "ConsolePort",
                inline = true,
                order = 3,
                args = {
                    hideConsolePortTempAbilityFrame = toggleOption(
                        "hideConsolePortTempAbilityFrame",
                        "Hide ConsolePort 'New Ability Available!' Frame",
                        "Hide ConsolePortTempAbilityFrame, e.g., Dungeon Assistance ability alert in Follower Dungeons.",
                        1,
                        function()
                            self:UpdateConsolePortTempAbilityFrameVisibility()
                        end,
                        function()
                            return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                        end
                    ),
                    consolePortBarSharing = toggleOption(
                        "consolePortBarSharing",
                        "Share ConsolePort Action Bar Settings For All Characters",
                        "Warning: This will overwrite your ConsolePort UI settings. When enabled, Stock UI Tweaks saves your current ConsolePort action bar layout in ConsolePort's own presets as \"UITweaksProfile\" every time you log out, then restores that same preset automatically the next time you log in on any character. This keeps your ConsolePort action bar layout, optional bar settings, and action page logic consistent across characters without any manual export/import.",
                        3,
                        function()
                            return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                        end
                    ),
                    -- Keep this execute action last in the ConsolePort panel.
                    openConsolePortDesigner = {
                        type = "execute",
                        name = "Open ConsolePort Designer",
                        desc = "Open the ConsolePort action bar configuration window.",
                        order = 4,
                        width = "full",
                        func = function()
                            if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                            then
                                return
                            end
                            self:OpenConsolePortActionBarConfig()
                        end,
                        disabled = function()
                            return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                        end,
                    },
                },
            },
            framesVisibility = {
                type = "group",
                name = "Other",
                inline = true,
                order = 4,
                args = {
                    addMacroForNextQuestInTracker = {
                        type = "execute",
                        name = "Add Quest Prev/Next Macros",
                        desc = "Pressing this button creates or updates macros named Quest Next and Quest Prev, then opens the Macro menu. Quest Next runs /uitnextquest and selects the next tracked quest (or the first if none is selected). Quest Prev runs /uitprevquest and selects the previous tracked quest (or the last if none is selected).",
                        order = 1,
                        width = "full",
                        func = function()
                            self:EnsureAddMacroForNextQuestInTracker()
                        end,
                    },
                    alwaysShowQuestMarkerDistance = toggleOption(
                        "alwaysShowQuestMarkerDistance",
                        "Always Show Quest Marker Distance",
                        "Always show the built-in quest marker distance, even when not facing the objective.",
                        2,
                        function(val)
                            if val then
                                self:ApplyQuestMarkerDistanceSetting()
                            end
                        end
                    ),
                    hideBackpackButton = toggleOption(
                        "hideBackpackButton",
                        "Auto-Hide Bags Bar",
                        "Auto-Hide the Blizzard Bags Bar until you mouse over it.",
                        3,
                        function()
                            self:UpdateBackpackButtonVisibility()
                        end
                    ),
                    hideBuffFrame = toggleOption(
                        "hideBuffFrame",
                        "Auto-Hide Buff Frame",
                        "Auto-Hide the Blizzard player buff frame until you mouse over it.",
                        4,
                        function()
                            self:ApplyBuffFrameHide()
                        end
                    ),
                    hideStanceButtons = toggleOption(
                        "hideStanceButtons",
                        "Auto-Hide Stance Bar",
                        "Auto-Hide the Blizzard stance bar until you mouse over it.",
                        5,
                        function()
                            self:UpdateStanceButtonsVisibility()
                        end
                    ),
                    hideGroupLootHistoryFrame = toggleOption(
                        "hideGroupLootHistoryFrame",
                        "Hide Group Loot History",
                        "Hide the group loot history frame.",
                        6,
                        function()
                            self:UpdateGroupLootHistoryVisibility()
                        end
                    ),
                    hideHelpTips = toggleOption(
                        "hideHelpTips",
                        "Hide Help Tips",
                        "Hide help tooltips like 'You have unspent talent points' and 'You can drag this to your action bar'.",
                        7,
                        function()
                            self:HookHelpTipFrames()
                        end
                    ),
                    hideAddonMinimapIcons = toggleOption(
                        "hideAddonMinimapIcons",
                        "Hide Minimap Addon Icons",
                        "Hide addon minimap icons, except the AddOn Compartment button.",
                        8,
                        function()
                            self:UpdateAddonMinimapIconsVisibility()
                        end
                    ),
                    hideMicroMenuButtons = toggleOption(
                        "hideMicroMenuButtons",
                        "Hide Micro Menu Buttons",
                        "Hide all micro menu buttons except the Dungeon Finder eye.",
                        9,
                        function()
                            self:UpdateMicroMenuVisibility()
                        end
                    ),
                    hideTotemFrame = toggleOption(
                        "hideTotemFrame",
                        "Hide Totem Frame",
                        "Hide the totem frame, including warlock pets.",
                        10,
                        function()
                            self:UpdateTotemFrameVisibility()
                        end
                    ),
                    highlightActiveConsumablesInInventory = toggleOption(
                        "highlightActiveConsumablesInInventory",
                        "Highlight Active Consumables In Inventory",
                        "Highlight inventory consumables with a green frame and remaining buff time when their player aura or weapon enchant is active. Supports flasks, food, oils, and other consumables that apply a helpful aura or temporary weapon enchant. If a Well Fed buff is active, all food items are highlighted with that buff's remaining time. Cases where a consumable applies an aura with a different name than the item spell are not supported (except Well Fed food). Does not update during combat.",
                        11,
                        function()
                            self.consumables.ApplyInventoryConsumableHighlights(self)
                        end
                    ),
                    skyridingBarSharing = toggleOption(
                        "skyridingBarSharing",
                        "Share Skyriding Action Bar Skills For All Characters",
                        "Warning: This will overwrite your Skyriding action bar skills layout. When enabled, Stock UI Tweaks saves the Skyriding action bar (bonus bar 5) after you dismount (actual mount, not shapeshift), then restores that layout on login for any character. It will not overwrite slots using empty or unavailable skills.",
                        12,
                        function(val)
                            if val then
                                self:StartSkyridingBarMonitor()
                            else
                                self:StopSkyridingBarMonitor()
                            end
                        end
                    ),
                },
            },
            --@alpha@
            debug = self.debug.BuildDebugOptions(self, toggleOption),
            --@end-alpha@
        },
    }
    AceConfig:RegisterOptionsTable(addonName, options)
    self.optionsFrame = AceConfigDialog:AddToBlizOptions(addonName, "Stock UI Tweaks")
    self:EnsureReloadButton()
end

return Options
