local _, addonTable = ...
local ImmersionCompatibility = {}

if addonTable then
    addonTable.Immersion = ImmersionCompatibility
end

local swappedButtonIDs = {
    CIRCLE = "TRIANGLE",
    TRIANGLE = "CIRCLE",
}

local function swapButtonID(buttonID)
    return swappedButtonIDs[buttonID] or buttonID
end

local function hasVisibleBlockingPopup()
    for index = 1, 4 do
        local popup = _G["StaticPopup" .. index]
        if popup and popup:IsShown() then return true end
    end
    return false
end

local function wrapHintMethod(frame, methodName)
    local originalMethod = frame[methodName]
    frame[methodName] = function(self, buttonID, ...)
        return originalMethod(self, swapButtonID(buttonID), ...)
    end
end

local function getUIControlKey(consolePort, handle, button)
    if consolePort.GetUIControlKey then
        return consolePort:GetUIControlKey(GetBindingAction(button))
    elseif handle.GetUIControlBinding then
        return handle:GetUIControlBinding(button)
    end
end

local function disableDialogListItemScaling(addon, frame)
    if not addon.db.profile.disableImmersionDialogListItemScaling or addon.immersionDialogListItemScalingDisabled then return end

    local titleButtons = frame and frame.TitleButtons
    if not titleButtons or not titleButtons.Buttons or not titleButtons.GetButton then return end

    local function disableButtonScaling(button)
        button.enterScale = 1
        button.normalScale = 1
        button.targetScale = 1
        button:SetScale(1)
    end

    addon.immersionDialogListItemScalingDisabled = true
    for _, button in pairs(titleButtons.Buttons) do
        disableButtonScaling(button)
    end
    hooksecurefunc(titleButtons, "GetButton", function(self, index)
        local button = self.Buttons[index]
        if button then
            disableButtonScaling(button)
        end
    end)
end

local function applyCircleCancel(addon, frame)
    if not addon.db.profile.useCircleToCancelImmersion or addon.immersionCircleCancelApplied then return end

    local api = _G.ImmersionAPI
    local consolePort = _G.ConsolePort
    local handle = _G.ConsolePortUIHandle
    if not frame or not api or not consolePort or not handle then return end

    addon.immersionCircleCancelApplied = true

    wrapHintMethod(frame, "AddHint")
    wrapHintMethod(frame, "RemoveHint")
    wrapHintMethod(frame, "SetHintEnabled")
    wrapHintMethod(frame, "SetHintDisabled")
    wrapHintMethod(frame, "GetHintForKey")

    local originalParseControllerCommand = frame.ParseControllerCommand
    local keys = consolePort:GetData().KEY
    frame.ParseControllerCommand = function(self, button)
        if not handle:IsHintFocus(self)
            or hasVisibleBlockingPopup()
            or (_G.AzeriteEmpoweredItemUI and _G.AzeriteEmpoweredItemUI:IsVisible())
            or self:IsInspectModifier(button)
            or button:match("SHIFT")
        then
            return originalParseControllerCommand(self, button)
        end

        local keyID = getUIControlKey(consolePort, handle, button)
        if keyID == keys.CIRCLE then
            api:CloseGossip()
            api:CloseQuest()
            return true
        elseif keyID == keys.TRIANGLE then
            if self.isInspecting then
                self.Inspector:Hide()
            elseif self.hasItems then
                self:ShowItems()
            end
            return true
        end

        return originalParseControllerCommand(self, button)
    end
end

function ImmersionCompatibility.Apply(addon)
    local frame = _G.ImmersionFrame
    if not frame then return end

    disableDialogListItemScaling(addon, frame)
    applyCircleCancel(addon, frame)
end

return ImmersionCompatibility
