local UITweaks = LibStub("AceAddon-3.0"):GetAddon("UITweaks")

local function isActionButtonFrame(frame)
    if not frame or type(frame) ~= "table" then return false end
    if not frame.GetObjectType then return false end
    local objType = frame:GetObjectType()
    if objType ~= "CheckButton" and objType ~= "Button" then return false end
    if not frame.GetAttribute then return false end
    local action = frame.action or frame:GetAttribute("action")
    return type(action) == "number"
end

local function getActionSpellID(button)
    if not button then return nil end
    if button.GetAttribute then
        local actionField = button:GetAttribute("action_field")
        if actionField then
            local actionValue = button:GetAttribute(actionField)
            if actionField == "action" and actionValue then
                local actionType, actionID = GetActionInfo(actionValue)
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

function UITweaks:BuildActionButtonCache()
    local buttons = {}
    local seen = {}
    local function addButton(btn)
        if not btn or seen[btn] then return end
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
        if isActionButtonFrame(frame) and getActionSpellID(frame) then
            addButton(frame)
        end
        frame = EnumerateFrames(frame)
    end

    self.actionButtonsCache = buttons
end

function UITweaks:HookActionButtonUpdateAction(button)
    if not button or button.__UITweaksActionHooked then return end
    if type(button.UpdateAction) ~= "function" then return end
    hooksecurefunc(button, "UpdateAction", function()
        if self.db and self.db.profile and self.db.profile.showActionButtonAuraTimers then
            self:RequestActionButtonAuraRefresh()
        end
    end)
    button.__UITweaksActionHooked = true
end

function UITweaks:FindActionButtonsForSpellName(name)
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

function UITweaks:GetActionButtonList(spellID)
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

    function overlay:SetViewerItem(item)
        self.viewerItem = item
    end

    function overlay:Update()
        if not self.viewerItem then
            if self.Glow then self.Glow:Hide() end
            self:Hide()
            return
        end

        local unit = self.viewerItem.auraDataUnit
        local auraInstanceID = self.viewerItem.auraInstanceID
        if unit and auraInstanceID then
            local duration = C_UnitAuras.GetAuraDuration(unit, auraInstanceID)
            if duration then
                self.Cooldown:SetCooldownFromDurationObject(duration, true)
                self.Cooldown:Show()
            else
                self.Cooldown:Hide()
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

    overlay:Hide()
    return overlay
end

function UITweaks:ReportCooldownViewerMissing()
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

function UITweaks:IsCooldownViewerVisible(viewer)
    if not viewer or not viewer.GetAlpha then return false end
    local alpha = viewer:GetAlpha()
    if alpha and alpha <= 0 then return false end
    if viewer.IsShown then
        return viewer:IsShown()
    end
    return true
end

function UITweaks:GetActionButtonAuraOverlay(actionButton)
    if not self.actionButtonAuraOverlays[actionButton] then
        self.actionButtonAuraOverlays[actionButton] = createActionButtonAuraOverlay(actionButton)
    end
    return self.actionButtonAuraOverlays[actionButton]
end

function UITweaks:UpdateActionButtonAuraFromItem(item)
    if not self.db.profile.showActionButtonAuraTimers then return end
    if not item.cooldownID then return end
    if not C_CooldownViewer or not C_CooldownViewer.GetCooldownViewerCooldownInfo then
        self:ReportCooldownViewerMissing()
        return
    end

    local cdInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(item.cooldownID)
    if cdInfo and cdInfo.spellID then
        local buttonList = self:GetActionButtonList(cdInfo.spellID)
        for _, button in ipairs(buttonList) do
            local overlay = self:GetActionButtonAuraOverlay(button)
            overlay:SetViewerItem(item)
            overlay:Update()
        end
    end
end

function UITweaks:UpdateActionButtonAurasFromViewer(viewer)
    if not viewer or not viewer.GetItemFrames then return end
    for _, itemFrame in ipairs(viewer:GetItemFrames()) do
        if itemFrame.cooldownID then
            self:UpdateActionButtonAuraFromItem(itemFrame)
        end
    end
end

function UITweaks:HookActionButtonAuraViewerItem(item)
    if not item.__UITweaksAuraHooked then
        local hook = function() self:UpdateActionButtonAuraFromItem(item) end
        hooksecurefunc(item, "RefreshData", hook)
        item.__UITweaksAuraHooked = true
    end
