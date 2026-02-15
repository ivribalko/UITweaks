local _, addonTable = ...
local Auras = {}

if addonTable then
    addonTable.Auras = Auras
end

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
    -- prevent highlighting ConsolePort targeting R2/L2 buttons
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

function Auras:BuildActionButtonCache()
    local buttons = {}
    local seen = {}
    local function addButton(btn)
        if not btn or seen[btn] then return end
        if isCustomBindingButton(btn) then return end
        seen[btn] = true
        table.insert(buttons, btn)
        Auras.HookActionButtonUpdateAction(self, btn)
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

function Auras:HookActionButtonUpdateAction(button)
    if not button or hookedActionButtons[button] then return end
    if type(button.UpdateAction) ~= "function" then return end
    hooksecurefunc(button, "UpdateAction", function()
        Auras.RequestActionButtonAuraRefresh(self)
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

function Auras:ResolveActionButtonInfo(button)
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

function Auras:ReapplyManualHighlightsFromPlayerAuras()
    if not self.db or not self.db.profile or not self.db.profile.showActionButtonAuraTimers then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if not self.actionButtonsCache or self.actionButtonsCacheDirty then
        self.actionButtonsCacheDirty = nil
        Auras.BuildActionButtonCache(self)
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
        local overlay = Auras.GetActionButtonAuraOverlay(self, button)
        if not overlay.viewerAuraUnit or not overlay.viewerAuraInstanceID then
            local spellID, spellName = Auras.ResolveActionButtonInfo(self, button)
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

function Auras:ScheduleReapplyManualHighlightsFromPlayerAuras()
    if self.pendingReapplyPlayerAuras then return end
    self.pendingReapplyPlayerAuras = true
    local function run()
        self.pendingReapplyPlayerAuras = false
        Auras.ReapplyManualHighlightsFromPlayerAuras(self)
    end
    C_Timer.After(0.05, run)
end

function Auras:FindActionButtonsForSpellName(name)
    if not self.actionButtonsCache then
        Auras.BuildActionButtonCache(self)
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

function Auras:GetActionButtonList(spellID)
    local buttonList = {}
    local seen = {}
    local spellName = C_Spell.GetSpellName(spellID)
    if not spellName then return buttonList end
    local buttons = Auras.FindActionButtonsForSpellName(self, spellName)
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
            self.manualStart = nil
            self.manualDuration = nil
            return
        end
        self.viewerAuraUnit = nil
        self.viewerAuraInstanceID = nil
        self.viewerSpellID = nil
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
                self.Stacks:SetText("")
                self.Stacks:Hide()
                self.Cooldown:Hide()
                self.Glow:Hide()
                self:Hide()
                return
            end
            local duration = C_UnitAuras.GetAuraDuration(unit, auraInstanceID)
            if duration then
                self.Cooldown:SetCooldownFromDurationObject(duration, true)
                self.Cooldown:Show()
            else
                self.viewerAuraUnit = nil
                self.viewerAuraInstanceID = nil
                self.viewerSpellID = nil
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
        self.manualStart = GetTime()
        self.manualDuration = durationSeconds
        self:Update()
    end

    function overlay:SetManualCooldownFromStart(startTime, durationSeconds)
        if not startTime or not durationSeconds or durationSeconds <= 0 then return end
        self.viewerAuraUnit = nil
        self.viewerAuraInstanceID = nil
        self.viewerSpellID = nil
        self.manualStart = startTime
        self.manualDuration = durationSeconds
        self:Update()
    end

    overlay:Hide()
    return overlay
end

function Auras:ReportCooldownViewerMissing()
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

function Auras:IsCooldownViewerVisible(viewer)
    if not viewer or not viewer.GetAlpha then return false end
    local alpha = viewer:GetAlpha()
    if alpha and alpha <= 0 then return false end
    if viewer.IsShown then
        return viewer:IsShown()
    end
    return true
end

function Auras:GetActionButtonAuraOverlay(actionButton)
    if not self.actionButtonAuraOverlays then
        self.actionButtonAuraOverlays = {}
    end
    if not self.actionButtonAuraOverlays[actionButton] then
        self.actionButtonAuraOverlays[actionButton] = createActionButtonAuraOverlay(actionButton)
    end
    return self.actionButtonAuraOverlays[actionButton]
end

function Auras:UpdateActionButtonAuraFromItem(item)
    if not self.db.profile.showActionButtonAuraTimers then return end
    if not item.cooldownID then return end
    if not item.auraDataUnit or not item.auraInstanceID then return end
    if not C_CooldownViewer or not C_CooldownViewer.GetCooldownViewerCooldownInfo then
        Auras.ReportCooldownViewerMissing(self)
        return
    end

    local cdInfo = C_CooldownViewer.GetCooldownViewerCooldownInfo(item.cooldownID)
    if cdInfo and cdInfo.spellID then
        local buttonList = Auras.GetActionButtonList(self, cdInfo.spellID)
        for _, button in ipairs(buttonList) do
            local overlay = Auras.GetActionButtonAuraOverlay(self, button)
            overlay:SetViewerItem(item, cdInfo.spellID)
            overlay:Update()
        end
    end
end

function Auras:UpdateActionButtonAurasFromViewer(viewer)
    if not viewer or not viewer.GetItemFrames then return end
    for _, itemFrame in ipairs(viewer:GetItemFrames()) do
        if itemFrame.cooldownID then
            Auras.UpdateActionButtonAuraFromItem(self, itemFrame)
        end
    end
end

function Auras:HookActionButtonAuraViewer(viewer)
    if not viewer or hookedAuraViewers[viewer] then return end
    local hook = function(_, item) Auras.HookActionButtonAuraViewerItem(self, item) end
    hooksecurefunc(viewer, "OnAcquireItemFrame", hook)
    hookedAuraViewers[viewer] = true
end

function Auras:HookActionButtonAuraViewerItem(item)
    if not item or hookedAuraItems[item] then return end
    local hook = function() Auras.UpdateActionButtonAuraFromItem(self, item) end
    hooksecurefunc(item, "RefreshData", hook)
    hookedAuraItems[item] = true
end

function Auras:RefreshActionButtonAuraOverlays(rebuildCache)
    if not self.actionButtonAuraOverlays then return end
    if rebuildCache then
        self.actionButtonsCache = nil
        Auras.BuildActionButtonCache(self)
    end
    for _, overlay in pairs(self.actionButtonAuraOverlays) do
        overlay:SetViewerItem(nil)
    end
    Auras.UpdateActionButtonAurasFromViewer(self, BuffBarCooldownViewer)
    Auras.UpdateActionButtonAurasFromViewer(self, BuffIconCooldownViewer)
    Auras.UpdateActionButtonAurasFromViewer(self, EssentialCooldownViewer)
    Auras.UpdateActionButtonAurasFromViewer(self, UtilityCooldownViewer)
    for _, overlay in pairs(self.actionButtonAuraOverlays) do
        overlay:Update()
    end
end

function Auras:RequestActionButtonAuraRefresh(rebuildCache)
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
        Auras.RefreshActionButtonAuraOverlays(self, self.actionButtonsCacheDirty)
        self.actionButtonsCacheDirty = nil
    end

    C_Timer.After(0, run)
end

function Auras:ClearActionButtonAuraOverlays()
    if not self.actionButtonAuraOverlays then return end
    for _, overlay in pairs(self.actionButtonAuraOverlays) do
        overlay:SetViewerItem(nil)
        overlay:Update()
    end
end

function Auras:InitializeActionButtonAuraTimers()
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
        Auras.ReportCooldownViewerMissing(self)
        return
    end
    local buffBarVisible = Auras.IsCooldownViewerVisible(self, BuffBarCooldownViewer)
    local buffIconVisible = Auras.IsCooldownViewerVisible(self, BuffIconCooldownViewer)
    local essentialVisible = Auras.IsCooldownViewerVisible(self, EssentialCooldownViewer)
    local utilityVisible = Auras.IsCooldownViewerVisible(self, UtilityCooldownViewer)
    if not buffBarVisible and not buffIconVisible and not essentialVisible and not utilityVisible then
        Auras.ReportCooldownViewerMissing(self)
        return
    end
    self.actionButtonAuraTimersInitialized = true
    self.actionButtonAuraOverlays = self.actionButtonAuraOverlays or {}
    self.actionButtonsCache = nil

    Auras.HookActionButtonAuraViewer(self, BuffBarCooldownViewer)
    Auras.HookActionButtonAuraViewer(self, BuffIconCooldownViewer)
    Auras.HookActionButtonAuraViewer(self, EssentialCooldownViewer)
    Auras.HookActionButtonAuraViewer(self, UtilityCooldownViewer)

    Auras.BuildActionButtonCache(self)
    Auras.RegisterConsolePortActionPageCallback(self)
end

function Auras:RegisterConsolePortActionPageCallback()
    if self.consolePortActionPageCallbackRegistered then return end
    local consolePort = _G.ConsolePort
    if not consolePort or not consolePort.GetData then return end
    local data = consolePort:GetData()
    if not data or not data.RegisterCallback then return end
    data:RegisterCallback("OnActionPageChanged", Auras.ConsolePortActionPageChanged, self)
    self.consolePortActionPageCallbackRegistered = true
end

function Auras:ConsolePortActionPageChanged()
    Auras.RequestActionButtonAuraRefresh(self, true)
    Auras.ScheduleReapplyManualHighlightsFromPlayerAuras(self)
end

function Auras:ApplyCooldownViewerAlpha()
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

function Auras:ApplyActionButtonAuraTimers()
    if self.db.profile.showActionButtonAuraTimers then
        Auras.InitializeActionButtonAuraTimers(self)
        Auras.RefreshActionButtonAuraOverlays(self)
    else
        Auras.ClearActionButtonAuraOverlays(self)
    end
    Auras.ApplyCooldownViewerAlpha(self)
end

return Auras
