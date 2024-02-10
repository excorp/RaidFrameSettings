--[[
    Created by Slothpala
    The aura indicator position and the aura timers are greatly inspired by a pull request from: https://github.com/excorp
--]]
local _, addonTable = ...
local addon = addonTable.RaidFrameSettings
local Buffs = addon:NewModule("Buffs")
Mixin(Buffs, addonTable.hooks)
local CDT = addonTable.cooldownText
local Media = LibStub("LibSharedMedia-3.0")

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
-- local org_SpellGetVisibilityInfo
local module_enabled
local blacklist = {}
local whitelist = {}

function Buffs:OnEnable()
    module_enabled = true

    CDT.TimerTextLimit = addon.db.profile.MinorModules.TimerTextLimit

    local frameOpt = CopyTable(addon.db.profile.Buffs.BuffFramesDisplay)
    frameOpt.framestrata = addon:ConvertDbNumberToFrameStrata(frameOpt.framestrata)
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
    --blacklist
    for k in pairs(blacklist) do
        blacklist[k] = nil
    end
    for spellId, value in pairs(addon.db.profile.Buffs.Blacklist) do
        blacklist[tonumber(spellId)] = true
    end
    --whitelist
    for k in pairs(whitelist) do
        whitelist[k] = nil
    end
    for spellId, value in pairs(addon.db.profile.Buffs.Whitelist) do
        whitelist[tonumber(spellId)] = value
    end
    --user placed
    local userPlaced = {}
    local userPlacedIdx = 1
    local maxUserPlaced = 0
    for _, auraInfo in pairs(addon.db.profile.Buffs.AuraPosition) do
        userPlaced[auraInfo.spellId] = {
            idx = userPlacedIdx,
            point = addon:ConvertDbNumberToPosition(auraInfo.point),
            relativePoint = addon:ConvertDbNumberToPosition(auraInfo.relativePoint),
            xOffset = auraInfo.xOffset,
            yOffset = auraInfo.yOffset,
        }
        userPlacedIdx = userPlacedIdx + 1
    end
    maxUserPlaced = userPlacedIdx - 1
    --Buff size
    local width  = frameOpt.width
    local height = frameOpt.height
    local resizeBuffFrame
    if frameOpt.cleanIcons then
        local left, right, top, bottom = 0.1, 0.9, 0.1, 0.9
        if height ~= width then
            if height < width then
                local delta = width - height
                local scale_factor = ((( 100 / width )  * delta) / 100) / 2
                top = top + scale_factor
                bottom = bottom - scale_factor
            else
                local delta = height - width 
                local scale_factor = ((( 100 / height )  * delta) / 100) / 2
                left = left + scale_factor
                right = right - scale_factor
            end
        end
        resizeBuffFrame = function(buffFrame)
            buffFrame:SetSize(width, height)
            buffFrame.icon:SetTexCoord(left,right,top,bottom)
        end
    else
        resizeBuffFrame = function(buffFrame)
            buffFrame:SetSize(width, height)
        end
    end
    --Buffframe position
    local point = addon:ConvertDbNumberToPosition(frameOpt.point)
    local relativePoint = addon:ConvertDbNumberToPosition(frameOpt.relativePoint)
    local followPoint, followRelativePoint = addon:GetAuraGrowthOrientationPoints(frameOpt.orientation)

    if not AuraUtil.org_ShouldDisplayBuff then
        AuraUtil.org_ShouldDisplayBuff = AuraUtil.ShouldDisplayBuff
        AuraUtil.ShouldDisplayBuff = function(unitCaster, spellId, canApplyAura)
            if module_enabled then
                if blacklist[spellId] then
                    return false
                elseif whitelist[spellId] then
                    if whitelist[spellId].other then
                        return true
                    end
                    return unitCaster == "player" or unitCaster == "pet" or unitCaster == "vehicle"
                end
            end
            return AuraUtil.org_ShouldDisplayBuff(unitCaster, spellId, canApplyAura)
        end
    end
    --[[
    if not org_SpellGetVisibilityInfo then
        org_SpellGetVisibilityInfo = SpellGetVisibilityInfo
        SpellGetVisibilityInfo = function(spellId, visType)
            if module_enabled then
                if blacklist[spellId] then
                    return true, false, false
                elseif whitelist[spellId] then
                    if whitelist[spellId].other then
                        return true, false, true
                    end
                    return false
                end
            end
            return org_SpellGetVisibilityInfo(spellId, visType)
        end
    end
    ]]

    local onSetBuff = function(buffFrame, aura)
        local cooldown = buffFrame.cooldown
        CDT:StartCooldownText(cooldown)
        cooldown:SetDrawEdge(frameOpt.edge)
        if not cooldown.count then
            return
        end
        if buffFrame.count:IsShown() then
            cooldown.count:SetText(buffFrame.count:GetText())
            cooldown.count:Show()
            buffFrame.count:Hide()
        else
            cooldown.count:Hide()
        end
    end
    self:HookFunc("CompactUnitFrame_UtilSetBuff", onSetBuff)

    local onHideAllBuffs = function(frame)
        if not frame_registry[frame] or not frame.buffs or not frame:IsVisible() then
            return
        end

        -- set placed aura / other aura
        local frameNum = 1
        frame.buffs:Iterate(function(auraInstanceID, aura)
            --[[
            if blacklist[aura.spellId] then
                return false
            end
            ]]

            if userPlaced[aura.spellId] then
                local idx = frame_registry[frame].placedAuraStart + userPlaced[aura.spellId].idx - 1
                local buffFrame = frame_registry[frame].extraBuffFrames[idx]
                CompactUnitFrame_UtilSetBuff(buffFrame, aura)
                return false
            end

            if frameNum <= frame_registry[frame].maxBuffs then
                local buffFrame = frame.buffFrames[frameNum] or frame_registry[frame].extraBuffFrames[frameNum]
                CompactUnitFrame_UtilSetBuff(buffFrame, aura)
                frameNum = frameNum + 1
            end
            return false
        end)
        for _, aura in pairs(frame_registry[frame].buffs) do
            if userPlaced[aura.spellId] then
                local idx = frame_registry[frame].placedAuraStart + userPlaced[aura.spellId].idx - 1
                local buffFrame = frame_registry[frame].extraBuffFrames[idx]
                CompactUnitFrame_UtilSetBuff(buffFrame, aura)
            elseif frameNum <= frame_registry[frame].maxBuffs then
                local buffFrame = frame.buffFrames[frameNum] or frame_registry[frame].extraBuffFrames[frameNum]
                CompactUnitFrame_UtilSetBuff(buffFrame, aura)
                frameNum = frameNum + 1
            end
        end

        -- hide left aura frames
        for i = 1, maxUserPlaced do
            local idx = frame_registry[frame].placedAuraStart + i - 1
            local buffFrame = frame_registry[frame].extraBuffFrames[idx]
            if not buffFrame.auraInstanceID or (not frame.buffs[buffFrame.auraInstanceID] and not frame_registry[frame].buffs[buffFrame.auraInstanceID]) then
                buffFrame:Hide()
                CooldownFrame_Clear(buffFrame.cooldown)
            end
        end
        for i = frameNum, math.max(frame_registry[frame].maxBuffs, frame.maxBuffs) do
            local buffFrame = frame.buffFrames[i] or frame_registry[frame].extraBuffFrames[i]
            buffFrame:Hide()
            CooldownFrame_Clear(buffFrame.cooldown)
        end
    end
    self:HookFunc("CompactUnitFrame_HideAllBuffs", onHideAllBuffs)

    --[[
    local function onUpdateAuras(frame, unitAuraUpdateInfo)
        if not frame_registry[frame] or not frame.buffs then
            return
        end
        local dirty
        if unitAuraUpdateInfo == nil or unitAuraUpdateInfo.isFullUpdate then
            for k in pairs(frame_registry[frame].buffs) do
                frame_registry[frame].buffs[k] = nil
                dirty = true
            end
            local batchCount = nil
            local usePackedAura = true
            local function HandleAura(aura)
                if aura.isHelpful and not frame.buffs[aura.auraInstanceID] and not blacklist[aura.spellId] and whitelist[aura.spellId] and (whitelist[aura.spellId].other or UnitIsUnit(aura.sourceUnit, "player")) then
                    frame_registry[frame].buffs[aura.auraInstanceID] = aura
                    dirty = true
                end
            end
            AuraUtil.ForEachAura(frame.displayedUnit, AuraUtil.CreateFilterString(AuraUtil.AuraFilters.Helpful), batchCount, HandleAura, usePackedAura);
        else
            if unitAuraUpdateInfo.addedAuras ~= nil then
                for _, aura in ipairs(unitAuraUpdateInfo.addedAuras) do
                    if aura.isHelpful and not frame.buffs[aura.auraInstanceID] and not blacklist[aura.spellId] and whitelist[aura.spellId] and (whitelist[aura.spellId].other or UnitIsUnit(aura.sourceUnit, "player")) then
                        frame_registry[frame].buffs[aura.auraInstanceID] = aura
                        dirty = true
                    end
                end
            end
            if unitAuraUpdateInfo.updatedAuraInstanceIDs ~= nil then
                for _, auraInstanceID in ipairs(unitAuraUpdateInfo.updatedAuraInstanceIDs) do
                    local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(frame.displayedUnit, auraInstanceID)
                    if aura and aura.isHelpful and not frame.buffs[aura.auraInstanceID] and not blacklist[aura.spellId] and whitelist[aura.spellId] and (whitelist[aura.spellId].other or UnitIsUnit(aura.sourceUnit, "player")) then
                        frame_registry[frame].buffs[aura.auraInstanceID] = aura
                        dirty = true
                    end
                end
            end
            if unitAuraUpdateInfo.removedAuraInstanceIDs ~= nil then
                for _, auraInstanceID in ipairs(unitAuraUpdateInfo.removedAuraInstanceIDs) do
                    if frame_registry[frame].buffs[auraInstanceID] then
                        frame_registry[frame].buffs[auraInstanceID] = nil
                        dirty = true
                    end
                end
            end
        end
        if dirty then
            onHideAllBuffs(frame)
        end
    end
    self:HookFunc("CompactUnitFrame_UpdateAuras", onUpdateAuras)
    ]]

    local function onFrameSetup(frame)
        if frame.maxBuffs == 0 then
            return
        end

        if not frame_registry[frame] then
            frame_registry[frame] = {
                maxBuffs        = frameOpt.maxbuffsAuto and frame.maxBuffs or frameOpt.maxbuffs,
                placedAuraStart = 0,
                lockdown        = false,
                dirty           = true,
                extraBuffFrames = {},
                buffs           = {},
            }
        end

        if frame_registry[frame].dirty then
            if InCombatLockdown() then
                frame_registry[frame].lockdown = true
                return
            end
            frame_registry[frame].maxBuffs = frameOpt.maxbuffsAuto and frame.maxBuffs or frameOpt.maxbuffs
            frame_registry[frame].lockdown = false
            frame_registry[frame].dirty = false

            local placedAuraStart = frame.maxBuffs + 1
            for i = frame.maxBuffs + 1, frame_registry[frame].maxBuffs do
                local buffFrame = frame.buffFrames[i] or frame_registry[frame].extraBuffFrames[i]
                if not buffFrame then
                    buffFrame = CreateFrame("Button", nil, nil, "CompactBuffTemplate")
                    buffFrame:SetParent(frame)
                    buffFrame:Hide()
                    buffFrame.cooldown:SetHideCountdownNumbers(true)
                    frame_registry[frame].extraBuffFrames[i] = buffFrame
                end
                buffFrame.icon:SetTexCoord(0, 1, 0, 1)
                placedAuraStart = i + 1
            end
            frame_registry[frame].placedAuraStart = placedAuraStart

            for _, place in pairs(userPlaced) do
                local idx = placedAuraStart + place.idx - 1
                local buffFrame = frame_registry[frame].extraBuffFrames[idx]
                if not buffFrame then
                    buffFrame = CreateFrame("Button", nil, nil, "CompactBuffTemplate")
                    buffFrame:SetParent(frame)
                    buffFrame:Hide()
                    buffFrame.cooldown:SetHideCountdownNumbers(true)
                    frame_registry[frame].extraBuffFrames[idx] = buffFrame
                end
                buffFrame.icon:SetTexCoord(0, 1, 0, 1)
            end

            for i = 1, frame_registry[frame].maxBuffs + maxUserPlaced do
                local buffFrame = frame_registry[frame].extraBuffFrames[i] or frame.buffFrames[i]
                if frameOpt.framestrata ~= "Inherited" then
                    buffFrame:SetFrameStrata(frameOpt.framestrata)
                end
                --Timer Settings
                local cooldown = buffFrame.cooldown
                if frameOpt.timerText then
                    local cooldownText = CDT:CreateOrGetCooldownFontString(cooldown)
                    cooldownText:ClearAllPoints()
                    cooldownText:SetPoint(durationOpt.point, buffFrame, durationOpt.relativePoint, durationOpt.xOffsetFont, durationOpt.yOffsetFont)
                    cooldownText:SetFont(durationOpt.font, durationOpt.fontSize, durationOpt.outlinemode)
                    cooldownText:SetTextColor(durationOpt.fontColor.r, durationOpt.fontColor.g, durationOpt.fontColor.b)
                    cooldownText:SetShadowColor(durationOpt.shadowColor.r, durationOpt.shadowColor.g, durationOpt.shadowColor.b, durationOpt.shadowColor.a)
                    cooldownText:SetShadowOffset(durationOpt.xOffsetShadow, durationOpt.yOffsetShadow)
                    if OmniCC and OmniCC.Cooldown and OmniCC.Cooldown.SetNoCooldownCount then
                        if not cooldown.OmniCC then
                            cooldown.OmniCC = {
                                noCooldownCount = cooldown.noCooldownCount,
                            }
                        end
                        OmniCC.Cooldown.SetNoCooldownCount(cooldown, true)
                    end
                end
                --Stack Settings
                if not cooldown.count then
                    cooldown.count = cooldown:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
                end
                local stackText = cooldown.count
                stackText:ClearAllPoints()
                stackText:SetPoint(stackOpt.point, buffFrame, stackOpt.relativePoint, stackOpt.xOffsetFont, stackOpt.yOffsetFont)
                stackText:SetFont(stackOpt.font, stackOpt.fontSize, stackOpt.outlinemode)
                stackText:SetTextColor(stackOpt.fontColor.r, stackOpt.fontColor.g, stackOpt.fontColor.b)
                stackText:SetShadowColor(stackOpt.shadowColor.r, stackOpt.shadowColor.g, stackOpt.shadowColor.b, stackOpt.shadowColor.a)
                stackText:SetShadowOffset(stackOpt.xOffsetShadow, stackOpt.yOffsetShadow)
                --Swipe Settings
                cooldown:SetDrawSwipe(frameOpt.swipe)
                cooldown:SetReverse(frameOpt.inverse)
                cooldown:SetDrawEdge(frameOpt.edge)
            end
        end

        -- set anchor and resize
        local anchorSet, prevFrame
        for i = 1, frame_registry[frame].maxBuffs do
            local buffFrame = frame.buffFrames[i] or frame_registry[frame].extraBuffFrames[i]
            if not anchorSet then
                buffFrame:ClearAllPoints()
                buffFrame:SetPoint(point, frame, relativePoint, frameOpt.xOffset, frameOpt.yOffset)
                anchorSet = true
            else
                buffFrame:ClearAllPoints()
                buffFrame:SetPoint(followPoint, prevFrame, followRelativePoint, 0, 0)
            end
            prevFrame = buffFrame
            resizeBuffFrame(buffFrame)
        end
        for _, place in pairs(userPlaced) do
            local idx = frame_registry[frame].placedAuraStart + place.idx - 1
            local buffFrame = frame_registry[frame].extraBuffFrames[idx]
            buffFrame:ClearAllPoints()
            buffFrame:SetPoint(place.point, frame, place.relativePoint, place.xOffset, place.yOffset)
            resizeBuffFrame(buffFrame)
        end

        onHideAllBuffs(frame)
    end
    self:HookFuncFiltered("DefaultCompactUnitFrameSetup", onFrameSetup)

    for _, v in pairs(frame_registry) do
        v.dirty = true
    end
    addon:IterateRoster(function(frame)
        onFrameSetup(frame)
        if frame_registry[frame] then
            CompactUnitFrame_UpdateAuras(frame)
        end
    end)

    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        for frame, v in pairs(frame_registry) do
            if v.lockdown and v.dirty then
                onFrameSetup(frame)
            end
        end
    end)
