local _, addonTable = ...
local CooldownOverlay = {}

if addonTable then
    addonTable.CooldownOverlay = CooldownOverlay
end

local viewerNames = {
    "BuffIconCooldownViewer",
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
}

local watchedButtonAttributes = {
    action = true,
    action_field = true,
    macro = true,
    spell = true,
    state = true,
    type = true,
}

local watchedEvents = {
    "ADDON_RESTRICTION_STATE_CHANGED",
    "ACTIONBAR_SLOT_CHANGED",
    "COOLDOWN_VIEWER_DATA_LOADED",
    "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED",
    "COOLDOWN_VIEWER_TABLE_HOTFIXED",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_PVP_TALENT_UPDATE",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_SPECIALIZATION_CHANGED",
    "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
    "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",
    "SPELLS_CHANGED",
    "TRAIT_CONFIG_UPDATED",
    "UPDATE_MACROS",
    "UPDATE_SHAPESHIFT_FORM",
}

local hotkeyKeys = { "Hotkey", "Hotkey1", "Hotkey2" }
local REMOVE_ALL_TRACKING_POPUP = "UITWEAKS_REMOVE_ALL_COOLDOWN_TRACKING"
local hookedConsolePortButtons = setmetatable({}, { __mode = "k" })
local hookedViewerItems = setmetatable({}, { __mode = "k" })
local hookedViewers = setmetatable({}, { __mode = "k" })
local settingsButtons = setmetatable({}, { __mode = "k" })

local linkedActionSpellIDs = {
    [264173] = { 264178 }, -- Demonic Core -> Demonbolt
    [433885] = { 105174, 116858, 434636, 1250197 }, -- Ruination aura -> Hand of Gul'dan, Chaos Bolt, Ruination, Eye of Gul'dan
    [433891] = { 686, 29722, 434506 }, -- Infernal Bolt aura -> Shadow Bolt, Incinerate, Infernal Bolt
}

local function canAccessValue(value)
    if issecretvalue and issecretvalue(value) then return false end
    if value == nil then return true end
    if canaccessvalue then return canaccessvalue(value) end
    return true
end

local function canAccessTable(value)
    if issecretvalue and issecretvalue(value) then return false end
    if value == nil then return true end
    if canaccesstable then return canaccesstable(value) end
    return canAccessValue(value)
end

local function isAddOnLoaded(addonName)
    return (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addonName))
        or (IsAddOnLoaded and IsAddOnLoaded(addonName))
end

local function loadAddOn(addonName)
    local loader = (C_AddOns and C_AddOns.LoadAddOn) or UIParentLoadAddOn
    if loader and not isAddOnLoaded(addonName) then
        loader(addonName)
    end
    return isAddOnLoaded(addonName)
end

local function removeAllCooldownTracking(settings)
    local dataProvider = settings:GetDataProvider()
    local layoutManager = settings:GetLayoutManager()
    if not (dataProvider and layoutManager) then return end

    local hiddenCategoryByCategory = {
        [Enum.CooldownViewerCategory.Essential] = Enum.CooldownViewerCategory.HiddenActive,
        [Enum.CooldownViewerCategory.Utility] = Enum.CooldownViewerCategory.HiddenActive,
        [Enum.CooldownViewerCategory.TrackedBuff] = Enum.CooldownViewerCategory.HiddenPassive,
        [Enum.CooldownViewerCategory.TrackedBar] = Enum.CooldownViewerCategory.HiddenPassive,
    }
    local changes = {}
    for _, cooldownID in ipairs(dataProvider:GetOrderedCooldownIDs()) do
        local cooldownInfo = dataProvider:GetCooldownInfoForID(cooldownID)
        local hiddenCategory = cooldownInfo and hiddenCategoryByCategory[cooldownInfo.category]
        if hiddenCategory then
            changes[#changes + 1] = {
                cooldownID = cooldownID,
                hiddenCategory = hiddenCategory,
            }
        end
    end

    if #changes == 0 then return end

    local failureStatus
    layoutManager:LockNotifications()
    for _, change in ipairs(changes) do
        local status = dataProvider:SetCooldownToCategory(change.cooldownID, change.hiddenCategory)
        if status ~= Enum.CooldownLayoutStatus.Success then
            failureStatus = failureStatus or status
        end
    end
    layoutManager:UnlockNotifications(true)

    if failureStatus and settings.CheckDisplayActionStatus then
        settings:CheckDisplayActionStatus(Enum.CooldownLayoutAction.ChangeCategory, failureStatus)
    end
    settings:RefreshLayout()
    settings:UpdateSaveButtonStates()
