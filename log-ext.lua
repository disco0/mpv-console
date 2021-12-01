--region Environment

local unpack = table.unpack or _G.unpack
---@generic T: any
---@type fun(...: T): T[]
local pack = ---@diagnostic disable-next-line
    _G.pack or table.pack
    or function(...) return {n = select('#', ...), ...} end

--endregion Environment

--region Declarations

---
--- Extended form of mp.msg, with additional `msg.<log-method>f` functions that accept
--- `string.format` style arguments, and the `extend` method, an alias of the prefixed
--- logger constructir
---
--- Extension methods are added to a new table with each existing msg method copied over, the
--- original `mp.msg` namespace is not polluted.
---
--- @TODO: Is it possible (and not a significant performance hit) to replace manual reimplementions
---        of original methods below with `__index` metatable based getters?
---
---@class msgext: msg
---@field public fdebug FormatLogMethod
---@field public ferror FormatLogMethod
---@field public finfo  FormatLogMethod
---@field public ftrace FormatLogMethod
---@field public fwarn  FormatLogMethod
---@field public extend fun(header: string): fmsg

---@alias FormatLogMethod fun(format_string: string, ...): nil

--endregion Declarations

local M = setmetatable({ }, {
_NAME        = 'log-ext',
_VERSION     = '0.1.2',
_DESCRIPTION = 'Extended logging for mpv scripts'
})

--region Utils

--region nil-safe table.unpack

local NIL_VALUE = [[<NIL>]] -- {} -- placeholder value for nil, storable in table.
local ntable = { }

---@vararg any
ntable.pack = function(...)
    local n = select('#', ...)
    local t = { }
    for i = 1,n
    do
        local v = select(i, ...)
        t[i] = (v == nil) and NIL_VALUE or v
    end
    return t
end

---@param t table
ntable.unpack_mut = function(t)
    if #t == 0
    then
        return
    else
        local v = table.remove(t, 1)
        if v == NIL_VALUE then v = nil end
        return v, ntable.unpack_mut(t)
    end
end

---
--- Replace nils with safe representation
---
ntable.varargs = function(...)
    return ntable.unpack_mut(ntable.pack(...))
end

--endregion nil-safe table.unpack

---
--- Wrapper for string.format that replaces nils with printable alias
---
local function safe_format(...)
    return string.format(ntable.varargs(...))
end

--endregion Utils

--region Extended msg

local PRIMORDIAL_msg = require('mp.msg')

---@type msgext
local msg_ext = { }

do
    -- Copy builtin msg functions
    for msg_method, msg_method_fn in pairs(PRIMORDIAL_msg) do
        msg_ext[msg_method] = function(...) msg_method_fn(safe_format(...)) end
    end

    function msg_ext.finfo(...)    PRIMORDIAL_msg.log('info',  safe_format(...)) end
    function msg_ext.ferror(...)   PRIMORDIAL_msg.log('error', safe_format(...)) end
    function msg_ext.fverbose(...) PRIMORDIAL_msg.log('v',     safe_format(...)) end
    function msg_ext.fdebug(...)   PRIMORDIAL_msg.log('debug', safe_format(...)) end
    function msg_ext.ftrace(...)   PRIMORDIAL_msg.log('trace', safe_format(...)) end
end

M.msg = msg_ext

--endregion Extended msg

--region Debug Logger Generator

local Prefix = { }

-- @TODO: Normalize usage of `title` && `header` && `prefix`
-- @TODO: memoize.lua needed for repeated generation of these msg wrappers?

---@alias MsgLevel
---| "'info'"
---| "'debug'"
---| "'error'"
---| "'fatal'"
---| "'verbose'"
---| "'trace'"

---
---@param header     string
---@param log_level? MsgLevel
---@return fun(...): nil
function Prefix.msg_method(header, log_level)
    local msg_level = 'debug' -- Default
    if type(log_level) == "string" then
        msg_level = log_level
    end

    ---@type string
    local header_content = string.format('[%s]', header)

    -- Return composed logger function
    ---@vararg string
    return function(...)
        PRIMORDIAL_msg[msg_level](table.concat({header_content,...}, ' '))
    end
end

---@param header     string
---@param log_level? MsgLevel
function Prefix.fmsg_method(header, log_level)
    local msg_level = 'debug' -- Default
    if type(log_level) == "string"
    then
        msg_level = log_level
    end

    ---@type string
    local header_content = string.format('[%s] ', header)

    -- Return composed logger function
    ---@param  format_str string
    ---@vararg            string
    ---@return            nil
    return function(format_str, ...)
        if type(format_str) ~= 'string' or #format_str == 0 then
            error('Format message requires non-zero length format string first argument.')
        end
        PRIMORDIAL_msg[msg_level](string.format(header_content .. format_str, ...))
    end
end

---@class fmsg
---@field public debug  FormatLogMethod
---@field public error  FormatLogMethod
---@field public info   FormatLogMethod
---@field public trace  FormatLogMethod
---@field public warn   FormatLogMethod
---@field public extend fun(header_append: string): fmsg

---@param    header string
---@vararg   string
---@overload fun(header: string, ...): fmsg
---@return   fmsg
function Prefix.fmsg(header, ...)
    assert(
        (type(header) == 'string' and #header >= 1),
        '[fmsg] header argument must be string of non-zero length' )

    ---@type string
    local header = header
    ---@type string
    local header_content = string.format('[%s] ', header)

    -- Handle multi element header
    local rest = pack({...})
    if #rest > 0
    then
        for i, next_header in ipairs(rest)
        do
            if type(next_header) == 'string' and #next_header > 0
            then
                header_content = header_content .. string.format('[%s] ', next_header)
            end
        end
    end

    return {
        debug = function(format_str, ...)
            PRIMORDIAL_msg.debug(safe_format(header_content .. format_str, ...))
        end,
        error = function(format_str, ...)
            PRIMORDIAL_msg.error(safe_format(header_content .. format_str, ...))
        end,
        info = function(format_str, ...)
            PRIMORDIAL_msg.info(safe_format(header_content .. format_str, ...))
        end,
        trace = function(format_str, ...)
            PRIMORDIAL_msg.trace(safe_format(header_content .. format_str, ...))
        end,
        warn = function(format_str, ...)
            PRIMORDIAL_msg.warn(safe_format(header_content .. format_str, ...))
        end,
        ---
        --- Create new instance with additional namespacing
        ---
        ---@param  header_append string
        ---@param  prefix        string | nil
        ---@return               fmsg
        extend = function(header_append, prefix)
            assert(
                (type(header_append) == 'string' and #header >= 1),
                '[fmsg::extend] header_append argument must be string of non-zero length' )
            local prefix = type(prefix) == 'string' and prefix or '::'

            return Prefix.fmsg(header .. prefix .. header_append)
        end
    }
end

M.msg.extend = Prefix.fmsg

M.Prefix = Prefix

--region Default Header

---@type fmsg
M.base = M.msg

---
--- Update globlal
---
---@param  header string
M.update_base = function(header)
    assert(type(header) == 'string' and #header > 0,
        "`header` parameter is a string with at least one character.")

    M.base = Prefix.fmsg(header)
end

--endregion Default Header

--endregion Debug Logger Generator

return M
