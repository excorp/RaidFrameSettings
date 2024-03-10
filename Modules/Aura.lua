local _, addonTable = ...
local isVanilla, isWrath, isClassic, isRetail = addonTable.isVanilla, addonTable.isWrath, addonTable.isClassic, addonTable.isRetail
local addon = addonTable.RaidFrameSettings
addonTable.Aura = {}
local Aura = addonTable.Aura
local CDT = addonTable.cooldownText

local fontObj = CreateFont("RaidFrameSettingsFont")

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
                if (aura.applications > 1) then
                    local countText = aura.applications
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
                auraFrame:SetCoord(width, height)
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
                    if self.swipe then
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
                    self:SetDrawEdge(self.edge)

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

                if (aura.applications > 1) then
                    local countText = aura.applications
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
                if enabled and self.swipe then
                    auraFrame.spark:Show()
                else
                    auraFrame.spark:Hide()
                end
            end
        end

        if category == "Buff" then
            function auraFrame:UpdateTooltip()
                GameTooltip:SetUnitBuffByAuraInstanceID(self:GetParent().displayedUnit, self.auraInstanceID, self.filter)
            end
        else
            function auraFrame:UpdateTooltip()
                if (self.isBossBuff) then
                    GameTooltip:SetUnitBuffByAuraInstanceID(self:GetParent().displayedUnit, self.auraInstanceID, self.filter)
                else
                    GameTooltip:SetUnitDebuffByAuraInstanceID(self:GetParent().displayedUnit, self.auraInstanceID, self.filter)
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
    local spark = auraFrame.spark
    local mask = auraFrame.mask
    if type == "blizzard" then
        cooldown:SetReverse(frameOpt.inverse)
    elseif type == "baricon" then
        if frameOpt.cdOrientation == 1 then -- left
            cooldown:SetOrientation("HORIZONTAL")
            cooldown:SetReverseFill(true)

            spark:ClearAllPoints()
            spark:SetPoint("TOPRIGHT", cooldown:GetStatusBarTexture(), "TOPLEFT", border_size / 2, 0)
            spark:SetPoint("BOTTOMRIGHT", cooldown:GetStatusBarTexture(), "BOTTOMLEFT", border_size / 2, 0)
            spark:SetWidth(border_size)

            mask:ClearAllPoints()
            mask:SetPoint("TOPLEFT", cooldown:GetStatusBarTexture())
            mask:SetPoint("BOTTOMRIGHT")
        elseif frameOpt.cdOrientation == 2 then -- right
            cooldown:SetOrientation("HORIZONTAL")
            cooldown:SetReverseFill(false)

            spark:ClearAllPoints()
            spark:SetPoint("TOPLEFT", cooldown:GetStatusBarTexture(), "TOPRIGHT", -border_size / 2, 0)
            spark:SetPoint("BOTTOMLEFT", cooldown:GetStatusBarTexture(), "BOTTOMRIGHT", -border_size / 2, 0)
            spark:SetWidth(border_size)

            mask:ClearAllPoints()
            mask:SetPoint("TOPLEFT")
            mask:SetPoint("BOTTOMRIGHT", cooldown:GetStatusBarTexture())
        elseif frameOpt.cdOrientation == 3 then -- up
            cooldown:SetOrientation("VERTICAL")
            cooldown:SetReverseFill(false)

            spark:ClearAllPoints()
            spark:SetPoint("BOTTOMLEFT", cooldown:GetStatusBarTexture(), "TOPLEFT", 0, -border_size / 2)
            spark:SetPoint("BOTTOMRIGHT", cooldown:GetStatusBarTexture(), "TOPRIGHT", 0, -border_size / 2)
            spark:SetHeight(border_size)

            mask:ClearAllPoints()
            mask:SetPoint("TOPLEFT", cooldown:GetStatusBarTexture())
            mask:SetPoint("BOTTOMRIGHT")
        elseif frameOpt.cdOrientation == 4 then -- down
            cooldown:SetOrientation("VERTICAL")
            cooldown:SetReverseFill(true)

            spark:ClearAllPoints()
            spark:SetPoint("TOPLEFT", cooldown:GetStatusBarTexture(), "BOTTOMLEFT", 0, border_size / 2)
            spark:SetPoint("TOPRIGHT", cooldown:GetStatusBarTexture(), "BOTTOMRIGHT", 0, border_size / 2)
            spark:SetHeight(border_size)

            mask:ClearAllPoints()
            mask:SetPoint("TOPLEFT")
            mask:SetPoint("BOTTOMRIGHT", cooldown:GetStatusBarTexture())
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
