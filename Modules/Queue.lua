local addonName, addonTable = ...
local addon = addonTable.RaidFrameSettings
local Queue = addonTable.Queue

local module = addon:NewModule("Queue")

function module:OnEnable()
    Queue.use = true
end

function module:OnDisable()
    Queue:flush()
    Queue.use = false
end
