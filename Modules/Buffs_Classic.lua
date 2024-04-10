--[[
    Created by Slothpala
    The aura indicator position and the aura timers are greatly inspired by a pull request from: https://github.com/excorp
--]]
local _, addonTable = ...
local addon = addonTable.RaidFrameSettings
local Buffs = addon:NewModule("Buffs")
Mixin(Buffs, addonTable.hooks)
local Glow = addonTable.Glow
local Aura = addonTable.Aura
local Media = LibStub("LibSharedMedia-3.0")

local AuraFilter = addon:GetModule("AuraFilter")

--WoW Api
local UnitBuff = UnitBuff
local UnitAffectingCombat = UnitAffectingCombat
local SpellIsSelfBuff = SpellIsSelfBuff
local CooldownFrame_Set = CooldownFrame_Set
local CooldownFrame_Clear = CooldownFrame_Clear
local GetClassicExpansionLevel = GetClassicExpansionLevel
local GetSpellInfo = GetSpellInfo
-- local SpellGetVisibilityInfo = SpellGetVisibilityInfo -- SpellGetVisibilityInfo function is prehooked from the AuraFilter, so we must comment this.
local C_Timer = C_Timer

-- Lua
local CopyTable = CopyTable
local GetTime = GetTime
local math = math
local table = table
local pairs = pairs
local tonumber = tonumber
local tinsert = tinsert
local random = random


local frame_registry = {}
local roster_changed = true
local groupClass = {}
local glowOpt
local onUpdateAuras
local testmodeTicker


local function UnitBuff2(unit, index, filter)
    local name, icon, applications, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura = UnitBuff(unit, index, filter)
    if not name then
        local registry
        for frame, v in pairs(frame_registry) do
            if frame.unit == unit then
                registry = v
                break
            end
        end
        if not registry or not registry.buffs then
            return false
        end
        for i = index, 1, -1 do
            name = UnitBuff(unit, index, filter)
            if name then
                index = index - i
                break
            end
        end
        local aura = registry.buffs:Get(index)
        if not aura then
            return false
        end
        return aura.name, aura.icon, aura.applications, aura.dispelName, aura.duration, aura.expirationTime, aura.sourceUnit, aura.isStealable, nil, aura.spellId, aura.canApplyAura
    end
    return name, icon, applications, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura
end

