local addonName, addonTable = ...
local ConsolePortItemMenu = {}

-- Weapon oils supported by retail WoW, including older oils that remain usable.
local WEAPON_OIL_ITEM_IDS = {
    [3824] = true,   -- Shadow Oil
    [3829] = true,   -- Frost Oil
    [20744] = true,  -- Minor Wizard Oil
    [20745] = true,  -- Minor Mana Oil
    [20746] = true,  -- Lesser Wizard Oil
    [20747] = true,  -- Lesser Mana Oil
    [20748] = true,  -- Brilliant Mana Oil
    [20749] = true,  -- Brilliant Wizard Oil
    [22521] = true,  -- Superior Mana Oil
    [22522] = true,  -- Superior Wizard Oil
    [23123] = true,  -- Blessed Wizard Oil
    [171285] = true, -- Shadowcore Oil
    [171286] = true, -- Embalmer's Oil
    [224105] = true, -- Algari Mana Oil
    [224108] = true, -- Oil of Beledar's Grace
    [224113] = true, -- Oil of Deep Toxins
    [243733] = true, -- Thalassian Phoenix Oil, quality 1
    [243734] = true, -- Thalassian Phoenix Oil, quality 2
    [243735] = true, -- Oil of Dawn, quality 1
    [243736] = true, -- Oil of Dawn, quality 2
}

if addonTable then
    addonTable.ConsolePortItemMenu = ConsolePortItemMenu
end

local function addMainHandOilCommand(addon, itemMenu)
    if not addon.db.profile.addOilToMainHandConsolePortShortcut then return end
    if not WEAPON_OIL_ITEM_IDS[itemMenu:GetItemID()] then return end

    local bagID, slotID = itemMenu:GetBagAndSlot()
    itemMenu:AddCommand(
        "Apply to Main-Hand Weapon",
        "UITweaksApplyOilToMainHand",
        nil,
        nil,
        function(button)
            button:SetAttribute(CPAPI.ActionTypeRelease, "macro")
            button:SetAttribute(CPAPI.ActionPressAndHold, true)
            button:SetAttribute("macrotext", ("/use %d %d\n/use 16"):format(bagID, slotID))
        end
    )

    local commandCount = itemMenu:GetNumActive()
    local oilCommand = itemMenu.Registry[commandCount]
    for index = commandCount, 2, -1 do
        itemMenu.Registry[index] = itemMenu.Registry[index - 1]
    end
    itemMenu.Registry[1] = oilCommand

    for index = 1, commandCount do
        local button = itemMenu.Registry[index]
        local previousButton = itemMenu.Registry[index - 1]
        button:ClearAllPoints()
        button:SetPoint(
            "TOPLEFT",
            previousButton or itemMenu.Tooltip,
            "BOTTOMLEFT",
            previousButton and 0 or itemMenu.buttonOffsetX,
            previousButton and 1 or -16
        )
    end
end

function ConsolePortItemMenu.Apply(addon)
    if not addon.db.profile.addOilToMainHandConsolePortShortcut then return false end

    local itemMenu = _G.ConsolePortItemMenu
    if not itemMenu or not itemMenu.SetCommands or not itemMenu.AddCommand then return false end

    if not itemMenu.UITweaksOilShortcutHooked then
        itemMenu.UITweaksOilShortcutHooked = true
        itemMenu.UITweaksApplyOilToMainHand = function(menu)
            menu:Hide()
        end
        hooksecurefunc(itemMenu, "SetCommands", function(menu)
            addMainHandOilCommand(addon, menu)
        end)
    end

    if itemMenu:IsShown() then
        itemMenu:SetCommands()
        itemMenu:FixHeight()
    end
    return true
end

return ConsolePortItemMenu
