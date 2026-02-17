local addonName, addonTable = ...
local Debug = {}

if addonTable then
    addonTable.Debug = Debug
end

function Debug.OnEnable(self)
    self.blockedInterfaceActionCount = 0
    self.blockedActionEventDetails = {}
    self:UpdateBottomLeftReloadButton()
    self:UpdateBlockedActionCounterTracking()
end

function Debug.SerializeBlockedActionEventArg(value)
    local valueType = type(value)
    if valueType == "string" then
        if value == "" then
            return "<empty>"
        end
        return value
    end
    if valueType == "number" or valueType == "boolean" then
        return tostring(value)
    end
    if valueType == "nil" then
        return "nil"
    end
    return string.format("<%s>", valueType)
end

function Debug.AddBlockedActionEventDetail(self, eventName, sourceAddonName, ...)
    local timestamp = (_G["date"] and _G["date"]("%H:%M:%S")) or "unknown"
    local args = { ... }
    local serializedArgs = {}
    for index = 1, #args do
        serializedArgs[#serializedArgs + 1] = Debug.SerializeBlockedActionEventArg(args[index])
    end

    local detail = {
        timestamp = timestamp,
        eventName = tostring(eventName or "unknown"),
        sourceAddon = tostring(sourceAddonName or "unknown"),
        args = serializedArgs,
    }

    local entries = self.blockedActionEventDetails
    entries[#entries + 1] = detail
    local maxEntries = 40
    while #entries > maxEntries do
        table.remove(entries, 1)
    end
end

function Debug.GetBlockedActionEventDetailsText(self)
    local entries = self.blockedActionEventDetails or {}
    if #entries == 0 then
        return "recentBlockedEvents=none"
    end

    local lines = {
        string.format("recentBlockedEvents=%d", #entries),
    }
    for index, detail in ipairs(entries) do
        local argsText = (#detail.args > 0) and table.concat(detail.args, " | ") or "none"
        lines[#lines + 1] = string.format(
            "event[%d]=%s %s addon=%s details=%s",
            index,
            tostring(detail.timestamp),
            tostring(detail.eventName),
            tostring(detail.sourceAddon),
            argsText
        )
    end
    return table.concat(lines, "\n")
end

function Debug.GetBlockedActionDebugInfo(self)
    local getBuildInfo = _G["GetBuildInfo"]
    local getAddOnMetadata = _G["GetAddOnMetadata"]
    local formatDate = _G["date"]
    local unitName = _G["UnitName"]
    local getRealmName = _G["GetRealmName"]
    local getCVar = _G["GetCVar"]
    local wowVersion, buildNumber, buildDate, interfaceVersion = "unknown", "unknown", "unknown", "unknown"
    if getBuildInfo then
        wowVersion, buildNumber, buildDate, interfaceVersion = getBuildInfo()
    end
    local addonVersion = getAddOnMetadata and getAddOnMetadata(addonName, "Version") or "unknown"
    local now = formatDate and formatDate("%Y-%m-%d %H:%M:%S") or "unknown"
    local playerName = unitName and unitName("player") or "unknown"
    local realmName = getRealmName and getRealmName() or "unknown"
    local inCombat = InCombatLockdown and InCombatLockdown() and "true" or "false"
    local lines = {
        "Stock UI Tweaks blocked actions debug",
        string.format("timestamp=%s", now),
        string.format("addon=%s", addonName),
        string.format("addonVersion=%s", tostring(addonVersion or "unknown")),
        string.format("blockedCount=%d", self.blockedInterfaceActionCount or 0),
        "filter=UITweaks only",
        string.format("showCounter=%s", self.db.profile.showBlockedInterfaceActionCount and "true" or "false"),
        string.format("showReloadButton=%s", self.db.profile.showReloadButtonBottomLeft and "true" or "false"),
        string.format("player=%s-%s", tostring(playerName), tostring(realmName)),
        string.format("inCombat=%s", inCombat),
        string.format("scriptErrors=%s", tostring(getCVar and getCVar("scriptErrors") or "unknown")),
        string.format("taintLog=%s", tostring(getCVar and getCVar("taintLog") or "unknown")),
        string.format("wowVersion=%s", tostring(wowVersion)),
        string.format("build=%s", tostring(buildNumber)),
        string.format("buildDate=%s", tostring(buildDate)),
        string.format("interface=%s", tostring(interfaceVersion)),
        self:GetBlockedActionEventDetailsText(),
    }
    return table.concat(lines, "\n")
end

function Debug.EnsureBlockedActionDebugCopyFrame(self)
    if self.blockedActionDebugCopyFrame then
        return self.blockedActionDebugCopyFrame
    end
    if not CreateFrame then return end

    local frame = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(760, 300)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -8)
    title:SetText("Stock UI Tweaks Debug Copy")

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -28)
    hint:SetText("Press Ctrl+C to copy, then paste into chat.")

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -48)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 44)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
    editBox:SetWidth(700)
    editBox:SetHeight(220)
    editBox:SetTextInsets(4, 4, 4, 4)
    editBox:SetTextColor(1, 1, 1, 1)
    editBox:SetJustifyH("LEFT")
    editBox:SetJustifyV("TOP")
    editBox:EnableMouse(true)
    editBox:EnableKeyboard(true)
    local fontObject = _G["ChatFontNormal"] or _G["GameFontHighlightSmall"] or _G["GameFontNormalSmall"]
    if fontObject and editBox.SetFontObject then
        editBox:SetFontObject(fontObject)
    end
    editBox:SetScript("OnTextChanged", function(box)
        if not box then return end
        local text = box:GetText() or ""
        local lines = 1
        for _ in string.gmatch(text, "\n") do
            lines = lines + 1
        end
        local targetHeight = math.max(220, (lines * 14) + 12)
        box:SetHeight(targetHeight)
    end)
    editBox:SetScript("OnEscapePressed", function()
        frame:Hide()
    end)
    scrollFrame:SetScrollChild(editBox)

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeButton:SetSize(100, 22)
    closeButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    local selectAllButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    selectAllButton:SetSize(100, 22)
    selectAllButton:SetPoint("RIGHT", closeButton, "LEFT", -8, 0)
    selectAllButton:SetText("Select All")
    selectAllButton:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    frame.editBox = editBox
    frame.scrollFrame = scrollFrame
    self.blockedActionDebugCopyFrame = frame
    return frame
