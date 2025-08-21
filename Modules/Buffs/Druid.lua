local _, addonTable = ...
local addon = addonTable.RaidFrameSettings

local GetSpellInfo = addon.GetSpellInfo

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
    frenziedRegen     = 22842,
    barkskin          = 22812,
    symbioticBlooms   = 439530,
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
    [spell.symbioticBlooms]   = true, -- Symbiotic Blooms
}

local lifebloom = {
    [spell.lifebloom]         = true, -- Lifebloom
    [spell.lifebloomVerdancy] = true, -- Lifebloom (Verdancy)
}

local player
player = {
    GUID            = UnitGUID("player"),
    GUIDS           = {},
    spec            = 0,
    stat            = nil,
    aura            = {},
    buff            = {},
    sotfTrail       = 0,
    sotfTrail_time  = 0.2,
    totem           = {
        [1] = false,
        [2] = false,
        [3] = false,
    },
    totems          = 0,
    symbioticBlooms = 0,
    affectedSpell   = {
        [spell.rejuvenation] = true,
        [spell.germination]  = true,
        [spell.regrowth]     = true,
        [spell.wildgrowth]   = true
    },
    talent          = {
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

        lotg = 0, -- Lore of the Grove 숲의 전승: 회복/급성 치유량 +3%/+5%
        gi   = 0, -- Grove's Inspiration 숲의 감화: 재생,급속,신치 +9%
        wp   = 0, -- Wildstalker's Power 야생추적자의 힘: 회복,꽃피,피생 +10%

        pon  = 0, -- Power of Nature 자연의 힘: 숲수호자 있을때 회복,꽃피,피생 +10%
        hotg = 0, -- Harmony of the Grove 숲의 조화: 숲수호자 있을때 회복,꽃피,피생 (1마리당) +5%

        rn   = 0, -- Root Network 뿌리 연결망: 공생체 꽃 1개당 치유 +2%
        vc   = 0, -- Vigorous Creepers 활력의 덩굴: 공생체 꽃 대상자에게 치유효과 +20%

        fr   = 0, -- Frenzied Regeneration 광포한 재생력: 광재중에 3초간 받는 치유 +20%     -> 내가 받는 치유
        vh   = 0, -- Verdant Heart 신록의 심장: 광재,나껍 치유 +20%                         -> 내가 받는 치유
        bwn  = 0, -- Bond with Nature 자연과의 유대: 받는 치유 +4%                          -> 내가 받는 치유
        hc   = 0, -- Harmonious Constitution 조화로운 체질: 자신에게 거는 재생 +35%         -> 내가 받는 치유
    },
}

-- 광재: 22842
-- 나껍: 22812

-- 공생체 꽃: 439530

-- 내 숲수호자가 몇마리 나와 있는지, 공생체 꽃 버프 걸린 사람이 몇명인지 추적이 필요하다. 한명한테 공생체꽃이 여러개 걸릴수 있나? -> 가능
-- 숲수호자 -> PLAYER_TOTEM_UPDATE 에서 토템 번호가 나오면 GetTotemInfo() API로 상태를 가져올수 있다.

