local addonName, addonTable = ...
local UITweaks = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
-- Skyriding uses Bonus Bar 5, which maps to action slots 121-132.
local SKYRIDING_BAR_SLOT_START = 121
local SKYRIDING_BAR_SLOT_COUNT = 12
local defaults = {
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
        consolePortBarSharing = false,
        skyridingBarSharing = false,
    },
    global = {
        skyridingBarLayout = {},
    },
}
local defaultsProfile = defaults.profile
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS or 10

local function sanitizeSeconds(value)
    local seconds = tonumber(value)
    if seconds and seconds > 0 then return seconds end
end

local function sanitizeFontSize(value)
    local size = tonumber(value)
    if size and size >= 8 and size <= 48 then return size end
end

local function getChatFrames()
    local frames = {}
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]
        if frame then frames[#frames + 1] = frame end
    end
    return frames
end

local function hookChatFrameHover(frame)
    if frame.UITweaksHoverHooked then return end
    frame:HookScript("OnEnter", function(chatFrame)
        if UITweaks.db and UITweaks.db.profile.chatMessageFadeAfterOverride then
            if chatFrame.SetFading then chatFrame:SetFading(false) end
            if chatFrame.ResetFadeTimer then chatFrame:ResetFadeTimer() end
        end
    end)
    frame:HookScript("OnLeave", function(chatFrame)
        if UITweaks.db and UITweaks.db.profile.chatMessageFadeAfterOverride then
            -- Defer fade reset to avoid rapid OnLeave/OnEnter churn from hyperlink hover.
            C_Timer.After(0, function()
                if chatFrame.IsMouseOver and chatFrame:IsMouseOver() then return end
                if chatFrame.SetFading then chatFrame:SetFading(true) end
                if chatFrame.ResetFadeTimer then chatFrame:ResetFadeTimer() end
            end)
        end
    end)
    frame.UITweaksHoverHooked = true
end

function UITweaks:CacheDefaultChatWindowTimes()
    if not self.defaultChatWindowTimeVisible then
        self.defaultChatWindowTimeVisible = {}
        for index, frame in ipairs(getChatFrames()) do
            if frame.GetTimeVisible then self.defaultChatWindowTimeVisible[index] = frame:GetTimeVisible() end
        end
    end
end

function UITweaks:CacheDefaultChatFonts()
    if not self.defaultChatFonts then
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
                if font then frame:SetFont(font, size, flags) end
            end
        end
    end
end

function UITweaks:ApplyChatBackgroundAlpha()
    if not SetChatWindowAlpha then return end
    if self.db.profile.transparentChatBackground then
        for i = 1, NUM_CHAT_WINDOWS do
            SetChatWindowAlpha(i, 0)
        end
    elseif GetChatWindowInfo then
        for i = 1, NUM_CHAT_WINDOWS do
            local _, _, _, _, _, alpha = GetChatWindowInfo(i)
            if alpha ~= nil then
                SetChatWindowAlpha(i, alpha <= 1 and alpha * 100 or alpha)
            end
        end
    end
end

function UITweaks:ApplyChatLineFade()
    local frames = getChatFrames()
    if self.db.profile.chatMessageFadeAfterOverride then
        self:CacheDefaultChatWindowTimes()
        local seconds = sanitizeSeconds(self.db.profile.chatMessageFadeAfterSeconds) or defaultsProfile.chatMessageFadeAfterSeconds
        for _, frame in ipairs(frames) do
            if frame.SetTimeVisible then frame:SetTimeVisible(seconds) end
            if frame.SetFading then frame:SetFading(true) end
            if frame.ResetFadeTimer then frame:ResetFadeTimer() end
            hookChatFrameHover(frame)
        end
    end
end

local UIAuras = {}
UITweaks.UIAuras = UIAuras
local hookedActionButtons = setmetatable({}, { __mode = "k" })
local hookedAuraViewers = setmetatable({}, { __mode = "k" })
local hookedAuraItems = setmetatable({}, { __mode = "k" })

local function isActionButtonFrame(frame)
    if not frame or type(frame) ~= "table" then return false end
    if not frame.GetObjectType then return false end
    local objType = frame:GetObjectType()
    if objType ~= "CheckButton" and objType ~= "Button" then return false end
    if not frame.GetAttribute then return false end
    local action = frame.action or frame:GetAttribute("action")
    return type(action) == "number"
end

local function isCustomBindingButton(button)
    -- ConsolePort uses "custom" type for proxy binding buttons (e.g. target nearest).
    if not button or not button.GetAttribute then return false end
    local actionType = button:GetAttribute("type")
    if actionType == "custom" then
        return true
    end
    local actionType2 = button:GetAttribute("type2")
    if actionType2 == "custom" then
        return true
    end
    return false
end

local function getActionIDFromButton(button)
    local action = button.GetAttribute and button:GetAttribute("action") or nil
    if not action then
        action = button.action
    end
    if not action and ActionButtonUtil and ActionButtonUtil.GetActionID then
        action = ActionButtonUtil.GetActionID(button)
    end
    if not action and ActionButton_GetPagedID then
        action = ActionButton_GetPagedID(button)
    end
    if not action and ActionButton_CalculateAction then
        action = ActionButton_CalculateAction(button)
    end
    return action
end

local function getResolvedActionSlot(button, fallbackAction)
    local action = fallbackAction
    if not action then
        action = button and button.GetAttribute and button:GetAttribute("action") or nil
    end
    if ActionButtonUtil and ActionButtonUtil.GetActionID then
        local resolved = ActionButtonUtil.GetActionID(button)
        if resolved then
            return resolved
        end
    end
    if ActionButton_GetPagedID then
        local resolved = ActionButton_GetPagedID(button)
        if resolved then
            return resolved
        end
    end
    if ActionButton_CalculateAction then
        local resolved = ActionButton_CalculateAction(button)
        if resolved then
            return resolved
        end
    end
    return action
end

local function getActionSpellID(button)
    if not button then return nil end
    if button.GetAttribute then
        local actionField = button:GetAttribute("action_field")
        if actionField then
            local actionValue = button:GetAttribute(actionField)
            if actionField == "action" and actionValue then
                local actionSlot = getResolvedActionSlot(button, actionValue)
                local actionType, actionID = GetActionInfo(actionSlot)
                if actionType == "spell" then
                    return actionID
                end
                if actionType == "macro" then
                    local macroSpellID = GetMacroSpell and GetMacroSpell(actionID)
                    if macroSpellID then
                        return macroSpellID
                    end
                end
            elseif actionField == "spell" then
                return actionValue
            elseif actionField == "macro" then
                local macroSpellID = GetMacroSpell and GetMacroSpell(actionValue)
                if macroSpellID then
                    return macroSpellID
                end
            end
        end
    end

    local action = getActionIDFromButton(button)
    if not action then return nil end

    local actionType, actionID = GetActionInfo(action)
    if actionType == "spell" then
        return actionID
    end
    if actionType == "macro" then
        local macroSpellID = GetMacroSpell and GetMacroSpell(actionID)
        if macroSpellID then
            return macroSpellID
        end
    end
    return nil
end

local function getItemSpellInfoFromAction(actionID)
    if not actionID or not GetItemSpell then return end
    local spellName, spellID = GetItemSpell(actionID)
    if spellID or spellName then
        return spellID, spellName
    end
end

local function getSpellInfoFromMacro(macroID)
    if not macroID then return end
    if GetMacroSpell then
        local macroSpellID = GetMacroSpell(macroID)
        if macroSpellID then
            return macroSpellID, C_Spell.GetSpellName(macroSpellID)
        end
    end
    if GetMacroItem then
        local macroItem = GetMacroItem(macroID)
        if macroItem then
            local itemID = GetItemInfoInstant and select(1, GetItemInfoInstant(macroItem)) or nil
            local spellID, spellName = getItemSpellInfoFromAction(itemID or macroItem)
            if spellID or spellName then
                return spellID, spellName
            end
        end
    end
end

local function getActionInfoFromButton(button)
    if not button then return end
    if button.GetAttribute then
        local actionField = button:GetAttribute("action_field")
        if actionField then
            local actionValue = button:GetAttribute(actionField)
            if actionField == "action" and actionValue then
                local actionSlot = getResolvedActionSlot(button, actionValue)
                return GetActionInfo(actionSlot)
            elseif actionField == "spell" then
                return "spell", actionValue
            elseif actionField == "macro" then
                return "macro", actionValue
            elseif actionField == "item" then
                return "item", actionValue
            end
        end
    end

    local action = getActionIDFromButton(button)
    if not action then return end
    return GetActionInfo(action)
end

local function getActionKeyFromButton(button)
    local actionType, actionID = getActionInfoFromButton(button)
    if not actionType or not actionID then return nil end
    return tostring(actionType) .. ":" .. tostring(actionID)
end

local function findAuraDuration(unit, spellID, spellName)
    if spellID and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellID then
        local aura = C_UnitAuras.GetAuraDataBySpellID(unit, spellID)
        if aura and aura.duration then
            return aura.duration, aura.expirationTime
        end
    end
    if spellName and AuraUtil and AuraUtil.FindAuraByName then
        local _, _, _, _, duration, expirationTime = AuraUtil.FindAuraByName(spellName, unit, "HELPFUL")
        if duration then
            return duration, expirationTime
        end
    end
end

function UIAuras:BuildActionButtonCache()
    local buttons = {}
    local seen = {}
    local function addButton(btn)
        if not btn or seen[btn] then return end
        if isCustomBindingButton(btn) then return end
        seen[btn] = true
        table.insert(buttons, btn)
        self:HookActionButtonUpdateAction(btn)
    end

    if ActionButtonUtil and ActionButtonUtil.ActionBarButtonNames then
        for _, actionBar in ipairs(ActionButtonUtil.ActionBarButtonNames) do
            for i = 1, NUM_ACTIONBAR_BUTTONS do
                addButton(_G[actionBar .. i])
            end
        end
    end

    local frame = EnumerateFrames()
    while frame do
        if isActionButtonFrame(frame) then
            if getActionSpellID(frame) then
                addButton(frame)
            elseif self.db and self.db.profile and self.db.profile.showActionButtonAuraTimers then
                local actionType = getActionInfoFromButton(frame)
                if actionType then
                    addButton(frame)
                end
            end
        end
        frame = EnumerateFrames(frame)
    end

    self.actionButtonsCache = buttons
end

function UIAuras:HookActionButtonUpdateAction(button)
    if not button or hookedActionButtons[button] then return end
    if type(button.UpdateAction) ~= "function" then return end
    hooksecurefunc(button, "UpdateAction", function()
        self:RequestActionButtonAuraRefresh()
        local overlay = self.actionButtonAuraOverlays and self.actionButtonAuraOverlays[button] or nil
        if overlay and overlay.manualActionKey then
            local currentKey = getActionKeyFromButton(button)
            if currentKey ~= overlay.manualActionKey then
                overlay.manualStart = nil
                overlay.manualDuration = nil
                overlay.manualActionKey = nil
                if overlay.Update then overlay:Update() end
            end
        end
    end)
    hookedActionButtons[button] = true
end

function UIAuras:ResolveActionButtonInfo(button)
    local actionType, actionID = getActionInfoFromButton(button)
    if not actionType then return end
    local spellID
    local spellName
    local itemName
    if actionType == "spell" then
        spellID = actionID
        spellName = C_Spell.GetSpellName(spellID)
    elseif actionType == "item" then
        spellID, spellName = getItemSpellInfoFromAction(actionID)
        if GetItemInfo then
            itemName = GetItemInfo(actionID)
        end
    elseif actionType == "macro" then
        spellID, spellName = getSpellInfoFromMacro(actionID)
    end

    if not spellName and itemName then
        spellName = itemName
    end
    if not spellName then return end
    return spellID, spellName
end

function UIAuras:ReapplyManualHighlightsFromPlayerAuras()
    if not self.db or not self.db.profile or not self.db.profile.showActionButtonAuraTimers then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if not self.actionButtonsCache or self.actionButtonsCacheDirty then
        self.actionButtonsCacheDirty = nil
        self:BuildActionButtonCache()
    end
    local auraBySpellID = {}
    local auraByName = {}
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local index = 1
        while true do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
            if not aura then break end
            if aura.spellId then
                auraBySpellID[aura.spellId] = aura
            end
            if aura.name then
                auraByName[aura.name] = aura
            end
            index = index + 1
        end
    elseif AuraUtil and AuraUtil.ForEachAura then
        AuraUtil.ForEachAura("player", "HELPFUL", nil, function(aura)
            if aura.spellId then
                auraBySpellID[aura.spellId] = aura
            end
            if aura.name then
                auraByName[aura.name] = aura
            end
            return true
        end)
    end
    for _, button in ipairs(self.actionButtonsCache or {}) do
        local overlay = self:GetActionButtonAuraOverlay(button)
        if not overlay.viewerAuraUnit or not overlay.viewerAuraInstanceID then
            local spellID, spellName = self:ResolveActionButtonInfo(button)
            local aura = (spellID and auraBySpellID[spellID]) or (spellName and auraByName[spellName]) or nil
            if aura and aura.duration and aura.duration > 0 and aura.expirationTime then
                local startTime = aura.expirationTime - aura.duration
                overlay.manualActionKey = getActionKeyFromButton(button)
                overlay:SetManualCooldownFromStart(startTime, aura.duration)
            elseif overlay.manualStart then
                overlay.manualStart = nil
                overlay.manualDuration = nil
                overlay.manualActionKey = nil
                overlay:Update()
            end
        end
    end
end

function UIAuras:ScheduleReapplyManualHighlightsFromPlayerAuras()
    if self.pendingReapplyPlayerAuras then return end
    self.pendingReapplyPlayerAuras = true
    local function run()
        self.pendingReapplyPlayerAuras = false
        self:ReapplyManualHighlightsFromPlayerAuras()
    end
    C_Timer.After(0.05, run)
end

function UIAuras:FindActionButtonsForSpellName(name)
    if not self.actionButtonsCache then
        self:BuildActionButtonCache()
    end
    local matches = {}
    for _, btn in ipairs(self.actionButtonsCache) do
        local actionSpellID = getActionSpellID(btn)
        if actionSpellID then
            local baseSpellID = C_Spell.GetBaseSpell(actionSpellID)
            local actionSpellName = C_Spell.GetSpellName(baseSpellID)
            if name == actionSpellName then
                table.insert(matches, btn)
            end
        end
    end
    if StanceBar and StanceBar.actionButtons then
        for i = 1, NUM_SPECIAL_BUTTONS do
            local stanceBtn = StanceBar.actionButtons[i]
            if stanceBtn then
                local stanceSpellID = select(4, GetShapeshiftFormInfo(stanceBtn:GetID()))
                if stanceSpellID then
                    local stanceSpellName = C_Spell.GetSpellName(stanceSpellID)
                    if name == stanceSpellName then
                        table.insert(matches, stanceBtn)
                    end
                end
            end
        end
    end
    return matches
end

function UIAuras:GetActionButtonList(spellID)
    local buttonList = {}
    local seen = {}
    local spellName = C_Spell.GetSpellName(spellID)
    if not spellName then return buttonList end
    local buttons = self:FindActionButtonsForSpellName(spellName)
    for _, button in ipairs(buttons) do
        if not seen[button] then
            seen[button] = true
            table.insert(buttonList, button)
        end
    end
    return buttonList
end

local function createActionButtonAuraOverlay(actionButton)
    local overlay = CreateFrame("Frame", nil, actionButton)
    overlay:SetAllPoints(actionButton)

    local parentCooldown = actionButton.cooldown or actionButton.Cooldown
    if parentCooldown and parentCooldown.GetFrameLevel then
        overlay:SetFrameLevel(parentCooldown:GetFrameLevel() + 1)
    end

    local cooldown = CreateFrame("Cooldown", nil, overlay, "CooldownFrameTemplate")
    overlay.Cooldown = cooldown
    local icon = actionButton.icon or actionButton.Icon
    if icon then
        cooldown:SetPoint("TOPLEFT", icon, "LEFT", 5, 0)
        cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOM", 0, 3)
    else
        cooldown:SetAllPoints(overlay)
    end
    cooldown:SetDrawSwipe(false)
    cooldown:SetCountdownFont("NumberFontNormal")
    cooldown:SetCountdownAbbrevThreshold(60)
    cooldown:SetScript("OnCooldownDone", function()
        if overlay.Update then overlay:Update() end
    end)

    local stacks = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    stacks:SetPoint("TOPLEFT", 5, -5)
    overlay.Stacks = stacks

    local glow = overlay:CreateTexture(nil, "ARTWORK")
    glow:SetAllPoints(overlay)
    glow:SetBlendMode("ADD")
    glow:SetTexture("Interface\\AddOns\\UITweaks\\Textures\\Overlay")
    glow:Hide()
    overlay.Glow = glow

    function overlay:SetViewerItem(item, spellID)
        if item and item.auraDataUnit and item.auraInstanceID then
            self.viewerAuraUnit = item.auraDataUnit
            self.viewerAuraInstanceID = item.auraInstanceID
            self.viewerSpellID = spellID
            if UnitGUID then
                self.viewerUnitGUID = UnitGUID(item.auraDataUnit)
            else
                self.viewerUnitGUID = nil
            end
            self.manualStart = nil
            self.manualDuration = nil
            return
        end
        self.viewerAuraUnit = nil
        self.viewerAuraInstanceID = nil
        self.viewerSpellID = nil
        self.viewerUnitGUID = nil
    end

    function overlay:Update()
        if not self.viewerAuraUnit or not self.viewerAuraInstanceID then
            if self.manualStart and self.manualDuration and GetTime then
                local now = GetTime()
                if now < (self.manualStart + self.manualDuration) then
                    self.Cooldown:SetCooldown(self.manualStart, self.manualDuration)
                    self.Cooldown:Show()
                    if self.Glow then
                        self.Glow:SetVertexColor(0, 0.7, 0, 0.5)
                        self.Glow:Show()
                    end
                    self:Show()
                    return
                end
            end
            self.manualStart = nil
            self.manualDuration = nil
            if self.Glow then self.Glow:Hide() end
            self:Hide()
            return
        end

        local unit = self.viewerAuraUnit
        local auraInstanceID = self.viewerAuraInstanceID
        if unit and auraInstanceID then
            if UnitExists and unit ~= "player" and not UnitExists(unit) then
                self.viewerAuraUnit = nil
                self.viewerAuraInstanceID = nil
                self.viewerSpellID = nil
                self.viewerUnitGUID = nil
                self.Stacks:SetText("")
                self.Stacks:Hide()
                self.Cooldown:Hide()
                self.Glow:Hide()
                self:Hide()
                return
            end
            if self.viewerUnitGUID and UnitGUID then
                local currentGUID = UnitGUID(unit)
                if not currentGUID or currentGUID ~= self.viewerUnitGUID then
                    self.viewerAuraUnit = nil
                    self.viewerAuraInstanceID = nil
                    self.viewerSpellID = nil
                    self.viewerUnitGUID = nil
                    self.Stacks:SetText("")
                    self.Stacks:Hide()
                    self.Cooldown:Hide()
                    self.Glow:Hide()
                    self:Hide()
                    return
                end
            end
            local duration = C_UnitAuras.GetAuraDuration(unit, auraInstanceID)
            if duration then
                self.Cooldown:SetCooldownFromDurationObject(duration, true)
                self.Cooldown:Show()
            else
                self.viewerAuraUnit = nil
                self.viewerAuraInstanceID = nil
                self.viewerSpellID = nil
                self.viewerUnitGUID = nil
                self.Stacks:SetText("")
                self.Stacks:Hide()
                self.Cooldown:Hide()
                self.Glow:Hide()
                self:Hide()
                return
            end

            local count = C_UnitAuras.GetAuraApplicationDisplayCount(unit, auraInstanceID)
            local numericCount = tonumber(count)
            if numericCount and numericCount > 1 then
                self.Stacks:SetText(numericCount)
                self.Stacks:Show()
            else
                self.Stacks:SetText("")
                self.Stacks:Hide()
            end

            if unit == "player" then
                self.Glow:SetVertexColor(0, 0.7, 0, 0.5)
            else
                self.Glow:SetVertexColor(1, 0, 0, 0.5)
            end
            self.Glow:Show()
            self:Show()
        else
            self.Glow:Hide()
            self:Hide()
        end
    end

    function overlay:SetManualCooldown(durationSeconds)
        if not durationSeconds or durationSeconds <= 0 or not GetTime then return end
        self.viewerAuraUnit = nil
        self.viewerAuraInstanceID = nil
        self.viewerSpellID = nil
        self.viewerUnitGUID = nil
        self.manualStart = GetTime()
        self.manualDuration = durationSeconds
        self:Update()
    end

    function overlay:SetManualCooldownFromStart(startTime, durationSeconds)
        if not startTime or not durationSeconds or durationSeconds <= 0 then return end
        self.viewerAuraUnit = nil
        self.viewerAuraInstanceID = nil
        self.viewerSpellID = nil
        self.viewerUnitGUID = nil
        self.manualStart = startTime
        self.manualDuration = durationSeconds
        self:Update()
    end

    overlay:Hide()
    return overlay
end

function UIAuras:ReportCooldownViewerMissing()
    if self.cooldownViewerMissingReported then return end
    self.cooldownViewerMissingReported = true

    local message = "UITweaks: Aura timers require Cooldown Viewer, but it's disabled. Enable: Options -> Gameplay Enhancements -> Enable Cooldown Manager."
    if self.Print then
        self:Print(message)
    elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    end

    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(message, 1, 0.2, 0.2)
    end
end

function UIAuras:IsCooldownViewerVisible(viewer)
    if not viewer or not viewer.GetAlpha then return false end
    local alpha = viewer:GetAlpha()
    if alpha and alpha <= 0 then return false end
    if viewer.IsShown then
        return viewer:IsShown()
    end
    return true
end

function UIAuras:GetActionButtonAuraOverlay(actionButton)
    if not self.actionButtonAuraOverlays then
        self.actionButtonAuraOverlays = {}
    end
    if not self.actionButtonAuraOverlays[actionButton] then
        self.actionButtonAuraOverlays[actionButton] = createActionButtonAuraOverlay(actionButton)
    end
    return self.actionButtonAuraOverlays[actionButton]
end

function UIAuras:UpdateActionButtonAuraFromItem(item)
    if not self.db.profile.showActionButtonAuraTimers then return end
    if not item.cooldownID then return end
    if not item.auraDataUnit or not item.auraInstanceID then return end
    if not C_CooldownViewer or not C_CooldownViewer.GetCooldownViewerCooldownInfo then
        self:ReportCooldownViewerMissing()
        return
    end

    local cdInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(item.cooldownID)
    if cdInfo and cdInfo.spellID then
        local buttonList = self:GetActionButtonList(cdInfo.spellID)
        for _, button in ipairs(buttonList) do
            local overlay = self:GetActionButtonAuraOverlay(button)
            overlay:SetViewerItem(item, cdInfo.spellID)
            overlay:Update()
        end
    end
end

function UIAuras:UpdateActionButtonAurasFromViewer(viewer)
    if not viewer or not viewer.GetItemFrames then return end
    for _, itemFrame in ipairs(viewer:GetItemFrames()) do
        if itemFrame.cooldownID then
            self:UpdateActionButtonAuraFromItem(itemFrame)
        end
    end
end

function UIAuras:HookActionButtonAuraViewer(viewer)
    if not viewer or hookedAuraViewers[viewer] then return end
    local hook = function(_, item) self:HookActionButtonAuraViewerItem(item) end
    hooksecurefunc(viewer, "OnAcquireItemFrame", hook)
    hookedAuraViewers[viewer] = true
end

function UIAuras:HookActionButtonAuraViewerItem(item)
    if not item or hookedAuraItems[item] then return end
    local hook = function() self:UpdateActionButtonAuraFromItem(item) end
    hooksecurefunc(item, "RefreshData", hook)
    hookedAuraItems[item] = true
end

function UIAuras:RefreshActionButtonAuraOverlays(rebuildCache)
    if not self.actionButtonAuraOverlays then return end
    if rebuildCache then
        self.actionButtonsCache = nil
        self:BuildActionButtonCache()
    end
    for _, overlay in pairs(self.actionButtonAuraOverlays) do
        overlay:SetViewerItem(nil)
    end
    self:UpdateActionButtonAurasFromViewer(BuffBarCooldownViewer)
    self:UpdateActionButtonAurasFromViewer(BuffIconCooldownViewer)
    self:UpdateActionButtonAurasFromViewer(EssentialCooldownViewer)
    self:UpdateActionButtonAurasFromViewer(UtilityCooldownViewer)
    for _, overlay in pairs(self.actionButtonAuraOverlays) do
        overlay:Update()
    end
end

function UIAuras:RequestActionButtonAuraRefresh(rebuildCache)
    if not self.db or not self.db.profile or not self.db.profile.showActionButtonAuraTimers then
        return
    end
    if rebuildCache then
        self.actionButtonsCacheDirty = true
    end
    if self.pendingAuraRefresh then return end
    self.pendingAuraRefresh = true

    local function run()
        self.pendingAuraRefresh = false
        if not self.db or not self.db.profile or not self.db.profile.showActionButtonAuraTimers then
            self.actionButtonsCacheDirty = nil
            return
        end
        self:RefreshActionButtonAuraOverlays(self.actionButtonsCacheDirty)
        self.actionButtonsCacheDirty = nil
    end

    C_Timer.After(0, run)
end

function UIAuras:ClearActionButtonAuraOverlays()
    if not self.actionButtonAuraOverlays then return end
    for _, overlay in pairs(self.actionButtonAuraOverlays) do
        overlay:SetViewerItem(nil)
        overlay:Update()
    end
end

function UIAuras:InitializeActionButtonAuraTimers()
    if self.actionButtonAuraTimersInitialized then return end
    if not C_UnitAuras or not C_UnitAuras.GetAuraDuration then return end
    if not BuffBarCooldownViewer or not BuffIconCooldownViewer then
        if UIParentLoadAddOn then
            UIParentLoadAddOn("Blizzard_BuffFrame")
        end
    end
    if (not EssentialCooldownViewer or not UtilityCooldownViewer) and UIParentLoadAddOn then
        UIParentLoadAddOn("Blizzard_CooldownViewer")
    end
    if not BuffBarCooldownViewer or not BuffIconCooldownViewer then
        self:ReportCooldownViewerMissing()
        return
    end
    local buffBarVisible = self:IsCooldownViewerVisible(BuffBarCooldownViewer)
    local buffIconVisible = self:IsCooldownViewerVisible(BuffIconCooldownViewer)
    local essentialVisible = self:IsCooldownViewerVisible(EssentialCooldownViewer)
    local utilityVisible = self:IsCooldownViewerVisible(UtilityCooldownViewer)
    if not buffBarVisible and not buffIconVisible and not essentialVisible and not utilityVisible then
        self:ReportCooldownViewerMissing()
        return
    end
    self.actionButtonAuraTimersInitialized = true
    self.actionButtonAuraOverlays = self.actionButtonAuraOverlays or {}
    self.actionButtonsCache = nil

    self:HookActionButtonAuraViewer(BuffBarCooldownViewer)
    self:HookActionButtonAuraViewer(BuffIconCooldownViewer)
    self:HookActionButtonAuraViewer(EssentialCooldownViewer)
    self:HookActionButtonAuraViewer(UtilityCooldownViewer)

    self:BuildActionButtonCache()
    self:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    self:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
    self:RegisterEvent("MODIFIER_STATE_CHANGED")
    self:RegisterEvent("UNIT_AURA")
    self:RegisterConsolePortActionPageCallback()
end

function UIAuras:RegisterConsolePortActionPageCallback()
    if self.consolePortActionPageCallbackRegistered then return end
    local consolePort = _G.ConsolePort
    if not consolePort or not consolePort.GetData then return end
    local data = consolePort:GetData()
    if not data or not data.RegisterCallback then return end
    data:RegisterCallback("OnActionPageChanged", self.ConsolePortActionPageChanged, self)
    self.consolePortActionPageCallbackRegistered = true
end

function UIAuras:ConsolePortActionPageChanged()
    self:RequestActionButtonAuraRefresh(true)
    self:ScheduleReapplyManualHighlightsFromPlayerAuras()
end

function UIAuras:ApplyCooldownViewerAlpha()
    local shouldHide = self.db.profile.showActionButtonAuraTimers and self.db.profile.hideBlizzardCooldownViewer
    if shouldHide and UIParentLoadAddOn then
        if not BuffBarCooldownViewer or not BuffIconCooldownViewer then
            UIParentLoadAddOn("Blizzard_BuffFrame")
        end
    end

    self.defaultCooldownViewerScale = self.defaultCooldownViewerScale or {}
    self.defaultCooldownViewerAnchors = self.defaultCooldownViewerAnchors or {}
    local function applyViewerTransform(viewer, key)
        if not viewer then return end
        if self.defaultCooldownViewerScale[key] == nil and viewer.GetScale then
            self.defaultCooldownViewerScale[key] = viewer:GetScale() or 1
        end
        if self.defaultCooldownViewerAnchors[key] == nil and viewer.GetNumPoints and viewer.GetPoint then
            local points = {}
            for i = 1, viewer:GetNumPoints() do
                points[i] = { viewer:GetPoint(i) }
            end
            self.defaultCooldownViewerAnchors[key] = points
        end
        if shouldHide then
            if viewer.SetScale then
                viewer:SetScale(0.01)
            end
            if viewer.ClearAllPoints and viewer.SetPoint then
                viewer:ClearAllPoints()
                viewer:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -20000, 20000)
            end
        else
            if viewer.SetScale then
                viewer:SetScale(self.defaultCooldownViewerScale[key] or 1)
            end
            local anchors = self.defaultCooldownViewerAnchors[key]
            if anchors and viewer.ClearAllPoints and viewer.SetPoint then
                viewer:ClearAllPoints()
                for _, point in ipairs(anchors) do
                    viewer:SetPoint(unpack(point))
                end
            end
        end
    end

    applyViewerTransform(BuffBarCooldownViewer, "buffBar")
    applyViewerTransform(BuffIconCooldownViewer, "buffIcon")
    applyViewerTransform(EssentialCooldownViewer, "essential")
    applyViewerTransform(UtilityCooldownViewer, "utility")
