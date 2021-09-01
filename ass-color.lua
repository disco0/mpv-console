local module = { }

-- @TODO Check out R/G/B value to 24bit color operations (as well as the rest of
--       this post https://ebens.me/post/simulate-bitwise-shift-operators-in-lua
local function rgb2hex(r, g, b) 
    return (r * 2 ^ 16) 
         + (b * 2 ^ 08) 
         + (g * 2 ^ 01)
end 


--region Util

--region Builtin Aliases

local floor  = math.floor
local ceil   = math.ceil
local unpack = table.unpack or unpack
local pack   = table.pack   or pack

---
--- Extract whole component of (float) number
---
---@param  num number
---@return     number
local function int(num)
    -- -- lol@stackoverflow solution
    -- return (function(upper)
    --     return upper
    -- end)(math.modf(num))

    return (math.modf(num))
end

--endregion Builtin Aliases

--region Asserts

---
--- Returns caller's defined format string message, or the default defined in parameters.
---
---@param  passed_message  string | nil
---@param  passed_varargs  any[]
---@param  default_message string
---@vararg                 any
---@return                 string
local function passed_or_default(passed_message, passed_varargs, default_message, ...)
    -- Check if passed custom message string
    if type(passed_message) == 'string' then
        -- Check for varargs for format string
        if type(passed_varargs) == 'table' then
            return string.format(passed_message, unpack(passed_varargs))
        else
            return passed_message
        end
    -- Else use default defined in this check function
    else
        return string.format(default_message, ...)
    end
end

---
--- Guard functions that return the passed value on success, and throw an error with passed
--- `message` and format string values, or a relevant message defined in the function.
---
local check = { }
check = {
    ---
    --- Check that given value is a string, throwing `message` on failure.
    ---
    --- Additional values can be passed for handling the `message` parameter as a `string.format` expression.
    ---
    ---@generic S:       string
    ---@param   str      S      | any
    ---@param   message  string | nil
    ---@vararg           any
    ---@return           S
    string = function(str, message, ...)
        -- local message = message or string.format('Value is not string. (%s: %s)', str or '[nil]')
        return assert((type(str) == 'string'),
            passed_or_default(message, {...},
                'Value is not string. (%s: %s)',  str, type(str) )
        )
    end,

    ---
    --- Check that given is string with at least one character, throwing `message` on failure.
    ---
    --- Additional values can be passed for handling the `message` parameter as a `string.format` expression.
    ---
    ---@generic S:       string
    ---@param   str      S      | any
    ---@param   message  string | nil
    ---@vararg           any
    ---@return           S
    has_char = function(str, message, ...)
        -- local message = message or string.format('Value is not a string with at least one character. (%s)', str or '[nil]')

        return assert(check.string(str, message, ...),
            passed_or_default(message, {...},
                'Value is not a string with at least one character. (%s: %s)',
                str,
                type(str)
            )
        )
    end,

    ---
    --- Check that given value is a number, throwing `message` on failure.
    ---
    --- Additional values can be passed for handling the `message` parameter as a `string.format` expression.
    ---
    ---@generic N:       number
    ---@param   num      N      | any
    ---@param   message  string | nil
    ---@vararg           any
    ---@return           N
    number = function(num, message, ...)
        return assert((type(num) == 'number'),
            passed_or_default(message, {...},
                'Value is not a number. (%s: %s)', tostring(num), type(num) )
        )
    end,

    ---
    --- Check that given value is a number greater than or equal to zero, throwing `message` on failure.
    ---
    --- Additional values can be passed for handling the `message` parameter as a `string.format` expression.
    ---
    ---@generic N:       number
    ---@param   num      N      | any
    ---@param   message  string | nil
    ---@vararg           any
    ---@return           N
    natural = function(num, message, ...)
        -- local message = message or string.format(
        --     'Value is not a natural number. (%s: %s)',
        --     tostring(num),
        --     type(num)
        -- )

        return assert(check.number(num, message, ...) and num >= 0,
            passed_or_default(message, {...},
                'Value is not a natural number. (%s: %s)', tostring(num), type(num) )
        )
    end,

    ---
    --- Check that given value is a number in the range [`min`, `max`], throwing `message` on failure.
    ---
    --- Additional values can be passed for handling the `message` parameter as a `string.format` expression.
    ---
    ---@generic N:       number
    ---@param   num      N      | any
    ---@param   min      number
    ---@param   max      number
    ---@param   message  string | nil
    ---@vararg           any
    ---@return           N
    range = function(num, min, max, message, ...)
        -- This will explode
        -- local message = message or string.format(
        --     'Value is not in range [%s, %s]. (%s: %s)',
        --     tostring(min) or '[nil]',
        --     tostring(max) or '[nil]',
        --     tostring(num) or '[nil]',
        --     type(num)
        -- )
        return assert((check.number(num, message, ...) and num >= min and num <= max),
            passed_or_default(message, {...},
                -- This will explode
                'Value is not in range [%s, %s]. (%s: %s)',
                tostring(min) or '[nil]',
                tostring(max) or '[nil]',
                tostring(num) or '[nil]',
                type(num)
            )
        )
    end,

    ---
    --- Check that given value is a number in the bounds `[0, 1]`, throwing `message` on failure.
    ---
    --- Additional values can be passed for handling the `message` parameter as a `string.format` expression.
    ---
    ---@generic N:       number
    ---@param   num      N      | any
    ---@param   message  string | nil
    ---@vararg           any
    ---@return           N
    normalized = function(num, message, ...)
        -- local message = message or string.format(
        --     'Value is not a number, or out of bounds [0, 1]. (%s: %s)',
        --     num or '[nil]', type(num)
        -- )
        return assert((check.number(num, message, ...) and num >= 0 and num <= 1),
            passed_or_default(message, {...},
                'Value is not a number, or out of bounds [0, 1]. (%s: %s)',
                num or '[nil]', type(num)
            )
        )
    end
}

--endregion Asserts

--region Conversions

local convert = { }

local norm = { }
norm = {
    ---
    --- Defaults to norm.to_hex256
    ---
    ---@overload fun(normalized: number): number
    ---@param  normalized number
    ---@param  upper      '"16"' | '"256"' | '"1024"'
    ---@return            number
    to_hex = function(normalized, upper)
        if type(upper) == 'nil' or upper == "256" then
            return norm.to_hex256(normalized)
        elseif upper == '16' then
            return int(15 * normalized)
        elseif upper == '1024' then
            return int(1023 * normalized)
        end

        assert(false, string.format(
            'Invalid "upper" argument passed: "%s" ∉ {nil, "16", "256", "1024"}',
            upper
        ))
    end,

    ---@param  normalized number
    ---@return            number
    to_hex256 = function(normalized)
        return int(255 * normalized)
    end
}

convert.norm = norm

--endregion Conversions

--region Debugging

---
--- Pretty print a table will explode if anything fancy in it atm
---
--- Varargs can be passed one string and number value (each), corresponding to a prefix/type
--- label and indent level.
---
---@param  table_obj    table
---@vararg              string | number
---@return              nil
function inspect(table_obj, ...)
    local label = ''
    local indent_char = ' '
    local indent_size = 4
    local function indent(level, content)
        local indent_str = string.rep(indent_char, (level * indent_size))
        if type(content) == 'string' then
            return string.format('%s%s', indent_str, content)
        else
            return indent_str
        end
    end
    local function iprint(amount, message, ...)
        local amount = type(amount) == 'number' and amount >= 0 and amount or 0
        -- idk
        local args = pack(...)
        if #args == 0 then
            print(indent(amount, message))
        else
            print(indent(amount, message), ...)
        end
    end

    local varargs_accepted = { label = false, indent_size = false }
    for _, arg in pairs({...}) do
        local arg_type = type(arg)
        if arg_type == 'number' and varargs_accepted.indent_size == false and arg > 0 then
            indent_size = arg
            varargs_accepted.indent_size = true
        elseif arg_type == 'string' and varargs_accepted.label == false  then
            label = arg
            varargs_accepted.label = true
        end
    end

    --region Process

    if type(label) == 'string' and #label > 0 then
        iprint(0, label)
        iprint(0, '{')
    else
        iprint(0, '{')
    end

    for k, v in pairs(table_obj or { failed = true }) do
        iprint(1, string.format('[%s]: %s', k, tostring(v)))
    end

    local mt = getmetatable(table_obj)
    if type(mt) == 'table' then
        iprint(1, '[#metatable]:')
        iprint(1, '{')
        for k, v in pairs(mt or { failed = true }) do
            iprint(2, string.format('[%s]: %s', k, tostring(v)))
        end
        iprint(1, '}')
    end

    iprint(0, '}')

    --endregion Process
end

--endregion Debugging

--endregion Util

---@class Color
---@field public to_hex_string fun(noHashbang: boolean): string
---@field public to_hex        fun(): number

---@class AlphaColor: Color
---@field public without_alpha fun(): Color @TODO

--region RGBA?Color

---@class RGBAColor: AlphaColor
---@field public r number
---@field public g number
---@field public b number
---@field public a number

local RGBAColor = { prototype = { } }

--region Statics

---@alias RGBOutputMode '"RGB"' | '"BGR"'

RGBAColor.Format =
{
    RGB = 'RGB',
    BGR = 'BGR',
    ASS = 'BGR'
}

---
--- Internal constructor for RGBAColor that takes in r/g/b/a values from public constructor
--- functions—***r/g/b/a values should be normalized and validated in public constructors.***
---
---@param  r number
---@param  g number
---@param  b number
---@param  a number
---@return   RGBAColor
local function raw_RGBAColorNew(r, g, b, a)
    return setmetatable(
        {
            r = r,
            g = g,
            b = b,
            a = a
        },
        {
            __index    = RGBAColor.prototype,
            __tostring = RGBAColor.prototype.to_string
        }
    )
end

--region Constructors

---@alias ColorComponentIdent '"r"' | '"g"' | '"b"' | '"a"'
---@alias ColorTable          table<ColorComponentIdent, number>

---@overload fun(rgbaTable: ColorTable): RGBAColor
---@vararg number | string
function RGBAColor.new(...)
    --
    -- @single-arg
    -- -?? Single argument?
    --    @single-arg:string
    --    -?? String?
    --      @single-arg:string:parse
    --      -> Parse as hex value in string
    --    @single-arg:num
    --    -|| Number?
    --      @single-arg:num:parse
    --      -> Parse hex value in number (TODO: Best way?)
    --    @single-arg:table
    --    -|| Table?
    --      @single-arg:table:parse
    --       -> Recurse with unpacked first table argument as arguments
    -- @three-arg
    -- -|| Three arguments?
    --    @three-arg:parse
    --    -> Parse as RGB
    --
    -- @four-arg
    -- -|| Four arguments?
    --    @four-arg:parse
    --    -> Parse as RGBA
    --
    local args = {...}

    --region @single-arg

    if #args == 1 then
        if type(args[1]) == 'table' then
            -- Check for one of r/g/b/a keys,
            if type(args[1].r) ~= 'nil' then
                return RGBAColor.fromTable(args[1])
            -- Otherwise assume its an array and recall with unpacked args
            else
                return RGBAColor.new(unpack(args[1]))
            end
        elseif type(args[1]) == 'string' then
            assert(false, '[RGBAColor.new] Implement single string argument')
        elseif type(args[1]) == 'number' then
            assert(false, '[RGBAColor.new] Implement single number argument')
        end

        assert(false, '[RGBAColor.new] Implement single argument default')
    end

    --endregion @single-arg

    --region @three-arg

    if #args == 3 then
        local r, g, b = args[1], args[2], args[3]

        return RGBAColor.from(r, g, b)

        -- assert(false, '[RGBAColor.new] Implement three arguments')
    end

    --endregion @three-arg

    --region @four-arg

    if #args == 4 then
        local r, g, b, a = args[1], args[2], args[3], args[4]

        return RGBAColor.from(r, g, b, a)

        -- assert(false, '[RGBAColor.new] Implement four arguments')
    end

    --endregion @four-arg

    assert(false, '[RGBAColor.new] Reached end of function.')
end

---@param  ident string
---@param  value number
---@return       number
local function check_ident_normalized(ident, value)
    return check.normalized(value,
        '`%s` component is not a normalized number. (%s: %s)',
        ident,
        tostring(value),
        type(value)
    )
end

---
--- Create new RGBAColor from normalized r, g, b[, a] values, alpha value (`a`) defaults to 1.
---
---@param  color ColorTable
---@return       RGBAColor
function RGBAColor.fromTable(color)
    for component, value in pairs(color) do
        check_ident_normalized(component, value)
    end
    if type(a) ~= 'nil' then
        check_ident_normalized('a', color.a)
        -- check.normalized(a, string.format('Alpha component is not a normalized number. (%s)', tostring(a)))
    else
        color.a = 1
    end

    return raw_RGBAColorNew(color.r, color.g, color.b, color.a)
end

---
--- Create new RGBAColor from normalized r, g, b[, a] values.
---
---@param  r number
---@param  g number
---@param  b number
---@param  a number | nil
---@return   RGBAColor
function RGBAColor.from(r, g, b, a)
    check.normalized(r, 'Red component is not a normalized number. (%s)',   tostring(r))
    check.normalized(g, 'Green component is not a normalized number. (%s)', tostring(g))
    check.normalized(b, 'Blue component is not a normalized number. (%s)',  tostring(b))
    if type(a) ~= 'nil' then
        check.normalized(a, 'Alpha component is not a normalized number. (%s)', tostring(a))
    else
        a = 1
    end

    return raw_RGBAColorNew(r, g, b, a)
end

---
--- Create new RGBAColor from 8-bit numeric r, g, b[, a] values.
---
---@param  r number
---@param  g number
---@param  b number
---@param  a number | nil
---@return   RGBAColor
function RGBAColor.from256(r, g, b, a)
    check.range(r, 0, 255, 'Red component is not in range [0, 255]. (%s)', tostring(r))
    check.range(g, 0, 255, 'Green component is not in range [0, 255]. (%s)', tostring(g))
    check.range(b, 0, 255, 'Blue component is not in range [0, 255]. (%s)', tostring(b))
    if type(a) ~= 'nil' then
        check.range(a, 0, 255, 'Alpha component is not in range [0, 255]. (%s)', tostring(a))
    else
        a = 255
    end

    return raw_RGBAColorNew((r / 255), (g / 255), (b / 255), (a / 255))
end

--endregion Constructors

--endregion Statics

--region Instance

--region Color

---@class RGBAColorToHexOptions
---@field public hashbang boolean       | nil
---@field public format   RGBOutputMode | nil

---
--- Converts RGBAColor instance to a hex string value. Instead of an options table, the `options`
--- parameter can be given a boolean value to control hashbang prefix only (output format will then
--- use the instance's `format` value.
--
---@param  self    RGBAColor
---@param  options RGBAColorToHexOptions | boolean | nil
---@return         string
function RGBAColor.prototype.to_hex_string(self, options)

    ---@type RGBOutputMode
    local format = self.format
    ---@type boolean
    local use_hashbang = false

    --region Collapse overload

    local opt_type = type(options)
    if opt_type == 'nil' then
        -- Handled above
    elseif opt_type == 'table' then
        if type(options.format)   == 'string' then format       = options.format   end
        if type(options.hashbang) == 'string' then use_hashbang = options.hashbang end
    elseif opt_type == 'boolean' then
        ---@type boolean
        use_hashbang = options
    end

    --endregion Collapse overload

    local prefix = use_hashbang and '#' or ''

    if format == RGBAColor.Format.RGB then
        return string.format(prefix .. '%02X%02X%02X%02X',
            norm.to_hex256(self.r),
            norm.to_hex256(self.g),
            norm.to_hex256(self.b),
            norm.to_hex256(self.a)
        )
    else
        return string.format(prefix .. '%02X%02X%02X%02X',
            norm.to_hex256(self.b),
            norm.to_hex256(self.g),
            norm.to_hex256(self.r),
            norm.to_hex256(self.a)
        )
    end
end

--endregion Color

---@param  self RGBAColor
---@return      string
function RGBAColor.prototype.to_string(self)
    -- inspect(self, 'RGBAColor')

    return self:to_hex_string()
end

---
--- Control output format (intended for mpv ASS subtitles' use of BBGGRR)
---
RGBAColor.prototype.format = RGBAColor.Format.RGB

--endregion Instance

setmetatable(RGBAColor, { __call = function(_, ...) return RGBAColor.new(...) end })

module.RGBAColor = RGBAColor

--endregion RGBA?Color

return module
