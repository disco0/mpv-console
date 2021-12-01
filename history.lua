local M = setmetatable({ }, {
_NAME = 'mpv-console-history',
_DESCRIPTION = [[Console command history state, configuration, and management functions.]]
})

---@alias HistoryEntry string

---@class History
---@field public values HistoryEntry[]
---@field public last   HistoryEntry
---@field public add    fun(self: History, line: string): nil

---
--- Storage table for history entries
---
---@type HistoryEntry[]
local history_stack = { }

---
--- Position of last history entry read/iterated
---
---@type number
M.pos = -1

local proto = { }

--region methods

local methods = { }

function methods.add(self, history_item)

    history_stack[#history_stack + 1] = history_item

end


proto.methods = methods

--endregion methods

--region properties

--region values

proto.values = { }

--endregion values

--region get/set

do local __ = { }

    --region last

    __.last =
    {
        get = function(self)
            return history_stack[#history_stack]
        end
    }

    __.values =
    {
        get = function(self)
            return history_stack
        end
    }

    --endregion last

    local get = { }
    local set = { }

    for k, v in pairs(__)
    do
        if v.get
        then
            get[k] = v.get
        end

        if v.set
        then
            set[k] = v.set
        end
    end

    proto.getset = { get = get, set = set }

end

--endregion get/set

--endregion properties

--region metatable

---@type Metatable
local history__mt = {
    __index = function(self, key)
        if proto.methods[key]
        then
            return proto.methods[key]

        elseif proto.values[key]
        then
            return proto.values[key]

        elseif proto.getset.get[key]
        then
            print(proto.getset.get[key])
            return proto.getset.get[key](self)
        end
    end,

    __newindex = function(self, key, value)
        if proto.getset.set[key]
        then
            proto.getset.set[key](self, value)
        end
    end,

    __len = function(self) return #history_stack end
}

--endregion metatable

--region static

local History = { }
---@return History
function History.new()
    local instance = setmetatable({}, history__mt)
    return instance
end

return History.new()

--endregion static
