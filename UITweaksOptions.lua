local addonName, addonTable = ...
local Options = {}
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

if addonTable then
    addonTable.Options = Options
end

Options.defaults = {
    profile = {
        chatMessageFadeAfterOverride = false,
        chatMessageFadeAfterSeconds = 10,
        hideHelpTips = false,
        hideBuffFrame = false,
        hidePlayerFrameOutOfCombat = false,
        hideBackpackButton = false,
        hideDamageMeter = false,
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
        showReloadButtonBottomLeft = false,
        chatFontOverrideEnabled = false,
        chatFontSize = 16,
        hideConsolePortTempAbilityFrame = false,
        consolePortBarSharing = false,
        skyridingBarSharing = false,
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
        name = "UI Tweaks",
        type = "group",
        args = {
            actionTimers = {
                type = "group",
                name = "Action Bars",
                inline = true,
                order = 1,
                args = {
                    hideBlizzardCooldownViewer = toggleOption(
                        "hideBlizzardCooldownViewer",
                        "Hide Blizzard Cooldown Viewers",
                        "Move Blizzard's Cooldown Viewer elements off-screen and shrink them to near-zero scale (Buff Bar, Buff Icon, Essential, Utility).",
                        1,
                        function()
                            self.auras.ApplyActionButtonAuraTimers(self)
                        end,
                        "showActionButtonAuraTimers"
                    ),
                    skyridingBarSharing = toggleOption(
                        "skyridingBarSharing",
                        "Share Skyriding Action Bar Skills For All Characters",
                        "Warning: This will overwrite your Skyriding action bar skills layout. When enabled, UI Tweaks saves the Skyriding action bar (bonus bar 5) after you dismount (actual mount, not shapeshift), then restores that layout on login for any character. It will not overwrite slots using empty or unavailable skills.",
                        3,
                        function(val)
                            if val then
                                self:StartSkyridingBarMonitor()
                            else
                                self:StopSkyridingBarMonitor()
                            end
                        end
                    ),
                    showActionButtonAuraTimers = toggleOption(
                        "showActionButtonAuraTimers",
                        "Show Action Button Aura Timers",
                        "Show buffs and debuffs highlight and remaining duration on action buttons. Requires Blizzard Cooldown Manager: Options -> Gameplay Enhancements -> Enable Cooldown Manager. In Cooldown Manager, move abilities from 'Not Displayed' to 'Tracked Buffs' or 'Tracked Bars' then close the window to save it. Cooldown Viewer auras work in and out of combat. Additional highlights from untracked player buffs and items on the action bar only reapply out of combat.",
                        4,
                        function()
                            self.auras.ApplyActionButtonAuraTimers(self)
                        end
                    ),
                    openCooldownViewerSettings = {
                        type = "execute",
                        name = "Open Advanced Cooldown Settings",
                        desc = "Open the Cooldown Viewer settings window on Buffs tab.",
                        order = 99,
                        width = "full",
                        func = function()
                            self:OpenCooldownViewerSettings()
                        end,
                    },
                },
            },
            chatSettings = {
                type = "group",
                name = "Chat",
                inline = true,
                order = 2,
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
                order = 3,
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
            consolePortSettings = {
                type = "group",
                name = "ConsolePort",
                inline = true,
                order = 4,
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
                        "Warning: This will overwrite your ConsolePort UI settings. When enabled, UI Tweaks saves your current ConsolePort action bar layout in ConsolePort's own presets as \"UITweaksProfile\" every time you log out, then restores that same preset automatically the next time you log in on any character. This keeps your ConsolePort action bar layout, optional bar settings, and action page logic consistent across characters without any manual export/import.",
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
                order = 5,
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
                        "Auto-Hide the Blizzard player buff frame until you mouse over it.",
                        2,
                        function()
                            self:ApplyBuffFrameHide()
                        end
                    ),
                    hideStanceButtons = toggleOption(
                        "hideStanceButtons",
                        "Auto-Hide Stance Bar",
                        "Auto-Hide the Blizzard stance bar until you mouse over it.",
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
                    hideHelpTips = toggleOption(
                        "hideHelpTips",
                        "Hide Help Tips",
                        "Hide help tooltips like 'You have unspent talent points' and 'You can drag this to your action bar'.",
                        5,
                        function()
                            self:HookHelpTipFrames()
                        end
                    ),
                    hideMicroMenuButtons = toggleOption(
                        "hideMicroMenuButtons",
                        "Hide Micro Menu Buttons",
                        "Hide all micro menu buttons except the Dungeon Finder eye.",
                        6,
                        function()
                            self:UpdateMicroMenuVisibility()
                        end
                    ),
                },
            },
            --@alpha@
            service = {
                type = "group",
                name = "Service",
                inline = true,
                order = 6,
                args = {
                    forceSaveSkyridingBarLayout = {
                        type = "execute",
                        name = "Force Save Skyriding Bar Layout",
                        desc = "Save the current Skyriding action bar (bonus bar 5) layout immediately.",
                        order = 1,
                        width = "full",
                        func = function()
                            self:SaveSkyridingBarLayout()
                        end,
                    },
                    forceRestoreSkyridingBarLayout = {
                        type = "execute",
                        name = "Force Restore Skyriding Bar Layout",
                        desc = "Restore the saved Skyriding action bar (bonus bar 5) layout immediately.",
                        order = 2,
                        width = "full",
                        func = function()
                            self:RestoreSkyridingBarLayout()
                        end,
                    },
                    showOptionsOnReload = toggleOption(
                        "showOptionsOnReload",
                        "Open This Settings Menu on Reload/Login",
                        "Re-open the UI Tweaks options panel after /reload or login (useful for development).",
                        3
                    ),
                    showReloadButtonBottomLeft = toggleOption(
                        "showReloadButtonBottomLeft",
                        "Show Reload Button in Top Left Corner",
                        "Show a Reload button in the top-left corner of the screen.",
                        4,
                        function()
                            self:UpdateBottomLeftReloadButton()
                        end
                    ),
                },
            },
            --@end-alpha@
        },
    }
    AceConfig:RegisterOptionsTable(addonName, options)
    self.optionsFrame = AceConfigDialog:AddToBlizOptions(addonName, "UI Tweaks")
    self:EnsureReloadButton()
end

return Options
