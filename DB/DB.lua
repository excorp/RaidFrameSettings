--[[
    Created by Slothpala
    DB:
    Setup the default database structure for the user settings.
--]]
local _, addonTable = ...
local RaidFrameSettings = addonTable.RaidFrameSettings

local Media = LibStub("LibSharedMedia-3.0")
local fontObj = CreateFont("RaidFrameSettingsFont")

local function findFont(font)
    fontObj:SetFontObject(font)
    local filename = fontObj:GetFont()
    for fontstring, fontfile in pairs(Media.MediaTable.font) do
        if fontfile == filename then
            return fontstring, { fontObj:GetFont() }
        end
    end
    return nil
end

local defaults                                    = {
    profile = {
        Module = {
            ["*"]         = true,
            CustomScale   = false,
            AuraHighlight = false,
        },
        HealthBars = {
            Textures = {
                statusbar  = "Solid",
                powerbar   = "Solid",
                background = "Solid",
                border     = "Solid",
            },
            Colors = {
                statusbarmode = 1,
                statusbar     = { r = 1, g = 1, b = 1, a = 1 },
                background    = { r = 0.2, g = 0.2, b = 0.2, a = 1 },
                border        = { r = 0, g = 0, b = 0, a = 1 },
            },
        },
        Fonts = {
            ["**"] = {
                font       = "Friz Quadrata TT",
                fontcolor  = { r = 1, g = 1, b = 1, a = 1 },
                outline    = true,
                thick      = false,
                monochrome = false,
            },
            Name = {
                fontsize      = 12,
                useclasscolor = false,
                point         = 4,
                relativePoint = 6,
                frame         = 2,
                justifyH      = 1,
                x_offset      = 0,
                y_offset      = 0,
            },
            Status = {
                fontsize      = 14,
                useclasscolor = false,
                point         = 6,
                relativePoint = 6,
                justifyH      = 2,
                x_offset      = 0,
                y_offset      = -5,
            },
            Advanced = {
                shadowColor = { r = 0, g = 0, b = 0, a = 1 },
                x_offset = 1,
                y_offset = -1,
            },
        },
        AuraFilter = {
            Buffs = {},
            Debuffs = {},
        },
        Debuffs = {
            DebuffFramesDisplay = {
                width = 21,
                height = 21,
                cleanIcons = true,
                tooltip = false,
                increase = 1.2,
                point = 9,
                relativePoint = 3,
                xOffset = 0,
                yOffset = -18,
                orientation = 1,
                baseline = 3,
                gap = 0,
                swipe = true,
                edge = true,
                inverse = true,
                timerText = true,
                maxdebuffs = 5,
                framestrata = 5,
            },
            DurationDisplay = {
                font = "Friz Quadrata TT",
                outlinemode = 2,
                fontSize = 11,
                debuffColor = true,
                fontColor = { r = 0.8274, g = 0.8274, b = 0.8274, a = 1 },
                shadowColor = { r = 0, g = 0, b = 0, a = 1 },
                xOffsetShadow = 1,
                yOffsetShadow = -1,
                point = 1,
                relativePoint = 1,
                xOffsetFont = -3,
                yOffsetFont = 3,
            },
            StacksDisplay = {
                font = "Friz Quadrata TT",
                outlinemode = 2,
                fontSize = 12,
                fontColor = { r = 1, g = 1, b = 0, a = 1 },
                shadowColor = { r = 0, g = 0, b = 0, a = 1 },
                xOffsetShadow = 1,
                yOffsetShadow = -1,
                point = 9,
                relativePoint = 9,
                xOffsetFont = 4,
                yOffsetFont = -3,
            },
            AuraPosition = {

            },
            AuraGroup = {

            },
            Increase = {
                --[[spellID = name                ]] --
            },
            AuraFilter = {

            },
        },
        Buffs = {
            BuffFramesDisplay = {
                width = 16,
                height = 16,
                cleanIcons = true,
                tooltip = false,
                increase = 1.2,
                point = 7,
                relativePoint = 7,
                xOffset = 0,
                yOffset = 8,
                orientation = 2,
                baseline = 3,
                gap = 0,
                swipe = true,
                edge = true,
                inverse = true,
                timerText = true,
                maxbuffsAuto = false,
                maxbuffs = 5,
                framestrata = 5,
            },
            DurationDisplay = {
                font = "Friz Quadrata TT",
                outlinemode = 2,
                fontSize = 10,
                fontColor = { r = 1, g = 1, b = 1, a = 1 },
                shadowColor = { r = 0, g = 0, b = 0, a = 1 },
                xOffsetShadow = 1,
                yOffsetShadow = -1,
                point = 1,
                relativePoint = 1,
                xOffsetFont = -3,
                yOffsetFont = 3,
            },
            StacksDisplay = {
                font = "Friz Quadrata TT",
                outlinemode = 2,
                fontSize = 11,
                fontColor = { r = 0, g = 1, b = 1, a = 1 },
                shadowColor = { r = 0, g = 0, b = 0, a = 1 },
                xOffsetShadow = 1,
                yOffsetShadow = -1,
                point = 9,
                relativePoint = 9,
                xOffsetFont = 4,
                yOffsetFont = -3,
            },
            AuraPosition = {

            },
            AuraGroup = {

            },
            Increase = {
                --[[spellID = name                ]] --
            },
            AuraFilter = {

            },
        },
        AuraHighlight = {
            Config = {
                operation_mode = 1,
                useHealthBarColor = true,
                useHealthBarGlow = false,
                Curse = false,
                Disease = false,
                Magic = false,
                Poison = false,
                Bleed = false,
            },
            MissingAura = {
                classSelection = 1,
                missingAuraColor = { r = 0.8156863451004028, g = 0.5803921818733215, b = 0.658823549747467 },
                ["*"] = {
                    input_field = "",
                    spellIDs = {},
                },
            },
        },
        MinorModules = {
            RoleIcon = {
                position    = 1,
                x_offset    = 0,
                y_offset    = 0,
                scaleFactor = 1,
            },
            RaidMark = {
                point         = 4,
                relativePoint = 6,
                frame         = 2,
                x_offset      = 0,
                y_offset      = 0,
                width         = 14,
                height        = 14,
                alpha         = 1,
            },
            RangeAlpha = {
                statusbar  = 0.3,
                background = 0.2,
            },
            DispelColor = {
                curse   = { r = 0.6, g = 0.0, b = 1.0 },
                disease = { r = 0.6, g = 0.4, b = 0.0 },
                magic   = { r = 0.2, g = 0.6, b = 1.0 },
                poison  = { r = 0.0, g = 0.6, b = 0.0 },
            },
            DebuffColors = {
                Curse   = { r = 0.6, g = 0.0, b = 1.0 },
                Disease = { r = 0.6, g = 0.4, b = 0.0 },
                Magic   = { r = 0.2, g = 0.6, b = 1.0 },
                Poison  = { r = 0.0, g = 0.6, b = 0.0 },
                Bleed   = { r = 0.8, g = 0.0, b = 0.0 },
            },
            CustomScale = {
                Party = 1,
                Raid  = 1,
                Arena = 1,
            },
            Overabsorb = {
                glowAlpha = 1,
                position  = 1,
            },
            TimerTextLimit = {
                sec = 100,
                min = 570,
                hour = 34200,
            },
        },
        PorfileManagement = {
            GroupProfiles = {
                partyprofile = "Default",
                raidprofile  = "Default",
            },
        },
    },
    global = {
        GroupProfiles = {
            party = "Default",
            raid = "Default",
            arena = "Default",
            battleground = "Default",
        },
    },
}

