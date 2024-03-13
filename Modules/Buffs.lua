--[[
    Created by Slothpala
    The aura indicator position and the aura timers are greatly inspired by a pull request from: https://github.com/excorp
--]]
local _, addonTable = ...
local addon = addonTable.RaidFrameSettings
local Buffs = addon:NewModule("Buffs")
Mixin(Buffs, addonTable.hooks)
local CDT = addonTable.cooldownText
local Glow = addonTable.Glow
local Aura = addonTable.Aura
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
local unitFrame = {}
local roster_changed = true
local glowOpt

-- Code for the Restoration Druid
local spell = {
    rejuvenation      = 774,
    germination       = 155777,
    sotf              = 114108,
    wildgrowth        = 48438,
    regrowth          = 8936,
    mastery           = 77495,
    clarity           = 16870,
    nss               = 132158,
    forestwalk        = 400129,
    lifebloom         = 33763,
    lifebloomVerdancy = 188550,
    adaptiveSwarm     = 391891,
    ironbark          = 102342,
}

local duridMasterySpell = {
    [spell.rejuvenation]      = true, -- Rejuvenation
    [spell.regrowth]          = true, -- Regrowth
    [spell.wildgrowth]        = true, -- Wild Growth
    [spell.lifebloom]         = true, -- Lifebloom
    [spell.lifebloomVerdancy] = true, -- Lifebloom (Verdancy)
    [200389]                  = true, -- Cultivation
    [157982]                  = true, -- Tranquility
    [383193]                  = true, -- Grove Tending
    [207386]                  = true, -- Spring Blossoms
    [102352]                  = true, -- Cenarion Ward
    [spell.germination]       = true, -- Germination
    [spell.adaptiveSwarm]     = true, -- Adaptive Swarm
}

local lifebloom = {
    [spell.lifebloom]         = true, -- Lifebloom
    [spell.lifebloomVerdancy] = true, -- Lifebloom (Verdancy)
}

local player
player = {
    GUID           = UnitGUID("player"),
    GUIDS          = {},
    spec           = 0,
    stat           = nil,
    aura           = {},
    buff           = {},
    sotfTrail      = 0,
    sotfTrail_time = 0.2,
    affectedSpell  = {
        [spell.rejuvenation] = true,
        [spell.germination]  = true,
        [spell.regrowth]     = true,
        [spell.wildgrowth]   = true
    },
    talent         = {
        ger  = 0, -- 82071 Germination
        sotf = 0, -- 82059 Soul of the Forest
        hb   = 0, -- 82065 Harmonious Blooming. 1스택일때=2, 2스택일때=3 으로 설정
        ni   = 0, -- 82214 Nurturing Instinct 회복의 본능 - 주문공격력 및 치유량 6% 증가
        nr   = 0, -- 82206 Natural Recovery 자연 회복 - 치유량과 받는 치유 효과 4% 증가
        rlfn = 0, -- 82207 Rising Light, Falling Night 떠오르는 빛, 몰락하는 밤 - 낮 치유/공격력 3% 증가 / 밤 유연 2%
        fw   = 0, -- 92229 Forestwalk 숲걸음 - <내가> 받는 모든 치유 5% 증가 -> 재생 힐량 계산시 무시한다.
        rg   = 0, -- 82058 Rampant Growth 무성한 생장
        nss  = 0, -- 82051 Nature's Splendor
        sb   = 0, -- 82081 Stonebark
    },
}

local talentMap = {
    [82071] = { key = "ger" },
    [82059] = { key = "sotf" },
    [82065] = { key = "hb" },
    [82214] = { key = "ni" },
    [82206] = { key = "nr" },
    [82207] = { key = "rlfn" },
    [92229] = { key = "fw" },
    [82058] = { key = "rg" },
    [82051] = { key = "nss" },
    [82081] = { key = "sb" },
}

local initMember

