local _, addonTable = ...
local addon = addonTable.RaidFrameSettings
local RaidMark = addon:NewModule("RaidMark")
Mixin(RaidMark, addonTable.hooks)

function RaidMark:UpdateRaidMarker(frame)
    if not frame.raidmark or not frame.unit or frame.unit:match("na") then
        return
    end

    if not addon.db.profile.Module.RaidMark then
        frame.raidmark:Hide()
        return
    end

    local index = GetRaidTargetIndex(frame.unit)
    if index and index >= 1 and index <= 8 then
        local texture = UnitPopupRaidTarget1ButtonMixin:GetIcon() or "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
        local coords = _G["UnitPopupRaidTarget" .. index .. "ButtonMixin"]:GetTextureCoords()
        frame.raidmark:Show()
        frame.raidmark:SetTexture(texture, nil, nil, "TRILINEAR")
        frame.raidmark:SetTexCoord(coords.tCoordLeft, coords.tCoordRight, coords.tCoordTop, coords.tCoordBottom)
    else
        frame.raidmark:Hide()
    end
end

function RaidMark:UpdateAllRaidmark()
    addon:IterateRoster(function(frame)
        RaidMark:UpdateRaidMarker(frame)
    end)
end

function RaidMark:OnEnable()
    local raidmarkOpt = CopyTable(addon.db.profile.MinorModules.RaidMark)
    raidmarkOpt.point = addon:ConvertDbNumberToPosition(raidmarkOpt.point)
    raidmarkOpt.relativePoint = addon:ConvertDbNumberToPosition(raidmarkOpt.relativePoint)

    local function initRaidMark(frame, force)
        local fname = frame:GetName()
        if not fname or fname:match("pet") then
            return
        end
        if not frame.raidmark then
            frame.raidmark = frame:CreateTexture(nil, "OVERLAY")
            force = true
        end
        if force then
            frame.raidmark:Hide()
            frame.raidmark:ClearAllPoints()
            local parent = raidmarkOpt.frame == 2 and frame.roleIcon or frame
            frame.raidmark:SetPoint(raidmarkOpt.point, parent, raidmarkOpt.relativePoint, raidmarkOpt.x_offset, raidmarkOpt.y_offset)
            frame.raidmark:SetSize(raidmarkOpt.width, raidmarkOpt.height)
            frame.raidmark:SetAlpha(raidmarkOpt.alpha)
        end
    end
    self:HookFuncFiltered("DefaultCompactUnitFrameSetup", initRaidMark)

    addon:IterateRoster(function(frame)
        initRaidMark(frame, true)
    end)
    self:UpdateAllRaidmark()

    self:RegisterEvent("RAID_TARGET_UPDATE", function()
        self:UpdateAllRaidmark()
    end)
end

function RaidMark:OnDisable()
    self:UnregisterEvent("RAID_TARGET_UPDATE")
    self:UpdateAllRaidmark()
end
