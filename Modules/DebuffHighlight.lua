local addonName, addonTable = ...
local addon = addonTable.RaidFrameSettings
local DebuffHighlight = addon:NewModule("DebuffHighlight")
Mixin(DebuffHighlight, addonTable.hooks)
local Glow = addonTable.Glow
local Aura = addonTable.Aura
local LD = LibStub("LibDispel-1.0")

--WoW Api
local UnitIsPlayer = UnitIsPlayer
local UnitInPartyIsAI = UnitInPartyIsAI
local C_ClassTalents = C_ClassTalents
local C_Traits = C_Traits
local IsSpellKnownOrOverridesKnown = IsSpellKnownOrOverridesKnown
local GetSpellCooldown = GetSpellCooldown
local GetTime = GetTime
local C_Timer = C_Timer
local GetLocale = GetLocale

-- Lua
local CopyTable = CopyTable
local pairs = pairs
local tinsert = tinsert
local math = math
local unpack = unpack


local frame_registry = {}
local roster_changed = true
local locale = GetLocale()
local lastPlayed = {
    Magic   = 0,
    Curse   = 0,
    Disease = 0,
    Poison  = 0,
    Bleed   = 0,
}
local channel = "Master" -- Music, SFX, Ambience, Dialog
local ignoreSpells = {
    [240443] = true,     -- Burst
}

local dispelConf = {
    Magic = {
        { spellId = 88423,  traitsEntryId = nil },
        { spellId = 360823, traitsEntryId = nil },
        { spellId = 115450, traitsEntryId = nil },
        { spellId = 4987,   traitsEntryId = nil },
        { spellId = 527,    traitsEntryId = nil },
        { spellId = 32375,  traitsEntryId = nil },
        { spellId = 77130,  traitsEntryId = nil },
        { spellId = 119905, traitsEntryId = nil },
        { spellId = 32375,  traitsEntryId = nil },
    },
    Curse = {
        { spellId = 2782,   traitsEntryId = nil },
        { spellId = 374251, traitsEntryId = nil },
        { spellId = 475,    traitsEntryId = nil },
        { spellId = 51886,  traitsEntryId = nil },
        { spellId = 88423,  traitsEntryId = 103281 },
        { spellId = 77130,  traitsEntryId = 101964 },
    },
    Disease = {
        { spellId = 374251, traitsEntryId = nil },
        { spellId = 218164, traitsEntryId = nil },
        { spellId = 213644, traitsEntryId = nil },
        { spellId = 213634, traitsEntryId = nil },
        { spellId = 115450, traitsEntryId = 102627 },
        { spellId = 4987,   traitsEntryId = 102477 },
        { spellId = 527,    traitsEntryId = 103855 },
        { spellId = 527,    traitsEntryId = 103855 },
    },
    Poison = {
        { spellId = 2782,   traitsEntryId = nil },
        { spellId = 374251, traitsEntryId = nil },
        { spellId = 218164, traitsEntryId = nil },
        { spellId = 213644, traitsEntryId = nil },
        { spellId = 88423,  traitsEntryId = 103281 },
        { spellId = 115450, traitsEntryId = 102627 },
        { spellId = 4987,   traitsEntryId = 102477 },
    },
    Bleed = {
        { spellId = 374251, traitsEntryId = nil },
        -- 신기,징기 보축?
    }
}

