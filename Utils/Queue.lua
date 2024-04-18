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

local co

Queue.use = false

-- local stat = {}
-- DevTool:AddData(stat, "stat")
function Queue:init()
    co = coroutine.create(function()
        while true do
            local run = 0
            for k, v in next, queue do
                if v then
                    v.func(SafeUnpack(v.args))
                    coroutine.yield(k)
                end
                run = k
            end
            for i = 1, run do
                queue[i] = nil
            end
            print("queue end:", run)
            coroutine.yield(0)
        end
    end)
end

function Queue:add(func, ...)
    -- local key = debugstack(2, 2, 0) or "no key"
    -- if not stat[key] then stat[key] = 0 end
    -- stat[key] = stat[key] + 1
    if not Queue.use then
        func(...)
        return
    end
    queue[#queue + 1] = {
        func = func,
        args = SafePack(...),
    }
    Queue:run()
end

function Queue:runAndAdd(func, ...)
    func(...)
    if not Queue.use then
        return
    end
    Queue:add(func, ...)
end

function Queue:run()
    if ticker and not ticker:IsCancelled() then
        return
    end
    local function run()
        local start = debugprofilestop()
        local ok, idx
        while debugprofilestop() - start < 4 do
            if coroutine.status(co) ~= "dead" then
                ok, idx = coroutine.resume(co)
                if not ok then
                    geterrorhandler()(debugstack(co))
                    ticker:Cancel()
                    break
                end
                if idx == 0 then
                    ticker:Cancel()
                    break
                end
            else
                Queue:init()
                ticker:Cancel()
                break
            end
        end
        -- print("queue:", idx)
    end
    ticker = C_Timer.NewTicker(0, run)
end

function Queue:flush()
    if ticker and not ticker:IsCancelled() then
        ticker:Cancel()
    end
    while true do
        if coroutine.status(co) ~= "dead" then
            local ok, idx = coroutine.resume(co)
            if not ok then
                geterrorhandler()(debugstack(co))
                break
            end
            if idx == 0 then
                break
            end
        else
            break
        end
    end
end

Queue:init()
