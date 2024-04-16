local addonName, addonTable = ...
local addon = addonTable.RaidFrameSettings
local Queue = addonTable.Queue

local module = addon:NewModule("Queue")

function module:OnEnable()
    Queue.use = addon.db.global.MinimapButton.enabled
end

function module:OnDisable()
    Queue:flush()
    Queue.use = addon.db.global.MinimapButton.enabled
end