local fontstring, font, fontheight
fontstring, font                                  = findFont("GameFontHighlightSmall")
fontheight                                        = font and font[2] or 10
defaults.profile.Fonts.Name.font                  = fontstring
defaults.profile.Fonts.Name.fontsize              = fontheight
fontstring, font                                  = findFont("GameFontDisable")
fontheight                                        = font and font[2] or 14
defaults.profile.Fonts.Status.font                = fontstring
-- defaults.profile.Fonts.Status.fontsize            = fontheight
fontstring, font                                  = findFont("NumberFontNormalSmall")
fontheight                                        = font and font[2] or 12
defaults.profile.Buffs.DurationDisplay.font       = fontstring
defaults.profile.Buffs.DurationDisplay.fontsize   = fontheight
defaults.profile.Buffs.StacksDisplay.font         = fontstring
defaults.profile.Buffs.StacksDisplay.fontsize     = fontheight
defaults.profile.Debuffs.DurationDisplay.font     = fontstring
defaults.profile.Debuffs.DurationDisplay.fontsize = fontheight
defaults.profile.Debuffs.StacksDisplay.font       = fontstring
defaults.profile.Debuffs.StacksDisplay.fontsize   = fontheight

function RaidFrameSettings:LoadDataBase()
    self.db = LibStub("AceDB-3.0"):New("RaidFrameSettingsDB", defaults, true)
    --db callbacks
    self.db.RegisterCallback(self, "OnNewProfile", "ReloadConfig")
    self.db.RegisterCallback(self, "OnProfileDeleted", "ReloadConfig")
    self.db.RegisterCallback(self, "OnProfileChanged", "ReloadConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "ReloadConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "ReloadConfig")
