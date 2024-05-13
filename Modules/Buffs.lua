--[[
    Created by Slothpala
--]]

local _, addonTable = ...
local addon = addonTable.RaidFrameSettings
local Buffs = addon:NewModule("Buffs")
Mixin(Buffs, addonTable.hooks)
local Glow = addonTable.Glow
local Aura = addonTable.Aura
local Queue = addonTable.Queue
local classMod = addonTable.classMod
local Media = LibStub("LibSharedMedia-3.0")

local AuraFilter = addon:GetModule("AuraFilter")

-- WoW Api
local UnitIsPlayer = UnitIsPlayer
local UnitInPartyIsAI = UnitInPartyIsAI
local TableUtil = TableUtil
local AuraUtil = AuraUtil
local C_Timer = C_Timer

-- Lua
local CopyTable = CopyTable
local GetTime = GetTime
local pairs = pairs
local tonumber = tonumber
local tinsert = tinsert
local math = math
local table = table
local random = random


local frame_registry = {}
local groupClass = {}
local groupClassRangeIn = {}
local unitFrame = {}
local glowOpt
local testmodeTicker
local onUpdateAuras
local onUnsetBuff

local unitToPetUnit = {
    player = "pet"
}
for i = 1, 40 do
    unitToPetUnit["raid" .. i] = "raidpet" .. i
end
for i = 1, 4 do
    unitToPetUnit["party" .. i] = "partypet" .. i
end

if not classMod then
    classMod = {
        onSetBuff = function(buffFrame, aura, oldAura, opt) end,
        rosterUpdate = function() end,
        init = function(frame) end,
        onEnable = function(opt) end,
        onDisable = function() end,
        initMod = function(buffs_mod, buffs_frame_registry, displayAura) end,
    }
end

local function initRegistry(frame)
    if frame_registry[frame] then
        return
    end
    frame_registry[frame] = {
        maxBuffs        = 0,
        placedAuraStart = 0,
        auraGroupStart  = {},
        auraGroupEnd    = {},
        extraBuffFrames = {},
        reanchor        = {},
        buffs           = TableUtil.CreatePriorityTable(AuraUtil.DefaultAuraCompare, TableUtil.Constants.AssociativePriorityTable),
        aura            = {},
        allaura         = {
            aura  = {},
            all   = {},
            own   = {},
            other = {},
        },
        empowered       = {},
        userPlacedShown = {},
        dirty           = true,
    }
end

classMod:initMod(Buffs, frame_registry)

function Buffs:Glow(frame, onoff)
    if onoff then
        Glow:Start(glowOpt, frame)
    else
        Glow:Stop(glowOpt, frame)
    end
end

