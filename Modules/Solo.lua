local _, addonTable = ...
local addon = addonTable.RaidFrameSettings

local Solo = addon:NewModule("Solo")
Mixin(Solo, addonTable.hooks)

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
        CompactPartyFrame:SetShown(solo)
        last = solo
    end
    self:HookFunc(CompactPartyFrame, "UpdateVisibility", onUpdateVisibility);
    if not IsInGroup() or not IsInRaid() then
        CompactPartyFrame:SetShown(true)
        PartyFrame:UpdatePaddingAndLayout()
    end
end

function Solo:OnDisable()
    self:DisableHooks()
    if not IsInGroup() or IsInRaid() then
        if InCombatLockdown() then
            addon:RunWhenCombatEnds(function()
                CompactPartyFrame:SetShown(false)
                PartyFrame:UpdatePaddingAndLayout()
                last = false
            end, "Solo")
            return
        end
        CompactPartyFrame:SetShown(false)
        PartyFrame:UpdatePaddingAndLayout()
        last = false
    end
end
