--[[
    Created by Slothpala
    i will rename this to StatusBars.lua at some point.
--]]
local _, addonTable = ...
local RaidFrameSettings = addonTable.RaidFrameSettings

local HealthBars = RaidFrameSettings:NewModule("HealthBars")
Mixin(HealthBars, addonTable.hooks)
local Media = LibStub("LibSharedMedia-3.0")

--wow api speed reference
local UnitIsConnected = UnitIsConnected
local UnitIsDead = UnitIsDead
local UnitIsTapDenied = UnitIsTapDenied
local UnitInVehicle = UnitInVehicle
local GetStatusBarTexture = GetStatusBarTexture
local SetStatusBarTexture = SetStatusBarTexture
local SetStatusBarColor = SetStatusBarColor
local SetTexture = SetTexture
local SetVertexColor = SetVertexColor
local SetPoint = SetPoint
local SetBackdrop = SetBackdrop
local ApplyBackdrop = ApplyBackdrop
local SetBackdropBorderColor = SetBackdropBorderColor

local frame_registry = {}
local needUpdate = {}
local timer

function HealthBars:OnEnable()
    --textures
    local backdropInfo      = {
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile     = false,
        tileEdge = true,
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    }
    local statusBarTexture  = Media:Fetch("statusbar", RaidFrameSettings.db.profile.HealthBars.Textures.statusbar)
    local backgroundTexture = Media:Fetch("statusbar", RaidFrameSettings.db.profile.HealthBars.Textures.background)
    local powerBarTexture   = Media:Fetch("statusbar", RaidFrameSettings.db.profile.HealthBars.Textures.powerbar)
    local backgroundColor   = CopyTable(RaidFrameSettings.db.profile.HealthBars.Colors.background)
    local borderColor       = CopyTable(RaidFrameSettings.db.profile.HealthBars.Colors.border)


    --callbacks
    --only apply the power bar texture if the power bar is shown
    local raidFramesDisplayPowerBars = C_CVar.GetCVar("raidFramesDisplayPowerBars") == "1" and true or false
    --with powerbar
    local updateReal = function(frame1)
        local target
        if frame1 then
            target = {
                [frame1] = true,
            }
        else
            target = needUpdate
            timer = nil
        end
        for frame in pairs(target) do
            target[frame] = nil
            if not frame_registry[frame] then
                frame_registry[frame] = {

                }
            end
            -- 텍스쳐가 동일하면 무시한다
            if frame_registry[frame].texture == frame.background:GetTexture(backgroundTexture) then
                return
            end

            if frame.unit and frame.unit:match("pet") then
                for _, border in pairs({
                    "horizTopBorder",
                    "horizBottomBorder",
                    "vertLeftBorder",
                    "vertRightBorder",
                }) do
                    if frame[border] then
                        frame[border]:SetAlpha(0)
                    end
                end
            end

            frame.healthBar:SetStatusBarTexture(statusBarTexture)
            frame.healthBar:GetStatusBarTexture():SetDrawLayer("BORDER")
            frame.background:SetTexture(backgroundTexture)
            frame_registry[frame].texture = frame.background:GetTexture(backgroundTexture)
            frame.background:SetVertexColor(backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundColor.a)
            if raidFramesDisplayPowerBars then
                frame.powerBar:SetStatusBarTexture(powerBarTexture)
                frame.powerBar.background:SetPoint("TOPLEFT", frame.healthBar, "BOTTOMLEFT", 0, 1)
                frame.powerBar.background:SetPoint("BOTTOMRIGHT", frame.background, "BOTTOMRIGHT", 0, 0)
            end
            if not frame.backdropInfo then
                Mixin(frame, BackdropTemplateMixin)
                frame:SetBackdrop(backdropInfo)
            end
            frame:ApplyBackdrop()
            frame:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
        end
    end
    local updateTextures = function(frame)
        updateReal(frame)
        needUpdate[frame] = true
        if not timer or timer:IsCancelled() then
            timer = C_Timer.NewTimer(0, function() updateReal() end)
        end
    end
    self:HookFuncFiltered("DefaultCompactUnitFrameSetup", updateTextures)
    --[[
    self:HookFunc("DefaultCompactMiniFrameSetup", function(frame)
        for _, border in pairs({
            "horizTopBorder",
            "horizBottomBorder",
            "vertLeftBorder",
            "vertRightBorder",
        }) do
            if frame[border] then
                frame[border]:SetAlpha(0)
            end
        end
        updateTextures(frame)
    end)
    ]]
    --colors
    local r, g, b, a = 0, 1, 0, 1
    local useClassColors
    local updateHealthColor = function(frame)
        if RaidFrameSettings:IsModuleEnabled("AuraHighlight") then
            return
        end
        if useClassColors then
            local selected = RaidFrameSettings.db.profile.HealthBars.Colors.statusbarmode
            r, g, b, a = 0, 1, 0, 1
            if selected == 3 then
                local color = RaidFrameSettings.db.profile.HealthBars.Colors.statusbar
                r, g, b, a = color.r, color.g, color.b, color.a
            end
            if frame.unit and frame.unitExists and not frame.unit:match("pet") then
                local _, englishClass = UnitClass(frame.unit)
                r, g, b = GetClassColor(englishClass)
            end
        end
        frame.healthBar:SetStatusBarColor(r, g, b, a)
    end

    if RaidFrameSettings:IsModuleEnabled("HealthBars") then
        local selected = RaidFrameSettings.db.profile.HealthBars.Colors.statusbarmode
        if selected == 1 then
            useClassColors = true
            if C_CVar.GetCVar("raidFramesDisplayClassColor") == "0" then
                C_CVar.SetCVar("raidFramesDisplayClassColor", "1")
            end
        elseif selected == 2 then
            -- r,g,b,a = 0,1,0,1 -- r,g,b,a default = 0,1,0,1
            if C_CVar.GetCVar("raidFramesDisplayClassColor") == "1" then
                C_CVar.SetCVar("raidFramesDisplayClassColor", "0")
            end
        elseif selected == 3 then
            local color = RaidFrameSettings.db.profile.HealthBars.Colors.statusbar
            r, g, b, a = color.r, color.g, color.b, color.a
            self:HookFuncFiltered("CompactUnitFrame_UpdateHealthColor", updateHealthColor)
        end
    else
        if C_CVar.GetCVar("raidFramesDisplayClassColor") == "0" then
            -- r,g,b,a = 0,1,0,1 -- r,g,b,a default = 0,1,0,1
        else
            useClassColors = true
        end
    end

    if RaidFrameSettings:IsModuleEnabled("AuraHighlight") then
        RaidFrameSettings:UpdateModule("AuraHighlight")
    end

    self:HookFunc("CompactUnitFrame_SetUnit", function(frame, unit)
        if not unit or unit:match("nameplate") then
            return
        end
        updateTextures(frame)
        updateHealthColor(frame)
    end)

    --[[
    self:RegisterEvent("UNIT_PET", function(event, unit)
        for frame in pairs(frame_registry) do
            if frame.unit == unit then
                updateTextures(frame)
                updateHealthColor(frame)
            end
        end
    end)
    ]]

    RaidFrameSettings:IterateRoster(function(frame)
        C_Timer.After(0, function()
            updateTextures(frame)
            updateHealthColor(frame)
        end)
    end)