function Buffs:OnEnable()
    AuraFilter:reloadConf()

    Aura:setTimerLimit(addon.db.profile.MinorModules.TimerTextLimit)

    glowOpt = CopyTable(addon.db.profile.MinorModules.Glow)
    glowOpt.type = addon:ConvertDbNumberToGlowType(glowOpt.type)

    local frameOpt = CopyTable(addon.db.profile.Buffs.BuffFramesDisplay)
    frameOpt.petframe = addon.db.profile.Buffs.petframe
    frameOpt.sotf = addon.db.profile.Buffs.sotf
    frameOpt.mastery = addon.db.profile.Buffs.mastery
    frameOpt.framestrata = addon:ConvertDbNumberToFrameStrata(frameOpt.framestrata)
    frameOpt.baseline = addon:ConvertDbNumberToBaseline(frameOpt.baseline)
    frameOpt.type = frameOpt.baricon and "baricon" or "blizzard"
    frameOpt.missingAura = addon.db.profile.Buffs.useMissingAura
    frameOpt.missingAuraRangeCheck = addon.db.profile.Buffs.useMissingAuraRangeCheck
    frameOpt.missingAuraNotCombat = addon.db.profile.Buffs.useMissingAuraNotCombat

    --Timer
    local durationOpt = CopyTable(addon.db.profile.Buffs.DurationDisplay) --copy is important so that we dont overwrite the db value when fetching the real values
    durationOpt.font = Media:Fetch("font", durationOpt.font)
    durationOpt.outlinemode = addon:ConvertDbNumberToOutlinemode(durationOpt.outlinemode)
    durationOpt.point = addon:ConvertDbNumberToPosition(durationOpt.point)
    durationOpt.relativePoint = addon:ConvertDbNumberToPosition(durationOpt.relativePoint)
    -- Stack display options
    local stackOpt = CopyTable(addon.db.profile.Buffs.StacksDisplay)
    stackOpt.font = Media:Fetch("font", stackOpt.font)
    stackOpt.outlinemode = addon:ConvertDbNumberToOutlinemode(stackOpt.outlinemode)
    stackOpt.point = addon:ConvertDbNumberToPosition(stackOpt.point)
    stackOpt.relativePoint = addon:ConvertDbNumberToPosition(stackOpt.relativePoint)

    Aura.Opt.Buff.frameOpt = frameOpt
    Aura.Opt.Buff.durationOpt = durationOpt
    Aura.Opt.Buff.stackOpt = stackOpt

    --aura filter
    local filteredAuras = addon.filteredAuras

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
    --missing aura
    local missingAuraOpt = {}
    local missingAuraAll = {}
    for spellId, v in pairs(addon.db.profile.Buffs.MissingAura) do
        local conf = CopyTable(v)
        conf.class = addon:ConvertDbNumberToClass(v.class)
        missingAuraOpt[tonumber(spellId)] = conf
        missingAuraAll[tonumber(spellId)] = true
        for _, alterSpellId in pairs(conf.alter) do
            missingAuraAll[alterSpellId] = true
        end
    end
    if next(missingAuraOpt) == nil then
        frameOpt.missingAura = false
    end


    --Buff size
    local width      = frameOpt.width
    local height     = frameOpt.height
    local big_width  = width * frameOpt.increase
    local big_height = height * frameOpt.increase


    --Buffframe position
    local point = addon:ConvertDbNumberToPosition(frameOpt.point)
    local relativePoint = addon:ConvertDbNumberToPosition(frameOpt.relativePoint)
    local followPoint, followRelativePoint, followOffsetX, followOffsetY = addon:GetAuraGrowthOrientationPoints(frameOpt.orientation, frameOpt.gap, frameOpt.baseline)

    local comparePriority = function(a, b)
        return a.priority > b.priority
    end

    classMod:onEnable(frameOpt)

    local _onSetBuff = function(buffFrame, aura, opt)
        if not buffFrame or buffFrame:IsForbidden() then --not sure if this is still neede but when i created it at the start if dragonflight it was
            return
        end
        if buffFrame.aura == aura and buffFrame:IsShown() then
            return
        end

        local parent = buffFrame:GetParent()
        if not parent or not frame_registry[parent] then
            return
        end

        local aurastored = frame_registry[parent].aura
        local oldAura = aurastored[aura.auraInstanceID]
        if frameOpt.refreshAni and oldAura then
            if math.abs(aura.expirationTime - oldAura.expirationTime) > 1 or (aura.applications + oldAura.applications ~= 1 and oldAura.applications ~= aura.applications) then
                aura.refresh = true
            end
        end
        aurastored[aura.auraInstanceID] = aura

        classMod:onSetBuff(buffFrame, aura, oldAura, opt)

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
    local onSetBuff = function(buffFrame, aura, opt)
        if not buffFrame or buffFrame:IsForbidden() then --not sure if this is still neede but when i created it at the start if dragonflight it was
            return
        end
        if buffFrame.aura == aura and buffFrame:IsShown() then
            return
        end
        Queue:add(_onSetBuff, buffFrame, aura, opt)
    end

    local _onUnsetBuff = function(buffFrame)
        if not buffFrame or not buffFrame:IsShown() then
            return
        end
        self:Glow(buffFrame, false)
        buffFrame:UnsetAura()
    end
    onUnsetBuff = function(buffFrame)
        Queue:runAndAdd(_onUnsetBuff, buffFrame)
    end

    local function _onUpdateMissingAuras(frame)
        if not frame or not frame.unit then
            return
        end
        local changed
        if not frame_registry[frame] then
            return
        end
        local registry = frame_registry[frame]

        if (frameOpt.missingAuraNotCombat and InCombatLockdown()) or (frameOpt.missingAuraRangeCheck and not (UnitIsUnit("player", frame.unit) or UnitInRange(frame.unit))) then
            if registry.buffs:Size() == 0 then
                return
            end
            registry.buffs:Clear()
            onUpdateAuras(frame)
            return
        end

        for spellId, v in pairs(missingAuraOpt) do
            local check
            if v.other then
                if groupClass[v.class] then
                    if next(groupClassRangeIn[v.class]) ~= nil then
                        check = registry.allaura.all
                    else
                        if registry.buffs[-spellId] then
                            registry.buffs[-spellId] = nil
                            changed = true
                        end
                    end
                end
            else
                check = registry.allaura.own
            end
            if check then
                local checkId = spellId
                if not check[checkId] then
                    for _, alterId in pairs(v.alter) do
                        if check[alterId] then
                            checkId = alterId
                        end
                    end
                end
                if check[checkId] then
                    if registry.buffs[-spellId] then
                        registry.buffs[-spellId] = nil
                        changed = true
                    end
                else
                    if not registry.buffs[-spellId] then
                        registry.buffs[-spellId] = addon:makeFakeAura(spellId, {
                            expirationTime = 1,
                        })
                        changed = true
                    end
                end
            end
        end

        if changed then
            onUpdateAuras(frame)
        end
        return changed
    end
    local function onUpdateMissingAuras(frame)
        if not frame then
            return
        end
        Queue:add(_onUpdateMissingAuras, frame)
    end

    local _onUpdateAuras = function(frame)
        if not frame or not frame_registry[frame] or frame_registry[frame].dirty or frame:IsForbidden() or not frame:IsVisible() then
            return
        end
        for k = 1, frame.maxBuffs do
            local v = frame.buffFrames[k]
            if not v:IsShown() then
                break
            end
            v:Hide()
        end
        --[[
        for _, v in next, frame.buffFrames do
            if not v:IsShown() then
                break
            end
            v:Hide()
        end
        ]]
        if not frame or not frame_registry[frame] or frame:IsForbidden() or not frame:IsVisible() then
            return
        end

        -- set placed aura / other aura
        local frameNum = 1
        local groupFrameNum = {}
        local sorted = {
            [0] = {},
        }
        local userPlacedShown = {}
        for _, buffs in pairs({ frame.buffs, frame_registry[frame].buffs }) do
            buffs:Iterate(function(auraInstanceID, aura)
                if userPlaced[aura.spellId] then
                    local idx = frame_registry[frame].placedAuraStart + userPlaced[aura.spellId].idx - 1
                    local buffFrame = frame_registry[frame].extraBuffFrames[idx]
                    local placed = userPlaced[aura.spellId]
                    onSetBuff(buffFrame, aura, placed)
                    userPlacedShown[buffFrame] = true
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
                local filtered = filteredAuras[aura.spellId]
                local priority = filtered and filtered.priority or 0
                tinsert(sorted[0], { spellId = aura.spellId, priority = priority, aura = aura, opt = filtered or {} })
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
                    if k > frame_registry[frame].maxBuffs then
                        break
                    end
                    frameNum = k + 1
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
        for buffFrame in pairs(frame_registry[frame].userPlacedShown) do
            if not userPlacedShown[buffFrame] then
                if not buffFrame.auraInstanceID or not (frame.buffs[buffFrame.auraInstanceID] or frame_registry[frame].buffs[buffFrame.auraInstanceID]) then
                    onUnsetBuff(buffFrame)
                else
                    userPlacedShown[buffFrame] = true
                end
            end
        end
        frame_registry[frame].userPlacedShown = userPlacedShown
        for i = frameNum, frame_registry[frame].maxBuffs do
            local buffFrame = frame_registry[frame].extraBuffFrames[i]
            if not buffFrame:IsShown() then
                break
            end
            onUnsetBuff(buffFrame)
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
                if not buffFrame:IsShown() then
                    break
                end
                onUnsetBuff(buffFrame)
            end
        end
    end
    onUpdateAuras = function(frame)
        if not frame or not frame_registry[frame] or frame:IsForbidden() or not frame:IsVisible() then
            return
        end
        for k = 1, frame.maxBuffs do
            local v = frame.buffFrames[k]
            if not v:IsShown() then
                break
            end
            v:Hide()
        end
        --[[
        for _, v in next, frame.buffFrames do
            if not v:IsShown() then
                break
            end
            v:Hide()
        end
        ]]
        Queue:add(_onUpdateAuras, frame)
    end
    -- self:HookFunc("CompactUnitFrame_UpdateAuras", onUpdateAuras)
    self:HookFunc("CompactUnitFrame_HideAllBuffs", onUpdateAuras)

    local function onFrameSetup(frame)
        if not frame then
            return
        end
        if frame.unit and not (frame.unit:match("pet") and frameOpt.petframe) and not UnitIsPlayer(frame.unit) and not UnitInPartyIsAI(frame.unit) then
            return
        end

        initRegistry(frame)

        if frame_registry[frame].dirty then
            frame_registry[frame].maxBuffs = frameOpt.maxbuffsAuto and frame.maxBuffs or frameOpt.maxbuffs
            frame_registry[frame].dirty = false

            local placedAuraStart = frame.maxBuffs + 1
            for i = 1, frame_registry[frame].maxBuffs do
                local buffFrame, dirty = Aura:createAuraFrame(frame, "Buff", frameOpt.type, i) -- category:Buff,Debuff, type=blizzard,baricon
                frame_registry[frame].extraBuffFrames[i] = buffFrame
                frame_registry[frame].dirty = dirty
                buffFrame:ClearAllPoints()
                buffFrame.icon:SetTexCoord(0, 1, 0, 1)
                placedAuraStart = i + 1
            end
            frame_registry[frame].placedAuraStart = placedAuraStart

            for i = 1, maxUserPlaced + maxAuraGroup do
                local idx = placedAuraStart + i - 1
                local buffFrame, dirty = Aura:createAuraFrame(frame, "Buff", frameOpt.type, idx) -- category:Buff,Debuff, type=blizzard,baricon
                frame_registry[frame].extraBuffFrames[idx] = buffFrame
                frame_registry[frame].dirty = dirty
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
                buffFrame:SetSize(width, height)
                buffFrame:SetCoord(width, height)
                buffFrame.overwrapWithParent = Aura:framesOverlap(frame, buffFrame)
            end
            local idx = frame_registry[frame].placedAuraStart - 1
            for _, place in pairs(userPlaced) do
                idx = frame_registry[frame].placedAuraStart + place.idx - 1
                local buffFrame = frame_registry[frame].extraBuffFrames[idx]
                local parentIdx = (place.frame == 2 and place.frameNo > 0 and userPlaced[place.frameNo] and (frame_registry[frame].placedAuraStart + userPlaced[place.frameNo].idx - 1)) or
                    (place.frame == 3 and place.frameNo > 0 and auraGroup[place.frameNo] and (frame_registry[frame].auraGroupStart[place.frameNo] + place.frameNoNo - 1))
                local parent = parentIdx and frame_registry[frame].extraBuffFrames[parentIdx] or place.frame == 4 and frame.healthBar or frame
                buffFrame:ClearAllPoints()
                buffFrame:SetPoint(place.point, parent, place.relativePoint, place.xOffset, place.yOffset)
                buffFrame:SetSize(width, height)
                buffFrame:SetCoord(width, height)
                buffFrame.overwrapWithParent = Aura:framesOverlap(frame, buffFrame)
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
                        local parent = parentIdx and frame_registry[frame].extraBuffFrames[parentIdx] or v.frame == 4 and frame.healthBar or frame
                        buffFrame:ClearAllPoints()
                        buffFrame:SetPoint(v.point, parent, v.relativePoint, v.xOffset, v.yOffset)
                        anchorSet = true
                    else
                        buffFrame:ClearAllPoints()
                        buffFrame:SetPoint(followPoint, prevFrame, followRelativePoint, followOffsetX, followOffsetY)
                    end
                    prevFrame = buffFrame
                    buffFrame:SetSize(width, height)
                    buffFrame:SetCoord(width, height)
                    buffFrame.overwrapWithParent = Aura:framesOverlap(frame, buffFrame)
                end
            end
        end

        for _, v in pairs(frame.buffFrames) do
            v:ClearAllPoints()
            v.cooldown:SetDrawSwipe(false)
        end

        if frameOpt.missingAura then
            if frame.unit and (UnitIsPlayer(frame.unit) or UnitInPartyIsAI(frame.unit)) then
                Aura:SetAuraVar(frame, "buffsAll", frame_registry[frame].allaura, onUpdateMissingAuras, missingAuraAll)
            end
        end
    end
    local function onFrameSetupQueued(frame)
        for k = 1, frame.maxBuffs do
            local v = frame.buffFrames[k]
            if v:GetNumPoints() == 0 then
                break
            end
            v:ClearAllPoints()
            v.cooldown:SetDrawSwipe(false)
        end
        --[[
        for _, v in pairs(frame.buffFrames) do
            if v:GetNumPoints() == 0 then
                break
            end
            v:ClearAllPoints()
            v.cooldown:SetDrawSwipe(false)
        end
        ]]
        Queue:add(onFrameSetup, frame)
    end

    self:HookFuncFiltered("DefaultCompactUnitFrameSetup", onFrameSetupQueued)

    if frameOpt.petframe then
        self:HookFuncFiltered("DefaultCompactMiniFrameSetup", onFrameSetupQueued)
    end

    if frameOpt.missingAura then
        local function checkRange(frame)
            local unit = frame.unit
            if not unit or not frame_registry[frame] or not (UnitIsPlayer(unit) or UnitInPartyIsAI(unit)) then
                return
            end
            -- Aura:SetAuraVar(frame, "buffsAll", frame_registry[frame].allaura, onUpdateMissingAuras, missingAuraAll)

            local class = select(2, UnitClass(frame.unit))
            if class then
                groupClassRangeIn[class] = groupClassRangeIn[class] or {}
                local classExists = next(groupClassRangeIn[class]) and true or false
                groupClassRangeIn[class][frame] = (UnitIsUnit(frame.unit, "player") and true) or (UnitInRange(frame.unit) and true or nil)
                if classExists ~= (next(groupClassRangeIn[class]) ~= nil) then
                    for frame2 in pairs(frame_registry) do
                        if frame2.unit and frame_registry[frame2] and (UnitIsPlayer(frame2.unit) or UnitInPartyIsAI(frame2.unit)) then
                            onUpdateMissingAuras(frame2)
                        end
                    end
                    return
                end
            end

            onUpdateMissingAuras(frame)
        end
        if frameOpt.missingAuraRangeCheck then
            self:HookFuncFiltered("CompactUnitFrame_UpdateInRange", checkRange)
        end

        if frameOpt.missingAuraNotCombat then
            self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
                for frame, v in pairs(frame_registry) do
                    if frame.unit and UnitIsPlayer(frame.unit) or UnitInPartyIsAI(frame.unit) then
                        onUpdateMissingAuras(frame)
                    end
                end
            end)

            self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
                for frame, v in pairs(frame_registry) do
                    if frame.unit and UnitIsPlayer(frame.unit) or UnitInPartyIsAI(frame.unit) then
                        onUpdateMissingAuras(frame)
                    end
                end
            end)
        end
    end

    if frameOpt.sotf then
        self:RegisterEvent("UNIT_STATS", function(event, unit)
            if not unitFrame[unit] or next(unitFrame[unit]) == nil then
                return
            end
            for frame in pairs(unitFrame[unit]) do
                classMod:init(frame)
            end
        end)
    end

    local function groupInit(frame)
        if frame.unit and (UnitIsPlayer(frame.unit) or UnitInPartyIsAI(frame.unit) or (frameOpt.petframe and frame.unit:match("pet"))) then
            onFrameSetup(frame)
            if frame_registry[frame] then
                unitFrame[frame.unit] = unitFrame[frame.unit] or {}
                unitFrame[frame.unit][frame] = true
            end
            if not frame.unit:match("pet") then
                local class = select(2, UnitClass(frame.unit))
                if class then
                    groupClass[class] = groupClass[class] or {}
                    groupClass[class][frame] = true
                    groupClassRangeIn[class] = groupClassRangeIn[class] or {}
                    groupClassRangeIn[class][frame] = (UnitIsUnit(frame.unit, "player") and true) or (UnitInRange(frame.unit) and true or nil)
                end
            end
            classMod:init(frame)
        end
    end

    self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        C_Timer.After(0, function()
            groupClass = {}
            groupClassRangeIn = {}
            unitFrame = {}
            -- 그룹정리 먼저
            addon:IterateRoster(groupInit)

            if frameOpt.missingAura then
                addon:IterateRoster(function(frame)
                    if frame.unit and (UnitIsPlayer(frame.unit) or UnitInPartyIsAI(frame.unit)) then
                        Queue:add(function(frame)
                            Aura:SetAuraVar(frame, "buffsAll", frame_registry[frame].allaura, onUpdateMissingAuras, missingAuraAll)
                        end, frame)
                    end
                end)
            end
            classMod:rosterUpdate()
        end)
    end)

    if frameOpt.petframe then
        self:RegisterEvent("UNIT_PET", function(event, unit)
            local petunit = unitToPetUnit[unit]
            if not petunit then
                return
            end
            Queue:add(function(unit)
                if not unitFrame[unit] or next(unitFrame[unit]) == nil then
                    addon:IterateRoster(function(frame)
                        if frame.unit == unit then
                            unitFrame[unit] = unitFrame[unit] or {}
                            unitFrame[unit][frame] = true
                        end
                    end)
                    if not unitFrame[unit] or next(unitFrame[unit]) == nil then
                        return
                    end
                end
                for frame in pairs(unitFrame[unit]) do
                    if UnitExists(unit) then
                        initRegistry(frame)
                        Aura:SetAuraVar(frame, "buffs", frame_registry[frame].buffs, onUpdateAuras)
                    else
                        Aura:SetAuraVar(frame, "buffs")
                    end
                end
            end, petunit)
        end)
    end

    addon:IterateRoster(function(frame)
        if not frameOpt.petframe then
            local fname = frame:GetName()
            if not fname or fname:match("Pet") then
                return
            end
        end
        onFrameSetup(frame)
    end)

    groupClass = {}
    groupClassRangeIn = {}
    unitFrame = {}
    for frame, v in pairs(frame_registry) do
        groupInit(frame)
    end

    local function init(frame)
        onFrameSetup(frame)
        if frame.unit then
            if frame.unitExists and frame:IsShown() and not frame:IsForbidden() then
                if frameOpt.missingAura and frame.unit and (UnitIsPlayer(frame.unit) or UnitInPartyIsAI(frame.unit)) then
                    if not onUpdateMissingAuras(frame) then
                        onUpdateAuras(frame)
                    end
                else
                    onUpdateAuras(frame)
                end
            end
            if frameOpt.petframe and frame.unit:match("pet") then
                Aura:SetAuraVar(frame, "buffs", frame_registry[frame].buffs, onUpdateAuras)
            end
        end
        classMod:init(frame)
    end
    for frame, v in pairs(frame_registry) do
        v.dirty = true
        Queue:add(init, frame)
    end