local function UtilShouldDisplayBuff(unit, index, filter)
    local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura = UnitBuff2(unit, index, filter)

    local hasCustom, alwaysShowMine, showForMySpec = SpellGetVisibilityInfo(spellId, UnitAffectingCombat("player") and "RAID_INCOMBAT" or "RAID_OUTOFCOMBAT")

    if (hasCustom) then
        return showForMySpec or (alwaysShowMine and (unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle"))
    else
        return (unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle") and canApplyAura and not SpellIsSelfBuff(spellId)
    end
end

local function UtilIsBossAura(unit, index, filter, checkAsBuff)
    -- make sure you are using the correct index here!	allAurasIndex ~= debuffIndex
    local name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura, isBossAura
    if (checkAsBuff) then
        name, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura, isBossAura = UnitBuff(unit, index, filter)
    else
        isBossAura = false
    end
    return isBossAura
end

local function UpdateCooldownFrame(frame, expirationTime, duration)
    local enabled = expirationTime and expirationTime ~= 0
    if enabled then
        local startTime = expirationTime - duration
        CooldownFrame_Set(frame.cooldown, startTime, duration, true)
    else
        CooldownFrame_Clear(frame.cooldown)
    end
end

local function makeAura(spellId, opt)
    local spellName, _, icon = GetSpellInfo(spellId)
    local aura = {
        applications            = 0,         --number	
        applicationsp           = nil,       --string? force show applications evenif it is 1
        auraInstanceID          = -spellId,  --number	
        canApplyAura            = true,      -- boolean	Whether or not the player can apply this aura.
        charges                 = 1,         --number	
        dispelName              = nil,       --string?	
        duration                = 0,         --number	
        expirationTime          = 1,         --number	
        icon                    = icon,      --number	
        isBossAura              = false,     --boolean	Whether or not this aura was applied by a boss.
        isFromPlayerOrPlayerPet = true,      --boolean	Whether or not this aura was applied by a player or their pet.
        isHarmful               = false,     --boolean	Whether or not this aura is a debuff.
        isHelpful               = true,      --boolean	Whether or not this aura is a buff.
        isNameplateOnly         = false,     --boolean	Whether or not this aura should appear on nameplates.
        isRaid                  = false,     --boolean	Whether or not this aura meets the conditions of the RAID aura filter.
        isStealable             = false,     --boolean	
        maxCharges              = 1,         --number	
        name                    = spellName, --string	The name of the aura.
        nameplateShowAll        = false,     --boolean	Whether or not this aura should always be shown irrespective of any usual filtering logic.
        nameplateShowPersonal   = false,     --boolean	
        points                  = {},        --array	Variable returns - Some auras return additional values that typically correspond to something shown in the tooltip, such as the remaining strength of an absorption effect.	
        sourceUnit              = "player",  --string?	Token of the unit that applied the aura.
        spellId                 = spellId,   --number	The spell ID of the aura.
        timeMod                 = 1,         --number	
    }
    if opt and type(opt) == "table" then
        MergeTable(aura, opt)
    end
    return aura
end

local function initRegistry(frame)
    frame_registry[frame] = {
        maxBuffs        = 0,
        placedAuraStart = 0,
        auraGroupStart  = {},
        auraGroupEnd    = {},
        extraBuffFrames = {},
        reanchor        = {},
        aura            = {},
        allaura         = {
            aura  = {},
            all   = {},
            own   = {},
            other = {},
        },
        userPlacedShown = {},
        buffs           = TableUtil.CreatePriorityTable(function(a, b)
            local aFromPlayer = (a.sourceUnit ~= nil) and UnitIsUnit("player", a.sourceUnit) or false
            local bFromPlayer = (b.sourceUnit ~= nil) and UnitIsUnit("player", b.sourceUnit) or false
            if aFromPlayer ~= bFromPlayer then
                return aFromPlayer
            end

            if a.canApplyAura ~= b.canApplyAura then
                return a.canApplyAura
            end

            return a.auraInstanceID < b.auraInstanceID
        end, TableUtil.Constants.AssociativePriorityTable),
        dirty           = true,
    }
end

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
    frameOpt.framestrata = addon:ConvertDbNumberToFrameStrata(frameOpt.framestrata)
    frameOpt.baseline = addon:ConvertDbNumberToBaseline(frameOpt.baseline)
    frameOpt.type = frameOpt.baricon and "baricon" or "blizzard"
    frameOpt.missingAura = false -- addon.db.profile.Buffs.useMissingAura

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
    for spellId, v in pairs(addon.db.profile.Buffs.MissingAura) do
        local conf = CopyTable(v)
        conf.class = addon:ConvertDbNumberToClass(v.class)
        missingAuraOpt[tonumber(spellId)] = conf
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

    local onSetBuff = function(buffFrame, unit, index, filter, opt)
        if buffFrame:IsForbidden() then --not sure if this is still neede but when i created it at the start if dragonflight it was
            return
        end
        local parent = buffFrame:GetParent()
        if not parent or not frame_registry[parent] then
            return
        end
        buffFrame:SetID(index)
        buffFrame.filter = filter
        local name, icon, applications, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura = UnitBuff2(unit, index, filter)
        if GetClassicExpansionLevel() < LE_EXPANSION_BURNING_CRUSADE and not frameOpt.baricon then
            UpdateCooldownFrame(buffFrame, expirationTime, duration)
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
                canApplyAura    = canApplyAura,
                auraInstanceID  = auraInstanceID,
                refresh         = refresh,
            }
        end

        -- icon, stack, cooldown(duration) start
        buffFrame:SetAura(aurastored[auraInstanceID])
        local auraGroupNo = auraGroupList[spellId]
        if userPlaced[spellId] and userPlaced[spellId].setSize then
            local placed = userPlaced[spellId]
            buffFrame:SetSize(placed.width, placed.height)
        elseif auraGroupNo and auraGroup[auraGroupNo].setSize then
            local group = auraGroup[auraGroupNo]
            buffFrame:SetSize(group.width, group.height)
        elseif increase[spellId] then
            buffFrame:SetSize(big_width, big_height)
        else
            buffFrame:SetSize(width, height)
        end

        self:Glow(buffFrame, opt.glow)
        buffFrame:SetAlpha(opt.alpha or 1)
    end

    local function onUpdateMissingAuras(frame)
        local changed
        if not frame_registry[frame] then
            return
        end

        for spellId, v in pairs(missingAuraOpt) do
            local check
            if v.other then
                if groupClass[v.class] then
                    check = frame_registry[frame].allaura.all
                end
            else
                check = frame_registry[frame].allaura.own
            end
            if check then
                if check[spellId] then
                    if frame_registry[frame].buffs[-spellId] then
                        frame_registry[frame].buffs[-spellId] = nil
                        changed = true
                    end
                else
                    if not frame_registry[frame].buffs[-spellId] then
                        frame_registry[frame].buffs[-spellId] = makeAura(spellId)
                        changed = true
                    end
                end
            end
        end

        if changed then
            onUpdateAuras(frame)
        end
    end

    onUpdateAuras = function(frame)
        if not frame_registry[frame] or frame:IsForbidden() or not frame:IsVisible() then
            return
        end
        for _, v in pairs(frame.buffFrames) do
            if not v:IsShown() then
                break
            end
            v:Hide()
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
        while true do
            local buffName, icon, count, debuffType, duration, expirationTime, unitCaster, canStealOrPurge, _, spellId, canApplyAura = UnitBuff2(frame.displayedUnit, index, filter)
            if not buffName then
                break
            end
            if UtilShouldDisplayBuff(frame.displayedUnit, index, filter) and not UtilIsBossAura(frame.displayedUnit, index, filter, true) then
                if userPlaced[spellId] then
                    local idx = frame_registry[frame].placedAuraStart + userPlaced[spellId].idx - 1
                    local buffFrame = frame_registry[frame].extraBuffFrames[idx]
                    local placed = userPlaced[spellId]
                    onSetBuff(buffFrame, frame.displayedUnit, index, filter, placed)
                    userPlacedShown[buffFrame] = true
                elseif auraGroupList[spellId] then
                    local groupNo = auraGroupList[spellId]
                    local auraList = auraGroup[groupNo].auraList
                    local auraOpt = auraList[spellId]
                    local priority = auraOpt.priority > 0 and auraOpt.priority or filteredAuras[spellId] and filteredAuras[spellId].priority or 0
                    if not sorted[groupNo] then sorted[groupNo] = {} end
                    tinsert(sorted[groupNo], { spellId = spellId, priority = priority, index = index, opt = auraOpt })
                    groupFrameNum[groupNo] = groupFrameNum[groupNo] and (groupFrameNum[groupNo] + 1) or 2
                else
                    local filtered = filteredAuras[spellId]
                    local priority = filtered and filtered.priority or 0
                    tinsert(sorted[0], { spellId = spellId, priority = priority, index = index, opt = filtered or {} })
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
                    if frameNum > frame_registry[frame].maxBuffs then
                        break
                    end
                    frameNum = k + 1
                    -- default aura frame
                    local buffFrame = frame_registry[frame].extraBuffFrames[k]
                    onSetBuff(buffFrame, frame.displayedUnit, v.index, filter, v.opt)
                else
                    -- aura group frame
                    local idx = frame_registry[frame].auraGroupStart[groupNo] + k - 1
                    local buffFrame = frame_registry[frame].extraBuffFrames[idx]
                    onSetBuff(buffFrame, frame.displayedUnit, v.index, filter, v.opt)
                    -- grow direction == NONE
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
                    frame_registry[frame].aura[buffFrame.auraInstanceID] = nil
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
            if buffFrame.auraInstanceID and frame_registry[frame].aura[buffFrame.auraInstanceID] then
                frame_registry[frame].aura[buffFrame.auraInstanceID] = nil
            end
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
                if buffFrame.auraInstanceID and frame_registry[frame].aura[buffFrame.auraInstanceID] then
                    frame_registry[frame].aura[buffFrame.auraInstanceID] = nil
                end
            end
        end
    end
    self:HookFunc("CompactUnitFrame_UpdateAuras", onUpdateAuras)

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
                buffFrame:ClearAllPoints()
                buffFrame.icon:SetTexCoord(0, 1, 0, 1)
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
        end
        for k, v in pairs(auraGroup) do
            frame_registry[frame].auraGroupStart[k] = idx + 1
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
            end
            frame_registry[frame].auraGroupEnd[k] = idx
        end

        if frameOpt.missingAura and next(missingAuraOpt) ~= nil then
            Aura:SetAuraVar(frame, "buffsAll", frame_registry[frame].allaura, onUpdateMissingAuras)
        end
    end
    self:HookFuncFiltered("DefaultCompactUnitFrameSetup", onFrameSetup)

    if frameOpt.petframe then
        self:HookFuncFiltered("DefaultCompactMiniFrameSetup", onFrameSetup)
    end

    self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        roster_changed = true
        C_Timer.After(0, function()
            groupClass = {}
            addon:IterateRoster(function(frame)
                if frame.unit and UnitIsPlayer(frame.unit) then
                    local class = select(2, UnitClass(frame.unit))
                    if class then
                        groupClass[class] = true
                    end
                end
            end)
        end)
    end)

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

    groupClass = {}
    for frame, v in pairs(frame_registry) do
        v.dirty = true
        onFrameSetup(frame)
        if frame.unit and frame.unitExists and frame:IsShown() and not frame:IsForbidden() then
            onUpdateAuras(frame)
            if frame.unit and UnitIsPlayer(frame.unit) then
                local class = select(2, UnitClass(frame.unit))
                groupClass[class] = true
            end
        end
    end
end

--parts of this code are from FrameXML/CompactUnitFrame.lua
function Buffs:OnDisable()
    self:DisableHooks()
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    roster_changed = true
    local restoreBuffFrames = function(frame)
        Aura:SetAuraVar(frame, "buffsAll")
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

        initRegistry(frame)
    end
    for frame in pairs(frame_registry) do
        restoreBuffFrames(frame)
    end
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
                for spellId, v in pairs(testauras) do
                    local auraInstanceID = -spellId
                    if registry.buffs[auraInstanceID] then
                        if registry.buffs[auraInstanceID].expirationTime < now then
                            registry.buffs[auraInstanceID] = nil
                        end
                    end
                    if not registry.buffs[auraInstanceID] then
                        local aura = makeAura(spellId, {
                            applications   = random(1, v.maxstack),                      --number	
                            duration       = v.duration,                                 --number	
                            expirationTime = v.duration > 0 and (now + v.duration) or 0, --number	
                        })
                        registry.buffs[auraInstanceID] = aura
                    end
                end
                onUpdateAuras(frame)
            end
        end
    end
    testmodeTicker = C_Timer.NewTicker(1, fakeaura)
    fakeaura()
end
