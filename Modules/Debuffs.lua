--[[
    Created by Slothpala
    The aura indicator position and the aura timers are greatly inspired by a pull request from: https://github.com/excorp
--]]
local _, addonTable = ...
local addon = addonTable.RaidFrameSettings
local Debuffs = addon:NewModule("Debuffs")
Mixin(Debuffs, addonTable.hooks)
local CDT = addonTable.cooldownText
local Glow = addonTable.Glow
local Aura = addonTable.Aura
local Media = LibStub("LibSharedMedia-3.0")

local fontObj = CreateFont("RaidFrameSettingsFont")

--Debuffframe size
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
local IsForbidden = IsForbidden
--Lua
local next = next

local frame_registry = {}
local unitFrame = {}
local roster_changed = true
local glowOpt

function Debuffs:Glow(frame, onoff)
    if onoff then
        Glow:Start(glowOpt, frame)
    else
        Glow:Stop(glowOpt, frame)
    end
end

local function CompactUnitFrame_ParseAllAuras(frame, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)
    frame.debuffs:Clear()
    for type, _ in pairs(AuraUtil.DispellableDebuffTypes) do
        frame.dispels[type]:Clear()
    end

    local batchCount = nil
    local usePackedAura = true
    local function HandleAura(aura)
        local type = CompactUnitFrame_ProcessAura(frame, aura, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)

        if type == AuraUtil.AuraUpdateChangedType.Debuff then
            frame.debuffs[aura.auraInstanceID] = aura
        elseif type == AuraUtil.AuraUpdateChangedType.Dispel then
            frame.debuffs[aura.auraInstanceID] = aura
        end
    end
    AuraUtil.ForEachAura(frame.displayedUnit, AuraUtil.CreateFilterString(AuraUtil.AuraFilters.Harmful), batchCount, HandleAura, usePackedAura)
    AuraUtil.ForEachAura(frame.displayedUnit, AuraUtil.CreateFilterString(AuraUtil.AuraFilters.Harmful, AuraUtil.AuraFilters.Raid), batchCount, HandleAura, usePackedAura)
end

