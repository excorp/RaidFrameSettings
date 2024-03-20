local _, addonTable = ...

addonTable.isClassic = true
addonTable.isCata = true

addonTable.texturePaths = {
    PortraitIcon = "Interface\\AddOns\\RaidFrameSettings_Excorp_Fork\\Textures\\Icon\\Icon_Circle.tga",
}

addonTable.playerClass = select(2, UnitClass("player"))

addonTable.playableHealerClasses = {
    [1] = "PRIEST",
    [2] = "PALADIN",
    [3] = "SHAMAN",
    [4] = "DRUID",
}
