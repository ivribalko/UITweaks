local _, addonTable = ...
-- Adds ConsolePort shoulder-button navigation and controller-aware tab hints.
local ConsolePortTabs = {}
local hookedFrames = setmetatable({}, { __mode = "k" })
local overlayRecords = setmetatable({}, { __mode = "k" })
local watchedTabs = setmetatable({}, { __mode = "k" })
local tabOverlays = setmetatable({}, { __mode = "k" })
local cycleSelections = setmetatable({}, { __mode = "k" })
local pressedShoulders = {}
local iconCallbackSource

if addonTable then
    addonTable.ConsolePortTabs = ConsolePortTabs
end

local function getDirection(button)
    if button == "PADLSHOULDER" then
        return -1
    elseif button == "PADRSHOULDER" then
        return 1
    end
end

local function selectAdjacent(currentValue, values, direction, selectValue)
    if #values < 2 then return false end

    local currentIndex
    for index, value in ipairs(values) do
        if value == currentValue then
            currentIndex = index
            break
        end
    end

    local nextIndex
    if currentIndex then
        nextIndex = ((currentIndex - 1 + direction) % #values) + 1
    elseif direction > 0 then
        nextIndex = 1
    else
        nextIndex = #values
    end

    selectValue(values[nextIndex])
    return true
end

local function selectFrameAdjacent(frame, currentValue, values, direction, selectValue)
    local cachedValue = cycleSelections[frame]
    for _, value in ipairs(values) do
        if value == cachedValue then
            currentValue = cachedValue
            break
        end
    end

    return selectAdjacent(currentValue, values, direction, function(value)
        cycleSelections[frame] = value
        selectValue(value)
    end)
end

local function isPanelTabAvailable(frame, tab)
    return tab and tab:IsShown()
        and (tab:IsEnabled() or tab:GetID() == PanelTemplates_GetSelectedTab(frame))
end

local function getCharacterTabs(frame, includeUnavailable)
    local tabs = {
        _G.CharacterFrameTab1,
        _G.CharacterFrameTab2,
        _G.CharacterFrameTab3,
    }
    if includeUnavailable then return tabs end

    local availableTabs = {}
    for _, tab in ipairs(tabs) do
        if isPanelTabAvailable(frame, tab) then
            table.insert(availableTabs, tab)
        end
    end
    return availableTabs
end

local function getAdventureGuideTabs(frame, includeUnavailable)
    local tabs = {
        frame.JourneysTab,
        frame.MonthlyActivitiesTab,
        frame.suggestTab,
        frame.dungeonsTab,
        frame.raidsTab,
        frame.LootJournalTab,
        frame.TutorialsTab,
    }
    if includeUnavailable then return tabs end

    local availableTabs = {}
    for _, tab in ipairs(tabs) do
        if isPanelTabAvailable(frame, tab) then
            table.insert(availableTabs, tab)
        end
    end
    return availableTabs
end

local function getBankTabs(frame, includeUnavailable)
    local tabs = {}
    for _, tabID in ipairs(frame:GetTabSet()) do
        local tab = frame:GetTabButton(tabID)
        if tab and (includeUnavailable or tab:IsShown()) then
            table.insert(tabs, tab)
        end
    end
    return tabs
end

local function getDungeonsAndRaidsTabs(frame, includeUnavailable)
    local tabs = { frame.tab1, frame.tab2, frame.tab3 }
    if includeUnavailable then return tabs end

    local availableTabs = {}
    for _, tab in ipairs(tabs) do
        if isPanelTabAvailable(frame, tab) then
            table.insert(availableTabs, tab)
        end
    end
    return availableTabs
end

local function getMapTabs(frame, includeUnavailable)
    local tabs = {}
    for _, tab in ipairs(frame.TabButtons) do
        if includeUnavailable or tab:IsShown() then
            table.insert(tabs, tab)
        end
    end
    return tabs
end

local function getPlayerSpellsTabs(frame, includeUnavailable)
    local tabs = {}
    for _, tabID in ipairs({ frame.specTabID, frame.talentTabID, frame.spellBookTabID }) do
        local tab = tabID and frame:GetTabButton(tabID)
        if tab and (includeUnavailable or frame:IsTabAvailable(tabID)) then
            table.insert(tabs, tab)
        end
    end
    return tabs
end

local function getCollectionsTabs(frame, includeUnavailable)
    local tabs = {}
    for index = 1, 6 do
        local tab = _G["CollectionsJournalTab" .. index]
        if tab and (includeUnavailable or isPanelTabAvailable(frame, tab)) then
            table.insert(tabs, tab)
        end
    end
    return tabs
end

local function setOverlayIcon(record, texture, button)
    record.data.Gamepad.SetIconToTexture(texture, button, 32, { 24, 24 }, { 18, 18 })
end

local function getTabOverlays(tab)
    local overlays = tabOverlays[tab]
    if overlays then return overlays end

    overlays = {
        decrement = tab:CreateTexture(nil, "OVERLAY", nil, 7),
        increment = tab:CreateTexture(nil, "OVERLAY", nil, 7),
    }
    overlays.decrement:SetSize(32, 32)
    overlays.decrement:SetPoint("CENTER", tab, "LEFT", 8, 0)
    overlays.increment:SetSize(32, 32)
    overlays.increment:SetPoint("CENTER", tab, "RIGHT", -8, 0)
    overlays.decrement:Hide()
    overlays.increment:Hide()
    tabOverlays[tab] = overlays
    return overlays
end

local function refreshOverlay(record)
    for _, tab in ipairs(record.getTabs(record.frame, true)) do
        local overlays = tabOverlays[tab]
        if overlays then
            overlays.decrement:Hide()
            overlays.increment:Hide()
        end
    end

    local tabs = record.getTabs(record.frame)
    local show = record.frame:IsShown() and #tabs > 1
    if not show then return end

    local firstTabOverlays = getTabOverlays(tabs[1])
    local lastTabOverlays = getTabOverlays(tabs[#tabs])
    setOverlayIcon(record, firstTabOverlays.decrement, "PADLSHOULDER")
    setOverlayIcon(record, lastTabOverlays.increment, "PADRSHOULDER")
    firstTabOverlays.decrement:Show()
    lastTabOverlays.increment:Show()
end

local function scheduleOverlayRefresh(record)
    if record.refreshPending then return end
    record.refreshPending = true
    C_Timer.After(0, function()
        record.refreshPending = nil
        if overlayRecords[record.frame] == record then
            refreshOverlay(record)
        end
    end)
end

local function watchTabs(record)
    for _, tab in ipairs(record.getTabs(record.frame, true)) do
        if tab and not watchedTabs[tab] then
            tab:HookScript("OnShow", function() scheduleOverlayRefresh(record) end)
            tab:HookScript("OnHide", function() scheduleOverlayRefresh(record) end)
            watchedTabs[tab] = true
        end
    end
end

local function addOverlays(frame, data, getTabs)
    local record = overlayRecords[frame]
    if record then
        watchTabs(record)
        refreshOverlay(record)
        return
    end

    record = {
        frame = frame,
        data = data,
        getTabs = getTabs,
    }
    overlayRecords[frame] = record
    watchTabs(record)
    refreshOverlay(record)

    frame:HookScript("OnShow", function()
        watchTabs(record)
        scheduleOverlayRefresh(record)
    end)
    frame:HookScript("OnHide", function()
        refreshOverlay(record)
    end)
end

function ConsolePortTabs:RefreshOverlays()
    for _, record in pairs(overlayRecords) do
        refreshOverlay(record)
    end
end

local function hookFrame(addon, consolePort, data, frame, changeTab, getTabs)
    if not frame then return false end

    addOverlays(frame, data, getTabs)
    if hookedFrames[frame] then return false end

    local inputFrame = CreateFrame("Frame", nil, frame)
    inputFrame:SetAllPoints(frame)
    inputFrame:SetFrameStrata("TOOLTIP")
    inputFrame:SetAttribute("nodeignore", true)
    inputFrame:SetPropagateKeyboardInput(true)
    inputFrame:EnableGamePadButton(true)
    inputFrame:SetScript("OnGamePadButtonDown", function(self, button)
        local direction = getDirection(button)
        local shouldHandle = addon.db.profile.addTabControlsToConsolePort
            and consolePort:IsCursorActive()
            and frame:IsVisible()
            and direction
        if not shouldHandle then
            self:SetPropagateKeyboardInput(true)
            return
        end

        self:SetPropagateKeyboardInput(false)
        if pressedShoulders[button] then return end

        pressedShoulders[button] = true
        local handled = changeTab(frame, direction)
        if not handled then self:SetPropagateKeyboardInput(true) end
        if handled then scheduleOverlayRefresh(overlayRecords[frame]) end
    end)
    inputFrame:SetScript("OnGamePadButtonUp", function(self, button)
        if getDirection(button) then pressedShoulders[button] = nil end
        self:SetPropagateKeyboardInput(true)
    end)
    frame:HookScript("OnHide", function()
        cycleSelections[frame] = nil
        pressedShoulders.PADLSHOULDER = nil
        pressedShoulders.PADRSHOULDER = nil
    end)

    hookedFrames[frame] = inputFrame
    return true
end

local function clickTabWithID(tabs, tabID)
    for _, tab in ipairs(tabs) do
        if tab:GetID() == tabID then
            tab:Click("LeftButton")
            return
        end
    end
end

local function changeButtonTabs(frame, direction, getTabs)
    local tabs = getTabs(frame)
    local tabIDs = {}
    for _, tab in ipairs(tabs) do
        table.insert(tabIDs, tab:GetID())
    end

    return selectFrameAdjacent(frame, PanelTemplates_GetSelectedTab(frame), tabIDs, direction, function(tabID)
        clickTabWithID(tabs, tabID)
    end)
end

local function changeCharacterTab(frame, direction)
    local tabs = getCharacterTabs(frame)
    local subframeNames = { "PaperDollFrame", "ReputationFrame", "TokenFrame" }
    local tabIDs = {}
    local currentTabID
    for _, tab in ipairs(tabs) do
        local tabID = tab:GetID()
        table.insert(tabIDs, tabID)
        local subframe = _G[subframeNames[tabID]]
        if subframe and subframe:IsShown() then
            currentTabID = tabID
        end
    end

    return selectFrameAdjacent(frame, currentTabID, tabIDs, direction, function(tabID)
        clickTabWithID(tabs, tabID)
    end)
end

local function changeAdventureGuideTab(frame, direction)
    local tabIDs = {}
    for _, tab in ipairs(getAdventureGuideTabs(frame)) do
        table.insert(tabIDs, tab:GetID())
    end

    return selectFrameAdjacent(frame, PanelTemplates_GetSelectedTab(frame), tabIDs, direction, function(tabID)
        _G.EJ_ContentTab_Select(tabID)
    end)
end

local function changeBankTab(frame, direction)
    local tabIDs = {}
    for _, tabID in ipairs(frame:GetTabSet()) do
        local tab = frame:GetTabButton(tabID)
        if tab and tab:IsShown() then
            table.insert(tabIDs, tabID)
        end
    end

    return selectFrameAdjacent(frame, frame:GetTab(), tabIDs, direction, function(tabID)
        frame:SetTab(tabID)
    end)
end

local function changeMapTab(frame, direction)
    local displayModes = {}
    for _, tab in ipairs(getMapTabs(frame)) do
        table.insert(displayModes, tab.displayMode)
    end

    return selectFrameAdjacent(frame, frame.displayMode, displayModes, direction, function(displayMode)
        frame:SetDisplayMode(displayMode)
    end)
end

local function changeDungeonsAndRaidsTab(frame, direction)
    return changeButtonTabs(frame, direction, getDungeonsAndRaidsTabs)
end

local function changePlayerSpellsTab(frame, direction)
    local tabIDs = {}
    for _, tabID in ipairs({ frame.specTabID, frame.talentTabID, frame.spellBookTabID }) do
        if tabID and frame:IsTabAvailable(tabID) then
            table.insert(tabIDs, tabID)
        end
    end

    return selectFrameAdjacent(frame, frame:GetTab(), tabIDs, direction, function(tabID)
        frame:SetTab(tabID)
    end)
end

local function changeCollectionsTab(frame, direction)
    return changeButtonTabs(frame, direction, getCollectionsTabs)
end

function ConsolePortTabs.Apply(addon)
    if not addon.db.profile.addTabControlsToConsolePort then return false end

    local consolePort = _G.ConsolePort
    if not consolePort or not consolePort.IsCursorActive or not consolePort.GetData then return false end

    local data = consolePort:GetData()
    if not data or not data.Gamepad or not data.Gamepad.SetIconToTexture then return false end
    if iconCallbackSource ~= data then
        data:RegisterCallback("OnIconsChanged", ConsolePortTabs.RefreshOverlays, ConsolePortTabs)
        iconCallbackSource = data
    end

    local applied = false
    applied = hookFrame(addon, consolePort, data, _G.EncounterJournal, changeAdventureGuideTab, getAdventureGuideTabs) or applied
    applied = hookFrame(addon, consolePort, data, _G.BankFrame, changeBankTab, getBankTabs) or applied
    applied = hookFrame(addon, consolePort, data, _G.CharacterFrame, changeCharacterTab, getCharacterTabs) or applied
    applied = hookFrame(addon, consolePort, data, _G.PVEFrame, changeDungeonsAndRaidsTab, getDungeonsAndRaidsTabs) or applied

    local questLog = _G.QuestMapFrame
    if questLog and questLog.TabButtons then
        applied = hookFrame(addon, consolePort, data, questLog, changeMapTab, getMapTabs) or applied
    end

    local playerSpells = _G.PlayerSpellsFrame
    if playerSpells and playerSpells.IsTabAvailable and playerSpells.GetTabButton then
        applied = hookFrame(addon, consolePort, data, playerSpells, changePlayerSpellsTab, getPlayerSpellsTabs) or applied
    end

    applied = hookFrame(addon, consolePort, data, _G.CollectionsJournal, changeCollectionsTab, getCollectionsTabs) or applied
    return applied
end

return ConsolePortTabs
