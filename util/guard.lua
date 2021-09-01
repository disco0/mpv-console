#!/usr/bin/env lua

--region Type Guards

---@alias Unknown any @ Stub type representing `unknown` style type in TypeScript.

local M = { }

--region is

---
--- Namespace of all type checking functions.
---
M.is = { }

--region Functions


---
--- Check that argument `obj` is a `string`.
---
---@param  obj Unknown
---@return     boolean
local function is__string(obj)
    return type(obj) == 'string'
end


---
--- Check that argument `obj` is a `table`.
---
---@param  obj Unknown
---@return     boolean
local function is__table(obj)
    return type(obj) == 'table'
end


---
--- Check that argument `obj` is a `array`.
---
---@param  obj Unknown
---@return     boolean
local function is__array(obj)
    return type(obj) == 'array'
end

---
--- Check that argument `obj` is a `number`.
---
---@param  obj Unknown
---@return     boolean
local function is__number(obj)
    return type(obj) == 'number'
end

--region Number Subtype Checking

---@param obj Unknown
---@return boolean
local function is__whole_number(obj)
    return is__number(obj) and obj == math.floor(obj)
end

-- @NOTE: Should remain disabled until is.Integer is renamed, as having both of these (both using
--        the same checking method) would be misleading as to their actual functions.
--
--        If you can't remember what the issue was—checking if `obj` is a float (in LuaJIT, or any
--        other Lua without math.type) is done via `obj ~= math.floor(obj)` and will break for
--        floats with no fractional part, e.g. is__float will incorrectly return false given `4.0`.

--[[

---
--- Returns opposite result of `is.Integer` call.
---
--- (Literally just the opposite)
---
---
-- -@param obj Unknown
-- -@return boolean
local function is__float(obj)
    return math.type(obj) == "integer"
end

]]--

--endregion Number Subtype Checking

---
--- Check that argument `obj` is a `nil`.
---
---@param  obj Unknown
---@return     boolean
local function is__nil(obj)
    return type(obj) == 'nil'
end


---
--- Check that argument `obj` is a `function`.
---
---@param  obj Unknown
---@return     boolean
local function is__function(obj)
    return type(obj) == 'function'
end


---
--- Check that argument `obj` is a `boolean`.
---
---@param  obj Unknown
---@return     boolean
local function is__boolean(obj)
    return type(obj) == 'boolean'
end


---
--- Check that `obj` is a positive integer. By default zero-inclusive, but controllable via `zero`
--- param
---
---@param  obj   Unknown
---@param  zero? boolean
---@return       boolean
local function is__natural(obj, zero)
    if not is__number(obj) then return false end

    --region Handle zero checking

    zero = is_nil(zero) and true or zero
    -- Shift +1 to allow for zero
    if zero == true then obj = obj + 1 end

    --endregion Handle zero checking

    return is__whole_number(obj) and obj > 0
end

--endregion Functions

--region Create Export

do
    local is =
    {
        String   = is__string,
        Table    = is__table,
        Array    = is__array,
        Nil      = is__nil,
        Function = is__function,
        Boolean  = is__boolean,
        --- Checks if `obj` is a number.
        ---@param  obj Unknown
        ---@return     boolean
        Number   = is__number,
        --- Checks if `obj` is a whole number, e.g. `3`, `3.0`, `-3`, `-3.000`
        ---@param  obj Unknown
        ---@return     boolean
        Integer  = is__whole_number,
        ---
        --- Check that `obj` is a positive integer. By default zero-inclusive, but controllable via `zero`
        --- param
        ---
        ---@param  obj   Unknown
        ---@param  zero? boolean
        ---@return       boolean
        Natural  = is__natural,
    }

    M.is = is
end

--endregion Create Export

--endregion Type Guards

--region Filtering

--region Cache

--- @TODO Add weak table for caching results from fpack callbacks

-- local fpack__cache

-- fpack__cache = setmetatable({ }, )

--endregion Cache

---
--- Collect varargs and return a callback that takes a filtering function.
---
local function fpack(...)
    -- Store copy of arguments
    local varargs = table.pack and table.pack(...) or {...}
    local last = { predicate = nil, result = nil }
    ---@param predicate fun(value: any): boolean
    ---@param force? boolean
    local apply_filter = function(predicate, force)
        -- Check if repeat call
        if not force
            and last.predicate == predicate
            and last.result    ~= nil
        then
            return last.filtered
        end

        local filtered = { }
        for index, arg in ipairs(varargs) do
            if(predicate(arg)) then filtered[#filtered + 1] = arg end
        end

        last = { predicate = predicate, result = filtered }

        return filtered
    end
    return setmetatable({ },
    {
        __call = function(self, ...) return apply_filter(...) end,
        __index = function(self, key)
            if key ~= 'last' then return nil end

            if last ~= nil and last.result ~= nil then return last.result end
        end
    })
end

M.fpack = fpack

--endregion Filtering

return M
