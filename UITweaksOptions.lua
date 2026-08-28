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
        hideTargetFrameAuras = false,
        showRaidFrameDebuffsOnPlayerFrame = false,
        playerAndTargetFrameOpacityInCombat = 100,
        playerAndTargetFrameOpacityOutOfCombat = 100,
        hideChatTabs = false,
        hideAllSpeechBubbles = false,
        hideChatMenuButton = false,
        hideChatChannelsButton = false,
        hideSocialButton = false,
        transparentChatBackground = false,
        partyAndRaidFrameScale = 100,
        hideCompactRaidFrameManager = false,
        hideGroupLootHistoryFrame = false,
        hideStanceButtons = false,
        hideTotemFrame = false,
        fadeObjectiveTrackerInRaids = false,
        fadeObjectiveTrackerInDungeons = false,
        fadeObjectiveTrackerEverywhereElse = false,
        showOptionsOnReload = false,
        showReloadButtonBottomLeft = false,
        showBlockedInterfaceActionCount = false,
        showAddonCpuUsage = false,
        showTaintLogButton = false,
        chatFontOverrideEnabled = false,
        chatFontSize = 16,
        addLeaveInstanceGroupToConsolePortMenu = false,
        addMythicPlusFinderToConsolePortMenu = false,
        addOilToMainHandConsolePortShortcut = false,
        addSoundToggleToConsolePortMenu = false,
        addTabControlsToConsolePort = false,
        closeAllInventoryBagsWithConsolePortCancel = false,
        hideConsolePortTempAbilityFrame = false,
        onlyShowConsolePortCrosshairInCombat = false,
        overlayCooldownManagerOnConsolePort = false,
        removeTimerFromCooldownManagerOverlays = false,
        respectConsolePortCameraSettingWhileCasting = false,
        consolePortBarSharing = false,
        disableImmersionDialogListItemScaling = false,
        fixDropdownsForConsolePort = false,
        focusMailboxOpenAllButton = false,
        useCircleToCancelImmersion = false,
        skyridingBarSharing = false,
        alwaysShowQuestMarkerDistance = false,
        adjustMinimapZoomBasedOnPlayerSpeed = false,
        highlightActiveConsumablesInInventory = false,
        showMobAggroRadiusOnMouseOverOutOfCombat = false,
        rememberGroupFinderRequirements = false,
        groupFinderRequirements = {
            dungeons = {},
            raids = {},
        },
        minimapPos = 225,
    },
    global = {
        skyridingBarLayout = {},
    },
}