end

--parts of this code are from FrameXML/CompactUnitFrame.lua
function Buffs:OnDisable()
    module_enabled = false

    self:DisableHooks()
    local restoreBuffFrames = function(frame)
        if frame_registry[frame] then
            frame_registry[frame].dirty = true
            for _, buffFrame in pairs(frame.buffFrames) do
                buffFrame:Hide()
            end
            for _, extraBuffFrame in pairs(frame_registry[frame].extraBuffFrames) do
                extraBuffFrame:Hide()
            end
        end

        local frameWidth = frame:GetWidth()
        local frameHeight = frame:GetHeight()
        local componentScale = min(frameWidth / NATIVE_UNIT_FRAME_HEIGHT, frameWidth / NATIVE_UNIT_FRAME_WIDTH)
        local Display = math.min(15, 11 * componentScale)
        local powerBarUsedHeight = frame.powerBar:IsShown() and frame.powerBar:GetHeight() or 0
        local buffPos, buffRelativePoint, buffOffset = "BOTTOMRIGHT", "BOTTOMLEFT", CUF_AURA_BOTTOM_OFFSET + powerBarUsedHeight;
        frame.buffFrames[1]:ClearAllPoints();
        frame.buffFrames[1]:SetPoint(buffPos, frame, "BOTTOMRIGHT", -3, buffOffset);
        for i=1, #frame.buffFrames do
            local buffFrame = frame.buffFrames[i]
            buffFrame:SetFrameStrata(frame:GetFrameStrata())
            buffFrame:SetSize(Display, Display)
            buffFrame.icon:SetTexCoord(0,1,0,1)
            if ( i > 1 ) then
                buffFrame:ClearAllPoints();
                buffFrame:SetPoint(buffPos, frame.buffFrames[i - 1], buffRelativePoint, 0, 0);
            end
            local cooldown = buffFrame.cooldown
            cooldown:SetDrawSwipe(true)
            cooldown:SetReverse(true)
            cooldown:SetDrawEdge(false)
            CDT:DisableCooldownText(cooldown)
            if cooldown.count then
                cooldown.count:Hide()
            end
            if cooldown.OmniCC then
                OmniCC.Cooldown.SetNoCooldownCount(cooldown, cooldown.OmniCC.noCooldownCount)
                cooldown.OmniCC = nil
            end
        end

        CompactUnitFrame_UpdateAuras(frame)
    end
    addon:IterateRoster(restoreBuffFrames)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
end