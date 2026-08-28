local _, addonTable = ...
-- Remembers selected requirements for Blizzard Dungeon and Raid group listings.
local GroupFinder = {}
local addonInstance
local applied

local DUNGEON_CATEGORY_ID = 2
local RAID_CATEGORY_ID = 3

if addonTable then
    addonTable.GroupFinder = GroupFinder
end

local function getCategoryKey(categoryID)
    if categoryID == DUNGEON_CATEGORY_ID then return "dungeons" end
    if categoryID == RAID_CATEGORY_ID then return "raids" end
end

local function getEntryCreation()
    return LFGListFrame and LFGListFrame.EntryCreation
end

local function isNewRememberedListing(entryCreation)
    if not addonInstance.db.profile.rememberGroupFinderRequirements then return false end
    if LFGListEntryCreation_IsEditMode(entryCreation) then return false end
    return getCategoryKey(entryCreation.selectedCategory) ~= nil
end

local function getSavedRequirements(entryCreation)
    local categoryKey = getCategoryKey(entryCreation.selectedCategory)
    return categoryKey and addonInstance.db.profile.groupFinderRequirements[categoryKey]
end

local function saveItemLevel(entryCreation)
    if not isNewRememberedListing(entryCreation) then return end
    getSavedRequirements(entryCreation).itemLevel = tonumber(entryCreation.ItemLevel.EditBox:GetText())
end

local function saveMythicPlusRating(entryCreation)
    if not isNewRememberedListing(entryCreation)
        or entryCreation.selectedCategory ~= DUNGEON_CATEGORY_ID
    then
        return
    end
    getSavedRequirements(entryCreation).mythicPlusRating = tonumber(entryCreation.MythicPlusRating.EditBox:GetText())
end

local function savePlaystyle(entryCreation)
    if not isNewRememberedListing(entryCreation) then return end
    getSavedRequirements(entryCreation).playstyle = entryCreation.generalPlaystyle
end

local function setRequirement(requirement, value)
    local text = value and tostring(value) or ""
    requirement.EditBox:SetText(text)
    requirement.CheckButton:SetChecked(text ~= "")
end

local function restoreRequirements(entryCreation)
    if not isNewRememberedListing(entryCreation) then return end

    local saved = getSavedRequirements(entryCreation)
    setRequirement(entryCreation.ItemLevel, saved.itemLevel)
    if entryCreation.selectedCategory == DUNGEON_CATEGORY_ID then
        setRequirement(entryCreation.MythicPlusRating, saved.mythicPlusRating)
    end
    if saved.playstyle and saved.playstyle ~= Enum.LFGEntryGeneralPlaystyle.None then
        LFGListEntryCreation_OnPlayStyleSelectedInternal(entryCreation, saved.playstyle)
    end
    LFGListEntryCreation_UpdateValidState(entryCreation)
end

local function hookEntryCreation(entryCreation)
    if entryCreation.uitweaksRequirementsHooked then return end

    entryCreation.ItemLevel.EditBox:HookScript("OnTextChanged", function()
        saveItemLevel(entryCreation)
    end)
    entryCreation.MythicPlusRating.EditBox:HookScript("OnTextChanged", function()
        saveMythicPlusRating(entryCreation)
    end)
    hooksecurefunc("LFGListEntryCreation_OnPlayStyleSelectedInternal", function(changedEntryCreation)
        if changedEntryCreation == entryCreation then savePlaystyle(entryCreation) end
    end)
    hooksecurefunc("LFGListEntryCreation_Show", function(shownEntryCreation)
        if shownEntryCreation == entryCreation then restoreRequirements(entryCreation) end
    end)

    entryCreation.uitweaksRequirementsHooked = true
end

function GroupFinder.Apply(addon)
    addonInstance = addon
    if applied then return true end

    local entryCreation = getEntryCreation()
    if not entryCreation
        or not LFGListEntryCreation_IsEditMode
        or not LFGListEntryCreation_OnPlayStyleSelectedInternal
        or not LFGListEntryCreation_Show
    then
        return false
    end

    hookEntryCreation(entryCreation)
    applied = true
    return true
end

return GroupFinder
