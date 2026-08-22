local addonName, addonTable = ...
local ConsolePortMenu = {}
local MYTHIC_PLUS_CATEGORY_ID = 2
local mythicPlusFinderWatcher

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

local function enableGroupFinderFilterGamepadClick()
    local panel = LFGListFrame and LFGListFrame.SearchPanel
    local dropdown = panel and panel.FilterButton
    if not dropdown or dropdown.UITweaksConsolePortDropdownClick then return end
    dropdown.UITweaksConsolePortDropdownClick = true

    dropdown:HookScript("OnMouseDown", function(button, mouseButton)
        if mouseButton ~= "LeftButton" or IsMouseButtonDown("LeftButton") then return end
        if not ConsolePort or not ConsolePort.IsCursorActive or not ConsolePort:IsCursorActive() then return end
        if ConsolePort:GetCursorNode() ~= button then return end
        if button.UITweaksHandlingGamepadClick then return end

        button.UITweaksHandlingGamepadClick = true
        button:SetMenuOpen(not button:IsMenuOpen())
        C_Timer.After(0, function()
            button.UITweaksHandlingGamepadClick = nil
        end)
    end)
end

local function tryOpenMythicPlusFinder()
    if not LFGListFrame or C_LFGList.HasActiveEntryInfo() then return true end
    local filters = bit.bor(Enum.LFGListFilter.PvE, Enum.LFGListFilter.Recommended)
    if #C_LFGList.GetAvailableActivities(MYTHIC_PLUS_CATEGORY_ID, nil, filters) == 0 then
        return false
    end

    LFGListFrame_SetBaseFilters(LFGListFrame, Enum.LFGListFilter.PvE)
    local panel = LFGListFrame.CategorySelection
    LFGListCategorySelection_SelectCategory(panel, MYTHIC_PLUS_CATEGORY_ID, 0)
    LFGListCategorySelection_StartFindGroup(panel)
    return true
end

local function waitToOpenMythicPlusFinder()
    if not mythicPlusFinderWatcher then
        mythicPlusFinderWatcher = CreateFrame("Frame")
        mythicPlusFinderWatcher:SetScript("OnEvent", function(watcher)
            if tryOpenMythicPlusFinder() then
                watcher:UnregisterEvent("LFG_LIST_AVAILABILITY_UPDATE")
            end
        end)
    end
    mythicPlusFinderWatcher:RegisterEvent("LFG_LIST_AVAILABILITY_UPDATE")
end

local function openMythicPlusFinder()
    if not isAddOnLoaded("Blizzard_GroupFinder") and C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("Blizzard_GroupFinder")
    end
    if not PVEFrame_ShowFrame or not LFGListPVEStub or not LFGListFrame then return end

    enableGroupFinderFilterGamepadClick()
    PVEFrame_ShowFrame("GroupFinderFrame", LFGListPVEStub)
    C_LFGList.RequestAvailableActivities()
    if not tryOpenMythicPlusFinder() then
        waitToOpenMythicPlusFinder()
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

local function createMythicPlusFinderButtonData()
    return {
        UITweaksMythicPlusFinder = true,
        text = "Mythic+ Finder",
        img = "Interface\\LFGFRAME\\UI-LFG-PORTRAIT",
        click = openMythicPlusFinder,
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

local function findGroupFinderButtonIndex(selector)
    for button in selector:EnumerateActive() do
        if (DUNGEONS_BUTTON and button.text == DUNGEONS_BUTTON)
            or (LFDMicroButton and button.ref == LFDMicroButton)
            or (LFGMicroButton and button.ref == LFGMicroButton)
        then
            return button:GetID()
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

local function findMythicPlusFinderButton(selector)
    for button in selector:EnumerateActive() do
        if button.UITweaksMythicPlusFinder then
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

local function addButtonToInitializedSelector(selector, insertIndex, buttonData)
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
    button:SetData(buttonData)
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
    local addLeaveButton = addon.db.profile.addLeaveInstanceGroupToConsolePortMenu
    local addMythicPlusButton = addon.db.profile.addMythicPlusFinderToConsolePortMenu
    if not addLeaveButton and not addMythicPlusButton then return false end
    if addLeaveButton then
        ensureGroupWatcher(addon)
    end
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
    if addLeaveButton and not IsInGroup() then
        if leaveInstanceGroupButton then
            removeButtonFromSelector(selector, leaveInstanceGroupButton)
        end
        leaveInstanceGroupButton = nil
    elseif addLeaveButton and not leaveInstanceGroupButton then
        local scenarioIndex = findScenarioButtonIndex(selector)
        if not scenarioIndex then return false end
        local buttonCount
        leaveInstanceGroupButton, buttonCount = addButtonToInitializedSelector(
            selector,
            scenarioIndex,
            createLeaveInstanceGroupButtonData()
        )
        if not leaveInstanceGroupButton then return false end
        updateSelectorSize(selector, buttonCount)
    end

    local mythicPlusFinderButton = findMythicPlusFinderButton(selector)
    if addMythicPlusButton and not mythicPlusFinderButton then
        local groupFinderIndex = findGroupFinderButtonIndex(selector)
        if not groupFinderIndex then return false end
        local buttonCount
        mythicPlusFinderButton, buttonCount = addButtonToInitializedSelector(
            selector,
            groupFinderIndex + 1,
            createMythicPlusFinderButtonData()
        )
        if not mythicPlusFinderButton then return false end
        updateSelectorSize(selector, buttonCount)
    end

    addon.consolePortMenuApplied = true
    return true
end

return ConsolePortMenu
