local M = setmetatable({ }, {
_NAME = 'console-builtin-extensions-global',
_DESCRIPTION = [[Additions for lua intrinsic types—global version of script that binds additions to global type tables (also returns module form).]]
})

-- @NOTE: In preparation for full modularization, beginning to  move method style calls
--        (`<target>:<method>(...args)`) to safer form <method>(<target>, ...args)

--region String

local string_ext = { }

---
--- Used in `get_all_completions`
---
---@param self string
---@param base string
---@return boolean
local function starts_with(self, base)
    if type(base) ~= "string" or type(self) ~= "string"
    then
        error("[string:starts_with] self or base argument is not string (self:" .. tostring(self).. ", base: " .. tostring(base) .. ")")
    end

    return self:sub(1, #base) == base
end

string_ext.starts_with = starts_with
string.starts_with     = starts_with

---
--- Escape possible `%*` format expressions in `str`
---
---@param  str string
---@return     string
function string_ext.format_escape(str)
    return (str or ''):gsub('(%%)', '%%%1')
end

string.format_escape = string_ext.format_escape

--region Quoting

---@return string
function string.quot(self)
    -- Get double quoted form, and replace with single quotes

    local dquoted = self:dquot()
    return [[']] .. dquoted:sub(2, #dquoted - 1) .. [[']]
end

---@return string
function string.dquot(self)
    -- Additional gsub call used to fix newlines when quoted—otherwise
    -- you get something of the form:
    --"start\
    --end"
    return string.format('%q', self):gsub('[\\]\n', '\n')
end

---
--- Wrapper for general non-string variable use
---
--- Note: Use for concatenating non-nilchecked values
---
---@param  value any
---@return       string
function _G.quote(value)
    value = type(value) == 'string' and value or tostring(value)

    return value:quot()
end

---
--- Wrapper for general non-string variable use
---
--- Note: Use for concatenating non-nilchecked values
---
---@param  value any
---@return       string
function _G.dquot(value)
    value = type(value) == 'string' and value or tostring(value)

    return value:dquot()
end

--endregion Quoting

--region Padding

---
--- Pad the right side of string `str` to length `len` with spaces, or string
--- `repeat_str`. If passed, only the first character of `repeat_str` is used.
---
---@param self       string
---@param len        number
---@param repeat_str string
---@return           string, boolean
function string.pad_right(self, len, repeat_str)
    local repeat_char =
        (type(repeat_str) == "string" and #repeat_str > 0)
            and repeat_str:sub(1, 1)
            or ' '
    if type(self) ~= "string" then self = tostring(self) end

    local res = self .. string.rep(repeat_char, len - #self)
    return res, res ~= self
end

---
--- Pad the left side of string `str` to length `len` with spaces, or string
--- `repeat_str`. If passed, only the first character of `repeat_str` is used.
---
---@param self       string
---@param len        number
---@param repeat_str string
---@return           string, boolean
function string.pad_left(self, len, repeat_str)
    local repeat_char =
        (type(repeat_str) == "string" and #repeat_str > 0)
            and repeat_str:sub(1, 1)
            or ' '
    if type(self) ~= "string" then self = tostring(self) end

    local res = string.rep(repeat_char, len - #self) .. self
    return res, res ~= self
end

local EOL =
{
    LF   = '\n',
    CRLF = '\r\n'
}
local default_eol = 'lf'
local default_new_line = EOL[default_eol:upper()]
---
--- Create iterator over lines of a string
---
---@param self string
---@param eol nil | "'lf'" | "'crlf'"
function string.lines(self, eol)
    local new_line =
        (type(eol) ~= "string" or eol:upper() == 'LF') and EOL.LF or EOL.CRLF

    -- Insert final separator for last line if needed
    if self:sub(-(#new_line)) ~= new_line then
        self = self .. new_line
    end

    return self:gmatch("(.-)" .. new_line)
end

--region UTF8 Compatible

--[[
    @TODO:
    Investigate using version that handles unicode characters, wrote it to
    handle output of box chars in a test output,
]]--

---
--- Pad the right side of string `str` to length `len` with spaces, or string
--- `repeat_str`. If passed, only the first character of `repeat_str` is used.
---
---@param str        string
---@param len        number
---@param repeat_str string
---@return           string, boolean
function string.rpad_utf8(str, len, repeat_str)
    -- Default case
    local repeat_char =
        (type(repeat_str) == "string" and utf8.len(repeat_str) > 0)
            and repeat_str or utf8.sub(repeat_str, 1)
            or ' '

    if type(str) ~= "string" then str = tostring(str) end

    local str_len = utf8.len(str)
    local res = string.format('%s%s', str, repeat_char:rep(len - str_len))
    return res, res ~= str
end

---
--- Pad the left side of string `str` to length `len` with spaces, or string
--- `repeat_str`. If passed, only the first character of `repeat_str` is used.
---
---@param str        string
---@param len        number
---@param repeat_str string
---@return           string, boolean
function string.lpad_utf8(str, len, repeat_str)
    -- Default case
    local repeat_char =
        (type(repeat_str) == "string" and utf8.len(repeat_str) > 0)
            and repeat_str or utf8.sub(repeat_str, 1)
            or ' '

    if type(str) ~= "string" then str = tostring(str) end

    local str_len = utf8.len(str)
    local res = string.format('%s%s', repeat_char:rep(len - str_len), str)
    return res, res ~= str
end

--endregion UTF8 Compatible

--endregion Padding

--region Trim

---@param  str string
---@return     string
function string.trim(str)
    local s = type(str) == "string" and str or ''
    return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

---@param  str string
---@return     string
function string.rtrim(str)
    local s = type(str) == "string" and str or ''
    return s:match'^(.*%S)%s*$'
end

---@param  str string
---@return     string
function string.ltrim(str)
    local s = type(str) == "string" and str or ''
    return s:match'^%s*(%S.*)$'
end

--endregion Trim

--region Title Case

--- Based on tchhelper implementation @ http://lua-users.org/wiki/StringRecipes

---@param  self string
---@return      string
function string.title_case(self)
    local word_pattern = "(%a)([%w_']*)"
    ---@param  first string
    ---@param  rest  string
    ---@return       string
    local function casing(first, rest)
        return first:upper()..rest:lower()
    end

    -- Add extra characters to the pattern if you need to. _ and ' are
    --  found in the middle of identifiers and English words.
    -- We must also put %w_' into [%w_'] to make it handle normal stuff
    -- and extra stuff the same.
    -- This also turns hex numbers into, eg. 0Xa7d4

    return self:gsub(word_pattern, casing)

end

--endregion Title Case

---
--- Returns if first char of string `char` is a hexadecimal digit, or `false`
--- by defauly if `char` is zero-length string or non-string value.
---
--- EDIT: There's an %x character class in pattern matching for this dummy
---
---@param  char string
---@return      boolean
local function is_hex_char(char)
    return type(char) == "string" and #char == 1 and char:find('^%x')
    -- if type(char) == "string" and #char > 0 then
    --     return (function(char_code)
    --         return ((char_code >= 48) and (char_code <= 57 ))
    --             or ((char_code >= 65) and (char_code <= 70 ))
    --             or ((char_code >= 97) and (char_code <= 102))
    --     end)(char:sub(1,1))
    -- else
    --     return false
    -- end
end

---
---@overload fun(str: string, vars: table<string, any>)
---@param   str  string
---@param   vars table
---@return       string
function template(str, vars)
    -- Allow replace_vars{str, vars} syntax as well as replace_vars(str, {vars})
    if type(vars) ~= 'table' then
        vars = str
        str  = vars[1]
    end
    -- Idiot check on string value
    if type(str) ~= "string" then
        error(string.format('Received template value is not a string (%s)', tostring(str)))
    end
    return (
        str:gsub("({([^}]+)})", function(whole, i) return vars[i] or whole end)
    )
end

--endregion Strings

-- end)

--region os

---
--- Capture command output
---
---@param  cmd string
---@overload fun(cmd: string, as_lines: true): string[]
---@return     string
function os.capture(cmd, as_lines)
    if type(as_lines) ~= 'boolean'
    then
        as_lines = false
    end
    local cmd      = (type(cmd) == "string" and cmd) or nil
    assert(cmd)

    -- Invoke command and read output
    local f = assert(io.popen(cmd, 'r'))

    -- If lines arg is passed true, return iterator of lines
    if as_lines
    then
        local line_itr = assert(f:lines())
        local lines = { }

        for entry in f:lines()
        do
            lines[#lines + 1] = entry
        end
        f:close()

        return lines
    else
        local s = assert(f:read('*a'))
        f:close()

        return s
    end
end

---@param cmd string
---@return    string[]
function os.capture_lines(cmd)
    return os.capture(cmd, true)
end

--endregion os
