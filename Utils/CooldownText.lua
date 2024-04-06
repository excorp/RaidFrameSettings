local _, addonTable = ...
local addon = addonTable.RaidFrameSettings
addonTable.cooldownText = {}
local CooldownText = addonTable.cooldownText

--WoW Api
local SetScript = SetScript
local SetText = SetText
local Round = Round
--Lua
local next = next
local string_format = string.format

--Cooldown Formatting
CooldownText.TimerTextLimit = {
    sec = 60,
    min = 3600,
    hour = 86400,
}

local function getTimerText(number)
    if number < CooldownText.TimerTextLimit.sec then
        return Round(number)
    elseif number < CooldownText.TimerTextLimit.min then
        return string_format("%dm", Round(number / 60))
    elseif number < CooldownText.TimerTextLimit.hour then
        return string_format("%dh", Round(number / 3600))
    else
        return string_format("%dd", Round(number / 86400))
    end
end

--Cooldown Display
local CooldownQueue = {}

local CooldownOnUpdateFrame = CreateFrame("Frame")
CooldownOnUpdateFrame.elapsed = 0
CooldownOnUpdateFrame.count = 0

local function updateFontStrings(self, elapsed)
    if next(CooldownQueue) == nil then
        CooldownOnUpdateFrame:SetScript("OnUpdate", nil)
        return
    end

    self.elapsed = self.elapsed + elapsed
    local limit = self.count * 0.01
    if limit < 0.1 then limit = 0.1 end
    if limit > 1 then limit = 1 end
    if self.elapsed > limit then
        self.count = 0
        for Cooldown in next, CooldownQueue do
            local fs = Cooldown._rfs_cd_text
            fs.elapsed = fs.elapsed + self.elapsed
            fs.duration = fs.duration - fs.elapsed
            fs.elapsed = 0
            if fs.duration <= 0 then
                fs:SetText("")
                CooldownQueue[Cooldown] = nil
            end
            fs:SetText(getTimerText(fs.duration))
            self.count = self.count + 1
        end
        self.elapsed = 0
    end

    if next(CooldownQueue) == nil then
        CooldownOnUpdateFrame:SetScript("OnUpdate", nil)
        return
    end
end

function CooldownText:StartCooldownText(Cooldown)
    if not Cooldown._rfs_cd_text then
        return false
    end
    local fs = Cooldown._rfs_cd_text
    fs:SetText(getTimerText(fs.duration - fs.elapsed))
    fs:Show()
    fs.elapsed = fs.elapsed - CooldownOnUpdateFrame.elapsed
    if not CooldownQueue[Cooldown] then
        CooldownQueue[Cooldown] = true
        CooldownOnUpdateFrame.count = CooldownOnUpdateFrame.count + 1
    end
    CooldownOnUpdateFrame:SetScript("OnUpdate", updateFontStrings)
end

function CooldownText:StopCooldownText(Cooldown)
    if not Cooldown._rfs_cd_text then
        return false
    end
    local fs = Cooldown._rfs_cd_text
    if CooldownQueue[Cooldown] then
        CooldownQueue[Cooldown] = nil
        CooldownOnUpdateFrame.count = CooldownOnUpdateFrame.count - 1
    end
    fs:SetText("")
    fs:Hide()
end

function CooldownText:DisableCooldownText(Cooldown)
    if Cooldown then
        self:StopCooldownText(Cooldown)
    else
        for Cooldown in pairs(CooldownQueue) do
            self:StopCooldownText(Cooldown)
        end
    end
end

--The position of _rfs_cd_text on the frame aswell as the font should be set in the module
function CooldownText:CreateOrGetCooldownFontString(Cooldown)
    if not Cooldown._rfs_cd_text then
        Cooldown._rfs_cd_text = Cooldown:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    end
    Cooldown._rfs_cd_text:Show()
    return Cooldown._rfs_cd_text
end
