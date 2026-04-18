local addonName, addonTable = ...
local Consumables = {}

if addonTable then
    addonTable.Consumables = Consumables
end

local UPDATE_INTERVAL_SECONDS = 0.2
local MAIN_HAND_SLOT_ID = 16
local OFF_HAND_SLOT_ID = 17
local ITEM_CLASS_CONSUMABLE = 0
local ITEM_SUBCLASS_FOOD_AND_DRINK = 5

local function formatRemainingTime(remainingSeconds)
    if not remainingSeconds or remainingSeconds <= 0 then return "" end
    if remainingSeconds >= 3600 then
        return tostring(math.ceil(remainingSeconds / 3600)) .. "h"
    end
    if remainingSeconds >= 60 then
        return tostring(math.ceil(remainingSeconds / 60)) .. "m"
    end
    return tostring(math.ceil(remainingSeconds))
end

local function getHelpfulAuras()
    local auraBySpellID = {}
    local auraByName = {}

    local function is_valid_key(key)
        local t = type(key)
        return key ~= nil and (t == "string" or t == "number")
    end

    local function safe_assign(tbl, key, value, context)
        if type(tbl) ~= "table" then return end
        if is_valid_key(key) then
            local ok = pcall(function()
                if tbl[key] == nil then
                    tbl[key] = value
                end
            end)
            -- silently ignore errors
        end
        -- silently skip invalid keys
    end

    if type(auraBySpellID) ~= "table" then auraBySpellID = {} end
    if type(auraByName) ~= "table" then auraByName = {} end

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local index = 1
        while true do
            local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
            if not aura then break end
            safe_assign(auraBySpellID, aura.spellId, aura, "auraBySpellID at index " .. tostring(index))
            safe_assign(auraByName, aura.name, aura, "auraByName at index " .. tostring(index))
            index = index + 1
        end
    elseif AuraUtil and AuraUtil.ForEachAura then
        AuraUtil.ForEachAura("player", "HELPFUL", nil, function(aura)
            safe_assign(auraBySpellID, aura.spellId, aura, "auraBySpellID in AuraUtil")
            safe_assign(auraByName, aura.name, aura, "auraByName in AuraUtil")
        end)
    end

    return auraBySpellID, auraByName
end

local function findWellFedAura(auraByName)
    if not auraByName then return nil end
    for auraName, auraData in pairs(auraByName) do
        if type(auraName) == "string" and auraName:lower():find("well fed", 1, true) then
            return auraData
        end
    end
end

local function isFoodItem(itemID)
    if not itemID then return false end

    if GetItemInfoInstant then
        local _, itemType, itemSubType, _, _, classID, subClassID = GetItemInfoInstant(itemID)
        if classID == ITEM_CLASS_CONSUMABLE and subClassID == ITEM_SUBCLASS_FOOD_AND_DRINK then
            return true
        end

        if itemType == "Consumable" and itemSubType and itemSubType:find("Food", 1, true) then
            return true
        end
    end

    return false
end

local function normalizeSearchText(text)
    if type(text) ~= "string" or text == "" then return nil end
    return text:lower()
end

local function tooltipDataContainsText(tooltipData, searchText)
    local normalizedSearchText = normalizeSearchText(searchText)
    if not normalizedSearchText or not tooltipData or not tooltipData.lines then return false end

    for _, line in ipairs(tooltipData.lines) do
        local leftText = normalizeSearchText(line.leftText or line.text)
        local rightText = normalizeSearchText(line.rightText)
        if leftText and leftText:find(normalizedSearchText, 1, true) then
            return true
        end
        if rightText and rightText:find(normalizedSearchText, 1, true) then
            return true
        end
    end

    return false
end