local debuffHighlightConf = {
    Magic = {
        type      = "Pixel",
        use_color = true,
        color     = {
            r = 0.19607843137255,
            g = 0.58823529411765,
            b = 1,
            a = 1,
        },
        lines     = 8,
        frequency = nil,
        length    = nil,
        thickness = 3,
        XOffset   = nil,
        YOffset   = nil,
        border    = true,
    },
    Curse = {
        type      = "Pixel",
        use_color = true,
        color     = {
            r = 0.58823529411765,
            g = 0,
            b = 1,
            a = 1,
        },
        lines     = 8,
        frequency = nil,
        length    = nil,
        thickness = 3,
        XOffset   = nil,
        YOffset   = nil,
        border    = true,
    },
    Disease = {
        type      = "Pixel",
        use_color = true,
        color     = {
            r = 0.58823529411765,
            g = 0.3921568627451,
            b = 0,
            a = 1,
        },
        lines     = 8,
        frequency = nil,
        length    = nil,
        thickness = 3,
        XOffset   = nil,
        YOffset   = nil,
        border    = true,
    },
    Poison = {
        type      = "Pixel",
        use_color = true,
        color     = {
            r = 0,
            g = 0.58823529411765,
            b = 0,
            a = 1,
        },
        lines     = 8,
        frequency = nil,
        length    = nil,
        thickness = 3,
        XOffset   = nil,
        YOffset   = nil,
        border    = true,
    },
    Bleed = {
        type      = "Pixel",
        use_color = true,
        color     = {
            r = 1,
            g = 0,
            b = 0,
            a = 1,
        },
        lines     = 8,
        frequency = nil,
        length    = nil,
        thickness = 3,
        XOffset   = nil,
        YOffset   = nil,
        border    = true,
    },
}


local canDispel = {}
local talentActiveEntry = {}

local function initRegistry(frame)
    frame_registry[frame] = {
        allaura = {
            aura  = {},
            all   = {},
            own   = {},
            other = {},
        },
        glow = {},
    }
end

local function getTalent()
    local configID = C_ClassTalents.GetActiveConfigID()
    if configID then
        talentActiveEntry = {}
        local config = C_Traits.GetConfigInfo(configID)
        for _, treeID in pairs(config.treeIDs) do
            for _, nodeID in pairs(C_Traits.GetTreeNodes(treeID)) do
                local node = C_Traits.GetNodeInfo(configID, nodeID)
                if node.activeEntry and node.activeEntry.rank > 0 then
                    talentActiveEntry[node.activeEntry.entryID] = true
                end
            end
        end
    end

    canDispel = {}
    for type, confs in pairs(dispelConf) do
        for _, conf in pairs(confs) do
            if conf.traitsEntryId then
                if talentActiveEntry[conf.traitsEntryId] and IsSpellKnownOrOverridesKnown(conf.spellId) then
                    canDispel[type] = canDispel[type] or {}
                    tinsert(canDispel[type], conf.spellId)
                end
            else
                if IsSpellKnownOrOverridesKnown(conf.spellId) then
                    canDispel[type] = canDispel[type] or {}
                    tinsert(canDispel[type], conf.spellId)
                end
            end
        end
    end
end

local onUpdateHighlihgt

local trackSpellFrame = {}
local function trackCooldown(spellId, frame)
    trackSpellFrame[spellId] = trackSpellFrame[spellId] or {}
    trackSpellFrame[spellId][frame] = true
end

