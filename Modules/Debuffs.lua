--[[
    Created by Slothpala
    The aura indicator position and the aura timers are greatly inspired by a pull request from: https://github.com/excorp
--]]
local _, addonTable = ...
local addon = addonTable.RaidFrameSettings
local Debuffs = addon:NewModule("Debuffs")
Mixin(Debuffs, addonTable.hooks)
local CDT = addonTable.cooldownText
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
local roster_changed = true

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

    local frameOpt = CopyTable(addon.db.profile.Debuffs.DebuffFramesDisplay)
    frameOpt.framestrata = addon:ConvertDbNumberToFrameStrata(frameOpt.framestrata)
    frameOpt.baseline = addon:ConvertDbNumberToBaseline(frameOpt.baseline)

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
            debuffFrame.border:SetTexture("Interface\\AddOns\\RaidFrameSettings_Fork\\Textures\\DebuffOverlay_clean_icons.tga")
            debuffFrame.border:SetTexCoord(0, 1, 0, 1)
            debuffFrame.border:SetTextureSliceMargins(5.01, 26.09, 5.01, 26.09)
            debuffFrame.border:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
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

    local onSetDebuff = function(debuffFrame, aura)
        if debuffFrame:IsForbidden() or not debuffFrame:IsVisible() then --not sure if this is still neede but when i created it at the start if dragonflight it was
            return
        end
        local parent = debuffFrame:GetParent()
        if not parent or not frame_registry[parent] then
            return
        end
        local cooldown = debuffFrame.cooldown
        if not cooldown._rfs_cd_text then
            return
        end
        CDT:StartCooldownText(cooldown)
        cooldown:SetDrawEdge(frameOpt.edge)

        local color = durationOpt.fontColor
        if aura.dispelName then
            color = debuffColors[aura.dispelName]
        end
        if Bleeds[aura.spellId] then
            color = debuffColors.Bleed
        end
        debuffFrame.border:SetVertexColor(color.r, color.g, color.b)

        if not durationOpt.debuffColor then
            color = durationOpt.fontColor
        end
        local cooldownText = CDT:CreateOrGetCooldownFontString(cooldown)
        cooldownText:SetVertexColor(color.r, color.g, color.b)

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

            if aura.applications > 0 then
                if aura.duration == 0 then
                    debuffFrame.count:SetParent(debuffFrame)
                else
                    debuffFrame.count:SetParent(cooldown)
                end
            end
        end
    end
    self:HookFunc("CompactUnitFrame_UtilSetDebuff", onSetDebuff)

    local function onUpdatePrivateAuras(frame)
        if not frame.PrivateAuraAnchors or not frame_registry[frame] or frame:IsForbidden() or not frame:IsVisible() then
            return
        end

        local lastShownDebuff
        for i = frame_registry[frame].maxDebuffs, 1, -1 do
            local debuff = frame.debuffFrames[i] or frame_registry[frame].extraDebuffFrames[i]
            if debuff and debuff:IsShown() then
                lastShownDebuff = debuff
                break
            end
        end
        frame.PrivateAuraAnchor1:ClearAllPoints()
        if lastShownDebuff then
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

        -- set placed aura / other aura
        local frameNum = 1
        local groupFrameNum = {}
        local sorted = {
            [0] = {},
        }
        frame.debuffs:Iterate(function(auraInstanceID, aura)
            if userPlaced[aura.spellId] then
                local idx = frame_registry[frame].placedAuraStart + userPlaced[aura.spellId].idx - 1
                local debuffFrame = frame_registry[frame].extraDebuffFrames[idx]
                local placed = userPlaced[aura.spellId]
                CompactUnitFrame_UtilSetDebuff(debuffFrame, aura)
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
            if frameNum <= frame_registry[frame].maxDebuffs then
                local priority = filteredAuras[aura.spellId] and filteredAuras[aura.spellId].priority or 0
                tinsert(sorted[0], { spellId = aura.spellId, priority = priority, aura = aura })
                frameNum = frameNum + 1
            end
            return false
        end)
        -- set debuffs after sorting to priority.
        for _, v in pairs(sorted) do
            table.sort(v, comparePriority)
        end
        for groupNo, auralist in pairs(sorted) do
            for k, v in pairs(auralist) do
                if groupNo == 0 then
                    -- default aura frame
                    local debuffFrame = frame.debuffFrames[k] or frame_registry[frame].extraDebuffFrames[k]
                    CompactUnitFrame_UtilSetDebuff(debuffFrame, v.aura)
                else
                    -- aura group frame
                    local idx = frame_registry[frame].auraGroupStart[groupNo] + k - 1
                    local debuffFrame = frame_registry[frame].extraDebuffFrames[idx]
                    CompactUnitFrame_UtilSetDebuff(debuffFrame, v.aura)
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
                debuffFrame:Hide()
                CooldownFrame_Clear(debuffFrame.cooldown)
            end
        end
        for i = frameNum, math.max(frame_registry[frame].maxDebuffs, frame.maxDebuffs) do
            local debuffFrame = frame.debuffFrames[i] or frame_registry[frame].extraDebuffFrames[i]
            debuffFrame:Hide()
            CooldownFrame_Clear(debuffFrame.cooldown)
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
                debuffFrame:Hide()
                CooldownFrame_Clear(debuffFrame.cooldown)
            end
        end

        onUpdatePrivateAuras(frame)
    end
    self:HookFunc("CompactUnitFrame_HideAllDebuffs", onHideAllDebuffs)

    local function onFrameSetup(frame)
        local fname = frame:GetName()
        if not fname or fname:match("Pet") then
            return
        end

        if not frame_registry[frame] then
            frame_registry[frame] = {
                maxDebuffs        = frameOpt.maxdebuffs,
                placedAuraStart   = 0,
                auraGroupStart    = {},
                auraGroupEnd      = {},
                extraDebuffFrames = {},
                reanchor          = {},
                dirty             = true,
            }
        end

        if frame_registry[frame].dirty then
            frame_registry[frame].maxDebuffs = frameOpt.maxdebuffs
            frame_registry[frame].dirty = false
            local placedAuraStart = frame.maxDebuffs + 1
            for i = frame.maxDebuffs + 1, frame_registry[frame].maxDebuffs do
                local debuffFrame = frame.debuffFrames[i] or frame_registry[frame].extraDebuffFrames[i]
                if not debuffFrame then
                    debuffFrame = CreateFrame("Button", nil, nil, "CompactDebuffTemplate")
                    debuffFrame:SetParent(frame)
                    debuffFrame:Hide()
                    debuffFrame.baseSize = width
                    debuffFrame.maxHeight = width
                    debuffFrame.cooldown:SetHideCountdownNumbers(true)
                    frame_registry[frame].extraDebuffFrames[i] = debuffFrame
                end
                debuffFrame:ClearAllPoints()
                debuffFrame.icon:SetTexCoord(0, 1, 0, 1)
                debuffFrame.border:SetTexture("Interface\\BUTTONS\\UI-Debuff-Overlays")
                debuffFrame.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
                debuffFrame.border:SetTextureSliceMargins(0, 0, 0, 0)
                placedAuraStart = i + 1
            end
            frame_registry[frame].placedAuraStart = placedAuraStart

            for i = 1, maxUserPlaced + maxAuraGroup do
                local idx = placedAuraStart + i - 1
                local debuffFrame = frame_registry[frame].extraDebuffFrames[idx]
                if not debuffFrame then
                    debuffFrame = CreateFrame("Button", nil, nil, "CompactDebuffTemplate")
                    debuffFrame:SetParent(frame)
                    debuffFrame:Hide()
                    debuffFrame.baseSize = width
                    debuffFrame.maxHeight = width
                    debuffFrame.cooldown:SetHideCountdownNumbers(true)
                    frame_registry[frame].extraDebuffFrames[idx] = debuffFrame
                end
                debuffFrame:ClearAllPoints()
                debuffFrame.icon:SetTexCoord(0, 1, 0, 1)
                debuffFrame.border:SetTexture("Interface\\BUTTONS\\UI-Debuff-Overlays")
                debuffFrame.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
                debuffFrame.border:SetTextureSliceMargins(0, 0, 0, 0)
            end

            for i = 1, frame_registry[frame].maxDebuffs + maxUserPlaced + maxAuraGroup do
                local debuffFrame = frame_registry[frame].extraDebuffFrames[i] or frame.debuffFrames[i]
                if frameOpt.framestrata ~= "Inherited" then
                    debuffFrame:SetFrameStrata(frameOpt.framestrata)
                end
                --Timer Settings
                local cooldown = debuffFrame.cooldown
                if frameOpt.timerText then
                    local cooldownText = CDT:CreateOrGetCooldownFontString(cooldown)
                    cooldownText:ClearAllPoints()
                    cooldownText:SetPoint(durationOpt.point, debuffFrame, durationOpt.relativePoint, durationOpt.xOffsetFont, durationOpt.yOffsetFont)
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
                local stackText = debuffFrame.count
                stackText:ClearAllPoints()
                stackText:SetPoint(stackOpt.point, debuffFrame, stackOpt.relativePoint, stackOpt.xOffsetFont, stackOpt.yOffsetFont)
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

            for _, v in pairs(frame.debuffFrames) do
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
        for i = 1, frame_registry[frame].maxDebuffs do
            local debuffFrame = frame.debuffFrames[i] or frame_registry[frame].extraDebuffFrames[i]
            if not anchorSet then
                debuffFrame:ClearAllPoints()
                debuffFrame:SetPoint(point, frame, relativePoint, frameOpt.xOffset, frameOpt.yOffset)
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
    end
    self:HookFuncFiltered("DefaultCompactUnitFrameSetup", onFrameSetup)

    if roster_changed then
        roster_changed = false
        addon:IterateRoster(function(frame)
            local fname = frame:GetName()
            if not fname or fname:match("Pet") then
                return
            end
            if not frame_registry[frame] then
                frame_registry[frame] = {
                    maxDebuffs        = frameOpt.maxdebuffs,
                    placedAuraStart   = 0,
                    auraGroupStart    = {},
                    auraGroupEnd      = {},
                    extraDebuffFrames = {},
                    reanchor          = {},
                    dirty             = true,
                }
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
        for _, debuffFrame in pairs(frame.debuffFrames) do
            debuffFrame:SetScript("OnUpdate", nil)
            debuffFrame:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, 0)
                self:UpdateTooltip()
                local function RunOnUpdate()
                    if (GameTooltip:IsOwned(self)) then
                        self:UpdateTooltip()
                    end
                end
                self:SetScript("OnUpdate", RunOnUpdate)
            end)
            debuffFrame:SetScript("OnLeave", function()
                GameTooltip:Hide();
                self:SetScript("OnUpdate", nil)
            end)
            debuffFrame:Hide()
        end
        for _, extraDebuffFrame in pairs(frame_registry[frame].extraDebuffFrames) do
            extraDebuffFrame:Hide()
        end

        local frameWidth = frame:GetWidth()
        local frameHeight = frame:GetHeight()
        local componentScale = min(frameWidth / NATIVE_UNIT_FRAME_HEIGHT, frameWidth / NATIVE_UNIT_FRAME_WIDTH)
        local buffSize = math.min(15, 11 * componentScale)
        for i = 1, #frame.debuffFrames do
            frame.debuffFrames[i]:SetSize(buffSize, buffSize)
        end
        local powerBarUsedHeight = frame.powerBar:IsShown() and frame.powerBar:GetHeight() or 0
        local debuffPos, debuffRelativePoint, debuffOffset = "BOTTOMLEFT", "BOTTOMRIGHT", CUF_AURA_BOTTOM_OFFSET + powerBarUsedHeight
        frame.debuffFrames[1]:ClearAllPoints()
        frame.debuffFrames[1]:SetPoint(debuffPos, frame, "BOTTOMLEFT", 3, debuffOffset)
        for i = 1, #frame.debuffFrames do
            local debuffFrame = frame.debuffFrames[i]
            debuffFrame:SetFrameStrata(frame:GetFrameStrata())
            debuffFrame.border:SetTexture("Interface\\BUTTONS\\UI-Debuff-Overlays")
            debuffFrame.border:SetTexCoord(0.296875, 0, 0.296875, 0.515625, 0.5703125, 0, 0.5703125, 0.515625)
            debuffFrame.border:SetTextureSliceMargins(0, 0, 0, 0)
            debuffFrame.icon:SetTexCoord(0, 1, 0, 1)
            if (i > 1) then
                debuffFrame:ClearAllPoints();
                debuffFrame:SetPoint(debuffPos, frame.debuffFrames[i - 1], debuffRelativePoint, 0, 0);
            end
            local cooldown = debuffFrame.cooldown
            cooldown:SetDrawSwipe(true)
            cooldown:SetReverse(false)
            cooldown:SetDrawEdge(false)
            CDT:DisableCooldownText(cooldown)
            local stackText = debuffFrame.count
            stackText:ClearAllPoints()
            stackText:SetPoint("BOTTOMRIGHT", debuffFrame, "BOTTOMRIGHT", 0, 0)
            fontObj:SetFontObject("NumberFontNormalSmall")
            stackText:SetFont(fontObj:GetFont())
            stackText:SetTextColor(fontObj:GetTextColor())
            stackText:SetShadowColor(fontObj:GetShadowColor())
            stackText:SetShadowOffset(fontObj:GetShadowOffset())
            stackText:SetParent(debuffFrame)
            if cooldown.OmniCC then
                OmniCC.Cooldown.SetNoCooldownCount(cooldown, cooldown.OmniCC.noCooldownCount)
                cooldown.OmniCC = nil
            end
        end

        if frame.unit and frame.unitExists and frame:IsShown() and not frame:IsForbidden() then
            CompactUnitFrame_UpdateAuras(frame)
        end
    end
    for frame in pairs(frame_registry) do
        restoreDebuffFrames(frame)
    end
end
