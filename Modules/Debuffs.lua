--[[
    Created by Slothpala
    The aura indicator position and the aura timers are greatly inspired by a pull request from: https://github.com/excorp
--]]
local _, addonTable = ...
local addon = addonTable.RaidFrameSettings
local Debuffs = addon:NewModule("Debuffs")
Mixin(Debuffs, addonTable.hooks)
local Glow = addonTable.Glow
local Aura = addonTable.Aura
local Queue = addonTable.Queue
local Media = LibStub("LibSharedMedia-3.0")

local AuraFilter = addon:GetModule("AuraFilter")

--Debuffframe size
--WoW Api
local UnitIsPlayer = UnitIsPlayer
local UnitInPartyIsAI = UnitInPartyIsAI
local GetSpellInfo = GetSpellInfo
local CreateFrame = CreateFrame
local AuraUtil = AuraUtil
local TableUtil = TableUtil
local C_Timer = C_Timer
local GameTooltip = GameTooltip

-- Lua
local CopyTable = CopyTable
local GetTime = GetTime
local math = math
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tinsert = tinsert
local table = table
local random = random


local frame_registry = {}
local roster_changed = true
local glowOpt
local testmodeTicker
local onUpdateAuras

local function initRegistry(frame)
    if frame_registry[frame] then
        return
    end
    frame_registry[frame] = {
        maxDebuffs        = 0,
        placedAuraStart   = 0,
        auraGroupStart    = {},
        auraGroupEnd      = {},
        extraDebuffFrames = {},
        reanchor          = {},
        debuffs           = TableUtil.CreatePriorityTable(AuraUtil.UnitFrameDebuffComparator, TableUtil.Constants.AssociativePriorityTable),
        aura              = {},
        userPlacedShown   = {},
        dirty             = true,
    }
end

function Debuffs:Glow(frame, onoff)
    if onoff then
        Glow:Start(glowOpt, frame)
    else
        Glow:Stop(glowOpt, frame)
    end
end

