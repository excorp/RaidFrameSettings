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

function Buffs:OnEnable()
    CDT.TimerTextLimit = addon.db.profile.MinorModules.TimerTextLimit

    local frameOpt = CopyTable(addon.db.profile.Buffs.BuffFramesDisplay)
    frameOpt.framestrata = addon:ConvertDbNumberToFrameStrata(frameOpt.framestrata)
    frameOpt.baseline = addon:ConvertDbNumberToBaseline(frameOpt.baseline)
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

    local onSetBuff = function(buffFrame, aura)
        if buffFrame:IsForbidden() or not buffFrame:IsVisible() then --not sure if this is still neede but when i created it at the start if dragonflight it was
            return
        end
        local cooldown = buffFrame.cooldown
        if not cooldown._rfs_cd_text then
            return
        end
        CDT:StartCooldownText(cooldown)
        cooldown:SetDrawEdge(frameOpt.edge)

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

            if aura.applications > 0 then
                if aura.duration == 0 then
                    buffFrame.count:SetParent(buffFrame)
                else
                    buffFrame.count:SetParent(cooldown)
                end
            end
        end
    end
    self:HookFunc("CompactUnitFrame_UtilSetBuff", onSetBuff)

    local onHideAllBuffs = function(frame)
        if not frame_registry[frame] or frame:IsForbidden() or not frame:IsVisible() then
            return
        end

        -- set placed aura / other aura
        local frameNum = 1
        local groupFrameNum = {}
        local sorted = {
            [0] = {},
        }
        frame.buffs:Iterate(function(auraInstanceID, aura)
            if userPlaced[aura.spellId] then
                local idx = frame_registry[frame].placedAuraStart + userPlaced[aura.spellId].idx - 1
                local buffFrame = frame_registry[frame].extraBuffFrames[idx]
                local placed = userPlaced[aura.spellId]
                CompactUnitFrame_UtilSetBuff(buffFrame, aura)
                return false
            end
            if auraGroupList[aura.spellId] then
                local groupNo = auraGroupList[aura.spellId]
                local auraList = auraGroup[groupNo].auraList
                local priority = auraList[aura.spellId].priority > 0 and auraList[aura.spellId].priority or filteredAuras[aura.spellId] and filteredAuras[aura.spellId].priority or 0
                if not sorted[groupNo] then sorted[groupNo] = {} end
                tinsert(sorted[groupNo], { spellId = aura.spellId, priority = priority, aura = aura })
                groupFrameNum[groupNo] = groupFrameNum[groupNo] and (groupFrameNum[groupNo] + 1) or 2
                return false
            end
            if frameNum <= frame_registry[frame].maxBuffs then
                local priority = filteredAuras[aura.spellId] and filteredAuras[aura.spellId].priority or 0
                tinsert(sorted[0], { spellId = aura.spellId, priority = priority, aura = aura })
                frameNum = frameNum + 1
            end
            return false
        end)
        -- set buffs after sorting to priority.
        for _, v in pairs(sorted) do
            table.sort(v, comparePriority)
        end
        for groupNo, auralist in pairs(sorted) do
            for k, v in pairs(auralist) do
                if groupNo == 0 then
                    -- default aura frame
                    local buffFrame = frame.buffFrames[k] or frame_registry[frame].extraBuffFrames[k]
                    CompactUnitFrame_UtilSetBuff(buffFrame, v.aura)
                else
                    -- aura group frame
                    local idx = frame_registry[frame].auraGroupStart[groupNo] + k - 1
                    local buffFrame = frame_registry[frame].extraBuffFrames[idx]
                    CompactUnitFrame_UtilSetBuff(buffFrame, v.aura)
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
                buffFrame:Hide()
                CooldownFrame_Clear(buffFrame.cooldown)
            end
        end
        for i = frameNum, math.max(frame_registry[frame].maxBuffs, frame.maxBuffs) do
            local buffFrame = frame.buffFrames[i] or frame_registry[frame].extraBuffFrames[i]
            buffFrame:Hide()
            CooldownFrame_Clear(buffFrame.cooldown)
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
                buffFrame:Hide()
                CooldownFrame_Clear(buffFrame.cooldown)
            end
        end
    end
    self:HookFunc("CompactUnitFrame_HideAllBuffs", onHideAllBuffs)

    local function onFrameSetup(frame)
        if frame.maxBuffs == 0 or not frame.buffs then
            return
        end

        if not frame_registry[frame] then
            frame_registry[frame] = {
                maxBuffs        = frameOpt.maxbuffsAuto and frame.maxBuffs or frameOpt.maxbuffs,
                placedAuraStart = 0,
                auraGroupStart  = {},
                auraGroupEnd    = {},
                extraBuffFrames = {},
                reanchor        = {},
                dirty           = true,
            }
        end

        if frame_registry[frame].dirty then
            frame_registry[frame].maxBuffs = frameOpt.maxbuffsAuto and frame.maxBuffs or frameOpt.maxbuffs
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
                buffFrame:ClearAllPoints()
                buffFrame.icon:SetTexCoord(0, 1, 0, 1)
                placedAuraStart = i + 1
            end
            frame_registry[frame].placedAuraStart = placedAuraStart

            for i = 1, maxUserPlaced + maxAuraGroup do
                local idx = placedAuraStart + i - 1
                local buffFrame = frame_registry[frame].extraBuffFrames[idx]
                if not buffFrame then
                    buffFrame = CreateFrame("Button", nil, nil, "CompactBuffTemplate")
                    buffFrame:SetParent(frame)
                    buffFrame:Hide()
                    buffFrame.cooldown:SetHideCountdownNumbers(true)
                    frame_registry[frame].extraBuffFrames[idx] = buffFrame
                end
                buffFrame:ClearAllPoints()
                buffFrame.icon:SetTexCoord(0, 1, 0, 1)
            end

            for i = 1, frame_registry[frame].maxBuffs + maxUserPlaced + maxAuraGroup do
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
                    local res = cooldownText:SetFont(durationOpt.font, durationOpt.fontSize, durationOpt.outlinemode)
                    if not res then
                        fontObj:SetFontObject("NumberFontNormalSmall")
                        cooldownText:SetFont(fontObj:GetFont())
                        frame_registry[frame].dirty = true
                    end
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
                local stackText = buffFrame.count
                stackText:ClearAllPoints()
                stackText:SetPoint(stackOpt.point, buffFrame, stackOpt.relativePoint, stackOpt.xOffsetFont, stackOpt.yOffsetFont)
                local res = stackText:SetFont(stackOpt.font, stackOpt.fontSize, stackOpt.outlinemode)
                if not res then
                    fontObj:SetFontObject("NumberFontNormalSmall")
                    stackText:SetFont(fontObj:GetFont())
                    frame_registry[frame].dirty = true
                end
                stackText:SetTextColor(stackOpt.fontColor.r, stackOpt.fontColor.g, stackOpt.fontColor.b)
                stackText:SetShadowColor(stackOpt.shadowColor.r, stackOpt.shadowColor.g, stackOpt.shadowColor.b, stackOpt.shadowColor.a)
                stackText:SetShadowOffset(stackOpt.xOffsetShadow, stackOpt.yOffsetShadow)
                stackText:SetParent(cooldown)
                --Swipe Settings
                cooldown:SetDrawSwipe(frameOpt.swipe)
                cooldown:SetReverse(frameOpt.inverse)
                cooldown:SetDrawEdge(frameOpt.edge)
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

            for _, v in pairs(frame.buffFrames) do
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
                        GameTooltip:Hide();
                        self:SetScript("OnUpdate", nil)
                    end)
                else
                    v:SetScript("OnUpdate", nil)
                    v:SetScript("OnEnter", nil)
                    v:SetScript("OnLeave", nil)
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
                    v:SetScript("OnLeave", function()
                        GameTooltip:Hide();
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
            local buffFrame = frame.buffFrames[i] or frame_registry[frame].extraBuffFrames[i]
            if not anchorSet then
                buffFrame:ClearAllPoints()
                buffFrame:SetPoint(point, frame, relativePoint, frameOpt.xOffset, frameOpt.yOffset)
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

    for _, v in pairs(frame_registry) do
        v.dirty = true
    end
    addon:IterateRoster(function(frame)
        onFrameSetup(frame)
        if frame.unit then
            if frame:IsShown() then
                frame:Hide()
                frame:Show()
            end
        end
    end)
end

--parts of this code are from FrameXML/CompactUnitFrame.lua
function Buffs:OnDisable()
    self:DisableHooks()
    local restoreBuffFrames = function(frame)
        if not frame_registry[frame] then
            return
        end
        for _, buffFrame in pairs(frame.buffFrames) do
            buffFrame:SetScript("OnUpdate", nil)
            buffFrame:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, 0)
                self:UpdateTooltip()
                local function RunOnUpdate()
                    if (GameTooltip:IsOwned(self)) then
                        self:UpdateTooltip()
                    end
                end
                self:SetScript("OnUpdate", RunOnUpdate)
            end)
            buffFrame:SetScript("OnLeave", function()
                GameTooltip:Hide();
                self:SetScript("OnUpdate", nil)
            end)
            buffFrame:Hide()
        end
        for _, extraBuffFrame in pairs(frame_registry[frame].extraBuffFrames) do
            extraBuffFrame:Hide()
        end

        local frameWidth = frame:GetWidth()
        local frameHeight = frame:GetHeight()
        local componentScale = min(frameWidth / NATIVE_UNIT_FRAME_HEIGHT, frameWidth / NATIVE_UNIT_FRAME_WIDTH)
        local Display = math.min(15, 11 * componentScale)
        local powerBarUsedHeight = frame.powerBar:IsShown() and frame.powerBar:GetHeight() or 0
        local buffPos, buffRelativePoint, buffOffset = "BOTTOMRIGHT", "BOTTOMLEFT", CUF_AURA_BOTTOM_OFFSET + powerBarUsedHeight;
        frame.buffFrames[1]:ClearAllPoints();
        frame.buffFrames[1]:SetPoint(buffPos, frame, "BOTTOMRIGHT", -3, buffOffset);
        for i = 1, #frame.buffFrames do
            local buffFrame = frame.buffFrames[i]
            buffFrame:SetFrameStrata(frame:GetFrameStrata())
            buffFrame:SetSize(Display, Display)
            buffFrame.icon:SetTexCoord(0, 1, 0, 1)
            if (i > 1) then
                buffFrame:ClearAllPoints();
                buffFrame:SetPoint(buffPos, frame.buffFrames[i - 1], buffRelativePoint, 0, 0);
            end
            local cooldown = buffFrame.cooldown
            cooldown:SetDrawSwipe(true)
            cooldown:SetReverse(true)
            cooldown:SetDrawEdge(false)
            CDT:DisableCooldownText(cooldown)
            local stackText = buffFrame.count
            stackText:ClearAllPoints()
            stackText:SetPoint("BOTTOMRIGHT", buffFrame, "BOTTOMRIGHT", 0, 0)
            fontObj:SetFontObject("NumberFontNormalSmall")
            stackText:SetFont(fontObj:GetFont())
            stackText:SetTextColor(fontObj:GetTextColor())
            stackText:SetShadowColor(fontObj:GetShadowColor())
            stackText:SetShadowOffset(fontObj:GetShadowOffset())
            stackText:SetParent(buffFrame)
            if cooldown.OmniCC then
                OmniCC.Cooldown.SetNoCooldownCount(cooldown, cooldown.OmniCC.noCooldownCount)
                cooldown.OmniCC = nil
            end
        end

        if frame.unit then
            CompactUnitFrame_UpdateAuras(frame)
        end
    end
    addon:IterateRoster(restoreBuffFrames)
end
