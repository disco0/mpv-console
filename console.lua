--- Copyright (C) 2019 the mpv developers
---
--- Permission to use, copy, modify, and/or distribute this software for any
--- purpose with or without fee is hereby granted, provided that the above
--- copyright notice and this permission notice appear in all copies.
---
--- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
--- WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
--- MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
--- SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
--- WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
--- OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
--- CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

--region Init

--region Declarations

--- List of tab-completions:
---   pattern: A Lua pattern used in string:find. Should return the start and
---            end positions of the word to be completed in the first and second
---            capture groups (using the empty parenthesis notation "()")
---   list: A list of candidate completion values.
---   append: An extra string to be appended to the end of a successful
---           completion. It is only appended if 'list' contains exactly one
---           match.
---@class CompletionSet
---@field public pattern string
---@field public list    CompletionList
---@field public append  string

---
---@alias Completions    CompletionSet[]
---@alias CompletionList string[]

---
---@class MpvProfile
---@field public name    string
---@field public options table<string, MpvPropertyType>

---@class LogLine
---@field style string
---@field text  string

---@class LogRawText: LogLine
---@field raw boolean | 'true'

---@alias LogRecord LogLine | LogRawText

---@class CompletionCompArgTable
---@field public pattern string
---@field public list    CompletionList
---@field public append  string

---@class CompletionCompArgTableTargeted: CompletionCompArgTable
---@field public target  CompletionList

---@class LogEventTable
---@field prefix string
---@field level  MessageLevel
---@field text   string

--endregion Declarations

--region Imports

---@type mp
local mp      = require('mp')
---@type utils
local utils   = require('mp.utils')
---@type options
local options = require('mp.options')
---@type assdraw
local assdraw = require('mp.assdraw')
---@type msg
local msg     = require ("mp.msg")

--endregion Imports