end

function Debug.ShowBlockedActionDebugCopyDialog(self)
    local frame = self:EnsureBlockedActionDebugCopyFrame()
    if not (frame and frame.editBox and frame.scrollFrame) then return end

    local ok, debugText = pcall(function()
        return self:GetBlockedActionDebugInfo()
    end)
    if not ok or type(debugText) ~= "string" or debugText == "" then
        debugText = string.format(
            "Failed to build debug info\naddon=%s\nblockedCount=%d",
            tostring(addonName),
            tonumber(self.blockedInterfaceActionCount) or 0
        )
    end

    frame:Show()
    frame.editBox:Show()
    frame.editBox:SetText(debugText)
    frame.editBox:SetCursorPosition(0)
    frame.editBox:SetFocus()
    frame.editBox:HighlightText()
    frame.scrollFrame:SetVerticalScroll(0)

    C_Timer.After(0, function()
        if not (frame and frame:IsShown() and frame.editBox) then return end
        frame.editBox:SetText(debugText)
        frame.editBox:SetCursorPosition(0)
        frame.editBox:HighlightText()
        if frame.scrollFrame then
            frame.scrollFrame:SetVerticalScroll(0)
        end
    end)

    local defaultChatFrame = _G["DEFAULT_CHAT_FRAME"]
    if defaultChatFrame and defaultChatFrame.AddMessage then
        defaultChatFrame:AddMessage(string.format("UITweaks: debug text prepared (%d chars).", string.len(debugText)))
    end
end