end

--parts of this code are from FrameXML/CompactUnitFrame.lua
function Buffs:OnDisable()
    classMod:onDisable()
    self:DisableHooks()
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    self:UnregisterEvent("UNIT_STATS")
    self:UnregisterEvent("UNIT_PET")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    local restoreBuffFrames = function(frame)
        -- frame.optionTable.displayDebuffs = frame_registry[frame].displayBuffs
        Aura:SetAuraVar(frame, "buffs")
        Aura:SetAuraVar(frame, "buffsAll")
        for _, extraBuffFrame in pairs(frame_registry[frame].extraBuffFrames) do
            onUnsetBuff(extraBuffFrame)
        end

        local isPowerBarShowing = frame.powerBar and frame.powerBar:IsShown()
        local powerBarUsedHeight = isPowerBarShowing and 8 or 0
        local buffPos, buffRelativePoint, buffOffset = "BOTTOMRIGHT", "BOTTOMLEFT", CUF_AURA_BOTTOM_OFFSET + powerBarUsedHeight
        frame.buffFrames[1]:SetPoint(buffPos, frame, "BOTTOMRIGHT", -3, buffOffset)
        for i = 1, #frame.buffFrames do
            if i > 1 then
                frame.buffFrames[i]:SetPoint(buffPos, frame.buffFrames[i - 1], buffRelativePoint, 0, 0)
            end
            frame.buffFrames[i].cooldown:SetDrawSwipe(true)
        end

        if frame.unit and frame.unitExists and frame:IsShown() and not frame:IsForbidden() then
            CompactUnitFrame_UpdateAuras(frame)
        end
    end
    for frame in pairs(frame_registry) do
        restoreBuffFrames(frame)
    end
    Aura:reset()