end

function UIAuras:ApplyActionButtonAuraTimers()
    if self.db.profile.showActionButtonAuraTimers then
        self:InitializeActionButtonAuraTimers()
        self:RefreshActionButtonAuraOverlays()
    else
        self:ClearActionButtonAuraOverlays()
    end
    self:ApplyCooldownViewerAlpha()
end

function UIAuras:ACTIONBAR_SLOT_CHANGED()
    self:RequestActionButtonAuraRefresh()
end

function UIAuras:ACTIONBAR_PAGE_CHANGED()
    self:RequestActionButtonAuraRefresh(true)
    self:ScheduleReapplyManualHighlightsFromPlayerAuras()
end

function UIAuras:MODIFIER_STATE_CHANGED()
    self:RequestActionButtonAuraRefresh(true)
    self:ScheduleReapplyManualHighlightsFromPlayerAuras()
end

function UIAuras:UNIT_AURA(_, unit)
    if unit ~= "player" and unit ~= "target" then return end
    self:RequestActionButtonAuraRefresh()
    if unit == "player" then
        self:ScheduleReapplyManualHighlightsFromPlayerAuras()
    end
end

for key, value in pairs(UIAuras) do
    if UITweaks[key] == nil then
        UITweaks[key] = value
    end
end

function UITweaks:HideHelpTips()
    if self.db and self.db.profile.hideHelpTips and HelpTip then
        if HelpTip.HideAllSystem then HelpTip:HideAllSystem() end
        if HelpTip.HideAll then HelpTip:HideAll(UIParent) end
    end
