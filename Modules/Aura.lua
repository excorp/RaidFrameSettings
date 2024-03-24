local _, addonTable = ...
local isVanilla, isWrath, isClassic, isRetail = addonTable.isVanilla, addonTable.isWrath, addonTable.isClassic, addonTable.isRetail
local addon = addonTable.RaidFrameSettings
addonTable.Aura = {}
local Aura = addonTable.Aura
local CDT = addonTable.cooldownText

local fontObj = CreateFont("RaidFrameSettingsFont")

-- mouseover queue
local TooltipCheckQueueAll = {}
local TooltipCheckQueueWhere = {}
local TooltipCheckQueueUnknownPos = {}
local TooltipCheckQueueUnderFrame = {}
local TooltipCheckOnUpdateFrame = CreateFrame("Frame")

Aura.Opt = {
    Buff = {
        frameOpt = {},
        stackOpt = {},
        durationOpt = {},
    },
    Debuff = {
        frameOpt = {},
        stackOpt = {},
        durationOpt = {},
    },
}

local iconCrop = 0

local function GetTexCoord(width, height)
    -- ULx,ULy, LLx,LLy, URx,URy, LRx,LRy
    local texCoord = { iconCrop, iconCrop, iconCrop, 1 - iconCrop, 1 - iconCrop, iconCrop, 1 - iconCrop, 1 - iconCrop }
    local aspectRatio = width / height

    local xRatio = aspectRatio < 1 and aspectRatio or 1
    local yRatio = aspectRatio > 1 and 1 / aspectRatio or 1

    for i, coord in ipairs(texCoord) do
        local aspectRatio = (i % 2 == 1) and xRatio or yRatio
        texCoord[i] = (coord - 0.5) * aspectRatio + 0.5
    end

    return texCoord
end

function Aura:reset()
    TooltipCheckQueueWhere = {}
end

function Aura:framesOverlap(frame1, frame2)
    local frame1Left = frame1:GetLeft()
    local frame1Right = frame1:GetRight()
    local frame1Top = frame1:GetTop()
    local frame1Bottom = frame1:GetBottom()

    local frame2Left = frame2:GetLeft()
    local frame2Right = frame2:GetRight()
    local frame2Top = frame2:GetTop()
    local frame2Bottom = frame2:GetBottom()

    if frame1Left == nil or frame1Right == nil or frame1Top == nil or frame1Bottom == nil or
        frame2Left == nil or frame2Right == nil or frame2Top == nil or frame2Bottom == nil then
        return false
    end

    -- Check if frames overlap
    if frame1Left < frame2Right and frame1Right > frame2Left and frame1Top > frame2Bottom and frame1Bottom < frame2Top then
        return true
    else
        return false
    end
end

