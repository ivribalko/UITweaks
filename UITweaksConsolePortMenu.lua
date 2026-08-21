local addonName, addonTable = ...
local ConsolePortMenu = {}

if addonTable then
    addonTable.ConsolePortMenu = ConsolePortMenu
end

local function isAddOnLoaded(name)
    return (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name))
        or (IsAddOnLoaded and IsAddOnLoaded(name))
end

local function canLeaveInstanceGroup()
    return PartyUtil and PartyUtil.CanLeaveInstance and PartyUtil.CanLeaveInstance()
end

local function leaveInstanceGroup()
    if canLeaveInstanceGroup() and ConfirmOrLeaveParty then
        ConfirmOrLeaveParty()
    end
end

local function createLeaveInstanceGroupButtonData()
    return {
        UITweaksLeaveInstanceGroup = true,
        text = INSTANCE_PARTY_LEAVE or "Leave Instance Group",
        atlas = "poi-door-down",
        click = leaveInstanceGroup,
        OnShow = function(button)
            button:SetEnabled(canLeaveInstanceGroup())
        end,
    }
end

local function findScenarioButtonIndex(selector)
    for button in selector:EnumerateActive() do
        if button.states then
            for _, state in ipairs(button.states) do
                if state.text == TELEPORT_OUT_OF_DUNGEON then
                    return button:GetID()
                end
            end
        end
    end
end

local function findLeaveInstanceGroupButton(selector)
    for button in selector:EnumerateActive() do
        if button.UITweaksLeaveInstanceGroup then
            return button
        end
    end
end

local function setSecureButtonReference(selector, index, button)
    selector:SetFrameRef(tostring(index), button)
    selector:Run([[
        local index = %d;
        BUTTONS[index] = self:GetFrameRef(tostring(index));
    ]], index)
end

local function updateSelectorMacro(selector, buttonCount)
    local macroLines = {}
    for index = 1, buttonCount do
        local button = selector:GetObjectByIndex(index)
        if button then
            macroLines[#macroLines + 1] = "/click " .. button:GetName()
        end
    end
    selector:SetAttribute("macrotext", table.concat(macroLines, "\n"))
end

local function updateSelectorSize(selector, buttonCount)
    selector:SetDynamicSizeFunction(("local size = %d;"):format(buttonCount))
    selector:SetAttribute("numbuttons", buttonCount)
    updateSelectorMacro(selector, buttonCount)
end

local function addButtonToInitializedSelector(selector, insertIndex)
    local oldButtonCount = selector:GetNumActive()
    local buttonCount = oldButtonCount + 1
    local activeButtons = {}

    for button in selector:EnumerateActive() do
        activeButtons[button:GetID()] = button
    end
    selector.Registry = {}
    selector:Run([[ wipe(BUTTONS) ]])

    for oldIndex = 1, oldButtonCount do
        local button = activeButtons[oldIndex]
        if not button then return false end
        local newIndex = oldIndex >= insertIndex and oldIndex + 1 or oldIndex
        local point, x, y = selector:GetPointForIndex(newIndex, buttonCount)
        button:ClearAllPoints()
        button:SetPoint(point, x, selector.axisInversion * y)
        button:SetRotation(selector:GetRotation(x, y))
        button:SetID(newIndex)
        selector.Registry[newIndex] = button
        setSecureButtonReference(selector, newIndex, button)
    end

    local button, newButton = selector:Acquire(insertIndex)
    local point, x, y = selector:GetPointForIndex(insertIndex, buttonCount)
    if newButton then
        button:SetSize(60, 60)
        button:RegisterForClicks("AnyUp")
        button:SetAttribute(CPAPI.ActionPressAndHold, true)
        button.Name:Hide()
    end
    button:SetPoint(point, x, selector.axisInversion * y)
    button:SetRotation(selector:GetRotation(x, y))
    button:SetID(insertIndex)
    button:Show()
    button:SetData(createLeaveInstanceGroupButtonData())
    setSecureButtonReference(selector, insertIndex, button)
    if not button.UITweaksPostClickHooked then
        selector:Hook(button, "PostClick", selector.PrivateEnv.ButtonPostClick)
        button.UITweaksPostClickHooked = true
    end
    return button, buttonCount
end

local function removeButtonFromSelector(selector, targetButton)
    local oldButtonCount = selector:GetNumActive()
    local buttonCount = oldButtonCount - 1
    local activeButtons = {}

    for button in selector:EnumerateActive() do
        activeButtons[button:GetID()] = button
    end

    selector.ObjectPool:Release(targetButton)
    selector.Registry = {}
    selector:Run([[ wipe(BUTTONS) ]])

    local newIndex = 0
    for oldIndex = 1, oldButtonCount do
        local button = activeButtons[oldIndex]
        if button and button ~= targetButton then
            newIndex = newIndex + 1
            local point, x, y = selector:GetPointForIndex(newIndex, buttonCount)
            button:ClearAllPoints()
            button:SetPoint(point, x, selector.axisInversion * y)
            button:SetRotation(selector:GetRotation(x, y))
            button:SetID(newIndex)
            selector.Registry[newIndex] = button
            setSecureButtonReference(selector, newIndex, button)
        end
    end

    updateSelectorSize(selector, buttonCount)
end

local function ensureGroupWatcher(addon)
    if addon.consolePortMenuGroupWatcher then return end

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("GROUP_ROSTER_UPDATE")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:SetScript("OnEvent", function()
        ConsolePortMenu.Apply(addon)
    end)
    addon.consolePortMenuGroupWatcher = watcher
end

function ConsolePortMenu.Apply(addon)
    if not addon.db.profile.addLeaveInstanceGroupToConsolePortMenu then return false end
    ensureGroupWatcher(addon)
    if InCombatLockdown and InCombatLockdown() then return false end
    if not isAddOnLoaded("ConsolePort_Menu") then return false end

    local selector = _G.ConsolePortMenuRing
    if not selector or not selector.ObjectPool then
        if not addon.consolePortMenuRetryPending then
            addon.consolePortMenuRetryPending = true
            C_Timer.After(0, function()
                addon.consolePortMenuRetryPending = nil
                ConsolePortMenu.Apply(addon)
            end)
        end
        return true
    end

    local leaveInstanceGroupButton = findLeaveInstanceGroupButton(selector)
    if not IsInGroup() then
        if leaveInstanceGroupButton then
            removeButtonFromSelector(selector, leaveInstanceGroupButton)
        end
        addon.consolePortMenuApplied = nil
        return true
    end
    if leaveInstanceGroupButton then
        addon.consolePortMenuApplied = true
        return true
    end

    local scenarioIndex = findScenarioButtonIndex(selector)
    if not scenarioIndex then return false end
    local buttonCount
    leaveInstanceGroupButton, buttonCount = addButtonToInitializedSelector(selector, scenarioIndex)
    if not leaveInstanceGroupButton then return false end

    updateSelectorSize(selector, buttonCount)
    addon.consolePortMenuApplied = true
    return true
end

return ConsolePortMenu