end

function UITweaks:HookHelpTipFrames()
    self:EnsureHelpTipHooks()
    self:HideHelpTips()
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
        if loaded and ObjectiveTrackerFrame then return true end
    end
end

function UITweaks:IsObjectiveTrackerCollapsed()
    if ObjectiveTrackerFrame then
        if ObjectiveTrackerFrame.IsCollapsed then return ObjectiveTrackerFrame:IsCollapsed() end
        if ObjectiveTrackerFrame.collapsed ~= nil then return ObjectiveTrackerFrame.collapsed end
    end
end

function UITweaks:ShouldCollapseObjectiveTracker()
    return self.db.profile.collapseObjectiveTrackerInRaids
        or self.db.profile.collapseObjectiveTrackerInDungeons
        or self.db.profile.collapseObjectiveTrackerEverywhereElse
end

function UITweaks:CollapseTrackerIfNeeded()
    if self:ShouldCollapseObjectiveTracker() then
        local shouldCollapse = true
        local inInstance, instanceType = IsInInstance()
        if inInstance and instanceType == "raid" then
            shouldCollapse = self.db.profile.collapseObjectiveTrackerInRaids
        elseif inInstance and instanceType == "party" then
            shouldCollapse = self.db.profile.collapseObjectiveTrackerInDungeons
        else
            shouldCollapse = self.db.profile.collapseObjectiveTrackerEverywhereElse
        end
        if shouldCollapse and self:EnsureObjectiveTrackerLoaded() then
            if not self:IsObjectiveTrackerCollapsed() then
                collapseObjectiveTracker()
                self.trackerCollapsedByAddon = true
            else
                self.trackerCollapsedByAddon = false
            end
        end
    end
