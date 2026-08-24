local _, addonTable = ...
local ConsolePortBags = {}

if addonTable then
    addonTable.ConsolePortBags = ConsolePortBags
end

local function closeAllInventoryBags()
    CloseAllBags()
    return true
end

local function isContainerFrame(frame)
    return frame and frame.EnumerateValidItems and frame.GetBagID and frame.Items
end

local function isInventoryBagNode(node)
    local frame = node
    while frame do
        if isContainerFrame(frame) then return true end

        local parent = frame.GetParent and frame:GetParent()
        if parent == frame then return false end
        frame = parent
    end
    return false
end

function ConsolePortBags.Apply(addon)
    if not addon.db.profile.closeAllInventoryBagsWithConsolePortCancel then return false end
    if addon.consolePortBagCancelApplied then return true end

    local consolePort = _G.ConsolePort
    local data = consolePort and consolePort.GetData and consolePort:GetData()
    local cursor = data and data.Cursor
    local hooks = data and data.Hooks
    if not cursor or not hooks or not hooks.GetCancelClickHandler then return false end

    local originalGetCancelClickHandler = hooks.GetCancelClickHandler
    hooks.GetCancelClickHandler = function(self, node)
        if isInventoryBagNode(node) then
            return closeAllInventoryBags
        end
        return originalGetCancelClickHandler(self, node)
    end

    addon.consolePortBagCancelApplied = true

    local currentNode = cursor.GetCurrentNode and cursor:GetCurrentNode()
    if currentNode and cursor.SetCancelButtonForNode then
        cursor:SetCancelButtonForNode(currentNode)
    end

    return true
end

return ConsolePortBags
