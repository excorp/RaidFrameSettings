--[[
    Created by Slothpala
    The aura indicator position and the aura timers are greatly inspired by a pull request from: https://github.com/excorp
--]]
local _, addonTable = ...
local isVanilla, isWrath, isClassic, isRetail = addonTable.isVanilla, addonTable.isWrath, addonTable.isClassic, addonTable.isRetail
local addon = addonTable.RaidFrameSettings
local Debuffs = addon:NewModule("Debuffs")
Mixin(Debuffs, addonTable.hooks)
local CDT = addonTable.cooldownText
local Glow = addonTable.Glow
local Aura = addonTable.Aura
local Media = LibStub("LibSharedMedia-3.0")

local fontObj = CreateFont("RaidFrameSettingsFont")

--Debuffframe size
--They don't exist in classic
local NATIVE_UNIT_FRAME_HEIGHT = 36
local NATIVE_UNIT_FRAME_WIDTH = 72
--WoW Api
local UnitDebuff = UnitDebuff
local SetSize = SetSize
local SetTexCoord = SetTexCoord
local ClearAllPoints = ClearAllPoints
local SetPoint = SetPoint
local SetFont = SetFont
local SetTextColor = SetTextColor
local SetShadowColor = SetShadowColor
local SetShadowOffset = SetShadowOffset
local SetDrawSwipe = SetDrawSwipe
local SetReverse = SetReverse
local SetDrawEdge = SetDrawEdge
local SetScale = SetScale
-- Lua
local next = next
local select = select

local frame_registry = {}
local roster_changed = true

local glowOpt

function Debuffs:Glow(frame, onoff)
    if onoff then
        Glow:Start(glowOpt, frame)
    else
        Glow:Stop(glowOpt, frame)
    end
end

