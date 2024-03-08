--[[
    Created by Slothpala
    The aura indicator position and the aura timers are greatly inspired by a pull request from: https://github.com/excorp
--]]
local _, addonTable = ...
local addon = addonTable.RaidFrameSettings
local Buffs = addon:NewModule("Buffs")
Mixin(Buffs, addonTable.hooks)
local CDT = addonTable.cooldownText
local Glow = addonTable.Glow
local Aura = addonTable.Aura
local Media = LibStub("LibSharedMedia-3.0")

local fontObj = CreateFont("RaidFrameSettingsFont")

--[[
    --TODO local references here
]]
--WoW Api
local GetAuraDataByAuraInstanceID = C_UnitAuras.GetAuraDataByAuraInstanceID
local SetSize = SetSize
local SetTexCoord = SetTexCoord
local ClearAllPoints = ClearAllPoints
local SetPoint = SetPoint
local Hide = Hide
local SetFont = SetFont
local SetTextColor = SetTextColor
local SetShadowColor = SetShadowColor
local SetShadowOffset = SetShadowOffset
local SetDrawSwipe = SetDrawSwipe
local SetReverse = SetReverse
local SetDrawEdge = SetDrawEdge
--Lua
local next = next

local frame_registry = {}
local unitFrame = {}
local roster_changed = true
local glowOpt

local player = {
    GUID          = UnitGUID("player"),
    GUIDS         = {},
    aura          = {},
    buff          = {},
    sotfTrail     = 0,
    affectedSpell = {
        [774]    = true,
        [155777] = true,
        [8936]   = true,
        [48438]  = true
    },
}

local function CompactUnitFrame_ParseAllAuras(frame, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)
    frame.buffs:Clear()

    local batchCount = nil
    local usePackedAura = true
    local function HandleAura(aura)
        local type = CompactUnitFrame_ProcessAura(frame, aura, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)

        if type == AuraUtil.AuraUpdateChangedType.Buff then
            frame.buffs[aura.auraInstanceID] = aura
        end
    end
    AuraUtil.ForEachAura(frame.displayedUnit, AuraUtil.CreateFilterString(AuraUtil.AuraFilters.Helpful), batchCount, HandleAura, usePackedAura)
end

function Buffs:Glow(frame, onoff)
    if onoff then
        Glow:Start(glowOpt, frame)
    else
        Glow:Stop(glowOpt, frame)
    end
end