local getTalent = function()
    local specId = GetSpecializationInfo(GetSpecialization())
    if player.spec ~= specId then
        player.GUIDS = {}
        player.aura = {}
        player.buff = {}
        for frame, v in pairs(frame_registry) do
            v.buffs:Clear()
            v.debuffs = nil
            if frame.unit then
                initMember(UnitGUID(frame.unit))
            end
        end
    end
    player.spec = specId
    if specId ~= 105 then
        return
    end
    for k in pairs(player.talent) do
        player.talent[k] = 0
    end
    local configId = C_ClassTalents.GetActiveConfigID()
    if not configId then return end
    for nodeId, v in pairs(talentMap) do
        local nodeInfo = C_Traits.GetNodeInfo(configId, nodeId)
        if nodeInfo.activeRank > 0 then
            if v.key == "hb" then
                player.talent[v.key] = nodeInfo.activeRank + 1
            else
                player.talent[v.key] = nodeInfo.activeRank
            end
        end
    end
end

local getPlayerStat = function()
    local _, int = UnitStat("player", 4)
    local haste = GetHaste()
    local critical = GetCritChance()
    if GetSpecializationInfo(GetSpecialization()) == 63 then
        critical = critical + 15
    end
    local mastery = GetMasteryEffect()
    local versatility = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)
    return {
        int         = int,
        haste       = haste / 100,
        critical    = critical / 100,
        mastery     = mastery / 100,
        versatility = versatility / 100,
    }
end

local cachedEstimatedHeal = {}
local getEstimatedHeal = function(spellId, masteryStack, me, GUID)
    if not player.stat then
        player.stat = getPlayerStat()
    end
    local power
    if spellId == spell.rejuvenation or spellId == spell.germination then
        power = 0.28594        -- 24.65% * 16%
    elseif spellId == spell.regrowth then
        power = 1.8684         -- 207.6% * -10%
    elseif spellId == spell.wildgrowth then
        power = 0.190989103872 -- 94.08% * 16% /7 * 1.07 * 1.07 * 1.07
    end

    -- 특성중에 바위 껍질 -> 무껍 대상자는 HoT 힐량 20% 증가. 이건 무시한다.

    local clarity    = player.buff[spell.clarity] and 1 or 0
    local nss        = player.buff[spell.nss] and 1 or 0
    local forestwalk = player.buff[spell.forestwalk] and 1 or 0


    local adaptiveSwarm = player.GUIDS[GUID].buff[spell.adaptiveSwarm] and 1 or 0
    local ironbark = player.GUIDS[GUID].buff[spell.ironbark] and 1 or 0

    local key = string.format("ID:%d I:%d M:%f V:%f,ni:%d nr:%d rlfn:%d rg:%d,ms:%d,c:%d nss:%d fw:%d,as:%d ib:%d",
        spellId,
        player.stat.int, player.stat.mastery, player.stat.versatility,
        player.talent.ni, player.talent.nr, player.talent.rlfn, player.talent.rg,
        masteryStack, clarity, nss, forestwalk,
        adaptiveSwarm, ironbark)
    if cachedEstimatedHeal[key] then
        return cachedEstimatedHeal[key]
    end
    local estimated = player.stat.int * power * (1 + masteryStack * player.stat.mastery) * (1 + player.stat.versatility)

    if spellId ~= spell.regrowth then
        if player.talent.sb and ironbark > 0 then
            estimated = estimated * 1.2
        end
        if adaptiveSwarm > 0 then
            estimated = estimated * 1.2
        end
    end

    local inc = 0
    if player.talent.ni > 0 then
        inc = inc + player.talent.ni * 0.03
    end
    if player.talent.nr > 0 then
        inc = inc + player.talent.nr * 0.02
    end
    if player.talent.rlfn > 0 then
        local hour, _ = GetGameTime()
        if hour >= 6 and hour < 18 then
            -- Increased healing by 3% during the day. At night, this is already included in my versatility.
            inc = inc + 0.03
        end
    end
    if spellId == spell.regrowth then
        -- 재생의 첫 힐량을 구하는것이라서 주기적인 힐량 증가는 계산하면 안된다
        --[[
        if player.talent.rg > 0 then
            inc = inc + 0.5
        end
        ]]
        -- 청명은 첫 힐에만 반영되고, 주기적인 힐에는 반영되지 않는다. 따라서 주기적인 힐의 강화 여부를 첫힐량으로 판단할때는 버프 받은 힐량으로 구해야 한다.
        if clarity > 0 then
            inc = inc + 0.3
        end
        -- 신속함은 첫 힐에만 반영되고, 주기적인 힐에는 반영되지 않는다. 따라서 주기적인 힐의 강화 여부를 첫힐량으로 판단할때는 버프 받은 힐량으로 구해야 한다.
        if nss > 0 then
            inc = inc + 1
            if player.talent.nss > 0 then
                inc = inc + 0.35
            end
        end
    end

    if me then
        if player.talent.nr > 0 then
            inc = inc + player.talent.nr * 0.02
        end
        if forestwalk > 0 then
            inc = inc + 0.05
        end
    end

    estimated = Round(estimated * (1 + inc))
    cachedEstimatedHeal[key] = estimated
    return estimated