local function buildWeaponEnchantStates()
    if not GetWeaponEnchantInfo then return {} end

    local states = {}
    local hasMainHandEnchant, mainHandExpiration, _, _, hasOffHandEnchant, offHandExpiration = GetWeaponEnchantInfo()
    local now = GetTime()

    if hasMainHandEnchant and mainHandExpiration and mainHandExpiration > 0 then
        states[#states + 1] = {
            slotID = MAIN_HAND_SLOT_ID,
            expirationTime = now + (mainHandExpiration / 1000),
        }
    end
    if hasOffHandEnchant and offHandExpiration and offHandExpiration > 0 then
        states[#states + 1] = {
            slotID = OFF_HAND_SLOT_ID,
            expirationTime = now + (offHandExpiration / 1000),
        }
    end

    return states
end

local function buildWeaponEnchantTooltipCache()
    if not C_TooltipInfo or not C_TooltipInfo.GetInventoryItem then return {} end

    local weaponEnchantStates = buildWeaponEnchantStates()
    for _, state in ipairs(weaponEnchantStates) do
        state.tooltipData = C_TooltipInfo.GetInventoryItem("player", state.slotID)
    end
    return weaponEnchantStates
end

local function getContainerButtonItemInfo(button)
    if not C_Container or not C_Container.GetContainerItemID then return end

    local bagID = button and button.GetBagID and button:GetBagID() or nil
    local slot = button and button.GetID and button:GetID() or nil
    if bagID == nil or slot == nil then return end

    local itemID = C_Container.GetContainerItemID(bagID, slot)
    if not itemID then return end

    local itemLink = C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bagID, slot) or nil
    return bagID, slot, itemID, itemLink
end

local function getItemSpellInfo(itemID, itemLink)
    if not GetItemSpell then return end

    local spellName, spellID = nil, nil
    if itemLink then
        spellName, spellID = GetItemSpell(itemLink)
    end
    if not spellName and not spellID and itemID then
        spellName, spellID = GetItemSpell(itemID)
    end
    if spellID or spellName then
        return spellID, spellName
    end
end

local function getItemButtonAnchor(button)
    return button.icon or button.Icon or button
end

local function createConsumableOverlay(button)
    local anchor = getItemButtonAnchor(button)
    local overlay = CreateFrame("Frame", nil, button, "BackdropTemplate")
    overlay:SetPoint("TOPLEFT", anchor, "TOPLEFT", -1, 1)
    overlay:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 1, -1)
    overlay:SetFrameLevel((button.GetFrameLevel and button:GetFrameLevel() or 1) + 5)
    overlay:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 18,
        insets = {
            left = 2,
            right = 2,
            top = 2,
            bottom = 2,
        },
    })
    overlay:SetBackdropBorderColor(0.0, 1.0, 0.2, 1.0)
    overlay:SetBackdropColor(0.0, 1.0, 0.2, 0.18)
    overlay:Hide()

    overlay.timeText = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    overlay.timeText:SetPoint("TOPLEFT", overlay, "TOPLEFT", 3, -3)
    overlay.timeText:SetTextColor(0.9, 1, 0.9)
    overlay.timeText:SetJustifyH("LEFT")

    function overlay:ClearState()
        self.expirationTime = nil
        self.timeText:SetText("")
        self:Hide()
    end

    function overlay:SetAura(aura)
        self.expirationTime = aura and aura.expirationTime or nil
        self:UpdateTimer()
    end

    function overlay:UpdateTimer()
        if not self.expirationTime then
            self:ClearState()
            return
        end

        local remainingSeconds = self.expirationTime - GetTime()
        if remainingSeconds <= 0 then
            self:ClearState()
            return
        end

        self.timeText:SetText(formatRemainingTime(remainingSeconds))
        self:Show()
    end

    return overlay
end

function Consumables:GetConsumableOverlay(button)
    if not self.inventoryConsumableOverlays then
        self.inventoryConsumableOverlays = {}
    end
    if not self.inventoryConsumableOverlays[button] then
        self.inventoryConsumableOverlays[button] = createConsumableOverlay(button)
    end
    return self.inventoryConsumableOverlays[button]
end

