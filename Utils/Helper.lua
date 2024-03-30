local _, addonTable = ...
local addon = addonTable.RaidFrameSettings

--[[

]]
function addon:ConvertDbNumberToOutlinemode(number)
    local outlinemodes = {
        [1] = "NONE",
        [2] = "OUTLINE",
        [3] = "THICKOUTLINE",
        [4] = "MONOCHROME",
        [5] = "MONOCHROMEOUTLINE",
        [6] = "MONOCHROMETHICKOUTLINE",
    }
    local outlinemode = outlinemodes[number]
    return outlinemode or ""
end

function addon:ConvertDbNumberToPosition(number)
    local positions = {
        [1] = "TOPLEFT",
        [2] = "TOP",
        [3] = "TOPRIGHT",
        [4] = "LEFT",
        [5] = "CENTER",
        [6] = "RIGHT",
        [7] = "BOTTOMLEFT",
        [8] = "BOTTOM",
        [9] = "BOTTOMRIGHT",
    }
    local position = positions[number]
    return position or ""
end

function addon:ConvertDbNumberToFrameStrata(number)
    local positions = {
        [1] = "Inherited",
        [2] = "BACKGROUND",
        [3] = "LOW",
        [4] = "MEDIUM",
        [5] = "HIGH",
        [6] = "DIALOG",
        [7] = "FULLSCREEN",
        [8] = "FULLSCREEN_DIALOG",
        [9] = "TOOLTIP",
    }
    local position = positions[number]
    return position or ""
end

function addon:ConvertDbNumberToBaseline(number)
    local positions = {
        [1] = "TOP",
        [2] = "",
        [3] = "BOTTOM",
        [4] = "LEFT",
        [5] = "",
        [6] = "RIGHT",
    }
    local position = positions[number]
    return position or ""
end

--[[

]]
--number = db value for growth direction 1 = Left, 2 = Right, 3 = Up, 4 = Down, 5 Horizontal Center, 6 = Vertical Center
function addon:GetAuraGrowthOrientationPoints(number, gap, baseline)
    if baseline == nil then
        if number == 1 or number == 2 then
            baseline = "BOTTOM"
        elseif number == 3 or number == 4 then
            baseline = "LEFT"
        elseif number == 5 then
            baseline = ""
        elseif number == 6 then
            baseline = ""
        end
    end
    if gap == nil then
        gap = 0
    end
    local point, relativePoint, offsetX, offsetY
    if number == 1 then
        point = baseline .. "RIGHT"
        relativePoint = baseline .. "LEFT"
        offsetX = -gap
        offsetY = 0
    elseif number == 2 or number == 5 then
        point = baseline .. "LEFT"
        relativePoint = baseline .. "RIGHT"
        offsetX = gap
        offsetY = 0
    elseif number == 3 then
        point = "BOTTOM" .. baseline
        relativePoint = "TOP" .. baseline
        offsetX = 0
        offsetY = gap
    elseif number == 4 or number == 6 then
        point = "TOP" .. baseline
        relativePoint = "BOTTOM" .. baseline
        offsetX = 0
        offsetY = -gap
    end
    return point, relativePoint, offsetX, offsetY
end

function addon:ConvertDbNumberToGlowType(number)
    local types = {
        [1] = "buttonOverlay",
        [2] = "Pixel",
        [3] = "ACShine",
        [4] = "Proc",
    }
    return types[number] or ""
end

function addon:GetPersonalCooldowns()
    local defensives = {}
    if addonTable.isRetail then
        for _, spellId in pairs({
            --DK
            48707,  -- Anti Magic Shell
            48792,  -- Icebound Fortitude
            --DH
            212800, -- Blur
            196555, -- Netherwalk
            187827, -- Metamorphosis
            --Druid
            22812,  -- Barkskin
            200851, -- Rage of the Sleeper
            61336,  -- Survival Instincts
            --Evoker
            363916, -- Obsidian Scales
            374348, -- Renewing Blaze
            --Hunter
            186265, -- Aspect of the Turtle
            264735, -- Survival of the Fittest
            --Mage
            45438,  -- Ice Block
            342246, -- Alter Time
            113862, -- Greater Invisibility
            414658, -- Ice Cold
            --Monk
            125174, -- Touch of Karma
            122278, -- Dampen Harm
            122783, -- Diffuse Magic
            120954, -- Fortifying Brew
            --Paladin
            642,    -- Divine Shield
            31850,  -- Ardent Defender
            403876, -- Divine Protection Retri
            498,    -- Divine Protection Holy
            86659,  -- Guardian of Ancient Kings
            212641, -- Guardian of Ancient Kings + Glyph of Queens
            184662, -- Shield of Vengance
            -- Priest
            19236,  -- Desperate Prayer
            47585,  -- Dispersion
            -- Rogue
            31224,  -- Cloak of Shadows
            5277,   -- Evasion
            1966,   -- Feint
            -- Shaman
            108271, -- Astral Shift
            -- Warlock
            108416, -- Dark Pact
            104773, -- Unending Resolve
            -- Warrior
            118038, -- Die by the Sword
            184364, -- Enraged Regeneration
            12975,  -- Last Stand
            871,    -- Shield Wall
            23920,  -- Spell Reflection
        }) do
            table.insert(defensives, tostring(spellId))
        end
    elseif addonTable.isWrath then

    elseif addonTable.isVanilla then

    end
    return defensives