end

local testauras = {}

function Buffs:test()
    if testmodeTicker then
        testmodeTicker:Cancel()
        testmodeTicker = nil
        -- 테스트 버프 삭제

        for frame, registry in pairs(frame_registry) do
            if registry.buffs then
                for spellId, v in pairs(testauras) do
                    local auraInstanceID = -spellId
                    if registry.buffs[auraInstanceID] then
                        registry.buffs[auraInstanceID] = nil
                    end
                end
                onUpdateAuras(frame)
            end
        end

        return
    end

    testauras = {
        [774] = {
            duration = 15,
            maxstack = 1,
        },
        [8936] = {
            duration = 12,
            maxstack = 1,
        },
        [188550] = {
            duration = 15,
            maxstack = 1,
        },
        [391891] = {
            duration = 12,
            maxstack = 3,
        },
    }

    for k, v in pairs(addon.filteredAuras) do
        if not v.debuff and v.show and not testauras[k] then
            testauras[k] = {
                duration = random(10, 20),
                maxstack = random(1, 3),
            }
        end
    end

    local conf = addon.db.profile.Buffs

    --increase
    local increase = {}
    for spellId, value in pairs(conf.Increase) do
        local k = tonumber(spellId)
        if k and not testauras[k] then
            testauras[k] = {
                duration = random(10, 20),
                maxstack = random(1, 3),
            }
        end
    end
    --user placed
    for _, auraInfo in pairs(conf.AuraPosition) do
        local k = auraInfo.spellId
        if k and not testauras[k] then
            testauras[k] = {
                duration = random(10, 20),
                maxstack = random(1, 3),
            }
        end
    end
    --auras group
    for _, auraInfo in pairs(conf.AuraGroup) do
        for spellId, v in pairs(auraInfo.auraList) do
            local k = tonumber(spellId)
            if k and not testauras[k] then
                testauras[k] = {
                    duration = random(10, 20),
                    maxstack = random(1, 3),
                }
            end
        end
    end

    local fakeaura = function()
        local now = GetTime()
        for frame, registry in pairs(frame_registry) do
            if registry.buffs then
                local displayOnlyDispellableDebuffs = false
                local ignoreBuffs = not frame.optionTable.displayBuffs or registry.maxBuffs == 0
                local ignoreDebuffs = true
                local ignoreDispelDebuffs = true

                for spellId, v in pairs(testauras) do
                    local auraInstanceID = -spellId
                    if registry.buffs[auraInstanceID] then
                        if registry.buffs[auraInstanceID].expirationTime < now then
                            registry.buffs[auraInstanceID] = nil
                        end
                    end
                    if not registry.buffs[auraInstanceID] then
                        local aura = addon:makeFakeAura(spellId, {
                            isHelpful               = true,                                       --boolean	Whether or not this aura is a buff.
                            canApplyAura            = true,                                       --boolean	Whether or not the player can apply this aura.
                            isFromPlayerOrPlayerPet = true,                                       --boolean	Whether or not this aura was applied by a player or their pet.
                            sourceUnit              = "player",                                   --string?	Token of the unit that applied the aura.
                            applications            = random(1, v.maxstack),                      --number	
                            duration                = v.duration,                                 --number	
                            expirationTime          = v.duration > 0 and (now + v.duration) or 0, --number	
                        })
                        local type = CompactUnitFrame_ProcessAura(frame, aura, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)
                        if type == AuraUtil.AuraUpdateChangedType.Buff then
                            registry.buffs[auraInstanceID] = aura
                        end
                    end
                end
                onUpdateAuras(frame)
            end
        end
    end
    testmodeTicker = C_Timer.NewTicker(1, fakeaura)
    fakeaura()
end