msg.info('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
msg.info('~~             Loading Extended Console             ~~')
msg.info('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')

--region package.path Fix

---@type string
local resolved_mpv_config_base = nil

--- Resolves (and caches) user mpv config path in order:
--- MPV_HOME        -> $MPV_HOME/
--- XDG_CONFIG_HOME -> $XDG_CONFIG_HOME/mpv/
--- HOME            -> $HOME/.config/mpv/
function resolve_mpv_config_base()
    if type(resolved_mpv_config_base) == "string" and #resolve_mpv_config_base > 0
    then
        return resolved_mpv_config_base
    else
        local env = os.getenv
        local env_fmt_lut =
        {
            { 'MPV_HOME',        '%s'             },
            { 'XDG_CONFIG_HOME', '%s/mpv'         },
            { 'HOME',            '%s/.config/mpv' }
        }
        ---@type string
        local value = nil

        for _, env_map in ipairs(env_fmt_lut) do
            value = env(env_map[1])
            if type(value) and #value > 0 then
                resolved_mpv_config_base = string.format(env_map[2], value)
                return resolved_mpv_config_base
            end
        end
    end
end

function package_path_fix()
    local mpv_base = resolve_mpv_config_base() -- nil

    if type(mpv_base) and #mpv_base > 0 then
        local mpv_script_path = mpv_base .. "/scripts/"
        _G.package.path =
            -- ~~/scripts/?
            mpv_script_path .. '?;' ..
            -- ~~/scripts/?.lua
            mpv_script_path .. '?.lua;' ..
            -- Initial package.path
            _G.package.path

        msg.debug(
            'Updated package.path to:' ..
            -- Split on separator and indent each path
            package.path:gsub(';', "\n    "):gsub('^', "\n    ")
        )
    else
        msg.warn(
            'Failed to resolve mpv configuration path: '..
            '(mpv_base?: ' .. type(mpv_base) .. ' => ' ..tostring(mpv_base) .. ')'
        )
        return
    end
end

local PACKAGE_PATH_FIX = true
if PACKAGE_PATH_FIX then
    msg.debug('Fixing package.path')
    package_path_fix()
end

--endregion package.path Fix

--region Builtin Utils

--region String

---
--- Used in `get_all_completions`
---
---@param base string
---@return boolean
function string.starts_with(self, base)
    if type(base) ~= "string" or type(self) ~= "string"
    then
        error("[string:starts_with] self or base argument is not string (self:" .. tostring(self).. ", base: " .. tostring(base) .. ")")
    end

    return self:sub(1, #base) == base
end

string.default_quote_char = [["]]
string.default_quote_char_esc = [[\]]
string.quote_char_esc = { }
string.quote_char_esc['"'] = [[\]]
string.quote_char_esc["'"] = [[\]]

--region Format String

---@overload fun(str: string, vars: table<string, any>)
---@param str  string
---@param vars table
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

--endregion Format String

--region Quoting

---@return string
function _G.string.quot(self)
    -- Get double quoted form, and replace with single quotes
    local dquoted = self:dquot()
    return [[']] .. dquoted:sub(2, #dquoted - 1) .. [[']]
end

---@return string
function _G.string.dquot(self)
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
function _G.dquote(value)
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
function _G.string.pad_right(self, len, repeat_str)
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
function _G.string.pad_left(self, len, repeat_str)
    local repeat_char =
        (type(repeat_str) == "string" and #repeat_str > 0)
            and repeat_str:sub(1, 1)
            or ' '
    if type(str) ~= "string" then str = tostring(str) end

    local res = string.rep(repeat_char, len - #str) .. str
    return res, res ~= str
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
function _G.string.rpad_utf8(str, len, repeat_str)
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
function _G.string.lpad_utf8(str, len, repeat_str)
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
function _G.string.trim(str)
    local s = type(str) == "string" and str or ''
    return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
end

---@param  str string
---@return     string
function _G.string.rtrim(str)
    local s = type(str) == "string" and str or ''
    return s:match'^(.*%S)%s*$'
end

---@param  str string
---@return     string
function _G.string.ltrim(str)
    local s = type(str) == "string" and str or ''
    return s:match'^%s*(%S.*)$'
end

--endregion Trim

--region Title Case

--- Based on tchhelper implementation @ http://lua-users.org/wiki/StringRecipes

---@param  self string
---@return      string
function _G.string.title_case(self)
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

--endregion Strings

--region Arrays

---
---@param str_arr string[]
---@return string, number
local function longest(str_arr)
    local idx = 1
    local total = #str_arr

    -- msg.debug('[longest] Array elements:')
    -- for i, v in ipairs(str_arr) do
    --     msg.debug('[longest]  #' .. i .. '  ' .. tostring(v))
    -- end
    -- print(str_arr)

    if total < 1 then
        error('Invalid array count: ' .. tostring(total))
        return
    end

    local curr_longest = {
        index = 0,
        value = "",
        length = -1
    }

    while idx <= total do
        -- msg.trace('[longest] Element #' .. tostring(idx))
        ---@type string
        local idx_value  = str_arr[idx]
        -- msg.trace('[longest]  Value: ' .. tostring(idx_value))

        -- Check if value is invalid (non-string or empty)
        if type(idx_value) == "string" then
            --region Main Loop Processing
            if #idx_value > 0 then
                ---@type number
                local idx_value_length = #idx_value
                if idx_value_length > curr_longest.length then
                    -- Record new longest
                    curr_longest = {
                        index  = idx,
                        value  = idx_value,
                        length = idx_value_length
                    }
                end
            --endregion Main Loop Processing
            else
                msg.debug('Zero length string in array, index #' .. tostring(idx))
            end
        -- Handle invalid, skip warning for empty strings
        elseif idx_value == nil then
            msg.warn('[longest] Value of element string array is nil (tostring: "'.. tostring(idx_value) ..'" => '.. type(idx_value) ..')')
        elseif type(idx_value) ~= "string" then
            msg.warn('[longest] Value of element string array is not a string, or nil (tostring: "'.. tostring(idx_value) ..'" => '.. type(idx_value) ..')')
        end
        idx = idx + 1
    end

    return curr_longest.value, curr_longest.length
end

--endregion Arrays

--endregion Builtin Utils

--region Script-Message tracking

--- @NOTE: Has to be loaded earlier no later than subscripts—otherwise
---        no script messages outside of main script will be completed
--- @TODO: Find out if there's a builtin property/method to query for registered
---        script messages, even in javascript realm

---
--- Store defined script messages for completion value generation
---
---@type string[]
_G.script_message_names = { }

---
--- Store parsed script message names for completion value generation
---
--- TODO: Implement script searcher/parser to generate values
---
_G.external_script_message_names = { }

--region Script-Message wrapper

---
--- Wrapper for `mp.register_script_message` that records the message name
--- for enumeration in completion builder
---
---@see mp.register_script_message
---@param name string
---@param fn   function
function _G.initialize_script_message(name, fn)
    mp.register_script_message(name, fn)

    -- Check if message name already in list before appending (still registering
    -- all new handler functions before this above)
    -- new script-message regardless)
    for _, existing_name in ipairs(_G.script_message_names) do
        if name == existing_name then
            msg.debug(string.format('Skipping adding message name %q to script-message name table, found previous instance.', name))
            return
        end
    end

    _G.script_message_names[#_G.script_message_names + 1] = name
end

--endregion Script-Message wrapper

--endregion Script-Message tracking

--region Debug Logger Generator

---@param header    string
---@param log_level nil | 'info' | 'debug' | 'error' | 'fatal' | 'verbose' | 'trace'
function titled_dbg_msg(header, log_level)
    local msg_level = 'debug' -- Default
    if type(log_level) == "string" then
        msg_level = log_level
    end

    ---@type string
    local header_content = string.format('[%s]', header)

    -- Return composed logger function
    ---@vararg string
    return function(...)
        msg[msg_level](table.concat({header_content,...}, ' '))
    end
end

--endregion Debug Logger Generator

--region Load Subscripts

-- @TODO Atm will be handling multiple subscripts (instead of one) by loading
--       through main subscript—if that changes make sure to add regions
--       for each one with the same scaffolding as the main subscript
-- @TODO Removed almost all the ceremony around loading, will handle later

--region Load Subscript: console_extensions.lua

msg.info("Loading core extension script")

console2 = { }
do
    -- TODO: require call uses literal string for lua-language-server, it can be
    --       moved back to `ext_require_path` eventually
    local ext_require_path = 'console/console_extensions'
    local subscript = require('console/console_extensions')
    if subscript ~= nil then
        console2 = subscript
    else
        msg.error(string.format('Failed to load console extension script with path "%s"', ext_require_path))
    end
end

--endregion Load Subscript: console_extensions.lua

--endregion Load Subscripts

--region Platform Detection

-- @NOTE Additional platform specific properties and relevant defines in source:
--     - Windows: HAVE_WIN32_DESKTOP
--         priority
--     - Android: HAVE_EGL_ANDROID
--         android-surface-size

local function detect_platform()
    local o = { }
    -- Kind of a dumb way of detecting the platform but whatever
    if mp.get_property_native('options/vo-mmcss-profile', o) ~= o then
        return 'windows'
    elseif mp.get_property_native('options/macos-force-dedicated-gpu', o) ~= o then
        return 'macos'
    end
    return 'x11'
end

_G.platform = detect_platform()

--endregion Platform Detection

--region Initialize Options

-- Get better font per user operating system
local function default_system_font(platform)
    platform = type(platform) == "string"
                    and #platform > 0
                    and platform
                or detect_platform()

    if platform == 'windows' then
        return 'Consolas'
    elseif platform == 'macos' then
        return 'Menlo'
    else
        return 'monospace'
    end
end

-- Default options
local opts =
{
    --- All drawing is scaled by this value, including the text borders and the
    --- cursor. Change it if you have a high-DPI display.
    scale = 1,

    --- Set the font used for the Console and the console. This probably doesn't
    --- have to be a monospaced font.
    font = default_system_font(),

    --- Set the font size used for the Console and the console. This will be
    --- multiplied by "scale."
    font_size = 16,
}

-- Apply user-set options
options.read_options(opts)

--endregion Initialize Options

--endregion Init

--region Script Global State

---@type boolean
_G.console_active = false
---@type boolean
_G.insert_mode = false
---@type boolean
_G.pending_update = false
-- Made non-local for extension script access
---@type string
_G.line = ''
---@type number
local cursor = 1
local history = {}
---@type number
local history_pos = 1
---@type LogRecord[]
_G.log_buffer = {}
local key_bindings = {}
---@type number
local global_margin_y = 0
local buffer_line_max = 100

--endregion Script Global State

local update_timer = nil
update_timer = mp.add_periodic_timer(0.05, function()
    if pending_update then
        update()
    else
        update_timer:kill()
    end
end)

update_timer:kill()

utils.shared_script_property_observe("osc-margins", function(_, val)
    if val then
        -- formatted as "%f,%f,%f,%f" with left, right, top, bottom, each
        -- value being the border size as ratio of the window size (0.0-1.0)
        local vals = {}
        for v in string.gmatch(val, "[^,]+") do
            vals[#vals + 1] = tonumber(v)
        end
        global_margin_y = vals[4] -- bottom
    else
        global_margin_y = 0
    end
    update()
end)

--region Console Output

---
--- Append last log entry's text instead of writing a new entry.
---
---@param text   string
---@param update boolean
function _G.log_edit(text, update)
    local curr_item = log_buffer[#log_buffer + 1]
    curr_item.text = curr_item.text .. text

    if type(update) == 'boolean' and update == true then
        if console_active then
            if not update_timer:is_enabled() then
                update()
                update_timer:resume()
            else
                pending_update = true
            end
        end
    end
end

-- local default_console_color = 'CCCCCC'

---
--- Add a line to the log buffer (which is limited to 100 lines)
---
---@param  style string
---@param  text  string
---@return       nil
function _G.log_add(style, text)
    log_buffer[#log_buffer + 1] = { style = style, text = text }
    if #log_buffer >  buffer_line_max  then
        table.remove(log_buffer, 1)
    end

    if console_active then
        if not update_timer:is_enabled() then
            update()
            update_timer:resume()
        else
            pending_update = true
        end
    end
end

--- Empty the log buffer of all messages (`Ctrl+l`)
local function clear_log_buffer()
    log_buffer = {}
    update()
end

--region Util

---@class AssEscapeOptions
---@field slash         boolean?
---@field brackets      boolean?
---@field newline       boolean?
---@field leading_space boolean?

_G.ASS_CHAR =
{
    -- Zero-width non-breaking space
    ZWNBSP = '\239\187\191',
    NEW_LINE = '\\N',
    HARD_SPACE = '\\h'
}

---
--- Escape a string `str` for verbatim display on the OSD
---
---@param  str string
---@return     string
local function ass_escape(str, no_escape)

    local disable = type(no_escape) == "table" and no_escape or { }

    local str = str and str or ''

    -- There is no escape for '\' in ASS (I think?) but '\' is used verbatim if
    -- it isn't followed by a recognised character, so add a zero-width
    -- non-breaking space
    -- str = str:gsub('\\', '\\\239\187\191')
    str = str:gsub('\\', '\\' .. ASS_CHAR.ZWNBSP)
    str = str:gsub('{', '\\{')
    str = str:gsub('}', '\\}')

    -- Precede newlines with a ZWNBSP to prevent ASS's weird collapsing of
    -- consecutive newlines
    -- str = str:gsub('\n', '\239\187\191\\N')
    str = str:gsub('\n', ASS_CHAR.ZWNBSP .. ASS_CHAR.NEW_LINE)

    -- Turn leading spaces into hard spaces to prevent ASS from stripping them
    str = str:gsub('\\N ', '\\N\\h') -- What is this for specifically? (????)
    str = str:gsub('^ ', ASS_CHAR.HARD_SPACE)

    return str
end

--endregion Util

--endregion Console Output

-- Render the Console and console as an ASS OSD
function update()
    pending_update = false

    local dpi_scale = mp.get_property_native("display-hidpi-scale", 1.0)

    dpi_scale = dpi_scale * opts.scale

    local screenx, screeny, aspect = mp.get_osd_size()
    screenx = screenx / dpi_scale
    screeny = screeny / dpi_scale

    -- Clear the OSD if the Console is not active
    if not console_active then
        mp.set_osd_ass(screenx, screeny, '')
        return
    end

    local ass = assdraw.ass_new()
    local style = '{\\r' ..
                  '\\1a&H00&\\3a&H00&\\4a&H99&' ..
                  '\\1c&Heeeeee&\\3c&H111111&\\4c&H000000&' ..
                  '\\fn' .. opts.font .. '\\fs' .. opts.font_size ..
                  '\\bord1\\xshad0\\yshad1\\fsp0\\q1}'
    -- Create the cursor glyph as an ASS drawing. ASS will draw the cursor
    -- inline with the surrounding text, but it sets the advance to the width
    -- of the drawing. So the cursor doesn't affect layout too much, make it as
    -- thin as possible and make it appear to be 1px wide by giving it 0.5px
    -- horizontal borders.
    local cheight = opts.font_size * 8
    local cglyph = '{\\r' ..
                   '\\1a&H44&\\3a&H44&\\4a&H99&' ..
                   '\\1c&Heeeeee&\\3c&Heeeeee&\\4c&H000000&' ..
                   '\\xbord0.5\\ybord0\\xshad0\\yshad1\\p4\\pbo24}' ..
                   'm 0 0 l 1 0 l 1 ' .. cheight .. ' l 0 ' .. cheight ..
                   '{\\p0}'
    local before_cur = ass_escape(line:sub(1, cursor - 1))
    local after_cur  = ass_escape(line:sub(cursor))

    -- Render log messages as ASS. This will render at most screeny / font_size
    -- messages.
    local log_ass = ''
    local log_messages = #log_buffer
    local log_max_lines = math.ceil(screeny / opts.font_size)
    if log_max_lines < log_messages then
        log_messages = log_max_lines
    end
    for i = #log_buffer - log_messages + 1, #log_buffer do
        log_ass = log_ass .. style .. log_buffer[i].style .. ass_escape(log_buffer[i].text)
    end

    ass:new_event()
    ass:an(1)
    ass:pos(2, screeny - 2 - global_margin_y * screeny)
    -- ass:append(log_ass .. '\\N')
    ass:append(log_ass .. ASS_CHAR.NEW_LINE)
    ass:append(style .. '> ' .. before_cur)
    ass:append(cglyph)
    ass:append(style .. after_cur)

    -- Redraw the cursor with the REPL text invisible. This will make the
    -- cursor appear in front of the text.
    ass:new_event()
    ass:an(1)
    -- Replaced with screen position calculations above
    -- ass:pos(2, screeny - 2)
    ass:pos(2, screeny - 2 - global_margin_y * screeny)
    ass:append(style .. '{\\alpha&HFF&}> ' .. before_cur)
    ass:append(cglyph)
    ass:append(style .. '{\\alpha&HFF&}' .. after_cur)

    mp.set_osd_ass(screenx, screeny, ass.text)
end

-- Set the Console visibility ("enable", Esc)
local function set_active(active)
    if active == console_active then return end
    if active then
        console_active = true
        insert_mode = false
        mp.enable_key_bindings('console-input', 'allow-hide-cursor+allow-vo-dragging')
        mp.enable_messages('terminal-default')
        define_key_bindings()
    else
        console_active = false
        undefine_key_bindings()
        mp.enable_messages('silent:terminal-default')
        collectgarbage()
    end
    update()
end

---
--- Show the repl if hidden and replace its contents with 'text'. Additionally
--- input can be executed immediately if second argument passed `true`.
--- (script-message-to repl type)
---
---@param  text             string
---@param  eval_immediately boolean | nil
local function show_and_type(text, eval_immediately)
    local dbg_msg = titled_dbg_msg('show_and_type')

    text = text or ''

    if type(eval_immediately) ~= "boolean" then
        eval_immediately = false
    end

    -- Save the line currently being edited, just in case
    if _G.line ~= text
       and _G.line ~= ''
       and history[#history] ~= _G.line then
        dbg_msg('Saving current line to history before possibly clearing.')
        history[#history + 1] = _G.line
    end

    _G.line = text
    cursor = line:len() + 1
    history_pos = #history + 1
    _G.insert_mode = false

    -- @TODO: Best time to place this after?
    -- If immediate exec then simulate enter press
    if eval_immediately then
        dbg_msg('Evaluating console line immedately, calling `handle_enter`.')
        handle_enter()
    end

    if console_active then
        dbg_msg('Console is active, calling global update function.')
        update()
    else
        dbg_msg('Making console active.')
        set_active(true)
    end
end

--region UTF Util

---
--- Naive helper function to find the next UTF-8 character in 'str' after 'pos'
--- by skipping continuation bytes. Assumes 'str' contains valid UTF-8.
---
---@param  str string
---@param  pos number
---@return     number
local function next_utf8(str, pos)
    if pos > str:len() then
        return pos
    end
    repeat
        pos = pos + 1
    until pos > str:len()
            or str:byte(pos) < 0x80
            or str:byte(pos) > 0xbf

    return pos
end

---
--- Naive helper function to find the prev UTF-8 character in 'str' after 'pos'
--- by skipping continuation bytes. Assumes 'str' contains valid UTF-8.
---
---@param  str string
---@param  pos number
---@return     number
local function prev_utf8(str, pos)
    if pos <= 1 then
        return pos
    end

    repeat
        pos = pos - 1
    until pos <= 1
            or str:byte(pos) < 0x80
            or str:byte(pos) > 0xbf

    return pos
end

--endregion UTF Util

-- Close the console if the current line is empty, otherwise do nothing (Ctrl+D)
local function close_console_if_empty()
    if _G.line == '' then
        set_active(false)
    end
end

--region Help Command

local function help_command(param)
    local cmdlist = mp.get_property_native('command-list')
    local error_style = '{\\1c&H7a77f2&}'
    local output = ''
    if param == '' then
        output = 'Available commands:\n'
        for _, cmd in ipairs(cmdlist) do
            output = output  .. '  ' .. cmd.name
        end
        output = output .. '\n'
        output = output .. 'Use "help command" to show information about a command.\n'
        output = output .. "ESC or Ctrl+d exits the console.\n"
    else
        local cmd = nil
        for _, curcmd in ipairs(cmdlist) do
            if curcmd.name:find(param, 1, true) then
                cmd = curcmd
                if curcmd.name == param then
                    break -- exact match
                end
            end
        end
        if not cmd then
            _G.log_add(error_style, 'No command matches "' .. param .. '"!')
            return
        end
        output = output .. 'Command "' .. cmd.name .. '"\n'
        for _, arg in ipairs(cmd.args) do
            output = output .. '    ' .. arg.name .. ' (' .. arg.type .. ')'
            if arg.optional then
                output = output .. ' (optional)'
            end
            output = output .. '\n'
        end
        if cmd.vararg then
            output = output .. 'This command supports variable arguments.\n'
        end
    end
    _G.log_add('', output)
end

--region Modded Help

-- Help Display Function-copied from new console script(migration of repl.lua)
-- TODO: Make columns or something for the list outputs its horrible
---@param param string
local function help_command_custom(param)
    local dbg = titled_dbg_msg('!help', debug)

    -- Process possible dangerous optional param
    local param = param or nil
    if type(param) == 'nil' then
        dbg([[`param` argument appears to be nil.]])
        -- Now it can be set to a string
        param = ''
    else
        dbg(string.format('`param` equals: `%s`', tostring(param)))
    end

    local cmdlist = mp.get_property_native('command-list')

    -- Styles
    local cmd_style   = '{\\1c&H' .. "FFAD4C" .. '&}'
    local error_style = '{\\1c&H' .. "7a77f2" .. '&}'

    local output = ''

    -- Output Cases:
    if not param or param == '' then
        -- Case 1: Print Available Commands
        --   Modifications:
        --     - Print out commands with log style `cmd_style`
        --     - Limit columns of commands per line (check for longest)
        output = 'Available commands:\n'
        -- Use this variable for logging commands
        local cmd_output    = ''
        -- Add all commands to this variable while getting max length
        local cmds          = {}
        -- Max char count var
        local max_cmd_chars = -1

        -- Command list iteration 1
        for _, cmd in ipairs(cmdlist) do
            output = output  .. '  ' .. cmd.name
        end
        output = output .. '\n'
        output = output .. 'Use "help command" to show information about a command.\n'
        output = output .. "ESC or Ctrl+d exits the console.\n"
    else
        local cmd = nil
        for _, curcmd in ipairs(cmdlist) do
            if curcmd.name:find(param, 1, true) then
                cmd = curcmd
                if curcmd.name == param then
                    break -- exact match
                end
            end
        end
        if not cmd then
            _G.log_add(error_style, 'No command matches "' .. param .. '"!')
            return
        end
        output = output .. 'Command "' .. cmd.name .. '"\n'
        for _, arg in ipairs(cmd.args) do
            output = output .. '    ' .. arg.name .. ' (' .. arg.type .. ')'
            if arg.optional then
                output = output .. ' (optional)'
            end
            output = output .. '\n'
        end
        if cmd.vararg then
            output = output .. 'This command supports variable arguments.\n'
        end
    end
    _G.log_add('', output)
end

-- Call debug etc function
initialize_script_message('help', help_command_custom)
--- mp.register_script_message('help', help_command_custom)

-- Call debug etc function
initialize_script_message('?', help_command_custom)
--- mp.register_script_message('?', help_command_custom)

--endregion Modded Help

--endregion Help Command

--region script-message alias

---@param s string
---@return  string
local function trim(s)
    return s:match('^()%s*$') and '' or s:match('^%s*(.*%S)')
end

---TODO: Needs to be migrated to final processing chain implementation
---@param  line string
---@return      string, number
local function expand_script_message_alias(line)
    local line = line or ''
    if not line or line == '' then return '' end

    local trimmed_line = trim(line)
    if trimmed_line == '' then return trimmed_line end

    return trimmed_line:gsub('^!%s*', 'script-message ')
end

--endregion script-message alias

--region Pre-Eval Transforms

---
--- Functions stored in this table will be evaluated in order, returning a modified
--- form of the user's command input
---
-- local transforms =
-- {
--     expand_script_message
-- }

--endregion Pre-Eval Transforms

--region Line Editing

-- Insert a character at the current cursor position (any_unicode, Shift+Enter)
local function handle_char_input(c)
    if insert_mode then
        line = line:sub(1, cursor - 1) .. c .. line:sub(next_utf8(line, cursor))
    else
        line = line:sub(1, cursor - 1) .. c .. line:sub(cursor)
    end
    cursor = cursor + #c
    update()
end

--- Process keyboard input event (??)
local function text_input(info)
    if not info.key_text then
        return
    elseif info.event == "press"
        or info.event == "down"
        or info.event == "repeat" then
        handle_char_input(info.key_text)
    end
end

-- Remove the character behind the cursor (Backspace)
local function handle_backspace()
    if cursor <= 1 then return end
    local prev = prev_utf8(line, cursor)
    line = line:sub(1, prev - 1) .. line:sub(cursor)
    cursor = prev
    update()
end

-- Remove the character in front of the cursor (Del)
local function handle_del()
    if cursor > line:len() then return end
    line = line:sub(1, cursor - 1) .. line:sub(next_utf8(line, cursor))
    update()
end

-- Toggle insert mode (Ins)
local function handle_ins()
    insert_mode = not insert_mode
end

-- Clear the current line (Ctrl+C)
local function clear()
    line = ''
    cursor = 1
    insert_mode = false
    history_pos = #history + 1
    update()
end

-- Delete from the cursor to the end of the word (Ctrl+W)
local function del_word()
    local before_cur = line:sub(1, cursor - 1)
    local after_cur = line:sub(cursor)

    before_cur = before_cur:gsub('[^%s]+%s*$', '', 1)
    line = before_cur .. after_cur
    cursor = before_cur:len() + 1
    update()
end

-- Delete from the cursor to the end of the line (Ctrl+K)
local function del_to_eol()
    line = line:sub(1, cursor - 1)
    update()
end

-- Delete from the cursor back to the start of the line (Ctrl+U)
local function del_to_start()
    line = line:sub(cursor)
    cursor = 1
    update()
end

--endregion Line Editing

--region History

--- Go to the specified position in the command history
local function go_history(new_pos)
    local old_pos = history_pos
    history_pos = new_pos

    -- Restrict the position to a legal value
    if history_pos > #history + 1 then
        history_pos = #history + 1
    elseif history_pos < 1 then
        history_pos = 1
    end

    -- Do nothing if the history position didn't actually change
    if history_pos == old_pos then
        return
    end

    -- If the user was editing a non-history line, save it as the last history
    -- entry. This makes it much less frustrating to accidentally hit Up/Down
    -- while editing a line.
    if old_pos == #history + 1 and line ~= '' and history[#history] ~= line then
        history[#history + 1] = line
    end

    -- Now show the history line (or a blank line for #history + 1)
    if history_pos <= #history then
        line = history[history_pos]
    else
        line = ''
    end
    cursor = line:len() + 1
    insert_mode = false
    update()
end

--- Go to the specified relative position in the command history (Up, Down)
local function move_history(amount)
    go_history(history_pos + amount)
end

--endregion History

--region Key Handlers

-- Go to the first command in the command history (PgUp)
local function handle_pgup()
    go_history(1)
end

-- Stop browsing history and start editing a blank line (PgDown)
local function handle_pgdown()
    go_history(#history + 1)
end

local save_preexpanded_line_in_history = false

-- Run the current command and clear the line (Enter)
local function handle_enter()
    local dbg = titled_dbg_msg('handle_enter', 'trace')
    local dbgwarn = titled_dbg_msg('handle_enter', 'warn')

    local line_init = _G.line
    local line_proc = line_init
    dbg(string.format('Console line content at time of enter handle: "%s"', line_init))

    -- Exit immediately if no non-whitespace content
    local line_trimmed = line_init:gsub('^%s+', ''):gsub('%s+$', '')
    if line_trimmed == '' then return end

    -- Record (unprocessed) input line to history if option variable set true
    if save_preexpanded_line_in_history == true and history[#history] ~= line_init then
        history[#history + 1] = line_init
    end

    local eval_fn = console2.eval_line_new
    if type(eval_fn) == "function" then
        dbg('Using extended prompt evaluation')
        dbg(string.format('Eval Input:\n"%s"', line_init))
        local line_eval = eval_fn(line_init)
        -- _G.line = eval_fn(line_init)
        dbg(string.format('Eval Output:\n"%s"', line_new))
        line_proc = line_eval
    end

    --region Command Processing

    --region Help Command

    local override_base_help = true

    --TODO: Move help command and further additions into extracted subfunction
    --      dedicated to any additional processing
    -- match "help [<text>]", return <text> or "", strip all whitespace
    local help = line:match('^%s*help%s+(.-)%s*$')
                  or (line:match('^%s*help$') and '')
    local help_mod = line:match('^%s*help[_-]mod%s+(.-)%s*$')
                      or (line:match('^%s*help[_-]mod$') and '')
    if help_mod then
        msg.debug('Received input for custom help function: "'
            ..tostring(help_mod)..'"')
        help_command_custom(help_mod)
    elseif help then
        if override_base_help then
            msg.debug('Using modified help function. Input: "'..tostring(help)..'"')
            help_command_custom(help_mod)
        else
            help_command(help)
        end
    --endregion Help Command
    else
        dbg('Entered final block.')
        local processed_line, expansion_count = expand_script_message_alias(line_proc)
        if expansion_count and expansion_count > 0 then
            dbg(string.format('Processed ! aliases: %s', dquote(processed_line)))
        end
        if not save_preexpanded_line_in_history or (
               processed_line ~= line_init and  history[#history] ~= processed_line )
        then
            dbg(string.format('Writing processed line to history'))
            -- Push transformed line to history
            if history[#history] ~= processed_line then
                history[#history + 1] = processed_line
            end
        end

        -- Idiot check
        if #processed_line < 1 then
            dbgwarn('Processed line is empty, exiting before execution and display.')
            return
        end

        _G.log_add('{\\1c&H99cc99&}', '  $ ' .. (processed_line) .. "\n")
        mp.command(processed_line)
    end
    --endregion Command Processing

    clear()
end

--endregion Key Handlers

--region Line Navigation

-- Move to the start of the current word, or if already at the start, the start
-- of the previous word. (Ctrl+Left)
local function prev_word()
    -- This is basically the same as next_word() but backwards, so reverse the
    -- string in order to do a "backwards" find. This wouldn't be as annoying
    -- to do if Lua didn't insist on 1-based indexing.
    cursor = line:len() - select(2, line:reverse():find('%s*[^%s]*', line:len() - cursor + 2)) + 1
    update()
end

-- Move to the end of the current word, or if already at the end, the end of
-- the next word. (Ctrl+Right)
local function next_word()
    cursor = select(2, line:find('%s*[^%s]*', cursor)) + 1
    update()
end

-- Move the cursor to the next character (Right)
local function next_char(amount)
    cursor = next_utf8(line, cursor)
    update()
end

-- Move the cursor to the previous character (Left)
local function prev_char(amount)
    cursor = prev_utf8(line, cursor)
    update()
end

-- Move the cursor to the beginning of the line (HOME)
local function go_home()
    cursor = 1
    update()
end

-- Move the cursor to the end of the line (END)
local function go_end()
    cursor = line:len() + 1
    update()
end

--endregion Line Navigation

--region Completion

--region Completion Value Enumeration

---
--- Store defined script messages for completion value generation
---
---@type string[]
local function build_script_message_completions()

    ---@type CompletionList
    local completions = { }

    -- Found message names in console script
    if type(_G.script_message_names) == "table" then
        -- Iterate through declared script messages
        for _, name in ipairs(_G.script_message_names) do
            completions[#completions + 1] = name
        end
    end

    -- Found message names in other scripts
    if type(_G.external_script_message_names) == "table" then
        -- Iterate through declared script messages
        for _, name in ipairs(_G.external_script_message_names) do
            completions[#completions + 1] = name
        end
    end

    msg.trace(string.format('[build_script_message_completions] Generated %i message name completions.', #completions))

    return completions
end

---
--- Generate list of available profiles for completions.
---
---@return CompletionList
local function build_profile_completions()
    msg.trace('[build_profile_completions] Building profile completion list')

    ---@type string[]
    local profile_completions = {}
    ---@type MpvProfile[]
    local raw_profiles = mp.get_property_native('profile-list')

    for
        ---@type number
        _,
        ---@type MpvProfile
        profile in ipairs(raw_profiles) do
        if profile.name then
            profile_completions[#profile_completions + 1] = profile.name
        else
            msg.warn('  [Entry in profile list missing name]')
        end
    end

    return profile_completions
end

---
--- Generate list of macro symbol completions
---
---@return CompletionList
local function build_macro_completions()
    -- msg.trace('[build_macro_completions] Building macro completion list')

    ---@type CompletionList
    local macro_comps = { }

    if console2.macros then
        local macro_symbols = { }
        for symbol in pairs(console2.macros) do
            macro_symbols[#macro_symbols + 1] = symbol
        end

        -- msg.trace('[build_macro_completions] Building ' .. tostring(#macro_symbols) .. ' macro completions')

        for _, symbol in ipairs(macro_symbols) do
            if type(symbol) == "string" then
                macro_comps[#macro_comps + 1] = symbol
            end
        end
    end

    return macro_comps
end

---
--- Generate list of macro symbol completions
---
---@return CompletionList
local function build_prop_completions()
    local option_info =
    {
        'name', 'type', 'set-from-commandline',
        'set-locally',  'default-value',
        'min',  'max',  'choices',
    }

    ---@type string[]
    local raw_prop_list = mp.get_property_native('property-list')

    ---@type string[]
    local prop_list = raw_prop_list

    for _, opt in ipairs(mp.get_property_native('options')) do
        prop_list[#prop_list + 1] = 'options/' .. opt
        prop_list[#prop_list + 1] = 'file-local-options/' .. opt
        prop_list[#prop_list + 1] = 'option-info/' .. opt
        for _, p in ipairs(option_info) do
            prop_list[#prop_list + 1] = 'option-info/' .. opt .. '/' .. p
        end
    end

    msg.trace(string.format('Built %i property completions.', #prop_list))

    return prop_list
end

---@return Completions
local function build_completers()
    -- Build a list of commands, properties and options for tab-completion
    local cmd_list = {}
    for i, cmd in ipairs(mp.get_property_native('command-list')) do
        cmd_list[i] = cmd.name
    end

    ---@type CompletionList
    local prop_list           = build_prop_completions()           or { }
    ---@type CompletionList
    local profile_list        = build_profile_completions()        or { }
    ---@type CompletionList
    local macro_list          = build_macro_completions()          or { }
    ---@type CompletionList
    local script_message_list = build_script_message_completions() or { }

    --region Pattern Components

    local prefix =
    {
        set              = '^%s*set%s+',
        set_profile      = '^%s*set%s+profile%s+',
        add              = '^%s*add%s+',
        cycle            = '^%s*cycle%s+',
        cycle_values     = '^%s*cycle[-]values%s+',
        multiply         = '^%s*multiply%s+',
        script_msg       = '^%s*script-message%s+',
        script_msg_alias = '^%s*!%s+',
    }

    local token_char_base = '%w_/-'
    -- Base pattern for matching active completion range
    local token      = '[' .. token_char_base .. ']*'
    -- Only match for completion with at least beginning character
    local token_part = '[' .. token_char_base .. ']+'

    local bracket_begin = '[%$]{'

    --endregion Pattern Components

    ---@type Completions
    local completions = {
        { pattern = '^%s*()[%w_-]+()$', list = cmd_list, append = ' ' },

        -- Macros
        -- First token on line
        { pattern = '^[%s]*#()'.. '[^#%s]*' ..'()$', list = macro_list, append = ' ' },
        -- @TODO: Confirm below works for  flexible completion positions
        --        (like `${...` has)
        { pattern = '[%s]+#()'.. '[^#%s]*' ..'()$',  list = macro_list, append = ' ' },

        -- Profiles
        { pattern = prefix.set_profile ..  [[()]] .. token .. '()$',       list = profile_list, append = ' '  },
        { pattern = prefix.set_profile .. [["()]] .. token .. '()$',       list = profile_list, append = '" ' },
        { pattern = prefix.set_profile .. [['()]] .. token .. '()$',       list = profile_list, append = "' " },
        { pattern = prefix.set_profile .. bracket_begin .. '()[^}%s]*()$', list = profile_list, append = '}'  },

        -- Prop => set
        { pattern = prefix.set ..  [[()]] .. token_part .. '()$', list = prop_list, append = ' '    },
        { pattern = prefix.set .. [["()]] .. token_part .. '()$', list = prop_list, append = '" '   },
        { pattern = prefix.set .. [['()]] .. token_part .. '()$', list = prop_list, append = [[' ]] },

        -- Prop => add
        { pattern = prefix.add ..  [[()]] .. token_part .. '()$', list = prop_list, append = ' '  },
        { pattern = prefix.add .. [["()]] .. token_part .. '()$', list = prop_list, append = '" ' },

        -- Prop => cycle-values
        { pattern = prefix.cycle_values ..  [[()]] .. token_part .. '()$', list = prop_list, append = ' '  },
        { pattern = prefix.cycle_values .. [["()]] .. token_part .. '()$', list = prop_list, append = '" ' },

        -- Prop => cycle
        { pattern = prefix.cycle ..  [[()]] .. token_part .. '()$', list = prop_list, append = ' '  },
        { pattern = prefix.cycle .. [["()]] .. token_part .. '()$', list = prop_list, append = '" ' },

        -- Prop => multiply
        { pattern = prefix.multiply ..  [[()]] .. token_part .. '()$', list = prop_list, append = ' '  },
        { pattern = prefix.multiply .. [["()]] .. token_part .. '()$', list = prop_list, append = '" ' },

        -- Script Message Name => script-message
        { pattern = prefix.script_msg       ..  [[()]] .. token_part .. '()$', list = script_message_list, append = ' '  },
        { pattern = prefix.script_msg       .. [["()]] .. token_part .. '()$', list = script_message_list, append = '" ' },

        -- For alias (e.g. the line `! type "string"`)
        { pattern = prefix.script_msg_alias ..  [[()]] .. token .. '()$', list = script_message_list, append = ' '  },
        { pattern = prefix.script_msg_alias .. [["()]] .. token .. '()$', list = script_message_list, append = '" ' },

        { pattern = bracket_begin .. [[()]] .. token_part .. '()$', list = prop_list, append = '}' },
    }

    return completions
end

--endregion Completion Value Enumeration

---
--- Extended form of completion function that returns a tuple of the exact
--- match (if found) and all completions prefixed with input part
---
---@param part string
---@param list string[]
function get_all_completions(part, list)
    ---@type string | nil
    local completion = nil
    ---@type string | nil
    local exact = nil
    ---@type string[]
    local partials = {}

    for _, candidate in ipairs(list) do
        if candidate:starts_with(part) then
            -- If completion value does not exactly equal the input part (part is prefix of completion)
            if candidate ~= part then
                ---@type number
                table.insert(partials, candidate)
            else
                exact = candidate
            end
        else
        end
    end

    return exact, partials
end

---
--- Use 'list' to find possible tab-completions for 'part.' Returns the longest
--- common prefix of all the matching list items and a flag that indicates
--- whether the match was unique or not.
---
---@param part string
---@param list CompletionList
---@return string, boolean
local function complete_match(part, list)
    local completion = nil
    local full_match = false

    for _, candidate in ipairs(list) do
        if candidate:sub(1, part:len()) == part then
            if completion and completion ~= candidate then
                local prefix_len = part:len()
                while completion:sub(1, prefix_len + 1)
                       == candidate:sub(1, prefix_len + 1) do
                    prefix_len = prefix_len + 1
                end
                completion = candidate:sub(1, prefix_len)
                full_match = false
            else
                completion = candidate
                full_match = true
            end
        end
    end

    return completion, full_match
end

--region Main Completion Function

-- Complete the option or property at the cursor (TAB)
local function complete()
    ---@type string
    local before_cur = line:sub(1, cursor - 1)
    ---@type string
    local after_cur = line:sub(cursor)

    -- If line is empty or cursor is immediately proceeding a statement
    -- terminating `;` then just complete commands

    -- Try the first completer that works
    for
        ---@type number
        _,
        ---@type CompletionSet
        completer
            in ipairs(build_completers()) do
        -- Completer patterns should return the start and end of the word to be
        -- completed as the first and second capture groups
        local _, _, start_idx, e = before_cur:find(completer.pattern)
        if not start_idx then
            -- Multiple input commands can be separated by semicolons, so all
            -- completions that are anchored at the start of the string with
            -- '^' can start from a semicolon as well. Replace ^ with ; and try
            -- to match again.
            _, _, start_idx, e = before_cur:find(completer.pattern:gsub('^^', ';'))
        end
        if start_idx then
            -- If the completer's pattern found a word, check the completer's
            -- list for possible completions
            local part = before_cur:sub(start_idx, e)
            local completed, full = complete_match(part, completer.list)
            if completed then
                -- If there was only one full match from the list, add
                -- completer.append to the final string. This is normally a
                -- space or a quotation mark followed by a space.
                if full and completer.append then
                    completed = completed .. completer.append

                -- Else display all partial matches
                else


                    local _, partials = get_all_completions(part, completer.list)
                    msg.trace('Completion had ' .. #partials .. ' partial completions.')
                    local partials_to_complete = partials
                    if #partials_to_complete > 0 then
                        -- Used as reference and as storage if limit is hit.

                        -- @TODO: Make some of these params user configurable

                        -- Formatting
                        local comp_style = '{\\1c&HCCCCCC&}'
                        local comp_header_style = '{\\1c&H33CC55&}'  -- comp_style -- w'{\\1c&H33CC45&}'

                        -- Control completion bounds (-1 to disable)
                        ---@type number
                        local comp_fragment_limit = -1 -- 80
                        --- Defaults to disabled (for -1 case)
                        ---@type boolean
                        local comp_hit_fragment_limit = false
                        --- Only update if actually a valid limit
                        if comp_fragment_limit > 0 then
                            comp_hit_fragment_limit = (#partials_to_complete > comp_fragment_limit)
                        end

                        if comp_hit_fragment_limit then
                            -- msg.trace('Hit completion fragment limit, reducing.')
                            -- To complete partial count reduction

                            -- msg.trace('Over partial completion limit by ' .. tostring(comp_fragment_limit - #partials_to_complete) .. 'partials.')
                            local limited_partials = {}
                            local fragment_idx = 0
                            while fragment_idx <= comp_fragment_limit do
                                table.insert(limited_partials, fragment_idx, partials_to_complete[fragment_idx])
                                fragment_idx = fragment_idx + 1
                            end
                            partials_to_complete = limited_partials
                            msg.trace('Reduced completions table to ' .. #partials_to_complete .. ' partials.')
                        else
                            msg.trace('Completion fragment limit not reached or disabled.')

                            -- Anything required if no reduction in partials
                            partials_to_complete = partials

                            msg.trace('Total partials: ' .. #partials_to_complete)
                        end

                        -- Add heading to completion list
                        -- @TODO: Why doesn't this work?
                        _G.log_add(comp_header_style, 'Completions:')
                        -- log_add('', "\n")

                        local pad_amount = 18

                        msg.trace('Checking for longest of ' .. #partials .. ' partial completions.')

                        -- @TODO: Remove this sanity check after this is working
                        --        for awhile—for some reason longest was receiving
                        --        and empty array for awhile.
                        -- if #partials_to_complete > 1 then
                        -- -- Nevermind, moved to outer block

                        -- Get longest result for calculating padding
                        local longest, longest_length = longest(partials_to_complete)
                        if longest and longest_length > 0 then
                            pad_amount = #longest + 3
                        end
                        local last_idx = 3
                        local idx      = 0
                        local curr     = ''

                        for _, partial in ipairs(partials_to_complete) do
                            idx  = idx + 1
                            curr = curr .. partial:pad_right(pad_amount, ' ')
                            if idx >= last_idx then
                                _G.log_add(comp_style, '\n' .. curr)
                                curr = ''
                                idx = 0
                            end
                            -- if idx == last_idx then
                            -- end
                        end
                        -- Add the remaining two completion values if not
                        -- logged yet
                        if #curr > 0 then
                            _G.log_add(comp_style,   '\n' .. curr .. '\n')
                        else
                            _G.log_add('', "\n\n")
                        end

                        -- Always add eol
                    end
                end


                -- Insert the completion and update
                before_cur = before_cur:sub(1, start_idx - 1) .. completed
                cursor = #before_cur + 1
                line   = before_cur .. after_cur
                update()
                return
            end
        end
    end
end

--endregion Main Completion Function

--endregion Completion

--region Clipboard Access

--- Returns a string of UTF-8 text from the clipboard (or the primary selection)
local function get_clipboard(clip)
    mp.msg.trace('[get_clipboard] Checking for clipboard procedure for current platform: ' .. tostring(platform))
    if platform == 'x11' then
        ---@type Subprocess
        local res = utils.subprocess({
            args = { 'xclip', '-selection', clip and 'clipboard' or 'primary', '-out' },
            playback_only = false,p
        })
        if not res.error then
            return res.stdout
        else
            mp.msg.warn('Clipboard command returned error: ' .. tostring(res.error))
        end
    elseif platform == 'windows' then
        local res = utils.subprocess({
            args = { 'powershell', '-NoProfile', '-Command', [[& {
                Trap {
                    Write-Error -ErrorRecord $_
                    Exit 1
                }

                $clip = ""
                if (Get-Command "Get-Clipboard" -errorAction SilentlyContinue) {
                    $clip = Get-Clipboard -Raw -Format Text -TextFormatType UnicodeText
                } else {
                    Add-Type -AssemblyName PresentationCore
                    $clip = [Windows.Clipboard]::GetText()
                }

                $clip = $clip -Replace "`r",""
                $u8clip = [System.Text.Encoding]::UTF8.GetBytes($clip)
                [Console]::OpenStandardOutput().Write($u8clip, 0, $u8clip.Length)
            }]] },
            playback_only = false,
        })
        if not res.error then
            return res.stdout
        else
            mp.msg.warn('Clipboard command returned error: ' .. tostring(res.error))
        end
    elseif platform == 'macos' then
        local macOS_paste_def =
        {
            args = { 'pbpaste' },
            playback_only = false,
        }

        local res = utils.subprocess(macOS_paste_def)
        mp.msg.trace(string.format('[get_clipboard] Using macOS clipboard command: "%s"', table.concat(macOS_paste_def.args)))

        if not res.error then
            return res.stdout
        else
            mp.msg.warn('Clipboard command returned error: ' .. tostring(res.error))
        end
    end

    mp.msg.warn('[get_clipboard] Reached fallthrough after all platform checks.')
    return ''
end

-- Paste text from the window-system's clipboard.
---@param clip boolean | nil @ Determines whether the clipboard or the primary selection buffer is used (on X11 only.)
local function paste(clip)
    local text = get_clipboard(clip)
    local before_cur = line:sub(1, cursor - 1)
    local after_cur = line:sub(cursor)
    line = before_cur .. text .. after_cur
    cursor = cursor + text:len()
    update()
end

--endregion Clipboard Access

--region Keybinding Management

-- List of input bindings. This is a weird mashup between common GUI text-input
-- bindings and readline bindings.
local function get_bindings()
    local bindings =
    {
        { 'esc',         function() set_active(false) end       },
        { 'enter',       handle_enter                           },
        { 'kp_enter',    handle_enter                           },
        { 'shift+enter', function() handle_char_input('\n') end },
        { 'bs',          handle_backspace                       },
        { 'shift+bs',    handle_backspace                       },
        { 'del',         handle_del                             },
        { 'shift+del',   handle_del                             },
        { 'ins',         handle_ins                             },
        { 'shift+ins',   function() paste(false) end            },
        { 'mbtn_mid',    function() paste(false) end            },
        { 'left',        function() prev_char() end             },
        { 'right',       function() next_char() end             },
        { 'up',          function() move_history(-1) end        },
        { 'wheel_up',    function() move_history(-1) end        },
        { 'down',        function() move_history(1) end         },
        { 'wheel_down',  function() move_history(1) end         },
        { 'wheel_left',  function() end                         },
        { 'wheel_right', function() end                         },
        { 'ctrl+left',   prev_word                              },
        { 'ctrl+right',  next_word                              },
        { 'tab',         complete                               },
        { 'home',        go_home                                },
        { 'end',         go_end                                 },
        { 'pgup',        handle_pgup                            },
        { 'pgdwn',       handle_pgdown                          },
        { 'ctrl+c',      clear                                  },
        { 'ctrl+d',      close_console_if_empty                 },
        { 'ctrl+k',      del_to_eol                             },
        { 'ctrl+l',      clear_log_buffer                       },
        { 'ctrl+u',      del_to_start                           },
        { 'ctrl+v',      function() paste(true) end             },
        { 'meta+v',      function() paste(true) end             },
        { 'ctrl+w',      del_word                               },
        { 'Ctrl+BS',     del_word                               },
        { 'Alt+BS',      del_word                               },
        { 'kp_dec',      function() handle_char_input('.') end  },
    }

    for i = 0, 9 do
        bindings[#bindings + 1] =
            {'kp' .. i, function() handle_char_input('' .. i) end}
    end

    return bindings
end

function define_key_bindings()
    if #key_bindings > 0 then
        return
    end
    for _, bind in ipairs(get_bindings()) do
        -- Generate arbitrary name for removing the bindings later.
        local name = "_console_" .. (#key_bindings + 1)
        key_bindings[#key_bindings + 1] = name
        mp.add_forced_key_binding(bind[1], name, bind[2], {repeatable = true})
        msg.trace(string.format('[define_key_bindings] Defined keybind id: %s', name))
    end
    mp.add_forced_key_binding("any_unicode", "_console_text", text_input,
        {repeatable = true, complex = true})
    key_bindings[#key_bindings + 1] = "_console_text"
end

function undefine_key_bindings()
    for _, name in ipairs(key_bindings) do
        mp.remove_key_binding(name)
    end
    key_bindings = {}
end

--endregion Keybinding Management

-- Add a global binding for enabling the Console. While it's enabled, its bindings
-- will take over and it can be closed with ESC.
mp.add_key_binding(nil, 'enable', function() set_active(true) end)

-- Add a script-message to show the Console and fill it with the provided text
function type_script_message(text, immediate)
    local dbg = titled_dbg_msg('!type', 'debug')

    dbg(string.format('Entered type script-message handler, calling show_and_type with text:\n"%s"', text))

    show_and_type(typed, immedidate)
end
initialize_script_message('type', type_script_message)

-- Redraw the Console when the OSD size changes. This is needed because the
-- PlayRes of the OSD will need to be adjusted.
mp.observe_property('osd-width',           'native', update)
mp.observe_property('osd-height',          'native', update)
mp.observe_property('display-hidpi-scale', 'native', update)

-- Enable log messages. In silent mode, mpv will queue log messages in a buffer
-- until enable_messages is called again without the silent: prefix.
mp.enable_messages('silent:terminal-default')

local script_name =  mp.get_script_name()
---@param e LogEventTable
function ingest_log_message(e)
    -- Ignore log messages from the OSD because of paranoia, since writing them
    -- to the OSD could generate more messages in an infinite loop.
    if e.prefix:sub(1, 3) == 'osd' then return end

    -- Ignore messages output by this script.
    if e.prefix == script_name then return end

    -- Ignore buffer overflow warning messages. Overflowed log messages would
    -- have been offscreen anyway.
    if e.prefix == 'overflow' then return end

    -- Filter out trace-level log messages, even if the terminal-default log
    -- level includes them. These aren't too useful for an on-screen display
    -- without scrollback and they include messages that are generated from the
    -- OSD display itself.
    if e.level == 'trace' then return end

    -- Use color for debug/v/warn/error/fatal messages. Colors are stolen from
    -- base16 Eighties by Chris Kempson.
    local style = ''
    if e.level == 'debug' then
        style = '{\\1c&Ha09f93&}'
    elseif e.level == 'v' then
        style = '{\\1c&H99cc99&}'
    elseif e.level == 'warn' then
        style = '{\\1c&H66ccff&}'
    elseif e.level == 'error' then
        style = '{\\1c&H7a77f2&}'
    elseif e.level == 'fatal' then
        style = '{\\1c&H5791f9&\\b1}'
    end

    _G.log_add(style, '[' .. e.prefix .. '] ' .. e.text)
end

mp.register_event('log-message', ingest_log_message)

collectgarbage()

--region Debugging

--region VSCode: Error thrower to test problem matching in console output

-- @TODO: Error stack's script paths are truncated enough to break resolving
--        error location in problem matching, figure out how to show full paths

---
--- Exit script, loudly
---
function quit_by_error()
    local lolbye = utils.file_info( nil ).is_dir
end

initialize_script_message('exit', function() quit_by_error() end)

---
--- Restart script by loading another instance and then throwing error in current instance
---
function console_restart()
    local cmd = [[ load-script ~~/scripts/console/console.lua ]]
    mp.command(cmd)
    quit_by_error()
end

--endregion VSCode: Error thrower to test problem matching in console output

--endregion Debugging

--region Post-init

-- Prompt that alternate console script loaded
_G.log_add('{\\1c&H22CC00&\\b1}', 'Extended console loaded.')

--endregion Post-init

-- quick test
-- local af = {
--     info = mp.get_property_native('option-info/af', false)
-- }
-- if af.info then
--     msg.info('af (Audio Filter) object info:\n'
--                 .. utils.format_json(af.info)
--                 .. '\n' .. utils.format_json(af.info.choices) )
-- end

--region build_completers - Unused Partial Implementations


-- (Unused atm)
---@param  content string
---@return         string
--- function bracketed(content)
---    if type(content) == "string" then
---        return
---    else
---        return
---    end
--- end

---
--- Build a token pattern with additional character classes. Use of `]` and
--- `^` should be escaped (`%]`)
---
---@param  chars string
---@return       string
--- -- local function token_with(chars)
--- --     if type(chars) ~= "string" then
--- --         return token
--- --     else
--- --         return '[' .. token_char_base .. chars .. ']*'
--- --     end
--- -- end
---
--- ---
--- --- Build a completion description table, and optionally immediately append
--- --- to the result table instead of returning if `target` table passed.
--- ---
--- ---@overload fun(pattern: string, list: CompletionList, append: string, target: CompletionList)
--- ---@overload fun(pattern: CompletionCompArgTable): CompletionSet
--- ---@overload fun(pattern: CompletionCompArgTableTargeted)
--- ---@param  pattern string
--- ---@param  list    CompletionList
--- ---@param  append  string | nil
--- ---@return         CompletionSet
--- local function prop_comp(pattern, list, append)
---     -- Handle alternate syntax (prop_comp{pattern = ...})
---     if type(pattern) == "table"
---         and pattern.list
---         and pattern.append
---         and pattern.pattern
---     then
---         -- [typesystem incantations]
---         ---@type CompletionCompArgTable | CompletionCompArgTableTargeted
---         local pattern = pattern
---
---         list   = pattern.list
---         append = pattern.append
---         target = type(pattern.target) and pattern.target or nil
---         -- Have to do this last to avoid wiping other values
---         pattern = pattern.pattern
---     end
---
---     ---@type CompletionSet
---     local comp =
---     {
---         pattern = pattern,
---         list    = list,
---         append  = append
---     }
---
---     if type(target) == "table" then
---         target[#target + 1] = comp
---         return
---     else
---         return comp
---     end
--- end

--endregion build_completers - Unused Partial Implementations