function Consumables:FindConsumableAuraForButton(button, auraBySpellID, auraByName, weaponEnchantStates)
    local _, _, itemID, itemLink = getContainerButtonItemInfo(button)
    if not itemID then return end

    local spellID, spellName = getItemSpellInfo(itemID, itemLink)
    if not spellID and not spellName then return end

    local aura = nil
    if spellID then
        aura = auraBySpellID[spellID]
    elseif spellName then
        aura = auraByName[spellName]
    end
    if aura and aura.expirationTime then
        return aura
    end

    local wellFedAura = findWellFedAura(auraByName)
    if wellFedAura and wellFedAura.expirationTime and isFoodItem(itemID) then
        return wellFedAura
    end

    if spellName and weaponEnchantStates then
        for _, weaponEnchantState in ipairs(weaponEnchantStates) do
            if tooltipDataContainsText(weaponEnchantState.tooltipData, spellName) then
                return {
                    expirationTime = weaponEnchantState.expirationTime,
                }
            end
        end
    end
end

local function enumerateShownContainerItemButtons(callback)
    if not ContainerFrameUtil_EnumerateContainerFrames then return end

    for _, containerFrame in ContainerFrameUtil_EnumerateContainerFrames() do
        if containerFrame and containerFrame.IsShown and containerFrame:IsShown() and containerFrame.EnumerateValidItems then
            for _, itemButton in containerFrame:EnumerateValidItems() do
                callback(itemButton, containerFrame)
            end
        end
    end
end

function Consumables:RefreshInventoryConsumableHighlights()
    if not self.db.profile.highlightActiveConsumablesInInventory then
        Consumables.ClearInventoryConsumableHighlights(self)
        return
    end
    if InCombatLockdown() then return end

    local auraBySpellID, auraByName = getHelpfulAuras()
    local weaponEnchantStates = buildWeaponEnchantTooltipCache()
    local activeButtons = {}

    enumerateShownContainerItemButtons(function(button)
        if button then
            local overlay = Consumables.GetConsumableOverlay(self, button)
            local aura = Consumables.FindConsumableAuraForButton(self, button, auraBySpellID, auraByName,
                weaponEnchantStates)

            if aura then
                overlay:SetAura(aura)
                activeButtons[button] = true
            else
                overlay:ClearState()
            end
        end
    end)

    if not self.inventoryConsumableOverlays then return end
    for button, overlay in pairs(self.inventoryConsumableOverlays) do
        if not activeButtons[button] then
            overlay:ClearState()
        end
    end
end

function Consumables:ClearInventoryConsumableHighlights()
    if not self.inventoryConsumableOverlays then return end
    for _, overlay in pairs(self.inventoryConsumableOverlays) do
        overlay:ClearState()
    end
end

function Consumables:StartInventoryConsumableTicker()
    if self.inventoryConsumableTicker then return end
    self.inventoryConsumableTicker = C_Timer.NewTicker(UPDATE_INTERVAL_SECONDS, function()
        if InCombatLockdown() then return end
        Consumables.RefreshInventoryConsumableHighlights(self)
        if not self.inventoryConsumableOverlays then return end
        for _, overlay in pairs(self.inventoryConsumableOverlays) do
            if overlay:IsShown() then
                overlay:UpdateTimer()
            end
        end
    end)
end

function Consumables:StopInventoryConsumableTicker()
    if not self.inventoryConsumableTicker then return end
    self.inventoryConsumableTicker:Cancel()
    self.inventoryConsumableTicker = nil
end

function Consumables:RequestInventoryConsumableRefresh(forceRescan)
    if not self.db.profile.highlightActiveConsumablesInInventory then return end
    if InCombatLockdown() then return end
    Consumables.RefreshInventoryConsumableHighlights(self)
end

function Consumables:ApplyInventoryConsumableHighlights()
    if self.db.profile.highlightActiveConsumablesInInventory then
        Consumables.StartInventoryConsumableTicker(self)
        Consumables.RequestInventoryConsumableRefresh(self, true)
    else
        Consumables.StopInventoryConsumableTicker(self)
        Consumables.ClearInventoryConsumableHighlights(self)
    end
end

return Consumables