function Aura:createAuraFrame(frame, category, type, idx) -- category:Buff,Debuff, type=blizzard,baricon
    local fname = frame:GetName()
    local name = fname .. "Extra" .. category .. idx .. type
    local auraFrame = _G[name]

    local frameOpt = self.Opt[category].frameOpt
    local stackOpt = self.Opt[category].stackOpt
    local durationOpt = self.Opt[category].durationOpt

    local scale = frame:GetScale()
    local border_size = 1.5 * scale

    -- Create Aura Frame
    if not auraFrame then
        if type == "blizzard" then
            auraFrame = CreateFrame("Button", name, frame, "Compact" .. category .. "Template")
            auraFrame:Hide()
            auraFrame.cooldown:SetHideCountdownNumbers(true)

            local textFrame = CreateFrame("Frame", nil, auraFrame)
            auraFrame.textFrame = textFrame
            textFrame:SetAllPoints(auraFrame)
            textFrame:SetFrameLevel(auraFrame.cooldown:GetFrameLevel() + 1)
            auraFrame.count:SetParent(textFrame)

            auraFrame:SetScript("OnSizeChanged", function(self, width, height)
                -- keep aspect ratio
                auraFrame:SetCoord(width, height)
            end)

            function auraFrame:SetCoord(width, height)
                -- keep aspect ratio
                auraFrame.icon:SetTexCoord(unpack(GetTexCoord(width, height)))
            end

            function auraFrame.cooldown:_SetCooldown(aura)
                local enabled = aura and aura.expirationTime and aura.expirationTime ~= 0
                if enabled then
                    local startTime = aura.expirationTime - aura.duration
                    CooldownFrame_Set(self, startTime, aura.duration, true)
                    if self.timerText then
                        local ps = self._rfs_cd_text
                        ps.elapsed = GetTime() - startTime
                        ps.duration = aura.duration
                        CDT:StartCooldownText(self)
                    end
                    self:SetDrawEdge(self.edge)

                    if aura.refresh then
                        auraFrame.ag:Play()
                        aura.refresh = nil
                    end
                else
                    CooldownFrame_Clear(self)
                    CDT:StopCooldownText(self)
                end
            end

            function auraFrame:SetAura(aura)
                self.icon:SetTexture(aura.icon)
                if (aura.applications > 1 or (aura.applications >= 1 and aura.applicationsp)) then
                    local countText = aura.applications .. (aura.applicationsp or "")
                    if (aura.applications >= 100) then
                        countText = BUFF_STACKS_OVERFLOW
                    end
                    auraFrame.count:Show()
                    auraFrame.count:SetText(countText)
                else
                    auraFrame.count:Hide()
                end
                auraFrame.auraInstanceID = aura.auraInstanceID
                self.cooldown:_SetCooldown(aura)
                auraFrame:Show()
            end

            function auraFrame:UnsetAura()
                self.cooldown:_SetCooldown()
                self:Hide()
            end

            function auraFrame:SetBorderColor(r, g, b, a)
                self.border:SetVertexColor(r, g, b, a)
            end
        elseif type == "baricon" then
            -- bar icon
            auraFrame = CreateFrame("Frame", name, frame, "BackdropTemplate")
            auraFrame:Hide()
            auraFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            auraFrame:SetBackdropColor(0, 0, 0, 1)

            local icon = auraFrame:CreateTexture(name .. "Icon", "ARTWORK")
            auraFrame.icon = icon
            if category == "Buff" then
                icon:SetAllPoints(auraFrame)
            else
                icon:SetPoint("TOPLEFT", auraFrame, "TOPLEFT", border_size, -border_size)
                icon:SetPoint("BOTTOMRIGHT", auraFrame, "BOTTOMRIGHT", -border_size, border_size)
            end

            local cooldown = CreateFrame("StatusBar", name .. "CooldownBar", auraFrame)
            auraFrame.cooldown = cooldown
            cooldown.swipe = frameOpt.swipe
            cooldown.edge = frameOpt.edge
            cooldown:SetPoint("TOPLEFT", auraFrame.icon)
            cooldown:SetPoint("BOTTOMRIGHT", auraFrame.icon)
            cooldown:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
            cooldown:GetStatusBarTexture():SetAlpha(0)

            local spark = cooldown:CreateTexture(nil, "OVERLAY")
            auraFrame.spark = spark
            spark:SetBlendMode("ADD")
            spark:SetColorTexture(0.5, 0.5, 0.5, 1)

            local mask = auraFrame:CreateMaskTexture()
            auraFrame.mask = mask
            mask:SetTexture("Interface\\Buttons\\WHITE8x8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

            local maskIcon = cooldown:CreateTexture(name .. "MaskIcon", "ARTWORK")
            auraFrame.maskIcon = maskIcon
            maskIcon:SetDesaturated(true)
            maskIcon:SetAllPoints(icon)
            maskIcon:SetVertexColor(0.5, 0.5, 0.5, 1)
            maskIcon:AddMaskTexture(mask)

            auraFrame:SetScript("OnSizeChanged", function(self, width, height)
                self.overwrapWithParent = Aura:framesOverlap(frame, self)
                self:SetCoord(width, height)
            end)

            local textFrame = CreateFrame("Frame", nil, auraFrame)
            auraFrame.textFrame = textFrame
            textFrame:SetAllPoints(auraFrame)
            textFrame:SetFrameLevel(cooldown:GetFrameLevel() + 1)

            local count = textFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            auraFrame.count = count
            count:SetJustifyH("RIGHT")
            count:SetPoint("BOTTOMRIGHT", textFrame, "BOTTOMRIGHT", 0, 0)

            function auraFrame:SetCoord(width, height)
                -- keep aspect ratio
                icon:SetTexCoord(unpack(GetTexCoord(width, height)))
                maskIcon:SetTexCoord(unpack(GetTexCoord(width, height)))
            end

            function auraFrame.cooldown:_SetCooldown(aura)
                local enabled = aura and aura.expirationTime and aura.expirationTime ~= 0
                if enabled then
                    local startTime = aura.expirationTime - aura.duration
                    local elasped = GetTime() - startTime
                    if self.swipe or self.edge then
                        self.elapsed = 0
                        self:SetMinMaxValues(0, aura.duration)
                        self:SetValue(elasped)
                        self:Show()

                        self:SetScript("OnUpdate", function(self, elapsed)
                            self.elapsed = self.elapsed + elapsed
                            if self.elapsed >= 0.1 then
                                self:SetValue(self:GetValue() + self.elapsed)
                                self.elapsed = 0
                            end
                        end)
                    else
                        self:SetScript("OnUpdate", nil)
                        self:SetMinMaxValues(0, 1)
                        self:SetValue(0)
                        self:Show()
                    end
                    if self.timerText then
                        local fs = self._rfs_cd_text
                        fs.elapsed = elasped
                        fs.duration = aura.duration
                        CDT:StartCooldownText(self)
                    end

                    if aura.refresh then
                        auraFrame.ag:Play()
                        aura.refresh = nil
                    end
                else
                    self:Hide()
                    self:SetScript("OnUpdate", nil)
                    CDT:StopCooldownText(self)
                end
            end

            function auraFrame:SetAura(aura)
                auraFrame.icon:SetTexture(aura.icon)
                auraFrame.maskIcon:SetTexture(aura.icon)

                if (aura.applications > 1 or (aura.applications >= 1 and aura.applicationsp)) then
                    local countText = aura.applications .. (aura.applicationsp or "")
                    if (aura.applications >= 100) then
                        countText = BUFF_STACKS_OVERFLOW
                    end
                    auraFrame.count:Show()
                    auraFrame.count:SetText(countText)
                else
                    auraFrame.count:Hide()
                end
                auraFrame.auraInstanceID = aura.auraInstanceID
                self.cooldown:_SetCooldown(aura)
                auraFrame:Show()
            end

            function auraFrame:UnsetAura()
                self.cooldown:_SetCooldown()
                self:Hide()
            end

            function auraFrame:SetBorderColor(r, g, b, a)
                auraFrame.spark:SetColorTexture(r, g, b, a)
                auraFrame:SetBackdropColor(r, g, b, a)
            end

            function auraFrame.cooldown:SetDrawSwipe(enabled)
                self.swipe = enabled
            end

            function auraFrame.cooldown:SetDrawEdge(enabled)
                self.edge = enabled
                if enabled then
                    spark:Show()
                else
                    spark:Hide()
                end
            end
        end

        if category == "Buff" then
            function auraFrame:UpdateTooltip()
                if self.auraInstanceID > 0 and auraFrame:IsShown() then
                    GameTooltip:SetUnitBuffByAuraInstanceID(self:GetParent().displayedUnit, self.auraInstanceID, self.filter)
                end
            end
        else
            function auraFrame:UpdateTooltip()
                if self.auraInstanceID > 0 and auraFrame:IsShown() then
                    if (self.isBossBuff) then
                        GameTooltip:SetUnitBuffByAuraInstanceID(self:GetParent().displayedUnit, self.auraInstanceID, self.filter)
                    else
                        GameTooltip:SetUnitDebuffByAuraInstanceID(self:GetParent().displayedUnit, self.auraInstanceID, self.filter)
                    end
                end
            end
        end

        local ag = auraFrame:CreateAnimationGroup()
        auraFrame.ag = ag
        local t1 = ag:CreateAnimation("Translation")
        ag.t1 = t1
        t1:SetOffset(0, 5)
        t1:SetDuration(0.1)
        t1:SetOrder(1)
        t1:SetSmoothing("OUT")
        local t2 = ag:CreateAnimation("Translation")
        ag.t2 = t2
        t2:SetOffset(0, -5)
        t2:SetDuration(0.1)
        t2:SetOrder(2)
        t2:SetSmoothing("IN")
    end

    local dirty = false

    if frameOpt.cleanIcons then
        iconCrop = 0.1
        if category == "Debuff" and type == "blizzard" then
            auraFrame.border:SetTexture("Interface\\AddOns\\RaidFrameSettings_Excorp_Fork\\Textures\\DebuffOverlay_clean_icons.tga")
            auraFrame.border:SetTexCoord(0, 1, 0, 1)
        end
    else
        iconCrop = 0
        if category == "Debuff" and type == "blizzard" then
            auraFrame.border:SetTexture("Interface\\BUTTONS\\UI-Debuff-Overlays")
            auraFrame.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
        end
    end

    auraFrame.icon:SetTexCoord(iconCrop, 1 - iconCrop, iconCrop, 1 - iconCrop)
    if auraFrame.maskIcon then
        auraFrame.maskIcon:SetTexCoord(iconCrop, 1 - iconCrop, iconCrop, 1 - iconCrop)
    end

    -- Modify Aura Frame
    if frameOpt.framestrata ~= "Inherited" then
        auraFrame:SetFrameStrata(frameOpt.framestrata)
    end
    --Timer Settings
    local cooldown = auraFrame.cooldown
    cooldown.timerText = frameOpt.timerText
    cooldown.edge = frameOpt.edge
    if frameOpt.timerText then
        local cooldownText = CDT:CreateOrGetCooldownFontString(cooldown)
        cooldownText:ClearAllPoints()
        cooldownText:SetPoint(durationOpt.point, auraFrame, durationOpt.relativePoint, durationOpt.xOffsetFont, durationOpt.yOffsetFont)
        local res = cooldownText:SetFont(durationOpt.font, durationOpt.fontSize, durationOpt.outlinemode)
        if not res then
            fontObj:SetFontObject("NumberFontNormalSmall")
            cooldownText:SetFont(fontObj:GetFont())
            dirty = true
        end
        cooldownText:SetTextColor(durationOpt.fontColor.r, durationOpt.fontColor.g, durationOpt.fontColor.b, durationOpt.fontColor.a)
        cooldownText:SetShadowColor(durationOpt.shadowColor.r, durationOpt.shadowColor.g, durationOpt.shadowColor.b, durationOpt.shadowColor.a)
        cooldownText:SetShadowOffset(durationOpt.xOffsetShadow, durationOpt.yOffsetShadow)
        cooldownText.noCooldownCount = true
    end
    --Stack Settings
    local stackText = auraFrame.count
    stackText:ClearAllPoints()
    stackText:SetPoint(stackOpt.point, auraFrame, stackOpt.relativePoint, stackOpt.xOffsetFont, stackOpt.yOffsetFont)
    local res = stackText:SetFont(stackOpt.font, stackOpt.fontSize, stackOpt.outlinemode)
    if not res then
        fontObj:SetFontObject("NumberFontNormalSmall")
        stackText:SetFont(fontObj:GetFont())
        dirty = true
    end
    stackText:SetTextColor(stackOpt.fontColor.r, stackOpt.fontColor.g, stackOpt.fontColor.b, stackOpt.fontColor.a)
    stackText:SetShadowColor(stackOpt.shadowColor.r, stackOpt.shadowColor.g, stackOpt.shadowColor.b, stackOpt.shadowColor.a)
    stackText:SetShadowOffset(stackOpt.xOffsetShadow, stackOpt.yOffsetShadow)

    --Swipe Settings
    cooldown:SetDrawSwipe(frameOpt.swipe)
    cooldown:SetDrawEdge(frameOpt.edge)
    local spark = auraFrame.spark
    local mask = auraFrame.mask
    if type == "blizzard" then
        cooldown:SetReverse(frameOpt.inverse)
    elseif type == "baricon" then
        if not cooldown.swipe and cooldown.edge then
            auraFrame.maskIcon:Hide()
        else
            auraFrame.maskIcon:Show()
        end

        spark:ClearAllPoints()
        if frameOpt.cdOrientation == 1 then -- left
            cooldown:SetOrientation("HORIZONTAL")
            cooldown:SetReverseFill(true)

            spark:SetPoint("TOPRIGHT", cooldown:GetStatusBarTexture(), "TOPLEFT")
            spark:SetPoint("BOTTOMRIGHT", cooldown:GetStatusBarTexture(), "BOTTOMLEFT")
            spark:SetWidth(border_size)
            cooldown:SetPoint("TOPLEFT", auraFrame.icon, "TOPLEFT", cooldown.edge and border_size or 0, 0)
            cooldown:SetPoint("BOTTOMRIGHT", auraFrame.icon)

            mask:ClearAllPoints()
            mask:SetPoint("TOPLEFT", cooldown:GetStatusBarTexture())
            mask:SetPoint("BOTTOMRIGHT")
        elseif frameOpt.cdOrientation == 2 then -- right
            cooldown:SetOrientation("HORIZONTAL")
            cooldown:SetReverseFill(false)

            spark:SetPoint("TOPLEFT", cooldown:GetStatusBarTexture(), "TOPRIGHT")
            spark:SetPoint("BOTTOMLEFT", cooldown:GetStatusBarTexture(), "BOTTOMRIGHT")
            spark:SetWidth(border_size)
            cooldown:SetPoint("TOPLEFT", auraFrame.icon)
            cooldown:SetPoint("BOTTOMRIGHT", auraFrame.icon, "BOTTOMRIGHT", cooldown.edge and -border_size or 0, 0)

            mask:ClearAllPoints()
            mask:SetPoint("TOPLEFT")
            mask:SetPoint("BOTTOMRIGHT", cooldown:GetStatusBarTexture())
        elseif frameOpt.cdOrientation == 3 then -- up
            cooldown:SetOrientation("VERTICAL")
            cooldown:SetReverseFill(false)

            spark:SetPoint("BOTTOMLEFT", cooldown:GetStatusBarTexture(), "TOPLEFT")
            spark:SetPoint("BOTTOMRIGHT", cooldown:GetStatusBarTexture(), "TOPRIGHT")
            spark:SetHeight(border_size)
            cooldown:SetPoint("TOPLEFT", auraFrame.icon, "TOPLEFT", 0, cooldown.edge and -border_size or 0)
            cooldown:SetPoint("BOTTOMRIGHT", auraFrame.icon)

            mask:ClearAllPoints()
            mask:SetPoint("TOPLEFT", cooldown:GetStatusBarTexture())
            mask:SetPoint("BOTTOMRIGHT")
        elseif frameOpt.cdOrientation == 4 then -- down
            cooldown:SetOrientation("VERTICAL")
            cooldown:SetReverseFill(true)

            spark:SetPoint("TOPLEFT", cooldown:GetStatusBarTexture(), "BOTTOMLEFT")
            spark:SetPoint("TOPRIGHT", cooldown:GetStatusBarTexture(), "BOTTOMRIGHT")
            spark:SetHeight(border_size)
            cooldown:SetPoint("TOPLEFT", auraFrame.icon)
            cooldown:SetPoint("BOTTOMRIGHT", auraFrame.icon, "BOTTOMRIGHT", 0, cooldown.edge and border_size or 0)

            mask:ClearAllPoints()
            mask:SetPoint("TOPLEFT")
            mask:SetPoint("BOTTOMRIGHT", cooldown:GetStatusBarTexture())
        end
    end

    -- tooltip
    if type == "blizzard" then
        if frameOpt.tooltip then
            auraFrame:SetScript("OnEnter", function(self)
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
            auraFrame:SetScript("OnLeave", function(self)
                if GameTooltip:IsOwned(self) then
                    GameTooltip:Hide()
                end
                self:SetScript("OnUpdate", nil)
            end)
        else
            auraFrame:SetScript("OnUpdate", nil)
            auraFrame:SetScript("OnEnter", nil)
            auraFrame:SetScript("OnLeave", nil)
        end
    elseif type == "baricon" then
        auraFrame:EnableMouse(false)
        if frameOpt.tooltip then
            local onEnter = function(self)
                if GameTooltip:IsOwned(self) then
                    return
                end
                if frameOpt.tooltipPosition then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, 0)
                else
                    GameTooltip:SetOwner(self, "ANCHOR_PRESERVE")
                end
                self:UpdateTooltip()
            end
            local onLeave = function(self)
                if GameTooltip:IsOwned(self) then
                    GameTooltip:Hide()
                    local parent = self:GetParent()
                    if parent:IsMouseOver() then
                        if parent.UpdateTooltip then
                            if frameOpt.tooltipPosition then
                                GameTooltip:SetOwner(parent, "ANCHOR_RIGHT", 0, 0)
                            else
                                GameTooltip:SetOwner(parent, "ANCHOR_PRESERVE")
                            end
                            C_Timer.After(0, function() if parent.UpdateTooltip then parent:UpdateTooltip() end end)
                        end
                    end
                end
            end
            local tooltipChecker = function(self, elapsed)
                self.elapsed = self.elapsed + elapsed
                if self.elapsed > 0.1 then
                    self.elapsed = 0

                    -- Ignore the tooltip if it's already showing.
                    local owner = GameTooltip:GetOwner()
                    if owner and TooltipCheckQueueAll[owner] and owner:IsMouseOver() then
                        return
                    end

                    local frameName = GetMouseFocus() and GetMouseFocus():GetName()
                    local finish
                    if TooltipCheckQueueUnderFrame[frameName] then
                        for frame in pairs(TooltipCheckQueueUnderFrame[frameName]) do
                            if frame and frame:IsShown() and frame:IsMouseOver() then
                                onEnter(frame)
                                finish = true
                                break
                            end
                        end
                    end

                    if not finish then
                        for frame in pairs(TooltipCheckQueueUnknownPos) do
                            if frame and frame:IsShown() and frame:IsMouseOver() then
                                onEnter(frame)
                                finish = true

                                TooltipCheckQueueWhere[frame] = frame
                                TooltipCheckQueueUnknownPos[frame] = nil
                                TooltipCheckQueueUnderFrame[frameName] = TooltipCheckQueueUnderFrame[frameName] or {}
                                TooltipCheckQueueUnderFrame[frameName][frame] = true
                                break
                            end
                        end
                    end

                    if not finish then
                        local owner = GameTooltip:GetOwner()
                        if owner and TooltipCheckQueueAll[owner] then
                            onLeave(owner)
                        end
                    end
                end
                if next(TooltipCheckQueueAll) == nil then
                    TooltipCheckOnUpdateFrame:SetScript("OnUpdate", nil)
                    return
                end
            end
            auraFrame:SetScript("OnShow", function(self)
                if self.overwrapWithParent then
                    TooltipCheckQueueWhere[self] = fname
                end
                if TooltipCheckQueueWhere[self] then
                    local frameName = TooltipCheckQueueWhere[self]
                    TooltipCheckQueueUnderFrame[frameName] = TooltipCheckQueueUnderFrame[frameName] or {}
                    TooltipCheckQueueUnderFrame[frameName][self] = true
                else
                    TooltipCheckQueueUnknownPos[self] = true
                end

                TooltipCheckQueueAll[self] = true
                TooltipCheckOnUpdateFrame.elapsed = 0
                TooltipCheckOnUpdateFrame:SetScript("OnUpdate", tooltipChecker)
            end)
            auraFrame:SetScript("OnHide", function(self, ...)
                TooltipCheckQueueAll[self] = nil
                TooltipCheckQueueUnknownPos[self] = nil

                if TooltipCheckQueueWhere[self] then
                    local frameName = TooltipCheckQueueWhere[self]
                    if TooltipCheckQueueUnderFrame[frameName] then
                        TooltipCheckQueueUnderFrame[frameName][self] = nil
                    end
                end
                if next(TooltipCheckQueueAll) == nil then
                    TooltipCheckOnUpdateFrame:SetScript("OnUpdate", nil)
                end
                onLeave(self)
            end)
        else
            auraFrame:SetScript("OnShow", nil)
            auraFrame:SetScript("OnHide", nil)
        end
    end

    -- Set Animation Direction
    local ag = auraFrame.ag
    if frameOpt.aniOrientation == 1 then -- left
        ag.t1:SetOffset(-5, 0)
        ag.t2:SetOffset(5, 0)
    elseif frameOpt.aniOrientation == 2 then -- right
        ag.t1:SetOffset(5, 0)
        ag.t2:SetOffset(-5, 0)
    elseif frameOpt.aniOrientation == 3 then -- up
        ag.t1:SetOffset(0, 5)
        ag.t2:SetOffset(0, -5)
    elseif frameOpt.aniOrientation == 4 then -- down
        ag.t1:SetOffset(0, -5)
        ag.t2:SetOffset(0, 5)
    end

    return auraFrame, dirty
end