function Buffs:OnEnable()
    CDT.TimerTextLimit = addon.db.profile.MinorModules.TimerTextLimit

    glowOpt = CopyTable(addon.db.profile.MinorModules.Glow)
    glowOpt.type = addon:ConvertDbNumberToGlowType(glowOpt.type)

    local frameOpt = CopyTable(addon.db.profile.Buffs.BuffFramesDisplay)
    frameOpt.petframe = addon.db.profile.Buffs.petframe
    frameOpt.sotf = addon.db.profile.Buffs.sotf
    frameOpt.framestrata = addon:ConvertDbNumberToFrameStrata(frameOpt.framestrata)
    frameOpt.baseline = addon:ConvertDbNumberToBaseline(frameOpt.baseline)
    frameOpt.type = frameOpt.baricon and "baricon" or "blizzard"

    --Timer
    local durationOpt = CopyTable(addon.db.profile.Buffs.DurationDisplay) --copy is important so that we dont overwrite the db value when fetching the real values
    durationOpt.font = Media:Fetch("font", durationOpt.font)
    durationOpt.outlinemode = addon:ConvertDbNumberToOutlinemode(durationOpt.outlinemode)
    durationOpt.point = addon:ConvertDbNumberToPosition(durationOpt.point)
    durationOpt.relativePoint = addon:ConvertDbNumberToPosition(durationOpt.relativePoint)
    --Stack
    local stackOpt = CopyTable(addon.db.profile.Buffs.StacksDisplay)
    stackOpt.font = Media:Fetch("font", stackOpt.font)
    stackOpt.outlinemode = addon:ConvertDbNumberToOutlinemode(stackOpt.outlinemode)
    stackOpt.point = addon:ConvertDbNumberToPosition(stackOpt.point)
    stackOpt.relativePoint = addon:ConvertDbNumberToPosition(stackOpt.relativePoint)

    Aura.Opt.Buff.frameOpt = frameOpt
    Aura.Opt.Buff.durationOpt = durationOpt
    Aura.Opt.Buff.stackOpt = stackOpt

    --aura filter
    local filteredAuras = {}
    if addon.db.profile.Module.AuraFilter and addon.db.profile.AuraFilter.Buffs then
        for spellId, value in pairs(addon.db.profile.AuraFilter.Buffs) do
            filteredAuras[tonumber(spellId)] = value
        end
    end
    --increase
    local increase = {}
    for spellId, value in pairs(addon.db.profile.Buffs.Increase) do
        increase[tonumber(spellId)] = true
    end
    --user placed
    local userPlaced = {}
    local userPlacedIdx = 1
    local maxUserPlaced = 0
    for _, auraInfo in pairs(addon.db.profile.Buffs.AuraPosition) do
        userPlaced[auraInfo.spellId] = CopyTable(auraInfo)
        userPlaced[auraInfo.spellId].idx = userPlacedIdx
        userPlaced[auraInfo.spellId].point = addon:ConvertDbNumberToPosition(auraInfo.point)
        userPlaced[auraInfo.spellId].relativePoint = addon:ConvertDbNumberToPosition(auraInfo.relativePoint)
        userPlaced[auraInfo.spellId].frameNoNo = auraInfo.frameSelect == 3 and auraInfo.frameManualSelect or 1
        userPlacedIdx = userPlacedIdx + 1
    end
    maxUserPlaced = userPlacedIdx - 1
    --aura group
    local maxAuraGroup = 0
    local auraGroup = {}
    local auraGroupList = {}
    for k, auraInfo in pairs(addon.db.profile.Buffs.AuraGroup) do
        auraGroup[k] = CopyTable(auraInfo)
        auraGroup[k].point = addon:ConvertDbNumberToPosition(auraInfo.point)
        auraGroup[k].relativePoint = addon:ConvertDbNumberToPosition(auraInfo.relativePoint)
        auraGroup[k].frameNoNo = auraInfo.frameSelect == 3 and auraInfo.frameManualSelect or 1
        local maxAuras = auraInfo.unlimitAura ~= false and addon:count(auraInfo.auraList) or auraInfo.maxAuras or 1
        if maxAuras == 0 then
            maxAuras = 1
        end
        auraGroup[k].maxAuras = maxAuras
        maxAuraGroup = maxAuraGroup + maxAuras
        auraGroup[k].auraList = {}
        for aura, v in pairs(auraInfo.auraList) do
            auraGroup[k].auraList[tonumber(aura)] = v
            auraGroupList[tonumber(aura)] = auraGroupList[tonumber(aura)] or k
        end
    end
    for k, v in pairs(auraGroup) do
        if v.frame == 3 and v.frameNo > 0 then
            if v.frameNoNo > auraGroup[v.frameNo].maxAuras then
                v.frameNoNo = auraGroup[v.frameNo].maxAuras
            end
        end
    end
    --Buff size
    local width      = frameOpt.width
    local height     = frameOpt.height
    local big_width  = width * frameOpt.increase
    local big_height = height * frameOpt.increase
    local resizeBuffFrame
    if frameOpt.cleanIcons then
        local left, right, top, bottom = 0.1, 0.9, 0.1, 0.9
        if height ~= width then
            if height < width then
                local delta = width - height
                local scale_factor = (((100 / width) * delta) / 100) / 2
                top = top + scale_factor
                bottom = bottom - scale_factor
            else
                local delta = height - width
                local scale_factor = (((100 / height) * delta) / 100) / 2
                left = left + scale_factor
                right = right - scale_factor
            end
        end
        resizeBuffFrame = function(buffFrame)
            buffFrame:SetSize(width, height)
            buffFrame.icon:SetTexCoord(left, right, top, bottom)
        end
    else
        resizeBuffFrame = function(buffFrame)
            buffFrame:SetSize(width, height)
        end
    end
    --Buffframe position
    local point = addon:ConvertDbNumberToPosition(frameOpt.point)
    local relativePoint = addon:ConvertDbNumberToPosition(frameOpt.relativePoint)
    local followPoint, followRelativePoint, followOffsetX, followOffsetY = addon:GetAuraGrowthOrientationPoints(frameOpt.orientation, frameOpt.gap, frameOpt.baseline)

    local comparePriority = function(a, b)
        return a.priority > b.priority
    end

    local onSetBuff = function(buffFrame, aura, opt)
        if buffFrame:IsForbidden() then --not sure if this is still neede but when i created it at the start if dragonflight it was
            return
        end
        local parent = buffFrame:GetParent()
        if not parent or not frame_registry[parent] then
            return
        end

        local aurastored = frame_registry[parent].aura
        local oldAura = aurastored[aura.auraInstanceID]
        if frameOpt.refreshAni and oldAura then
            if math.abs(aura.expirationTime - oldAura.expirationTime) > 1 or oldAura.applications ~= aura.applications then
                aura.refresh = true
            end
        end
        aurastored[aura.auraInstanceID] = aura

        if frameOpt.sotf then
            if (not oldAura or math.abs(aura.expirationTime - oldAura.expirationTime) > 1) and (player.buff[114108] or player.sotfTrail > GetTime()) or (oldAura and oldAura.empowered) then
                if player.affectedSpell[aura.spellId] then
                    aura.empowered = true
                    frame_registry[parent].empowered[aura.spellId] = aura.auraInstanceID
                    local GUID = UnitGUID(parent.unit)
                    if GUID then
                        if not player.GUIDS[GUID] then
                            player.GUIDS[GUID] = {}
                        end
                        player.GUIDS[GUID][parent] = true
                    end
                end
            end
        end

        -- icon, stack, cooldown(duration) start
        buffFrame:SetAura(aura)

        if aura then
            local auraGroupNo = auraGroupList[aura.spellId]
            if userPlaced[aura.spellId] and userPlaced[aura.spellId].setSize then
                local placed = userPlaced[aura.spellId]
                buffFrame:SetSize(placed.width, placed.height)
            elseif auraGroupNo and auraGroup[auraGroupNo].setSize then
                local group = auraGroup[auraGroupNo]
                buffFrame:SetSize(group.width, group.height)
            elseif increase[aura.spellId] then
                buffFrame:SetSize(big_width, big_height)
            else
                buffFrame:SetSize(width, height)
            end
        end

        self:Glow(buffFrame, aura.empowered or opt.glow)
        buffFrame:SetAlpha(opt.alpha or 1)
    end

    local onHideAllBuffs = function(frame)
        if not frame_registry[frame] or frame:IsForbidden() or not frame:IsVisible() then
            return
        end
        if frame.buffFrames then
            for _, v in pairs(frame.buffFrames) do
                v:Hide()
            end
        end

        -- set placed aura / other aura
        local frameNum = 1
        local groupFrameNum = {}
        local sorted = {
            [0] = {},
        }
        for _, buffs in pairs({ frame.buffs, frame_registry[frame].buffs }) do
            buffs:Iterate(function(auraInstanceID, aura)
                if userPlaced[aura.spellId] then
                    local idx = frame_registry[frame].placedAuraStart + userPlaced[aura.spellId].idx - 1
                    local buffFrame = frame_registry[frame].extraBuffFrames[idx]
                    local placed = userPlaced[aura.spellId]
                    onSetBuff(buffFrame, aura, placed)
                    return false
                end
                if auraGroupList[aura.spellId] then
                    local groupNo = auraGroupList[aura.spellId]
                    local auraList = auraGroup[groupNo].auraList
                    local auraOpt = auraList[aura.spellId]
                    local priority = auraOpt.priority > 0 and auraOpt.priority or filteredAuras[aura.spellId] and filteredAuras[aura.spellId].priority or 0
                    if not sorted[groupNo] then sorted[groupNo] = {} end
                    tinsert(sorted[groupNo], { spellId = aura.spellId, priority = priority, aura = aura, opt = auraOpt })
                    groupFrameNum[groupNo] = groupFrameNum[groupNo] and (groupFrameNum[groupNo] + 1) or 2
                    return false
                end
                if frameNum <= frame_registry[frame].maxBuffs then
                    local filtered = filteredAuras[aura.spellId]
                    local priority = filtered and filtered.priority or 0
                    tinsert(sorted[0], { spellId = aura.spellId, priority = priority, aura = aura, opt = filtered or {} })
                    frameNum = frameNum + 1
                end
                return false
            end)
        end
        -- set buffs after sorting to priority.
        for _, v in pairs(sorted) do
            table.sort(v, comparePriority)
        end
        for groupNo, auralist in pairs(sorted) do
            for k, v in pairs(auralist) do
                if groupNo == 0 then
                    -- default aura frame
                    local buffFrame = frame_registry[frame].extraBuffFrames[k]
                    onSetBuff(buffFrame, v.aura, v.opt)
                else
                    -- aura group frame
                    local idx = frame_registry[frame].auraGroupStart[groupNo] + k - 1
                    local buffFrame = frame_registry[frame].extraBuffFrames[idx]
                    onSetBuff(buffFrame, v.aura, v.opt)
                    if k >= auraGroup[groupNo].maxAuras then
                        break
                    end
                end
            end
        end

        -- reanchor
        for groupNo, v in pairs(frame_registry[frame].reanchor) do
            local lastNum = groupFrameNum[groupNo] or 2
            if v.lastNum ~= lastNum then
                v.lastNum = lastNum
                for _, child in pairs(v.children) do
                    local idx = frame_registry[frame].auraGroupStart[groupNo] + v.lastNum - 2
                    local parent = frame_registry[frame].extraBuffFrames[idx]
                    child.frame:ClearAllPoints()
                    child.frame:SetPoint(child.conf.point, parent, child.conf.relativePoint, child.conf.xOffset, child.conf.yOffset)
                end
            end
        end

        -- hide left aura frames
        for i = 1, maxUserPlaced do
            local idx = frame_registry[frame].placedAuraStart + i - 1
            local buffFrame = frame_registry[frame].extraBuffFrames[idx]
            if not buffFrame.auraInstanceID or not frame.buffs[buffFrame.auraInstanceID] then
                self:Glow(buffFrame, false)
                buffFrame:UnsetAura()
            end
        end
        for i = frameNum, math.max(frame_registry[frame].maxBuffs, frame.maxBuffs) do
            local buffFrame = frame_registry[frame].extraBuffFrames[i]
            self:Glow(buffFrame, false)
            buffFrame:UnsetAura()
        end
        -- Modify the anchor of an auraGroup and hide left aura group
        for groupNo, v in pairs(auraGroup) do
            if groupFrameNum[groupNo] and groupFrameNum[groupNo] > 0 then
                if v.orientation == 5 or v.orientation == 6 then
                    local idx = frame_registry[frame].auraGroupStart[groupNo]
                    local buffFrame = frame_registry[frame].extraBuffFrames[idx]
                    local x, y = 0, 0
                    for i = 2, groupFrameNum[groupNo] - 1 do
                        local idx = frame_registry[frame].auraGroupStart[groupNo] + i - 1
                        local buffFrame = frame_registry[frame].extraBuffFrames[idx]
                        local w, h = buffFrame:GetSize()
                        if v.orientation == 5 then
                            x = x + w
                        elseif v.orientation == 6 then
                            y = y + h
                        end
                    end
                    buffFrame:ClearAllPoints()
                    buffFrame:SetPoint(v.point, frame, v.relativePoint, v.xOffset - x / 2, v.yOffset + y / 2)
                end
            end
            local groupSize = frame_registry[frame].auraGroupEnd[groupNo] - frame_registry[frame].auraGroupStart[groupNo] + 1
            for i = groupFrameNum[groupNo] or 1, groupSize do
                local idx = frame_registry[frame].auraGroupStart[groupNo] + i - 1
                local buffFrame = frame_registry[frame].extraBuffFrames[idx]
                self:Glow(buffFrame, false)
                buffFrame:UnsetAura()
            end
        end
    end
    self:HookFunc("CompactUnitFrame_HideAllBuffs", onHideAllBuffs)

    local function onFrameSetup(frame)
        if not frameOpt.petframe then
            local fname = frame:GetName()
            if not fname or fname:match("Pet") then
                return
            end
        end

        if not frame_registry[frame] then
            frame_registry[frame] = {
                maxBuffs        = frameOpt.maxbuffsAuto and frame.maxBuffs or frameOpt.maxbuffs,
                placedAuraStart = 0,
                auraGroupStart  = {},
                auraGroupEnd    = {},
                extraBuffFrames = {},
                reanchor        = {},
                buffs           = TableUtil.CreatePriorityTable(AuraUtil.DefaultAuraCompare, TableUtil.Constants.AssociativePriorityTable),
                aura            = {},
                empowered       = {},
                dirty           = true,
            }
        end

        if frame_registry[frame].dirty then
            frame_registry[frame].maxBuffs = frameOpt.maxbuffsAuto and frame.maxBuffs or frameOpt.maxbuffs
            frame_registry[frame].dirty = false

            local placedAuraStart = frame.maxBuffs + 1
            for i = 1, frame_registry[frame].maxBuffs do
                local buffFrame = Aura:createAuraFrame(frame, "Buff", frameOpt.type, i) -- category:Buff,Debuff, type=blizzard,baricon
                frame_registry[frame].extraBuffFrames[i] = buffFrame
                buffFrame:ClearAllPoints()
                buffFrame.icon:SetTexCoord(0, 1, 0, 1)
                placedAuraStart = i + 1
            end
            frame_registry[frame].placedAuraStart = placedAuraStart

            for i = 1, maxUserPlaced + maxAuraGroup do
                local idx = placedAuraStart + i - 1
                local buffFrame = Aura:createAuraFrame(frame, "Buff", frameOpt.type, idx) -- category:Buff,Debuff, type=blizzard,baricon
                frame_registry[frame].extraBuffFrames[idx] = buffFrame
            end

            local idx = frame_registry[frame].placedAuraStart - 1 + maxUserPlaced
            for k, v in pairs(auraGroup) do
                frame_registry[frame].auraGroupStart[k] = idx + 1
                frame_registry[frame].auraGroupEnd[k] = idx + v.maxAuras
                idx = idx + v.maxAuras
            end

            frame_registry[frame].reanchor = {}
            local reanchor = frame_registry[frame].reanchor
            for _, v in pairs(userPlaced) do
                if v.frame == 3 and v.frameSelect == 1 and auraGroup[v.frameNo] and auraGroup[v.frameNo].maxAuras > 1 then
                    if not reanchor[v.frameNo] then
                        reanchor[v.frameNo] = {
                            lastNum = 2,
                            children = {}
                        }
                    end
                    idx = frame_registry[frame].placedAuraStart + v.idx - 1
                    tinsert(reanchor[v.frameNo].children, {
                        frame = frame_registry[frame].extraBuffFrames[idx],
                        conf  = v,
                    })
                end
            end
            for groupNo, v in pairs(auraGroup) do
                if v.frame == 3 and v.frameSelect == 1 and auraGroup[v.frameNo] and auraGroup[v.frameNo].maxAuras > 1 then
                    if not reanchor[v.frameNo] then
                        reanchor[v.frameNo] = {
                            lastNum = 2,
                            children = {}
                        }
                    end
                    idx = frame_registry[frame].auraGroupStart[groupNo]
                    tinsert(reanchor[v.frameNo].children, {
                        frame = frame_registry[frame].extraBuffFrames[idx],
                        conf  = v,
                    })
                end
            end

            for _, v in pairs(frame_registry[frame].extraBuffFrames) do
                if frameOpt.tooltip then
                    v:SetScript("OnUpdate", nil)
                    v:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, 0)
                        self:UpdateTooltip()
                        local function RunOnUpdate()
                            if (GameTooltip:IsOwned(self)) then
                                self:UpdateTooltip()
                            end
                        end
                        self:SetScript("OnUpdate", RunOnUpdate)
                    end)
                    v:SetScript("OnLeave", function(self)
                        GameTooltip:Hide()
                        self:SetScript("OnUpdate", nil)
                    end)
                else
                    v:SetScript("OnUpdate", nil)
                    v:SetScript("OnEnter", nil)
                    v:SetScript("OnLeave", nil)
                end
            end
        end

        -- set anchor and resize
        local anchorSet, prevFrame
        for i = 1, frame_registry[frame].maxBuffs do
            local buffFrame = frame_registry[frame].extraBuffFrames[i]
            if not anchorSet then
                local parent = (frameOpt.frame == 2 and frame.healthBar) or (frameOpt.frame == 3 and frame.powerBar) or frame
                buffFrame:ClearAllPoints()
                buffFrame:SetPoint(point, parent, relativePoint, frameOpt.xOffset, frameOpt.yOffset)
                anchorSet = true
            else
                buffFrame:ClearAllPoints()
                buffFrame:SetPoint(followPoint, prevFrame, followRelativePoint, followOffsetX, followOffsetY)
            end
            prevFrame = buffFrame
            resizeBuffFrame(buffFrame)
        end
        local idx = frame_registry[frame].placedAuraStart - 1
        for _, place in pairs(userPlaced) do
            idx = frame_registry[frame].placedAuraStart + place.idx - 1
            local buffFrame = frame_registry[frame].extraBuffFrames[idx]
            local parentIdx = (place.frame == 2 and place.frameNo > 0 and userPlaced[place.frameNo] and (frame_registry[frame].placedAuraStart + userPlaced[place.frameNo].idx - 1)) or
                (place.frame == 3 and place.frameNo > 0 and auraGroup[place.frameNo] and (frame_registry[frame].auraGroupStart[place.frameNo] + place.frameNoNo - 1))
            local parent = parentIdx and frame_registry[frame].extraBuffFrames[parentIdx] or frame
            buffFrame:ClearAllPoints()
            buffFrame:SetPoint(place.point, parent, place.relativePoint, place.xOffset, place.yOffset)
            resizeBuffFrame(buffFrame)
        end
        for k, v in pairs(auraGroup) do
            local followPoint, followRelativePoint, followOffsetX, followOffsetY = addon:GetAuraGrowthOrientationPoints(v.orientation, v.gap, "")
            anchorSet, prevFrame = false, nil
            for _ = 1, v.maxAuras do
                idx = idx + 1
                local buffFrame = frame_registry[frame].extraBuffFrames[idx]
                if not anchorSet then
                    local parentIdx = (v.frame == 2 and v.frameNo > 0 and userPlaced[v.frameNo] and (frame_registry[frame].placedAuraStart + userPlaced[v.frameNo].idx - 1)) or
                        (v.frame == 3 and v.frameNo > 0 and auraGroup[v.frameNo] and (frame_registry[frame].auraGroupStart[v.frameNo] + v.frameNoNo - 1))
                    local parent = parentIdx and frame_registry[frame].extraBuffFrames[parentIdx] or frame
                    buffFrame:ClearAllPoints()
                    buffFrame:SetPoint(v.point, parent, v.relativePoint, v.xOffset, v.yOffset)
                    anchorSet = true
                else
                    buffFrame:ClearAllPoints()
                    buffFrame:SetPoint(followPoint, prevFrame, followRelativePoint, followOffsetX, followOffsetY)
                end
                prevFrame = buffFrame
                resizeBuffFrame(buffFrame)
            end
        end
    end
    self:HookFuncFiltered("DefaultCompactUnitFrameSetup", onFrameSetup)
    if frameOpt.petframe then
        self:HookFuncFiltered("DefaultCompactMiniFrameSetup", onFrameSetup)
    end

    if roster_changed then
        roster_changed = false
        addon:IterateRoster(function(frame)
            if not frameOpt.petframe then
                local fname = frame:GetName()
                if not fname or fname:match("Pet") then
                    return
                end
            end
            if not frame_registry[frame] then
                frame_registry[frame] = {
                    maxBuffs        = frameOpt.maxbuffsAuto and frame.maxBuffs or frameOpt.maxbuffs,
                    placedAuraStart = 0,
                    auraGroupStart  = {},
                    auraGroupEnd    = {},
                    extraBuffFrames = {},
                    reanchor        = {},
                    buffs           = TableUtil.CreatePriorityTable(AuraUtil.DefaultAuraCompare, TableUtil.Constants.AssociativePriorityTable),
                    aura            = {},
                    empowered       = {},
                    dirty           = true,
                }
            end
        end)
    end
    for frame, v in pairs(frame_registry) do
        v.dirty = true
        onFrameSetup(frame)
        if frame.unit then
            if not unitFrame[frame.unit] then unitFrame[frame.unit] = {} end
            unitFrame[frame.unit][frame] = true
            if frame.unitExists and frame:IsShown() and not frame:IsForbidden() then
                CompactUnitFrame_UpdateAuras(frame)
            end
        end
    end

    self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        roster_changed = true
    end)

    if frameOpt.petframe then
        self:HookFunc("CompactUnitFrame_SetUnit", function(frame, unit)
            if not unit or not unit:match("pet") then
                return
            end
            if not unitFrame[frame.unit] then unitFrame[frame.unit] = {} end
            unitFrame[frame.unit][frame] = true
            for srcframe in pairs(unitFrame[unit]) do
                if srcframe.unit ~= unit then
                    unitFrame[unit][srcframe] = nil
                end
            end
        end)
    end
    if frameOpt.sotf then
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", function()
            local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
            if sourceGUID ~= player.GUID or subevent ~= "SPELL_CAST_SUCCESS" then
                return
            end
            local spellId, spellName, school = select(12, CombatLogGetCurrentEventInfo())
            if not player.affectedSpell[spellId] then
                return
            end
            if not player.GUIDS[destGUID] then
                return
            end
            for srcframe in pairs(player.GUIDS[destGUID]) do
                local auraInstanceID = frame_registry[srcframe].empowered[spellId]
                if auraInstanceID then
                    frame_registry[srcframe].aura[auraInstanceID].empowered = nil
                    player.GUIDS[destGUID][srcframe] = nil
                end
            end
        end)
    end

    if frameOpt.petframe or frameOpt.sotf then
        self:RegisterEvent("UNIT_AURA", function(event, unit, unitAuraUpdateInfo)
            if frameOpt.sotf then
                if UnitIsUnit(unit, "player") then
                    if unitAuraUpdateInfo == nil then
                        local function HandleAura(aura)
                            if aura.spellId == 114108 then
                                player.aura[aura.auraInstanceID] = aura
                                player.buff[aura.spellId] = aura
                            end
                        end
                        AuraUtil.ForEachAura("player", AuraUtil.CreateFilterString(AuraUtil.AuraFilters.Helpful), nil, HandleAura, false)
                    else
                        if unitAuraUpdateInfo.addedAuras ~= nil then
                            for _, aura in ipairs(unitAuraUpdateInfo.addedAuras) do
                                if aura.spellId == 114108 then
                                    player.aura[aura.auraInstanceID] = aura
                                    player.buff[aura.spellId] = aura
                                end
                            end
                        end
                        if unitAuraUpdateInfo.removedAuraInstanceIDs ~= nil then
                            for _, auraInstanceID in ipairs(unitAuraUpdateInfo.removedAuraInstanceIDs) do
                                local aura = player.aura[auraInstanceID]
                                if aura then
                                    player.aura[auraInstanceID] = nil
                                    player.buff[aura.spellId] = nil
                                    if aura.spellId == 114108 then
                                        player.sotfTrail = GetTime() + 0.5
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if not unit:match("pet") then
                return
            end
            if not unitFrame[unit] then
                return
            end
            for srcframe in pairs(unitFrame[unit]) do
                local frame = frame_registry[srcframe]
                if frame then
                    local buffsChanged = false

                    local displayOnlyDispellableDebuffs = false
                    local ignoreBuffs = false
                    local ignoreDebuffs = true
                    local ignoreDispelDebuffs = true

                    frame.unit = srcframe.unit
                    frame.displayedUnit = srcframe.displayedUnit

                    if unitAuraUpdateInfo == nil or unitAuraUpdateInfo.isFullUpdate or frame.debuffs == nil then
                        CompactUnitFrame_ParseAllAuras(frame, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)
                        buffsChanged = true
                    else
                        if unitAuraUpdateInfo.addedAuras ~= nil then
                            for _, aura in ipairs(unitAuraUpdateInfo.addedAuras) do
                                local type = CompactUnitFrame_ProcessAura(frame, aura, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)
                                if type == AuraUtil.AuraUpdateChangedType.Buff then
                                    frame.buffs[aura.auraInstanceID] = aura
                                    buffsChanged = true
                                end
                            end
                        end

                        if unitAuraUpdateInfo.updatedAuraInstanceIDs ~= nil then
                            for _, auraInstanceID in ipairs(unitAuraUpdateInfo.updatedAuraInstanceIDs) do
                                if frame.buffs[auraInstanceID] ~= nil then
                                    local newAura = C_UnitAuras.GetAuraDataByAuraInstanceID(frame.displayedUnit, auraInstanceID)
                                    if newAura ~= nil then
                                        newAura.isBuff = true
                                    end
                                    frame.buffs[auraInstanceID] = newAura
                                    buffsChanged = true
                                end
                            end
                        end

                        if unitAuraUpdateInfo.removedAuraInstanceIDs ~= nil then
                            for _, auraInstanceID in ipairs(unitAuraUpdateInfo.removedAuraInstanceIDs) do
                                if frame.buffs[auraInstanceID] ~= nil then
                                    frame.buffs[auraInstanceID] = nil
                                    buffsChanged = true
                                end
                            end
                        end
                    end

                    if buffsChanged then
                        onHideAllBuffs(srcframe)
                    end
                end
            end
        end)
    end
end

--parts of this code are from FrameXML/CompactUnitFrame.lua
function Buffs:OnDisable()
    self:DisableHooks()
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:UnregisterEvent("UNIT_AURA")
    roster_changed = true
    local restoreBuffFrames = function(frame)
        for _, extraBuffFrame in pairs(frame_registry[frame].extraBuffFrames) do
            extraBuffFrame:Hide()
            self:Glow(extraBuffFrame, false)
        end
        if frame.unit and frame.unitExists and frame:IsShown() and not frame:IsForbidden() then
            CompactUnitFrame_UpdateAuras(frame)
        end
    end
    for frame in pairs(frame_registry) do
        restoreBuffFrames(frame)
    end
    CDT:DisableCooldownText()
end