function Debuffs:OnEnable()
    AuraFilter:reloadConf()

    local debuffColors = {
        Curse   = { r = 0.6, g = 0.0, b = 1.0 },
        Disease = { r = 0.6, g = 0.4, b = 0.0 },
        Magic   = { r = 0.2, g = 0.6, b = 1.0 },
        Poison  = { r = 0.0, g = 0.6, b = 0.0 },
        Bleed   = { r = 0.8, g = 0.0, b = 0.0 },
    }
    local Bleeds = addonTable.Bleeds

    Aura:setTimerLimit(addon.db.profile.MinorModules.TimerTextLimit)

    glowOpt = CopyTable(addon.db.profile.MinorModules.Glow)
    glowOpt.type = addon:ConvertDbNumberToGlowType(glowOpt.type)

    local frameOpt = CopyTable(addon.db.profile.Debuffs.DebuffFramesDisplay)
    frameOpt.petframe = addon.db.profile.Debuffs.petframe
    frameOpt.framestrata = addon:ConvertDbNumberToFrameStrata(frameOpt.framestrata)
    frameOpt.baseline = addon:ConvertDbNumberToBaseline(frameOpt.baseline)
    frameOpt.type = frameOpt.baricon and "baricon" or "blizzard"
    frameOpt.dispelPoint = addon:ConvertDbNumberToPosition(frameOpt.dispelPoint)

    local dbObj = addon.db.profile.MinorModules.DebuffColors
    debuffColors.Curse = dbObj.Curse
    debuffColors.Disease = dbObj.Disease
    debuffColors.Magic = dbObj.Magic
    debuffColors.Poison = dbObj.Poison
    debuffColors.Bleed = dbObj.Bleed

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
    local filteredAuras = addon.filteredAuras

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

    local onSetDebuff = function(debuffFrame, aura, opt)
        if not debuffFrame or debuffFrame:IsForbidden() then --not sure if this is still neede but when i created it at the start if dragonflight it was
            return
        end
        Queue:add(function(debuffFrame, aura, opt)
            if not debuffFrame or debuffFrame:IsForbidden() then --not sure if this is still neede but when i created it at the start if dragonflight it was
                return
            end
            local parent = debuffFrame:GetParent()
            if not parent or not frame_registry[parent] then
                return
            end

            if debuffFrame.aura == aura and debuffFrame:IsShown() then
                return
            end

            local aurastored = frame_registry[parent].aura
            if frameOpt.refreshAni and aurastored[aura.auraInstanceID] then
                if math.abs(aura.expirationTime - aurastored[aura.auraInstanceID].expirationTime) > 1 or aurastored[aura.auraInstanceID].applications ~= aura.applications then
                    aura.refresh = true
                end
            end
            aurastored[aura.auraInstanceID] = aura

            -- icon, stack, cooldown(duration) start
            debuffFrame.filter = aura.isRaid and AuraUtil.AuraFilters.Raid or nil
            debuffFrame:SetAura(aura)

            local color = durationOpt.fontColor
            if aura.dispelName then
                color = debuffColors[aura.dispelName]
            end
            if Bleeds[aura.spellId] then
                color = debuffColors.Bleed
            end
            debuffFrame:SetBorderColor(color.r, color.g, color.b, color.a)

            if not durationOpt.durationByDebuffColor then
                color = durationOpt.fontColor
            end
            local cooldownText = debuffFrame.cooldown._rfs_cd_text
            cooldownText:SetVertexColor(color.r, color.g, color.b, color.a)

            if aura then
                local auraGroupNo = auraGroupList[aura.spellId]
                if userPlaced[aura.spellId] and userPlaced[aura.spellId].setSize then
                    local placed = userPlaced[aura.spellId]
                    debuffFrame:SetSize(placed.width, placed.height)
                elseif auraGroupNo and auraGroup[auraGroupNo].setSize then
                    local group = auraGroup[auraGroupNo]
                    debuffFrame:SetSize(group.width, group.height)
                elseif aura.isBossAura or increase[aura.spellId] then
                    debuffFrame:SetSize(boss_width, boss_height)
                else
                    debuffFrame:SetSize(width, height)
                end
            end

            self:Glow(debuffFrame, opt.glow)
            debuffFrame:SetAlpha(opt.alpha or 1)
        end, debuffFrame, aura, opt)
    end

    local onUnsetDebuff = function(debuffFrame)
        Queue:runAndAdd(function(debuffFrame)
            if not debuffFrame then
                return
            end
            self:Glow(debuffFrame, false)
            debuffFrame:UnsetAura()
        end, debuffFrame)
    end

    local function onUpdatePrivateAuras(frame)
        if not frame or not frame.PrivateAuraAnchors or not frame_registry[frame] or frame:IsForbidden() or not frame:IsVisible() then
            return
        end
        Queue:add(function(frame)
            if not frame or not frame.PrivateAuraAnchors or not frame_registry[frame] or frame:IsForbidden() or not frame:IsVisible() then
                return
            end

            local lastShownDebuff
            for i = frame_registry[frame].maxDebuffs, 1, -1 do
                local debuff = frame_registry[frame].extraDebuffFrames[i]
                if debuff and debuff:IsShown() then
                    lastShownDebuff = debuff
                    break
                end
            end
            frame.PrivateAuraAnchor1:ClearAllPoints()
            if lastShownDebuff then
                local followPoint, followRelativePoint, followOffsetX, followOffsetY = addon:GetAuraGrowthOrientationPoints(frameOpt.orientation, frameOpt.gap + 3, frameOpt.baseline)
                frame.PrivateAuraAnchor1:SetPoint(followPoint, lastShownDebuff, followRelativePoint, followOffsetX, followOffsetY)
            else
                frame.PrivateAuraAnchor1:SetPoint(point, frame, relativePoint, frameOpt.xOffset, frameOpt.yOffset)
            end
            frame.PrivateAuraAnchor2:ClearAllPoints()
            frame.PrivateAuraAnchor2:SetPoint(followPoint, frame.PrivateAuraAnchor1, followRelativePoint, followOffsetX, followOffsetY)
        end, frame)
    end
    self:HookFunc("CompactUnitFrame_UpdatePrivateAuras", onUpdatePrivateAuras)

    local function UtilSetDispelDebuff(dispellDebuffFrame, aura)
        dispellDebuffFrame:Show()
        dispellDebuffFrame.icon:SetTexture("Interface\\RaidFrame\\Raid-Icon-Debuff" .. aura.dispelName)
        dispellDebuffFrame.auraInstanceID = aura.auraInstanceID
        dispellDebuffFrame.opt = frameOpt
    end

    onUpdateAuras = function(frame)
        if not frame or not frame_registry[frame] or frame:IsForbidden() or not frame:IsVisible() then
            return
        end
        for _, v in next, frame.debuffFrames do
            if not v:IsShown() then
                break
            end
            v:Hide()
        end
        Queue:add(function(frame)
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
            local dispelFrameNum = 1
            local dispelDisplayed = {}

            for _, debuffs in pairs({ frame.debuffs, frame_registry[frame].debuffs }) do
                debuffs:Iterate(function(auraInstanceID, aura)
                    if frameOpt.showDispel and AuraUtil.DispellableDebuffTypes[aura.dispelName] and not dispelDisplayed[aura.dispelName] and dispelFrameNum <= frame.maxDispelDebuffs then
                        local dispelFrame = frame.dispelDebuffFrames[dispelFrameNum]
                        UtilSetDispelDebuff(dispelFrame, aura)
                        dispelDisplayed[aura.dispelName] = true
                        dispelFrameNum = dispelFrameNum + 1
                    end

                    if userPlaced[aura.spellId] then
                        local idx = frame_registry[frame].placedAuraStart + userPlaced[aura.spellId].idx - 1
                        local debuffFrame = frame_registry[frame].extraDebuffFrames[idx]
                        local placed = userPlaced[aura.spellId]
                        onSetDebuff(debuffFrame, aura, placed)
                        userPlacedShown[debuffFrame] = true
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
            -- set debuffs after sorting to priority.
            for _, v in pairs(sorted) do
                table.sort(v, comparePriority)
            end
            for groupNo, auralist in pairs(sorted) do
                for k, v in pairs(auralist) do
                    if groupNo == 0 then
                        -- default aura frame
                        if k > frame_registry[frame].maxDebuffs then
                            break
                        end
                        frameNum = k + 1
                        local debuffFrame = frame_registry[frame].extraDebuffFrames[k]
                        onSetDebuff(debuffFrame, v.aura, v.opt)
                    else
                        -- aura group frame
                        local idx = frame_registry[frame].auraGroupStart[groupNo] + k - 1
                        local debuffFrame = frame_registry[frame].extraDebuffFrames[idx]
                        onSetDebuff(debuffFrame, v.aura, v.opt)
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
                    if not debuffFrame.auraInstanceID or not (frame.debuffs[debuffFrame.auraInstanceID] or frame_registry[frame].debuffs[debuffFrame.auraInstanceID]) then
                        onUnsetDebuff(debuffFrame)
                    else
                        userPlacedShown[debuffFrame] = true
                    end
                end
            end
            frame_registry[frame].userPlacedShown = userPlacedShown
            for i = frameNum, frame_registry[frame].maxDebuffs do
                local debuffFrame = frame_registry[frame].extraDebuffFrames[i]
                if not debuffFrame:IsShown() then
                    break
                end
                onUnsetDebuff(debuffFrame)
            end
            -- Modify the anchor of an auraGroup
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
                    onUnsetDebuff(debuffFrame)
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

            onUpdatePrivateAuras(frame)
        end, frame)
    end
    -- self:HookFunc("CompactUnitFrame_UpdateAuras", onUpdateAuras)
    self:HookFunc("CompactUnitFrame_HideAllDebuffs", onUpdateAuras)

    local function onFrameSetup(frame)
        if not frame then
            return
        end
        if frame.unit and not (frame.unit:match("pet") and frameOpt.petframe) and not UnitIsPlayer(frame.unit) and not UnitInPartyIsAI(frame.unit) then
            return
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
                debuffFrame.overwrapWithParent = Aura:framesOverlap(frame, debuffFrame)
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
                debuffFrame.overwrapWithParent = Aura:framesOverlap(frame, debuffFrame)
            end
            for k, v in pairs(auraGroup) do
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
                    debuffFrame.overwrapWithParent = Aura:framesOverlap(frame, debuffFrame)
                end
            end
        end

        for _, v in pairs(frame.debuffFrames) do
            v:ClearAllPoints()
            v.cooldown:SetDrawSwipe(false)
        end

        if frame.PrivateAuraAnchors then
            for _, privateAuraAnchor in ipairs(frame.PrivateAuraAnchors) do
                privateAuraAnchor:SetSize(boss_width, boss_height)
            end
        end

        frame.dispelDebuffFrames[1]:ClearAllPoints()
        frame.dispelDebuffFrames[1]:SetPoint(frameOpt.dispelPoint, frame, frameOpt.dispelPoint, frameOpt.dispelXOffset, frameOpt.dispelYOffset)
        local followPoint, followRelativePoint = addon:GetAuraGrowthOrientationPoints(frameOpt.dispelOrientation)
        for i = 1, #frame.dispelDebuffFrames do
            local dispelDebuffFrame = frame.dispelDebuffFrames[i]
            if (i > 1) then
                dispelDebuffFrame:ClearAllPoints()
                dispelDebuffFrame:SetPoint(followPoint, frame.dispelDebuffFrames[i - 1], followRelativePoint)
            end
            dispelDebuffFrame:SetSize(frameOpt.dispelWidth, frameOpt.dispelHeight)

            if frameOpt.tooltip then
                dispelDebuffFrame:SetScript("OnEnter", function(self)
                    if frameOpt.tooltipPosition then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, 0)
                    else
                        GameTooltip:SetOwner(self, "ANCHOR_PRESERVE")
                    end
                    self:UpdateTooltip()
                    local function RunOnUpdate()
                        if GameTooltip:IsOwned(self) then
                            self:UpdateTooltip()
                        end
                    end
                    self:SetScript("OnUpdate", RunOnUpdate)
                end)
                dispelDebuffFrame:SetScript("OnLeave", function(self)
                    if GameTooltip:IsOwned(self) then
                        GameTooltip:Hide()
                    end
                    self:SetScript("OnUpdate", nil)
                end)
            else
                dispelDebuffFrame:SetScript("OnUpdate", nil)
                dispelDebuffFrame:SetScript("OnEnter", nil)
                dispelDebuffFrame:SetScript("OnLeave", nil)
            end

            frame.dispelDebuffFrames[i].UpdateTooltip = function(self)
                if not GameTooltip:IsOwned(self) then
                    return
                end
                if self.auraInstanceID > 0 then
                    GameTooltip:SetUnitDebuffByAuraInstanceID(self:GetParent().displayedUnit, self.auraInstanceID)
                else
                    GameTooltip:SetSpellByID(-1 * self.auraInstanceID)
                end
            end
        end
    end

    local function onFrameSetupQueued(frame)
        for _, v in pairs(frame.debuffFrames) do
            v:ClearAllPoints()
            v.cooldown:SetDrawSwipe(false)
        end
        Queue:add(onFrameSetup, frame)
    end

    self:HookFuncFiltered("DefaultCompactUnitFrameSetup", onFrameSetupQueued)

    if frameOpt.petframe then
        self:HookFuncFiltered("DefaultCompactMiniFrameSetup", onFrameSetupQueued)
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
        Queue:add(function(frame)
            if not frame then
                return
            end
            onFrameSetup(frame)
            if frame.unit then
                if frame.unitExists and frame:IsShown() and not frame:IsForbidden() then
                    onUpdateAuras(frame)
                end
                if frameOpt.petframe and frame.unit:match("pet") then
                    Aura:SetAuraVar(frame, "debuffs", frame_registry[frame].buffs, onUpdateAuras)
                end
            end
        end, frame)
    end

    self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        roster_changed = true
    end)

    if frameOpt.petframe then
        local function onSetUnit(frame, unit)
            if not frame or not unit or not unit:match("pet") or not frame_registry[frame] then
                return
            end
            Queue:add(function(frame, init)
                Aura:SetAuraVar(frame, "debuffs", frame_registry[frame].debuffs, onUpdateAuras)
            end, frame, unit)
        end
        self:HookFunc("CompactUnitFrame_SetUnit", onSetUnit)
    end
