-- take from: https://github.com/MWSE/morrowind-nexus-lua-dump/blob/master/lua/Leeches%20Always%20Bite%20Twice/Leeches%20Always%20Bite%20Twice-53010-1-0-0-1685721478/MWSE/mods/leeches/quests/trailing.lua#L15

local lib = require("Flin.lib")
local log = lib.log

local this = {}

---@alias PathingCallback fun(timer: mwseTimer, reference: tes3reference): any
---@type table<string, PathingCallback>
local pathingCallbacks = {}

--- Register a pathing callback.
---
---@param name string
---@param callback PathingCallback
function this.registerCallback(name, callback)
    pathingCallbacks[name] = callback
end

---@class PathingData
---@field handle mwseSafeObjectHandle
---@field destination tes3vector3?
---@field onFinish string

---@param data PathingData
function this.startPathing(data)
    timer.start({
        iterations = 40, -- 5 seconds
        duration = 0.1,
        callback = "flin:pathing:update", ---@diagnostic disable-line
        persist = true,
        data = data,
    })
end

---@param e mwseTimerCallbackData
local function update(e)
    ---@type PathingData
    local data = e.timer.data

    -- Get the reference.
    if not data.handle:valid() then
        log:error("pathing: invalid handle")
        e.timer:cancel()
        return
    end

    local ref = data.handle:getObject()
    if ref == nil then
        log:error("pathing: invalid reference")
        e.timer:cancel()
        return
    end

    -- Ensure the reference is alive.
    if ref.isDead then
        log:debug("pathing: dead reference (%s)", ref.id)
        e.timer:cancel()
        return
    end

    -- Ensure the reference is in an active cell.
    local mobile = ref.mobile
    if not (mobile and mobile.activeAI) then
        log:debug("pathing: inactive reference (%s)", ref.id)
        return
    end

    -- Start pathing.
    local package = ref.mobile.aiPlanner:getActivePackage() or {}
    if package.type ~= tes3.aiPackage.travel then
        tes3.setAITravel({ reference = ref, destination = data.destination })
        return
    end

    -- Wait for pathing to finish.
    if not package.isDone then
        local iterationsLeft = e.timer.iterations
        log:debug("pathing: timeLeft (%s)", iterationsLeft)
        if iterationsLeft < 2 then
            -- skip to end
            package.isDone = true
        else
            return
        end
    end

    -- If we finished but we're not at the destination, teleport.
    if ref.position:distance(data.destination) > 1024 then
        tes3.positionCell({ reference = ref, position = data.destination })
    end

    -- Reset the AI.
    log:debug("Resetting AI for %s", ref.id)
    tes3.setAIWander({ reference = ref, idles = { 0, 0, 0, 0, 0, 0, 0, 0 } })

    -- Pop the destination.
    data.destination = nil

    -- Trigger the onFinish callback.
    if data.onFinish then
        local callback = assert(pathingCallbacks[data.onFinish])
        callback(e.timer, ref)
    end

    -- All finished, end the timer.
    log:debug("pathing: finished (%s)", ref.id)
    e.timer:cancel()
end
timer.register("flin:pathing:update", update)

return this
