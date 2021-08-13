--region Safe Extension

--[[
    @TODO: Implement extensions in a locally loadable manner—or at least something else that doesnt
           completely poison vscode-lua's completions
]]--

local function nameof(val)
    for name, v in pairs(_G) do if v == val then return name end end
    return '?'
end

local function extend(tab, field, val)
    if tab[field] == nil then
        tab[field] = val
        return val
    elseif tab[field] ~= val then
        error(string.format('Extension %s.%s failed: already occupied by %s', nameof(tab), field, tostring(val)))
    else
        return val
    end
end

--endregion Safe Extension

local module = { }

--region String

do
    module.string = { }

    local string_mt_index = getmetatable('').__index

    print(require('mp.utils').to_string(string_mt_index))

    ---
    --- Used in `get_all_completions`
    ---
    ---@param self string
    ---@param base string
    ---@return boolean
    function module.string.starts_with(self, base)
        if type(base) ~= "string" or type(self) ~= "string"
        then
            error("[string:starts_with] self or base argument is not string (self:" .. tostring(self).. ", base: " .. tostring(base) .. ")")
        end

        return self:sub(1, #base) == base
    end

    module.string.default_quote_char = [["]]
    module.string.default_quote_char_esc = [[\]]
    module.string.quote_char_esc = { }
    module.string.quote_char_esc['"'] = [[\]]
    module.string.quote_char_esc["'"] = [[\]]

    string_mt_index.default_quote_char = module.string.default_quote_char
    string_mt_index.default_quote_char_esc = module.string.default_quote_char_esc
    string_mt_index.quote_char_esc = module.string.quote_char_esc

    --region Quoting

    ---@param  self string
    ---@return      string
    function module.string.quot(self)
        -- Get double quoted form, and replace with single quotes
        local dquoted = self:dquot()
        return [[']] .. dquoted:sub(2, #dquoted - 1) .. [[']]
    end

    string_mt_index.quot = module.string.quot

    ---@param  self string
    ---@return      string
    function module.string.dquot(self)
        -- Additional gsub call used to fix newlines when quoted—otherwise
        -- you get something of the form:
        --"start\
        --end"
        return string.format('%q', self):gsub('[\\]\n', '\n')
    end

    string_mt_index.dquot = module.string.dquot

    ---
    --- Wrapper for general non-string variable use
    ---
    --- Note: Use for concatenating non-nilchecked values
    ---
    ---@param  value any
    ---@return       string
    function module.string.quote(value)
        value = type(value) == 'string' and value or tostring(value)

        return value:quot()
    end

    string_mt_index.quote = module.string.quote

    ---
    --- Wrapper for general non-string variable use
    ---
    --- Note: Use for concatenating non-nilchecked values
    ---
    ---@param  value any
    ---@return       string
    function module.string.dquot(value)
        value = type(value) == 'string' and value or tostring(value)

        return value:dquot()
    end

    string_mt_index.dquot = module.string.dquot

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
    function module.string.pad_right(self, len, repeat_str)
        local repeat_char =
            (type(repeat_str) == "string" and #repeat_str > 0)
                and repeat_str:sub(1, 1)
                or ' '
        if type(self) ~= "string" then self = tostring(self) end

        local res = self .. string.rep(repeat_char, len - #self)
        return res, res ~= self
    end

    string_mt_index.pad_right = module.string.pad_right

    ---
    --- Pad the left side of string `str` to length `len` with spaces, or string
    --- `repeat_str`. If passed, only the first character of `repeat_str` is used.
    ---
    ---@param self       string
    ---@param len        number
    ---@param repeat_str string
    ---@return           string, boolean
    function module.string.pad_left(self, len, repeat_str)
        local repeat_char =
            (type(repeat_str) == "string" and #repeat_str > 0)
                and repeat_str:sub(1, 1)
                or ' '
        if type(self) ~= "string" then self = tostring(self) end

        local res = string.rep(repeat_char, len - #self) .. self
        return res, res ~= self
    end

    string_mt_index.pad_left = module.string.pad_left

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
    function module.string.lines(self, eol)
        local new_line =
            (type(eol) ~= "string" or eol:upper() == 'LF') and EOL.LF or EOL.CRLF

        -- Insert final separator for last line if needed
        if self:sub(-(#new_line)) ~= new_line then
            self = self .. new_line
        end

        return self:gmatch("(.-)" .. new_line)
    end

    string_mt_index.lines = module.string.lines

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
    function module.string.rpad_utf8(str, len, repeat_str)
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

    string_mt_index.rpad_utf8 = module.string.rpad_utf8

    ---
    --- Pad the left side of string `str` to length `len` with spaces, or string
    --- `repeat_str`. If passed, only the first character of `repeat_str` is used.
    ---
    ---@param str        string
    ---@param len        number
    ---@param repeat_str string
    ---@return           string, boolean
    function module.string.lpad_utf8(str, len, repeat_str)
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

    string_mt_index.lpad_utf8 = module.string.lpad_utf8

    --endregion UTF8 Compatible

    --endregion Padding

    --region Trim

    ---@param  str string
    ---@return     string
    function module.string.trim(str)
        local s = type(str) == "string" and str or ''
        return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
    end

    string_mt_index.trim = module.string.trim

    ---@param  str string
    ---@return     string
    function module.string.rtrim(str)
        local s = type(str) == "string" and str or ''
        return s:match'^(.*%S)%s*$'
    end

    string_mt_index.rtrim = module.string.rtrim

    ---@param  str string
    ---@return     string
    function module.string.ltrim(str)
        local s = type(str) == "string" and str or ''
        return s:match'^%s*(%S.*)$'
    end

    string_mt_index.ltrim = module.string.ltrim

    --endregion Trim

    --region Title Case

    --- Based on tchhelper implementation @ http://lua-users.org/wiki/StringRecipes

    ---@param  self string
    ---@return      string
    function module.string.title_case(self)
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

    string_mt_index.title_case = module.string.title_case

    --endregion Title Case

    require('debug').getmetatable('').__index = string_mt_index
end

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

--endregion Strings

return module
