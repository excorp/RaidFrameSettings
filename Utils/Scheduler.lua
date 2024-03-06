local _, addonTable = ...
local addon = addonTable.RaidFrameSettings

local eventFrame = nil
local combatEndCallbacks = {}
local combatEndKeyedCallbacks = {}

local function OnCombatEnded()
    for _, callback in ipairs(combatEndCallbacks) do
        callback()
    end

    for _, callback in pairs(combatEndKeyedCallbacks) do
        callback()
    end

    combatEndCallbacks = wipe(combatEndCallbacks)
    combatEndKeyedCallbacks = wipe(combatEndKeyedCallbacks)
end

function addon:RunWhenCombatEnds(callback, key)
    if not InCombatLockdown() then
        callback()
        return
    end

    if key then
        combatEndKeyedCallbacks[key] = callback
    else
        combatEndCallbacks[#combatEndCallbacks + 1] = callback
    end
end

addon:RegisterEvent("PLAYER_REGEN_ENABLED", OnCombatEnded)
