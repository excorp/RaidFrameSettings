local _, addonTable = ...
local isVanilla, isWrath, isClassic, isRetail = addonTable.isVanilla, addonTable.isWrath, addonTable.isClassic, addonTable.isRetail
local RaidFrameSettings = addonTable.RaidFrameSettings

local module = RaidFrameSettings:NewModule("AuraHighlight")
Mixin(module, addonTable.hooks)
local Glow = addonTable.Glow
local LCD --LibCanDispel or custom defined in OnEnable
local LCG --libCustomGlow

local playerClass = select(2, UnitClass("player"))
local SetStatusBarColor = SetStatusBarColor
local UnitIsPlayer = UnitIsPlayer
local GetName = GetName
local match = match
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local pairs = pairs
local next = next
local AuraUtil_ForEachAura = AuraUtil.ForEachAura

local debuffColors = {
    Curse   = { r = 0.6, g = 0.0, b = 1.0, a = 1.0 },
    Disease = { r = 0.6, g = 0.4, b = 0.0, a = 1.0 },
    Magic   = { r = 0.2, g = 0.6, b = 1.0, a = 1.0 },
    Poison  = { r = 0.0, g = 0.6, b = 0.0, a = 1.0 },
    Bleed   = { r = 0.8, g = 0.0, b = 0.0, a = 1.0 },
}

local Bleeds = addonTable.Bleeds or {}
local auraMap = {}

local aura_missing_list = {}
local missingAuraColor = { r = 0.8156863451004028, g = 0.5803921818733215, b = 0.658823549747467 }

local blockColorUpdate = {}

local updateHealthColor

local useHealthBarColor
local useHealthBarGlow

local glowOpt = {
    type      = "Pixel",
    use_color = true,
    lines     = nil,
    frequency = nil,
    length    = nil,
    thickness = 3,
    XOffset   = nil,
    YOffset   = nil,
    border    = true,
}

local function toDebuffColor(frame, dispelName)
    blockColorUpdate[frame] = true
    if useHealthBarColor then
        frame.healthBar:SetStatusBarColor(debuffColors[dispelName].r, debuffColors[dispelName].g, debuffColors[dispelName].b, debuffColors[dispelName].a)
    end
    if useHealthBarGlow then
        module:Glow(frame, debuffColors[dispelName])
    end
end

local function updateColor(frame)
    for auraInstanceID, dispelName in next, auraMap[frame].debuffs do
        if auraInstanceID then
            toDebuffColor(frame, dispelName)
            return
        end
    end
    updateHealthColor(frame)
end

local function updateAurasFull(frame)
    if not frame.unit or not frame.unitExists then
        return
    end
    auraMap[frame] = {}
    auraMap[frame].debuffs = {}
    auraMap[frame].missing_list = {}

    if isClassic then
        for i = 1, 255 do
            local debuffName, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura, isBossAura = UnitDebuff(frame.displayedUnit, i)
            if not debuffName then
                break
            end
            local key = spellId .. "-" .. (unitCaster or "")
            if debuffType and LCD:CanDispel(debuffType) then
                auraMap[frame].debuffs[key] = debuffType
            end
            if Bleeds[spellId] and LCD:CanDispel("Bleed") then
                auraMap[frame].debuffs[key] = "Bleed"
            end
        end
        for i = 1, 255 do
            local buffName, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura, isBossAura = UnitBuff(frame.displayedUnit, i)
            if not buffName then
                break
            end
            local key = spellId .. "-" .. (unitCaster or "")
            if aura_missing_list[spellId] then
                auraMap[frame].missing_list[key] = spellId
            end
        end
    else
        local function HandleHarmAura(aura)
            if aura.dispelName and LCD:CanDispel(aura.dispelName) then
                auraMap[frame].debuffs[aura.auraInstanceID] = aura.dispelName
            end
            if Bleeds[aura.spellId] and LCD:CanDispel("Bleed") then
                auraMap[frame].debuffs[aura.auraInstanceID] = "Bleed"
            end
        end
        local function HandleHelpAura(aura)
            if aura_missing_list[aura.spellId] then
                auraMap[frame].missing_list[aura.auraInstanceID] = aura.spellId
            end
        end
        AuraUtil_ForEachAura(frame.unit, "HARMFUL", nil, HandleHarmAura, true)
        AuraUtil_ForEachAura(frame.unit, "HELPFUL", nil, HandleHelpAura, true)
    end
    updateColor(frame)
end

