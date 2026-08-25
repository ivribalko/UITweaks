local addonName, addonTable = ...
local ConsolePortMovement = {}
local applied

if addonTable then
    addonTable.ConsolePortMovement = ConsolePortMovement
end

local function ignoreSpellCastCameraOverride()
end

function ConsolePortMovement.Apply(addon)
    if applied or not addon.db.profile.respectConsolePortCameraSettingWhileCasting then return end
    if not ConsolePort or not ConsolePort.GetData then return end

    local movement = ConsolePort:GetData().Movement
    if not movement then return end

    if movement.fmSpellOverride ~= nil then
        movement:UpdateTurnWithCamera(movement.fmSpellOverride)
        movement.fmSpellOverride = nil
    end

    movement.UNIT_SPELLCAST_START = ignoreSpellCastCameraOverride
    movement.UNIT_SPELLCAST_STOP = ignoreSpellCastCameraOverride
    movement.UNIT_SPELLCAST_CHANNEL_START = ignoreSpellCastCameraOverride
    movement.UNIT_SPELLCAST_CHANNEL_STOP = ignoreSpellCastCameraOverride
    movement.UNIT_SPELLCAST_EMPOWER_START = ignoreSpellCastCameraOverride
    movement.UNIT_SPELLCAST_EMPOWER_STOP = ignoreSpellCastCameraOverride
    applied = true
end

return ConsolePortMovement
