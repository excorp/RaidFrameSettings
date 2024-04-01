local _, addonTable = ...
local addon = addonTable.RaidFrameSettings

local Solo = addon:NewModule("Solo")
Mixin(Solo, addonTable.hooks)

local secureframe

local last = false
function Solo:OnEnable()
    local function onUpdateVisibility()
        if InCombatLockdown() then
            addon:RunWhenCombatEnds(onUpdateVisibility, "Solo")
            return
        end

        local solo = true
        if IsInGroup() then
            solo = false
        end
        if solo == false and last == false then
            return
        end
        if solo then
            CompactRaidFrameManager:Show()
            CompactRaidFrameManager.container:Show()
        end

        last = solo
    end
    self:HookFunc("CompactRaidFrameManager_UpdateContainerVisibility", onUpdateVisibility);

    secureframe = CreateFrame("FRAME", nil, UIParent, "SecureHandlerStateTemplate")
    secureframe:SetAttribute("_onstate-combatstate", [[
        if newstate == "ignore" then return end

        local CompactRaidFrameManager = self:GetFrameRef("CompactRaidFrameManager")
        if not CompactRaidFrameManager:IsShown() then
            CompactRaidFrameManager:Show()
            local CompactRaidFrameManagerContainer = self:GetFrameRef("CompactRaidFrameManagerContainer")
            CompactRaidFrameManagerContainer:Show()
        end

        self:SetAttribute("state-combatstate", "ignore")
    ]])
    secureframe:SetFrameRef("CompactRaidFrameManager", CompactRaidFrameManager)
    secureframe:SetFrameRef("CompactRaidFrameManagerContainer", CompactRaidFrameManager.container)
    RegisterAttributeDriver(secureframe, "state-combatstate", "[combat] true")

    if not IsInGroup() or not IsInRaid() then
        CompactRaidFrameManager:Show()
        CompactRaidFrameManager.container:Show()
    end
end

function Solo:OnDisable()
    self:DisableHooks()
    UnregisterAttributeDriver(secureframe, "state-combatstate")
    if not IsInGroup() or IsInRaid() then
        CompactRaidFrameManager:Hide()
        last = false
    end
end