function Debuffs:OnEnable()
    local debuffColors = {
        Curse   = { r = 0.6, g = 0.0, b = 1.0 },
        Disease = { r = 0.6, g = 0.4, b = 0.0 },
        Magic   = { r = 0.2, g = 0.6, b = 1.0 },
        Poison  = { r = 0.0, g = 0.6, b = 0.0 },
        Bleed   = { r = 0.8, g = 0.0, b = 0.0 },
    }
    local Bleeds = addonTable.Bleeds

    CDT.TimerTextLimit = addon.db.profile.MinorModules.TimerTextLimit

    glowOpt = CopyTable(addon.db.profile.MinorModules.Glow)
    glowOpt.type = addon:ConvertDbNumberToGlowType(glowOpt.type)

    local frameOpt = CopyTable(addon.db.profile.Debuffs.DebuffFramesDisplay)
    frameOpt.petframe = addon.db.profile.Buffs.petframe
    frameOpt.framestrata = addon:ConvertDbNumberToFrameStrata(frameOpt.framestrata)
    frameOpt.baseline = addon:ConvertDbNumberToBaseline(frameOpt.baseline)
    frameOpt.type = frameOpt.baricon and "baricon" or "blizzard"

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
    --Stack
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
    if addon.db.profile.Module.AuraFilter and addon.db.profile.AuraFilter.Debuffs then
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
    local resizeDebuffFrame
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
        resizeDebuffFrame = function(debuffFrame)
            debuffFrame:SetSize(width, height)
            debuffFrame.icon:SetTexCoord(left, right, top, bottom)
            if debuffFrame.border then
                debuffFrame.border:SetTexture("Interface\\AddOns\\RaidFrameSettings_Excorp_Fork\\Textures\\DebuffOverlay_clean_icons.tga")
                debuffFrame.border:SetTexCoord(0, 1, 0, 1)
                debuffFrame.border:SetTextureSliceMargins(5.01, 26.09, 5.01, 26.09)
                debuffFrame.border:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
            end
        end
    else
        resizeDebuffFrame = function(debuffFrame)
            debuffFrame:SetSize(width, height)
        end
    end
    --Debuffframe position
    local point = addon:ConvertDbNumberToPosition(frameOpt.point)
    local relativePoint = addon:ConvertDbNumberToPosition(frameOpt.relativePoint)
    local followPoint, followRelativePoint, followOffsetX, followOffsetY = addon:GetAuraGrowthOrientationPoints(frameOpt.orientation, frameOpt.gap, frameOpt.baseline)

    local comparePriority = function(a, b)
        return a.priority > b.priority
    end

    local onSetDebuff = function(debuffFrame, aura, opt)
        if debuffFrame:IsForbidden() then --not sure if this is still neede but when i created it at the start if dragonflight it was
            return
        end
        local parent = debuffFrame:GetParent()
        if not parent or not frame_registry[parent] then
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

        if not durationOpt.debuffColor then
            color = durationOpt.fontColor
        end
        local cooldownText = CDT:CreateOrGetCooldownFontString(debuffFrame.cooldown)
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
    end

    local function onUpdatePrivateAuras(frame)
        if not frame.PrivateAuraAnchors or not frame_registry[frame] or frame:IsForbidden() or not frame:IsVisible() then
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
    end
    self:HookFunc("CompactUnitFrame_UpdatePrivateAuras", onUpdatePrivateAuras)

    local onHideAllDebuffs = function(frame)
        if not frame_registry[frame] or frame:IsForbidden() or not frame:IsVisible() then
            return
        end
        if frame.debuffFrames then
            for _, v in pairs(frame.debuffFrames) do
                v:Hide()
            end
        end

        -- set placed aura / other aura
        local frameNum = 1
        local groupFrameNum = {}
        local sorted = {
            [0] = {},
        }
        for _, debuffs in pairs({ frame.debuffs, frame_registry[frame].debuffs }) do
            debuffs:Iterate(function(auraInstanceID, aura)
                if userPlaced[aura.spellId] then
                    local idx = frame_registry[frame].placedAuraStart + userPlaced[aura.spellId].idx - 1
                    local debuffFrame = frame_registry[frame].extraDebuffFrames[idx]
                    local placed = userPlaced[aura.spellId]
                    onSetDebuff(debuffFrame, aura, placed)
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
                if frameNum <= frame_registry[frame].maxDebuffs then
                    local filtered = filteredAuras[aura.spellId]
                    local priority = filtered and filtered.priority or 0
                    tinsert(sorted[0], { spellId = aura.spellId, priority = priority, aura = aura, opt = filtered or {} })
                    frameNum = frameNum + 1
                end
                return false
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
        for i = 1, maxUserPlaced do
            local idx = frame_registry[frame].placedAuraStart + i - 1
            local debuffFrame = frame_registry[frame].extraDebuffFrames[idx]
            if not debuffFrame.auraInstanceID or not frame.debuffs[debuffFrame.auraInstanceID] then
                self:Glow(debuffFrame, false)
                debuffFrame:UnsetAura()
            end
        end
        for i = frameNum, math.max(frame_registry[frame].maxDebuffs, frame.maxDebuffs) do
            local debuffFrame = frame_registry[frame].extraDebuffFrames[i]
            self:Glow(debuffFrame, false)
            debuffFrame:UnsetAura()
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
                self:Glow(debuffFrame, false)
                debuffFrame:UnsetAura()
            end
        end

        onUpdatePrivateAuras(frame)
    end
    self:HookFunc("CompactUnitFrame_HideAllDebuffs", onHideAllDebuffs)

    local function onFrameSetup(frame)
        if not frameOpt.petframe then
            local fname = frame:GetName()
            if not fname or fname:match("Pet") then
                return
            end
        end
        if not frame_registry[frame] then
            frame_registry[frame] = {
                maxDebuffs        = frameOpt.maxdebuffs,
                placedAuraStart   = 0,
                auraGroupStart    = {},
                auraGroupEnd      = {},
                extraDebuffFrames = {},
                reanchor          = {},
                debuffs           = TableUtil.CreatePriorityTable(AuraUtil.UnitFrameDebuffComparator, TableUtil.Constants.AssociativePriorityTable),
                dispels           = {},
                aura              = {},
                dirty             = true,
            }
            for type, _ in pairs(AuraUtil.DispellableDebuffTypes) do
                frame_registry[frame].dispels[type] = TableUtil.CreatePriorityTable(AuraUtil.DefaultAuraCompare, TableUtil.Constants.AssociativePriorityTable)
            end
        end

        if frame_registry[frame].dirty then
            frame_registry[frame].maxDebuffs = frameOpt.maxdebuffs
            frame_registry[frame].dirty = false
            local placedAuraStart = frame.maxDebuffs + 1
            for i = 1, frame_registry[frame].maxDebuffs do
                local debuffFrame = Aura:createAuraFrame(frame, "Debuff", frameOpt.type, i) -- category:Buff,Debuff, type=blizzard,baricon
                frame_registry[frame].extraDebuffFrames[i] = debuffFrame
                debuffFrame:ClearAllPoints()
                debuffFrame.icon:SetTexCoord(0, 1, 0, 1)
                placedAuraStart = i + 1
            end
            frame_registry[frame].placedAuraStart = placedAuraStart

            for i = 1, maxUserPlaced + maxAuraGroup do
                local idx = placedAuraStart + i - 1
                local debuffFrame = Aura:createAuraFrame(frame, "Debuff", frameOpt.type, idx) -- category:Buff,Debuff, type=blizzard,baricon
                frame_registry[frame].extraDebuffFrames[idx] = debuffFrame
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

            for _, v in pairs(frame_registry[frame].extraDebuffFrames) do
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
            resizeDebuffFrame(debuffFrame)
        end
        local idx = frame_registry[frame].placedAuraStart - 1
        for _, place in pairs(userPlaced) do
            idx = frame_registry[frame].placedAuraStart + place.idx - 1
            local debuffFrame = frame_registry[frame].extraDebuffFrames[idx]
            local parentIdx = (place.frame == 2 and place.frameNo > 0 and userPlaced[place.frameNo] and (frame_registry[frame].placedAuraStart + userPlaced[place.frameNo].idx - 1)) or
                (place.frame == 3 and place.frameNo > 0 and auraGroup[place.frameNo] and (frame_registry[frame].auraGroupStart[place.frameNo] + place.frameNoNo - 1))
            local parent = parentIdx and frame_registry[frame].extraDebuffFrames[parentIdx] or frame
            debuffFrame:ClearAllPoints()
            debuffFrame:SetPoint(place.point, parent, place.relativePoint, place.xOffset, place.yOffset)
            resizeDebuffFrame(debuffFrame)
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
                    local parent = parentIdx and frame_registry[frame].extraDebuffFrames[parentIdx] or frame
                    debuffFrame:ClearAllPoints()
                    debuffFrame:SetPoint(v.point, parent, v.relativePoint, v.xOffset, v.yOffset)
                    anchorSet = true
                else
                    debuffFrame:ClearAllPoints()
                    debuffFrame:SetPoint(followPoint, prevFrame, followRelativePoint, followOffsetX, followOffsetY)
                end
                prevFrame = debuffFrame
                resizeDebuffFrame(debuffFrame)
            end
        end
        if frame.PrivateAuraAnchors then
            for _, privateAuraAnchor in ipairs(frame.PrivateAuraAnchors) do
                privateAuraAnchor:SetSize(boss_width, boss_height)
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
                    maxDebuffs        = frameOpt.maxdebuffs,
                    placedAuraStart   = 0,
                    auraGroupStart    = {},
                    auraGroupEnd      = {},
                    extraDebuffFrames = {},
                    reanchor          = {},
                    debuffs           = TableUtil.CreatePriorityTable(AuraUtil.UnitFrameDebuffComparator, TableUtil.Constants.AssociativePriorityTable),
                    dispels           = {},
                    aura              = {},
                    dirty             = true,
                }
                for type, _ in pairs(AuraUtil.DispellableDebuffTypes) do
                    frame_registry[frame].dispels[type] = TableUtil.CreatePriorityTable(AuraUtil.DefaultAuraCompare, TableUtil.Constants.AssociativePriorityTable)
                end
            end
        end)
    end
    for frame, v in pairs(frame_registry) do
        v.dirty = true
        onFrameSetup(frame)
        if frame.unit then
            if not unitFrame[frame.unit] then unitFrame[frame.unit] = {} end
            unitFrame[frame.unit][frame] = frame
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
            for srcframe in pairs(unitFrame[unit]) do
                if srcframe.unit ~= unit then
                    unitFrame[unit][srcframe] = nil
                end
            end
            unitFrame[frame.unit][frame] = frame
        end)

        self:RegisterEvent("UNIT_AURA", function(event, unit, unitAuraUpdateInfo)
            if not unit:match("pet") then
                return
            end
            if not unitFrame[unit] then
                return
            end
            for srcframe in pairs(unitFrame[unit]) do
                local frame = frame_registry[srcframe]
                if frame then
                    local debuffsChanged = false
                    local dispelsChanged = false

                    local displayOnlyDispellableDebuffs = false
                    local ignoreBuffs = true
                    local ignoreDebuffs = false
                    local ignoreDispelDebuffs = true

                    frame.unit = srcframe.unit
                    frame.displayedUnit = srcframe.displayedUnit

                    if unitAuraUpdateInfo == nil or unitAuraUpdateInfo.isFullUpdate or frame.debuffs == nil then
                        CompactUnitFrame_ParseAllAuras(frame, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)
                        debuffsChanged = true
                        dispelsChanged = true
                    else
                        if unitAuraUpdateInfo.addedAuras ~= nil then
                            for _, aura in ipairs(unitAuraUpdateInfo.addedAuras) do
                                local type = CompactUnitFrame_ProcessAura(frame, aura, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)
                                if type == AuraUtil.AuraUpdateChangedType.Debuff then
                                    frame.debuffs[aura.auraInstanceID] = aura
                                    debuffsChanged = true
                                elseif type == AuraUtil.AuraUpdateChangedType.Dispel then
                                    frame.debuffs[aura.auraInstanceID] = aura
                                    debuffsChanged = true
                                    frame.dispels[aura.dispelName][aura.auraInstanceID] = aura
                                    dispelsChanged = true
                                end
                            end
                        end

                        if unitAuraUpdateInfo.updatedAuraInstanceIDs ~= nil then
                            for _, auraInstanceID in ipairs(unitAuraUpdateInfo.updatedAuraInstanceIDs) do
                                if frame.debuffs[auraInstanceID] ~= nil then
                                    local newAura = C_UnitAuras.GetAuraDataByAuraInstanceID(frame.displayedUnit, auraInstanceID)
                                    local oldDebuffType = frame.debuffs[auraInstanceID].debuffType
                                    if newAura ~= nil then
                                        newAura.debuffType = oldDebuffType
                                    end
                                    frame.debuffs[auraInstanceID] = newAura
                                    debuffsChanged = true

                                    for _, tbl in pairs(frame.dispels) do
                                        if tbl[auraInstanceID] ~= nil then
                                            tbl[auraInstanceID] = C_UnitAuras.GetAuraDataByAuraInstanceID(frame.displayedUnit, auraInstanceID)
                                            dispelsChanged = true
                                            break
                                        end
                                    end
                                end
                            end
                        end

                        if unitAuraUpdateInfo.removedAuraInstanceIDs ~= nil then
                            for _, auraInstanceID in ipairs(unitAuraUpdateInfo.removedAuraInstanceIDs) do
                                if frame.debuffs[auraInstanceID] ~= nil then
                                    frame.debuffs[auraInstanceID] = nil
                                    debuffsChanged = true

                                    for _, tbl in pairs(frame.dispels) do
                                        if tbl[auraInstanceID] ~= nil then
                                            tbl[auraInstanceID] = nil
                                            dispelsChanged = true
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end

                    if debuffsChanged then
                        onHideAllDebuffs(srcframe)
                    end
                end
            end
        end)
    end
end

--parts of this code are from FrameXML/CompactUnitFrame.lua
function Debuffs:OnDisable()
    self:DisableHooks()
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    self:UnregisterEvent("UNIT_AURA")
    roster_changed = true
    local restoreDebuffFrames = function(frame)
        for _, extraDebuffFrame in pairs(frame_registry[frame].extraDebuffFrames) do
            extraDebuffFrame:Hide()
            self:Glow(extraDebuffFrame, false)
        end
        if frame.unit and frame.unitExists and frame:IsShown() and not frame:IsForbidden() then
            CompactUnitFrame_UpdateAuras(frame)
        end
    end
    for frame in pairs(frame_registry) do
        restoreDebuffFrames(frame)
    end
    CDT:DisableCooldownText()
end
