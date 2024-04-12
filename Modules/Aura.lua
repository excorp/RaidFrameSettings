local _, addonTable = ...
local isVanilla, isWrath, isClassic, isRetail = addonTable.isVanilla, addonTable.isWrath, addonTable.isClassic, addonTable.isRetail
local addon = addonTable.RaidFrameSettings

-- local Aura = addon:NewModule("Aura")
addonTable.Aura = {}
local Aura = addonTable.Aura
Mixin(Aura, addonTable.hooks)

local fontObj = CreateFont("RaidFrameSettingsFont")

-- mouseover queue
local TooltipCheckFrame = CreateFrame("Frame")
TooltipCheckFrame.QueueAll = {}
TooltipCheckFrame.QueueWhere = {}
TooltipCheckFrame.QueueUnknownPos = {}
TooltipCheckFrame.QueueUnderFrame = {}
TooltipCheckFrame.elapsed = 0
TooltipCheckFrame.count = 0

local CooldownUpdateFrame = CreateFrame("Frame")

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


local queue = {}
queue.queue = {}
queue.pending = {}

--Cooldown Formatting
queue.TimerTextLimit = {
    sec = 60,
    min = 3600,
    hour = 86400,
}

queue.getTimerText = function(number)
    if number < queue.TimerTextLimit.sec then
        return Round(number)
    elseif number < queue.TimerTextLimit.min then
        return string.format("%dm", Round(number / 60))
    elseif number < queue.TimerTextLimit.hour then
        return string.format("%dh", Round(number / 3600))
    else
        return string.format("%dd", Round(number / 86400))
    end
end

queue.co = coroutine.create(function()
    while true do
        local now = GetTime()
        local count = 0
        for cooldown in next, queue.queue do
            local elapsed = now - cooldown.time
            if elapsed > 0 then
                cooldown.elapsed = cooldown.elapsed + elapsed
                cooldown.time = now
                queue.setText(cooldown)

                if cooldown.type == "baricon" then
                    cooldown:SetValue(cooldown.elapsed)
                    if cooldown.edge and cooldown.elapsed > cooldown.sparkTurnPoint then
                        cooldown.sparkTurnPoint = cooldown.duration
                        local auraFrame = cooldown:GetParent()
                        local spark = auraFrame.spark
                        spark:ClearAllPoints()
                        if cooldown.orientation == 1 then -- left
                            spark:SetPoint("TOPLEFT", auraFrame, "TOPLEFT")
                            spark:SetPoint("BOTTOMLEFT", auraFrame, "BOTTOMLEFT")
                        elseif cooldown.orientation == 2 then -- right
                            spark:SetPoint("TOPRIGHT", auraFrame, "TOPRIGHT")
                            spark:SetPoint("BOTTOMRIGHT", auraFrame, "BOTTOMRIGHT")
                        elseif cooldown.orientation == 3 then -- up
                            spark:SetPoint("TOPLEFT", auraFrame, "TOPLEFT")
                            spark:SetPoint("TOPRIGHT", auraFrame, "TOPRIGHT")
                        elseif cooldown.orientation == 4 then -- down
                            spark:SetPoint("BOTTOMLEFT", auraFrame, "BOTTOMLEFT")
                            spark:SetPoint("BOTTOMRIGHT", auraFrame, "BOTTOMRIGHT")
                        end
                    end
                end

                if cooldown.elapsed >= cooldown.duration then
                    queue.queue[cooldown] = nil
                end
            end
            count = count + 1
            coroutine.yield(false, count)
        end
        coroutine.yield(true, count)
    end
end)

queue.add = function(cooldown)
    queue.pending[cooldown] = true
end

queue.setText = function(cooldown)
    local time = cooldown.duration - cooldown.elapsed
    local fs = cooldown._rfs_cd_text
    if not fs then
        return
    end
    if time > 0 then
        fs:SetText(queue.getTimerText(time))
        fs:Show()
    else
        fs:SetText("")
        fs:Hide()
    end
end

