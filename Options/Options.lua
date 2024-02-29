--[[
    Created by Slothpala
    Options:
    Create an options table for the GUI
--]]
local addonName, addonTable                   = ...
local isVanilla, isWrath, isClassic, isRetail = addonTable.isVanilla, addonTable.isWrath, addonTable.isClassic, addonTable.isRetail
local RaidFrameSettings                       = addonTable.RaidFrameSettings
local L                                       = LibStub('AceLocale-3.0'):GetLocale(addonName)
local Media                                   = LibStub("LibSharedMedia-3.0")
local lastEntry                               = 10
local HealthBars_disabled                     = function() return not RaidFrameSettings.db.profile.Module.HealthBars end
local Fonts_disabled                          = function() return not RaidFrameSettings.db.profile.Module.Fonts end
local RoleIcon_disabled                       = function() return not RaidFrameSettings.db.profile.Module.RoleIcon end
local RaidMark_disabled                       = function() return not RaidFrameSettings.db.profile.Module.RaidMark end
local Range_disabled                          = function() return not RaidFrameSettings.db.profile.Module.RangeAlpha end
local AuraFilter_disabled                     = function() return not RaidFrameSettings.db.profile.Module.AuraFilter end
local Buffs_disabled                          = function() return not RaidFrameSettings.db.profile.Module.Buffs end
local Debuffs_disabled                        = function() return not RaidFrameSettings.db.profile.Module.Debuffs end
local AuraHighlight_disabled                  = function() return not RaidFrameSettings.db.profile.Module.AuraHighlight end
local CustomScale_disabled                    = function() return not RaidFrameSettings.db.profile.Module.CustomScale end
local Overabsorb_disabled                     = function() return not RaidFrameSettings.db.profile.Module.Overabsorb end

--LibDDI-1.0
local statusbars                              = LibStub("LibSharedMedia-3.0"):List("statusbar")

--[[
    tmp locals
]]

local function getFontOptions()
    local font_options = {
        font = {
            order = 1,
            type = "select",
            dialogControl = "LSM30_Font",
            name = L["Font"],
            values = Media:HashTable("font"),
            get = "GetStatus",
            set = "SetStatus",
        },
        outlinemode = {
            order = 2,
            name = L["Outlinemode"],
            type = "select",
            values = { L["None"], L["Outline"], L["Thick Outline"], L["Monochrome"], L["Monochrome Outline"], L["Monochrome Thick Outline"] },
            sorting = { 1, 2, 3, 4, 5, 6 },
            get = "GetStatus",
            set = "SetStatus",
        },
        newline = {
            order = 3,
            type = "description",
            name = "",
        },
        fontSize = {
            order = 4,
            name = L["Font Size"],
            type = "range",
            get = "GetStatus",
            set = "SetStatus",
            min = 1,
            max = 40,
            step = 1,
        },
        fontColor = {
            order = 5,
            type = "color",
            name = L["Font Color"],
            get = "GetColor",
            set = "SetColor",
            width = 0.8,
        },
        shadowColor = {
            order = 6,
            type = "color",
            name = L["Shadow Color"],
            get = "GetColor",
            set = "SetColor",
            hasAlpha = true,
            width = 0.8,
        },
        xOffsetShadow = {
            order = 7,
            name = L["Shadow x-offset"],
            type = "range",
            get = "GetStatus",
            set = "SetStatus",
            softMin = -4,
            softMax = 4,
            step = 0.1,
            width = 0.8,
        },
        yOffsetShadow = {
            order = 8,
            name = L["Shadow y-offset"],
            type = "range",
            get = "GetStatus",
            set = "SetStatus",
            softMin = -4,
            softMax = 4,
            step = 0.1,
            width = 0.8,
        },
        newline2 = {
            order = 9,
            type = "description",
            name = "",
        },
        point = {
            order = 10,
            name = L["Anchor"],
            type = "select",
            values = { L["Top Left"], L["Top"], L["Top Right"], L["Left"], L["Center"], L["Right"], L["Bottom Left"], L["Bottom"], L["Bottom Right"] },
            sorting = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
            get = "GetStatus",
            set = "SetStatus",
        },
        relativePoint = {
            order = 11,
            name = L["to Frames"],
            type = "select",
            values = { L["Top Left"], L["Top"], L["Top Right"], L["Left"], L["Center"], L["Right"], L["Bottom Left"], L["Bottom"], L["Bottom Right"] },
            sorting = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
            get = "GetStatus",
            set = "SetStatus",
        },
        xOffsetFont = {
            order = 12,
            name = L["x - offset"],
            type = "range",
            get = "GetStatus",
            set = "SetStatus",
            softMin = -25,
            softMax = 25,
            step = 1,
            width = 0.8,
        },
        yOffsetFont = {
            order = 13,
            name = L["y - offset"],
            type = "range",
            get = "GetStatus",
            set = "SetStatus",
            softMin = -25,
            softMax = 25,
            step = 1,
            width = 0.8,
        },
    }
    return font_options
end


local function getDebuffDurationOptions()
    local options = getFontOptions()
    options.debuffColor = {
        order = 4.1,
        name = L["Debuff Colored"],
        type = "toggle",
        get = "GetStatus",
        set = "SetStatus",
        width = 0.8,
    }
    return options
end

