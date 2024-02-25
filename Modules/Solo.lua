local _, addonTable = ...
local addon = addonTable.RaidFrameSettings

local Solo = addon:NewModule("Solo")
Mixin(Solo, addonTable.hooks)

local last = false
function Solo:OnEnable()
    local function onUpdateVisibility()
        if InCombatLockdown() then
            self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                onUpdateVisibility()
            end)
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
        CompactPartyFrame:SetShown(false)
        PartyFrame:UpdatePaddingAndLayout()
        last = false
    end
end