end

--parts of this code are from FrameXML/CompactUnitFrame.lua
function Debuffs:OnDisable()
    self:DisableHooks()
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    roster_changed = true
    Queue:flush()
    local restoreDebuffFrames = function(frame)
        -- frame.optionTable.displayDebuffs = frame_registry[frame].displayDebuffs
        Aura:SetAuraVar(frame, "debuffs")
        for _, extraDebuffFrame in pairs(frame_registry[frame].extraDebuffFrames) do
            -- onUnsetDebuff(extraDebuffFrame)
            extraDebuffFrame:UnsetAura()
            self:Glow(extraDebuffFrame, false)
        end

        local isPowerBarShowing = frame.powerBar and frame.powerBar:IsShown()
        local powerBarUsedHeight = isPowerBarShowing and 8 or 0
        local debuffPos, debuffRelativePoint, debuffOffset = "BOTTOMLEFT", "BOTTOMRIGHT", CUF_AURA_BOTTOM_OFFSET + powerBarUsedHeight
        frame.debuffFrames[1]:SetPoint(debuffPos, frame, "BOTTOMLEFT", 3, debuffOffset)
        for i = 1, #frame.debuffFrames do
            if i > 1 then
                frame.debuffFrames[i]:SetPoint(debuffPos, frame.debuffFrames[i - 1], debuffRelativePoint, 0, 0)
            end
            frame.debuffFrames[i].cooldown:SetDrawSwipe(true)
        end

        frame.dispelDebuffFrames[1]:ClearAllPoints()
        frame.dispelDebuffFrames[1]:SetPoint("TOPRIGHT", -3, -2)
        for i = 1, #frame.dispelDebuffFrames do
            local dispelDebuffFrame = frame.dispelDebuffFrames[i]
            if (i > 1) then
                dispelDebuffFrame:ClearAllPoints()
                dispelDebuffFrame:SetPoint("RIGHT", frame.dispelDebuffFrames[i - 1], "LEFT", 0, 0)
            end
            dispelDebuffFrame:SetSize(12, 12)

            dispelDebuffFrame:SetScript("OnEnter", function(self)
                self:UpdateTooltip()
                local function RunOnUpdate()
                    if GameTooltip:IsOwned(self) then
                        self:UpdateTooltip()
                    end
                end
                self:SetScript("OnUpdate", RunOnUpdate)
            end)
            dispelDebuffFrame:SetScript("OnLeave", function(self)
                if GameTooltip:IsOwned(self) then
                    GameTooltip:Hide()
                end
                self:SetScript("OnUpdate", nil)
            end)
        end

        if frame.unit and frame.unitExists and frame:IsShown() and not frame:IsForbidden() then
            CompactUnitFrame_UpdateAuras(frame)
        end
    end
    for frame in pairs(frame_registry) do
        restoreDebuffFrames(frame)
    end
    Aura:reset()
