local M = setmetatable({ }, {
_NAME = 'console-ass-format'
})

--region Localize

local format = string.format
local rep    = string.rep

--endregion Localize

--region Declarations

---@alias ColorLiteralArray table<number | '1' | '2' | '3', string>

---@class ColorLiteralTable
---@field public r number
---@field public g number
---@field public b number

--endregion Declarations

--region Util

--region Validation

local hex_pattern =
{
    [0x000F] = format('^%s$', rep('%x', 1)),
    [0x00FF] = format('^%s$', rep('%x', 2)),
    [0x0FFF] = format('^%s$', rep('%x', 3)),
    [0xFFFF] = format('^%s$', rep('%x', 4))
}

for k, v in ipairs(hex_pattern) do print(k, v) end

---
--- Returns if first char of string `char` is a hexadecimal digit, or `false`
--- by defauly if `char` is zero-length string or non-string value.
---
--- EDIT: There's an %x character class in pattern matching for this dummy
---
---@param  value_string string
---@return              boolean
local function is_hex_value(value_string)
    return type(value_string) == "string" and #value_string == 1 and value_string:find('^%x')
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


--endregion Validation

--endregion Util

---@param  color_literal ColorLiteralTable
---@return               string
function rgb_table_fg(color_literal)
    if type(color_literal) ~= "table" then
        error('Argument passed to rgb_table_fg is not a table.')
    end
end

---@param  color_literal ColorLiteralArray
---@return               string
function rgb_list_fg(color_literal)
    if type(color_literal) ~= "table" then
        error('Argument passed to FG is not a table.')
    end

    if #color_literal < 3 then
        error('Argument passed is less than three characters long.')

    -- If short form
    elseif #color_literal <= 4 then
        if #color_literal == 3 then

        else -- #color_literal == 4

        end
    -- If possibly full form
    elseif #color_literal <= 8 then
    else
        if #color_literal == 8 then

        elseif #color_literal == 6 then

        else
            error('Table passed to rgb_list_fg is not length of 3.')
        end
    end

    ---@type string, string, string
    local r, g, b = table.unpack(color_literal)

    -- for()
end