function Debuffs:OnEnable()
    local debuffColors = {
        Curse   = { r = 0.6, g = 0.0, b = 1.0, a = 1 },
        Disease = { r = 0.6, g = 0.4, b = 0.0, a = 1 },
        Magic   = { r = 0.2, g = 0.6, b = 1.0, a = 1 },
        Poison  = { r = 0.0, g = 0.6, b = 0.0, a = 1 },
        Bleed   = { r = 0.8, g = 0.0, b = 0.0, a = 1 },
    }
    local Bleeds = addonTable.Bleeds

    local dbObj = addon.db.profile.MinorModules.DebuffColors
    debuffColors.Curse = dbObj.Curse
    debuffColors.Disease = dbObj.Disease
    debuffColors.Magic = dbObj.Magic
    debuffColors.Poison = dbObj.Poison
    debuffColors.Bleed = dbObj.Bleed

    CDT.TimerTextLimit = addon.db.profile.MinorModules.TimerTextLimit

    glowOpt = CopyTable(addon.db.profile.MinorModules.Glow)
    glowOpt.type = addon:ConvertDbNumberToGlowType(glowOpt.type)

    local frameOpt = CopyTable(addon.db.profile.Debuffs.DebuffFramesDisplay)
    frameOpt.petframe = addon.db.profile.Debuffs.petframe
    frameOpt.framestrata = addon:ConvertDbNumberToFrameStrata(frameOpt.framestrata)
    frameOpt.baseline = addon:ConvertDbNumberToBaseline(frameOpt.baseline)
    frameOpt.type = frameOpt.baricon and "baricon" or "blizzard"
    frameOpt.dispelPoint = addon:ConvertDbNumberToPosition(frameOpt.dispelPoint)

    --Timer
    local durationOpt = CopyTable(addon.db.profile.Debuffs.DurationDisplay) --copy is important so that we dont overwrite the db value when fetching the real values
    durationOpt.font = Media:Fetch("font", durationOpt.font)
    durationOpt.outlinemode = addon:ConvertDbNumberToOutlinemode(durationOpt.outlinemode)
    durationOpt.point = addon:ConvertDbNumberToPosition(durationOpt.point)
    durationOpt.relativePoint = addon:ConvertDbNumberToPosition(durationOpt.relativePoint)
    -- Stack display options
    local stackOpt = CopyTable(addon.db.profile.Debuffs.StacksDisplay)
    stackOpt.font = Media:Fetch("font", stackOpt.font)
    stackOpt.outlinemode = addon:ConvertDbNumberToOutlinemode(stackOpt.outlinemode)
    stackOpt.point = addon:ConvertDbNumberToPosition(stackOpt.point)
    stackOpt.relativePoint = addon:ConvertDbNumberToPosition(stackOpt.relativePoint)

    Aura.Opt.Debuff.frameOpt = frameOpt
    Aura.Opt.Debuff.durationOpt = durationOpt
    Aura.Opt.Debuff.stackOpt = stackOpt

    --aura filter
    local filteredAuras = {}
    if addon:IsModuleEnabled("AuraFilter") and addon:IsModuleEnabled("Debuffs") then
        for spellId, value in pairs(addon.db.profile.AuraFilter.Debuffs) do
            filteredAuras[tonumber(spellId)] = value
        end
    end
    --increase
    local increase = {}
    for spellId, value in pairs(addon.db.profile.Debuffs.Increase) do
        increase[tonumber(spellId)] = true
    end
    --user placed
    local userPlaced = {} --i will bring this at a later date for Debuffs including position and size
    local userPlacedIdx = 1
    local maxUserPlaced = 0
    for _, auraInfo in pairs(addon.db.profile.Debuffs.AuraPosition) do
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
    for k, auraInfo in pairs(addon.db.profile.Debuffs.AuraGroup) do
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
    --Debuffframe size
    local width       = frameOpt.width
    local height      = frameOpt.height
    local boss_width  = width * frameOpt.increase
    local boss_height = height * frameOpt.increase


    --Debuffframe position
    local point = addon:ConvertDbNumberToPosition(frameOpt.point)
    local relativePoint = addon:ConvertDbNumberToPosition(frameOpt.relativePoint)
    local followPoint, followRelativePoint, followOffsetX, followOffsetY = addon:GetAuraGrowthOrientationPoints(frameOpt.orientation, frameOpt.gap, frameOpt.baseline)

    local comparePriority = function(a, b)
        return a.priority > b.priority
    end

    local onSetDebuff = function(debuffFrame, unit, index, filter, isBossAura, isBossBuff, opt)
        if debuffFrame:IsForbidden() then --not sure if this is still neede but when i created it at the start if dragonflight it was
            return
        end
        local parent = debuffFrame:GetParent()
        if not parent or not frame_registry[parent] then
            return
        end
        debuffFrame:SetID(index)
        debuffFrame.filter = filter
        debuffFrame.isBossBuff = isBossBuff
        local name, icon, applications, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId
        if isBossBuff then
            name, icon, applications, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId = UnitBuff(unit, index, filter)
        else
            name, icon, applications, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId = UnitDebuff(unit, index, filter)
        end

        local aurastored = frame_registry[parent].aura
        local auraInstanceID = (unitCaster or "X") .. "_" .. spellId
        local refresh
        if aurastored[auraInstanceID] then
            if frameOpt.refreshAni then
                if math.abs(expirationTime - aurastored[auraInstanceID].expirationTime) > 1 or aurastored[auraInstanceID].applications ~= applications then
                    refresh = true
                end
            end
            local obj          = aurastored[auraInstanceID]
            obj.applications   = applications
            obj.duration       = duration
            obj.expirationTime = expirationTime
            obj.refresh        = refresh
        else
            aurastored[auraInstanceID] = {
                name            = name,
                icon            = icon,
                applications    = applications,
                debuffType      = debuffType,
                duration        = duration,
                expirationTime  = expirationTime,
                unitCaster      = unitCaster,
                canStealOrPurge = canStealOrPurge,
                spellId         = spellId,
                auraInstanceID  = auraInstanceID,
                refresh         = refresh,
            }
        end

        -- icon, stack, cooldown(duration) start
        debuffFrame:SetAura(aurastored[auraInstanceID])

        local color = durationOpt.fontColor
        if debuffType then
            color = debuffColors[debuffType]
        end
        if Bleeds and Bleeds[spellId] then
            color = debuffColors.Bleed
        end
        debuffFrame:SetBorderColor(color.r, color.g, color.b, color.a)

        if not durationOpt.durationByDebuffColor then
            color = durationOpt.fontColor
        end
        local cooldownText = CDT:CreateOrGetCooldownFontString(debuffFrame.cooldown)
        cooldownText:SetVertexColor(color.r, color.g, color.b, color.a)

        local auraGroupNo = auraGroupList[spellId]
        if userPlaced[spellId] and userPlaced[spellId].setSize then
            debuffFrame:SetSize(userPlaced[spellId].width, userPlaced[spellId].height)
        elseif auraGroupNo and auraGroup[auraGroupNo].setSize then
            local group = auraGroup[auraGroupNo]
            debuffFrame:SetSize(group.width, group.height)
        elseif isBossAura or increase[spellId] then
            debuffFrame:SetSize(boss_width, boss_height)
        else
            debuffFrame:SetSize(width, height)
        end

        self:Glow(debuffFrame, opt.glow)
        debuffFrame:SetAlpha(opt.alpha or 1)
    end

    local dispellableDebuffTypes = { Magic = true, Curse = true, Disease = true, Poison = true }

    local onUpdateAuras = function(frame)
        if not frame_registry[frame] or frame:IsForbidden() or not frame:IsVisible() then
            return
        end

        -- set placed aura / other aura
        local index = 1
        local frameNum = 1
        local groupFrameNum = {}
        local filter = nil
        local sorted = {
            [0] = {},
        }
        local userPlacedShown = {}
        local dispelFrameNum = 1
        local dispelDisplayed = {}
        while true do
            local debuffName, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId = UnitDebuff(frame.displayedUnit, index, filter)
            if not debuffName then
                break
            end
            local isBossAura = CompactUnitFrame_UtilIsBossAura(frame.displayedUnit, index, filter, false)
            local isBossBuff = CompactUnitFrame_UtilIsBossAura(frame.displayedUnit, index, filter, true)

            if frameOpt.showDispel and debuffType and dispellableDebuffTypes[debuffType] and not dispelDisplayed[debuffType] and dispelFrameNum <= frame.maxDispelDebuffs then
                local dispelFrame = frame.dispelDebuffFrames[dispelFrameNum]
                CompactUnitFrame_UtilSetDispelDebuff(dispelFrame, debuffType, index)
                dispelDisplayed[debuffType] = true
                dispelFrameNum = dispelFrameNum + 1
            end

            if CompactUnitFrame_UtilShouldDisplayDebuff(frame.displayedUnit, index, filter) then
                if userPlaced[spellId] then
                    local idx = frame_registry[frame].placedAuraStart + userPlaced[spellId].idx - 1
                    local debuffFrame = frame_registry[frame].extraDebuffFrames[idx]
                    local placed = userPlaced[spellId]
                    onSetDebuff(debuffFrame, frame.displayedUnit, index, filter, isBossAura, isBossBuff, placed)
                    userPlacedShown[debuffFrame] = true
                elseif auraGroupList[spellId] then
                    local groupNo = auraGroupList[spellId]
                    local auraList = auraGroup[groupNo].auraList
                    local auraOpt = auraList[spellId]
                    local priority = auraOpt.priority > 0 and auraOpt.priority or filteredAuras[spellId] and filteredAuras[spellId].priority or 0
                    if not sorted[groupNo] then sorted[groupNo] = {} end
                    tinsert(sorted[groupNo], { spellId = spellId, priority = priority, index = index, isBossAura = isBossAura, isBossBuff = isBossBuff, opt = auraOpt })
                    groupFrameNum[groupNo] = groupFrameNum[groupNo] and (groupFrameNum[groupNo] + 1) or 2
                else
                    local filtered = filteredAuras[spellId]
                    local priority = filtered and filtered.priority or 0
                    tinsert(sorted[0], { spellId = spellId, priority = priority, index = index, isBossAura = isBossAura, isBossBuff = isBossBuff, opt = filtered or {} })
                end
            end
            index = index + 1
        end
        -- set buffs after sorting to priority.
        for _, v in pairs(sorted) do
            table.sort(v, comparePriority)
        end
        for groupNo, auralist in pairs(sorted) do
            for k, v in pairs(auralist) do
                if groupNo == 0 then
                    if frameNum > frame_registry[frame].maxDebuffs then
                        break
                    end
                    frameNum = k + 1
                    -- default aura frame
                    local debuffFrame = frame_registry[frame].extraDebuffFrames[k]
                    onSetDebuff(debuffFrame, frame.displayedUnit, v.index, filter, v.isBossAura, v.isBossBuff, v.opt)
                else
                    -- aura group frame
                    local idx = frame_registry[frame].auraGroupStart[groupNo] + k - 1
                    local debuffFrame = frame_registry[frame].extraDebuffFrames[idx]
                    onSetDebuff(debuffFrame, frame.displayedUnit, v.index, filter, v.isBossAura, v.isBossBuff, v.opt)
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
                    local parent = frame_registry[frame].extraDebuffFrames[idx]
                    child.frame:ClearAllPoints()
                    child.frame:SetPoint(child.conf.point, parent, child.conf.relativePoint, child.conf.xOffset, child.conf.yOffset)
                end
            end
        end

        -- hide left aura frames
        for debuffFrame in pairs(frame_registry[frame].userPlacedShown) do
            if not userPlacedShown[debuffFrame] then
                if not debuffFrame.auraInstanceID or not (frame.buffs[debuffFrame.auraInstanceID] or frame_registry[frame].buffs[debuffFrame.auraInstanceID]) then
                    self:Glow(debuffFrame, false)
                    debuffFrame:UnsetAura()
                    frame_registry[frame].aura[debuffFrame.auraInstanceID] = nil
                else
                    userPlacedShown[debuffFrame] = true
                end
            end
        end
        frame_registry[frame].userPlacedShown = userPlacedShown
        for i = frameNum, frame_registry[frame].maxDebuffs do
            local debuffFrame = frame_registry[frame].extraDebuffFrames[i]
            self:Glow(debuffFrame, false)
            if not debuffFrame:IsShown() then
                break
            end
            debuffFrame:UnsetAura()
            if debuffFrame.auraInstanceID and frame_registry[frame].aura[debuffFrame.auraInstanceID] then
                frame_registry[frame].aura[debuffFrame.auraInstanceID] = nil
            end
        end
        -- Modify the anchor of an auraGroup and hide left aura group
        for groupNo, v in pairs(auraGroup) do
            if groupFrameNum[groupNo] and groupFrameNum[groupNo] > 0 then
                if v.orientation == 5 or v.orientation == 6 then
                    local idx = frame_registry[frame].auraGroupStart[groupNo]
                    local debuffFrame = frame_registry[frame].extraDebuffFrames[idx]
                    local x, y = 0, 0
                    for i = 2, groupFrameNum[groupNo] - 1 do
                        local idx = frame_registry[frame].auraGroupStart[groupNo] + i - 1
                        local debuffFrame = frame_registry[frame].extraDebuffFrames[idx]
                        local w, h = debuffFrame:GetSize()
                        if v.orientation == 5 then
                            x = x + w
                        elseif v.orientation == 6 then
                            y = y + h
                        end
                    end
                    debuffFrame:ClearAllPoints()
                    debuffFrame:SetPoint(v.point, frame, v.relativePoint, v.xOffset - x / 2, v.yOffset + y / 2)
                end
            end
            local groupSize = frame_registry[frame].auraGroupEnd[groupNo] - frame_registry[frame].auraGroupStart[groupNo] + 1
            for i = groupFrameNum[groupNo] or 1, groupSize do
                local idx = frame_registry[frame].auraGroupStart[groupNo] + i - 1
                local debuffFrame = frame_registry[frame].extraDebuffFrames[idx]
                if not debuffFrame:IsShown() then
                    break
                end
                self:Glow(debuffFrame, false)
                debuffFrame:UnsetAura()
                if debuffFrame.auraInstanceID and frame_registry[frame].aura[debuffFrame.auraInstanceID] then
                    frame_registry[frame].aura[debuffFrame.auraInstanceID] = nil
                end
            end
        end

        if frameOpt.showDispel then
            for i = dispelFrameNum, frame.maxDispelDebuffs do
                local dispelFrame = frame.dispelDebuffFrames[i]
                if not dispelFrame:IsShown() then
                    break
                end
                dispelFrame:Hide()
            end
        end
    end
    self:HookFunc("CompactUnitFrame_UpdateAuras", onUpdateAuras)

    local function initRegistry(frame)
        frame_registry[frame] = {
            maxDebuffs        = frameOpt.maxdebuffs,
            placedAuraStart   = 0,
            auraGroupStart    = {},
            auraGroupEnd      = {},
            extraDebuffFrames = {},
            reanchor          = {},
            aura              = {},
            userPlacedShown   = {},
            dirty             = true,
        }
    end

    local function onFrameSetup(frame)
        if not frameOpt.petframe then
            local fname = frame:GetName()
            if not fname or fname:match("Pet") then
                return
            end
        end

        if not frame_registry[frame] then
            initRegistry(frame)
        end

        if frame_registry[frame].dirty then
            frame_registry[frame].maxDebuffs = frameOpt.maxdebuffs
            frame_registry[frame].dirty = false
            local placedAuraStart = frame.maxDebuffs + 1
            for i = 1, frame_registry[frame].maxDebuffs do
                local debuffFrame, dirty = Aura:createAuraFrame(frame, "Debuff", frameOpt.type, i) -- category:Buff,Debuff, type=blizzard,baricon
                frame_registry[frame].extraDebuffFrames[i] = debuffFrame
                frame_registry[frame].dirty = dirty
                debuffFrame:ClearAllPoints()
                debuffFrame.icon:SetTexCoord(0, 1, 0, 1)
                placedAuraStart = i + 1
            end
            frame_registry[frame].placedAuraStart = placedAuraStart

            for i = 1, maxUserPlaced + maxAuraGroup do
                local idx = placedAuraStart + i - 1
                local debuffFrame, dirty = Aura:createAuraFrame(frame, "Debuff", frameOpt.type, idx) -- category:Buff,Debuff, type=blizzard,baricon
                frame_registry[frame].extraDebuffFrames[idx] = debuffFrame
                frame_registry[frame].dirty = dirty
                debuffFrame:ClearAllPoints()
                debuffFrame.icon:SetTexCoord(0, 1, 0, 1)
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
                        frame = frame_registry[frame].extraDebuffFrames[idx],
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
                        frame = frame_registry[frame].extraDebuffFrames[idx],
                        conf  = v,
                    })
                end
            end
        end

        -- set anchor and resize
        local anchorSet, prevFrame
        for i = 1, frame_registry[frame].maxDebuffs do
            local debuffFrame = frame_registry[frame].extraDebuffFrames[i]
            if not anchorSet then
                local parent = (frameOpt.frame == 2 and frame.healthBar) or (frameOpt.frame == 3 and frame.powerBar) or frame
                debuffFrame:ClearAllPoints()
                debuffFrame:SetPoint(point, parent, relativePoint, frameOpt.xOffset, frameOpt.yOffset)
                anchorSet = true
            else
                debuffFrame:ClearAllPoints()
                debuffFrame:SetPoint(followPoint, prevFrame, followRelativePoint, followOffsetX, followOffsetY)
            end
            prevFrame = debuffFrame
            debuffFrame:SetSize(width, height)
            debuffFrame:SetCoord(width, height)
        end
        local idx = frame_registry[frame].placedAuraStart - 1
        for _, place in pairs(userPlaced) do
            idx = frame_registry[frame].placedAuraStart + place.idx - 1
            local debuffFrame = frame_registry[frame].extraDebuffFrames[idx]
            local parentIdx = (place.frame == 2 and place.frameNo > 0 and userPlaced[place.frameNo] and (frame_registry[frame].placedAuraStart + userPlaced[place.frameNo].idx - 1)) or
                (place.frame == 3 and place.frameNo > 0 and auraGroup[place.frameNo] and (frame_registry[frame].auraGroupStart[place.frameNo] + place.frameNoNo - 1))
            local parent = parentIdx and frame_registry[frame].extraDebuffFrames[parentIdx] or place.frame == 4 and frame.healthBar or frame
            debuffFrame:ClearAllPoints()
            debuffFrame:SetPoint(place.point, parent, place.relativePoint, place.xOffset, place.yOffset)
            debuffFrame:SetSize(width, height)
            debuffFrame:SetCoord(width, height)
        end
        for k, v in pairs(auraGroup) do
            frame_registry[frame].auraGroupStart[k] = idx + 1
            local followPoint, followRelativePoint, followOffsetX, followOffsetY = addon:GetAuraGrowthOrientationPoints(v.orientation, v.gap, "")
            anchorSet, prevFrame = false, nil
            for _ = 1, v.maxAuras do
                idx = idx + 1
                local debuffFrame = frame_registry[frame].extraDebuffFrames[idx]
                if not anchorSet then
                    local parentIdx = (v.frame == 2 and v.frameNo > 0 and userPlaced[v.frameNo] and (frame_registry[frame].placedAuraStart + userPlaced[v.frameNo].idx - 1)) or
                        (v.frame == 3 and v.frameNo > 0 and auraGroup[v.frameNo] and (frame_registry[frame].auraGroupStart[v.frameNo] + v.frameNoNo - 1))
                    local parent = parentIdx and frame_registry[frame].extraDebuffFrames[parentIdx] or v.frame == 4 and frame.healthBar or frame
                    debuffFrame:ClearAllPoints()
                    debuffFrame:SetPoint(v.point, parent, v.relativePoint, v.xOffset, v.yOffset)
                    anchorSet = true
                else
                    debuffFrame:ClearAllPoints()
                    debuffFrame:SetPoint(followPoint, prevFrame, followRelativePoint, followOffsetX, followOffsetY)
                end
                prevFrame = debuffFrame
                debuffFrame:SetSize(width, height)
                debuffFrame:SetCoord(width, height)
            end
            frame_registry[frame].auraGroupEnd[k] = idx
        end

        frame.dispelDebuffFrames[1]:ClearAllPoints()
        frame.dispelDebuffFrames[1]:SetPoint(frameOpt.dispelPoint, frame, frameOpt.dispelPoint, frameOpt.dispelXOffset, frameOpt.dispelYOffset)
        local followPoint, followRelativePoint = addon:GetAuraGrowthOrientationPoints(frameOpt.dispelOrientation)
        for i = 1, #frame.dispelDebuffFrames do
            if (i > 1) then
                frame.dispelDebuffFrames[i]:ClearAllPoints()
                frame.dispelDebuffFrames[i]:SetPoint(followPoint, frame.dispelDebuffFrames[i - 1], followRelativePoint)
            end
            frame.dispelDebuffFrames[i]:SetSize(frameOpt.dispelWidth, frameOpt.dispelHeight)
        end

        for _, v in pairs(frame.debuffFrames) do
            v:ClearAllPoints()
        end
    end
    self:HookFuncFiltered("DefaultCompactUnitFrameSetup", onFrameSetup)

    if frameOpt.petframe then
        self:HookFuncFiltered("DefaultCompactMiniFrameSetup", onFrameSetup)
    end

    if roster_changed then
        roster_changed = false
        addon:IterateRoster(function(frame)
            local fname = frame:GetName()
            if not fname or fname:match("Pet") then
                return
            end
            if not frame_registry[frame] then
                initRegistry(frame)
            end
        end)
    end
    for frame, v in pairs(frame_registry) do
        v.dirty = true
        onFrameSetup(frame)
        if frame.unit and frame.unitExists and frame:IsShown() and not frame:IsForbidden() then
            CompactUnitFrame_UpdateAuras(frame)
        end
    end

    self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        roster_changed = true
    end)
end

--parts of this code are from FrameXML/CompactUnitFrame.lua
function Debuffs:OnDisable()
    self:DisableHooks()
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    roster_changed = true
    local restoreDebuffFrames = function(frame)
        for _, extraDebuffFrame in pairs(frame_registry[frame].extraDebuffFrames) do
            extraDebuffFrame:Hide()
            self:Glow(extraDebuffFrame, false)
        end

        frame.dispelDebuffFrames[1]:SetPoint("TOPRIGHT", -3, -2)
        frame.dispelDebuffFrames[1]:ClearAllPoints()
        for i = 1, #frame.dispelDebuffFrames do
            if (i > 1) then
                frame.dispelDebuffFrames[i]:ClearAllPoints()
                frame.dispelDebuffFrames[i]:SetPoint("RIGHT", frame.dispelDebuffFrames[i - 1], "LEFT", 0, 0)
            end
            frame.dispelDebuffFrames[i]:SetSize(12, 12)
        end

        if frame.unit and frame.unitExists and frame:IsShown() and not frame:IsForbidden() then
            CompactUnitFrame_UpdateAuras(frame)
        end
    end
    for frame in pairs(frame_registry) do
        restoreDebuffFrames(frame)
    end
end