end

local testauras = {}

function Debuffs:test()
    if testmodeTicker then
        testmodeTicker:Cancel()
        testmodeTicker = nil
        -- 테스트 버프 삭제

        for frame, registry in pairs(frame_registry) do
            if registry.debuffs then
                for spellId, v in pairs(testauras) do
                    local auraInstanceID = -spellId
                    if registry.debuffs[auraInstanceID] then
                        registry.debuffs[auraInstanceID] = nil
                    end
                end
                onUpdateAuras(frame)

                local fname = frame:GetName() .. "PrivateAuraTest"
                local indicator = _G[fname]
                if indicator then
                    indicator:Hide()
                end
            end
        end

        return
    end

    testauras = {
        [243237] = {
            duration = 10,
            maxstack = 10,
            dispelName = nil,
        },
        [198904] = {
            duration = 12,
            maxstack = 1,
            dispelName = "Poison",
        },
        [201365] = {
            duration = 15,
            maxstack = 1,
            dispelName = "Disease",
        },
        [265880] = {
            duration = 0,
            maxstack = 1,
            dispelName = "Curse",
        },
        [225908] = {
            duration = 16,
            maxstack = 1,
            dispelName = "Magic",
        },
        [206151] = {
            duration = 0,
            maxstack = 1,
            dispelName = nil,
        },
        [57723] = {
            duration = 600,
            maxstack = 1,
            dispelName = nil,
        },
    }

    local dispelType = { "Poison", "Disease", "Curse", "Magic", nil }

    for k, v in pairs(addon.filteredAuras) do
        if v.debuff and v.show and not testauras[k] then
            testauras[k] = {
                duration = random(10, 20),
                maxstack = random(1, 3),
                dispelName = dispelType[random(1, 5)],
            }
        end
    end

    local conf = addon.db.profile.Debuffs

    --increase
    local increase = {}
    for spellId, value in pairs(conf.Increase) do
        local k = tonumber(spellId)
        if k and not testauras[k] then
            testauras[k] = {
                duration = random(10, 20),
                maxstack = random(1, 3),
                dispelName = dispelType[random(1, 5)],
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
                dispelName = dispelType[random(1, 5)],
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
                    dispelName = dispelType[random(1, 5)],
                }
            end
        end
    end

    local fakeaura = function()
        local now = GetTime()
        for frame, registry in pairs(frame_registry) do
            if registry.debuffs then
                local displayOnlyDispellableDebuffs = CompactUnitFrame_GetOptionDisplayOnlyDispellableDebuffs(frame, frame.optionTable)
                local ignoreBuffs = true
                local displayDebuffs = CompactUnitFrame_GetOptionDisplayDebuffs(frame, frame.optionTable)
                local ignoreDebuffs = not frame.debuffFrames or not displayDebuffs or registry.maxDebuffs == 0
                local ignoreDispelDebuffs = ignoreDebuffs or not frame.dispelDebuffFrames or not frame.optionTable.displayDispelDebuffs or frame.maxDispelDebuffs == 0

                for spellId, v in pairs(testauras) do
                    local auraInstanceID = -spellId
                    if registry.debuffs[auraInstanceID] then
                        if registry.debuffs[auraInstanceID].expirationTime < now then
                            registry.debuffs[auraInstanceID] = nil
                        end
                    end
                    if not registry.debuffs[auraInstanceID] then
                        local aura = addon:makeFakeAura(spellId, {
                            isHarmful      = true,                                       --boolean	Whether or not this aura is a debuff.
                            isRaid         = true,                                       --boolean	Whether or not this aura meets the conditions of the RAID aura filter.
                            dispelName     = v.dispelName,                               --string?	
                            applications   = random(1, v.maxstack),                      --number	
                            duration       = v.duration,                                 --number	
                            expirationTime = v.duration > 0 and (now + v.duration) or 0, --number	
                        })
                        local type = CompactUnitFrame_ProcessAura(frame, aura, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)
                        if type == AuraUtil.AuraUpdateChangedType.Debuff or type == AuraUtil.AuraUpdateChangedType.Dispel then
                            registry.debuffs[auraInstanceID] = aura
                        end
                    end
                end
                onUpdateAuras(frame)

                if frame:IsVisible() then
                    local fname = frame:GetName() .. "PrivateAuraTest"
                    local indicator = _G[fname]
                    if indicator then
                        if not indicator:IsShown() then
                            indicator:Show()
                        end
                    else
                        indicator = CreateFrame("Frame", fname)
                        indicator:SetAllPoints(frame.PrivateAuraAnchor1)

                        indicator.mask = indicator:CreateMaskTexture()
                        indicator.mask:SetTexture("interface/framegeneral/uiframeiconmask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                        indicator.mask:SetAllPoints(indicator)

                        indicator.icon = indicator:CreateTexture(nil, "ARTWORK")
                        indicator.icon:SetAllPoints(indicator)
                        indicator.icon:SetTexture(237555)
                        indicator.icon:AddMaskTexture(indicator.mask)

                        indicator.border = indicator:CreateTexture(nil, "BORDER")
                        indicator.border:SetPoint("TOPLEFT", indicator.icon, -1, 0)
                        indicator.border:SetPoint("BOTTOMRIGHT", indicator.icon, 1, 0)
                        indicator.border:SetTexture([[Interface\Buttons\UI-Debuff-Overlays]])
                        indicator.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
                        indicator.border:SetVertexColor(0.8, 0, 0)

                        indicator.cooldown = CreateFrame("Cooldown", nil, indicator, "CooldownFrameTemplate")
                        indicator.cooldown:SetAllPoints(indicator)
                        indicator.cooldown:SetReverse(true)
                        indicator.cooldown:SetDrawEdge(false)
                        indicator.cooldown:SetDrawBling(false)

                        local timer
                        indicator:HookScript("OnShow", function()
                            if timer then timer:Cancel() end
                            indicator.cooldown:SetCooldown(GetTime(), 15)
                            timer = C_Timer.NewTicker(15, function()
                                indicator.cooldown:SetCooldown(GetTime(), 15)
                            end)
                        end)
                        frame:HookScript("OnHide", function()
                            if timer then timer:Cancel() end
                            indicator.cooldown:Clear()
                            indicator:Hide()
                        end)
                    end
                end
            end
        end
    end
    testmodeTicker = C_Timer.NewTicker(1, fakeaura)
    fakeaura()
end
