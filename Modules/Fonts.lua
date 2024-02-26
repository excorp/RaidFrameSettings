--[[
    Created by Slothpala
--]]
local _, addonTable = ...
local isVanilla, isWrath, isClassic, isRetail = addonTable.isVanilla, addonTable.isWrath, addonTable.isClassic, addonTable.isRetail
local RaidFrameSettings = addonTable.RaidFrameSettings
local Fonts = RaidFrameSettings:NewModule("Fonts")
Mixin(Fonts, addonTable.hooks)
local Media = LibStub("LibSharedMedia-3.0")

local ClearAllPoints = ClearAllPoints
local SetPoint = SetPoint
local SetFont = SetFont
local SetText = SetText
local SetWidth = SetWidth
local SetJustifyH = SetJustifyH
local SetShadowColor = SetShadowColor
local SetShadowOffset = SetShadowOffset
local SetVertexColor = SetVertexColor
local GetUnitName = GetUnitName
local UnitClass = UnitClass
local GetClassColor = GetClassColor

local fontObj = CreateFont("RaidFrameSettingsFont")

local frame_registry = {}

function Fonts:OnEnable()
    local dbObj          = RaidFrameSettings.db.profile.Fonts
    --Name
    local Name           = {}
    Name.Font            = Media:Fetch("font", dbObj.Name.font)
    Name.FontSize        = dbObj.Name.fontsize
    Name.FontColor       = dbObj.Name.fontcolor
    Name.Classcolored    = dbObj.Name.useclasscolor
    --OUTLINEMODE
    local flag1          = dbObj.Name.thick and "THICK" or ""
    local flag2          = dbObj.Name.outline and "OUTLINE" or ""
    local flag3          = dbObj.Name.monochrome and "MONOCHROME" or ""
    Name.Outlinemode     = (flag1 .. flag2 .. ", " .. flag3)
    Name.point           = RaidFrameSettings:ConvertDbNumberToPosition(dbObj.Name.point)
    Name.relativePoint   = RaidFrameSettings:ConvertDbNumberToPosition(dbObj.Name.relativePoint)
    Name.frame           = dbObj.Name.frame
    Name.JustifyH        = (dbObj.Name.justifyH == 1 and "LEFT") or (dbObj.Name.justifyH == 2 and "CENTER") or (dbObj.Name.justifyH == 3 and "RIGHT")
    Name.X_Offset        = dbObj.Name.x_offset
    Name.Y_Offset        = dbObj.Name.y_offset
    --Status
    local Status         = {}
    Status.Font          = Media:Fetch("font", dbObj.Status.font)
    Status.FontSize      = dbObj.Status.fontsize
    Status.FontColor     = dbObj.Status.fontcolor
    Status.Classcolored  = dbObj.Status.useclasscolor
    --OUTLINEMODE
    local flag1          = dbObj.Status.thick and "THICK" or ""
    local flag2          = dbObj.Status.outline and "OUTLINE" or ""
    local flag3          = dbObj.Status.monochrome and "MONOCHROME" or ""
    Status.Outlinemode   = (flag1 .. flag2 .. ", " .. flag3)
    Status.point         = RaidFrameSettings:ConvertDbNumberToPosition(dbObj.Status.point)
    Status.relativePoint = RaidFrameSettings:ConvertDbNumberToPosition(dbObj.Status.relativePoint)
    Status.JustifyH      = (dbObj.Status.justifyH == 1 and "LEFT") or (dbObj.Status.justifyH == 2 and "CENTER") or (dbObj.Status.justifyH == 3 and "RIGHT")
    Status.X_Offset      = dbObj.Status.x_offset
    Status.Y_Offset      = dbObj.Status.y_offset
    --Advanced Font Settings
    local Advanced       = {}
    Advanced.shadowColor = dbObj.Advanced.shadowColor
    Advanced.x_offset    = dbObj.Advanced.x_offset
    Advanced.y_offset    = dbObj.Advanced.y_offset
    --Callbacks
    local function UpdateFont(frame)
        if not frame_registry[frame] then
            frame_registry[frame] = true
        end
        --Name
        frame.name:ClearAllPoints()
        local res = frame.name:SetFont(Name.Font, Name.FontSize, Name.Outlinemode)
        if not res then
            fontObj:SetFontObject("GameFontHighlightSmall")
            frame.name:SetFont(fontObj:GetFont())
        end
        local parent = (Name.frame == 3 and frame.raidmark) or (Name.frame == 2 and frame.roleIcon) or frame
        frame.name:SetWidth((frame:GetWidth()))
        frame.name:SetJustifyH(Name.JustifyH)
        frame.name:SetPoint(Name.point, parent, Name.relativePoint, Name.X_Offset, Name.Y_Offset)
        frame.name:SetShadowColor(Advanced.shadowColor.r, Advanced.shadowColor.g, Advanced.shadowColor.b, Advanced.shadowColor.a)
        frame.name:SetShadowOffset(Advanced.x_offset, Advanced.y_offset)
        --Status
        frame.statusText:ClearAllPoints()
        res = frame.statusText:SetFont(Status.Font, Status.FontSize, Status.Outlinemode)
        if not res then
            fontObj:SetFontObject("GameFontDisable")
            frame.statusText:SetFont(fontObj:GetFont())
        end
        frame.statusText:SetWidth((frame:GetWidth()))
        frame.statusText:SetJustifyH(Status.JustifyH)
        frame.statusText:SetPoint(Status.point, frame, Status.relativePoint, Status.X_Offset, Status.Y_Offset)
        frame.statusText:SetVertexColor(Status.FontColor.r, Status.FontColor.g, Status.FontColor.b)
        frame.statusText:SetShadowColor(Advanced.shadowColor.r, Advanced.shadowColor.g, Advanced.shadowColor.b, Advanced.shadowColor.a)
        frame.statusText:SetShadowOffset(Advanced.x_offset, Advanced.y_offset)
    end
    self:HookFuncFiltered("DefaultCompactUnitFrameSetup", UpdateFont)
    --
    local UpdateNameCallback
    if Name.Classcolored then
        UpdateNameCallback = function(frame)
            local name = GetUnitName(frame.unit or "", true)
            if not name then return end
            local fname = frame:GetName()
            if frame.unit and frame.unitExists and fname and not fname:match("Pet") then
                local _, englishClass = UnitClass(frame.unit)
                local r, g, b = GetClassColor(englishClass)
                frame.name:SetVertexColor(r, g, b)
            else
                frame.name:SetVertexColor(Name.FontColor.r, Name.FontColor.g, Name.FontColor.b)
            end
            frame.name:SetText(name:match("[^-]+")) --hides the units server.
        end
    else
        UpdateNameCallback = function(frame)
            local name = GetUnitName(frame.unit or "", true)
            if not name then return end
            frame.name:SetVertexColor(Name.FontColor.r, Name.FontColor.g, Name.FontColor.b)
            frame.name:SetText(name:match("[^-]+")) --hides the units server.
        end
    end
    self:HookFuncFiltered("CompactUnitFrame_UpdateName", UpdateNameCallback)
    RaidFrameSettings:IterateRoster(function(frame)
        UpdateFont(frame)
        UpdateNameCallback(frame)
    end)