end

local masteryChange = function(GUID, spellId, delta, showIcon)
    if duridMasterySpell[spellId] then
        if lifebloom[spellId] then
            delta = delta * player.talent.hb
        end

        player.GUIDS[GUID].masteryStack = player.GUIDS[GUID].masteryStack + delta
        if not showIcon then
            return
        end
        if addon:count(player.GUIDS[GUID].frame) == 0 then
            for frame in pairs(frame_registry) do
                if frame and frame.unit and UnitGUID(frame.unit) == GUID then
                    player.GUIDS[GUID].frame[frame] = true
                    player.GUIDS[GUID].unit = frame.unit
                end
            end
        end
        for frame in pairs(player.GUIDS[GUID].frame) do
            if UnitGUID(frame.unit) ~= GUID then
                player.GUIDS[GUID].frame[frame] = nil
            else
                -- 가짜 aura 생성
                local auraInstanceID = -1
                local masterySpellName, _, masteryIcon, _, _, _, masterySpellId = GetSpellInfo(spell.mastery)
                if player.GUIDS[GUID].masteryStack > 0 then
                    frame_registry[frame].buffs[auraInstanceID] = {
                        applications            = player.GUIDS[GUID].masteryStack, --number	
                        applicationsp           = "",                              --string? force show applications evenif it is 1
                        auraInstanceID          = auraInstanceID,                  --number	
                        canApplyAura            = false,                           -- boolean	Whether or not the player can apply this aura.
                        charges                 = 1,                               --number	
                        dispelName              = false,                           --string?	
                        duration                = 0,                               --number	
                        expirationTime          = 0,                               --number	
                        icon                    = masteryIcon,                     --number	
                        isBossAura              = false,                           --boolean	Whether or not this aura was applied by a boss.
                        isFromPlayerOrPlayerPet = true,                            --boolean	Whether or not this aura was applied by a player or their pet.
                        isHarmful               = false,                           --boolean	Whether or not this aura is a debuff.
                        isHelpful               = true,                            --boolean	Whether or not this aura is a buff.
                        isNameplateOnly         = false,                           --boolean	Whether or not this aura should appear on nameplates.
                        isRaid                  = false,                           --boolean	Whether or not this aura meets the conditions of the RAID aura filter.
                        isStealable             = false,                           --boolean	
                        maxCharges              = 1,                               --number	
                        name                    = masterySpellName,                --string	The name of the aura.
                        nameplateShowAll        = false,                           --boolean	Whether or not this aura should always be shown irrespective of any usual filtering logic.
                        nameplateShowPersonal   = false,                           --boolean	
                        points                  = {},                              --array	Variable returns - Some auras return additional values that typically correspond to something shown in the tooltip, such as the remaining strength of an absorption effect.	
                        sourceUnit              = "player",                        --string?	Token of the unit that applied the aura.
                        spellId                 = masterySpellId,                  --number	The spell ID of the aura.
                        timeMod                 = 1,                               --number	
                    }
                else
                    frame_registry[frame].buffs[auraInstanceID] = nil
                end
            end
        end
    end
