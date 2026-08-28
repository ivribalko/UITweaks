local addonName, addonTable = ...
local AggroRadius = {}
local applied
local addonInstance

if addonTable then
    addonTable.AggroRadius = AggroRadius
end

local BASE_AGGRO_RADIUS_YARDS = 20
local MIN_AGGRO_RADIUS_YARDS = 5
local MAX_AGGRO_RADIUS_YARDS = 45
local HOSTILE_RANGE_ITEMS = {
    { itemID = 37727, range = 5 },
    { itemID = 63427, range = 6 },
    { itemID = 34368, range = 8 },
    { itemID = 32321, range = 10 },
    { itemID = 33069, range = 15 },
    { itemID = 10645, range = 20 },
    { itemID = 24268, range = 25 },
    { itemID = 835, range = 30 },
    { itemID = 24269, range = 35 },
    { itemID = 28767, range = 40 },
    { itemID = 23836, range = 45 },
    { itemID = 116139, range = 50 },
    { itemID = 32825, range = 60 },
    { itemID = 41265, range = 70 },
    { itemID = 35278, range = 80 },
    { itemID = 33119, range = 100 },
}

local function getUnitLevel(unit)
    local level = UnitEffectiveLevel and UnitEffectiveLevel(unit) or UnitLevel(unit)
    if canaccessvalue and not canaccessvalue(level) then return end
    if type(level) ~= "number" or level <= 0 then return end
    return level
end

local function getMouseoverAggroRadius()
    if not UnitExists("mouseover")
        or UnitIsPlayer("mouseover")
        or UnitPlayerControlled("mouseover")
        or UnitIsDeadOrGhost("mouseover")
        or not UnitCanAttack("player", "mouseover")
    then
        return
    end

    local reaction = UnitReaction("player", "mouseover")
    if not reaction or reaction > 3 then return end

    local playerLevel = getUnitLevel("player")
    if not playerLevel then return end

    -- Skull-level bosses report level -1 but count as three levels above the player.
    local mobLevel = getUnitLevel("mouseover") or (playerLevel + 3)

    local radius = BASE_AGGRO_RADIUS_YARDS + mobLevel - playerLevel
    return math.max(MIN_AGGRO_RADIUS_YARDS, math.min(MAX_AGGRO_RADIUS_YARDS, radius))
end

local function getMouseoverDistanceRange()
    if not C_Item or not C_Item.IsItemInRange then return end

    local previousRange
    for _, rangeItem in ipairs(HOSTILE_RANGE_ITEMS) do
        if not C_Item.GetItemInfo or C_Item.GetItemInfo(rangeItem.itemID) then
            local inRange = C_Item.IsItemInRange(rangeItem.itemID, "mouseover")
            if canaccessvalue and not canaccessvalue(inRange) then return end
            if inRange ~= nil then
                if inRange then
                    if previousRange then
                        return previousRange, rangeItem.range
                    end
                    return 0, rangeItem.range
                end
                previousRange = rangeItem.range
            end
        end
    end

    if previousRange then return previousRange end
end

local function getAggroDistanceText(radius)
    local minDistance, maxDistance = getMouseoverDistanceRange()
    if not minDistance then return end

    local minUntilAggro = math.max(0, minDistance - radius)
    if not maxDistance then return (">%d"):format(minUntilAggro) end

    local maxUntilAggro = math.max(0, maxDistance - radius)
    if minUntilAggro == maxUntilAggro then return tostring(minUntilAggro) end
    return ("%d-%d"):format(minUntilAggro, maxUntilAggro)
end

local function addMouseoverAggroRadius(tooltip)
    if tooltip ~= GameTooltip
        or not addonInstance.db.profile.showMobAggroRadiusOnMouseOverOutOfCombat
        or UnitAffectingCombat("player")
    then
        return
    end

    local radius = getMouseoverAggroRadius()
    if not radius then return end

    local aggroDistanceText = getAggroDistanceText(radius)
    if not aggroDistanceText then return end

    local text = ("Aggro in: %s yd"):format(aggroDistanceText)
    tooltip:AddLine(text, 1, 0.82, 0)
end

function AggroRadius.Apply(addon)
    addonInstance = addon
    if applied
        or not TooltipDataProcessor
        or not Enum
        or not Enum.TooltipDataType
        or not Enum.TooltipDataType.Unit
    then
        return
    end

    if C_Item and C_Item.RequestLoadItemDataByID then
        for _, rangeItem in ipairs(HOSTILE_RANGE_ITEMS) do
            C_Item.RequestLoadItemDataByID(rangeItem.itemID)
        end
    end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, addMouseoverAggroRadius)
    applied = true
end

return AggroRadius
