local _, addonTable = ...
local addon = addonTable.RaidFrameSettings

local _, englishClass = UnitClass("player")
if englishClass ~= "DRUID" then
    return
end

addonTable.classMod = {}
local mod = addonTable.classMod

local Buffs, frame_registry, frameOpt

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
    [spell.germination]       = true, -- Germination
    [spell.adaptiveSwarm]     = true, -- Adaptive Swarm
    [200389]                  = true, -- Cultivation
    [157982]                  = true, -- Tranquility
    [383193]                  = true, -- Grove Tending
    [207386]                  = true, -- Spring Blossoms
    [102352]                  = true, -- Cenarion Ward
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
        hb   = 0, -- 82065 Harmonious Blooming
        ni   = 0, -- 82214 Nurturing Instinct 회복의 본능 - 주문공격력 및 치유량 6% 증가
        nr   = 0, -- 82206 Natural Recovery 자연 회복 - 치유량과 받는 치유 효과 4% 증가
        rlfn = 0, -- 82207 Rising Light, Falling Night 떠오르는 빛, 몰락하는 밤 - 낮 치유/공격력 3% 증가 / 밤 유연 2%
        fw   = 0, -- 92229 Forestwalk 숲걸음 - <내가> 받는 모든 치유 5% 증가 -> 재생 힐량 계산시 무시한다.
        rg   = 0, -- 82058 Rampant Growth 무성한 생장
        nss  = 0, -- 82051 Nature's Splendor
        sb   = 0, -- 82081 Stonebark
        re   = 0, -- 82062 Regenesis
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
    [82062] = { key = "re" },
}

local initMember

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
local getEstimatedHeal = function(spellId, masteryStack, GUID)
    if not player.stat then
        player.stat = getPlayerStat()
    end
    local power
    if spellId == spell.rejuvenation or spellId == spell.germination then
        -- power = 0.3188889648 -- 27.608 * -7% * 15% * 8%
        power = 0.3193403298350825
    elseif spellId == spell.regrowth then
        -- power = 1.855769616  -- 207.6% * -7% * -11% * 8%
        power = 1.855322337331334
    elseif spellId == spell.wildgrowth then
        power = 0.190175753722752 -- 94.08% * -7% * 15% * 8% /7 * 1.07 * 1.07 * 1.07
    end

    local talent        = player.talent

    local me            = GUID == player.GUID

    local clarity       = player.buff[spell.clarity] and 1 or 0
    local nss           = player.buff[spell.nss] and 1 or 0
    local forestwalk    = player.buff[spell.forestwalk] and 1 or 0

    local unit          = player.GUIDS[GUID].unit
    local adaptiveSwarm = player.GUIDS[GUID].buff[spell.adaptiveSwarm] and 1 or 0
    local ironbark      = player.GUIDS[GUID].buff[spell.ironbark] and 1 or 0
    local re            = 0

    if spellId == spell.rejuvenation or spellId == spell.germination then
        if talent.re > 0 then
            re = (10 - math.floor(UnitHealth(unit) / UnitHealthMax(unit) * 10))
        end
    end

    local key = string.format("S:%d I:%d M:%f V:%f|c:%d nss:%d|me:%d ms:%d as:%d ib:%d re:%d",
        spellId, player.stat.int, player.stat.mastery, player.stat.versatility,
        clarity, nss,
        me, masteryStack, adaptiveSwarm, ironbark, re
    )
    if cachedEstimatedHeal[key] then
        return cachedEstimatedHeal[key]
    end
    local estimated = player.stat.int * power * (1 + masteryStack * player.stat.mastery) * (1 + player.stat.versatility)

    local inc = 0
    if talent.ni > 0 then
        -- inc = inc + talent.ni * 0.03
        estimated = estimated * (1 + talent.ni * 0.03)
    end
    if talent.nr > 0 then
        -- inc = inc + talent.nr * 0.02
        estimated = estimated * (1 + talent.nr * 0.02)
        if me then
            -- inc = inc + talent.nr * 0.02
            estimated = estimated * (1 + talent.nr * 0.02)
        end
    end
    if talent.rlfn > 0 then
        local hour, _ = GetGameTime()
        if hour >= 6 and hour < 18 then
            -- Increased healing by 3% during the day. At night, this is already included in my versatility.
            -- inc = inc + 0.03
            estimated = estimated * 1.03
        end
    end

    if spellId ~= spell.regrowth then
        if spellId == spell.rejuvenation or spellId == spell.germination then
            if talent.re > 0 then
                -- 대상의 깍인 체력 10%당 1%씩 힐량 증가.
                estimated = estimated * (1 + re * talent.re * 0.01)
            end
        end
        if talent.sb and ironbark > 0 then
            estimated = estimated * 1.2
        end
        if adaptiveSwarm > 0 then
            estimated = estimated * 1.2
        end
    else
        -- 청명은 첫 힐에만 반영되고, 주기적인 힐에는 반영되지 않는다. 따라서 주기적인 힐의 강화 여부를 첫힐량으로 판단할때는 버프 받은 힐량으로 구해야 한다.
        if clarity > 0 then
            -- inc = inc + 0.3
            estimated = estimated * 1.3
        end
        -- 신속함은 첫 힐에만 반영되고, 주기적인 힐에는 반영되지 않는다. 따라서 주기적인 힐의 강화 여부를 첫힐량으로 판단할때는 버프 받은 힐량으로 구해야 한다.
        if nss > 0 then
            -- inc = inc + 1 + talent.nss > 0 and 0.35 or 0
            --[[
            estimated = estimated * 2
            if talent.nss > 0 then
                estimated = estimated * 1.35
            end
            ]]
            estimated = estimated * (1 + talent.nss > 0 and 1.35 or 1)
        end
    end

    if me and forestwalk > 0 then
        -- inc = inc + 0.05
        estimated = estimated * 1.05
    end

    -- estimated = Round(estimated * (1 + inc))
    estimated = estimated * (1 + inc)
    cachedEstimatedHeal[key] = Round(estimated)
    return cachedEstimatedHeal[key]
