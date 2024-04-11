local _, addonTable = ...
local addon = addonTable.RaidFrameSettings
addonTable.Queue = {}
local Queue = addonTable.Queue

local pairs = pairs
local tinsert = tinsert
local debugprofilestop = debugprofilestop
local debugstack = debugstack
local geterrorhandler = geterrorhandler
local coroutine = coroutine
local SafePack = SafePack
local SafeUnpack = SafeUnpack
local C_Timer = C_Timer

local queue = {}
local pending = {}
local ticker

local co = coroutine.create(function()
    while true do
        for k, v in pairs(queue) do
            v.func(SafeUnpack(v.args))
            queue[k] = nil
            coroutine.yield(k, queue)
        end
    end
end)

function Queue:add(func, ...)
    tinsert(pending, {
        func = func,
        args = SafePack(...),
    })
end

function Queue:run()
    if ticker and not ticker:IsCancelled() then
        return
    end
    for k, v in pairs(pending) do
        tinsert(queue, v)
        pending[k] = nil
    end
    local function run()
        local start = debugprofilestop()
        while (debugprofilestop() - start < 1) do
            if coroutine.status(co) ~= "dead" then
                local ok, idx, queueLeft = coroutine.resume(co)
                if not ok then
                    geterrorhandler()(debugstack(co))
                    ticker:Cancel()
                end
                if next(queueLeft) == nil then
                    for k, v in pairs(pending) do
                        tinsert(queue, v)
                        pending[k] = nil
                    end
                    if #queue == 0 then
                        ticker:Cancel()
                        break
                    end
                end
            else
                ticker:Cancel()
                break
            end
        end
    end
    ticker = C_Timer.NewTicker(0, run)
end
