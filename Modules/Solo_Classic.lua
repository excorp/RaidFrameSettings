local _, addonTable = ...
local addon = addonTable.RaidFrameSettings

local Solo = addon:NewModule("Solo")
Mixin(Solo, addonTable.hooks)

local enabled
local org_GetDisplayedAllyFrames = GetDisplayedAllyFrames
function GetDisplayedAllyFrames()
    if enabled then
        return "raid"
    end
    return org_GetDisplayedAllyFrames()
end

function Solo:Refresh()
    local c = GetCVar("cameraDistanceMaxZoomFactor")
    if c ~= "1" then
        SetCVar("cameraDistanceMaxZoomFactor", 1)
    else
        SetCVar("cameraDistanceMaxZoomFactor", 1.1)
    end
    SetCVar("cameraDistanceMaxZoomFactor", c)
end

function Solo:OnEnable()
    enabled = true
    self:Refresh()
end

function Solo:OnDisable()
    enabled = false
    self:Refresh()
end
