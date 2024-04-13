local _, addonTable = ...
local addon = addonTable.RaidFrameSettings
addonTable.Queue = {}
local Queue = addonTable.Queue

local C_Timer = C_Timer
local SafePack = SafePack
local SafeUnpack = SafeUnpack
local tinsert = tinsert
local debugprofilestop = debugprofilestop
local debugstack = debugstack
local geterrorhandler = geterrorhandler

local coroutine = coroutine


local queue = {}
local ticker

local co = coroutine.create(function()
    while true do
        local run = 0
        local count = 0
        for k, v in next, queue do
            if v then
                v.func(SafeUnpack(v.args))
                coroutine.yield(#queue)
            end
            run = k
            count = count + 1
        end
        for i = 1, run do
            queue[i] = nil
        end
        -- print("queue:", count, run, #queue)
        coroutine.yield(#queue)
    end
end)

function Queue:add(func, ...)
    queue[#queue + 1] = {
        func = func,
        args = SafePack(...),
    }
    Queue:run()
end

function Queue:run()
    if ticker and not ticker:IsCancelled() then
        return
    end
    local function run()
        local start = debugprofilestop()
        while debugprofilestop() - start < 4 do
            if coroutine.status(co) ~= "dead" then
                local ok, queueSize = coroutine.resume(co)
                if not ok then
                    geterrorhandler()(debugstack(co))
                    ticker:Cancel()
                    break
                end
                if queueSize == 0 then
                    ticker:Cancel()
                    break
                end
            else
                ticker:Cancel()
                break
            end
        end
    end
    ticker = C_Timer.NewTicker(0, run)
end

function Queue:flush()
    if ticker and not ticker:IsCancelled() then
        ticker:Cancel()
    end
    while true do
        if coroutine.status(co) ~= "dead" then
            local ok, queueSize = coroutine.resume(co)
            if not ok then
                geterrorhandler()(debugstack(co))
                break
            end
            if queueSize == 0 then
                break
            end
        else
            break
        end
    end
end