function Debug.EnsureBlockedActionCounterFrame(self)
    if self.blockedActionCounterFrame then
        return self.blockedActionCounterFrame
    end
    if not CreateFrame then return end

    local frame = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
    frame:SetFrameStrata("TOOLTIP")
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 144, -16)
    frame:SetSize(240, 20)
    frame:EnableMouse(true)
    frame:SetScript("OnClick", function()
        self:ShowBlockedActionDebugCopyDialog()
    end)
    frame:SetScript("OnEnter", function(button)
        if not GameTooltip then return end
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Blocked Actions Debug")
        GameTooltip:AddLine("Click to open a copy box with debug info for this addon.", 1, 1, 1, true)
        GameTooltip:AddLine("Paste that output into chat for troubleshooting.", 1, 1, 1, true)
        GameTooltip:AddLine(string.format("Current count: %d", self.blockedInterfaceActionCount or 0), 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    frame:Hide()

    self.blockedActionCounterFrame = frame
    return frame
end

function Debug.UpdateBlockedActionCounterAnchor(self)
    local frame = self:EnsureBlockedActionCounterFrame()
    if not frame then return end

    frame:ClearAllPoints()
    local reloadButton = self:EnsureBottomLeftReloadButton()
    if reloadButton then
        frame:SetPoint("LEFT", reloadButton, "RIGHT", 8, 0)
    else
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 144, -16)
    end
end

function Debug.UpdateBlockedActionCounterText(self)
    local frame = self:EnsureBlockedActionCounterFrame()
    if not frame then return end
    frame:SetText(string.format("Blocked Events Count: %d", self.blockedInterfaceActionCount or 0))
end

function Debug.UpdateBlockedActionCounterTracking(self)
    if self.db.profile.showBlockedInterfaceActionCount then
        self:RegisterEvent("ADDON_ACTION_BLOCKED")
        self:RegisterEvent("ADDON_ACTION_FORBIDDEN")
        self:UpdateBlockedActionCounterText()
        self:UpdateBlockedActionCounterAnchor()
        local frame = self:EnsureBlockedActionCounterFrame()
        if frame then
            frame:Show()
        end
    else
        self:UnregisterEvent("ADDON_ACTION_BLOCKED")
        self:UnregisterEvent("ADDON_ACTION_FORBIDDEN")
        if self.blockedActionCounterFrame then
            self.blockedActionCounterFrame:Hide()
        end
    end
end

function Debug.HandleBlockedActionEvent(self, eventName, sourceAddonName, ...)
    if sourceAddonName ~= addonName then
        return
    end
    self.blockedInterfaceActionCount = (self.blockedInterfaceActionCount or 0) + 1
    self:AddBlockedActionEventDetail(eventName, sourceAddonName, ...)
    self:UpdateBlockedActionCounterText()
end

function Debug.ADDON_ACTION_BLOCKED(self, _, sourceAddonName, ...)
    self:HandleBlockedActionEvent("ADDON_ACTION_BLOCKED", sourceAddonName, ...)
end

function Debug.ADDON_ACTION_FORBIDDEN(self, _, sourceAddonName, ...)
    self:HandleBlockedActionEvent("ADDON_ACTION_FORBIDDEN", sourceAddonName, ...)
end

function Debug.EnsureReloadButtonForFrame(self, parent)
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

function Debug.EnsureReloadButton(self)
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

function Debug.EnsureBottomLeftReloadButton(self)
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

function Debug.UpdateBottomLeftReloadButton(self)
    local button = self:EnsureBottomLeftReloadButton()
    if not button then return end
    if self.db.profile.showReloadButtonBottomLeft then
        button:Show()
    else
        button:Hide()
    end
    self:UpdateBlockedActionCounterAnchor()
end

function Debug.BuildDebugOptions(self, toggleOption)
    return {
        type = "group",
        name = "Debug",
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
                "Re-open the Stock UI Tweaks options panel after /reload or login (useful for development).",
                3
            ),
            showBlockedInterfaceActionCount = toggleOption(
                "showBlockedInterfaceActionCount",
                "Show On-Screen Blocked Interface Action Count (UITweaks Only)",
                "Show a live on-screen count of blocked interface actions reported for this addon only.",
                4,
                function()
                    self:UpdateBlockedActionCounterTracking()
                end
            ),
            showReloadButtonBottomLeft = toggleOption(
                "showReloadButtonBottomLeft",
                "Show Reload Button in Top Left Corner",
                "Show a Reload button in the top-left corner of the screen.",
                5,
                function()
                    self:UpdateBottomLeftReloadButton()
                end
            ),
        },
    }
end

return Debug
