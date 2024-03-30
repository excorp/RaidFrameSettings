local _, addonTable = ...
local isVanilla, isWrath, isClassic, isRetail = addonTable.isVanilla, addonTable.isWrath, addonTable.isClassic, addonTable.isRetail
local addon = addonTable.RaidFrameSettings
local AuraFilter = addon:NewModule("AuraFilter")
Mixin(AuraFilter, addonTable.hooks)

local module_enabled
local filteredAuras = {}

addon.filteredAuras = filteredAuras

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

local function setFilter(spellId)
    if not filteredAuras[spellId] or filteredAuras[spellId].show == false then
        filteredAuras[spellId] = {
            spellId = spellId,
            show = true,
            other = false,
            hideInCombat = false,
            priority = 0,
            glow = false,
            alpha = 1,
        }
    end
end

function AuraFilter:reloadConf()
    --aura filter
    for k in pairs(filteredAuras) do
        filteredAuras[k] = nil
    end
    for spellId, value in pairs(addon.db.profile.AuraFilter.default.Buffs) do
        value.debuff = false
        filteredAuras[tonumber(spellId)] = filteredAuras[tonumber(spellId)] or value
    end
    for spellId, value in pairs(addon.db.profile.AuraFilter.default.Debuffs) do
        value.debuff = true
        filteredAuras[tonumber(spellId)] = filteredAuras[tonumber(spellId)] or value
    end

    for _, groupInfo in pairs(addon.db.profile.AuraFilter.FilterGroup.Buffs) do
        for spellId, value in pairs(groupInfo.auraList) do
            value.debuff = false
            filteredAuras[tonumber(spellId)] = filteredAuras[tonumber(spellId)] or value
        end
    end
    for _, groupInfo in pairs(addon.db.profile.AuraFilter.FilterGroup.Buffs) do
        for spellId, value in pairs(groupInfo.auraList) do
            value.debuff = false
            filteredAuras[tonumber(spellId)] = filteredAuras[tonumber(spellId)] or value
        end
    end

    if addon:IsModuleEnabled("Buffs") then
        --increase
        for spellId in pairs(addon.db.profile.Buffs.Increase) do
            setFilter(spellId)
        end
        --user placed
        for _, auraInfo in pairs(addon.db.profile.Buffs.AuraPosition) do
            setFilter(auraInfo.spellId)
        end
        --aura group
        for k, auraInfo in pairs(addon.db.profile.Buffs.AuraGroup) do
            for aura, v in pairs(auraInfo.auraList) do
                setFilter(tonumber(aura))
            end
        end
    end

    if addon:IsModuleEnabled("Debuffs") then
        --increase
        for spellId in pairs(addon.db.profile.Debuffs.Increase) do
            setFilter(spellId)
        end
        --user placed
        for _, auraInfo in pairs(addon.db.profile.Debuffs.AuraPosition) do
            setFilter(auraInfo.spellId)
        end
        --aura group
        for k, auraInfo in pairs(addon.db.profile.Debuffs.AuraGroup) do
            for aura, v in pairs(auraInfo.auraList) do
                -- tonumber(aura)
                setFilter(tonumber(aura))
            end
        end
    end

    AuraFilter:SetSpellGetVisibilityInfo(module_enabled)
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
    self:reloadConf()
    self:SetSpellGetVisibilityInfo(true)
    addon:IterateRoster(function(frame)
        if frame.unit and frame.unitExists and frame:IsShown() and not frame:IsForbidden() then
            CompactUnitFrame_UpdateAuras(frame)
        end
    end)
end

function AuraFilter:OnDisable()
    self:SetSpellGetVisibilityInfo(false)
    addon:IterateRoster(function(frame)
        if frame.unit and frame.unitExists and frame:IsShown() and not frame:IsForbidden() then
            CompactUnitFrame_UpdateAuras(frame)
        end
    end)
end