function Options.OnInitialize(self)
    local profile = self.db.profile
    local objectiveTrackerSettingMigration = {
        collapseObjectiveTrackerInRaids = "fadeObjectiveTrackerInRaids",
        collapseObjectiveTrackerInDungeons = "fadeObjectiveTrackerInDungeons",
        collapseObjectiveTrackerEverywhereElse = "fadeObjectiveTrackerEverywhereElse",
    }
    for oldKey, newKey in pairs(objectiveTrackerSettingMigration) do
        if rawget(profile, oldKey) then profile[newKey] = true end
        profile[oldKey] = nil
    end
    if rawget(profile, "minimapButtonAngle") then
        profile.minimapPos = profile.minimapButtonAngle
        profile.minimapButtonAngle = nil
    end
    if profile.hidePlayerFrameOutOfCombat or profile.hideTargetFrameOutOfCombat then
        profile.playerAndTargetFrameOpacityOutOfCombat = 0
    end
    profile.fadePlayerAndTargetFramesOutOfCombat = nil
    profile.hidePlayerFrameOutOfCombat = nil
    profile.hideTargetFrameOutOfCombat = nil
    profile.playerFrameOpacityOutOfCombat = nil
    profile.targetFrameOpacityOutOfCombat = nil
    profile.hideBackpackButton = nil
    profile.hideBuffFrame = nil
    profile.hideMicroMenuButtons = nil
    profile.combatVisibilityDelaySeconds = nil
    profile.hideDamageMeter = nil
    profile.showSoftTargetTooltipOutOfCombat = nil
    profile.showGlobalCooldownOnPlayerCastBar = nil
    if rawget(profile, "fixRaidFinderDropdownForConsolePort") then
        profile.fixDropdownsForConsolePort = true
    end
    profile.fixRaidFinderDropdownForConsolePort = nil
    if rawget(profile, "addMapTabControlsToConsolePort") then
        profile.addTabControlsToConsolePort = true
    end
    profile.addMapTabControlsToConsolePort = nil

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
                        "Auto-Hide chat tab titles, including newly created tabs, until you mouse over them.",
                        1,
                        function()
                            self:UpdateChatTabsVisibility()
                        end
                    ),
                    hideAllSpeechBubbles = toggleOption(
                        "hideAllSpeechBubbles",
                        "Hide All Speech Bubbles",
                        "Hide all native world-space speech bubbles from players and NPCs. Separate Talking Head, gossip, quest, and raid warning UI remains visible.",
                        2,
                        function(val)
                            if val then self:ApplySpeechBubbleVisibility() end
                        end
                    ),
                    hideChatMenuButton = toggleOption(
                        "hideChatMenuButton",
                        "Hide Chat Bubble Button",
                        "Auto-hide the chat button with the speech bubble icon until you mouse over the chat buttons area.",
                        3,
                        function()
                            self:UpdateChatControlButtonsVisibility()
                        end
                    ),
                    hideChatChannelsButton = toggleOption(
                        "hideChatChannelsButton",
                        "Hide Chat Channels Button",
                        "Auto-hide the chat button that opens the channel list until you mouse over the chat buttons area.",
                        4,
                        function()
                            self:UpdateChatControlButtonsVisibility()
                        end
                    ),
                    hideSocialButton = toggleOption(
                        "hideSocialButton",
                        "Hide Social Button",
                        "Auto-hide the social button next to the chat frame until you mouse over the chat buttons area.",
                        5,
                        function()
                            self:UpdateChatControlButtonsVisibility()
                        end
                    ),
                    chatFontOverrideEnabled = toggleOption(
                        "chatFontOverrideEnabled",
                        "Set Chat Font Size",
                        "Enable a custom chat window font size for all tabs.",
                        6,
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
                        7,
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
                    transparentChatBackground = toggleOption(
                        "transparentChatBackground",
                        "Transparent Chat Background",
                        "Set the chat background alpha to zero.",
                        8,
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
                    objectiveTrackerVisibility = {
                        type = "group",
                        name = "Fade Objective Tracker",
                        inline = true,
                        order = 1,
                        args = {
                            fadeObjectiveTrackerInRaids = {
                                type = "toggle",
                                name = "In Raids",
                                desc = "Fade out the objective tracker in combat while in raid instances.",
                                width = "auto",
                                order = 1,
                                get = function()
                                    return self.db.profile.fadeObjectiveTrackerInRaids
                                end,
                                set = function(_, val)
                                    self.db.profile.fadeObjectiveTrackerInRaids = val
                                    self:UpdateObjectiveTrackerState()
                                end,
                            },
                            fadeObjectiveTrackerInDungeons = {
                                type = "toggle",
                                name = "In Dungeons",
                                desc = "Fade out the objective tracker in combat while in dungeon instances.",
                                width = "auto",
                                order = 2,
                                get = function()
                                    return self.db.profile.fadeObjectiveTrackerInDungeons
                                end,
                                set = function(_, val)
                                    self.db.profile.fadeObjectiveTrackerInDungeons = val
                                    self:UpdateObjectiveTrackerState()
                                end,
                            },
                            fadeObjectiveTrackerEverywhereElse = {
                                type = "toggle",
                                name = "Everywhere Else",
                                desc = "Fade out the objective tracker in combat everywhere else (open world, scenarios, PvP, etc.).",
                                width = "auto",
                                order = 3,
                                get = function()
                                    return self.db.profile.fadeObjectiveTrackerEverywhereElse
                                end,
                                set = function(_, val)
                                    self.db.profile.fadeObjectiveTrackerEverywhereElse = val
                                    self:UpdateObjectiveTrackerState()
                                end,
                            },
                        },
                    },
                    hideTargetFrameAuras = toggleOption(
                        "hideTargetFrameAuras",
                        "Hide Target Frame Buffs and Debuffs",
                        "Hide all buffs and debuffs from the target frame.",
                        2,
                        function()
                            self:ApplyTargetFrameAurasHide()
                        end
                    ),
                    playerAndTargetFrameOpacityInCombat = rangeOption(
                        "playerAndTargetFrameOpacityInCombat",
                        "Player and Target Frame Opacity In Combat",
                        "Set the player unit frame, player cast bar, and target unit frame opacity in combat from 0% (invisible) to 100% (fully opaque).",
                        3,
                        0,
                        100,
                        1,
                        function()
                            self:UpdatePlayerAndTargetFrameOpacity()
                        end
                    ),
                    playerAndTargetFrameOpacityOutOfCombat = rangeOption(
                        "playerAndTargetFrameOpacityOutOfCombat",
                        "Player and Target Frame Opacity Out of Combat",
                        "Set the player unit frame, player cast bar, and target unit frame opacity outside combat from 0% (invisible) to 100% (fully opaque).",
                        4,
                        0,
                        100,
                        1,
                        function()
                            self:UpdatePlayerAndTargetFrameOpacity()
                        end
                    ),
                    showRaidFrameDebuffsOnPlayerFrame = toggleOption(
                        "showRaidFrameDebuffsOnPlayerFrame",
                        "Show Raid Frame Debuffs On My Player Frame",
                        "Show debuffs that Blizzard displays on raid frames in Blizzard's secure debuff-type gradient overlay over the player name, health bar, and mana bar.",
                        5,
                        function()
                            self.playerFrameDebuffs.UpdateVisibility(self)
                        end
                    ),
                    testPlayerFrameDebuffColors = {
                        type = "execute",
                        name = "Test Player Frame Debuff Colors",
                        desc = "Cycle through the gradient overlays for Magic, Curse, Disease, Poison, and Bleed.",
                        order = 6,
                        width = "full",
                        func = function()
                            self.playerFrameDebuffs.TestColors(self)
                        end,
                    },
                },
            },
            consolePortSettings = {
                type = "group",
                name = "ConsolePort",
                inline = true,
                order = 3,
                args = {
                    addLeaveInstanceGroupToConsolePortMenu = toggleOption(
                        "addLeaveInstanceGroupToConsolePortMenu",
                        "Add Leave Instance Group To ConsolePort Menu Ring",
                        "Add a separate Leave Instance Group button next to ConsolePort's dungeon teleport button in the menu ring. The button is hidden while you are not in a party or when ConsolePort's regular Leave Party action is already shown.",
                        1,
                        function(val)
                            if val then
                                self.consolePortMenu.Apply(self)
                            end
                        end
                    ),
                    addMythicPlusFinderToConsolePortMenu = toggleOption(
                        "addMythicPlusFinderToConsolePortMenu",
                        "Add Mythic+ Finder To ConsolePort Menu Ring",
                        "Add a Mythic+ Finder button next to ConsolePort's Group Finder button in the menu ring. It opens the Premade Groups dungeon search directly.",
                        2,
                        function(val)
                            if val then
                                self.consolePortMenu.Apply(self)
                            end
                        end
                    ),
                    addOilToMainHandConsolePortShortcut = toggleOption(
                        "addOilToMainHandConsolePortShortcut",
                        "Add Oil To Main-Hand Shortcut To ConsolePort Inventory Options",
                        "Add an Apply to Main-Hand Weapon shortcut to ConsolePort's Triangle options for weapon oil items in inventory.",
                        3,
                        function(val)
                            if val then
                                self.consolePortItemMenu.Apply(self)
                            end
                        end,
                        function()
                            return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                        end
                    ),
                    addSoundToggleToConsolePortMenu = toggleOption(
                        "addSoundToggleToConsolePortMenu",
                        "Add Sound Toggle To ConsolePort Menu Ring",
                        "Add a Sound button to ConsolePort's menu ring that toggles Settings -> Game -> Audio -> Enable Sound and shows whether sound is enabled or disabled.",
                        4,
                        function(val)
                            if val then
                                self.consolePortMenu.Apply(self)
                            end
                        end
                    ),
                    addTabControlsToConsolePort = toggleOption(
                        "addTabControlsToConsolePort",
                        "Add Tab Controls To ConsolePort",
                        "Use L1 and R1 to switch between tabs in the Adventure Guide, Auction House, Bank, Character, Dungeons & Raids, Map, Talents and Spellbook, and Warband Collections windows when using ConsolePort, with controller button icons shown on the tab controls.",
                        5,
                        function(val)
                            if val then
                                self.consolePortTabs.Apply(self)
                            end
                        end,
                        function()
                            return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                        end
                    ),
                    closeAllInventoryBagsWithConsolePortCancel = toggleOption(
                        "closeAllInventoryBagsWithConsolePortCancel",
                        "Close All Inventory Bags With ConsolePort Cancel",
                        "Close all open inventory bags at once when pressing ConsolePort's cancel button (Circle by default) while its cursor is focused anywhere in an inventory bag.",
                        6,
                        function(val)
                            if val then
                                self.consolePortBags.Apply(self)
                            end
                        end,
                        function()
                            return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                        end
                    ),
                    disableImmersionDialogListItemScaling = toggleOption(
                        "disableImmersionDialogListItemScaling",
                        "Disable Immersion Dialog List Item Scaling",
                        "Prevent Immersion's active dialogue list items from growing when hovered or selected.",
                        7,
                        function(val)
                            if val then
                                self.immersion.Apply(self)
                            end
                        end,
                        function()
                            return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Immersion"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("Immersion"))
                        end
                    ),
                    fixDropdownsForConsolePort = toggleOption(
                        "fixDropdownsForConsolePort",
                        "Fix Dropdowns For ConsolePort",
                        "Allow ConsolePort's controller X button to open modern dropdown menus throughout the UI, such as the Raid Finder raid selector and Premade Groups filter.",
                        8,
                        function(val)
                            if val then
                                self.consolePortMenu.Apply(self)
                            end
                        end,
                        function()
                            return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                        end
                    ),
                    focusMailboxOpenAllButton = toggleOption(
                        "focusMailboxOpenAllButton",
                        "Focus Mailbox Open All Button",
                        "Focus the ConsolePort controller cursor on the mailbox's Open All button when opening the mailbox.",
                        9,
                        nil,
                        function()
                            return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                        end
                    ),
                    hideConsolePortTempAbilityFrame = toggleOption(
                        "hideConsolePortTempAbilityFrame",
                        "Hide ConsolePort 'New Ability Available!' Frame",
                        "Hide ConsolePortTempAbilityFrame, e.g., Dungeon Assistance ability alert in Follower Dungeons.",
                        10,
                        function()
                            self:UpdateConsolePortTempAbilityFrameVisibility()
                        end,
                        function()
                            return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                        end
                    ),
                    onlyShowConsolePortCrosshairInCombat = toggleOption(
                        "onlyShowConsolePortCrosshairInCombat",
                        "Only Show ConsolePort Crosshair In Combat",
                        "Only allow ConsolePort's crosshair to appear while in combat.",
                        11,
                        function(val)
                            if val then
                                self:UpdateConsolePortCrosshairVisibility()
                            end
                        end,
                        function()
                            return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                        end
                    ),
                    overlayCooldownManagerOnConsolePort = toggleOption(
                        "overlayCooldownManagerOnConsolePort",
                        "Overlay Cooldown Manager Icons On ConsolePort Action Bar",
                        "Overlay Blizzard Cooldown Manager tracked buff, essential cooldown, and utility cooldown icons on matching ConsolePort action bar buttons at the same position and size, replacing the original action artwork while preserving ConsolePort button frames, native spell-activation glows, gamepad icons, and matching button opacity. Updates when ConsolePort toggle keys change the action shown on a button.",
                        12,
                        function(val)
                            if val then
                                self.cooldownOverlay.Apply(self)
                            end
                        end,
                        function()
                            return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                        end
                    ),
                    cooldownManagerTrackingNote = {
                        type = "description",
                        name = "Note: Some spells track more reliably as cooldowns, while others track more reliably as tracked buffs. Use Advanced Cooldown Settings to choose whichever works best for each spell. Changes made in Blizzard's Advanced Cooldown Settings require /reload before the overlays update.",
                        order = 12.1,
                        width = "full",
                    },
                    removeTimerFromCooldownManagerOverlays = toggleOption(
                        "removeTimerFromCooldownManagerOverlays",
                        "Remove Active Buff Timers And Use Yellow Swipes",
                        "Hide countdown timer numbers and use the Essential Cooldown yellow swipe color on Cooldown Manager icons overlaid on the ConsolePort action bar while their buff is active. Cooldown timer numbers remain visible.",
                        12.2,
                        function(val)
                            if val then
                                self.cooldownOverlay.RequestUpdate(self)
                            end
                        end,
                        function()
                            local consolePortLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                or (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                            return not self.db.profile.overlayCooldownManagerOnConsolePort or not consolePortLoaded
                        end
                    ),
                    respectConsolePortCameraSettingWhileCasting = toggleOption(
                        "respectConsolePortCameraSettingWhileCasting",
                        "Respect Turn Character With Camera While Casting",
                        "Prevent ConsolePort from changing Turn Character With Camera to Always while casting, channeling, or empowering spells.",
                        13,
                        function(val)
                            if val then
                                self.consolePortMovement.Apply(self)
                            end
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
                        14,
                        function()
                            return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                        end
                    ),
                    consolePortBarSharingNote = {
                        type = "description",
                        name = "Note: Enabling this setting overwrites your ConsolePort UI settings. Stock UI Tweaks saves the current layout when you log out and restores it when you log in on any character.",
                        order = 14.1,
                        width = "full",
                    },
                    useCircleToCancelImmersion = toggleOption(
                        "useCircleToCancelImmersion",
                        "Use Circle To Cancel Immersion Dialogues",
                        "Use Circle to cancel or close Immersion dialogue and Triangle to inspect items or back out of item inspection when using ConsolePort.",
                        15,
                        function(val)
                            if val then
                                self.immersion.Apply(self)
                            end
                        end,
                        function()
                            local consolePortLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                or (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                            local immersionLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Immersion"))
                                or (IsAddOnLoaded and IsAddOnLoaded("Immersion"))
                            return not consolePortLoaded or not immersionLoaded
                        end
                    ),
                    openConsolePortDesigner = {
                        type = "execute",
                        name = "Open ConsolePort Designer",
                        desc = "Open the ConsolePort action bar configuration window.",
                        order = 16,
                        width = "full",
                        func = function()
                            if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                            then
                                return
                            end
                            self:CloseOptionsPanel()
                            self:OpenConsolePortActionBarConfig()
                        end,
                        disabled = function()
                            return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                        end,
                    },
                    -- Keep this execute action last in the ConsolePort panel.
                    openAdvancedCooldownSettings = {
                        type = "execute",
                        name = "Open Advanced Cooldown Settings",
                        desc = "Open Blizzard's Advanced Cooldown Settings on the Auras tab.",
                        order = 17,
                        width = "full",
                        func = function()
                            self.cooldownOverlay.OpenSettings()
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
                        name = "Add Quest Prev/Next/Abandon Macros",
                        desc = "Pressing this button creates or updates macros named Quest Abandon, Quest Next, and Quest Prev, then opens the Macro menu. Quest Abandon runs /uitabandonquest and opens the standard abandon confirmation for the currently selected tracked quest. Quest Next runs /uitnextquest and selects the next tracked quest (or the first if none is selected). Quest Prev runs /uitprevquest and selects the previous tracked quest (or the last if none is selected).",
                        order = 1,
                        width = "full",
                        func = function()
                            self:EnsureQuestTrackerMacros()
                        end,
                    },
                    adjustMinimapZoomBasedOnPlayerSpeed = toggleOption(
                        "adjustMinimapZoomBasedOnPlayerSpeed",
                        "Adjust Minimap Zoom Based On Player Speed",
                        "Smoothly zoom the minimap in while stationary, use one zoom level while moving or in combat, and fully zoom it out while flying.",
                        2,
                        function(val)
                            if val then
                                self:StartMinimapSpeedZoomMonitor()
                            else
                                self:StopMinimapSpeedZoomMonitor()
                            end
                        end
                    ),
                    alwaysShowQuestMarkerDistance = toggleOption(
                        "alwaysShowQuestMarkerDistance",
                        "Always Show Quest Marker Distance",
                        "Always show the built-in quest marker distance, even when not facing the objective.",
                        3,
                        function(val)
                            if val then
                                self:ApplyQuestMarkerDistanceSetting()
                            end
                        end
                    ),
                    hideStanceButtons = toggleOption(
                        "hideStanceButtons",
                        "Auto-Hide Stance Bar",
                        "Auto-Hide the Blizzard stance bar until you mouse over it.",
                        4,
                        function()
                            self:UpdateStanceButtonsVisibility()
                        end
                    ),
                    hideCompactRaidFrameManager = toggleOption(
                        "hideCompactRaidFrameManager",
                        "Hide Compact Raid Frame Manager",
                        "Hide the compact raid frame manager.",
                        5,
                        function()
                            self:UpdateCompactRaidFrameManagerVisibility()
                        end
                    ),
                    hideHelpTips = toggleOption(
                        "hideHelpTips",
                        "Hide Help Tips",
                        "Hide help tooltips like 'You have unspent talent points' and 'You can drag this to your action bar'.",
                        6,
                        function()
                            self:HookHelpTipFrames()
                        end
                    ),
                    hideGroupLootHistoryFrame = toggleOption(
                        "hideGroupLootHistoryFrame",
                        "Hide Loot Notifications",
                        "Hide loot-result notifications for you and other players without hiding group-loot voting prompts. The loot history can still be opened from chat links.",
                        7,
                        function()
                            self:UpdateLootNotificationVisibility()
                        end
                    ),
                    hideTotemFrame = toggleOption(
                        "hideTotemFrame",
                        "Hide Totem Frame",
                        "Hide the totem frame, including warlock pets.",
                        8,
                        function()
                            self:UpdateTotemFrameVisibility()
                        end
                    ),
                    highlightActiveConsumablesInInventory = toggleOption(
                        "highlightActiveConsumablesInInventory",
                        "Highlight Active Consumables In Inventory",
                        "Highlight inventory consumables with a green frame and remaining buff time when their player aura or weapon enchant is active. Supports flasks, food, oils, and other consumables that apply a helpful aura or temporary weapon enchant. If a Well Fed buff is active, all food items are highlighted with that buff's remaining time. Cases where a consumable applies an aura with a different name than the item spell are not supported (except Well Fed food). Does not update during combat.",
                        9,
                        function()
                            self.consumables.ApplyInventoryConsumableHighlights(self)
                        end
                    ),
                    highlightActiveConsumablesNote = {
                        type = "description",
                        name = "Note: Consumables that apply an aura with a different name than the item spell are not supported, except for Well Fed food. Highlights do not update during combat.",
                        order = 9.1,
                        width = "full",
                    },
                    partyAndRaidFrameScale = rangeOption(
                        "partyAndRaidFrameScale",
                        "Party and Raid Frame Scale",
                        "Scale Blizzard's party and raid frame containers from 50% to 100%. Set this to 100% and reload to use Blizzard's Edit Mode sizes.",
                        10,
                        50,
                        100,
                        5,
                        function()
                            self:ApplyPartyAndRaidFrameScale()
                        end
                    ),
                    rememberGroupFinderRequirements = toggleOption(
                        "rememberGroupFinderRequirements",
                        "Remember Start a Group Requirements",
                        "Remember the minimum item level and playstyle last selected in Dungeon and Raid Start a Group forms, plus the minimum Mythic+ rating selected for Dungeons.",
                        11,
                        function(val)
                            if val then self.groupFinder.Apply(self) end
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
                    showMobAggroRadiusOnMouseOverOutOfCombat = toggleOption(
                        "showMobAggroRadiusOnMouseOverOutOfCombat",
                        "Show Mob Aggro Radius On Mouse Over Out Of Combat",
                        "Show the estimated distance remaining before entering a hostile mob's aggro radius in its tooltip when you mouse over it while out of combat.",
                        13,
                        function(val)
                            if val then self.aggroRadius.Apply(self) end
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
    self.optionsFrame, self.optionsCategoryID = AceConfigDialog:AddToBlizOptions(addonName, "Stock UI Tweaks")
    self:EnsureReloadButton()
end

return Options
