local _, addonTable = ...
local addon = addonTable.RaidFrameSettings

local _G = _G
local GetParent = GetParent
local IsInRaid = IsInRaid
local IsActiveBattlefieldArena = IsActiveBattlefieldArena
local next = next

local Roster = {}
local needsUpdate = true

local function showSeparateGroups()
    local showSeparateGroups
    if addonTable.isClassic then
        showSeparateGroups = CompactRaidFrameManager_GetSetting("KeepGroupsTogether")
    else
        showSeparateGroups = EditModeManagerFrame:ShouldRaidFrameShowSeparateGroups()
    end
    return showSeparateGroups
end

local function updateRoster()
    Roster = {}
    local useRaid = (IsInRaid() and not select(1, IsActiveBattlefieldArena())) or addonTable.isWrath --IsInRaid() returns true in arena even though we need party frame names
    if useRaid then
        if showSeparateGroups() then
            for i = 1, 8 do
                for j = 1, 5 do
                    local frame = _G["CompactRaidGroup" .. i .. "Member" .. j .. "HealthBar"]
                    if frame then
                        frame = frame:GetParent()
                        if frame.unit then
                            tinsert(Roster, frame)
                        end
                    end
                end
            end
            for i = 1, 40 do
                local frame = _G["CompactRaidFrame" .. i .. "HealthBar"]
                if frame then
                    frame = frame:GetParent()
                    if frame.unit then
                        tinsert(Roster, frame)
                    end
                end
            end
        else
            for i = 1, 80 do
                local frame = _G["CompactRaidFrame" .. i .. "HealthBar"]
                if frame then
                    frame = frame:GetParent()
                    if frame.unit then
                        tinsert(Roster, frame)
                    end
                end
            end
        end
    else
        for i = 1, 5 do
            local frame = _G["CompactPartyFrameMember" .. i .. "HealthBar"]
            if frame then
                frame = frame:GetParent()
                tinsert(Roster, frame)
            end
            local frame = _G["CompactPartyFramePet" .. i .. "HealthBar"]
            if frame then
                frame = frame:GetParent()
                if frame.unit then
                    tinsert(Roster, frame)
                end
            end
            local frame = _G["CompactArenaFrameMember" .. i .. "HealthBar"]
            if frame then
                frame = frame:GetParent()
                tinsert(Roster, frame)
            end
        end
    end
    needsUpdate = false
    return true
end

function addon:IterateRoster(callback)
    if needsUpdate then
        updateRoster()
    end
    for unit, frame in next, Roster do
        if not frame:IsForbidden() and frame:IsShown() then
            callback(frame)
        end
    end
end

hooksecurefunc("CompactUnitFrame_SetUnit", function(frame, unit)
    if not unit or unit:match("nameplate") then
        return
    end
    needsUpdate = true
end)