end

function addon:GetHealerSpellPreset(type)
    local spells = {}
    local selected = {}
    if type == "healer" then
        if addonTable.isRetail then
            selected = {
                8936,
                774,
                33763,
                188550,
                48438,
                102351,
                102352,
                391891,
                363502,
                370889,
                364343,
                355941,
                376788,
                366155,
                367364,
                373862,
                378001,
                373267,
                395296,
                395152,
                360827,
                410089,
                406732,
                406789,
                119611,
                124682,
                191840,
                235209,
                53563,
                223306,
                148039,
                156910,
                200025,
                287280,
                388013,
                388007,
                388010,
                388011,
                200654,
                139,
                41635,
                17,
                194384,
                77489,
                372847,
                974,
                383648,
                61295,
                382024,
            }
        elseif addonTable.isWrath then
        elseif addonTable.isVanilla then
        end
    elseif type == "externalDefs" then
        if addonTable.isRetail then
            selected = {
                -- DK
                51052,
                -- DH
                196718,
                -- Druid
                102342,
                -- Evoker
                374227,
                357170,
                378441,
                -- Mage
                198158,
                414660,
                -- Monk
                116849,
                202248,
                -- Paladin
                1022,
                210256,
                6940,
                228050,
                31821,
                204018,
                -- Priest
                47788,
                62618,
                33206,
                197268,
                213610,
                -- Rogue
                114018,
                -- Shaman
                383018,
                98008,
                8178,
                201633,
                -- Warrior
                213871,
                97462,
                3411,
            }
        elseif addonTable.isWrath then
        elseif addonTable.isVanilla then
        end
    elseif type == "defensives" then
        if addonTable.isRetail then
            selected = {
                -- DK
                194679,
                48707,
                55233,
                49028,
                48792,
                49039,
                -- DH
                196555,
                187827,
                198589,
                -- Druid
                22842,
                102558,
                61336,
                22812,
                200851,
                -- Evoker
                363916,
                374348,
                370960,
                -- Hunter
                186265,
                264735,
                -- Mage
                45438,
                342246,
                55342,
                414658,
                113862,
                -- Monk
                122783,
                125174,
                115203,
                115176,
                122278,
                -- Paladin
                642,
                184662,
                389539,
                205191,
                498,
                212641,
                31850,
                -- Priest
                47585,
                27827,
                193065,
                586,
                19236,
                -- Rogue
                1966,
                5277,
                31224,
                -- Shaman
                108271,
                409293,
                -- Warlock
                104773,
                108416,
                212295,
                -- Warrior
                23920,
                118038,
                184364,
                12975,
                871,
            }
        elseif addonTable.isWrath then
        elseif addonTable.isVanilla then
        end
    elseif type == "tank" then
        if addonTable.isRetail then
            selected = {
                -- DK Bone Shield
                195181,
                -- DH Demon Spikes
                203819,
                -- Druid Ironfur
                192081,
                -- Monk  Shuffle
                322120,
                -- Paladin Shield of the Righteous
                132403,
                -- Warrior Shield Block
                132404,
            }
        elseif addonTable.isWrath then
        elseif addonTable.isVanilla then
        end
    elseif type == "debuffs" then
        if addonTable.isRetail then
            selected = {
                8326,
                160029,
                255234,
                225080,
                57723,
                57724,
                80354,
                264689,
                390435,
                206151,
                195776,
                352562,
                356419,
                387847,
                213213,
            }
        elseif addonTable.isWrath then
        elseif addonTable.isVanilla then
        end
    elseif type == "bigDebuffs" then
        if addonTable.isRetail then
            selected = {
                46392,
                240443,
                209858,
                240559,
            }
        elseif addonTable.isWrath then
        elseif addonTable.isVanilla then
        end
    end

    for _, spellId in pairs(selected) do
        tinsert(spells, tostring(spellId))
    end
    return spells
end

function addon:GetSpellIdsByName(name)
    local loaded, reason = LoadAddOn("WeakAurasOptions")
    if not loaded then
        return false
    end
    return WeakAuras.spellCache.GetSpellsMatching(WeakAuras.spellCache.CorrectAuraName(name))
end

function addon:SafeToNumber(input)
    local nr = tonumber(input)
    return nr and (nr < 2147483648 and nr > -2147483649) and nr or nil
end