local function updateAurasIncremental(frame, updateInfo)
    if updateInfo.addedAuras then
        for _, aura in pairs(updateInfo.addedAuras) do
            if aura.isHarmful and aura.dispelName and LCD:CanDispel(aura.dispelName) then
                auraMap[frame].debuffs[aura.auraInstanceID] = aura.dispelName
            end
            if Bleeds[aura.spellId] and LCD:CanDispel("Bleed") then
                auraMap[frame].debuffs[aura.auraInstanceID] = "Bleed"
            end
            if aura_missing_list[aura.spellId] then
                auraMap[frame].missing_list[aura.auraInstanceID] = aura.spellId
            end
        end
    end
    if updateInfo.removedAuraInstanceIDs then
        for _, auraInstanceID in pairs(updateInfo.removedAuraInstanceIDs) do
            if auraMap[frame].debuffs[auraInstanceID] then
                auraMap[frame].debuffs[auraInstanceID] = nil
            end
            if auraMap[frame].missing_list[auraInstanceID] then
                auraMap[frame].missing_list[auraInstanceID] = nil
            end
        end
    end
    updateColor(frame)
end

function module:Glow(frame, rgb)
    local glow_frame = frame._rfs_glow_frame
    if not rgb then
        -- off
        if glow_frame and glow_frame.started then
            Glow:Stop(glowOpt, frame)
            glow_frame.started = false
        end
        return
    end

    local scale = frame:GetParent():GetScale() or 1
    if glow_frame and glow_frame.started then
        if glow_frame.color.r == rgb.r and glow_frame.color.g == rgb.g and glow_frame.color.b == rgb.b and glow_frame.scale == scale then
            return
        end
        -- off
        Glow:Stop(glowOpt, frame)
    end
    -- on
    glowOpt.color = rgb
    glowOpt.thickness = glowOpt.thickness and glowOpt.thickness * scale
    Glow:Start(glowOpt, frame)
    glow_frame = frame._rfs_glow_frame
    glow_frame.started = true
    glow_frame.color = rgb
    glow_frame.scale = scale
end

function module:HookFrame(frame)
    auraMap[frame] = {}
    auraMap[frame].debuffs = {}
    auraMap[frame].missing_list = {}
    --[[
        CompactUnitFrame_UnregisterEvents removes the event handler with frame:SetScript("OnEvent", nil) and thus the hook.
        Interface/FrameXML/CompactUnitFrame.lua
    ]]
    --
    self:RemoveHandler(frame, "OnEvent") --remove the registry key for frame["OnEvent"] so that it actually gets hooked again and not just stores a callback for an non existing hook
    self:HookScript(frame, "OnEvent", function(frame, event, unit, updateInfo)
        if event ~= "UNIT_AURA" or not RaidFrameSettings:IsModuleEnabled("AuraHighlight") then
            return
        end
        if isClassic or updateInfo.isFullUpdate then
            updateAurasFull(frame)
        else
            updateAurasIncremental(frame, updateInfo)
        end
    end)
    self:HookScript(frame, "OnShow", function(frame)
        updateAurasFull(frame)
    end)
    self:HookScript(frame, "OnHide", function(frame)
        blockColorUpdate[frame] = nil
    end)
end

function module:SetUpdateHealthColor()
    local function hasMissingAura(frame)
        if not UnitIsVisible(frame.unit) or next(aura_missing_list) == nil then
            return false
        end
        if not auraMap[frame] then
            return false
        end
        local reverse_missing_list = {}
        for _, spellId in next, auraMap[frame].missing_list do
            reverse_missing_list[spellId] = true
        end
        for spellId, name in next, aura_missing_list do
            if not reverse_missing_list[spellId] then
                return true
            end
        end
        return false
    end
    local r, g, b, a = 0, 1, 0, 1
    local useClassColors
    if RaidFrameSettings:IsModuleEnabled("HealthBars") then
        local selected = RaidFrameSettings.db.profile.HealthBars.Colors.statusbarmode
        if selected == 1 then
            useClassColors = true
        elseif selected == 2 then
            -- r,g,b,a = 0,1,0,1 -- r,g,b default = 0,1,0,1
        elseif selected == 3 then
            local color = RaidFrameSettings.db.profile.HealthBars.Colors.statusbar
            r, g, b, a = color.r, color.g, color.b, color.a
        end
    else
        if C_CVar.GetCVar("raidFramesDisplayClassColor") == "0" then
            -- r,g,b,a = 0,1,0,1 -- r,g,b default = 0,1,0,1
        else
            useClassColors = true
        end
    end

    updateHealthColor = function(frame)
        blockColorUpdate[frame] = false
        if hasMissingAura(frame) then
            if useHealthBarColor then
                frame.healthBar:SetStatusBarColor(missingAuraColor.r, missingAuraColor.g, missingAuraColor.b, missingAuraColor.a)
            end
            if useHealthBarGlow then
                module:Glow(frame, missingAuraColor)
            end
        else
            if useClassColors then
                local selected = RaidFrameSettings.db.profile.HealthBars.Colors.statusbarmode
                if selected == 2 then
                    r, g, b, a = 0, 1, 0, 1
                elseif selected == 3 then
                    local color = RaidFrameSettings.db.profile.HealthBars.Colors.statusbar
                    r, g, b, a = color.r, color.g, color.b, color.a
                end
                if frame.unit and frame.unitExists and not frame.unit:match("pet") then
                    local _, englishClass = UnitClass(frame.unit)
                    r, g, b = GetClassColor(englishClass)
                end
            end
            frame.healthBar:SetStatusBarColor(r, g, b, a)
            if useHealthBarGlow then
                module:Glow(frame, false)
            end
        end
    end