end
-- END: Code for the Restoration Druid


local function CompactUnitFrame_ParseAllAuras(frame, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)
    if not frame.debuffs then
        frame.debuffs = TableUtil.CreatePriorityTable(AuraUtil.UnitFrameDebuffComparator, TableUtil.Constants.AssociativePriorityTable)
    else
        frame.debuffs:Clear()
    end
    frame.buffs:Clear()

    local batchCount = nil
    local usePackedAura = true
    local function HandleAura(aura)
        local type = CompactUnitFrame_ProcessAura(frame, aura, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)

        if type == AuraUtil.AuraUpdateChangedType.Buff then
            frame.buffs[aura.auraInstanceID] = aura
        end
    end
    AuraUtil.ForEachAura(frame.displayedUnit, AuraUtil.CreateFilterString(AuraUtil.AuraFilters.Helpful), batchCount, HandleAura, usePackedAura)
end

function Buffs:Glow(frame, onoff)
    if onoff then
        Glow:Start(glowOpt, frame)
    else
        Glow:Stop(glowOpt, frame)
    end
end

function Buffs:OnEnable()
    CDT.TimerTextLimit = addon.db.profile.MinorModules.TimerTextLimit

    glowOpt = CopyTable(addon.db.profile.MinorModules.Glow)
    glowOpt.type = addon:ConvertDbNumberToGlowType(glowOpt.type)

    local frameOpt = CopyTable(addon.db.profile.Buffs.BuffFramesDisplay)
    frameOpt.petframe = addon.db.profile.Buffs.petframe
    frameOpt.sotf = addon.db.profile.Buffs.sotf
    frameOpt.mastery = addon.db.profile.Buffs.mastery
    frameOpt.framestrata = addon:ConvertDbNumberToFrameStrata(frameOpt.framestrata)
    frameOpt.baseline = addon:ConvertDbNumberToBaseline(frameOpt.baseline)
    frameOpt.type = frameOpt.baricon and "baricon" or "blizzard"

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

    Aura.Opt.Buff.frameOpt = frameOpt
    Aura.Opt.Buff.durationOpt = durationOpt
    Aura.Opt.Buff.stackOpt = stackOpt

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


    --Buffframe position
    local point = addon:ConvertDbNumberToPosition(frameOpt.point)
    local relativePoint = addon:ConvertDbNumberToPosition(frameOpt.relativePoint)
    local followPoint, followRelativePoint, followOffsetX, followOffsetY = addon:GetAuraGrowthOrientationPoints(frameOpt.orientation, frameOpt.gap, frameOpt.baseline)

    local comparePriority = function(a, b)
        return a.priority > b.priority
    end

    local onHideAllBuffs

    -- Code for the Restoration Druid
    initMember = function(GUID)
        if not frameOpt.sotf or player.spec ~= 105 or not GUID then
            return
        end
        player.GUIDS[GUID] = {
            unit         = nil,
            empowered    = {},
            buff         = {},
            frame        = {},
            masteryStack = 0,
        }

        for frame in pairs(frame_registry) do
            if frame and frame.unit and UnitGUID(frame.unit) == GUID then
                player.GUIDS[GUID].frame[frame] = true
                player.GUIDS[GUID].unit = frame.unit
            end
        end

        if not player.GUIDS[GUID].unit then
            player.GUIDS[GUID] = nil
            return
        end

        local function HandleAura(aura)
            -- 대상이 나 이거나, 내가 건 aura 일때
            if GUID == player.GUID or aura.isFromPlayerOrPlayerPet then
                -- 특화 stack 관련이 있나? -> 특화스택 증가
                masteryChange(GUID, aura.spellId, 1, frameOpt.mastery and player.spec == 105)
            end
        end
        player.GUIDS[GUID].masteryStack = 0
        AuraUtil.ForEachAura(player.GUIDS[GUID].unit, AuraUtil.CreateFilterString(AuraUtil.AuraFilters.Helpful), nil, HandleAura, true)
    end

    local trackingEvent = {
        SPELL_AURA_APPLIED  = true,
        SPELL_AURA_REMOVED  = true,
        SPELL_AURA_REFRESH  = true,
        SPELL_PERIODIC_HEAL = true,
        SPELL_HEAL          = true,
    }
    local trackEmpowered = function()
        local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, school, amount, overhealing, absorbed, critical = CombatLogGetCurrentEventInfo()

        if not trackingEvent[subevent] then
            return
        end

        -- 플레이어의 버프/디버프가 변경되면 스탯을 다시 구한다
        if destGUID == player.GUID and (subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REMOVED" or subevent == "SPELL_AURA_REFRESH") then
            player.stat = nil
            player.buff[spellId] = subevent ~= "SPELL_AURA_REMOVED" and true or nil
        end

        if sourceGUID ~= player.GUID or not destGUID or not spellId or player.spec ~= 105 then
            return
        end

        local buffsChanged
        if not player.GUIDS[destGUID] then
            initMember(destGUID)
            buffsChanged = true
            if not player.GUIDS[destGUID] then
                return
            end
        end

        -- 특화 스택 추적
        if not buffsChanged and duridMasterySpell[spellId] then
            if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
                if subevent == "SPELL_AURA_APPLIED" then
                    -- 특화 stack 관련이 있나? -> 특화스택 증가
                    masteryChange(destGUID, spellId, 1, frameOpt.mastery)
                    buffsChanged = frameOpt.mastery and true or buffsChanged
                end
            elseif subevent == "SPELL_AURA_REMOVED" then
                -- 특화 stack 관련이 있나? -> 특화스택 감사
                masteryChange(destGUID, spellId, -1, frameOpt.mastery)
                buffsChanged = frameOpt.mastery and true or buffsChanged
            end
        end

        if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
            player.GUIDS[destGUID].buff[spellId] = true

            -- 급성,회복 아니면 무시
            if spellId ~= spell.rejuvenation and spellId ~= spell.germination and spellId ~= spell.wildgrowth then
                return
            end
            if spellId == spell.wildgrowth and player.buff[spell.sotf] or player.sotfTrail >= GetTime() then
                -- 숲영 버프 받은 급성일 확율이 높음
                player.GUIDS[destGUID].empowered[spellId] = -1.5
            else
                -- 강화% 초기화
                player.GUIDS[destGUID].empowered[spellId] = nil
            end
        elseif subevent == "SPELL_AURA_REMOVED" then
            player.GUIDS[destGUID].buff[spellId] = nil
        elseif subevent == "SPELL_PERIODIC_HEAL" then
            -- 급성,회복 아니면 무시
            if spellId ~= spell.rejuvenation and spellId ~= spell.germination and spellId ~= spell.wildgrowth then
                return
            end
            -- 강화%가 없다면 새로 구함
            if not player.GUIDS[destGUID].empowered[spellId] or player.GUIDS[destGUID].empowered[spellId] < 0 then
                -- calc -> set -> display
                local estimatedHeal = getEstimatedHeal(spellId, player.GUIDS[destGUID].masteryStack, destGUID == player.GUID, destGUID)
                local rate = (critical and amount / 2 or amount) / estimatedHeal
                player.GUIDS[destGUID].empowered[spellId] = rate
                for frame in pairs(player.GUIDS[destGUID].frame) do
                    if UnitGUID(frame.unit) ~= destGUID then
                        player.GUIDS[destGUID].frame[frame] = nil
                    else
                        onHideAllBuffs(frame)
                    end
                end
            end
        elseif subevent == "SPELL_HEAL" then
            -- 재생 아니면 무시
            if spellId ~= spell.regrowth then
                return
            end
            -- 강화 % 구해서 임시 변수에 셋팅 -> UNIT_AURA에서 재생이 걸리거나,갱신될때 사용
            local estimatedHeal = getEstimatedHeal(spellId, player.GUIDS[destGUID].masteryStack, destGUID == player.GUID, destGUID)
            local rate = (critical and amount / 2 or amount) / estimatedHeal
            player.GUIDS[destGUID].empowered[spellId] = rate
        end

        if buffsChanged then
            for frame in pairs(player.GUIDS[destGUID].frame) do
                if UnitGUID(frame.unit) ~= destGUID then
                    player.GUIDS[destGUID].frame[frame] = nil
                else
                    onHideAllBuffs(frame)
                end
            end
        end
    end
    -- END: Code for the Restoration Druid

    local onUnitAuraPet = function(unit, unitAuraUpdateInfo)
        if not unit:match("pet") then
            return
        end
        if not unitFrame[unit] then
            return
        end
        for srcframe in pairs(unitFrame[unit]) do
            local frame = frame_registry[srcframe]
            if frame then
                local buffsChanged = false

                local displayOnlyDispellableDebuffs = false
                local ignoreBuffs = false
                local ignoreDebuffs = true
                local ignoreDispelDebuffs = true

                frame.unit = srcframe.unit
                frame.displayedUnit = srcframe.displayedUnit

                if unitAuraUpdateInfo == nil or unitAuraUpdateInfo.isFullUpdate or frame.debuffs == nil then
                    CompactUnitFrame_ParseAllAuras(frame, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)
                    buffsChanged = true
                else
                    if unitAuraUpdateInfo.addedAuras ~= nil then
                        for _, aura in ipairs(unitAuraUpdateInfo.addedAuras) do
                            local type = CompactUnitFrame_ProcessAura(frame, aura, displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs)
                            if type == AuraUtil.AuraUpdateChangedType.Buff then
                                frame.buffs[aura.auraInstanceID] = aura
                                buffsChanged = true
                            end
                        end
                    end

                    if unitAuraUpdateInfo.updatedAuraInstanceIDs ~= nil then
                        for _, auraInstanceID in ipairs(unitAuraUpdateInfo.updatedAuraInstanceIDs) do
                            if frame.buffs[auraInstanceID] ~= nil then
                                local newAura = C_UnitAuras.GetAuraDataByAuraInstanceID(frame.displayedUnit, auraInstanceID)
                                if newAura ~= nil then
                                    newAura.isBuff = true
                                end
                                frame.buffs[auraInstanceID] = newAura
                                buffsChanged = true
                            end
                        end
                    end

                    if unitAuraUpdateInfo.removedAuraInstanceIDs ~= nil then
                        for _, auraInstanceID in ipairs(unitAuraUpdateInfo.removedAuraInstanceIDs) do
                            if frame.buffs[auraInstanceID] ~= nil then
                                frame.buffs[auraInstanceID] = nil
                                buffsChanged = true
                            end
                        end
                    end
                end

                if buffsChanged then
                    onHideAllBuffs(srcframe)
                end
            end
        end
    end

    local onSetBuff = function(buffFrame, aura, opt)
        if buffFrame:IsForbidden() then --not sure if this is still neede but when i created it at the start if dragonflight it was
            return
        end
        local parent = buffFrame:GetParent()
        if not parent or not frame_registry[parent] then
            return
        end

        local aurastored = frame_registry[parent].aura
        local oldAura = aurastored[aura.auraInstanceID]
        if frameOpt.refreshAni and oldAura then
            if math.abs(aura.expirationTime - oldAura.expirationTime) > 1 or oldAura.applications ~= aura.applications then
                aura.refresh = true
            end
        end
        aurastored[aura.auraInstanceID] = aura

        -- Code for the Restoration Druid
        if frameOpt.sotf and player.spec == 105 then
            local GUID = UnitGUID(parent.unit)
            if GUID then
                if not player.GUIDS[GUID] then
                    initMember(GUID)
                end

                local empowered = player.GUIDS[GUID].empowered and player.GUIDS[GUID].empowered[aura.spellId]
                if empowered then
                    if empowered < 0 then
                        empowered = empowered * -1
                    end
                    local baseline = aura.spellId == spell.wildgrowth and 1.35 or 1.9
                    aura.applications = math.floor(empowered)
                    aura.applicationsp = empowered - aura.applications >= 0.35 and "+" or nil
                    aura.empowered = empowered > baseline and true
                else
                    aura.empowered = oldAura and oldAura.empowered
                end

                player.GUIDS[GUID].frame[parent] = true
                player.GUIDS[GUID].unit = parent.unit
            end
        end

        -- icon, stack, cooldown(duration) start
        buffFrame:SetAura(aura)

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
        end

        self:Glow(buffFrame, aura.empowered or opt.glow)
        buffFrame:SetAlpha(opt.alpha or 1)
    end

    onHideAllBuffs = function(frame)
        if not frame_registry[frame] or frame:IsForbidden() or not frame:IsVisible() then
            return
        end
        if frame.buffFrames then
            for _, v in pairs(frame.buffFrames) do
                v:Hide()
            end
        end

        -- set placed aura / other aura
        local frameNum = 1
        local groupFrameNum = {}
        local sorted = {
            [0] = {},
        }
        for _, buffs in pairs({ frame.buffs, frame_registry[frame].buffs }) do
            buffs:Iterate(function(auraInstanceID, aura)
                if userPlaced[aura.spellId] then
                    local idx = frame_registry[frame].placedAuraStart + userPlaced[aura.spellId].idx - 1
                    local buffFrame = frame_registry[frame].extraBuffFrames[idx]
                    local placed = userPlaced[aura.spellId]
                    onSetBuff(buffFrame, aura, placed)
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
                local filtered = filteredAuras[aura.spellId]
                local priority = filtered and filtered.priority or 0
                tinsert(sorted[0], { spellId = aura.spellId, priority = priority, aura = aura, opt = filtered or {} })
            end)
        end
        -- set buffs after sorting to priority.
        for _, v in pairs(sorted) do
            table.sort(v, comparePriority)
        end
        for groupNo, auralist in pairs(sorted) do
            for k, v in pairs(auralist) do
                if groupNo == 0 then
                    -- default aura frame
                    if k > frame_registry[frame].maxBuffs then
                        break
                    end
                    frameNum = k + 1
                    local buffFrame = frame_registry[frame].extraBuffFrames[k]
                    onSetBuff(buffFrame, v.aura, v.opt)
                else
                    -- aura group frame
                    local idx = frame_registry[frame].auraGroupStart[groupNo] + k - 1
                    local buffFrame = frame_registry[frame].extraBuffFrames[idx]
                    onSetBuff(buffFrame, v.aura, v.opt)
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
            if not buffFrame.auraInstanceID or not (frame.buffs[buffFrame.auraInstanceID] or frame_registry[frame].buffs[buffFrame.auraInstanceID]) then
                self:Glow(buffFrame, false)
                buffFrame:UnsetAura()
            end
        end
        for i = frameNum, frame_registry[frame].maxBuffs do
            local buffFrame = frame_registry[frame].extraBuffFrames[i]
            self:Glow(buffFrame, false)
            buffFrame:UnsetAura()
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
                self:Glow(buffFrame, false)
                buffFrame:UnsetAura()
            end
        end
    end
    self:HookFunc("CompactUnitFrame_HideAllBuffs", onHideAllBuffs)

    local function onFrameSetup(frame)
        if not frameOpt.petframe then
            local fname = frame:GetName()
            if not fname or fname:match("Pet") then
                return
            end
        end

        if not frame_registry[frame] then
            frame_registry[frame] = {
                maxBuffs        = frameOpt.maxbuffsAuto and frame.maxBuffs or frameOpt.maxbuffs,
                placedAuraStart = 0,
                auraGroupStart  = {},
                auraGroupEnd    = {},
                extraBuffFrames = {},
                reanchor        = {},
                buffs           = TableUtil.CreatePriorityTable(AuraUtil.DefaultAuraCompare, TableUtil.Constants.AssociativePriorityTable),
                aura            = {},
                empowered       = {},
                dirty           = true,
            }
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
            local parent = parentIdx and frame_registry[frame].extraBuffFrames[parentIdx] or frame
            buffFrame:ClearAllPoints()
            buffFrame:SetPoint(place.point, parent, place.relativePoint, place.xOffset, place.yOffset)
            buffFrame:SetSize(width, height)
            buffFrame:SetCoord(width, height)
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
                buffFrame:SetSize(width, height)
                buffFrame:SetCoord(width, height)
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
                    maxBuffs        = frameOpt.maxbuffsAuto and frame.maxBuffs or frameOpt.maxbuffs,
                    placedAuraStart = 0,
                    auraGroupStart  = {},
                    auraGroupEnd    = {},
                    extraBuffFrames = {},
                    reanchor        = {},
                    buffs           = TableUtil.CreatePriorityTable(AuraUtil.DefaultAuraCompare, TableUtil.Constants.AssociativePriorityTable),
                    aura            = {},
                    empowered       = {},
                    dirty           = true,
                }
            end
        end)
    end
    for frame, v in pairs(frame_registry) do
        v.dirty = true
        onFrameSetup(frame)
        if frame.unit then
            if not unitFrame[frame.unit] then unitFrame[frame.unit] = {} end
            unitFrame[frame.unit][frame] = true
            if frame.unitExists and frame:IsShown() and not frame:IsForbidden() then
                CompactUnitFrame_UpdateAuras(frame)
            end
            onUnitAuraPet(frame.unit)
            initMember(UnitGUID(frame.unit))
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
            unitFrame[frame.unit][frame] = true
            for srcframe in pairs(unitFrame[unit]) do
                if srcframe.unit ~= unit then
                    unitFrame[unit][srcframe] = nil
                end
            end
        end)
    end

    local _, englishClass = UnitClass("player")
    if englishClass == "DRUID" then
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", getTalent)
        self:RegisterEvent("TRAIT_CONFIG_UPDATED", getTalent)
        getTalent()
    end

    if frameOpt.sotf then
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", trackEmpowered)
    end

    if frameOpt.petframe or frameOpt.sotf then
        self:RegisterEvent("UNIT_AURA", function(event, unit, unitAuraUpdateInfo)
            onUnitAuraPet(unit, unitAuraUpdateInfo)
        end)
    end
end

--parts of this code are from FrameXML/CompactUnitFrame.lua
function Buffs:OnDisable()
    self:DisableHooks()
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self:UnregisterEvent("TRAIT_CONFIG_UPDATED")
    self:UnregisterEvent("UNIT_AURA")
    roster_changed = true
    local restoreBuffFrames = function(frame)
        for _, extraBuffFrame in pairs(frame_registry[frame].extraBuffFrames) do
            extraBuffFrame:Hide()
            self:Glow(extraBuffFrame, false)
        end
        if frame.unit and frame.unitExists and frame:IsShown() and not frame:IsForbidden() then
            CompactUnitFrame_UpdateAuras(frame)
        end
        frame_registry[frame].buffs:Clear()
        frame_registry[frame].debuffs = nil
    end
    for frame in pairs(frame_registry) do
        restoreBuffFrames(frame)
    end
    player.GUIDS = {}
    player.aura = {}
    player.buff = {}
    CDT:DisableCooldownText()
end