end

StaticPopupDialogs[REMOVE_ALL_TRACKING_POPUP] = {
    text = "Remove all tracked buffs, tracked bars, essential cooldowns, and utility cooldowns from this layout? You can use Revert before closing Advanced Cooldown Settings to undo this.",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, settings)
        removeAllCooldownTracking(settings)
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

local function setSettingsButtonShown(settings, shown)
    local button = settingsButtons[settings]
    if button then button:SetShown(shown) end
end

local function ensureSettingsButton(addon)
    if not addon.db.profile.overlayCooldownManagerOnConsolePort then return end
    if not loadAddOn("Blizzard_CooldownViewer") then return end

    local settings = _G.CooldownViewerSettings
    if not (settings and settings.UndoButton) then return end
    if settingsButtons[settings] then
        setSettingsButtonShown(settings, true)
        return
    end

    local button = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
    button:SetSize(60, 22)
    button:SetPoint("BOTTOMRIGHT", settings.UndoButton, "BOTTOMLEFT", -4, 0)
    button:SetText("Clear")
    button:SetScript("OnClick", function()
        StaticPopup_Show(REMOVE_ALL_TRACKING_POPUP, nil, nil, settings)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Clear")
        GameTooltip:AddLine("Moves all tracked buffs, tracked bars, essential cooldowns, and utility cooldowns into Blizzard's hidden categories for this layout.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    settingsButtons[settings] = button
    setSettingsButtonShown(settings, true)
end

local function addSpellID(spellIDs, spellID)
    if not canAccessValue(spellID) or type(spellID) ~= "number" or spellID <= 0 then return end
    if spellIDs[spellID] then return end
    spellIDs[spellID] = true
    local actionSpellIDs = linkedActionSpellIDs[spellID]
    if actionSpellIDs then
        for _, actionSpellID in ipairs(actionSpellIDs) do
            addSpellID(spellIDs, actionSpellID)
        end
    end
    if C_Spell and C_Spell.GetOverrideSpell then
        local overrideSpellID = C_Spell.GetOverrideSpell(spellID)
        if canAccessValue(overrideSpellID) and overrideSpellID and overrideSpellID > 0 then
            addSpellID(spellIDs, overrideSpellID)
        end
    end
end

local function getCooldownItemSpellIDs(item)
    local spellIDs = {}
    if item.GetSpellID then addSpellID(spellIDs, item:GetSpellID()) end
    if item.GetBaseSpellID then addSpellID(spellIDs, item:GetBaseSpellID()) end
    if item.GetLinkedSpell then addSpellID(spellIDs, item:GetLinkedSpell()) end

    local cooldownID = item.GetCooldownID and item:GetCooldownID()
    if not canAccessValue(cooldownID) then return spellIDs end
    local cooldownInfo = cooldownID
        and C_CooldownViewer
        and C_CooldownViewer.GetCooldownViewerCooldownInfo
        and C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
    if canAccessTable(cooldownInfo) and cooldownInfo then
        addSpellID(spellIDs, cooldownInfo.spellID)
        addSpellID(spellIDs, cooldownInfo.overrideSpellID)
        local linkedSpellIDs = cooldownInfo.linkedSpellIDs
        if canAccessTable(linkedSpellIDs) and linkedSpellIDs then
            for _, linkedSpellID in ipairs(linkedSpellIDs) do
                addSpellID(spellIDs, linkedSpellID)
            end
        end
    end
    return spellIDs
end

local function getActionSpellID(actionSlot)
    if not canAccessValue(actionSlot) or not actionSlot or not GetActionInfo then return nil end
    local actionType, actionID, actionSubType = GetActionInfo(actionSlot)
    if not canAccessValue(actionType)
        or not canAccessValue(actionID)
        or not canAccessValue(actionSubType)
    then
        return nil
    end
    if actionType == "spell" or (actionType == "macro" and actionSubType == "spell") then
        return actionID
    end
end

local function getConsolePortButtonSpellID(button)
    local actionType = button:GetAttribute("type")
    if not canAccessValue(actionType) then return nil end
    if actionType == "action" then
        return getActionSpellID(button:GetAttribute("action"))
    elseif actionType == "spell" then
        local spellID = button:GetAttribute("spell")
        return canAccessValue(spellID) and spellID or nil
    elseif actionType == "macro" then
        local macroID = button:GetAttribute("macro")
        if not canAccessValue(macroID) then return nil end
        local spellID = macroID and GetMacroSpell and GetMacroSpell(macroID) or nil
        return canAccessValue(spellID) and spellID or nil
    end
end

local function isConsolePortActionButton(frame)
    local signature = frame.GetAttribute and frame:GetAttribute("signature")
    return canAccessValue(signature)
        and type(signature) == "string"
        and (signature:match("^ClusterButton:") or signature:match("^GroupButton:"))
end

local function collectConsolePortButtons(frame, buttons)
    for _, child in ipairs({ frame:GetChildren() }) do
        if isConsolePortActionButton(child) then
            buttons[#buttons + 1] = child
        end
        collectConsolePortButtons(child, buttons)
    end
end

local function getConsolePortButtons()
    local manager = _G.ConsolePortBarManager
    if not manager then return {} end
    local buttons = {}
    collectConsolePortButtons(manager, buttons)
    table.sort(buttons, function(left, right)
        return (left:GetName() or "") < (right:GetName() or "")
    end)
    return buttons
end

local function getViewerItems(viewer)
    local items = {}
    if not (viewer and viewer.itemFramePool) then return items end
    for item in viewer.itemFramePool:EnumerateActive() do
        items[#items + 1] = item
    end
    table.sort(items, function(left, right)
        return (left.layoutIndex or 0) < (right.layoutIndex or 0)
    end)
    return items
end

local function restoreItemTimer(addon, item)
    local timerShown = addon.cooldownOverlayItemTimerShown[item]
    if timerShown == nil then return end
    item:SetTimerShown(timerShown)
    addon.cooldownOverlayItemTimerShown[item] = nil
end

local function applyItemActiveBuffAppearance(addon, item)
    if not (item.SetTimerShown and item.IsTimerShown) then return end
    if addon.cooldownOverlayItemTimerShown[item] == nil then
        addon.cooldownOverlayItemTimerShown[item] = item:IsTimerShown()
    end
    item:SetTimerShown(false)

    local cooldown = item.GetCooldownFrame and item:GetCooldownFrame()
    if cooldown then
        cooldown:SetSwipeColor(1, 0.95, 0.57, 0.7)
    end
end

local function isItemShowingActiveBuff(item, viewerName)
    if viewerName == "BuffIconCooldownViewer" then
        return item.IsActive and item:IsActive()
    end
    return item.wasSetFromAura == true
end

local function setItemUnmatched(addon, item)
    if C_RestrictedActions
        and C_RestrictedActions.CheckAllowProtectedFunctions
        and not C_RestrictedActions.CheckAllowProtectedFunctions(item, true)
    then
        return false
    end
    item:ClearAllPoints()
    item:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -1000, -1000)
    item:SetAlpha(0)
    restoreItemTimer(addon, item)
    return true
end

local function raiseConsolePortHotkeys(button, frameLevel)
    for _, key in ipairs(hotkeyKeys) do
        local hotkey = button[key]
        if hotkey then
            hotkey:SetFrameLevel(frameLevel)
        end
    end
end

local function isConsolePortHotkey(button, frame)
    for _, key in ipairs(hotkeyKeys) do
        if button[key] == frame then return true end
    end
    return false
end

local function isConsolePortGlow(button, frame)
    return button.__LBGoverlay == frame
end

local function raiseConsolePortGlow(button, frameLevel)
    local overlay = button.__LBGoverlay
    if overlay then
        overlay:SetFrameLevel(frameLevel)
    end
end

local function hideButtonArtwork(addon, button)
    local states = addon.cooldownOverlayButtonArtwork[button]
    if not states then
        states = {}
        addon.cooldownOverlayButtonArtwork[button] = states
    end

    local normalTexture = button.NormalTexture or (button.GetNormalTexture and button:GetNormalTexture())
    for _, region in ipairs({ button:GetRegions() }) do
        if region ~= normalTexture then
            if states[region] == nil then
                states[region] = region:GetAlpha()
            end
            region:SetAlpha(0)
        end
    end
    for _, child in ipairs({ button:GetChildren() }) do
        if not isConsolePortHotkey(button, child) and not isConsolePortGlow(button, child) then
            if states[child] == nil then
                states[child] = child:GetAlpha()
            end
            child:SetAlpha(0)
        end
    end
end

local function restoreButtonArtwork(addon, button)
    local states = addon.cooldownOverlayButtonArtwork[button]
    if not states then return end
    for region, alpha in pairs(states) do
        region:SetAlpha(alpha)
    end
    addon.cooldownOverlayButtonArtwork[button] = nil
end

local function setItemMatched(item, button)
    if C_RestrictedActions
        and C_RestrictedActions.CheckAllowProtectedFunctions
        and not C_RestrictedActions.CheckAllowProtectedFunctions(item, true)
    then
        return false
    end
    item:SetScale(1)
    item:ClearAllPoints()
    item:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    item:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    item:SetAlpha(button:GetEffectiveAlpha())
    item:SetFrameStrata(button:GetFrameStrata())
    item:SetFrameLevel(button:GetFrameLevel() + 20)
    raiseConsolePortGlow(button, item:GetFrameLevel() + 10)
    raiseConsolePortHotkeys(button, item:GetFrameLevel() + 20)
    return true
end

local function syncMatchedButtonVisuals(addon)
    for button, item in pairs(addon.cooldownOverlayMatchedButtons) do
        if button:IsShown() and item:IsVisible() then
            item:SetAlpha(button:GetEffectiveAlpha())
            hideButtonArtwork(addon, button)
        else
            restoreButtonArtwork(addon, button)
        end
    end
end

local function findMatchingButton(spellIDs, buttons, assignedButtons)
    local fallback
    for _, button in ipairs(buttons) do
        if not assignedButtons[button] then
            local spellID = getConsolePortButtonSpellID(button)
            if spellID and spellIDs[spellID] then
                if button:IsShown() and button:GetAlpha() > 0 then
                    return button
                end
                fallback = fallback or button
            end
        end
    end
    return fallback
end

local function hookConsolePortButton(addon, button)
    if hookedConsolePortButtons[button] then return end
    hookedConsolePortButtons[button] = true
    button:HookScript("OnAttributeChanged", function(_, attribute)
        if canAccessValue(attribute) and watchedButtonAttributes[attribute] then
            CooldownOverlay.RequestUpdate(addon)
        end
    end)
    button:HookScript("OnSizeChanged", function()
        CooldownOverlay.RequestUpdate(addon)
    end)
    button:HookScript("OnShow", function()
        CooldownOverlay.RequestUpdate(addon)
    end)
    button:HookScript("OnHide", function()
        CooldownOverlay.RequestUpdate(addon)
    end)
end

local function hookViewer(addon, viewer)
    if hookedViewers[viewer] then return end
    hookedViewers[viewer] = true
    hooksecurefunc(viewer, "RefreshLayout", function()
        CooldownOverlay.RequestUpdate(addon)
    end)
    viewer:HookScript("OnShow", function()
        CooldownOverlay.RequestUpdate(addon)
    end)
    viewer:HookScript("OnHide", function()
        CooldownOverlay.RequestUpdate(addon)
    end)
end

local function refreshItemActiveBuffAppearance(addon, item, viewerName)
    if addon.db.profile.removeTimerFromCooldownManagerOverlays
        and isItemShowingActiveBuff(item, viewerName)
    then
        applyItemActiveBuffAppearance(addon, item)
    end
end

local function hookViewerItem(addon, item, viewerName)
    if hookedViewerItems[item] then return end
    hookedViewerItems[item] = true
    item:HookScript("OnShow", function()
        refreshItemActiveBuffAppearance(addon, item, viewerName)
        CooldownOverlay.RequestUpdate(addon)
    end)
    item:HookScript("OnHide", function()
        CooldownOverlay.RequestUpdate(addon)
    end)
    if item.RefreshData then
        hooksecurefunc(item, "RefreshData", function()
            refreshItemActiveBuffAppearance(addon, item, viewerName)
            CooldownOverlay.RequestUpdate(addon)
        end)
    end
    if item.RefreshCooldownOnly then
        hooksecurefunc(item, "RefreshCooldownOnly", function()
            refreshItemActiveBuffAppearance(addon, item, viewerName)
            CooldownOverlay.RequestUpdate(addon)
        end)
    end
end

function CooldownOverlay.Update(addon)
    if not addon.db.profile.overlayCooldownManagerOnConsolePort then return end

    local buttons = getConsolePortButtons()
    if #buttons == 0 then return end
    for _, button in ipairs(buttons) do
        hookConsolePortButton(addon, button)
    end

    local assignedButtons = {}
    local matchedButtons = {}
    for _, viewerName in ipairs(viewerNames) do
        local viewer = _G[viewerName]
        if viewer then
            hookViewer(addon, viewer)
            for _, item in ipairs(getViewerItems(viewer)) do
                hookViewerItem(addon, item, viewerName)
                local button = viewer:IsShown() and item:IsShown()
                    and findMatchingButton(getCooldownItemSpellIDs(item), buttons, assignedButtons)
                if button and setItemMatched(item, button) then
                    if addon.db.profile.removeTimerFromCooldownManagerOverlays
                        and isItemShowingActiveBuff(item, viewerName)
                    then
                        applyItemActiveBuffAppearance(addon, item)
                    else
                        restoreItemTimer(addon, item)
                    end
                    assignedButtons[button] = true
                    matchedButtons[button] = item
                else
                    setItemUnmatched(addon, item)
                end
            end
        end
    end

    for button in pairs(addon.cooldownOverlayMatchedButtons) do
        if not matchedButtons[button] then
            restoreButtonArtwork(addon, button)
        end
    end
    addon.cooldownOverlayMatchedButtons = matchedButtons
    syncMatchedButtonVisuals(addon)
end

function CooldownOverlay.RequestUpdate(addon)
    if addon.cooldownOverlayUpdatePending then return end
    addon.cooldownOverlayUpdatePending = true
    C_Timer.After(0, function()
        addon.cooldownOverlayUpdatePending = false
        CooldownOverlay.Update(addon)
    end)
end

function CooldownOverlay.UpdateSettingsButton(addon)
    local settings = _G.CooldownViewerSettings
    if addon.db.profile.overlayCooldownManagerOnConsolePort then
        ensureSettingsButton(addon)
    elseif settings and settingsButtons[settings] then
        setSettingsButtonShown(settings, false)
    end
end

function CooldownOverlay.OpenSettings(addon)
    if not loadAddOn("Blizzard_CooldownViewer") then return end
    local settings = _G.CooldownViewerSettings
    if not settings then return end
    CooldownOverlay.UpdateSettingsButton(addon)

    local function showCooldownSettings()
        settings:ShowUIPanel()
        if settings.SetDisplayMode then
            settings:SetDisplayMode("auras")
        end
    end

    local settingsPanel = _G.SettingsPanel
    if settingsPanel and settingsPanel:IsShown() and settingsPanel.ExitWithCommit then
        settingsPanel:ExitWithCommit(true)
        C_Timer.After(0, showCooldownSettings)
    else
        showCooldownSettings()
    end
end

function CooldownOverlay.Apply(addon)
    if not addon.db.profile.overlayCooldownManagerOnConsolePort or addon.cooldownOverlayApplied then return end
    addon.cooldownOverlayApplied = true
    if not loadAddOn("ConsolePort_Bar") or not loadAddOn("Blizzard_CooldownViewer") then
        addon.cooldownOverlayApplied = nil
        return
    end

    ensureSettingsButton(addon)

    addon.cooldownOverlayMatchedButtons = {}
    addon.cooldownOverlayButtonArtwork = {}
    addon.cooldownOverlayItemTimerShown = {}
    addon.cooldownOverlayEventFrame = CreateFrame("Frame")
    for _, eventName in ipairs(watchedEvents) do
        addon.cooldownOverlayEventFrame:RegisterEvent(eventName)
    end
    addon.cooldownOverlayEventFrame:SetScript("OnEvent", function()
        CooldownOverlay.RequestUpdate(addon)
    end)
    CooldownOverlay.RequestUpdate(addon)
end

return CooldownOverlay
