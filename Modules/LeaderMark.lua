local _, addonTable = ...
local addon = addonTable.RaidFrameSettings
local LeaderMark = addon:NewModule("LeaderMark")
Mixin(LeaderMark, addonTable.hooks)

local enabled

function LeaderMark:UpdateAllLeaderMark()
    local LeaderMarkOpt = CopyTable(addon.db.profile.MinorModules.LeaderMark)
    LeaderMarkOpt.point = addon:ConvertDbNumberToPosition(LeaderMarkOpt.point)
    LeaderMarkOpt.relativePoint = addon:ConvertDbNumberToPosition(LeaderMarkOpt.relativePoint)

    local isLeader
    if enabled and UnitInRaid("player") then
        -- 레이드 일때 UnitInRaid() -> GetRaidRosterInfo() 호출해서 공장,부공장일때 표시 아니면 숨김
        isLeader = function(unit)
            local index = UnitInRaid(unit)
            if not index then
                return 0
            end
            local name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML, combatRole = GetRaidRosterInfo(index)
            return rank
        end
    elseif enabled and UnitInParty("player") then
        -- 파티일때 UnitIsGroupLeader() 이거 호출해서 true면 아이콘 표시, 아니면 width=1 + hide()
        isLeader = function(unit)
            if UnitIsGroupLeader(unit) then
                return 2
            end
            return 0
        end
    else
        -- 모두의 징표를 삭제할것
        isLeader = function()
            return 0
        end
    end

    addon:IterateRoster(function(frame)
        if not frame.unit or not UnitExists(frame.unit) or not UnitIsPlayer(frame.unit) then
            return
        end

        local leader = isLeader(frame.unit)
        if leader > 0 then
            if not frame.leaderMark then
                frame.leaderMark = frame:CreateTexture(nil, "OVERLAY")
                frame.leaderMark:Hide()
                local parent = LeaderMarkOpt.frame == 2 and frame.roleIcon or frame
                frame.leaderMark:SetPoint(LeaderMarkOpt.point, parent, LeaderMarkOpt.relativePoint, LeaderMarkOpt.x_offset, LeaderMarkOpt.y_offset)
            end

            if leader == 2 then
                frame.leaderMark:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
            elseif leader == 1 then
                frame.leaderMark:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
            end
            frame.leaderMark:Show()
            frame.leaderMark:SetSize(LeaderMarkOpt.width, LeaderMarkOpt.height)
        else
            if frame.leaderMark then
                frame.leaderMark:Hide()
                frame.leaderMark:SetSize(1, LeaderMarkOpt.height)
            end
        end
    end)
end

function LeaderMark:OnEnable()
    enabled = true
    -- 한타임 늦게 갱신.. 공대장 넘어간게 처리가 안됬을수 있어서
    self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        C_Timer.After(0, function()
            self:UpdateAllLeaderMark()
        end)
    end)

    self:UpdateAllLeaderMark()
end

function LeaderMark:OnDisable()
    enabled = false
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    self:UpdateAllLeaderMark()
end
