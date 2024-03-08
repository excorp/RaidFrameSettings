local _, addonTable = ...
local isVanilla, isWrath, isClassic, isRetail = addonTable.isVanilla, addonTable.isWrath, addonTable.isClassic, addonTable.isRetail
local addon = addonTable.RaidFrameSettings
local AuraFilter = addon:NewModule("AuraFilter")
Mixin(AuraFilter, addonTable.hooks)

local module_enabled
local filteredAuras = {}

local org_SpellGetVisibilityInfo = SpellGetVisibilityInfo
SpellGetVisibilityInfo = function(spellId, visType)
    if module_enabled then
        if filteredAuras[spellId] then
            if filteredAuras[spellId].show then
                -- show
                if filteredAuras[spellId].hideInCombat and visType == "RAID_INCOMBAT" then
                    return true, false, false
                end
                if filteredAuras[spellId].debuff then
                    return false
                end
                if filteredAuras[spellId].other then
                    return true, false, true
                end
                return true, true, false
            else
                -- hide
                return true, false, false
            end
        end
    end
    return org_SpellGetVisibilityInfo(spellId, visType)
end

function AuraFilter:SetSpellGetVisibilityInfo(enabled)
    module_enabled = enabled
    -- Trigger an event to initialize the local value of cachedVisualizationInfo in AuraUtil
    -- Only use the PLAYER_REGEN_ENABLED event because the module is only enabled/disabled when not in combat
    if not isClassic then
        EventRegistry:TriggerEvent("PLAYER_REGEN_ENABLED")
    end
end

function AuraFilter:OnEnable()
    --aura filter
    for k in pairs(filteredAuras) do
        filteredAuras[k] = nil
    end
    for spellId, value in pairs(addon.db.profile.AuraFilter.Buffs) do
        value.debuff = false
        filteredAuras[tonumber(spellId)] = value
    end
    for spellId, value in pairs(addon.db.profile.AuraFilter.Debuffs) do
        value.debuff = true
        filteredAuras[tonumber(spellId)] = value
    end
    self:SetSpellGetVisibilityInfo(true)
    if addon.db.profile.Module.Buffs then
        addon:UpdateModule("Buffs")
    elseif addon.db.profile.Module.Debuffs then
        addon:UpdateModule("Debuffs")
    else
        addon:IterateRoster(function(frame)
            if frame.unit and frame.unitExists and frame:IsShown() and not frame:IsForbidden() then
                CompactUnitFrame_UpdateAuras(frame)
            end
        end)
    end
end

function AuraFilter:OnDisable()
    self:SetSpellGetVisibilityInfo(false)
    if addon.db.profile.Module.Buffs then
        addon:UpdateModule("Buffs")
    elseif addon.db.profile.Module.Debuffs then
        addon:UpdateModule("Debuffs")
    else
        addon:IterateRoster(function(frame)
            if frame.unit and frame.unitExists and frame:IsShown() and not frame:IsForbidden() then
                CompactUnitFrame_UpdateAuras(frame)
            end
        end)
    end
end