end

--parts of this code are from FrameXML/CompactUnitFrame.lua
function Fonts:OnDisable()
    local restoreFonts = function(frame)
        --Name
        fontObj:SetFontObject("GameFontHighlightSmall")
        frame.name:SetFont(fontObj:GetFont())
        frame.name:SetVertexColor(fontObj:GetTextColor())
        frame.name:SetShadowColor(fontObj:GetShadowColor())
        frame.name:SetShadowOffset(fontObj:GetShadowOffset())

        frame.name:ClearAllPoints()
        frame.name:SetPoint("TOPLEFT", frame.roleIcon, "TOPRIGHT", 0, -1);
        frame.name:SetPoint("TOPRIGHT", -3, -3);
        frame.name:SetJustifyH("LEFT");
        --Status
        fontObj:SetFontObject("GameFontDisable")
        frame.statusText:SetFont(fontObj:GetFont())
        frame.statusText:SetVertexColor(fontObj:GetTextColor())
        frame.statusText:SetShadowColor(fontObj:GetShadowColor())
        frame.statusText:SetShadowOffset(fontObj:GetShadowOffset())

        local frameWidth = frame:GetWidth()
        local frameHeight = frame:GetHeight()
        local componentScale
        if isClassic then
            local NATIVE_UNIT_FRAME_HEIGHT = 36
            local NATIVE_UNIT_FRAME_WIDTH = 72
            componentScale = min(frameHeight / NATIVE_UNIT_FRAME_HEIGHT, frameWidth / NATIVE_UNIT_FRAME_WIDTH)
        else
            componentScale = min(frameHeight / NATIVE_UNIT_FRAME_HEIGHT, frameWidth / NATIVE_UNIT_FRAME_WIDTH)
        end
        local NATIVE_FONT_SIZE = 12
        local fontName, fontSize, fontFlags = frame.statusText:GetFont();
        frame.statusText:SetFont(fontName, NATIVE_FONT_SIZE * componentScale, fontFlags)
        frame.statusText:ClearAllPoints()
        frame.statusText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 3, frameHeight / 3 - 2)
        frame.statusText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, frameHeight / 3 - 2)
        frame.statusText:SetHeight(12 * componentScale)
    end
    for frame in pairs(frame_registry) do
        restoreFonts(frame)
        frame_registry[frame] = nil
    end
end