local profiles = {}
local options
options = {
    name = L["Raid Frame Settings"],
    handler = RaidFrameSettings,
    type = "group",
    childGroups = "tree",
    args = {
        Version = {
            order = 0,
            name = "@project-version@",
            type = "group",
            disabled = true,
            args = {},
        },
        Config = {
            order = lastEntry - 1,
            name = L["Enabled Modules"],
            type = "group",
            args = {
                Modules = {
                    order = 1,
                    name = L["Modules"],
                    type = "group",
                    inline = true,
                    args = {
                        HealthBars = {
                            order = 1,
                            type = "toggle",
                            name = L["Health Bars"],
                            desc = L["Choose colors and textures for Health Bars.\n|cffF4A460CPU Impact: |r|cff00ff00LOW|r to |cffFFFF00MEDIUM|r"],
                            get = "GetModuleStatus",
                            set = "SetModuleStatus",
                        },
                        Fonts = {
                            order = 2,
                            type = "toggle",
                            name = L["Fonts"],
                            desc = L["Adjust the Font, Font Size, Font Color as well as the position for the Names and Status Texts.\n|cffF4A460CPU Impact: |r|cff00ff00LOW|r to |cffFFFF00MEDIUM|r"],
                            get = "GetModuleStatus",
                            set = "SetModuleStatus",
                        },
                        RoleIcon = {
                            hidden = isVanilla,
                            order = 3,
                            type = "toggle",
                            name = L["Role Icon"],
                            desc = L["Position the Role Icon.\n|cffF4A460CPU Impact: |r|cff00ff00LOW|r"],
                            get = "GetModuleStatus",
                            set = "SetModuleStatus",
                        },
                        RaidMark = {
                            order = 3.1,
                            type = "toggle",
                            name = L["Raid Mark"],
                            desc = L["Position the Raid Mark.\n|cffF4A460CPU Impact: |r|cff90EE90VERY LOW|r"],
                            get = "GetModuleStatus",
                            set = "SetModuleStatus",
                        },
                        RangeAlpha = {
                            order = 4,
                            type = "toggle",
                            name = L["Range"],
                            desc = L["Use custom alpha values for out of range units.\n|cffF4A460CPU Impact: |r|cff00ff00LOW|r to |r|cffFFFF00MEDIUM|r"],
                            get = "GetModuleStatus",
                            set = "SetModuleStatus",
                        },
                        AuraFilter = {
                            order = 4.1,
                            type = "toggle",
                            name = L["Aura Filter"],
                            desc = L["Sets the visibility, hiding, and priority of the aura.\n|cffF4A460CPU Impact: |r|cff00ff00LOW|r"],
                            get = "GetModuleStatus",
                            set = "SetModuleStatus",
                        },
                        Buffs = {
                            order = 5,
                            type = "toggle",
                            name = L["Buffs"],
                            desc = L["Adjust the position, orientation and size of buffs.\n|cffF4A460CPU Impact: |r|cff00ff00LOW|r to |r|cffFFFF00MEDIUM|r"],
                            get = "GetModuleStatus",
                            set = "SetModuleStatus",
                        },
                        Debuffs = {
                            order = 6,
                            type = "toggle",
                            name = L["Debuffs"],
                            desc = L["Adjust the position, orientation and size of debuffs.\n|cffF4A460CPU Impact: |r|cff00ff00LOW|r to |r|cffFFFF00MEDIUM|r"],
                            get = "GetModuleStatus",
                            set = "SetModuleStatus",
                        },
                        Overabsorb = {
                            hidden = not isRetail,
                            order = 7,
                            type = "toggle",
                            name = L["Overabsorb"],
                            desc = L["Show absorbs above the units max hp.\n|cffF4A460CPU Impact: |r|cff00ff00LOW|r"],
                            get = "GetModuleStatus",
                            set = "SetModuleStatus",
                        },
                        AuraHighlight = {
                            order = 8,
                            type = "toggle",
                            name = L["Aura Highlight"],
                            desc = L["Recolor unit health bars based on debuff type.\n|cffF4A460CPU Impact: |r|cffFFFF00MEDIUM|r to |r|cffFF474DHIGH|r"],
                            get = "GetModuleStatus",
                            set = "SetModuleStatus",
                        },
                        CustomScale = {
                            hidden = not isRetail,
                            order = 9,
                            type = "toggle",
                            name = L["Custom Scale"],
                            desc = L["Set a scaling factor for raid and party frames.\n|cffF4A460CPU Impact: |r|cff90EE90NEGLIGIBLE|r"],
                            get = "GetModuleStatus",
                            set = "SetModuleStatus",
                        },
                        Solo = {
                            order = 10,
                            type = "toggle",
                            name = L["Solo"],
                            desc = L["Use CompactParty when Solo.\n|cffF4A460CPU Impact: |r|cff90EE90VERY LOW|r"],
                            get = "GetModuleStatus",
                            set = "SetModuleStatus",
                        },
                    },
                },
                DescriptionBox = {
                    order = 2,
                    name = L["Hints:"],
                    type = "group",
                    inline = true,
                    args = {
                        description = {
                            order = 1,
                            name = L["The default UI links the name text to the right of the role icon, so in some cases you will need to use both modules if you want to use either one."],
                            fontSize = "medium",
                            type = "description",
                        },
                        newline1 = {
                            order = 1.1,
                            name = "",
                            fontSize = "medium",
                            type = "description",
                        },
                        performanceNote = {
                            order = 2,
                            name = L["About |cffF4A460CPU Impact:|r The first value means small 5 man groups, the last value massive 40 man raids. As more frames are added, the addon must do more work. The addon runs very efficiently when the frames are set up, but you can get spikes when people spam leave and/or join the group, such as at the end of a battleground or in massive open world farm groups. The blizzard frames update very often in these scenarios and the addon needs to follow this."],
                            fontSize = "medium",
                            type = "description",
                        },
                    },
                },
            },
        },
        HealthBars = {
            order = 2,
            name = L["Health Bars"],
            type = "group",
            hidden = HealthBars_disabled,
            args = {
                Textures = {
                    order = 1,
                    name = " ",
                    type = "group",
                    inline = true,
                    args = {
                        Header = {
                            order = 1,
                            type = "header",
                            name = L["Textures"],
                        },
                        statusbar = {
                            order = 2,
                            type = "select",
                            name = L["Health Bar"],
                            values = statusbars,
                            get = function()
                                for i, v in next, statusbars do
                                    if v == RaidFrameSettings.db.profile.HealthBars.Textures.statusbar then return i end
                                end
                            end,
                            set = function(_, value)
                                RaidFrameSettings.db.profile.HealthBars.Textures.statusbar = statusbars[value]
                                RaidFrameSettings:ReloadConfig()
                            end,
                            itemControl = "DDI-Statusbar",
                            width = 1.6,
                        },
                        background = {
                            order = 3,
                            type = "select",
                            name = L["Health Bar Background"],
                            values = statusbars,
                            get = function()
                                for i, v in next, statusbars do
                                    if v == RaidFrameSettings.db.profile.HealthBars.Textures.background then return i end
                                end
                            end,
                            set = function(_, value)
                                RaidFrameSettings.db.profile.HealthBars.Textures.background = statusbars[value]
                                RaidFrameSettings:ReloadConfig()
                            end,
                            itemControl = "DDI-Statusbar",
                            width = 1.6,
                        },
                        newline = {
                            order = 4,
                            type = "description",
                            name = "",
                        },
                        powerbar = {
                            order = 5,
                            type = "select",
                            name = L["Power Bar"],
                            values = statusbars,
                            get = function()
                                for i, v in next, statusbars do
                                    if v == RaidFrameSettings.db.profile.HealthBars.Textures.powerbar then return i end
                                end
                            end,
                            set = function(_, value)
                                RaidFrameSettings.db.profile.HealthBars.Textures.powerbar = statusbars[value]
                                RaidFrameSettings:ReloadConfig()
                            end,
                            itemControl = "DDI-Statusbar",
                            width = 1.6,
                        },
                        border = {
                            guiHidden = true,
                            order = 6,
                            type = "select",
                            dialogControl = "LSM30_Border",
                            name = L["Border"],
                            values = Media:HashTable("statusbar"),
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 1.6,
                        },
                    },
                },
                Colors = {
                    order = 2,
                    name = " ",
                    type = "group",
                    inline = true,
                    args = {
                        Header = {
                            order = 1,
                            type = "header",
                            name = L["Colors"],
                        },
                        statusbarmode = {
                            order = 2,
                            name = L["Health Bar"],
                            desc = L["1. - Blizzards setting for Class Colors. \n2. - Blizzards setting for a unified green color. \n3. - AddOns setting for a customizable unified color."],
                            type = "select",
                            values = { L["Blizzard - Class Color"], L["Blizzard - Green Color"], L["AddOn - Static Color"] },
                            sorting = { 1, 2, 3 },
                            get = "GetStatus",
                            set = "SetStatus",
                        },
                        statusbar = {
                            order = 2.1,
                            type = "color",
                            name = L["Health Bar"],
                            get = "GetColor",
                            set = "SetColor",
                            width = 1,
                            hidden = function()
                                if RaidFrameSettings.db.profile.HealthBars.Colors.statusbarmode == 3 then return false end; return true
                            end
                        },
                        newline = {
                            order = 3,
                            type = "description",
                            name = "",
                        },
                        background = {
                            order = 4,
                            type = "color",
                            name = L["Health Bar Background"],
                            get = "GetColor",
                            set = "SetColor",
                            width = 1,
                        },
                        newline2 = {
                            order = 5,
                            type = "description",
                            name = "",
                        },
                        border = {
                            order = 6,
                            type = "color",
                            name = L["Border"],
                            get = "GetColor",
                            set = "SetColor",
                            width = 1,
                        },
                    },
                },
            },
        },
        Fonts = {
            order = 3,
            name = L["Fonts"],
            type = "group",
            childGroups = "tab",
            hidden = Fonts_disabled,
            args = {
                Name = {
                    order = 1,
                    name = L["Name"],
                    type = "group",
                    args = {
                        font = {
                            order = 2,
                            type = "select",
                            dialogControl = "LSM30_Font",
                            name = L["Font"],
                            values = Media:HashTable("font"),
                            get = "GetStatus",
                            set = "SetStatus",
                        },
                        outline = {
                            order = 3,
                            name = L["OUTLINE"],
                            type = "toggle",
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.5,
                        },
                        thick = {
                            disabled = function() return not RaidFrameSettings.db.profile.Fonts.Name.outline end,
                            order = 3.1,
                            name = L["THICK"],
                            type = "toggle",
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.4,
                        },
                        monochrome = {
                            order = 3.2,
                            name = L["MONOCHROME"],
                            type = "toggle",
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.8,
                        },
                        newline = {
                            order = 3.3,
                            type = "description",
                            name = "",
                        },
                        fontsize = {
                            order = 4,
                            name = L["Font Size"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            min = 1,
                            max = 40,
                            step = 1,
                        },
                        useclasscolor = {
                            order = 5,
                            name = L["Class Colored"],
                            type = "toggle",
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.6,
                        },
                        fontcolor = {
                            order = 5.1,
                            type = "color",
                            name = L["Name color"],
                            get = "GetColor",
                            set = "SetColor",
                            width = 0.6,
                        },
                        fontcolorDead = {
                            order = 5.2,
                            type = "color",
                            name = L["Dead color"],
                            get = "GetColor",
                            set = "SetColor",
                            width = 0.6,
                        },
                        fontcolorHostile = {
                            order = 5.3,
                            type = "color",
                            name = L["Hostile color"],
                            get = "GetColor",
                            set = "SetColor",
                            width = 0.6,
                        },
                        newline2 = {
                            order = 6.1,
                            type = "description",
                            name = "",
                        },
                        point = {
                            order = 7,
                            name = L["Anchor"],
                            type = "select",
                            values = { L["Top Left"], L["Top"], L["Top Right"], L["Left"], L["Center"], L["Right"], L["Bottom Left"], L["Bottom"], L["Bottom Right"] },
                            sorting = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.8,
                        },
                        relativePoint = {
                            order = 7.1,
                            name = L["to Frames"],
                            type = "select",
                            values = { L["Top Left"], L["Top"], L["Top Right"], L["Left"], L["Center"], L["Right"], L["Bottom Left"], L["Bottom"], L["Bottom Right"] },
                            sorting = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.8,
                        },
                        frame = {
                            order = 7.2,
                            name = L["to Attach Frame"],
                            type = "select",
                            values = function() return RaidFrameSettings.db.profile.Module.RaidMark and { L["Unit Frame"], L["Role Icon"], L["Raid Mark"] } or { L["Unit Frame"], L["Role Icon"] } end,
                            sorting = function() return RaidFrameSettings.db.profile.Module.RaidMark and { 1, 2, 3 } or { 1, 2 } end,
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.8,
                        },
                        justifyH = {
                            order = 7.2,
                            name = L["Align"],
                            type = "select",
                            values = { L["Left"], L["Center"], L["Right"] },
                            sorting = { 1, 2, 3 },
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.8,
                        },
                        newline3 = {
                            order = 7.3,
                            type = "description",
                            name = "",
                        },
                        x_offset = {
                            order = 8,
                            name = L["x - offset"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            softMin = -25,
                            softMax = 25,
                            step = 1,
                            width = 0.8,
                        },
                        y_offset = {
                            order = 9,
                            name = L["y - offset"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            softMin = -25,
                            softMax = 25,
                            step = 1,
                            width = 0.8,
                        },
                    },
                },
                Status = {
                    order = 2,
                    name = L["Status"],
                    type = "group",
                    args = {
                        font = {
                            order = 2,
                            type = "select",
                            dialogControl = "LSM30_Font",
                            name = L["Font"],
                            values = Media:HashTable("font"),
                            get = "GetStatus",
                            set = "SetStatus",
                        },
                        outline = {
                            order = 3,
                            name = L["OUTLINE"],
                            type = "toggle",
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.5,
                        },
                        thick = {
                            disabled = function() return not RaidFrameSettings.db.profile.Fonts.Status.outline end,
                            order = 3.1,
                            name = L["THICK"],
                            type = "toggle",
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.4,
                        },
                        monochrome = {
                            order = 3.2,
                            name = L["MONOCHROME"],
                            type = "toggle",
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.8,
                        },
                        newline = {
                            order = 3.3,
                            type = "description",
                            name = "",
                        },
                        fontsize = {
                            order = 4,
                            name = L["Font Size"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            min = 1,
                            max = 40,
                            step = 1,
                        },
                        fontcolor = {
                            order = 6,
                            type = "color",
                            name = L["Status color"],
                            get = "GetColor",
                            set = "SetColor",
                            width = 0.8,
                        },
                        newline2 = {
                            order = 6.1,
                            type = "description",
                            name = "",
                        },
                        point = {
                            order = 7,
                            name = L["Anchor"],
                            type = "select",
                            values = { L["Top Left"], L["Top"], L["Top Right"], L["Left"], L["Center"], L["Right"], L["Bottom Left"], L["Bottom"], L["Bottom Right"] },
                            sorting = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.8,
                        },
                        relativePoint = {
                            order = 7.1,
                            name = L["to Frames"],
                            type = "select",
                            values = { L["Top Left"], L["Top"], L["Top Right"], L["Left"], L["Center"], L["Right"], L["Bottom Left"], L["Bottom"], L["Bottom Right"] },
                            sorting = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.8,
                        },
                        justifyH = {
                            order = 7.2,
                            name = L["Align"],
                            type = "select",
                            values = { L["Left"], L["Center"], L["Right"] },
                            sorting = { 1, 2, 3 },
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.8,
                        },
                        newline3 = {
                            order = 7.3,
                            type = "description",
                            name = "",
                        },
                        x_offset = {
                            order = 8,
                            name = L["x - offset"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            softMin = -25,
                            softMax = 25,
                            step = 1,
                            width = 0.8,
                        },
                        y_offset = {
                            order = 9,
                            name = L["y - offset"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            softMin = -25,
                            softMax = 25,
                            step = 1,
                            width = 0.8,
                        },
                    },
                },
                Advanced = {
                    order = 3,
                    name = L["Advanced"],
                    type = "group",
                    args = {
                        shadowColor = {
                            order = 2,
                            type = "color",
                            name = L["Shadow Color"],
                            get = "GetColor",
                            set = "SetColor",
                            hasAlpha = true,
                            width = 0.8,
                        },
                        x_offset = {
                            order = 3,
                            name = L["Shadow x-offset"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            softMin = -4,
                            softMax = 4,
                            step = 0.1,
                            width = 0.8,
                        },
                        y_offset = {
                            order = 4,
                            name = L["Shadow y-offset"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            softMin = -4,
                            softMax = 4,
                            step = 0.1,
                            width = 0.8,
                        },
                    },
                },
            },
        },
        AuraFilter = {
            order = 4,
            name = L["Aura Filter"],
            type = "group",
            hidden = AuraFilter_disabled,
            childGroups = "tab",
            args = {
                Buffs = {
                    order = 1,
                    name = L["Buffs"],
                    type = "group",
                    args = {
                        addAura = {
                            order = 1,
                            name = L["Enter spellId:"],
                            desc = "",
                            type = "input",
                            width = 1.5,
                            pattern = "^%d+$",
                            usage = L["please enter a number"],
                            set = function(_, value)
                                RaidFrameSettings.db.profile.AuraFilter.Buffs[value] = {
                                    spellId = tonumber(value),
                                    show = false,
                                    other = false,
                                    hideInCombat = false,
                                    priority = 0,
                                    glow = false,
                                }
                                RaidFrameSettings:CreateAuraFilterEntry(value, "Buffs")
                                RaidFrameSettings:UpdateModule("Buffs")
                            end,
                        },
                        FilteredAuras = {
                            order = 4,
                            name = L["Filtered Auras:"],
                            type = "group",
                            inline = true,
                            args = {

                            },
                        },
                    },
                },
                Debuffs = {
                    order = 2,
                    name = L["Debuffs"],
                    type = "group",
                    args = {
                        addAura = {
                            order = 1,
                            name = L["Enter spellId:"],
                            desc = "",
                            type = "input",
                            width = 1.5,
                            pattern = "^%d+$",
                            usage = L["please enter a number"],
                            set = function(_, value)
                                RaidFrameSettings.db.profile.AuraFilter.Debuffs[value] = {
                                    spellId = tonumber(value),
                                    show = false,
                                    other = false,
                                    hideInCombat = false,
                                    priority = 0,
                                    glow = false,
                                }
                                RaidFrameSettings:CreateAuraFilterEntry(value, "Debuffs")
                                RaidFrameSettings:UpdateModule("Debuffs")
                            end,
                        },
                        FilteredAuras = {
                            order = 4,
                            name = L["Filtered Auras:"],
                            type = "group",
                            inline = true,
                            args = {

                            },
                        },
                    },
                },
            }
        },
        Auras = {
            order = 5,
            name = L["Auras"],
            type = "group",
            childGroups = "select",
            hidden = function()
                return not RaidFrameSettings.db.profile.Module.Buffs and not RaidFrameSettings.db.profile.Module.Debuffs
            end,
            args = {
                Buffs = {
                    hidden = Buffs_disabled,
                    order = 1,
                    name = L["Buffs"],
                    type = "group",
                    childGroups = "tab",
                    args = {
                        Buffs = { --name of the group is a workaround to not have several Set/Get functions just for that
                            order = 1,
                            name = L["Display"],
                            type = "group",
                            childGroups = "tab",
                            args = {
                                BuffFramesDisplay = {
                                    order = 1,
                                    name = L["Buff Frames"],
                                    type = "group",
                                    args = {
                                        width = {
                                            order = 1,
                                            name = L["width"],
                                            type = "range",
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            min = 1,
                                            max = 50,
                                            step = 1,
                                            width = 1,
                                        },
                                        height = {
                                            order = 2,
                                            name = L["height"],
                                            type = "range",
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            min = 1,
                                            max = 50,
                                            step = 1,
                                            width = 1,
                                        },
                                        increase = {
                                            order = 2.1,
                                            name = L["Aura Increase"],
                                            desc = L["This will increase the size of the auras added in the \34Increase\34 section."],
                                            type = "range",
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            min = 1,
                                            max = 2,
                                            step = 0.1,
                                            width = 1,
                                            isPercent = true,
                                        },
                                        cleanIcons = {
                                            order = 2.2,
                                            type = "toggle",
                                            name = L["Clean Icons"],
                                            -- and replace it with a 1pixel border #later
                                            desc = L["Crop the border. Keep the aspect ratio of icons when width is not equal to height."],
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            width = 0.6,
                                        },
                                        tooltip = {
                                            hidden = function() return isClassic end,
                                            order = 2.3,
                                            type = "toggle",
                                            name = L["Show Tooltip"],
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            width = 0.5,
                                        },
                                        newline = {
                                            order = 3,
                                            name = "",
                                            type = "description",
                                        },
                                        point = {
                                            order = 4,
                                            name = L["Buffframe anchor"],
                                            type = "select",
                                            values = { L["Top Left"], L["Top"], L["Top Right"], L["Left"], L["Center"], L["Right"], L["Bottom Left"], L["Bottom"], L["Bottom Right"] },
                                            sorting = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
                                            get = "GetStatus",
                                            set = "SetStatus",
                                        },
                                        relativePoint = {
                                            order = 5,
                                            name = L["to Frames"],
                                            type = "select",
                                            values = { L["Top Left"], L["Top"], L["Top Right"], L["Left"], L["Center"], L["Right"], L["Bottom Left"], L["Bottom"], L["Bottom Right"] },
                                            sorting = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
                                            get = "GetStatus",
                                            set = "SetStatus",
                                        },
                                        orientation = {
                                            order = 6,
                                            name = L["Directions for growth"],
                                            type = "select",
                                            values = { L["Left"], L["Right"], L["Up"], L["Down"] },
                                            sorting = { 1, 2, 3, 4 },
                                            get = function()
                                                local orientation = RaidFrameSettings.db.profile.Buffs.BuffFramesDisplay.orientation
                                                local baselineObj = options.args.Auras.args.Buffs.args.Buffs.args.BuffFramesDisplay.args.baseline
                                                if orientation == 1 or orientation == 2 then
                                                    baselineObj.values = { L["Top"], L["Middle"], L["Bottom"] }
                                                elseif orientation == 3 or orientation == 4 then
                                                    baselineObj.values = { L["Left"], L["Center"], L["Right"] }
                                                end
                                                return RaidFrameSettings.db.profile.Buffs.BuffFramesDisplay.orientation
                                            end,
                                            set = function(_, value)
                                                RaidFrameSettings.db.profile.Buffs.BuffFramesDisplay.orientation = value
                                                local baseline = RaidFrameSettings.db.profile.Buffs.BuffFramesDisplay.baseline
                                                if value == 1 or value == 2 then
                                                    if baseline >= 4 then
                                                        RaidFrameSettings.db.profile.Buffs.BuffFramesDisplay.baseline = 3
                                                    end
                                                elseif value == 3 or value == 4 then
                                                    if baseline <= 3 then
                                                        RaidFrameSettings.db.profile.Buffs.BuffFramesDisplay.baseline = 4
                                                    end
                                                end
                                                RaidFrameSettings:UpdateModule("Buffs")
                                            end,
                                            width = 0.8,
                                        },
                                        baseline = {
                                            order = 6.1,
                                            name = L["Baseline"],
                                            type = "select",
                                            values = { "Top/Left", "Middle/Center", "Bottom/Right" },
                                            sorting = { 1, 2, 3 },
                                            get = function()
                                                local baseline = RaidFrameSettings.db.profile.Buffs.BuffFramesDisplay.baseline
                                                return RaidFrameSettings.db.profile.Buffs.BuffFramesDisplay.orientation >= 3 and (baseline - 3) or baseline
                                            end,
                                            set = function(_, value)
                                                RaidFrameSettings.db.profile.Buffs.BuffFramesDisplay.baseline = RaidFrameSettings.db.profile.Buffs.BuffFramesDisplay.orientation >= 3 and (value + 3) or value
                                                RaidFrameSettings:UpdateModule("Buffs")
                                            end,
                                            width = 0.8,
                                        },
                                        newline2 = {
                                            order = 7,
                                            name = "",
                                            type = "description",
                                        },
                                        xOffset = {
                                            order = 8,
                                            name = L["x - offset"],
                                            type = "range",
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            softMin = -100,
                                            softMax = 100,
                                            step = 1,
                                            width = 1.4,
                                        },
                                        yOffset = {
                                            order = 9,
                                            name = L["y - offset"],
                                            type = "range",
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            softMin = -100,
                                            softMax = 100,
                                            step = 1,
                                            width = 1.4,
                                        },
                                        gap = {
                                            order = 9.1,
                                            name = L["Gap"],
                                            type = "range",
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            softMin = -10,
                                            softMax = 10,
                                            step = 1,
                                            width = 0.8,
                                        },
                                        newline3 = {
                                            order = 10,
                                            name = "",
                                            type = "description",
                                        },
                                        swipe = {
                                            order = 11,
                                            type = "toggle",
                                            name = L["Show \"Swipe\""],
                                            desc = L["Show the swipe radial overlay"],
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            width = 0.8,
                                        },
                                        edge = {
                                            order = 12,
                                            type = "toggle",
                                            name = L["Show \"Edge\""],
                                            desc = L["Show the glowing edge at the end of the radial overlay"],
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            width = 0.8,
                                        },
                                        inverse = {
                                            order = 13,
                                            type = "toggle",
                                            name = L["Inverse"],
                                            desc = L["Invert the direction of the radial overlay"],
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            width = 0.6,
                                        },
                                        timerText = {
                                            order = 14,
                                            type = "toggle",
                                            name = L["Show Duration Timer Text"],
                                            desc = L["Enabling this will display an aura duration timer. When the OmniCC add-on is loaded, it's cooldown timer will be hidden."],
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            width = 1.2,
                                        },
                                        newline4 = {
                                            order = 40,
                                            name = "",
                                            type = "description",
                                        },
                                        maxbuffsAuto = {
                                            order = 41,
                                            name = L["Auto Max buffes"],
                                            type = "toggle",
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            width = 0.9,
                                        },
                                        maxbuffs = {
                                            disabled = function() return RaidFrameSettings.db.profile.Buffs.BuffFramesDisplay.maxbuffsAuto end,
                                            order = 42,
                                            name = L["Max buffes"],
                                            type = "range",
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            min = 0,
                                            softMin = 3,
                                            softMax = 10,
                                            step = 1,
                                            width = 0.9,
                                        },
                                        framestrata = {
                                            order = 43,
                                            name = L["Frame Strata"],
                                            type = "select",
                                            values = { L["Inherited"], L["BACKGROUND"], L["LOW"], L["MEDIUM"], L["HIGH"], L["DIALOG"], L["FULLSCREEN"], L["FULLSCREEN_DIALOG"], L["TOOLTIP"] },
                                            sorting = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
                                            get = "GetStatus",
                                            set = "SetStatus",
                                        },
                                    },
                                },
                                DurationDisplay = {
                                    order = 2,
                                    name = L["Duration"],
                                    type = "group",
                                    args = getFontOptions()
                                },
                                StacksDisplay = {
                                    order = 3,
                                    name = L["Stacks"],
                                    type = "group",
                                    args = getFontOptions()
                                },
                            },
                        },
                        Increase = {
                            order = 2,
                            name = L["Increase"],
                            desc = L["Set up auras to a big aura like a boss aura."],
                            type = "group",
                            args = {
                                addAura = {
                                    order = 1,
                                    name = L["Enter spellId:"],
                                    desc = "",
                                    type = "input",
                                    width = 1.5,
                                    pattern = "^%d+$",
                                    usage = L["please enter a number"],
                                    set = function(_, value)
                                        RaidFrameSettings.db.profile.Buffs.Increase[value] = true
                                        RaidFrameSettings:CreateIncreaseEntry(value, "Buffs")
                                        RaidFrameSettings:UpdateModule("Buffs")
                                    end,
                                },
                                IncreasedAuras = {
                                    order = 4,
                                    name = L["Increase:"],
                                    type = "group",
                                    inline = true,
                                    args = {

                                    },
                                },
                            },
                        },
                        AuraPosition = {
                            order = 3,
                            name = L["Aura Position"],
                            type = "group",
                            childGroups = "tab",
                            args = {
                                addGroup = {
                                    order = 1,
                                    name = L["New Group"],
                                    type = "execute",
                                    func = function()
                                        local dbObjGroup = RaidFrameSettings.db.profile["Buffs"].AuraGroup
                                        tinsert(dbObjGroup, {
                                            name = "",
                                            point = 1,
                                            relativePoint = 1,
                                            frame = 1,
                                            frameNo = 0,
                                            frameSelect = 1,
                                            frameManualSelect = 1,
                                            unlimitAura = true,
                                            maxAuras = 1,
                                            xOffset = 0,
                                            yOffset = 0,
                                            orientation = 2,
                                            gap = 0,
                                            setSize = false,
                                            width = RaidFrameSettings.db.profile.Buffs.BuffFramesDisplay.width,
                                            height = RaidFrameSettings.db.profile.Buffs.BuffFramesDisplay.height,
                                            auraList = {},
                                        })
                                        local groupNo = #dbObjGroup
                                        dbObjGroup[groupNo].name = L["Group "] .. groupNo
                                        RaidFrameSettings:CreateAuraGroup(groupNo, "Buffs")
                                        RaidFrameSettings:UpdateModule("Buffs")
                                    end,
                                    width = 1,
                                },
                                auraGroup = {
                                    order = 2,
                                    name = L["Aura Position"],
                                    type = "group",
                                    args = {
                                        addAura = {
                                            order = 1,
                                            name = L["Enter spellId:"],
                                            type = "input",
                                            pattern = "^%d+$",
                                            usage = L["please enter a number"],
                                            set = function(_, value)
                                                RaidFrameSettings.db.profile.Buffs.AuraPosition[value] = {
                                                    ["spellId"] = tonumber(value),
                                                    point = 1,
                                                    relativePoint = 1,
                                                    frame = 1,
                                                    frameNo = 0,
                                                    frameSelect = 1,
                                                    frameManualSelect = 1,
                                                    xOffset = 0,
                                                    yOffset = 0,
                                                    setSize = false,
                                                    width = RaidFrameSettings.db.profile.Buffs.BuffFramesDisplay.width,
                                                    height = RaidFrameSettings.db.profile.Buffs.BuffFramesDisplay.height,
                                                    glow = RaidFrameSettings.db.profile.AuraFilter.Buffs[value] and RaidFrameSettings.db.profile.AuraFilter.Buffs[value].glow,
                                                }
                                                RaidFrameSettings:CreateAuraPositionEntry(value, "Buffs")
                                                RaidFrameSettings:UpdateModule("Buffs")
                                            end
                                        },
                                        auraList = {
                                            order = 2,
                                            name = "",
                                            type = "group",
                                            inline = true,
                                            args = {

                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
                Debuffs = {
                    hidden = Debuffs_disabled,
                    order = 2,
                    name = L["Debuffs"],
                    type = "group",
                    childGroups = "tab",
                    args = {
                        Debuffs = {
                            order = 1,
                            name = L["Display"],
                            type = "group",
                            childGroups = "tab",
                            args = {
                                DebuffFramesDisplay = {
                                    order = 1,
                                    name = L["Debuff Frames"],
                                    type = "group",
                                    args = {
                                        width = {
                                            order = 1,
                                            name = L["width"],
                                            type = "range",
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            min = 1,
                                            max = 50,
                                            step = 1,
                                            width = 1,
                                        },
                                        height = {
                                            order = 2,
                                            name = L["height"],
                                            type = "range",
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            min = 1,
                                            max = 50,
                                            step = 1,
                                            width = 1,
                                        },
                                        increase = {
                                            order = 2.1,
                                            name = L["Aura Increase"],
                                            desc = L["This will increase the size of \34Boss Auras\34 and the auras added in the \34Increase\34 section. Boss Auras are auras that the game deems to be more important by default."],
                                            type = "range",
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            min = 1,
                                            max = 2,
                                            step = 0.1,
                                            width = 1,
                                            isPercent = true,
                                        },
                                        cleanIcons = {
                                            order = 2.2,
                                            type = "toggle",
                                            name = L["Clean Icons"],
                                            desc = L["Crop the border. Keep the aspect ratio of icons when width is not equal to height."],
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            width = 0.6,
                                        },
                                        tooltip = {
                                            hidden = function() return isClassic end,
                                            order = 2.3,
                                            type = "toggle",
                                            name = L["Show Tooltip"],
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            width = 0.5,
                                        },
                                        newline = {
                                            order = 3,
                                            name = "",
                                            type = "description",
                                        },
                                        point = {
                                            order = 4,
                                            name = L["Debuffframe anchor"],
                                            type = "select",
                                            values = { L["Top Left"], L["Top"], L["Top Right"], L["Left"], L["Center"], L["Right"], L["Bottom Left"], L["Bottom"], L["Bottom Right"] },
                                            sorting = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
                                            get = "GetStatus",
                                            set = "SetStatus",
                                        },
                                        relativePoint = {
                                            order = 5,
                                            name = L["to Frames"],
                                            type = "select",
                                            values = { L["Top Left"], L["Top"], L["Top Right"], L["Left"], L["Center"], L["Right"], L["Bottom Left"], L["Bottom"], L["Bottom Right"] },
                                            sorting = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
                                            get = "GetStatus",
                                            set = "SetStatus",
                                        },
                                        orientation = {
                                            order = 6,
                                            name = L["Directions for growth"],
                                            type = "select",
                                            values = { L["Left"], L["Right"], L["Up"], L["Down"] },
                                            sorting = { 1, 2, 3, 4 },
                                            get = function()
                                                local orientation = RaidFrameSettings.db.profile.Debuffs.DebuffFramesDisplay.orientation
                                                local baselineObj = options.args.Auras.args.Debuffs.args.Debuffs.args.DebuffFramesDisplay.args.baseline
                                                if orientation == 1 or orientation == 2 then
                                                    baselineObj.values = { L["Top"], L["Middle"], L["Bottom"] }
                                                elseif orientation == 3 or orientation == 4 then
                                                    baselineObj.values = { L["Left"], L["Center"], L["Right"] }
                                                end
                                                return RaidFrameSettings.db.profile.Debuffs.DebuffFramesDisplay.orientation
                                            end,
                                            set = function(_, value)
                                                RaidFrameSettings.db.profile.Debuffs.DebuffFramesDisplay.orientation = value
                                                local baseline = RaidFrameSettings.db.profile.Debuffs.DebuffFramesDisplay.baseline
                                                if value == 1 or value == 2 then
                                                    if baseline >= 4 then
                                                        RaidFrameSettings.db.profile.Debuffs.DebuffFramesDisplay.baseline = 3
                                                    end
                                                elseif value == 3 or value == 4 then
                                                    if baseline <= 3 then
                                                        RaidFrameSettings.db.profile.Debuffs.DebuffFramesDisplay.baseline = 4
                                                    end
                                                end
                                                RaidFrameSettings:UpdateModule("Debuffs")
                                            end,
                                            width = 0.8,
                                        },
                                        baseline = {
                                            order = 6.1,
                                            name = L["Baseline"],
                                            type = "select",
                                            values = { "Top/Left", "Middle/Center", "Bottom/Right" },
                                            sorting = { 1, 2, 3 },
                                            get = function()
                                                local baseline = RaidFrameSettings.db.profile.Debuffs.DebuffFramesDisplay.baseline
                                                return RaidFrameSettings.db.profile.Debuffs.DebuffFramesDisplay.orientation >= 3 and (baseline - 3) or baseline
                                            end,
                                            set = function(_, value)
                                                RaidFrameSettings.db.profile.Debuffs.DebuffFramesDisplay.baseline = RaidFrameSettings.db.profile.Debuffs.DebuffFramesDisplay.orientation >= 3 and (value + 3) or value
                                                RaidFrameSettings:UpdateModule("Debuffs")
                                            end,
                                            width = 0.8,
                                        },
                                        newline2 = {
                                            order = 7,
                                            name = "",
                                            type = "description",
                                        },
                                        xOffset = {
                                            order = 8,
                                            name = L["x - offset"],
                                            type = "range",
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            softMin = -100,
                                            softMax = 100,
                                            step = 1,
                                            width = 1.4,
                                        },
                                        yOffset = {
                                            order = 9,
                                            name = L["y - offset"],
                                            type = "range",
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            softMin = -100,
                                            softMax = 100,
                                            step = 1,
                                            width = 1.4,
                                        },
                                        gap = {
                                            order = 9.1,
                                            name = L["Gap"],
                                            type = "range",
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            softMin = -10,
                                            softMax = 10,
                                            step = 1,
                                            width = 0.8,
                                        },
                                        newline3 = {
                                            order = 10,
                                            name = "",
                                            type = "description",
                                        },
                                        swipe = {
                                            order = 11,
                                            type = "toggle",
                                            name = L["Show \"Swipe\""],
                                            desc = L["Show the swipe radial overlay"],
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            width = 0.8,
                                        },
                                        edge = {
                                            order = 12,
                                            type = "toggle",
                                            name = L["Show \"Edge\""],
                                            desc = L["Show the glowing edge at the end of the radial overlay"],
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            width = 0.8,
                                        },
                                        inverse = {
                                            order = 13,
                                            type = "toggle",
                                            name = L["Inverse"],
                                            desc = L["Invert the direction of the radial overlay"],
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            width = 0.6,
                                        },
                                        timerText = {
                                            order = 14,
                                            type = "toggle",
                                            name = L["Show Duration Timer Text"],
                                            desc = L["Enabling this will display an aura duration timer. When the OmniCC add-on is loaded, it's cooldown timer will be hidden."],
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            width = 1.2,
                                        },
                                        newline4 = {
                                            order = 40,
                                            name = "",
                                            type = "description",
                                        },
                                        maxdebuffs = {
                                            order = 41,
                                            name = L["Max Debuffes"],
                                            type = "range",
                                            get = "GetStatus",
                                            set = "SetStatus",
                                            min = 0,
                                            softMin = 3,
                                            softMax = 10,
                                            step = 1,
                                            width = 1.4,
                                        },
                                        framestrata = {
                                            order = 42,
                                            name = L["Frame Strata"],
                                            type = "select",
                                            values = { L["Inherited"], L["BACKGROUND"], L["LOW"], L["MEDIUM"], L["HIGH"], L["DIALOG"], L["FULLSCREEN"], L["FULLSCREEN_DIALOG"], L["TOOLTIP"] },
                                            sorting = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
                                            get = "GetStatus",
                                            set = "SetStatus",
                                        },
                                    },
                                },
                                DurationDisplay = {
                                    order = 2,
                                    name = L["Duration"],
                                    type = "group",
                                    args = getDebuffDurationOptions()
                                },
                                StacksDisplay = {
                                    order = 3,
                                    name = L["Stacks"],
                                    type = "group",
                                    args = getFontOptions()
                                },
                            },
                        },
                        Increase = {
                            order = 2,
                            name = L["Increase"],
                            desc = L["Set up auras to have the same size increase as boss auras."],
                            type = "group",
                            args = {
                                addAura = {
                                    order = 1,
                                    name = L["Enter spellId:"],
                                    desc = "",
                                    type = "input",
                                    width = 1.5,
                                    pattern = "^%d+$",
                                    usage = L["please enter a number"],
                                    set = function(_, value)
                                        RaidFrameSettings.db.profile.Debuffs.Increase[value] = true
                                        RaidFrameSettings:CreateIncreaseEntry(value, "Debuffs")
                                        RaidFrameSettings:UpdateModule("Debuffs")
                                    end,
                                },
                                IncreasedAuras = {
                                    order = 4,
                                    name = L["Increase:"],
                                    type = "group",
                                    inline = true,
                                    args = {

                                    },
                                },
                            },
                        },
                        AuraPosition = {
                            order = 3,
                            name = L["Aura Position"],
                            type = "group",
                            childGroups = "tab",
                            args = {
                                addGroup = {
                                    order = 1,
                                    name = L["New Group"],
                                    type = "execute",
                                    func = function()
                                        local dbObjGroup = RaidFrameSettings.db.profile["Debuffs"].AuraGroup
                                        tinsert(dbObjGroup, {
                                            name = "",
                                            point = 1,
                                            relativePoint = 1,
                                            frame = 1,
                                            frameNo = 0,
                                            frameSelect = 1,
                                            frameManualSelect = 1,
                                            unlimitAura = true,
                                            maxAuras = 1,
                                            xOffset = 0,
                                            yOffset = 0,
                                            orientation = 2,
                                            gap = 0,
                                            setSize = false,
                                            width = RaidFrameSettings.db.profile.Buffs.BuffFramesDisplay.width,
                                            height = RaidFrameSettings.db.profile.Buffs.BuffFramesDisplay.height,
                                            auraList = {},
                                        })
                                        local groupNo = #dbObjGroup
                                        dbObjGroup[groupNo].name = L["Group "] .. groupNo
                                        RaidFrameSettings:CreateAuraGroup(groupNo, "Debuffs")
                                        RaidFrameSettings:UpdateModule("Debuffs")
                                    end,
                                    width = 1,
                                },
                                auraGroup = {
                                    order = 2,
                                    name = L["Aura Position"],
                                    type = "group",
                                    args = {
                                        addAura = {
                                            order = 1,
                                            name = L["Enter spellId:"],
                                            type = "input",
                                            pattern = "^%d+$",
                                            usage = L["please enter a number"],
                                            set = function(_, value)
                                                RaidFrameSettings.db.profile.Debuffs.AuraPosition[value] = {
                                                    ["spellId"] = tonumber(value),
                                                    point = 1,
                                                    relativePoint = 1,
                                                    frame = 1,
                                                    frameNo = 0,
                                                    frameSelect = 1,
                                                    frameManualSelect = 1,
                                                    xOffset = 0,
                                                    yOffset = 0,
                                                    setSize = false,
                                                    width = RaidFrameSettings.db.profile.Debuffs.DebuffFramesDisplay.width,
                                                    height = RaidFrameSettings.db.profile.Debuffs.DebuffFramesDisplay.height,
                                                    glow = RaidFrameSettings.db.profile.AuraFilter.Debuffs[value] and RaidFrameSettings.db.profile.AuraFilter.Debuffs[value].glow,
                                                }
                                                RaidFrameSettings:CreateAuraPositionEntry(value, "Debuffs")
                                                RaidFrameSettings:UpdateModule("Debuffs")
                                            end
                                        },
                                        auraList = {
                                            order = 2,
                                            name = "",
                                            type = "group",
                                            inline = true,
                                            args = {

                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
        AuraHighlight = {
            order = 6,
            name = L["Aura Highlight"],
            type = "group",
            hidden = AuraHighlight_disabled,
            args = {
                Config = {
                    order = 1,
                    name = L["Config"],
                    type = "group",
                    inline = true,
                    args = {
                        operation_mode = {
                            order = 1,
                            name = L["Operation mode"],
                            desc = L["Smart - The add-on will determine which debuffs you can dispel based on your talents and class, and will only highlight those debuffs. \nManual - You choose which debuff types you want to see."],
                            type = "select",
                            values = { L["Smart"], L["Manual"] },
                            sorting = { 1, 2 },
                            get = "GetStatus",
                            set = "SetStatus",
                        },
                        useHealthBarColor = {
                            order = 1.1,
                            name = L["Color HealthBar"],
                            desc = "",
                            type = "toggle",
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 1,
                        },
                        useHealthBarGlow = {
                            order = 1.2,
                            name = L["Glow HealthBar"],
                            desc = "",
                            type = "toggle",
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 1,
                        },
                        newline = {
                            order = 1.3,
                            type = "description",
                            name = "",
                        },
                        Curse = {
                            hidden = function() return RaidFrameSettings.db.profile.AuraHighlight.Config.operation_mode == 1 and true or false end,
                            order = 2,
                            name = L["Curse"],
                            type = "toggle",
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.5,
                        },
                        Disease = {
                            hidden = function() return RaidFrameSettings.db.profile.AuraHighlight.Config.operation_mode == 1 and true or false end,
                            order = 3,
                            name = L["Disease"],
                            type = "toggle",
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.5,
                        },
                        Magic = {
                            hidden = function() return RaidFrameSettings.db.profile.AuraHighlight.Config.operation_mode == 1 and true or false end,
                            order = 4,
                            name = L["Magic"],
                            type = "toggle",
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.5,
                        },
                        Poison = {
                            hidden = function() return RaidFrameSettings.db.profile.AuraHighlight.Config.operation_mode == 1 and true or false end,
                            order = 5,
                            name = L["Poison"],
                            type = "toggle",
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.5,
                        },
                        Bleed = {
                            hidden = function() return RaidFrameSettings.db.profile.AuraHighlight.Config.operation_mode == 1 and true or false end,
                            order = 6,
                            name = L["Bleed"],
                            type = "toggle",
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.5,
                        },
                    },
                },
                MissingAura = {
                    order = 3,
                    name = L["Missing Aura"],
                    type = "group",
                    inline = true,
                    args = {
                        classSelection = {
                            order = 1,
                            name = L["Class:"],
                            type = "select",
                            values = addonTable.playableHealerClasses,
                            get = "GetStatus",
                            set = "SetStatus",
                        },
                        missingAuraColor = {
                            order = 2,
                            name = L["Missing Aura Color"],
                            type = "color",
                            get = "GetColor",
                            set = "SetColor",
                        },
                        input_field = {
                            order = 3,
                            name = L["Enter spellIDs"],
                            desc = L["enter spellIDs seperated by a semicolon or comma\nExample: 12345; 123; 456;"],
                            type = "input",
                            width = "full",
                            multiline = 5,
                            set = function(self, input)
                                local dbObj = RaidFrameSettings.db.profile.AuraHighlight.MissingAura
                                local class = addonTable.playableHealerClasses[dbObj.classSelection]
                                dbObj[class].input_field = input
                                --transform string to a list of spellIDs:
                                local tbl = {}
                                for word in string.gmatch(input, "([^;,%s]+)") do
                                    local name = GetSpellInfo(word)
                                    if name then
                                        tbl[tonumber(word)] = name
                                    end
                                end
                                dbObj[class].spellIDs = tbl
                                RaidFrameSettings:UpdateModule("AuraHighlight")
                            end,
                            get = function()
                                local dbObj = RaidFrameSettings.db.profile.AuraHighlight.MissingAura
                                local class = addonTable.playableHealerClasses[dbObj.classSelection]
                                return dbObj[class].input_field
                            end,
                        },
                    },
                },
            },
        },
        MinorModules = {
            order = 7,
            name = L["Module Settings"],
            type = "group",
            args = {
                Minimap = {
                    order = 0,
                    type = "toggle",
                    name = L["Minimap Icon"],
                    desc = L["Displays the icon in the minimap."],
                    get = function()
                        return not RaidFrameSettings.db.profile.MinorModules.minimapIcon.hide
                    end,
                    set = function(info, value)
                        RaidFrameSettings.db.profile.MinorModules.minimapIcon.hide = not value
                        RaidFrameSettings:ShowMinimapIcon(value)
                    end,
                },
                newline = {
                    order = 0.1,
                    type = "description",
                    name = "\n",
                },
                RoleIcon = {
                    hidden = isVanilla or RoleIcon_disabled,
                    order = 1,
                    name = L["Role Icon"],
                    type = "group",
                    inline = true,
                    args = {
                        position = {
                            order = 1,
                            name = L["Position"],
                            type = "select",
                            values = { L["Top Left"], L["Top Right"], L["Bottom Left"], L["Bottom Right"] },
                            sorting = { 1, 2, 3, 4 },
                            get = "GetStatus",
                            set = "SetStatus",
                        },
                        x_offset = {
                            order = 2,
                            name = L["x - offset"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            softMin = -25,
                            softMax = 25,
                            step = 1,
                            width = 0.8,
                        },
                        y_offset = {
                            order = 3,
                            name = L["y - offset"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            softMin = -25,
                            softMax = 25,
                            step = 1,
                            width = 0.8,
                        },
                        scaleFactor = {
                            order = 4,
                            name = L["scale"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            min = 0.1,
                            softMax = 3,
                            step = 0.1,
                            width = 0.8,
                        },
                    },
                },
                RaidMark = {
                    hidden = RaidMark_disabled,
                    order = 2,
                    name = L["Raid Mark"],
                    type = "group",
                    inline = true,
                    args = {
                        point = {
                            order = 1,
                            name = L["Anchor"],
                            type = "select",
                            values = { L["Top Left"], L["Top"], L["Top Right"], L["Left"], L["Center"], L["Right"], L["Bottom Left"], L["Bottom"], L["Bottom Right"] },
                            sorting = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.8,
                        },
                        relativePoint = {
                            order = 1.1,
                            name = L["to Frames"],
                            type = "select",
                            values = { L["Top Left"], L["Top"], L["Top Right"], L["Left"], L["Center"], L["Right"], L["Bottom Left"], L["Bottom"], L["Bottom Right"] },
                            sorting = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.8,
                        },
                        frame = {
                            order = 1.2,
                            name = L["to Attach Frame"],
                            type = "select",
                            values = { L["Unit Frame"], L["Role Icon"] },
                            sorting = { 1, 2 },
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.8,
                        },
                        x_offset = {
                            order = 2,
                            name = L["x - offset"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            softMin = -25,
                            softMax = 25,
                            step = 1,
                            width = 0.8,
                        },
                        y_offset = {
                            order = 3,
                            name = L["y - offset"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            softMin = -25,
                            softMax = 25,
                            step = 1,
                            width = 0.8,
                        },
                        newline = {
                            order = 4,
                            type = "description",
                            name = "",
                        },
                        width = {
                            order = 5,
                            name = L["width"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            min = 1,
                            max = 50,
                            step = 1,
                            width = 1,
                        },
                        height = {
                            order = 6,
                            name = L["height"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            min = 1,
                            max = 50,
                            step = 1,
                            width = 1,
                        },
                        alpha = {
                            order = 7,
                            name = L["alpha"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            min = 0.01,
                            max = 1,
                            step = 0.01,
                            width = 0.8,
                        },
                    },
                },
                RangeAlpha = {
                    hidden = Range_disabled,
                    order = 3,
                    name = L["Range Alpha"],
                    type = "group",
                    inline = true,
                    args = {
                        statusbar = {
                            order = 1,
                            name = L["Foreground"],
                            desc = L["the foreground alpha level when a target is out of range"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            min = 0,
                            max = 1,
                            step = 0.01,
                            width = 1.2,
                            isPercent = true,
                        },
                        background = {
                            order = 2,
                            name = L["Background"],
                            desc = L["the background alpha level when a target is out of range"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            min = 0,
                            max = 1,
                            step = 0.01,
                            width = 1.2,
                            isPercent = true,
                        },
                    },
                },
                DebuffColors = {
                    hidden = function() return not RaidFrameSettings.db.profile.Module.Debuffs and not RaidFrameSettings.db.profile.Module.AuraHighlight end,
                    order = 4,
                    name = L["Debuff colors"],
                    type = "group",
                    inline = true,
                    args = {
                        Curse       = {
                            order = 1,
                            type = "color",
                            name = L["Curse"],
                            get = "GetColor",
                            set = "SetColor",
                            width = 0.5,
                        },
                        Disease     = {
                            order = 2,
                            type = "color",
                            name = L["Disease"],
                            get = "GetColor",
                            set = "SetColor",
                            width = 0.5,
                        },
                        Magic       = {
                            order = 3,
                            type = "color",
                            name = L["Magic"],
                            get = "GetColor",
                            set = "SetColor",
                            width = 0.5,
                        },
                        Poison      = {
                            order = 4,
                            type = "color",
                            name = L["Poison"],
                            get = "GetColor",
                            set = "SetColor",
                            width = 0.5,
                        },
                        Bleed       = {
                            order = 5,
                            type = "color",
                            name = L["Bleed"],
                            get = "GetColor",
                            set = "SetColor",
                            width = 0.5,
                        },
                        newline     = {
                            order = 6,
                            type = "description",
                            name = "",
                        },
                        ResetColors = {
                            order = 7,
                            name = L["reset"],
                            desc = L["to default"],
                            type = "execute",
                            width = 0.4,
                            confirm = true,
                            func =
                                function()
                                    RaidFrameSettings.db.profile.MinorModules.DebuffColors.Curse   = { r = 0.6, g = 0.0, b = 1.0 }
                                    RaidFrameSettings.db.profile.MinorModules.DebuffColors.Disease = { r = 0.6, g = 0.4, b = 0.0 }
                                    RaidFrameSettings.db.profile.MinorModules.DebuffColors.Magic   = { r = 0.2, g = 0.6, b = 1.0 }
                                    RaidFrameSettings.db.profile.MinorModules.DebuffColors.Poison  = { r = 0.0, g = 0.6, b = 0.0 }
                                    RaidFrameSettings.db.profile.MinorModules.DebuffColors.Bleed   = { r = 0.8, g = 0.0, b = 0.0 }
                                    RaidFrameSettings:ReloadConfig()
                                end,
                        },
                    },
                },
                Glow = {
                    hidden = function() return not RaidFrameSettings.db.profile.Module.Buffs and not RaidFrameSettings.db.profile.Module.Debuffs end,
                    order = 5,
                    name = L["Glow"],
                    type = "group",
                    inline = true,
                    args = {
                        type = {
                            order = 1,
                            name = L["Glow Type"],
                            type = "select",
                            values = { L["Action Button"], L["Pixel"], L["Autocast"], L["Proc"] },
                            sorting = { 1, 2, 3, 4 },
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 1,
                        },
                        use_color = {
                            order = 2,
                            name = L["Use Custom Color"],
                            type = "toggle",
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.8,
                        },
                        color = {
                            order = 3,
                            type = "color",
                            name = L["Glow Color"],
                            get = "GetColor",
                            set = "SetColor",
                            width = 0.5,
                        },
                        -- Pixel, Autocast
                        lines = {
                            hidden = function()
                                local type = RaidFrameSettings.db.profile.MinorModules.Glow.type
                                return not (type == 2 or type == 3)
                            end,
                            order = 4,
                            name = L["Lines"],
                            desc = "",
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            min = 1,
                            -- max = 1,
                            softMin = 1,
                            softMax = 30,
                            step = 1,
                            width = 1,
                        },
                        -- Pixel, Autocast
                        frequency = {
                            hidden = function()
                                local type = RaidFrameSettings.db.profile.MinorModules.Glow.type
                                return not (type == 2 or type == 3)
                            end,
                            order = 5,
                            name = L["Frequency"],
                            desc = "",
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            -- min = 1,
                            -- max = 1,
                            softMin = -2,
                            softMax = 2,
                            step = 0.05,
                            width = 1,
                        },
                        -- Pixel
                        length = {
                            hidden = function()
                                local type = RaidFrameSettings.db.profile.MinorModules.Glow.type
                                return type ~= 2
                            end,
                            order = 6,
                            name = L["Length"],
                            desc = "",
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            min = 1,
                            -- max = 1,
                            softMin = 1,
                            softMax = 20,
                            step = 0.05,
                            width = 1,
                        },
                        -- Pixel
                        thickness = {
                            hidden = function()
                                local type = RaidFrameSettings.db.profile.MinorModules.Glow.type
                                return type ~= 2
                            end,
                            order = 7,
                            name = L["Thickness"],
                            desc = "",
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            min = 0.05,
                            -- max = 1,
                            softMin = 0.05,
                            softMax = 20,
                            step = 0.05,
                            width = 1,
                        },
                        -- Proc
                        duration = {
                            hidden = function()
                                local type = RaidFrameSettings.db.profile.MinorModules.Glow.type
                                return type ~= 4
                            end,
                            order = 8,
                            name = L["Duration"],
                            desc = "",
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            min = 0.01,
                            -- max = 1,
                            softMin = 0.01,
                            softMax = 3,
                            step = 0.01,
                            width = 1,
                        },
                        -- Autocast
                        scale = {
                            hidden = function()
                                local type = RaidFrameSettings.db.profile.MinorModules.Glow.type
                                return type ~= 3
                            end,
                            order = 9,
                            name = L["Scale"],
                            desc = "",
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            min = 0.05,
                            -- max = 1,
                            softMin = 0.05,
                            softMax = 10,
                            step = 0.05,
                            width = 1,
                            isPercent = true,
                        },
                        -- Pixel, Autocast, Proc
                        XOffset = {
                            hidden = function()
                                local type = RaidFrameSettings.db.profile.MinorModules.Glow.type
                                return type == 1
                            end,
                            order = 10,
                            name = L["x - offset"], -- X 오프셋
                            desc = "",
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            -- min = 1,
                            -- max = 1,
                            softMin = -100,
                            softMax = 100,
                            step = 1,
                            width = 1,
                        },
                        -- Pixel, Autocast, Proc
                        YOffset = {
                            hidden = function()
                                local type = RaidFrameSettings.db.profile.MinorModules.Glow.type
                                return type == 1
                            end,
                            order = 11,
                            name = L["y - offset"], -- y 오프셋
                            desc = "",
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            -- min = 1,
                            -- max = 1,
                            softMin = -100,
                            softMax = 100,
                            step = 1,
                            width = 1,
                        },
                        -- Proc
                        startAnim = {
                            hidden = function()
                                local type = RaidFrameSettings.db.profile.MinorModules.Glow.type
                                return type ~= 4
                            end,
                            order = 12,
                            name = L["Start Animation"],
                            type = "toggle",
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 1,
                        },
                        -- Pixel
                        border = {
                            hidden = function()
                                local type = RaidFrameSettings.db.profile.MinorModules.Glow.type
                                return type ~= 2
                            end,
                            order = 13,
                            name = L["Border"],
                            type = "toggle",
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.5,
                        },
                    },
                },
                CustomScale = {
                    hidden = isClassic or CustomScale_disabled,
                    order = 7,
                    name = L["Custom Scale"],
                    type = "group",
                    inline = true,
                    args = {
                        Party = {
                            order = 1,
                            name = L["Party"],
                            desc = "",
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            min = 0.5,
                            max = 3,
                            step = 0.1,
                            width = 1.2,
                            isPercent = true,
                        },
                        Arena = {
                            order = 2,
                            name = L["Arena"],
                            desc = "",
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            min = 0.5,
                            max = 3,
                            step = 0.1,
                            width = 1.2,
                            isPercent = true,
                        },
                        Raid = {
                            order = 3,
                            name = L["Raid"],
                            desc = "",
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            min = 0.5,
                            max = 3,
                            step = 0.1,
                            width = 1.2,
                            isPercent = true,
                        },
                    },
                },
                Overabsorb = {
                    hidden = isClassic or Overabsorb_disabled,
                    order = 8,
                    name = L["Overabsorb"],
                    type = "group",
                    inline = true,
                    args = {
                        glowAlpha = {
                            order = 1,
                            name = L["Glow intensity"],
                            type = "range",
                            get = "GetStatus",
                            set = "SetStatus",
                            min = 0,
                            max = 1,
                            step = 0.1,
                            isPercent = true,
                        },
                        position = {
                            order = 7.1,
                            name = L["Glow position"],
                            type = "select",
                            values = { L["Default"], L["Move overflow"], L["Move left"] },
                            sorting = { 1, 2, 3 },
                            get = "GetStatus",
                            set = "SetStatus",
                            width = 0.8,
                        },
                    },
                },
                TimerTextLimit = {
                    hidden = Buffs_disabled and Debuffs_disabled,
                    order = 9,
                    name = L["TimerText Format Limit (by seconds)"],
                    type = "group",
                    inline = true,
                    args = {
                        sec = {
                            order = 1,
                            name = L["Second Limit"],
                            type = "input",
                            get = function() return tostring(RaidFrameSettings.db.profile.MinorModules.TimerTextLimit.sec) end,
                            set = function(info, value)
                                RaidFrameSettings.db.profile.MinorModules.TimerTextLimit.sec = tonumber(value)
                            end,
                            pattern = "^%d+$",
                            usage = L["Display in minutes if second limit is exceeded. (please enter a number)"],
                        },
                        min = {
                            order = 2,
                            name = L["Minute Limit"],
                            type = "input",
                            get = function() return tostring(RaidFrameSettings.db.profile.MinorModules.TimerTextLimit.min) end,
                            set = function(info, value)
                                RaidFrameSettings.db.profile.MinorModules.TimerTextLimit.min = tonumber(value)
                            end,
                            pattern = "^%d+$",
                            usage = L["Display in hours if minute limit is exceeded. (please enter a number)"],
                        },
                        hour = {
                            order = 3,
                            name = L["Hour Limit"],
                            type = "input",
                            get = function() return tostring(RaidFrameSettings.db.profile.MinorModules.TimerTextLimit.hour) end,
                            set = function(info, value)
                                RaidFrameSettings.db.profile.MinorModules.TimerTextLimit.hour = tonumber(value)
                            end,
                            pattern = "^%d+$",
                            usage = L["Display in days if hour limit is exceeded. (please enter a number)"],
                        },
                    },
                },
            },
        },
        PorfileManagement = {
            order = lastEntry,
            name = L["Profiles"],
            type = "group",
            childGroups = "tab",
            args = {
                --order 1 is the ace profile tab
                GroupProfiles = {
                    order = 2,
                    name = L["Raid/Party Profile"],
                    type = "group",
                    inline = true,
                    args = {
                        party = {
                            order = 1,
                            name = L["Party"],
                            type = "select",
                            values = profiles,
                            get = function()
                                for i, value in pairs(profiles) do
                                    if value == RaidFrameSettings.db.global.GroupProfiles.party then
                                        return i
                                    end
                                end
                            end,
                            set = function(info, value)
                                RaidFrameSettings.db.global.GroupProfiles.party = profiles[value]
                                RaidFrameSettings:LoadGroupBasedProfile()
                            end,
                        },
                        raid = {
                            order = 2,
                            name = L["Raid"],
                            type = "select",
                            values = profiles,
                            get = function()
                                for i, value in pairs(profiles) do
                                    if value == RaidFrameSettings.db.global.GroupProfiles.raid then
                                        return i
                                    end
                                end
                            end,
                            set = function(info, value)
                                RaidFrameSettings.db.global.GroupProfiles.raid = profiles[value]
                                RaidFrameSettings:LoadGroupBasedProfile()
                            end,
                        },
                        arena = {
                            order = 3,
                            name = L["Arena"],
                            type = "select",
                            values = profiles,
                            get = function()
                                for i, value in pairs(profiles) do
                                    if value == RaidFrameSettings.db.global.GroupProfiles.arena then
                                        return i
                                    end
                                end
                            end,
                            set = function(info, value)
                                RaidFrameSettings.db.global.GroupProfiles.arena = profiles[value]
                                RaidFrameSettings:LoadGroupBasedProfile()
                            end,
                        },
                        battleground = {
                            order = 4,
                            name = L["Battleground"],
                            type = "select",
                            values = profiles,
                            get = function()
                                for i, value in pairs(profiles) do
                                    if value == RaidFrameSettings.db.global.GroupProfiles.battleground then
                                        return i
                                    end
                                end
                            end,
                            set = function(info, value)
                                RaidFrameSettings.db.global.GroupProfiles.battleground = profiles[value]
                                RaidFrameSettings:LoadGroupBasedProfile()
                            end,
                        },
                        description = {
                            order = 5,
                            name = L["The profiles you select above will be loaded based on the type of group you are in, if you want to use the same profile for all cases select it for all cases."],
                            fontSize = "medium",
                            type = "description",
                        },
                    },
                },
                ImportExportPofile = {
                    order = 3,
                    name = L["Import/Export Profile"],
                    type = "group",
                    args = {
                        Header = {
                            order = 1,
                            name = L["Share your profile or import one"],
                            type = "header",
                        },
                        Desc = {
                            order = 2,
                            name = L["To export your current profile copy the code below.\nTo import a profile replace the code below and press Accept"],
                            fontSize = "medium",
                            type = "description",
                        },
                        Textfield = {
                            order = 3,
                            name = L["import/export from or to your current profile"],
                            desc = L["|cffFF0000Caution|r: Importing a profile will overwrite your current profile."],
                            type = "input",
                            multiline = 18,
                            width = "full",
                            confirm = function() return "Caution: Importing a profile will overwrite your current profile." end,
                            get = function() return RaidFrameSettings:ShareProfile() end,
                            set = function(self, input)
                                RaidFrameSettings:ImportProfile(input); ReloadUI()
                            end,
                        },
                    },
                },
            },
        },
    },
}

function RaidFrameSettings:count(table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end

function RaidFrameSettings:compareSpell(a, b)
    local aname = GetSpellInfo(a) or L["|cffff0000aura not found|r"]
    local bname = GetSpellInfo(b) or L["|cffff0000aura not found|r"]
    return aname < bname
end

function RaidFrameSettings:GetProfiles()
    RaidFrameSettings.db:GetProfiles(profiles)
end

function RaidFrameSettings:GetOptionsTable()
    local blizoptions = {
        name = L["Raid Frame Settings"],
        handler = RaidFrameSettings,
        type = "group",
        args = {
            Version = {
                order = 1,
                name = L["You can also open the options window with the /rfs command.\n\n"],
                type = "description",
            },
            remove = {
                order = 2,
                name = L["Raid Frame Settings"],
                type = "execute",
                func = function()
                    local frame = RaidFrameSettings:GetOptionsFrame()
                    frame:Show()
                end,
            },
        }
    }
    return options, blizoptions
end

function RaidFrameSettings:CreateAuraFilterEntry(spellId, category)
    local dbObj = self.db.profile.AuraFilter[category][spellId]
    local auraFilterOptions = options.args.AuraFilter.args[category].args.FilteredAuras.args
    local spellName, _, icon
    if #spellId <= 10 then --spellId's longer than 10 intergers cause an overflow error
        spellName, _, icon = GetSpellInfo(spellId)
    end
    local maxEntry = self:count(auraFilterOptions)
    local aurafilter_entry = {
        order = maxEntry + 1,
        name = "",
        type = "group",
        inline = true,
        args = {
            auraInfo = {
                order = 1,
                image = icon,
                imageCoords = { 0.1, 0.9, 0.1, 0.9 },
                name = (spellName or L["|cffff0000aura not found|r"]) .. " (" .. spellId .. ")",
                type = "description",
                width = 1.5,
            },
            show = {
                order = 2,
                name = L["Show"],
                type = "toggle",
                get = function() return dbObj.show end,
                set = function(_, value)
                    dbObj.show = value
                    RaidFrameSettings:UpdateModule("AuraFilter")
                end,
                width = 0.5,
            },
            others = {
                hidden = function() return not dbObj.show or category == "Debuffs" end,
                order = 3,
                name = L["Other's buff"],
                type = "toggle",
                get = function() return dbObj.other end,
                set = function(_, value)
                    dbObj.other = value
                    RaidFrameSettings:UpdateModule("AuraFilter")
                end,
                width = 0.8,
            },
            hideInCombat = {
                hidden = function() return not dbObj.show end,
                order = 4,
                name = L["Hide In Combat"],
                type = "toggle",
                get = function() return dbObj.hideInCombat end,
                set = function(_, value)
                    dbObj.hideInCombat = value
                    RaidFrameSettings:UpdateModule("AuraFilter")
                end,
                width = 0.8,
            },
            priority = {
                hidden = function()
                    return not dbObj.show or not RaidFrameSettings.db.profile.Module[category]
                end,
                order = 5,
                name = L["Priority"],
                type = "input",
                pattern = "^%d+$",
                usage = L["please enter a number"],
                get = function()
                    if dbObj.priority and dbObj.priority > 0 then
                        return tostring(dbObj.priority)
                    end
                end,
                set = function(_, value)
                    dbObj.priority = tonumber(value)
                    RaidFrameSettings:LoadUserInputEntrys()
                    RaidFrameSettings:UpdateModule("AuraFilter")
                end,
                width = 0.4,
            },
            glow = {
                hidden = function()
                    return not dbObj.show or not RaidFrameSettings.db.profile.Module[category]
                end,
                order = 5.1,
                name = L["Glow"],
                type = "toggle",
                get = function() return dbObj.glow end,
                set = function(_, value)
                    dbObj.glow = value
                    RaidFrameSettings:UpdateModule("AuraFilter")
                end,
                width = 0.5,
            },
            remove = {
                order = 6,
                name = L["remove"],
                type = "execute",
                func = function()
                    self.db.profile.AuraFilter[category][spellId] = nil
                    auraFilterOptions[spellId] = nil
                    RaidFrameSettings:LoadUserInputEntrys()
                    RaidFrameSettings:UpdateModule("AuraFilter")
                end,
                width = 0.5,
            },
        },
    }
    auraFilterOptions[spellId] = aurafilter_entry
end

function RaidFrameSettings:CreateIncreaseEntry(spellId, category)
    local dbObj = self.db.profile[category].Increase
    local increaseOptions = options.args.Auras.args[category].args.Increase.args.IncreasedAuras.args
    local spellName, _, icon
    if #spellId <= 10 then --spellId's longer than 10 intergers cause an overflow error
        spellName, _, icon = GetSpellInfo(spellId)
    end
    local maxEntry = self:count(increaseOptions)
    local increase_entry = {
        order = maxEntry + 1,
        name = "",
        type = "group",
        inline = true,
        args = {
            auraInfo = {
                order = 1,
                image = icon,
                imageCoords = { 0.1, 0.9, 0.1, 0.9 },
                name = (spellName or L["|cffff0000aura not found|r"]) .. " (" .. spellId .. ")",
                type = "description",
                width = 1.5,
            },
            remove = {
                order = 2,
                name = L["remove"],
                type = "execute",
                func = function()
                    self.db.profile[category].Increase[spellId] = nil
                    increaseOptions[spellId] = nil
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.5,
            },
        },
    }
    increaseOptions[spellId] = increase_entry
end

local function getParent(category, frame, frameNo)
    if frame == 1 then
        return 1, 0
    elseif frame == 2 then
        local placed = RaidFrameSettings.db.profile[category].AuraPosition[tostring(frameNo)]
        if not placed then
            return nil
        end
        return placed.frame, placed.frameNo
    elseif frame == 3 then
        local group = RaidFrameSettings.db.profile[category].AuraGroup[frameNo]
        if not group then
            return nil
        end
        return group.frame, group.frameNo
    else
        return nil
    end
end

local function getChildren(category, frame, frameNo)
    local children = {}
    local placed = RaidFrameSettings.db.profile[category].AuraPosition
    for _, v in pairs(placed) do
        if v.frame == frame and v.frameNo == frameNo then
            tinsert(children, v)
        end
    end
    local group = RaidFrameSettings.db.profile[category].AuraGroup
    for _, v in pairs(group) do
        if v.frame == frame and v.frameNo == frameNo then
            tinsert(children, v)
        end
    end
    return children
end

local function linkParentAndChildrend(category, frame, frameNo)
    local parentFrame, parentFrameNo = getParent(category, frame, frameNo)
    if not parentFrame then
        parentFrame = 1
        parentFrameNo = 0
    end
    local children = getChildren(category, frame, frameNo)
    for _, v in pairs(children) do
        v.frame = parentFrame
        v.frameNo = parentFrameNo
    end
end

local function validateParent(category, frame, frameNo, targetFrame, targetNo)
    if frame == targetFrame and frameNo == targetNo then
        return false
    end
    if targetNo ~= 0 then
        while true do
            local parentFrame, parentNo = getParent(category, targetFrame, targetNo)
            if not parentFrame or (parentFrame == frame and parentNo == frameNo) then
                return false
            end
            if parentFrame == 1 or parentNo == 0 then
                break
            end
            targetFrame, targetNo = parentFrame, parentNo or 0
        end
    end
    return true
end

function RaidFrameSettings:CreateAuraPositionEntry(spellId, category)
    local dbObj = self.db.profile[category].AuraPosition[spellId]
    local auraPositionOptions = options.args.Auras.args[category].args.AuraPosition.args.auraGroup.args.auraList.args
    local spellName, _, icon
    if #spellId <= 10 then --spellId's longer than 10 intergers cause an overflow error
        spellName, _, icon = GetSpellInfo(spellId)
    end
    local maxEntry = self:count(auraPositionOptions)
    local aura_entry = {
        order = maxEntry + 1,
        name = "|cffFFFFFF" .. (spellName or L["|cffff0000aura not found|r"]) .. " (" .. spellId .. ") |r",
        type = "group",
        inline = true,
        args = {
            auraInfo = {
                order = 1,
                name = "",
                image = icon,
                imageCoords = { 0.1, 0.9, 0.1, 0.9 },
                imageWidth = 28,
                imageHeight = 28,
                type = "description",
                width = 0.5,
            },
            point = {
                order = 3,
                name = L["Anchor"],
                type = "select",
                values = { L["Top Left"], L["Top"], L["Top Right"], L["Left"], L["Center"], L["Right"], L["Bottom Left"], L["Bottom"], L["Bottom Right"] },
                sorting = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
                get = function()
                    return dbObj.point
                end,
                set = function(_, value)
                    dbObj.point = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.6,
            },
            relativePoint = {
                order = 4,
                name = L["to Frames"],
                type = "select",
                values = { L["Top Left"], L["Top"], L["Top Right"], L["Left"], L["Center"], L["Right"], L["Bottom Left"], L["Bottom"], L["Bottom Right"] },
                sorting = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
                get = function()
                    return dbObj.relativePoint
                end,
                set = function(_, value)
                    dbObj.relativePoint = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.6,
            },
            frame = {
                order = 4.1,
                name = L["to Attach Frame"],
                type = "select",
                values = { L["Unit Frame"], L["Placed"], L["Group"] },
                sorting = { 1, 2, 3 },
                get = function()
                    local optObj = auraPositionOptions[spellId].args
                    if dbObj.frame == 2 then
                        optObj.frameNo.name = L["SpellId"]
                        optObj.frameNo.usage = L["please enter a number (spellId of the aura frame you want to attach.)"]
                    elseif dbObj.frame == 3 then
                        optObj.frameNo.name = L["GroupNo"]
                        optObj.frameNo.usage = L["please enter a number (no of aura group you want to attach.)"]
                    end
                    return dbObj.frame
                end,
                set = function(_, value)
                    if dbObj.frame == value then
                        return
                    end
                    dbObj.frame = value
                    dbObj.frameNo = 0
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.8,
            },
            frameNo = {
                hidden = function() return dbObj.frame == 1 end,
                order = 4.2,
                name = L["FrameNo"],
                type = "input",
                pattern = "^%d+$",
                usage = L["please enter a number (spellId of the aura frame you want to attach.)"],
                get = function()
                    return dbObj.frameNo ~= nil and dbObj.frameNo ~= 0 and tostring(dbObj.frameNo) or ""
                end,
                set = function(_, value)
                    -- frameNo can be 0. Not possible for self. The top level frameNo should be 0 when following the parent.
                    local frameNo = tonumber(value)
                    if frameNo == dbObj.frameNo then
                        return
                    end
                    if not validateParent(category, 2, tonumber(spellId), dbObj.frame, frameNo) then
                        return
                    end
                    dbObj.frameNo = frameNo
                    RaidFrameSettings:LoadUserInputEntrys()
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.4,
            },
            frameSelect = {
                hidden = function() return dbObj.frame ~= 3 or dbObj.frameNo == 0 end,
                order = 4.3,
                name = L["Frame Select"],
                type = "select",
                values = { L["Last"], L["First"], L["Select"] },
                sorting = { 1, 2, 3 },
                get = function()
                    return dbObj.frameSelect
                end,
                set = function(_, value)
                    dbObj.frameSelect = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.5,
            },
            frameManualSelect = {
                hidden = function() return dbObj.frame ~= 3 or dbObj.frameNo == 0 or dbObj.frameSelect ~= 3 end,
                order = 4.4,
                name = L["Frame No"],
                type = "input",
                pattern = "^%d+$",
                usage = L["please enter a number (The n th frame of the aura group)"],
                get = function()
                    dbObj.frameManualSelect = dbObj.frameManualSelect or 1
                    return tostring(dbObj.frameManualSelect)
                end,
                set = function(_, value)
                    local frameNoNo = tonumber(value)
                    local dbGroup = self.db.profile[category].AuraGroup[dbObj.frameNo]
                    local maxAuras = dbGroup.unlimitAura ~= false and self:count(dbGroup.auraList) or dbGroup.maxAuras or 1
                    if maxAuras < 1 then maxAuras = 1 end
                    dbObj.frameManualSelect = frameNoNo < 1 and 1 or frameNoNo > maxAuras and maxAuras or frameNoNo
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.4,
            },
            newline0 = {
                hidden = function() return dbObj.frame == 1 end,
                order = 4.5,
                type = "description",
                name = "",
            },
            xOffset = {
                order = 5,
                name = L["x - offset"],
                type = "range",
                get = function()
                    return dbObj.xOffset
                end,
                set = function(_, value)
                    dbObj.xOffset = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                softMin = -100,
                softMax = 100,
                step = 1,
                width = 0.8,
            },
            yOffset = {
                order = 6,
                name = L["y - offset"],
                type = "range",
                get = function()
                    return dbObj.yOffset
                end,
                set = function(_, value)
                    dbObj.yOffset = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                softMin = -100,
                softMax = 100,
                step = 1,
                width = 0.8,
            },
            remove = {
                order = 7,
                name = L["remove"],
                type = "execute",
                func = function()
                    -- This will be deleted, so link the parent and child.
                    linkParentAndChildrend(category, 2, tonumber(spellId))
                    self.db.profile[category].AuraPosition[spellId] = nil
                    RaidFrameSettings:LoadUserInputEntrys()
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.5,
            },
            newline = {
                order = 8,
                type = "description",
                name = "",
            },
            setSize = {
                order = 9,
                type = "toggle",
                name = L["Set Size"],
                desc = "",
                get = function()
                    return dbObj.setSize
                end,
                set = function(_, value)
                    dbObj.setSize = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.5,
            },
            width = {
                order = 10,
                hidden = function() return not dbObj.setSize end,
                name = L["Icon Width"],
                type = "range",
                get = function()
                    return dbObj.width
                end,
                set = function(_, value)
                    dbObj.width = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                min = 1,
                max = 50,
                step = 1,
                width = 0.8,
            },
            height = {
                order = 11,
                hidden = function() return not dbObj.setSize end,
                name = L["Icon Height"],
                type = "range",
                get = function()
                    return dbObj.height
                end,
                set = function(_, value)
                    dbObj.height = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                min = 1,
                max = 50,
                step = 1,
                width = 0.8,
            },
            glow = {
                order = 12,
                name = L["Glow"],
                type = "toggle",
                get = function() return dbObj.glow end,
                set = function(_, value)
                    dbObj.glow = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.5,
            },
        },
    }
    auraPositionOptions[spellId] = aura_entry
end

function RaidFrameSettings:CreateAuraGroupEntry(spellId, groupNo, category)
    local dbObj = self.db.profile[category].AuraGroup[groupNo].auraList
    local groupOptions = options.args.Auras.args[category].args.AuraPosition.args["group" .. groupNo].args.auraList.args
    local spellName, _, icon
    if #spellId <= 10 then --spellId's longer than 10 intergers cause an overflow error
        spellName, _, icon = GetSpellInfo(spellId)
    end
    local maxEntry = self:count(groupOptions)
    -- for backward compatibility
    if type(dbObj[spellId]) ~= "table" then
        dbObj[spellId] = {
            spellId = tonumber(spellId),
            priority = 0,
        }
    end
    local aura_entry = {
        order = maxEntry + 1,
        name = "",
        type = "group",
        inline = true,
        args = {
            auraInfo = {
                order = 1,
                image = icon,
                imageCoords = { 0.1, 0.9, 0.1, 0.9 },
                name = (spellName or L["|cffff0000aura not found|r"]) .. " (" .. spellId .. ")",
                type = "description",
                width = 1.5,
            },
            priority = {
                order = 2,
                name = L["Priority"],
                type = "input",
                pattern = "^%d+$",
                usage = L["please enter a number"],
                get = function()
                    if dbObj[spellId].priority > 0 then
                        return tostring(dbObj[spellId].priority)
                    end
                end,
                set = function(_, value)
                    dbObj[spellId].priority = tonumber(value)
                    RaidFrameSettings:LoadUserInputEntrys()
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.4,
            },
            glow = {
                order = 3,
                name = L["Glow"],
                type = "toggle",
                get = function() return dbObj[spellId].glow end,
                set = function(_, value)
                    dbObj[spellId].glow = value
                    RaidFrameSettings:LoadUserInputEntrys()
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.5,
            },
            remove = {
                order = 4,
                name = L["remove"],
                type = "execute",
                func = function()
                    dbObj[spellId] = nil
                    groupOptions[spellId] = nil
                    RaidFrameSettings:LoadUserInputEntrys()
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.5,
            },
        },
    }
    groupOptions[spellId] = aura_entry
end

function RaidFrameSettings:CreateAuraGroup(groupNo, category)
    local dbObj = self.db.profile[category].AuraGroup[groupNo]
    local groupOptions = options.args.Auras.args[category].args.AuraPosition.args
    local auragroup_entry = {
        order = 2 + groupNo,
        name = "<" .. groupNo .. "> " .. dbObj.name,
        type = "group",
        args = {
            groupname = {
                order = 1,
                name = L["Groupname"],
                type = "input",
                get = function()
                    return dbObj.name
                end,
                set = function(_, value)
                    dbObj.name = value
                    RaidFrameSettings:LoadUserInputEntrys()
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.7,
            },
            groupNo = {
                order = 1.1,
                name = L["Order"],
                type = "input",
                get = function()
                    return tostring(groupNo)
                end,
                set = function(_, value)
                    local newGroupNo = tonumber(value) or groupNo
                    if newGroupNo == groupNo or newGroupNo < 0 or newGroupNo > #self.db.profile[category].AuraGroup then
                        return
                    end
                    local info = self.db.profile[category].AuraGroup[groupNo]
                    table.remove(self.db.profile[category].AuraGroup, groupNo)
                    table.insert(self.db.profile[category].AuraGroup, newGroupNo, info)
                    local children = getChildren(category, 3, groupNo)
                    if newGroupNo > groupNo then
                        for i = groupNo + 1, newGroupNo do
                            local children = getChildren(category, 3, i)
                            for _, v in pairs(children) do
                                v.frameNo = i - 1
                            end
                        end
                    elseif newGroupNo < groupNo then
                        for i = groupNo - 1, newGroupNo, -1 do
                            local children = getChildren(category, 3, i)
                            for _, v in pairs(children) do
                                v.frameNo = i + 1
                            end
                        end
                    end
                    for _, v in pairs(children) do
                        v.frameNo = newGroupNo
                    end
                    RaidFrameSettings:LoadUserInputEntrys()
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.3,
            },
            point = {
                order = 2,
                name = L["Anchor"],
                type = "select",
                values = { L["Top Left"], L["Top"], L["Top Right"], L["Left"], L["Center"], L["Right"], L["Bottom Left"], L["Bottom"], L["Bottom Right"] },
                sorting = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
                get = function()
                    return dbObj.point
                end,
                set = function(_, value)
                    dbObj.point = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.6,
            },
            relativePoint = {
                order = 3,
                name = L["to Frames"],
                type = "select",
                values = { L["Top Left"], L["Top"], L["Top Right"], L["Left"], L["Center"], L["Right"], L["Bottom Left"], L["Bottom"], L["Bottom Right"] },
                sorting = { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
                get = function()
                    return dbObj.relativePoint
                end,
                set = function(_, value)
                    dbObj.relativePoint = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.6,
            },
            frame = {
                order = 3.1,
                name = L["to Attach Frame"],
                type = "select",
                values = { L["Unit Frame"], L["Placed"], L["Group"] },
                sorting = { 1, 2, 3 },
                get = function()
                    local optObj = groupOptions["group" .. groupNo].args
                    if dbObj.frame == 2 then
                        optObj.frameNo.name = L["SpellId"]
                        optObj.frameNo.usage = L["please enter a number (spellId of the aura frame you want to attach.)"]
                    elseif dbObj.frame == 3 then
                        optObj.frameNo.name = L["GroupNo"]
                        optObj.frameNo.usage = L["please enter a number (no of aura group you want to attach.)"]
                    end
                    return dbObj.frame
                end,
                set = function(_, value)
                    if dbObj.frame == value then
                        return
                    end
                    dbObj.frame = value
                    dbObj.frameNo = 0
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.8,
            },
            frameNo = {
                hidden = function() return dbObj.frame == 1 end,
                order = 3.2,
                name = L["FrameNo"],
                type = "input",
                pattern = "^%d+$",
                usage = L["please enter a number (spellId of the aura frame you want to attach.)"],
                get = function()
                    return dbObj.frameNo ~= nil and dbObj.frameNo ~= 0 and tostring(dbObj.frameNo) or ""
                end,
                set = function(_, value)
                    -- frameNo can be 0. Not possible for self. The top level frameNo should be 0 when following the parent.
                    local frameNo = tonumber(value)
                    if frameNo == dbObj.frameNo then
                        return
                    end
                    if not validateParent(category, 3, tonumber(groupNo), dbObj.frame, frameNo) then
                        return
                    end
                    dbObj.frameNo = frameNo
                    RaidFrameSettings:LoadUserInputEntrys()
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.4,
            },
            frameSelect = {
                hidden = function() return dbObj.frame ~= 3 or dbObj.frameNo == 0 end,
                order = 3.3,
                name = L["Frame Select"],
                type = "select",
                values = { L["Last"], L["First"], L["Select"] },
                sorting = { 1, 2, 3 },
                get = function()
                    return dbObj.frameSelect
                end,
                set = function(_, value)
                    dbObj.frameSelect = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.5,
            },
            frameManualSelect = {
                hidden = function() return dbObj.frame ~= 3 or dbObj.frameNo == 0 or dbObj.frameSelect ~= 3 end,
                order = 3.4,
                name = L["Frame No"],
                type = "input",
                pattern = "^%d+$",
                usage = L["please enter a number (The n th frame of the aura group)"],
                get = function()
                    dbObj.frameManualSelect = dbObj.frameManualSelect or 1
                    return tostring(dbObj.frameManualSelect)
                end,
                set = function(_, value)
                    local frameNoNo = tonumber(value)
                    local dbGroup = self.db.profile[category].AuraGroup[dbObj.frameNo]
                    local maxAuras = dbGroup.unlimitAura ~= false and self:count(dbGroup.auraList) or dbGroup.maxAuras or 1
                    if maxAuras < 1 then maxAuras = 1 end
                    dbObj.frameManualSelect = frameNoNo < 1 and 1 or frameNoNo > maxAuras and maxAuras or frameNoNo
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.4,
            },
            newline0 = {
                hidden = function() return dbObj.frame == 1 end,
                order = 3.5,
                type = "description",
                name = "",
            },
            xOffset = {
                order = 4,
                name = L["x - offset"],
                type = "range",
                get = function()
                    return dbObj.xOffset
                end,
                set = function(_, value)
                    dbObj.xOffset = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                softMin = -100,
                softMax = 100,
                step = 1,
                width = 0.8,
            },
            yOffset = {
                order = 5,
                name = L["y - offset"],
                type = "range",
                get = function()
                    return dbObj.yOffset
                end,
                set = function(_, value)
                    dbObj.yOffset = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                softMin = -100,
                softMax = 100,
                step = 1,
                width = 0.8,
            },
            newline = {
                order = 6,
                type = "description",
                name = "",
            },
            orientation = {
                order = 7,
                name = L["Directions for growth"],
                type = "select",
                values = { L["Left"], L["Right"], L["Up"], L["Down"], L["Horizontal Center"], L["Vertical Center"] },
                sorting = { 1, 2, 3, 4, 5, 6 },
                get = function()
                    return dbObj.orientation
                end,
                set = function(_, value)
                    dbObj.orientation = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 1,
            },
            unlimitAura = {
                order = 7.1,
                type = "toggle",
                name = L["Unlimit Auras"],
                desc = "",
                get = function()
                    return dbObj.unlimitAura
                end,
                set = function(_, value)
                    dbObj.unlimitAura = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.8,
            },
            maxAuras = {
                hidden = function() return dbObj.unlimitAura end,
                order = 7.2,
                name = L["Max Auras"],
                type = "range",
                get = function()
                    return dbObj.maxAuras
                end,
                set = function(_, value)
                    dbObj.maxAuras = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                min = 1,
                softMax = 10,
                step = 1,
                width = 0.8,
            },
            gap = {
                order = 7.3,
                name = L["Gap"],
                type = "range",
                get = function()
                    return dbObj.gap
                end,
                set = function(_, value)
                    dbObj.gap = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                softMin = -10,
                softMax = 10,
                step = 1,
                width = 0.8,
            },
            setSize = {
                order = 8,
                type = "toggle",
                name = L["Set Size"],
                desc = "",
                get = function()
                    return dbObj.setSize
                end,
                set = function(_, value)
                    dbObj.setSize = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.5,
            },
            width = {
                order = 9,
                hidden = function() return not dbObj.setSize end,
                name = L["Icon Width"],
                type = "range",
                get = function()
                    return dbObj.width
                end,
                set = function(_, value)
                    dbObj.width = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                min = 1,
                max = 50,
                step = 1,
                width = 0.8,
            },
            height = {
                order = 10,
                hidden = function() return not dbObj.setSize end,
                name = L["Icon Height"],
                type = "range",
                get = function()
                    return dbObj.height
                end,
                set = function(_, value)
                    dbObj.height = value
                    RaidFrameSettings:UpdateModule(category)
                end,
                min = 1,
                max = 50,
                step = 1,
                width = 0.8,
            },
            remove = {
                order = 11,
                name = L["remove"],
                type = "execute",
                func = function()
                    -- This will be deleted, so link the parent and child.
                    linkParentAndChildrend(category, 3, groupNo)
                    for i = groupNo + 1, #self.db.profile[category].AuraGroup do
                        local children = getChildren(category, 3, i)
                        for _, v in pairs(children) do
                            v.frameNo = i - 1
                        end
                    end
                    table.remove(self.db.profile[category].AuraGroup, groupNo)
                    RaidFrameSettings:LoadUserInputEntrys()
                    RaidFrameSettings:UpdateModule(category)
                end,
                width = 0.5,
            },
            newline2 = {
                order = 12,
                type = "description",
                name = "",
            },
            addAura = {
                order = 13,
                name = L["Enter spellId:"],
                type = "input",
                pattern = "^%d+$",
                usage = L["please enter a number"],
                set = function(_, value)
                    dbObj.auraList[value] = {
                        spellId = tonumber(value),
                        priority = 0,
                        glow = RaidFrameSettings.db.profile.AuraFilter[category][value] and self.db.profile.AuraFilter[category][value].glow,
                    }
                    RaidFrameSettings:CreateAuraGroupEntry(value, groupNo, category)
                    RaidFrameSettings:UpdateModule(category)
                end
            },
            auraList = {
                order = 14,
                name = L["Auras:"],
                type = "group",
                inline = true,
                args = {

                },
            },
        },
    }
    groupOptions["group" .. groupNo] = auragroup_entry
end

function RaidFrameSettings:LoadUserInputEntrys()
    for _, category in pairs({
        "Buffs",
        "Debuffs",
    }) do
        -- Importing previous blacklist settings
        if self.db.profile[category].Blacklist then
            for spellId in pairs(self.db.profile[category].Blacklist) do
                self.db.AuraFilter[category][spellId].profile[category] = {
                    show = false,
                    hideInCombat = false,
                }
                self.db.profile[category].Blacklist[spellId] = nil
            end
            self.db.profile[category].Blacklist = nil
        end
        -- Importing previous aurafilter settings
        if self.db.profile[category].AuraFilter then
            for spellId, v in pairs(self.db.profile[category].AuraFilter) do
                self.db.profile.AuraFilter[category][spellId] = v
                self.db.profile[category].AuraFilter[spellId] = nil
            end
            self.db.profile[category].AuraFilter = nil
        end

        --aura filter
        options.args.AuraFilter.args[category].args.FilteredAuras.args = {}
        -- sort
        local sorted = {}
        for spellId, v in pairs(self.db.profile.AuraFilter[category]) do
            if not v.spellId then
                v.spellId = tonumber(spellId)
            end
            if not v.priority then
                v.priority = 0
            end
            tinsert(sorted, v)
        end
        table.sort(sorted, function(a, b)
            return a.priority == b.priority and self:compareSpell(a.spellId, b.spellId) or a.priority > b.priority
        end)
        for _, v in pairs(sorted) do
            self:CreateAuraFilterEntry(tostring(v.spellId), category)
        end

        --aura increase
        options.args.Auras.args[category].args.Increase.args.IncreasedAuras.args = {}
        for spellId in pairs(self.db.profile[category].Increase) do
            self:CreateIncreaseEntry(spellId, category)
        end

        --aura positions
        options.args.Auras.args[category].args.AuraPosition.args.auraGroup.args.auraList.args = {}
        -- sort
        sorted = {}
        local placed = CopyTable(self.db.profile[category].AuraPosition)
        for spellId, v in pairs(placed) do
            if v.frame == 2 and v.frameNo > 0 then
                local frameNo = tostring(v.frameNo)
                if placed[frameNo] then
                    placed[frameNo].children = placed[frameNo].children or {}
                    tinsert(placed[frameNo].children, spellId)
                end
            end
        end
        local showChildren
        showChildren = function(v)
            if v.children then
                for _, childAura in pairs(v.children) do
                    self:CreateAuraPositionEntry(childAura, category)
                    showChildren(placed[childAura])
                end
            end
        end
        for _, v in pairs(placed) do
            if (v.frameNo == 0 or v.frame ~= 2) then
                tinsert(sorted, v)
            end
        end
        table.sort(sorted, function(a, b) return self:compareSpell(a.spellId, b.spellId) end)
        for _, v in pairs(sorted) do
            self:CreateAuraPositionEntry(tostring(v.spellId), category)
            showChildren(v)
        end

        --aura groups
        for k in pairs(options.args.Auras.args[category].args.AuraPosition.args) do
            if k:match("^group") then
                options.args.Auras.args[category].args.AuraPosition.args[k] = nil
            end
        end
        for groupNo, group in pairs(self.db.profile[category].AuraGroup) do
            self:CreateAuraGroup(groupNo, category)
            if group.unlimitAura == nil then
                group.unlimitAura = true
                group.maxAuras = 1
            end
            -- for backward compatibility
            if group.orientation > 6 then
                group.orientation = 1
                group.unlimitAura = false
                group.maxAuras = 1
            end
            -- sort
            sorted = {}
            for spellId, v in pairs(group.auraList) do
                if not v.spellId then
                    v.spellId = tonumber(spellId)
                end
                if not v.priority then
                    v.priority = 0
                end
                tinsert(sorted, v)
            end
            table.sort(sorted, function(a, b)
                return a.priority == b.priority and self:compareSpell(a.spellId, b.spellId) or a.priority > b.priority
            end)
            for _, v in pairs(sorted) do
                self:CreateAuraGroupEntry(tostring(v.spellId), groupNo, category)
            end
        end
    end
end