end

function UITweaks:ExpandTrackerIfNeeded(force)
    if self:EnsureObjectiveTrackerLoaded() then
        if force or self.trackerCollapsedByAddon then
            expandObjectiveTracker()
            self.trackerCollapsedByAddon = false
        end
    end
end

function UITweaks:UpdateObjectiveTrackerState()
    if self:ShouldCollapseObjectiveTracker() then
        if InCombatLockdown and InCombatLockdown() then
            self:CollapseTrackerIfNeeded()
        else
            self:ExpandTrackerIfNeeded()
        end
    end
end

local function setBuffFrameAlpha(alpha)
    if BuffFrame then
        BuffFrame:SetAlpha(alpha)
        BuffFrame:Show()
        if BuffFrame.CollapseAndExpandButton then
            BuffFrame.CollapseAndExpandButton:SetAlpha(alpha)
            BuffFrame.CollapseAndExpandButton:Show()
        end
    end
end

local function setBuffFrameHoverPolling(enabled)
    if not BuffFrame then return end
    if BuffFrame.UITweaksHoverTicker then
        BuffFrame.UITweaksHoverTicker:Cancel()
        BuffFrame.UITweaksHoverTicker = nil
    end
    if not enabled then return end

    BuffFrame.UITweaksHoverTicker = C_Timer.NewTicker(0.1, function()
        if not (UITweaks.db and UITweaks.db.profile.hideBuffFrame and BuffFrame) then return end
        local overBuffs = BuffFrame:IsMouseOver()
        local overButton = BuffFrame.CollapseAndExpandButton and BuffFrame.CollapseAndExpandButton:IsMouseOver()
        if overBuffs or overButton then
            setBuffFrameAlpha(1)
        else
            setBuffFrameAlpha(0)
        end
    end)
end

local function ensureBuffFrameLoaded()
    if BuffFrame then return true end
    if UIParentLoadAddOn then
        local loaded = UIParentLoadAddOn("Blizzard_BuffFrame")
        if loaded and BuffFrame then return true end
    end
end

function UITweaks:ApplyBuffFrameHide(retry)
    if ensureBuffFrameLoaded() and BuffFrame then
        if self.db.profile.hideBuffFrame then
            if not BuffFrame.UITweaksHooked then
                -- Keep the buff frame faded out after UI refreshes.
                BuffFrame:HookScript("OnShow", function()
                    if UITweaks.db and UITweaks.db.profile.hideBuffFrame then
                        setBuffFrameAlpha(0)
                    end
                end)
                BuffFrame.UITweaksHooked = true
            end
            setBuffFrameHoverPolling(true)
            setBuffFrameAlpha(0)
        else
            setBuffFrameHoverPolling(false)
            setBuffFrameAlpha(1)
        end
    elseif not retry then
        C_Timer.After(0.5, function() self:ApplyBuffFrameHide(true) end)
    end
end

local function UpdateCombatFrameVisibility(frame, profileKey, stateDriver, delayStateDriver)
    if not frame then return end
    if UITweaks.db and UITweaks.db.profile and UITweaks.db.profile[profileKey] then
        if not frame.UITweaksHooked then
            -- Keep frames hidden outside combat when addons try to show them.
            frame:HookScript("OnShow", function(shownFrame)
                if UITweaks.db and UITweaks.db.profile and UITweaks.db.profile[profileKey] then
                    if not (InCombatLockdown and InCombatLockdown()) and not UITweaks.visibilityDelayActive then
                        shownFrame:Hide()
                    end
                end
            end)
            frame.UITweaksHooked = true
        end
        if RegisterStateDriver then
            if not (InCombatLockdown and InCombatLockdown()) then
                local driver = UITweaks.visibilityDelayActive and delayStateDriver or stateDriver
                if driver then
                    RegisterStateDriver(frame, "visibility", driver)
                end
            end
        end
        if not (InCombatLockdown and InCombatLockdown()) and not UITweaks.visibilityDelayActive then
            frame:Hide()
        end
    end
