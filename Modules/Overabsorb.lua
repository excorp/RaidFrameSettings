--[[
    Created by Slothpala
    Based on https://www.curseforge.com/wow/addons/derangement-shieldmeters.
--]]
local _, addonTable = ...
local RaidFrameSettings = addonTable.RaidFrameSettings

local Overabsorb = RaidFrameSettings:NewModule("Overabsorb")
Mixin(Overabsorb, addonTable.hooks)

local ClearAllPoints = ClearAllPoints
local SetPoint = SetPoint
local SetParent = SetParent
local SetAlpha = SetAlpha
local IsShown = IsShown
local SetWidth = SetWidth
local SetTexCoord = SetTexCoord
local Show = Show

local frame_registry = {}

function Overabsorb:OnEnable()
    local opt = RaidFrameSettings.db.profile.MinorModules.Overabsorb
    local function OnFrameSetup(frame)
        local fname = frame:GetName()
        if not fname or fname:match("Pet") then
            return
        end
        if not frame_registry[frame] then
            frame_registry[frame] = true
        end
        local absorbOverlay = frame.totalAbsorbOverlay
        local healthBar = frame.healthBar
        absorbOverlay:SetParent(healthBar)
        absorbOverlay:ClearAllPoints()
        local absorbGlow = frame.overAbsorbGlow
        if opt.position == 3 then
            absorbGlow:ClearAllPoints()
            absorbGlow:SetPoint("TOPLEFT", absorbOverlay, "TOPLEFT", -5, 0)
            absorbGlow:SetPoint("BOTTOMLEFT", absorbOverlay, "BOTTOMLEFT", -5, 0)
            absorbGlow:SetAlpha(opt.glowAlpha)
        end
    end
    self:HookFuncFiltered("DefaultCompactUnitFrameSetup", OnFrameSetup)
    local function UpdateHealPredictionCallback(frame)
        local fname = frame:GetName()
        if not fname or fname:match("Pet") then
            return
        end
        if not frame_registry[frame] then
            return
        end
        local absorbBar = frame.totalAbsorb
        local absorbOverlay = frame.totalAbsorbOverlay
        local healthBar = frame.healthBar
        local _, maxHealth = healthBar:GetMinMaxValues()
        local health = frame.healthBar:GetValue()
        if (maxHealth <= 0) then return end
        local totalAbsorb = UnitGetTotalAbsorbs(frame.displayedUnit or "") or 0
        if (totalAbsorb > maxHealth) then
            totalAbsorb = maxHealth
        end
        if (totalAbsorb > 0) then
            if (absorbBar:IsShown()) then
                absorbOverlay:SetPoint("TOPRIGHT", absorbBar, "TOPRIGHT", 0, 0)
                absorbOverlay:SetPoint("BOTTOMRIGHT", absorbBar, "BOTTOMRIGHT", 0, 0)
            else
                absorbOverlay:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", 0, 0)
                absorbOverlay:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 0, 0)
            end
            local width, height = healthBar:GetSize()
            local barSize = totalAbsorb / maxHealth * width
            absorbOverlay:SetWidth(barSize)
            absorbOverlay:SetTexCoord(0, barSize / absorbOverlay.tileSize, 0, height / absorbOverlay.tileSize)
            absorbOverlay:Show()

            local overflow = health + totalAbsorb - maxHealth
            if opt.position == 2 and overflow > 0 then
                local absorbGlow = frame.overAbsorbGlow
                barSize = overflow / maxHealth * width
                absorbGlow:ClearAllPoints()
                absorbGlow:SetPoint("BOTTOMLEFT", frame.healthBar, "BOTTOMRIGHT", -7 - barSize, 0)
                absorbGlow:SetPoint("TOPLEFT", frame.healthBar, "TOPRIGHT", -7 - barSize, 0)
            end
        end
    end
    self:HookFuncFiltered("CompactUnitFrame_UpdateHealPrediction", UpdateHealPredictionCallback)
    RaidFrameSettings:IterateRoster(function(frame)
        OnFrameSetup(frame)
        UpdateHealPredictionCallback(frame)
    end)
end

function Overabsorb:OnDisable()
    self:DisableHooks()
    local restoreOverabsorbs = function(frame)
        frame.overAbsorbGlow:SetPoint("BOTTOMLEFT", frame.healthBar, "BOTTOMRIGHT", -7, 0)
        frame.overAbsorbGlow:SetPoint("TOPLEFT", frame.healthBar, "TOPRIGHT", -7, 0)
        frame.overAbsorbGlow:SetAlpha(1)
    end
    for frame in pairs(frame_registry) do
        restoreOverabsorbs(frame)
        frame_registry[frame] = nil
    end
end
