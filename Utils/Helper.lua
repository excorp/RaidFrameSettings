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
