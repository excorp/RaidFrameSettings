--[[
    Created by Slothpala
    position 1,2,3,4 = {"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"},
--]]
local _, addonTable = ...
local RaidFrameSettings = addonTable.RaidFrameSettings
local RoleIcon = RaidFrameSettings:NewModule("RoleIcon")
Mixin(RoleIcon, addonTable.hooks)

local ClearAllPoints = ClearAllPoints
local SetPoint = SetPoint
local SetScale = SetScale

local frame_registry = {}

function RoleIcon:OnEnable()
    local x, y, relativePoint
    local x_offset, y_offset = RaidFrameSettings.db.profile.MinorModules.RoleIcon.x_offset, RaidFrameSettings.db.profile.MinorModules.RoleIcon.y_offset
    local position = RaidFrameSettings.db.profile.MinorModules.RoleIcon.position
    local scaleFactor = RaidFrameSettings.db.profile.MinorModules.RoleIcon.scaleFactor
    if position == 1 then
        x = 4
        y = -4
        relativePoint = "TOPLEFT"
    elseif position == 2 then
        x = -4
        y = -4
        relativePoint = "TOPRIGHT"
    elseif position == 3 then
        x = 4
        y = 4
        relativePoint = "BOTTOMLEFT"
    elseif position == 4 then
        x = -4
        y = 4
        relativePoint = "BOTTOMRIGHT"
    end
    local updatePosition = function(frame)
        if not frame.roleIcon then
            return
        end
        local fname = frame:GetName()
        if not fname or fname:match("Pet") then
            return
        end
        if not frame_registry[frame] then
            frame_registry[frame] = true
        end
        frame.roleIcon:ClearAllPoints()
        frame.roleIcon:SetPoint(relativePoint, frame, relativePoint, x + x_offset, y + y_offset)
        frame.roleIcon:SetScale(scaleFactor)
    end
    self:HookFunc("CompactUnitFrame_UpdateRoleIcon", updatePosition)
    RaidFrameSettings:IterateRoster(updatePosition)
end

function RoleIcon:OnDisable()
    self:DisableHooks()
    local restoreRoleIcon = function(frame)
        frame.roleIcon:ClearAllPoints()
        frame.roleIcon:SetPoint("TOPLEFT", 3, -2)
        if frame.roleIcon:IsShown() then
            frame.roleIcon:SetSize(12, 12)
        end
        frame.roleIcon:SetScale(1)
    end
    for frame in pairs(frame_registry) do
        restoreRoleIcon(frame)
        frame_registry[frame] = nil
    end
end
