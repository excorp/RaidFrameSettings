local addonName, addonTable = ...

addonTable.isClassic = true
addonTable.isCata = true
addonTable.isFirstLoad = true

addonTable.texturePaths = {
    PortraitIcon = "Interface\\AddOns\\" .. addonName .. "\\Media\\Textures\\Icon\\Icon_Circle.tga",
}

addonTable.playerClass = select(2, UnitClass("player"))

addonTable.playableHealerClasses = {
    [1] = "PRIEST",
    [2] = "PALADIN",
    [3] = "SHAMAN",
    [4] = "DRUID",
}