end

function HealthBars:OnDisable()
    self:DisableHooks()
    -- self:UnregisterEvent("UNIT_PET")
    if timer and not timer:IsCancelled() then
        timer:Cancel()
    end
    timer = nil
    needUpdate = {}
    local restoreStatusBars = function(frame)
        frame.healthBar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
        frame.healthBar:GetStatusBarTexture():SetDrawLayer("BORDER")
        frame.background:SetTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Bg")
        frame.background:SetTexCoord(0, 1, 0, 0.53125)
        frame.powerBar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Resource-Fill")
        frame.powerBar:GetStatusBarTexture():SetDrawLayer("BORDER")
        if frame.backdropInfo then
            frame:ClearBackdrop()
        end
        if not RaidFrameSettings:IsModuleEnabled("AuraHighlight") and frame.unit and frame.unitExists and frame:IsVisible() and not frame:IsForbidden() then
            -- restore healthbar color
            local r, g, b, a = 0, 1, 0, 1
            if C_CVar.GetCVar("raidFramesDisplayClassColor") == "1" and frame.unit and frame.unitExists and not frame.unit:match("pet") then
                local _, englishClass = UnitClass(frame.unit)
                r, g, b = GetClassColor(englishClass)
            end
            frame.healthBar:SetStatusBarColor(r, g, b, a)
        end
    end
    for frame in pairs(frame_registry) do
        restoreStatusBars(frame)
        frame_registry[frame] = nil
    end
end
