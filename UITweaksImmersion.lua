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

function ImmersionCompatibility.Apply(addon)
    if not addon.db.profile.useCircleToCancelImmersion or addon.immersionCircleCancelApplied then return end

    local frame = _G.ImmersionFrame
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

return ImmersionCompatibility