end

local getTalent = function()
    local specId = GetSpecializationInfo(GetSpecialization())
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
            player.talent[v.key] = nodeInfo.activeRank
        end
    end
    cachedEstimatedHeal = {}
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

local masteryChange = function(GUID, spellId, delta, showIcon)
    if duridMasterySpell[spellId] then
        if lifebloom[spellId] then
            delta = delta * (1 + player.talent.hb)
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
            if not frame.unit or UnitGUID(frame.unit) ~= GUID then
                player.GUIDS[GUID].frame[frame] = nil
            else
                -- 가짜 aura 생성
                local auraInstanceID = -spell.mastery
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
            local estimatedHeal = getEstimatedHeal(spellId, player.GUIDS[destGUID].masteryStack, destGUID)
            local rate = (critical and amount / 2 or amount) / estimatedHeal
            player.GUIDS[destGUID].empowered[spellId] = rate
            for frame in pairs(player.GUIDS[destGUID].frame) do
                if UnitGUID(frame.unit) ~= destGUID then
                    player.GUIDS[destGUID].frame[frame] = nil
                else
                    CompactUnitFrame_HideAllBuffs(frame, #frame.buffFrames + 1)
                end
            end
        end
    elseif subevent == "SPELL_HEAL" then
        -- 재생 아니면 무시
        if spellId ~= spell.regrowth then
            return
        end
        -- 강화 % 구해서 임시 변수에 셋팅 -> UNIT_AURA에서 재생이 걸리거나,갱신될때 사용
        local estimatedHeal = getEstimatedHeal(spellId, player.GUIDS[destGUID].masteryStack, destGUID)
        local rate = (critical and amount / 2 or amount) / estimatedHeal
        player.GUIDS[destGUID].empowered[spellId] = rate
    end

    if buffsChanged then
        for frame in pairs(player.GUIDS[destGUID].frame) do
            if UnitGUID(frame.unit) ~= destGUID then
                player.GUIDS[destGUID].frame[frame] = nil
            else
                CompactUnitFrame_HideAllBuffs(frame, #frame.buffFrames + 1)
            end
        end
    end
end

function mod:initMod(buffs_mod, buffs_frame_registry, displayAura)
    Buffs = buffs_mod
    frame_registry = buffs_frame_registry
end

function mod:onSetBuff(buffFrame, aura, oldAura, opt)
    local parent = buffFrame:GetParent()
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
end

function mod:init(frame)
    if frame and frame.unit then
        initMember(UnitGUID(frame.unit))
    end
end

function mod:onEnable(opt)
    frameOpt = opt

    Buffs:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", getTalent)
    Buffs:RegisterEvent("TRAIT_CONFIG_UPDATED", getTalent)
    getTalent()

    Buffs:RegisterEvent("ENCOUNTER_END", function()
        self:rosterUpdate()
    end)

    if frameOpt.sotf then
        Buffs:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", trackEmpowered)
    end
end

function mod:onDisable()
    Buffs:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    Buffs:UnregisterEvent("TRAIT_CONFIG_UPDATED")
    Buffs:UnregisterEvent("ENCOUNTER_END")
    Buffs:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    player.GUIDS = {}
    player.aura = {}
    player.buff = {}
end

function mod:rosterUpdate()
    player.GUIDS = {}
    player.aura = {}
    player.buff = {}
    for frame, v in pairs(frame_registry) do
        v.buffs:Clear()
        v.debuffs = nil
    end
end
