--[[
    (In separate file to do initial testing in repl)
]]

---@class Perf
---@field public history table<number, PerfEventEntry>
---@field public init PerfEventEntry
---@field public last PerfEventEntry
---@field public record fun(description?: string)

---@type Perf
local perf
do local P = { }
    ---@class PerfEventEntry
    ---@field public memory      number
    ---@field public desciption? string

    ---@type table<number, PerfEventEntry>
    local history = { }

    local init =
    {
        memory = collectgarbage("count"),
        desciption = '<init>'
    }

    ---
    ---@param description? string
    ---@return PerfEventEntry
    function P.record(description)
        history[#history + 1] =
        {
            memory = collectgarbage("count"),
            -- @NOTE Maybe just default to an empty string to avoid issue with output later
            info = type(description) == 'string' and #description > 0 and description or nil
        }

        return history[#history]
    end
    local __index_operations = setmetatable(
        {
            history = function(self, key)
                print('Resolving history table.')
                return history
            end,
            init = function() return init end,
            last = function(self, key) return history[#history] end
        },
        {
            -- Meta-meta-event to catch any unknown lookups and default to a no-op
            __index = function(self, key) return function() end end
        })

    perf = setmetatable(P,
        ---@type Metatable
        {
            __index = function(self, key) return __index_operations[key](key) end,
            __new_index = function() end
        })
end

return {
    ---@type Perf
    Perf =
    ---@type Perf
    perf
}