end

function UITweaks:UpdatePlayerFrameVisibility()
    UpdateCombatFrameVisibility(PlayerFrame, "hidePlayerFrameOutOfCombat", "[combat] show; hide", "show")
end

function UITweaks:UpdateTargetFrameVisibility()
    UpdateCombatFrameVisibility(_G.TargetFrame, "hideTargetFrameOutOfCombat", "[combat,@target,exists] show; hide", "[@target,exists] show; hide")
end

function UITweaks:UpdateBackpackButtonVisibility()
    if self.bagsBarHoverTicker then
        self.bagsBarHoverTicker:Cancel()
        self.bagsBarHoverTicker = nil
    end
    if not self.db.profile.hideBackpackButton then
        if _G.BagsBar then
            _G.BagsBar:SetAlpha(1)
            _G.BagsBar:Show()
        end
        return
    end
    if _G.BagsBar then
        _G.BagsBar:SetAlpha(0)
        _G.BagsBar:Show()
    end
    if _G.BagsBar then
        self.bagsBarHoverTicker = C_Timer.NewTicker(0.1, function()
            if not (UITweaks.db and UITweaks.db.profile.hideBackpackButton and _G.BagsBar) then return end
            if _G.BagsBar:IsMouseOver() then
                _G.BagsBar:SetAlpha(1)
            else
                _G.BagsBar:SetAlpha(0)
            end
        end)
    end
end

function UITweaks:UpdateDamageMeterVisibility(retry)
    if self.damageMeterHoverTicker then
        self.damageMeterHoverTicker:Cancel()
        self.damageMeterHoverTicker = nil
    end
    if not _G.DamageMeter then
        if not retry then
            C_Timer.After(0.5, function() self:UpdateDamageMeterVisibility(true) end)
        end
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        _G.DamageMeter:SetAlpha(1)
        _G.DamageMeter:Show()
        return
    end
    if self.visibilityDelayActive then
        _G.DamageMeter:SetAlpha(1)
        _G.DamageMeter:Show()
        return
    end
    if not self.db.profile.hideDamageMeter then
        _G.DamageMeter:SetAlpha(1)
        _G.DamageMeter:Show()
        return
    end
    if not _G.DamageMeter.UITweaksHooked then
        _G.DamageMeter:HookScript("OnShow", function(frame)
            if UITweaks.db and UITweaks.db.profile.hideDamageMeter
                and not (InCombatLockdown and InCombatLockdown()) then
                frame:SetAlpha(0)
            end
        end)
        _G.DamageMeter.UITweaksHooked = true
    end
    _G.DamageMeter:SetAlpha(0)
    _G.DamageMeter:Show()
    if _G.DamageMeter then
        self.damageMeterHoverTicker = C_Timer.NewTicker(0.1, function()
            if not (UITweaks.db and UITweaks.db.profile.hideDamageMeter and _G.DamageMeter) then return end
            if InCombatLockdown and InCombatLockdown() then
                _G.DamageMeter:SetAlpha(1)
                return
            end
            if UITweaks.visibilityDelayActive then
                _G.DamageMeter:SetAlpha(1)
                return
            end
            if _G.DamageMeter:IsMouseOver() then
                _G.DamageMeter:SetAlpha(1)
            else
                _G.DamageMeter:SetAlpha(0)
            end
        end)
    end
end

function UITweaks:UpdateChatTabsVisibility()
    self.hiddenChatTabs = self.hiddenChatTabs or {}
    if self.chatTabsHoverTicker then
        self.chatTabsHoverTicker:Cancel()
        self.chatTabsHoverTicker = nil
    end
    local function isChatWindowActive(index, tab)
        if FCF_IsChatWindowIndexActive then
            return FCF_IsChatWindowIndexActive(index)
        end
        if tab and tab.IsShown then
            return tab:IsShown()
        end
        return false
    end
    for i = 1, NUM_CHAT_WINDOWS do
        local tabName = "ChatFrame" .. i .. "Tab"
        local tab = _G[tabName]
        if tab and not tab.UITweaksHooked then
            -- Keep tabs faded out even when hover/OnShow tries to reveal them.
            tab:HookScript("OnShow", function(frame)
                if UITweaks.db and UITweaks.db.profile.hideChatTabs then
                    frame:SetAlpha(0)
                end
            end)
            tab.UITweaksHooked = true
        end
        if tab then
            if self.db.profile.hideChatTabs then
                if isChatWindowActive(i, tab) then
                    tab:SetAlpha(0)
                    self.hiddenChatTabs[tabName] = true
                end
            else
                tab:SetAlpha(1)
                self.hiddenChatTabs[tabName] = nil
            end
        end
    end
    if self.db.profile.hideChatTabs then
        self.chatTabsHoverTicker = C_Timer.NewTicker(0.1, function()
            if not (UITweaks.db and UITweaks.db.profile.hideChatTabs) then return end
            for i = 1, NUM_CHAT_WINDOWS do
                local tab = _G["ChatFrame" .. i .. "Tab"]
                if tab and isChatWindowActive(i, tab) then
                    if tab:IsMouseOver() then
                        tab:SetAlpha(1)
                    else
                        tab:SetAlpha(0)
                    end
                end
            end
        end)
    end
end

function UITweaks:UpdateChatMenuButtonVisibility()
    local button = _G.ChatFrameMenuButton
    if not button then return end
    if self.db.profile.hideChatMenuButton then
        if not button.UITweaksHooked then
            -- Keep the menu button hidden even when UI code shows it.
            button:HookScript("OnShow", function(frame)
                if UITweaks.db and UITweaks.db.profile.hideChatMenuButton then
                    frame:Hide()
                end
            end)
            button.UITweaksHooked = true
        end
        button:Hide()
    end
end

local function ensureGroupLootHistoryLoaded()
    if _G.GroupLootHistoryFrame then return true end
    local loadAddOn = C_AddOns and C_AddOns.LoadAddOn or UIParentLoadAddOn
    if loadAddOn then
        local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_GroupLootHistory"))
            or (IsAddOnLoaded and IsAddOnLoaded("Blizzard_GroupLootHistory"))
        if not isLoaded then
            loadAddOn("Blizzard_GroupLootHistory")
        end
    end
    return _G.GroupLootHistoryFrame ~= nil
end

function UITweaks:UpdateGroupLootHistoryVisibility()
    if not ensureGroupLootHistoryLoaded() then return end
    local frame = _G.GroupLootHistoryFrame
    if not frame then return end
    if self.db.profile.hideGroupLootHistoryFrame then
        if not frame.UITweaksHooked then
            frame:HookScript("OnShow", function(shownFrame)
                if UITweaks.db and UITweaks.db.profile.hideGroupLootHistoryFrame then
                    shownFrame:Hide()
                end
            end)
            frame.UITweaksHooked = true
        end
        frame:Hide()
    end
end