end

--for modules having this seperated makes it easier to iterate modules
function RaidFrameSettings:GetModuleStatus(info)
    return self.db.profile.Module[info[#info]]
end

function RaidFrameSettings:SetModuleStatus(info, value)
    self.db.profile.Module[info[#info]] = value
    --will reload the config each time the settings have been adjusted
    self:ReloadConfig()
end

--status
function RaidFrameSettings:GetStatus(info)
    return self.db.profile[info[#info - 2]][info[#info - 1]][info[#info]]
end

function RaidFrameSettings:SetStatus(info, value)
    self.db.profile[info[#info - 2]][info[#info - 1]][info[#info]] = value
    --will reload the config each time the settings have been adjusted
    local module_name = info[#info - 2] == "MinorModules" and info[#info - 1] or info[#info - 2]
    self:UpdateModule(module_name)
end

--color
function RaidFrameSettings:GetColor(info)
    return self.db.profile[info[#info - 2]][info[#info - 1]][info[#info]].r, self.db.profile[info[#info - 2]][info[#info - 1]][info[#info]].g, self.db.profile[info[#info - 2]][info[#info - 1]][info[#info]].b, self.db.profile[info[#info - 2]][info[#info - 1]][info[#info]].a
end

function RaidFrameSettings:SetColor(info, r, g, b, a)
    self.db.profile[info[#info - 2]][info[#info - 1]][info[#info]].r = r
    self.db.profile[info[#info - 2]][info[#info - 1]][info[#info]].g = g
    self.db.profile[info[#info - 2]][info[#info - 1]][info[#info]].b = b
    self.db.profile[info[#info - 2]][info[#info - 1]][info[#info]].a = a
    local module_name = info[#info - 2] == "MinorModules" and info[#info - 1] or info[#info - 2]
    if module_name == "DebuffColors" then
        if self.db.profile.Module.Debuffs then
            self:UpdateModule("Debuffs")
        end
        if self.db.profile.Module.AuraHighlight then
            self:UpdateModule("AuraHighlight")
        end
    else
        self:UpdateModule(module_name)
    end
end

function RaidFrameSettings:GetGlobal(info)
    return self.db.profile[info[#info - 2]][info[#info - 1]][info[#info]]
end

function RaidFrameSettings:SetGlobal(info, value)
    self.db.profile[info[#info - 2]][info[#info - 1]][info[#info]] = value
end
