local _, addonTable = ...
local addon = addonTable.RaidFrameSettings
addonTable.Glow = {}
local Glow = addonTable.Glow
local LCG = LibStub("LibCustomGlow-1.0")

--WoW Api
local SetScript = SetScript
local SetText = SetText
local Round = Round
--Lua
local next = next
local string_format = string.format

function Glow:Stop(actions, frame, id)
    if not frame then
        return
    end
    if not frame._rfs_glow_frame then return end
    if actions.type == "buttonOverlay" then
        LCG.ButtonGlow_Stop(frame._rfs_glow_frame)
    elseif actions.type == "Pixel" then
        LCG.PixelGlow_Stop(frame._rfs_glow_frame, id)
    elseif actions.type == "ACShine" then
        LCG.AutoCastGlow_Stop(frame._rfs_glow_frame, id)
    elseif actions.type == "Proc" then
        LCG.ProcGlow_Stop(frame._rfs_glow_frame, id)
    end
end

function Glow:Start(actions, frame, id)
    if not frame._rfs_glow_frame then
        frame._rfs_glow_frame = CreateFrame("Frame", nil, frame)
        frame._rfs_glow_frame:SetAllPoints(frame)
        frame._rfs_glow_frame:SetSize(frame:GetSize())
    end
    local glow_frame = frame._rfs_glow_frame
    if glow_frame:GetWidth() < 1 or glow_frame:GetHeight() < 1 then
        self:Stop(actions, frame)
        return
    end
    local color = actions.use_color and actions.color and { actions.color.r, actions.color.g, actions.color.b, actions.color.a } or nil
    if actions.type == "buttonOverlay" then
        LCG.ButtonGlow_Start(glow_frame, color)
    elseif actions.type == "Pixel" then
        LCG.PixelGlow_Start(
            glow_frame,
            color,
            actions.lines,
            actions.frequency,
            actions.length,
            actions.thickness,
            actions.XOffset,
            actions.YOffset,
            actions.border and true or false,
            id
        )
    elseif actions.type == "ACShine" then
        LCG.AutoCastGlow_Start(
            glow_frame,
            color,
            actions.lines,
            actions.frequency,
            actions.scale,
            actions.XOffset,
            actions.YOffset,
            id
        )
    elseif actions.type == "Proc" then
        LCG.ProcGlow_Start(glow_frame, {
            color = color,
            startAnim = actions.startAnim and true or false,
            xOffset = actions.XOffset,
            yOffset = actions.YOffset,
            duration = actions.duration or 1,
            key = id
        })
    end
end