local talents = {
    { key = "fr",   nodeId = 82220 },                   -- Frenzied Regeneration 광포한 재생력: 광재중에 3초간 받는 치유 +20%
    { key = "vh",   nodeId = 82218 },                   -- Verdant Heart 신록의 심장: 광재,나껍 치유 +20%
    { key = "lotg", nodeId = 100175 },                  -- Lore of the Grove 숲의 전승: 회복/급성 치유량 +3%/+5%
    { key = "pon",  nodeId = 94605, entryId = 117201 }, -- Power of Nature 자연의 힘: 숲수호자 있을때 회복,꽃피,피생 +10%
    { key = "gi",   nodeId = 94595, entryId = 117189 }, -- Grove's Inspiration 숲의 감화: 재생,급속,신치 +9%
    { key = "hotg", nodeId = 94606 },                   -- Harmony of the Grove 숲의 조화: 숲수호자 있을때 회복,꽃피,피생 (1마리당) +5%
    { key = "wp",   nodeId = 94621 },                   -- Wildstalker's Power 야생추적자의 힘: 회복,꽃피,피생 +10%
    { key = "bwn",  nodeId = 94625, entryId = 117225 }, -- Bond with Nature 자연과의 유대: 받는 치유 +4%
    { key = "hc",   nodeId = 94625, entryId = 119854 }, -- Harmonious Constitution 조화로운 체질: 자신에게 거는 재생 +35%
    { key = "rn",   nodeId = 94631, entryId = 117233 }, -- Root Network 뿌리 연결망: 공생체 꽃 1개당 치유 +2%
    { key = "vc",   nodeId = 94627 },                   -- Vigorous Creepers 활력의 덩굴: 공생체 꽃 대상자에게 치유효과 +20%
    { key = "ger",  nodeId = 82071 },
    { key = "sotf", nodeId = 82059 },
    { key = "hb",   nodeId = 82065 },
    { key = "ni",   nodeId = 82214 }, -- 회복의 본능: 주문/치유력 +3%/+6%
    { key = "nr",   nodeId = 82206 }, -- 자연 회복: 받는 치유 +4%
    { key = "rlfn", nodeId = 82207 }, -- 떠오르는 빛, 몰락하는 밤: 낮 주문/치유 +3%, 밤 유연 +2%
    { key = "fw",   nodeId = 92229 },
    { key = "rg",   nodeId = 82058 },
    { key = "nss",  nodeId = 82051 },
    { key = "sb",   nodeId = 82081 },
    { key = "re",   nodeId = 82062 },
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
    -- https://www.wowhead.com/ko/spell=137012/%ED%9A%8C%EB%B3%B5-%EB%93%9C%EB%A3%A8%EC%9D%B4%EB%93%9C
    -- 회복,급속 +12%
    -- 재생 +37%
    -- 회복 주기치유 +135%
    -- 재생 주기치유 +37%
    -- 급속 주기치유 +61%

    if spellId == spell.rejuvenation or spellId == spell.germination then
        -- https://www.wowhead.com/ko/spell=774/%ED%9A%8C%EB%B3%B5
        -- power = 0.3188889648 -- 27.608 * -7% * 15% * 8%
        -- 98.6% / 12 (24.65% / 3)
        -- 풀돌가죽으로 테스트했을때 계수는 2.352166364
        power = 0.6087994591623
    elseif spellId == spell.regrowth then
        -- https://www.wowhead.com/ko/spell=8936/%EC%9E%AC%EC%83%9D
        -- power = 1.855769616  -- 207.6% * -7% * -11% * 8%
        -- 269.88% + 51.84% / 12 (8.64% / 2)
        -- 풀돌가죽으로 테스트했을때 계수는 즉발힐 1.378553580149055 / 지속치유 1.365893872
        power = 3.87058810084128
    elseif spellId == spell.wildgrowth then
        -- https://www.wowhead.com/ko/spell=48438/%EA%B8%89%EC%86%8D-%EC%84%B1%EC%9E%A5
        -- 94.08% / 7 -- 94.08% * -7% * 15% * 8% /7 * 1.07 * 1.07 * 1.07
        -- 풀돌가죽으로 테스트했을때 계수는 1.583658323
        power = 0.2737797915057453
    end

    local talent        = player.talent

    local me            = GUID == player.GUID

    local clarity       = player.buff[spell.clarity] and 1 or 0
    local nss           = player.buff[spell.nss] and 1 or 0
    local forestwalk    = player.buff[spell.forestwalk] and 1 or 0

    local unit          = player.GUIDS[GUID].unit
    local adaptiveSwarm = player.GUIDS[GUID].buff[spell.adaptiveSwarm] and 1 or 0
    local ironbark      = player.GUIDS[GUID].buff[spell.ironbark] and 1 or 0
    local symbiotic     = player.GUIDS[GUID].buff[spell.symbioticBlooms] and 1 or 0
    local re            = 0

    if spellId == spell.rejuvenation or spellId == spell.germination then
        if talent.re > 0 then
            re = (10 - math.floor(UnitHealth(unit) / UnitHealthMax(unit) * 10))
        end
    end

    local key = string.format("S:%d I:%d M:%f V:%f to:%d sym:%d|c:%d nss:%d|me:%d ms:%d as:%d ib:%d re:%d sym:%d|fr:%d bs:%s",
        spellId, player.stat.int, player.stat.mastery, player.stat.versatility, player.totems, player.symbioticBlooms,
        clarity, nss,
        me, masteryStack, adaptiveSwarm, ironbark, re, symbiotic,
        me and player.buff[spell.frenziedRegen] and 1 or 0,
        me and player.buff[spell.barkskin] and 1 or 0
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

    if me then
        if forestwalk > 0 then
            -- inc = inc + 0.05
            estimated = estimated * 1.05
        end
        if talent.fr > 0 and player.buff[spell.frenziedRegen] then
            -- Frenzied Regeneration 광포한 재생력: 광재중에 3초간 받는 치유 +20%     -> 내가 받는 치유
            estimated = estimated * 1.2
        end
        if talent.vh > 0 then
            -- Verdant Heart 신록의 심장: 광재,나껍 치유 +20%                         -> 내가 받는 치유
            if player.buff[spell.frenziedRegen] or player.buff[spell.barkskin] then
                estimated = estimated * 1.2
            end
        end
        if talent.bwn > 0 then
            -- Bond with Nature 자연과의 유대: 받는 치유 +4%                          -> 내가 받는 치유
            estimated = estimated * 1.04
        end
        if talent.hc > 0 then
            -- Harmonious Constitution 조화로운 체질: 자신에게 거는 재생 +35%         -> 내가 받는 치유
            if spellId == spell.regrowth then
                estimated = estimated * 1.35
            end
        end
    end

    if talent.lotg > 0 then
        -- Lore of the Grove 숲의 전승: 회복/급성 치유량 +3%/+5%
        if spellId == spell.rejuvenation or spellId == spell.germination or spellId == spell.wildgrowth then
            if talent.lotg == 1 then
                estimated = estimated * 1.03
            else
                estimated = estimated * 1.05
            end
        end
    end
    if talent.gi > 0 then
        -- Grove's Inspiration 숲의 감화: 재생,급속,신치 +9%
        if spellId == spell.regrowth or spellId == spell.wildgrowth then
            estimated = estimated * 1.09
        end
    end
    if talent.wp > 0 then
        -- Wildstalker's Power 야생추적자의 힘: 회복,꽃피,피생 +10%
        if spellId == spell.rejuvenation or spellId == spell.germination then
            estimated = estimated * 1.1
        end
    end

    if talent.pon > 0 and player.totems > 0 then
        -- Power of Nature 자연의 힘: 숲수호자 있을때 회복,꽃피,피생 +10%
        if spellId == spell.rejuvenation or spellId == spell.germination then
            estimated = estimated * 1.1
        end
    end
    if talent.hotg > 0 and player.totems > 0 then
        -- Harmony of the Grove 숲의 조화: 숲수호자 있을때 회복,꽃피,피생 (1마리당) +5%
        if spellId == spell.rejuvenation or spellId == spell.germination then
            estimated = estimated * (1 + 0.05 * player.totems)
        end
    end
    if talent.rn > 0 and player.symbioticBlooms > 0 then
        -- Root Network 뿌리 연결망: 공생체 꽃 1개당 치유 +2%
        estimated = estimated * (1 + 0.02 * player.symbioticBlooms)
    end
    if talent.vc > 0 and symbiotic then
        -- Vigorous Creepers 활력의 덩굴: 공생체 꽃 대상자에게 치유효과 +20%
        estimated = estimated * 1.2
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
    for _, v in pairs(talents) do
        local nodeInfo = C_Traits.GetNodeInfo(configId, v.nodeId)
        if nodeInfo.subTreeActive == nil or nodeInfo.subTreeActive then
            if not v.entryId or (nodeInfo.activeEntry and nodeInfo.activeEntry.entryID and v.entryId == nodeInfo.activeEntry.entryID) then
                if nodeInfo.activeRank > 0 then
                    player.talent[v.key] = nodeInfo.activeRank
                end
            end
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

    if not player.GUIDS[GUID].unit or (not frameOpt.petframe and player.GUIDS[GUID].unit:match("pet")) then
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
    SPELL_AURA_APPLIED      = true,
    SPELL_AURA_APPLIED_DOSE = true,
    SPELL_AURA_REMOVED      = true,
    SPELL_AURA_REMOVED_DOSE = true,
    SPELL_AURA_REFRESH      = true,
    SPELL_PERIODIC_HEAL     = true,
    SPELL_HEAL              = true,
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

    -- 공생체 꽃 갯수 추적
    if spellId == spell.symbioticBlooms then
        if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_APPLIED_DOSE" then
            player.symbioticBlooms = player.symbioticBlooms + 1
        elseif subevent == "SPELL_AURA_REMOVED" or subevent == "SPELL_AURA_REMOVED_DOSE" then
            player.symbioticBlooms = player.symbioticBlooms - 1
        end
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
        if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_APPLIED_DOSE" or subevent == "SPELL_AURA_REFRESH" then
            if subevent ~= "SPELL_AURA_REFRESH" then
                -- 특화 stack 관련이 있나? -> 특화스택 증가
                masteryChange(destGUID, spellId, 1, frameOpt.mastery)
                buffsChanged = frameOpt.mastery and true or buffsChanged
            end
        elseif subevent == "SPELL_AURA_REMOVED" or subevent == "SPELL_AURA_REMOVED_DOSE" then
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
            -- DevTool:AddData(rate, spellId)
            player.GUIDS[destGUID].empowered[spellId] = rate
            for frame in pairs(player.GUIDS[destGUID].frame) do
                if frame.unit and UnitGUID(frame.unit) ~= destGUID then
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
        -- DevTool:AddData(rate, spellId)
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

local trackPlayerTotem = function(event, totemNo)
    local haveTotem, totemName, startTime, duration = GetTotemInfo(totemNo)
    player.totem[totemNo] = haveTotem
    player.totems = player.totems + (haveTotem and 1 or -1)
end

function mod:initMod(buffs_mod, buffs_frame_registry)
    Buffs = buffs_mod
    frame_registry = buffs_frame_registry
end

function mod:onSetBuff(buffFrame, aura, oldAura, opt)
    local parent = buffFrame:GetParent()
    if frameOpt.sotf and player.spec == 105 and parent.unit then
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
    -- DevTool:AddData(player, "player")
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
        Buffs:RegisterEvent("PLAYER_TOTEM_UPDATE", trackPlayerTotem)
    end
end

function mod:onDisable()
    Buffs:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    Buffs:UnregisterEvent("TRAIT_CONFIG_UPDATED")
    Buffs:UnregisterEvent("ENCOUNTER_END")
    Buffs:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    Buffs:UnregisterEvent("PLAYER_TOTEM_UPDATE")
    player.GUIDS = {}
    player.aura = {}
    player.buff = {}
end

function mod:rosterUpdate()
    player.GUIDS = {}
    player.aura = {}
    player.buff = {}
    player.totems = 0
    for i = 1, 3 do
        player.totem[i] = GetTotemInfo(i);
        player.totems = player.totems + (player.totem[i] and 1 or 0)
    end

    for frame, v in pairs(frame_registry) do
        v.buffs:Clear()
        v.debuffs = nil
    end
end