queue.run = function()
    if queue.ticker and not queue.ticker:IsCancelled() then
        return
    end
    for k, v in pairs(queue.pending) do
        queue.queue[k] = v
        queue.pending[k] = nil
    end
    local function run()
        -- Start timing
        local start = debugprofilestop()
        -- Resume as often as possible (Limit to 5ms per frame)
        while (debugprofilestop() - start < 2) do
            -- Resume or remove
            if coroutine.status(queue.co) ~= "dead" then
                local ok, done, count = coroutine.resume(queue.co)
                if not ok then
                    geterrorhandler()(debugstack(queue.co))
                    queue.ticker:Cancel()
                    break
                end
                if done == true then
                    for k, v in pairs(queue.pending) do
                        queue.queue[k] = v
                        queue.pending[k] = nil
                        count = count + 1
                    end
                    if next(queue.queue) == nil then
                        queue.ticker:Cancel()
                        break
                    end
                end
            else
                queue.ticker:Cancel()
                break
            end
        end
    end
    queue.ticker = C_Timer.NewTicker(0.1, run)
end

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

function Aura:setTimerLimit(conf)
    queue.TimerTextLimit = conf
end

function Aura:reset()
    TooltipCheckFrame.QueueWhere = {}
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
            auraFrame = CreateFrame("Button", name, addonTable.isClassic and UIParent or nil, "Compact" .. category .. "Template") -- Specifying a "frame" as parent will automatically add it to frame.buffFrames, so set it to nil and set the parent later.
            auraFrame:SetParent(frame)
            auraFrame:Hide()
            local cooldown = auraFrame.cooldown
            cooldown:SetHideCountdownNumbers(true)
            cooldown.type = type

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
                    local now = GetTime()
                    CooldownFrame_Set(self, startTime, aura.duration, true)
                    if aura.expirationTime > now then
                        if self.timerText then
                            self.time = now
                            self.elapsed = self.time - startTime
                            self.duration = aura.duration
                            queue.setText(self)
                            queue.add(self)
                            queue.run()
                        end
                        self:SetDrawSwipe(self.swipe)
                        self:SetDrawEdge(self.edge)
                        if aura.refresh then
                            auraFrame.ag:Play()
                            aura.refresh = nil
                        end
                    else
                        auraFrame.icon:SetDesaturated(true)
                        auraFrame.icon:SetVertexColor(0.5, 0.5, 0.5, 1)
                    end
                else
                    CooldownFrame_Clear(self)
                    self.elapsed = 0
                    self.duration = 0
                    queue.setText(self)
                end
            end

            function auraFrame:SetAura(aura)
                self.icon:SetTexture(aura.icon)
                self.icon:SetDesaturated(false)
                self.icon:SetVertexColor(1, 1, 1, 1)
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
                auraFrame.spellId = aura.spellId
                self.cooldown:_SetCooldown(aura)
                auraFrame:Show()
                auraFrame.aura = aura
            end

            function auraFrame:UnsetAura()
                self.cooldown:_SetCooldown()
                auraFrame.aura = nil
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
            cooldown.type = type
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
                    local now = GetTime()
                    local startTime = aura.expirationTime - aura.duration
                    local elasped = now - startTime

                    self.time = now
                    self.elapsed = elasped
                    self.duration = aura.duration

                    if aura.expirationTime > now then
                        if self.timerText then
                            queue.setText(self)
                        end

                        if self.swipe or self.edge then
                            self:SetMinMaxValues(0, aura.duration)
                            self:SetValue(elasped)
                            self:Show()

                            local frameSize = 0
                            if self.edge then
                                local spark = self:GetParent().spark
                                spark:ClearAllPoints()
                                if self.orientation == 1 then -- left
                                    spark:SetPoint("TOPRIGHT", cooldown:GetStatusBarTexture(), "TOPLEFT")
                                    spark:SetPoint("BOTTOMRIGHT", cooldown:GetStatusBarTexture(), "BOTTOMLEFT")
                                    frameSize = auraFrame:GetWidth()
                                elseif self.orientation == 2 then -- right
                                    spark:SetPoint("TOPLEFT", cooldown:GetStatusBarTexture(), "TOPRIGHT")
                                    spark:SetPoint("BOTTOMLEFT", cooldown:GetStatusBarTexture(), "BOTTOMRIGHT")
                                    frameSize = auraFrame:GetWidth()
                                elseif self.orientation == 3 then -- up
                                    spark:SetPoint("BOTTOMLEFT", cooldown:GetStatusBarTexture(), "TOPLEFT")
                                    spark:SetPoint("BOTTOMRIGHT", cooldown:GetStatusBarTexture(), "TOPRIGHT")
                                    frameSize = auraFrame:GetHeight()
                                elseif self.orientation == 4 then -- down
                                    spark:SetPoint("TOPLEFT", cooldown:GetStatusBarTexture(), "BOTTOMLEFT")
                                    spark:SetPoint("TOPRIGHT", cooldown:GetStatusBarTexture(), "BOTTOMRIGHT")
                                    frameSize = auraFrame:GetHeight()
                                end
                                spark:Show()
                                self.sparkTurnPoint = (frameSize - border_size) / (frameSize / aura.duration)
                            end
                        end

                        queue.add(self)
                        queue.run()
                    else
                        self:SetMinMaxValues(0, 1)
                        self:SetValue(1)
                        self:Show()
                        -- self:Hide()
                        self:GetParent().spark:Hide()
                    end

                    if aura.refresh then
                        auraFrame.ag:Play()
                        aura.refresh = nil
                    end
                else
                    self:Hide()
                    self:GetParent().spark:Hide()
                    self.elapsed = 0
                    self.duration = 0
                    queue.setText(self)
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
                auraFrame.spellId = aura.spellId
                self.cooldown:_SetCooldown(aura)
                auraFrame:Show()
                auraFrame.aura = aura
            end

            function auraFrame:UnsetAura()
                -- self.cooldown:_SetCooldown()
                -- auraFrame.aura = nil
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
                if auraFrame:IsShown() then
                    if isClassic then
                        if UnitBuff(self:GetParent().displayedUnit, self:GetID(), self.filter) then
                            GameTooltip:SetUnitBuff(self:GetParent().displayedUnit, self:GetID(), self.filter)
                        elseif self.spellId then
                            GameTooltip:SetSpellByID(self.spellId)
                        end
                    else
                        if auraFrame.auraInstanceID > 0 then
                            GameTooltip:SetUnitBuffByAuraInstanceID(self:GetParent().displayedUnit, self.auraInstanceID, self.filter)
                        else
                            GameTooltip:SetSpellByID(-1 * auraFrame.auraInstanceID)
                        end
                    end
                end
            end
        else
            function auraFrame:UpdateTooltip()
                if auraFrame:IsShown() then
                    if isClassic then
                        if self.isBossBuff then
                            if UnitBuff(self:GetParent().displayedUnit, self:GetID(), self.filter) then
                                GameTooltip:SetUnitBuff(self:GetParent().displayedUnit, self:GetID(), self.filter)
                            elseif self.spellId then
                                GameTooltip:SetSpellByID(self.spellId)
                            end
                        else
                            if UnitDebuff(self:GetParent().displayedUnit, self:GetID(), self.filter) then
                                GameTooltip:SetUnitDebuff(self:GetParent().displayedUnit, self:GetID(), self.filter)
                            elseif self.spellId then
                                GameTooltip:SetSpellByID(self.spellId)
                            end
                        end
                    else
                        if self.auraInstanceID > 0 then
                            if (self.isBossBuff) then
                                GameTooltip:SetUnitBuffByAuraInstanceID(self:GetParent().displayedUnit, self.auraInstanceID, self.filter)
                            else
                                GameTooltip:SetUnitDebuffByAuraInstanceID(self:GetParent().displayedUnit, self.auraInstanceID, self.filter)
                            end
                        else
                            GameTooltip:SetSpellByID(-1 * auraFrame.auraInstanceID)
                        end
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
        local cooldownText = cooldown._rfs_cd_text or cooldown:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        cooldown._rfs_cd_text = cooldownText
        cooldownText:Show()
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
        cooldown.swipe = frameOpt.swipe
        cooldown.edge = frameOpt.edge
    elseif type == "baricon" then
        if not cooldown.swipe and cooldown.edge then
            auraFrame.maskIcon:Hide()
        else
            auraFrame.maskIcon:Show()
        end

        spark:ClearAllPoints()
        cooldown.orientation = frameOpt.cdOrientation
        if frameOpt.cdOrientation == 1 then -- left
            cooldown:SetOrientation("HORIZONTAL")
            cooldown:SetReverseFill(true)
            spark:SetWidth(border_size)
            cooldown:SetPoint("TOPLEFT", auraFrame.icon, "TOPLEFT")
            cooldown:SetPoint("BOTTOMRIGHT", auraFrame.icon)
            mask:ClearAllPoints()
            mask:SetPoint("TOPLEFT", cooldown:GetStatusBarTexture())
            mask:SetPoint("BOTTOMRIGHT")
        elseif frameOpt.cdOrientation == 2 then -- right
            cooldown:SetOrientation("HORIZONTAL")
            cooldown:SetReverseFill(false)
            spark:SetWidth(border_size)
            cooldown:SetPoint("TOPLEFT", auraFrame.icon)
            cooldown:SetPoint("BOTTOMRIGHT", auraFrame.icon, "BOTTOMRIGHT")
            mask:ClearAllPoints()
            mask:SetPoint("TOPLEFT")
            mask:SetPoint("BOTTOMRIGHT", cooldown:GetStatusBarTexture())
        elseif frameOpt.cdOrientation == 3 then -- up
            cooldown:SetOrientation("VERTICAL")
            cooldown:SetReverseFill(false)
            spark:SetHeight(border_size)
            cooldown:SetPoint("TOPLEFT", auraFrame.icon, "TOPLEFT")
            cooldown:SetPoint("BOTTOMRIGHT", auraFrame.icon)
            mask:ClearAllPoints()
            mask:SetPoint("TOPLEFT", cooldown:GetStatusBarTexture())
            mask:SetPoint("BOTTOMRIGHT")
        elseif frameOpt.cdOrientation == 4 then -- down
            cooldown:SetOrientation("VERTICAL")
            cooldown:SetReverseFill(true)
            spark:SetHeight(border_size)
            cooldown:SetPoint("TOPLEFT", auraFrame.icon)
            cooldown:SetPoint("BOTTOMRIGHT", auraFrame.icon, "BOTTOMRIGHT")
            mask:ClearAllPoints()
            mask:SetPoint("TOPLEFT")
            mask:SetPoint("BOTTOMRIGHT", cooldown:GetStatusBarTexture())
        end
    end

    -- tooltip
    auraFrame.tooltip         = frameOpt.tooltip
    auraFrame.tooltipPosition = frameOpt.tooltipPosition
    if type == "blizzard" then
        if auraFrame.tooltip then
            auraFrame:SetScript("OnEnter", function(self)
                if self.tooltipPosition then
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
        if auraFrame.tooltip then
            local onEnter = function(self)
                if GameTooltip:IsOwned(self) then
                    return
                end
                if self.tooltipPosition then
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
                        if isClassic then
                            if parent.tooltip then
                                GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
                                GameTooltip:SetText(self.tooltip, nil, nil, nil, nil, true)
                                GameTooltip:Show()
                            else
                                self:GetParent():GetScript("OnEnter")(self:GetParent(), false)
                            end
                        else
                            if parent.UpdateTooltip then
                                GameTooltip:SetOwner(parent, "ANCHOR_PRESERVE")
                                C_Timer.After(0, function() if parent.UpdateTooltip then parent:UpdateTooltip() end end)
                            end
                        end
                    end
                end
            end
            local tooltipChecker = function(self, elapsed)
                if next(self.QueueAll) == nil then
                    self:SetScript("OnUpdate", nil)
                    return
                end

                self.elapsed = self.elapsed + elapsed
                if self.elapsed > 0.1 then
                    self.elapsed = 0

                    -- Ignore the tooltip if it's already showing.
                    local owner = GameTooltip:GetOwner()
                    if owner and self.QueueAll[owner] and owner:IsMouseOver() then
                        return
                    end

                    local focusFrame = GetMouseFocus()
                    local frameName = focusFrame and focusFrame.GetName and focusFrame:GetName()
                    if not frameName then
                        return
                    end
                    local finish
                    if self.QueueUnderFrame[frameName] then
                        for frame in pairs(self.QueueUnderFrame[frameName]) do
                            if frame and frame:IsShown() and frame:IsMouseOver() then
                                onEnter(frame)
                                finish = true
                                break
                            end
                        end
                    end

                    if not finish then
                        for frame in pairs(self.QueueUnknownPos) do
                            if frame and frame:IsShown() and frame:IsMouseOver() then
                                onEnter(frame)
                                finish = true

                                self.QueueWhere[frame] = frame
                                self.QueueUnknownPos[frame] = nil
                                self.QueueUnderFrame[frameName] = self.QueueUnderFrame[frameName] or {}
                                self.QueueUnderFrame[frameName][frame] = true
                                break
                            end
                        end
                    end

                    if not finish then
                        local owner = GameTooltip:GetOwner()
                        if owner and self.QueueAll[owner] then
                            onLeave(owner)
                        end
                    end
                end
            end
            auraFrame:SetScript("OnShow", function(self)
                if self.overwrapWithParent then
                    TooltipCheckFrame.QueueWhere[self] = fname
                end
                if TooltipCheckFrame.QueueWhere[self] then
                    local frameName = TooltipCheckFrame.QueueWhere[self]
                    TooltipCheckFrame.QueueUnderFrame[frameName] = TooltipCheckFrame.QueueUnderFrame[frameName] or {}
                    TooltipCheckFrame.QueueUnderFrame[frameName][self] = true
                else
                    TooltipCheckFrame.QueueUnknownPos[self] = true
                end

                TooltipCheckFrame.QueueAll[self] = true
                TooltipCheckFrame:SetScript("OnUpdate", tooltipChecker)
            end)
            auraFrame:SetScript("OnHide", function(self, ...)
                TooltipCheckFrame.QueueAll[self] = nil
                TooltipCheckFrame.QueueUnknownPos[self] = nil

                if TooltipCheckFrame.QueueWhere[self] then
                    local frameName = TooltipCheckFrame.QueueWhere[self]
                    if TooltipCheckFrame.QueueUnderFrame[frameName] then
                        TooltipCheckFrame.QueueUnderFrame[frameName][self] = nil
                    end
                end
                onLeave(self)

                if self.cooldown then
                    self.cooldown:_SetCooldown()
                end
                auraFrame.aura = nil
            end)
        else
            auraFrame:SetScript("OnShow", nil)
            auraFrame:SetScript("OnHide", function()
                if self.cooldown then
                    self.cooldown:_SetCooldown()
                end
                auraFrame.aura = nil
            end)
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

local frame_registry = {}

local function processAura(frame, aura, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)
    local type = AuraUtil.ProcessAura(aura, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)

    -- Can't dispell debuffs on pvp frames
    if type == AuraUtil.AuraUpdateChangedType.Dispel and CompactUnitFrame_IsPvpFrame(frame) then
        type = AuraUtil.AuraUpdateChangedType.Debuff
    end

    return type
end


local function parseAllAuras(srcframe, frame, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)
    local batchCount = nil
    local usePackedAura = true
    local function HandleAura(aura)
        local all
        if aura.isHelpful and frame.buffsAll then
            all = frame.buffsAll
        elseif aura.isHarmful and frame.debuffsAll then
            all = frame.debuffsAll
        end
        if all then
            all.aura[aura.auraInstanceID] = aura
            all.all[aura.spellId] = all.all[aura.spellId] or {}
            all.all[aura.spellId][aura.auraInstanceID] = aura
            if aura.isFromPlayerOrPlayerPet then
                all.own[aura.spellId] = aura
            else
                -- all.other[aura.spellId] = all.other[aura.spellId] or {}
                -- all.other[aura.spellId][aura.auraInstanceID] = aura
            end
        end
        local type = processAura(srcframe, aura, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)
        if frame.buffs and type == AuraUtil.AuraUpdateChangedType.Buff then
            frame.buffs[aura.auraInstanceID] = aura
        elseif frame.debuffs and (type == AuraUtil.AuraUpdateChangedType.Debuff or type == AuraUtil.AuraUpdateChangedType.Dispel) then
            frame.debuffs[aura.auraInstanceID] = aura
        end
    end
    if frame.buffs or frame.buffsAll then
        if frame.buffs then
            frame.buffs:Clear()
        elseif frame.buffsAll then
            frame.buffsAll.aura = {}
            frame.buffsAll.all = {}
            frame.buffsAll.own = {}
            frame.buffsAll.other = {}
        end
        AuraUtil.ForEachAura(srcframe.displayedUnit, AuraUtil.CreateFilterString(AuraUtil.AuraFilters.Helpful), batchCount, HandleAura, usePackedAura)
    end
    if frame.debuffs or frame.debuffsAll then
        if frame.debuffs then
            frame.debuffs:Clear()
        elseif frame.debuffsAll then
            frame.debuffsAll.aura = {}
            frame.debuffsAll.all = {}
            frame.debuffsAll.own = {}
            frame.debuffsAll.other = {}
        end
        AuraUtil.ForEachAura(srcframe.displayedUnit, AuraUtil.CreateFilterString(AuraUtil.AuraFilters.Harmful), batchCount, HandleAura, usePackedAura)
        AuraUtil.ForEachAura(srcframe.displayedUnit, AuraUtil.CreateFilterString(AuraUtil.AuraFilters.Harmful, AuraUtil.AuraFilters.Raid), batchCount, HandleAura, usePackedAura)
    end
end

local function GetOptionDisplayOnlyDispellableDebuffs(frame, optionTable)
    if isClassic then
        return frame.optionTable.displayOnlyDispellableDebuffs
    end
    return CompactUnitFrame_GetOptionDisplayOnlyDispellableDebuffs(frame, frame.optionTable)
end

local function updateAuras(srcframe, unitAuraUpdateInfo)
    local frame = frame_registry[srcframe]

    if not srcframe.displayedUnit or not frame.buffs and not frame.debuffs and not frame.buffsAll and not frame.debuffsAll then
        return
    end

    local buffsChanged = false
    local debuffsChanged = false
    local buffsAllChanged = false
    local debuffsAllChanged = false

    local displayOnlyDispellableDebuffs = GetOptionDisplayOnlyDispellableDebuffs(srcframe, srcframe.optionTable)
    local ignoreBuffs = not frame.buffs
    local ignoreDebuffs = not frame.debuffs
    local ignoreDispelDebuffs = true

    if unitAuraUpdateInfo == nil or unitAuraUpdateInfo.isFullUpdate then
        parseAllAuras(srcframe, frame, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)
        buffsChanged = true
        debuffsChanged = true
        buffsAllChanged = true
        debuffsAllChanged = true
    else
        if unitAuraUpdateInfo.addedAuras ~= nil then
            for _, aura in ipairs(unitAuraUpdateInfo.addedAuras) do
                local all
                if aura.isHelpful and frame.buffsAll then
                    all = frame.buffsAll
                    buffsAllChanged = true
                elseif aura.isHarmful and frame.debuffsAll then
                    all = frame.debuffsAll
                    debuffsAllChanged = true
                end
                if all then
                    all.aura[aura.auraInstanceID] = aura
                    all.all[aura.spellId] = all.all[aura.spellId] or {}
                    all.all[aura.spellId][aura.auraInstanceID] = aura
                    if aura.isFromPlayerOrPlayerPet then
                        all.own[aura.spellId] = aura
                    else
                        -- all.other[aura.spellId] = all.other[aura.spellId] or {}
                        -- all.other[aura.spellId][aura.auraInstanceID] = aura
                    end
                end
                local type = processAura(srcframe, aura, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)
                if type == AuraUtil.AuraUpdateChangedType.Buff then
                    frame.buffs[aura.auraInstanceID] = aura
                    buffsChanged = true
                elseif type == AuraUtil.AuraUpdateChangedType.Debuff or type == AuraUtil.AuraUpdateChangedType.Dispel then
                    frame.debuffs[aura.auraInstanceID] = aura
                    debuffsChanged = true
                end
            end
        end

        if unitAuraUpdateInfo.updatedAuraInstanceIDs ~= nil then
            for _, auraInstanceID in ipairs(unitAuraUpdateInfo.updatedAuraInstanceIDs) do
                local newAura = C_UnitAuras.GetAuraDataByAuraInstanceID(srcframe.displayedUnit, auraInstanceID)
                if newAura then
                    local all
                    if newAura.isHelpful and frame.buffsAll then
                        all = frame.buffsAll
                        buffsAllChanged = true
                    elseif newAura.isHarmful and frame.debuffsAll then
                        all = frame.debuffsAll
                        debuffsAllChanged = true
                    end
                    if all then
                        all.aura[newAura.auraInstanceID] = newAura
                        all.all[newAura.spellId] = all.all[newAura.spellId] or {}
                        all.all[newAura.spellId][newAura.auraInstanceID] = newAura
                        if newAura.isFromPlayerOrPlayerPet then
                            all.own[newAura.spellId] = newAura
                        else
                            -- all.other[newAura.spellId] = all.other[newAura.spellId] or {}
                            -- all.other[newAura.spellId][newAura.auraInstanceID] = newAura
                        end
                    end
                    if frame.buffs and frame.buffs[auraInstanceID] ~= nil then
                        if newAura ~= nil then
                            newAura.isBuff = true
                        end
                        frame.buffs[auraInstanceID] = newAura
                        buffsChanged = true
                    elseif frame.debuffs and frame.debuffs[auraInstanceID] ~= nil then
                        local oldDebuffType = frame.debuffs[auraInstanceID].debuffType
                        if newAura ~= nil then
                            newAura.debuffType = oldDebuffType
                        end
                        frame.debuffs[auraInstanceID] = newAura
                        debuffsChanged = true
                    end
                end
            end
        end

        if unitAuraUpdateInfo.removedAuraInstanceIDs ~= nil then
            for _, auraInstanceID in ipairs(unitAuraUpdateInfo.removedAuraInstanceIDs) do
                if frame.buffsAll or frame.debuffsAll then
                    local all = frame.buffsAll and frame.buffsAll.aura[auraInstanceID] and frame.buffsAll or frame.debuffsAll and frame.debuffsAll.aura[auraInstanceID] and frame.debuffsAll
                    if all then
                        if all == frame.buffsAll then
                            buffsAllChanged = true
                        else
                            debuffsAllChanged = true
                        end
                        local aura = all.aura[auraInstanceID]
                        all.aura[auraInstanceID] = nil
                        all.all[aura.spellId] = all.all[aura.spellId] or {}
                        all.all[aura.spellId][aura.auraInstanceID] = nil
                        if next(all.all[aura.spellId]) == nil then
                            all.all[aura.spellId] = nil
                        end
                        if aura.isFromPlayerOrPlayerPet then
                            all.own[aura.spellId] = nil
                        else
                            -- all.other[aura.spellId] = all.other[aura.spellId] or {}
                            -- all.other[aura.spellId][aura.auraInstanceID] = nil
                            -- if next(all.other[aura.spellId]) == nil then
                            --     all.other[aura.spellId] = nil
                            -- end
                        end
                    end
                end
                if frame.buffs and frame.buffs[auraInstanceID] ~= nil then
                    frame.buffs[auraInstanceID] = nil
                    buffsChanged = true
                end
                if frame.debuffs and frame.debuffs[auraInstanceID] ~= nil then
                    frame.debuffs[auraInstanceID] = nil
                    debuffsChanged = true
                end
            end
        end
    end

    if buffsAllChanged and frame.callback.buffsAll then
        if frame.callback.buffsAll(srcframe) then
            buffsChanged = false
        end
    end

    if debuffsAllChanged and frame.callback.debuffsAll then
        frame.callback.debuffsAll(srcframe)
    end

    if buffsChanged and frame.callback.buffs then
        frame.callback.buffs(srcframe)
    end
    if debuffsChanged and frame.callback.debuffs then
        frame.callback.debuffs(srcframe)
    end
end

function Aura:SetAuraVar(srcframe, type, var, callback)
    frame_registry[srcframe] = frame_registry[srcframe] or {}
    local frame = frame_registry[srcframe]
    frame[type] = var
    frame.callback = frame.callback or {}
    frame.callback[type] = callback
    if not frame.buffs and not frame.debuffs and not frame.buffsAll and not frame.debuffsAll then
        return
    end
    self:HookScript(srcframe, "OnEvent", function(srcframe, event, unit, unitAuraUpdateInfo)
        if event ~= "UNIT_AURA" then
            return
        end
        updateAuras(srcframe, unitAuraUpdateInfo)
    end)
    updateAuras(srcframe)
end