end

function UITweaks:RefreshActionButtonAuraOverlays(rebuildCache)
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
    for _, overlay in pairs(self.actionButtonAuraOverlays) do
        overlay:Update()
    end
end

function UITweaks:RequestActionButtonAuraRefresh(rebuildCache)
    if rebuildCache then
        self.actionButtonsCacheDirty = true
    end
    if self.pendingAuraRefresh then return end
    self.pendingAuraRefresh = true

    local function run()
        self.pendingAuraRefresh = false
        self:RefreshActionButtonAuraOverlays(self.actionButtonsCacheDirty)
        self.actionButtonsCacheDirty = nil
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, run)
    else
        run()
    end
end

function UITweaks:ClearActionButtonAuraOverlays()
    if not self.actionButtonAuraOverlays then return end
    for _, overlay in pairs(self.actionButtonAuraOverlays) do
        overlay:SetViewerItem(nil)
        overlay:Update()
    end
end

function UITweaks:InitializeActionButtonAuraTimers()
    if self.actionButtonAuraTimersInitialized then return end
    if not C_UnitAuras or not C_UnitAuras.GetAuraDuration then return end
    if not BuffBarCooldownViewer or not BuffIconCooldownViewer then
        if UIParentLoadAddOn then
            UIParentLoadAddOn("Blizzard_BuffFrame")
        end
    end
    if not BuffBarCooldownViewer or not BuffIconCooldownViewer then
        self:ReportCooldownViewerMissing()
        return
    end
    local buffBarVisible = self:IsCooldownViewerVisible(BuffBarCooldownViewer)
    local buffIconVisible = self:IsCooldownViewerVisible(BuffIconCooldownViewer)
    if not buffBarVisible and not buffIconVisible then
        self:ReportCooldownViewerMissing()
        return
    end
    self.actionButtonAuraTimersInitialized = true
    self.actionButtonAuraOverlays = self.actionButtonAuraOverlays or {}
    self.actionButtonsCache = nil

    local hook = function(_, item) self:HookActionButtonAuraViewerItem(item) end
    hooksecurefunc(BuffBarCooldownViewer, "OnAcquireItemFrame", hook)
    hooksecurefunc(BuffIconCooldownViewer, "OnAcquireItemFrame", hook)

    self:BuildActionButtonCache()
    self:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    self:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
    self:RegisterEvent("MODIFIER_STATE_CHANGED")
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterConsolePortActionPageCallback()
end

function UITweaks:RegisterConsolePortActionPageCallback()
    if self.consolePortActionPageCallbackRegistered then return end
    local consolePort = _G.ConsolePort
    if not consolePort or not consolePort.GetData then return end
    local data = consolePort:GetData()
    if not data or not data.RegisterCallback then return end
    data:RegisterCallback("OnActionPageChanged", self.ConsolePortActionPageChanged, self)
    self.consolePortActionPageCallbackRegistered = true
end

function UITweaks:ConsolePortActionPageChanged()
    if self.db.profile.showActionButtonAuraTimers then
        self:RequestActionButtonAuraRefresh(true)
    end
end

function UITweaks:ApplyCooldownViewerAlpha()
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

function UITweaks:ApplyActionButtonAuraTimers()
    if self.db.profile.showActionButtonAuraTimers then
        self:InitializeActionButtonAuraTimers()
        self:RefreshActionButtonAuraOverlays()
    else
        self:ClearActionButtonAuraOverlays()
    end
    self:ApplyCooldownViewerAlpha()
end

function UITweaks:ACTIONBAR_SLOT_CHANGED()
    if self.db.profile.showActionButtonAuraTimers then
        self:RequestActionButtonAuraRefresh()
    end
end

function UITweaks:ACTIONBAR_PAGE_CHANGED()
    if self.db.profile.showActionButtonAuraTimers then
        self:RequestActionButtonAuraRefresh(true)
    end
end

function UITweaks:MODIFIER_STATE_CHANGED()
    if self.db.profile.showActionButtonAuraTimers then
        self:RequestActionButtonAuraRefresh(true)
    end
end

function UITweaks:ADDON_LOADED(addonName)
    if addonName == "ConsolePort" then
        self:RegisterConsolePortActionPageCallback()
    end
end