local function getMicroMenuButtons()
    local buttons = {}
    local function addButtonsFromParent(parent)
        if not (parent and parent.GetChildren) then return end
        local children = { parent:GetChildren() }
        for _, child in ipairs(children) do
            if child and child.IsObjectType and child:IsObjectType("Button") then
                buttons[#buttons + 1] = child
            elseif child and child.GetChildren then
                addButtonsFromParent(child)
            end
        end
    end
    local parent = _G.MicroMenuContainer or _G.MicroButtonAndBagsBar or _G.MicroMenu
    addButtonsFromParent(parent)
    return buttons
end

function UITweaks:UpdateMicroMenuVisibility()
    for _, button in ipairs(getMicroMenuButtons()) do
        local name = button and button.GetName and button:GetName() or ""
        if self.db.profile.hideMicroMenuButtons and name ~= "QueueStatusButton" then
            if not button.UITweaksHooked then
                button:HookScript("OnShow", function(btn)
                    if UITweaks.db and UITweaks.db.profile.hideMicroMenuButtons then
                        local btnName = btn and btn.GetName and btn:GetName() or ""
                        if btnName ~= "QueueStatusButton" then
                            btn:Hide()
                        end
                    end
                end)
                button.UITweaksHooked = true
            end
            button:Hide()
        end
    end
end

local function getStanceBars()
    local bars = {}
    if _G.StanceBar then bars[#bars + 1] = _G.StanceBar end
    if _G.ShapeshiftBarFrame and _G.ShapeshiftBarFrame ~= _G.StanceBar then
        bars[#bars + 1] = _G.ShapeshiftBarFrame
    end
    return bars
end

local function getStanceButtons()
    local buttons = {}
    local numButtons = NUM_STANCE_SLOTS or NUM_SHAPESHIFT_SLOTS or 10
    for i = 1, numButtons do
        local button = _G["StanceButton" .. i] or _G["ShapeshiftButton" .. i]
        if button then buttons[#buttons + 1] = button end
    end
    return buttons
end

local function setStanceAlpha(alpha)
    for _, stanceBar in ipairs(getStanceBars()) do
        if stanceBar then
            stanceBar:SetAlpha(alpha)
            stanceBar:Show()
        end
    end
    for _, button in ipairs(getStanceButtons()) do
        if button then
            button:SetAlpha(alpha)
            button:Show()
        end
    end
end

local function hookStanceButtons()
    for _, stanceBar in ipairs(getStanceBars()) do
        if stanceBar and not stanceBar.UITweaksHooked then
            -- Prevent stance bar reappearing when attack while on a mount refreshes action bars.
            stanceBar.UITweaksHooked = true
        end
    end
    local numButtons = NUM_STANCE_SLOTS or NUM_SHAPESHIFT_SLOTS or 10
    for i = 1, numButtons do
        local button = _G["StanceButton" .. i] or _G["ShapeshiftButton" .. i]
        if button and not button.UITweaksHooked then
            button:HookScript("OnShow", function(btn)
                if UITweaks.db and UITweaks.db.profile.hideStanceButtons then
                    btn:SetAlpha(0)
                end
            end)
            button.UITweaksHooked = true
        end
    end
end

function UITweaks:UpdateStanceButtonsVisibility()
    hookStanceButtons()
    if self.stanceBarHoverTicker then
        self.stanceBarHoverTicker:Cancel()
        self.stanceBarHoverTicker = nil
    end
    if not self.db.profile.hideStanceButtons then
        setStanceAlpha(1)
        return
    end
    setStanceAlpha(0)
    self.stanceBarHoverTicker = C_Timer.NewTicker(0.1, function()
        if not (UITweaks.db and UITweaks.db.profile.hideStanceButtons) then return end
        local hovered = false
        for _, stanceBar in ipairs(getStanceBars()) do
            if stanceBar and stanceBar:IsMouseOver() then
                hovered = true
                break
            end
        end
        if not hovered then
            for _, button in ipairs(getStanceButtons()) do
                if button and button:IsMouseOver() then
                    hovered = true
                    break
                end
            end
        end
        if hovered then
            setStanceAlpha(1)
        else
            setStanceAlpha(0)
        end
    end)
end

function UITweaks:GetTargetTooltipUnit()
    local unit
    if UnitExists("target") then unit = "target" end
    if not unit and self.db.profile.showSoftTargetTooltipOutOfCombat then
        if UnitExists("softenemy") then unit = "softenemy" end
        if not unit and UnitExists("softfriend") then unit = "softfriend" end
        if not unit and UnitExists("softinteract") then unit = "softinteract" end
    end
    return unit
end

function UITweaks:UpdateTargetTooltip(forceHide)
    if GameTooltip and self.db.profile.replaceTargetFrameWithTooltip then
        if forceHide then
            GameTooltip:Hide()
            return
        end
        local unit = self:GetTargetTooltipUnit()
        local targetFrameShown = _G.TargetFrame and _G.TargetFrame.IsShown and _G.TargetFrame:IsShown()
        if unit and not targetFrameShown then
            GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
            GameTooltip:SetUnit(unit)
        elseif forceHide or not unit or targetFrameShown then
            GameTooltip:Hide()
        end
    end
end

function UITweaks:HasDelayedVisibilityFeatures()
    return self.db.profile.hideDamageMeter
        or self.db.profile.hidePlayerFrameOutOfCombat
        or self.db.profile.hideTargetFrameOutOfCombat
        or self:ShouldCollapseObjectiveTracker()
        or self.db.profile.replaceTargetFrameWithTooltip
end

function UITweaks:ApplyDelayedVisibility()
    if self.db.profile.hideDamageMeter then
        self:UpdateDamageMeterVisibility()
    end
    if self.db.profile.hidePlayerFrameOutOfCombat then self:UpdatePlayerFrameVisibility() end
    if self.db.profile.hideTargetFrameOutOfCombat then self:UpdateTargetFrameVisibility() end
    if self:ShouldCollapseObjectiveTracker() then self:ExpandTrackerIfNeeded(true) end
    if self.db.profile.replaceTargetFrameWithTooltip then self:UpdateTargetTooltip() end
end

function UITweaks:ScheduleDelayedVisibilityUpdate(skipDelay)
    if self.visibilityTimer then
        self.visibilityTimer:Cancel()
        self.visibilityTimer = nil
    end
    self.visibilityDelayActive = false
    if self:HasDelayedVisibilityFeatures() then
        local delay = tonumber(self.db.profile.combatVisibilityDelaySeconds)
        if not delay or delay < 0 then delay = defaultsProfile.combatVisibilityDelaySeconds end
        if skipDelay and not (InCombatLockdown and InCombatLockdown()) then
            self:ApplyDelayedVisibility()
        elseif delay <= 0 then
            self:ApplyDelayedVisibility()
        else
            self.visibilityDelayActive = true
            self:UpdatePlayerFrameVisibility()
            self:UpdateTargetFrameVisibility()
            self.visibilityTimer = C_Timer.NewTimer(delay, function()
                if not InCombatLockdown or not InCombatLockdown() then
                    self.visibilityDelayActive = false
                    self:ApplyDelayedVisibility()
                end
            end)
        end
    end
end

function UITweaks:OpenOptionsPanel()
    if InterfaceOptionsFrame_OpenToCategory and self.optionsFrame then
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    elseif AceConfigDialog then
        AceConfigDialog:Open(addonName)
        if AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[addonName] then
            self:EnsureReloadButtonForFrame(AceConfigDialog.OpenFrames[addonName])
        end
    end
end

function UITweaks:EnsureReloadButtonForFrame(parent)
    if type(parent) == "table" then
        if parent.frame and parent.frame.GetObjectType then
            parent = parent.frame
        elseif parent.content and parent.content.GetObjectType then
            parent = parent.content
        end
    end

    if not (parent and parent.GetObjectType and parent:IsObjectType("Frame")) then
        return
    end
    if not parent or not CreateFrame then return end

    self.reloadButtons = self.reloadButtons or {}
    if self.reloadButtons[parent] then return self.reloadButtons[parent] end

    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetText("Reload")
    button:SetSize(120, 22)
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, -16)
    button:SetScript("OnClick", function() ReloadUI() end)
    button:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText("Reload the interface to immediately apply changes.")
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    button:Hide()

    self.reloadButtons[parent] = button
    parent:HookScript("OnShow", function() button:Show() end)
    parent:HookScript("OnHide", function() button:Hide() end)
    if parent:IsShown() then
        button:Show()
    end

    return button
end

function UITweaks:EnsureReloadButton()
    local parent = InterfaceOptionsFramePanelContainer or InterfaceOptionsFrame or self.optionsFrame
    local button = self:EnsureReloadButtonForFrame(parent)
    if not (button and self.optionsFrame) then return end

    self.optionsFrame:HookScript("OnShow", function() button:Show() end)
    self.optionsFrame:HookScript("OnHide", function() button:Hide() end)
    if self.optionsFrame:IsShown() then
        button:Show()
    else
        button:Hide()
    end
end

function UITweaks:EnsureBottomLeftReloadButton()
    if self.bottomLeftReloadButton then
        return self.bottomLeftReloadButton
    end
    if not CreateFrame then return end

    local button = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
    button:SetText("Reload")
    button:SetSize(120, 22)
    button:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -16)
    button:SetScript("OnClick", function() ReloadUI() end)
    button:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText("Reload the interface to immediately apply changes.")
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    button:Hide()

    self.bottomLeftReloadButton = button
    return button
end

function UITweaks:UpdateBottomLeftReloadButton()
    local button = self:EnsureBottomLeftReloadButton()
    if not button then return end
    if self.db.profile.showReloadButtonBottomLeft then
        button:Show()
    else
        button:Hide()
    end
end

function UITweaks:GetConsolePortBarEnv()
    local relaTable = LibStub("RelaTable", true)
    if not relaTable then return end
    return relaTable("ConsolePort_Bar")
end

local function shallowCopyTable(src)
    if type(src) ~= "table" then return end
    local out = {}
    for key, value in pairs(src) do
        out[key] = value
    end
    return out
end

function UITweaks:IsConsolePortPresetEmpty(preset)
    return type(preset) ~= "table" or next(preset) == nil
end

function UITweaks:EnsureConsolePortBarLoaded()
    local loadAddOn = C_AddOns and C_AddOns.LoadAddOn or UIParentLoadAddOn
    if loadAddOn then
        local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort_Bar"))
            or (IsAddOnLoaded and IsAddOnLoaded("ConsolePort_Bar"))
        if not isLoaded then
            loadAddOn("ConsolePort_Bar")
        end
    end
    return (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort_Bar"))
        or (IsAddOnLoaded and IsAddOnLoaded("ConsolePort_Bar"))
end

function UITweaks:GetConsolePortPreset(name)
    if not self.consolePortPresetCache then
        self:CacheConsolePortPresets()
    end
    if self.consolePortPresetCache and self.consolePortPresetCache[name] then
        return self.consolePortPresetCache[name]
    end
    local env = self:GetConsolePortBarEnv()
    if not env then return end
    local preset = env("Presets/" .. name)
    if type(preset) ~= "table" then return end
    if not self.consolePortPresetCache then
        self.consolePortPresetCache = {}
    end
    self.consolePortPresetCache[name] = preset
    return preset
end

function UITweaks:CacheConsolePortPresets()
    local env = self:GetConsolePortBarEnv()
    if not env then return end
    local presets = env("Presets")
    if type(presets) ~= "table" then return end
    self.consolePortPresetCache = shallowCopyTable(presets) or {}
end

function UITweaks:RefreshConsolePortPresetCache()
    self.consolePortPresetCache = nil
    self:CacheConsolePortPresets()
end

function UITweaks:HasConsolePortPreset(name)
    local preset = self:GetConsolePortPreset(name)
    if self:IsConsolePortPresetEmpty(preset) then return false end
    return true
end

function UITweaks:GetConsolePortActionBarLoadout(allowOpen)
    if self.consolePortActionBarLoadout then
        local loadout = self.consolePortActionBarLoadout
        if loadout and (loadout.OnSave or loadout.OnLoadPreset) then
            return loadout
        end
    end
    local configFrame = _G.ConsolePortActionBarConfig
    if not configFrame then
        if not allowOpen then
            return
        end
        self:OpenConsolePortActionBarConfig(false)
        configFrame = _G.ConsolePortActionBarConfig
    end
    local loadout = configFrame
        and configFrame.SettingsContainer
        and configFrame.SettingsContainer.ScrollChild
        and configFrame.SettingsContainer.ScrollChild.Loadout
    if loadout and (loadout.OnSave or loadout.OnLoadPreset) then
        self.consolePortActionBarLoadout = loadout
    end
    return loadout
end

function UITweaks:SaveConsolePortActionBarProfileAs(name, desc)
    local loadout = self:GetConsolePortActionBarLoadout(true)
    if not (loadout and loadout.OnSave) then
        return
    end
    loadout:OnSave({
        name = name,
        desc = desc,
    }, true, true)
    self:RefreshConsolePortPresetCache()
end

function UITweaks:SaveConsolePortActionBarProfile()
    self:SaveConsolePortActionBarProfileAs("UITweaksProfile", "Saved by UI Tweaks")
end

function UITweaks:RestoreConsolePortActionBarProfileFrom(name)
    local preset = self:GetConsolePortPreset(name)
    if self:IsConsolePortPresetEmpty(preset) then return false end
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    if not self:GetConsolePortActionBarLoadout(true) then
        return false
    end
    local loadout = self.consolePortActionBarLoadout
    if loadout and loadout.OnLoadPreset then
        loadout:OnLoadPreset(preset)
    end
    return true
end

function UITweaks:RestoreConsolePortActionBarProfile()
    return self:RestoreConsolePortActionBarProfileFrom("UITweaksProfile")
end

function UITweaks:OpenConsolePortActionBarConfig(show)
    if not self:EnsureConsolePortBarLoaded() then
        return
    end
    local relaTable = LibStub("RelaTable", true)
    if not relaTable then return end
    local env = relaTable("ConsolePort_Bar")
    if not env or not env.TriggerEvent then return end
    env:TriggerEvent("OnConfigToggle")
    env:TriggerEvent("OnConfigToggle", true)

    local configFrame = _G.ConsolePortActionBarConfig
    if not configFrame and _G.ConsolePort then
        local cp = _G.ConsolePort
        if cp.ToggleConfig then
            cp:ToggleConfig()
        elseif cp.ToggleConfigFrame then
            cp:ToggleConfigFrame()
        end
        configFrame = _G.ConsolePortActionBarConfig
    end

    if configFrame then
        if show ~= false then
            configFrame:Show()
        end
        return
    end

end

function UITweaks:SaveSkyridingBarLayout()
    local layout = {}
    for index = 1, SKYRIDING_BAR_SLOT_COUNT do
        local slot = SKYRIDING_BAR_SLOT_START + index - 1
        local actionType, actionID, subType = GetActionInfo(slot)
        if actionType then
            layout[index] = {
                type = actionType,
                id = actionID,
                subType = subType,
            }
        else
            layout[index] = false
        end
    end
    if not next(layout) then return end
    local hasAny = false
    for _, entry in pairs(layout) do
        if entry then
            hasAny = true
            break
        end
    end
    if not hasAny then return end
    self.db.global.skyridingBarLayout = layout
end

local function clearActionSlot(slot)
    if ClearAction then
        ClearAction(slot)
        return
    end
    if PickupAction and ClearCursor then
        PickupAction(slot)
        ClearCursor()
    end
end

local function placeActionIntoSlot(slot, entry)
    if not entry or entry == false then return end
    local actionType = entry.type
    local actionID = entry.id
    if not actionType or not actionID then return false end

    if actionType == "spell" then
        if C_Spell and C_Spell.PickupSpell then
            C_Spell.PickupSpell(actionID)
        end
    elseif actionType == "item" and PickupItem then
        PickupItem(actionID)
    elseif actionType == "macro" and PickupMacro then
        PickupMacro(actionID)
    elseif actionType == "equipmentset" and C_EquipmentSet and C_EquipmentSet.PickupEquipmentSet then
        C_EquipmentSet.PickupEquipmentSet(actionID)
    else
        return
    end

    if PlaceAction then
        PlaceAction(slot)
    end
    if ClearCursor then
        ClearCursor()
    end

    local placedType, placedID = GetActionInfo(slot)
    return placedType == actionType and placedID == actionID
end

local function isSavedActionAvailable(entry)
    if not entry or entry == false then return false end
    local actionType = entry.type
    local actionID = entry.id
    if not actionType or not actionID then return false end

    if actionType == "spell" then
        if (IsSpellKnown and IsSpellKnown(actionID)) or (IsPlayerSpell and IsPlayerSpell(actionID)) then
            return true
        end
        if IsUsableSpell and IsUsableSpell(actionID) then
            return true
        end
        if C_Spell and C_Spell.IsSpellUsable and C_Spell.IsSpellUsable(actionID) then
            return true
        end
        return false
    elseif actionType == "item" then
        if C_Item and C_Item.DoesItemExist then
            return C_Item.DoesItemExist(actionID)
        end
        return GetItemInfo and GetItemInfo(actionID) ~= nil
    elseif actionType == "macro" and GetMacroInfo then
        return GetMacroInfo(actionID) ~= nil
    elseif actionType == "equipmentset" and C_EquipmentSet and C_EquipmentSet.GetEquipmentSetInfo then
        return C_EquipmentSet.GetEquipmentSetInfo(actionID) ~= nil
    end

    return false
end

function UITweaks:RestoreSkyridingBarLayout()
    local layout = self.db.global.skyridingBarLayout
    if not layout or not next(layout) then return end
    for index = 1, SKYRIDING_BAR_SLOT_COUNT do
        local slot = SKYRIDING_BAR_SLOT_START + index - 1
        local entry = layout[index]
        if entry and entry ~= false and isSavedActionAvailable(entry) then
            clearActionSlot(slot)
            placeActionIntoSlot(slot, entry)
        end
    end
end

function UITweaks:OpenCooldownViewerSettings()
    local loadAddOn = C_AddOns and C_AddOns.LoadAddOn or UIParentLoadAddOn
    if loadAddOn then
        local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_CooldownViewer"))
            or (IsAddOnLoaded and IsAddOnLoaded("Blizzard_CooldownViewer"))
        if not isLoaded then
            loadAddOn("Blizzard_CooldownViewer")
        end
    end
    local settingsFrame = _G.CooldownViewerSettings
    if settingsFrame and settingsFrame.Show then
        settingsFrame:Show()
        self:EnsureCooldownViewerSettingsHooked()
        self:QueueCooldownViewerSettingsMove()
    end
end

local function getFrameText(frame)
    if not frame then return nil end
    if frame.GetText then return frame:GetText() end
    local textRegion = frame.Text or frame.Label or frame.Title
    if textRegion and textRegion.GetText then
        return textRegion:GetText()
    end
    return nil
end

local function traverseFrames(root, visitor)
    if not root or not root.GetChildren then return end
    local children = { root:GetChildren() }
    for _, child in ipairs(children) do
        if visitor(child) then return true end
        if traverseFrames(child, visitor) then return true end
    end
    return false
end

function UITweaks:FindCooldownViewerPanelByTitle(root, title)
    local match = nil
    traverseFrames(root, function(frame)
        local text = getFrameText(frame)
        if text == title then
            match = frame:GetParent()
            return true
        end
        return false
    end)
    return match
end

function UITweaks:ClickCooldownViewerButtonsByLabel(root, labels)
    local clicked = 0
    traverseFrames(root, function(frame)
        if clicked > 200 then return true end
        if frame.GetObjectType and frame:GetObjectType() == "Button" and frame.Click then
            local text = getFrameText(frame)
            if text and labels[text] then
                if frame.IsEnabled and not frame:IsEnabled() then
                    return false
                end
                frame:Click()
                clicked = clicked + 1
            end
        end
        return false
    end)
    return clicked
end

function UITweaks:SelectCooldownViewerBuffsTab()
    local settingsFrame = _G.CooldownViewerSettings
    if not settingsFrame then return end
    local tab = settingsFrame.AurasTab
    if not settingsFrame.SetDisplayMode then return end
    settingsFrame:SetDisplayMode((tab and tab.displayMode) or "auras")
    if settingsFrame.UpdateTabs then settingsFrame:UpdateTabs() end
end

function UITweaks:MoveCooldownViewerNotDisplayedToTracked()
    local settingsFrame = _G.CooldownViewerSettings
    if not settingsFrame then return end

    self:SelectCooldownViewerBuffsTab()

    local notDisplayedPanel = self:FindCooldownViewerPanelByTitle(settingsFrame, "Not Displayed")
    if not notDisplayedPanel then return end

    local clicked = self:ClickCooldownViewerButtonsByLabel(notDisplayedPanel, {
        ["Track"] = true,
        ["Add"] = true,
        ["Move"] = true,
        ["Display"] = true,
        ["Track All"] = true,
        ["Add All"] = true,
    })
    if clicked > 0 then
        self.cooldownViewerNotDisplayedMoved = true
    end
end

function UITweaks:QueueCooldownViewerSettingsMove()
    if self.cooldownViewerNotDisplayedMoved then return end
    C_Timer.After(0, function()
        self:SelectCooldownViewerBuffsTab()
        self:MoveCooldownViewerNotDisplayedToTracked()
    end)
end

function UITweaks:EnsureCooldownViewerSettingsHooked()
    if self.cooldownViewerSettingsHooked then return end
    local settingsFrame = _G.CooldownViewerSettings
    if not settingsFrame or not settingsFrame.HookScript then return end
    settingsFrame:HookScript("OnShow", function()
        self:SelectCooldownViewerBuffsTab()
        self:QueueCooldownViewerSettingsMove()
    end)
    settingsFrame:HookScript("OnHide", function()
        self.cooldownViewerSettingsOpened = false
    end)
    self.cooldownViewerSettingsHooked = true
end

function UITweaks:ApplyVisibilityState()
    self:UpdatePlayerFrameVisibility()
    self:UpdateTargetFrameVisibility()
    self:UpdateDamageMeterVisibility()
    self:UpdateTargetTooltip()
    self:UpdateChatTabsVisibility()
    self:UpdateChatMenuButtonVisibility()
    self:UpdateGroupLootHistoryVisibility()
    self:UpdateMicroMenuVisibility()
    self:UpdateStanceButtonsVisibility()
    self:UpdateBackpackButtonVisibility()
end

function UITweaks:EnsureHelpTipHooks()
    if HelpTip and not self.helpTipShowHooked then
        hooksecurefunc(HelpTip, "Show", function(_, owner, info)
            if not (UITweaks.db and UITweaks.db.profile and UITweaks.db.profile.hideHelpTips) then return end
            if HelpTip.HideAllSystem then HelpTip:HideAllSystem() end
            if HelpTip.HideAll then HelpTip:HideAll(owner or UIParent) end
            if HelpTip.Hide and info and info.text then
                HelpTip:Hide(owner, info.text)
            end
        end)
        self.helpTipShowHooked = true
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
                            self:ApplyActionButtonAuraTimers()
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
                        "Show buffs and debuffs timers on action buttons and highlight action buttons with resolved buff durations when available. Requires Blizzard Cooldown Manager: Options -> Gameplay Enhancements -> Enable Cooldown Manager. In Cooldown Manager, move abilities from 'Not Displayed' to 'Tracked Buffs' or 'Tracked Bars'. Cooldown Viewer auras work in and out of combat. Manual highlights from player buffs (items/spells) only reapply out of combat.",
                        4,
                        function()
                            self:ApplyActionButtonAuraTimers()
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
                    consolePortBarSharing = toggleOption(
                        "consolePortBarSharing",
                        "Share ConsolePort Action Bar Settings For All Characters",
                        "Warning: This will overwrite your ConsolePort UI settings. When enabled, UI Tweaks saves your current ConsolePort action bar layout in ConsolePort's own presets as \"UITweaksProfile\" every time you log out, then restores that same preset automatically the next time you log in on any character. This keeps your ConsolePort action bar layout, optional bar settings, and action page logic consistent across characters without any manual export/import.",
                        1,
                        function()
                            return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("ConsolePort"))
                                and not (IsAddOnLoaded and IsAddOnLoaded("ConsolePort"))
                        end
                    ),
                    openConsolePortDesigner = {
                        type = "execute",
                        name = "Open ConsolePort Designer",
                        desc = "Open the ConsolePort action bar configuration window.",
                        order = 2,
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

function UITweaks:IsSkyridingBarActive()
    if IsMounted and IsMounted() then
        return true
    end
    return false
end

function UITweaks:StartSkyridingBarMonitor()
    if self.skyridingBarTicker then return end
    self.skyridingBarTicker = C_Timer.NewTicker(0.5, function()
        self:UpdateSkyridingBarSaveState()
    end)
end

function UITweaks:StopSkyridingBarMonitor()
    if self.skyridingBarTicker then
        self.skyridingBarTicker:Cancel()
        self.skyridingBarTicker = nil
    end
end

function UITweaks:OnEnable()
    self:CacheDefaultChatWindowTimes()
    self:ApplyChatLineFade()
    self:ApplyChatFontSize()
    self:ApplyChatBackgroundAlpha()
    self:HookHelpTipFrames()
    self:ApplyBuffFrameHide()
    if self.db.profile.showActionButtonAuraTimers then
        self:ApplyActionButtonAuraTimers()
    end
    self:UpdateBottomLeftReloadButton()
    self:ApplyVisibilityState()
    self:UpdateObjectiveTrackerState()
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_LOGOUT")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("LOOT_OPENED")
    self:RegisterEvent("LOOT_CLOSED")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("PLAYER_SOFT_ENEMY_CHANGED")
    self:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED")
    if self.db.profile.showOptionsOnReload then
        C_Timer.After(1, function() self:OpenOptionsPanel() end)
    end
end

function UITweaks:ADDON_LOADED(event, addonName)
    if addonName == "Blizzard_HelpTip" then
        self:HookHelpTipFrames()
    elseif addonName == "Blizzard_CooldownViewer" then
        self:EnsureCooldownViewerSettingsHooked()
    elseif addonName == "Blizzard_BuffFrame" then
        self:ApplyBuffFrameHide()
        if self.db.profile.showActionButtonAuraTimers then
            self:ApplyActionButtonAuraTimers()
        end
        self:ApplyVisibilityState()
        self:ScheduleDelayedVisibilityUpdate(true)
    elseif addonName == "Blizzard_GroupLootHistory" then
        self:UpdateGroupLootHistoryVisibility()
    elseif addonName == "Blizzard_ActionBarController" or addonName == "Blizzard_ActionBar" then
        self:UpdateStanceButtonsVisibility()
        if self.db.profile.showActionButtonAuraTimers then
            self:InitializeActionButtonAuraTimers()
        end
        self:RequestActionButtonAuraRefresh(true)
    elseif addonName == "Blizzard_ObjectiveTracker" then
        self:UpdateObjectiveTrackerState()
    elseif addonName == "ConsolePort"
        or addonName == "ConsolePort_ActionBar"
        or addonName == "ConsolePortActionBar"
        or addonName == "ConsolePortGroupCrossbar"
        or addonName == "ConsolePort_GroupCrossbar"
    then
        if addonName == "ConsolePort" then
            self:RegisterConsolePortActionPageCallback()
        end
        if self.db.profile.showActionButtonAuraTimers then
            self:InitializeActionButtonAuraTimers()
        end
        self:RequestActionButtonAuraRefresh(true)
    end
end

function UITweaks:PLAYER_REGEN_DISABLED()
    if self:ShouldCollapseObjectiveTracker() then
        self:CollapseTrackerIfNeeded()
    end
    self:UpdatePlayerFrameVisibility()
    self:UpdateTargetFrameVisibility()
    self:UpdateDamageMeterVisibility()
    if self.db.profile.replaceTargetFrameWithTooltip then GameTooltip:Hide() end
    if self.visibilityTimer then
        self.visibilityTimer:Cancel()
        self.visibilityTimer = nil
    end
    self.visibilityDelayActive = false
end

function UITweaks:PLAYER_REGEN_ENABLED()
    self:ScheduleDelayedVisibilityUpdate()
end

function UITweaks:PLAYER_ENTERING_WORLD()
    self:ApplyBuffFrameHide()
    self:ApplyVisibilityState()
    self:ScheduleDelayedVisibilityUpdate(true)
    if self.db.profile.consolePortBarSharing then
        self:RestoreConsolePortActionBarProfile()
    end
    self.skyridingBarActive = self:IsSkyridingBarActive()
    if self.db.profile.skyridingBarSharing then
        C_Timer.After(2, function() self:RestoreSkyridingBarLayout() end)
        self:StartSkyridingBarMonitor()
    end
    if self.db.profile.showActionButtonAuraTimers then
        C_Timer.After(0.3, function() self:ReapplyManualHighlightsFromPlayerAuras() end)
    end
end

function UITweaks:PLAYER_LOGOUT()
    if self.db.profile.consolePortBarSharing then
        self:SaveConsolePortActionBarProfile()
    end
end

function UITweaks:UpdateSkyridingBarSaveState()
    local wasActive = self.skyridingBarActive
    local isActive = self:IsSkyridingBarActive()
    self.skyridingBarActive = isActive
    if wasActive and not isActive and self.db.profile.skyridingBarSharing then
        self:SaveSkyridingBarLayout()
    end
end

function UITweaks:PLAYER_TARGET_CHANGED()
    self:UpdateTargetTooltip()
    self:UpdateTargetFrameVisibility()
    if self.db and self.db.profile and self.db.profile.showActionButtonAuraTimers then
        self:RequestActionButtonAuraRefresh()
    end
end

function UITweaks:PLAYER_SOFT_ENEMY_CHANGED()
    self:UpdateTargetTooltip()
end

function UITweaks:PLAYER_SOFT_INTERACT_CHANGED()
    self:UpdateTargetTooltip()
end

function UITweaks:LOOT_OPENED()
    self:UpdateTargetTooltip(true)
end

function UITweaks:LOOT_CLOSED()
    self:UpdateTargetTooltip()
end