end

function module:GetDebuffColors()
    local dbObj = RaidFrameSettings.db.profile.MinorModules.DebuffColors
    debuffColors.Curse = dbObj.Curse
    debuffColors.Disease = dbObj.Disease
    debuffColors.Magic = dbObj.Magic
    debuffColors.Poison = dbObj.Poison
    debuffColors.Bleed = dbObj.Bleed
end

function module:OnEnable()
    self:SetUpdateHealthColor()
    local dbObj = RaidFrameSettings.db.profile.AuraHighlight
    useHealthBarColor = dbObj.Config.useHealthBarColor
    useHealthBarGlow = dbObj.Config.useHealthBarGlow
    aura_missing_list = dbObj.MissingAura[addonTable.playerClass].spellIDs
    missingAuraColor = dbObj.MissingAura.missingAuraColor
    if dbObj.Config.operation_mode == 1 then
        LCD = {}
        LCD = LibStub("LibCanDispel-1.0")
    else
        local shownDispelType = {
            ["Curse"] = dbObj.Config.Curse,
            ["Disease"] = dbObj.Config.Disease,
            ["Magic"] = dbObj.Config.Magic,
            ["Poison"] = dbObj.Config.Poison,
            ["Bleed"] = dbObj.Config.Bleed,
        }
        LCD = {}
        function LCD:CanDispel(dispelName)
            return shownDispelType[dispelName]
        end
    end
    self:GetDebuffColors()
    self:HookFunc("CompactUnitFrame_RegisterEvents", function(frame)
        if frame.unit:match("pet") or frame.unit:match("na") then --this will exclude nameplates and arena
            return
        end
        if not UnitIsPlayer(frame.unit) then --exclude pet/vehicle frame
            return
        end
        self:HookFrame(frame)
        updateAurasFull(frame)
    end)
    local onUpdateHealthColor = function(frame)
        if blockColorUpdate[frame] then
            updateColor(frame)
        else
            updateHealthColor(frame)
        end
    end

    self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        RaidFrameSettings:IterateRoster(function(frame)
            self:HookFrame(frame)
            updateAurasFull(frame)
        end)
    end)

    --[[
        CompactUnitFrame_UpdateHealthColor checks the current healthbar color value and restores it to the designated color if it differs from it.
        If this happens while the frame has a debuff color, we will need to update it again.
    ]]
    self:HookFuncFiltered("CompactUnitFrame_UpdateHealthColor", onUpdateHealthColor)

    RaidFrameSettings:IterateRoster(function(frame)
        self:HookFrame(frame)
        updateAurasFull(frame)
    end)
end

function module:OnDisable()
    self:DisableHooks()
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    RaidFrameSettings:IterateRoster(function(frame)
        if frame.unit and frame.unitExists and frame:IsVisible() and not frame:IsForbidden() then
            -- restore healthbar color
            local r, g, b, a = 0, 1, 0, 1
            if C_CVar.GetCVar("raidFramesDisplayClassColor") == "1" and frame.unit and frame.unitExists and not frame.unit:match("pet") then
                local _, englishClass = UnitClass(frame.unit)
                r, g, b = GetClassColor(englishClass)
            end
            frame.healthBar:SetStatusBarColor(r, g, b, a)
        end
        module:Glow(frame, false)
    end)
end