local ticker
function DebuffHighlight:OnEnable()
    local Bleeds = LD:GetBleedList()

    local debuffOpt = CopyTable(addon.db.profile.DebuffHighlight)

    local dbObj = addon.db.profile.MinorModules.DebuffColors
    debuffHighlightConf.Curse.color = dbObj.Curse
    debuffHighlightConf.Disease.color = dbObj.Disease
    debuffHighlightConf.Magic.color = dbObj.Magic
    debuffHighlightConf.Poison.color = dbObj.Poison
    debuffHighlightConf.Bleed.color = dbObj.Bleed

    onUpdateHighlihgt = function(frame)
        local glow = {}
        local now = GetTime()
        for auraInstanceID, aura in pairs(frame_registry[frame].allaura.aura) do
            if not ignoreSpells[aura.spellId] then
                local dispelName = Bleeds[aura.spellId] and "Bleed" or aura.dispelName
                if dispelName then
                    local show
                    local leftime = {}
                    local conf = debuffOpt.Config[dispelName]
                    if conf == 1 then
                        show = true
                    elseif conf == 2 then
                        if canDispel[dispelName] then
                            show = true
                        end
                    elseif conf == 3 then
                        if canDispel[dispelName] then
                            local GCD_startTime, GCD_duration = GetSpellCooldown(23881)
                            for _, spellId in pairs(canDispel[dispelName]) do
                                local start, duration, enabled = GetSpellCooldown(spellId)
                                local left = start + duration - GetTime()
                                if enabled and left <= GCD_duration then
                                    show = true
                                    trackCooldown(spellId, frame)
                                else
                                    tinsert(leftime, left)
                                end
                            end
                        end
                    end

                    if show then
                        if not frame_registry[frame].glow[dispelName] then
                            Glow:Start(debuffHighlightConf[dispelName], frame, dispelName)
                            -- play sound
                            if debuffOpt.Etc.playSound and lastPlayed[dispelName] < now - 2 then
                                local soundPath = string.format("Interface\\Addon\\%s\\Media\\Sounds\\", addonName)
                                local soundFile = soundPath .. string.format("%s\\%s.mp3", locale, dispelName)
                                local success = PlaySoundFile(soundFile, channel)
                                if not success then
                                    soundFile = soundPath .. string.format("%s\\%s.mp3", "enUS", dispelName)
                                    success = PlaySoundFile(soundFile, channel)
                                end
                                if success then
                                    lastPlayed[dispelName] = now
                                end
                            end
                        end
                        glow[dispelName] = true
                    else
                        if ticker and not ticker:IsCancelled() then
                            ticker:Cancel()
                        end
                        if #leftime > 0 then
                            local leasttime = math.min(unpack(leftime))
                            ticker = C_Timer.NewTimer(leasttime, function()
                                onUpdateHighlihgt(frame)
                                ticker = nil
                            end)
                        end
                    end
                end
            end
        end

        for dispelName in pairs(frame_registry[frame].glow) do
            if not glow[dispelName] then
                Glow:Stop(debuffHighlightConf[dispelName], frame, dispelName)
            end
        end
        frame_registry[frame].glow = glow
    end

    local function onFrameSetup(frame)
        if frame.unit and not UnitIsPlayer(frame.unit) and not UnitInPartyIsAI(frame.unit) then
            return
        end

        if not frame_registry[frame] then
            initRegistry(frame)
        end

        Aura:SetAuraVar(frame, "debuffsAll", frame_registry[frame].allaura, onUpdateHighlihgt)
    end
    self:HookFuncFiltered("DefaultCompactUnitFrameSetup", onFrameSetup)

    self:RegisterEvent("TRAIT_CONFIG_UPDATED", function()
        getTalent()
    end)

    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(event, unitTarget, castGUID, spellID)
        if not UnitIsUnit(unitTarget, "player") then
            return
        end
        if trackSpellFrame[spellID] then
            local frames = CopyTable(trackSpellFrame[spellID])
            trackSpellFrame[spellID] = nil
            C_Timer.After(0, function()
                for frame in next, frames do
                    onUpdateHighlihgt(frame)
                end
            end)
        end
    end)

    self:RegisterEvent("GROUP_ROSTER_UPDATE", function()
        roster_changed = true
    end)

    if roster_changed then
        roster_changed = false
        addon:IterateRoster(function(frame)
            if not frame_registry[frame] then
                initRegistry(frame)
            end
        end)
    end
    for frame, v in pairs(frame_registry) do
        onFrameSetup(frame)
    end
    getTalent()
end

function DebuffHighlight:OnDisable()
    self:DisableHooks()
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    self:UnregisterEvent("TRAIT_CONFIG_UPDATED")
    self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    roster_changed = true
    local restoreFrames = function(frame)
        Aura:SetAuraVar(frame, "debuffsAll")
        initRegistry(frame)
    end
    for frame in pairs(frame_registry) do
        restoreFrames(frame)
    end
    Aura:reset()
end
