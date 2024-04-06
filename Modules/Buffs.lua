--[[
    Created by Slothpala
--]]

local _, addonTable = ...
local addon = addonTable.RaidFrameSettings
local Buffs = addon:NewModule("Buffs")
Mixin(Buffs, addonTable.hooks)
local CDT = addonTable.cooldownText
local Glow = addonTable.Glow
local Aura = addonTable.Aura
local classMod = addonTable.classMod
local Media = LibStub("LibSharedMedia-3.0")

local AuraFilter = addon:GetModule("AuraFilter")

-- WoW Api

-- Lua
local next = next

local frame_registry = {}
local roster_changed = true
local glowOpt

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

    CDT.TimerTextLimit = addon.db.profile.MinorModules.TimerTextLimit

    glowOpt = CopyTable(addon.db.profile.MinorModules.Glow)
    glowOpt.type = addon:ConvertDbNumberToGlowType(glowOpt.type)

    local frameOpt = CopyTable(addon.db.profile.Buffs.BuffFramesDisplay)
    frameOpt.petframe = addon.db.profile.Buffs.petframe
    frameOpt.sotf = addon.db.profile.Buffs.sotf
    frameOpt.mastery = addon.db.profile.Buffs.mastery
    frameOpt.framestrata = addon:ConvertDbNumberToFrameStrata(frameOpt.framestrata)
    frameOpt.baseline = addon:ConvertDbNumberToBaseline(frameOpt.baseline)
    frameOpt.type = frameOpt.baricon and "baricon" or "blizzard"

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

    local onSetBuff = function(buffFrame, aura, opt)
        if buffFrame:IsForbidden() then --not sure if this is still neede but when i created it at the start if dragonflight it was
            return
        end
        local parent = buffFrame:GetParent()
        if not parent or not frame_registry[parent] then
            return
        end

        if buffFrame.aura == aura and buffFrame:IsShown() then
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

    local onUpdateAuras = function(frame)
        if not frame_registry[frame] or frame:IsForbidden() or not frame:IsVisible() then
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
                    self:Glow(buffFrame, false)
                    buffFrame:UnsetAura()
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
                if not buffFrame:IsShown() then
                    break
                end
                self:Glow(buffFrame, false)
                buffFrame:UnsetAura()
            end
        end
    end
    self:HookFunc("CompactUnitFrame_UpdateAuras", onUpdateAuras)

    local function initRegistry(frame)
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
            userPlacedShown = {},
            dirty           = true,
        }
    end

    local function onFrameSetup(frame)
        if not (frame.unit:match("pet") and frameOpt.petframe) and not UnitIsPlayer(frame.unit) and not UnitInPartyIsAI(frame.unit) then
            return
        end

        if not frame_registry[frame] then
            initRegistry(frame)
        end

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
        end

        for _, v in pairs(frame.buffFrames) do
            v:ClearAllPoints()
            v.cooldown:SetDrawSwipe(false)
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

        -- frame_registry[frame].displayBuffs = frame.optionTable.displayBuffs
        -- frame.optionTable.displayBuffs = false
        -- Aura:SetAuraVar(frame, "buffs", frame_registry[frame].buffs, onUpdateAuras)
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
                initRegistry(frame)
            end
        end)
    end
    for frame, v in pairs(frame_registry) do
        v.dirty = true
        onFrameSetup(frame)
        if frame.unit then
            if frame.unitExists and frame:IsShown() and not frame:IsForbidden() then
                onUpdateAuras(frame)
            end
            if frameOpt.petframe and frame.unit:match("pet") then
                Aura:SetAuraVar(frame, "buffs", frame_registry[frame].buffs, onUpdateAuras)
            end
        end
        classMod:init(frame)
    end

    self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        roster_changed = true
        C_Timer.After(0, function()
            classMod:rosterUpdate()
        end)
    end)

    if frameOpt.petframe then
        self:HookFunc("CompactUnitFrame_SetUnit", function(frame, unit)
            if not unit or not unit:match("pet") or not frame_registry[frame] then
                return
            end
            Aura:SetAuraVar(frame, "buffs", frame_registry[frame].buffs, onUpdateAuras)
        end)
    end
end

--parts of this code are from FrameXML/CompactUnitFrame.lua
function Buffs:OnDisable()
    classMod:onDisable()
    self:DisableHooks()
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    roster_changed = true

    local restoreBuffFrames = function(frame)
        -- frame.optionTable.displayDebuffs = frame_registry[frame].displayBuffs
        Aura:SetAuraVar(frame, "buffs")
        for _, extraBuffFrame in pairs(frame_registry[frame].extraBuffFrames) do
            extraBuffFrame:UnsetAura()
            self:Glow(extraBuffFrame, false)
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
        frame_registry[frame].buffs:Clear()
        frame_registry[frame].debuffs = nil
    end
    for frame in pairs(frame_registry) do
        restoreBuffFrames(frame)
    end
    CDT:DisableCooldownText()
    Aura:reset()
end
