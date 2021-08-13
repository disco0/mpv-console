--region Source copyright
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
--endregion Source copyright

--region Init

---@type mp
local mp = require('mp')

mp.msg.info('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
mp.msg.info('~~             Loading Extended Console             ~~')
mp.msg.info('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')

--region package.path

--[[

mpv Package Path Patcher

@version 1.0.0

@description Extends and normalizes package path for mpv scripts.

The following examples use the script directory: `/Users/<User>/.config/mpv/scripts`

An example of package path before and after for a script _file_ in the base script directory (scripts
loaded as a directory will

```
loading file /Users/disk0/.config/mpv/scripts/<script>.lua
[package.path] Initial package.path:
    /usr/local/Cellar/luajit-openresty/20210510/share/luajit-2.1.0-beta3/?.lua
    /usr/local/share/lua/5.1/?.lua
    /usr/local/share/lua/5.1/?/init.lua
    /usr/local/Cellar/luajit-openresty/20210510/share/lua/5.1/?.lua
    /usr/local/Cellar/luajit-openresty/20210510/share/lua/5.1/?/init.lua
[package.path] Updated package.path:
  /Users/disk0/.config/mpv/scripts/?.lua
  /Users/disk0/.config/mpv/scripts/console/?.lua
  /usr/local/Cellar/luajit-openresty/20210510/share/luajit-2.1.0-beta3/?.lua
  /usr/local/share/lua/5.1/?.lua
  /usr/local/share/lua/5.1/?/init.lua
  /usr/local/Cellar/luajit-openresty/20210510/share/lua/5.1/?.lua
  /usr/local/Cellar/luajit-openresty/20210510/share/lua/5.1/?/init.lua
```

]]--

--region Configuration

---
--- Array of additional subdirectories (in mpv scripts directory) that will be appended after
--- default additions.
---
--- @TODO: Actually make it do this
---
local additional_subdirectories =
{
    "utils"
}

--endregion Configuration

-- (Pulled out of do loop for completing script paths for load-script)

--- Resolves user mpv config path, checking the following environment variables (in order):
---
--- `MPV_HOME`: `$MPV_HOME/`
---
--- `XDG_CONFIG_HOME`: `$XDG_CONFIG_HOME/mpv/`
---
--- `HOME`: `$HOME/.config/mpv/`
---
---@param  no_cache boolean | nil
---@return          string  | nil
local get_mpv_config_dir

do

    ---@type string
    local resolved_mpv_config_base = nil
    get_mpv_config_dir = function (no_cache)
        if type(resolved_mpv_config_base) == "string" and #resolved_mpv_config_base > 0
        then
            return resolved_mpv_config_base
        else
            local env_fmt_lut =
            {
                { 'MPV_HOME',        '%s'             },
                { 'XDG_CONFIG_HOME', '%s/mpv'         },
                { 'HOME',            '%s/.config/mpv' }
            }
            ---@type string
            local value = nil

            for _, env_map in ipairs(env_fmt_lut) do
                value = os.getenv(env_map[1])
                if type(value) == 'string' and #value > 0 then
                    resolved_mpv_config_base = string.format(env_map[2], value)
                    return resolved_mpv_config_base
                end
            end
        end
    end

    ---
    --- Get full path of mpv script using native lua introspection becuase there's no way to do it
    --- via scripting API (or I've failed to find it, leaning on the latter)
    ---
    local function script_path_rawget()
        local info = require('debug').getinfo(1, 'S')

        return info.source or [[<UNKNOWN PATH>]]
    end

    ---
    --- Debug log for package.path patching block
    ---@param  msg string
    ---@vararg     any
    ---@return     nil
    local function log(msg, ...)
        if not msg or #msg == 0 then mp.msg.debug('[package.path]') return end

        mp.msg.debug('[package.path] ' .. string.format(msg, ...))
    end

    ---
    --- Split string containing semicolon delimited paths into array
    ---@param  package_path string | nil
    ---@return              string[]
    local function get_package_paths(package_path)
        -- Default to relevant target if alternative not provided
        if type(package_path) ~= 'string' or #package_path < 1 then
            package_path = package.path
        end

        if type(package_path) ~= 'string' or #package_path < 1 then
            error(string.format(
                '[get_package_paths] package.path or package_path parameter is not a string, or is empty (value: %s = "%s"',
                    type(package_path),
                    tostring(package_path)
            ))
        end

        ---@type string[]
        local paths = { }

        do
            ---@param  first string
            ---@return       nil
            local function add_path_match(first) table.insert(paths, first) end

            package_path:gsub( "([^;]+)([;]?)", add_path_match )
        end

        return paths
    end

    local function package_path_fix()

        log('Initial package.path:%s',
            package.path:gsub(';', "\n  "):gsub('^', "\n  ") )

        ---@type string[]
        local package_paths = get_package_paths()

        local mpv_script_dir  = get_mpv_config_dir()
        local script_name     = mp.get_script_name()
        local raw_script_path = script_path_rawget() or ''
        -- Used later to check if script is file/directory based
        local raw_script_dir  = raw_script_path:gsub('[/\\]?[^/\\]+%.lua$', '')

        if not(type(mpv_script_dir) == "string" and #mpv_script_dir > 0)
        then
            mp.msg.warn(string.format(
                '[package.path] Failed to resolve mpv configuration path: (mpv_base?: %s => %s)',
                type(mpv_script_dir),
                tostring(mpv_script_dir)
            ))
            return
        end

        local mpv_script_path = mpv_script_dir .. "/scripts/"
        local paths           = mpv_script_path .. '?.lua;'

        -- Check if script directory based and append base mpv script directory _after_ script's
        -- own directory (expected to be first path in package.path)
        ---@type number
        local script_dir_path_index = -1
        -- Check if raw script path is <script-name>/{<script-name>,main}.lua
        if  raw_script_path:find(script_name .. '/' .. script_name .. '.lua') or
            raw_script_path:find(script_name .. '/main.lua')
        then
            -- Find index of script's directory
            paths = mpv_script_path .. script_name .. '/?.lua;' .. paths

        end

        _G.package.path =
            -- ~~/scripts/?.lua
            -- [~~/scripts/<script-dir>/?.lua]
            paths ..
            -- Initial package.path
            _G.package.path

        log('Updated package.path:%s',
            -- Split on separator and indent each path
            package.path:gsub(';', "\n  "):gsub('^', "\n  ") )

        return
    end

    package_path_fix()
end

--endregion package.path

--region Imports

---@type utils
local utils = require('mp.utils')
---@type options
local options = require('mp.options')
---@type assdraw
local assdraw = require('mp.assdraw')

local logging = require('logging')
local Prefix = logging.Prefix
local msg    = logging.msg

local Const = require('constants')

-- Builtin Utils
-- require('console/console-builtin-extensions')
require('builtin-extensions-global')

--- `script-message` Tracking
local script_messages = require('script-message-tracker')

-- Additional console functionality
local console_ext = require('console-extensions')

local history = require('history')
local Perf    = require('perf').Perf

--endregion Imports

--region Localize

local format = string.format

--endregion Localize

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

    if total < 1
    then
        error('Invalid array count: ' .. tostring(total))
        return
    end

    local curr_longest =
    {
        index  = 0,
        value  = "",
        length = -1
    }

    while idx <= total
    do
        -- msg.trace('[longest] Element #' .. tostring(idx))
        ---@type string
        local idx_value  = str_arr[idx]
        -- msg.trace('[longest]  Value: ' .. tostring(idx_value))

        -- Check if value is invalid (non-string or empty)
        if type(idx_value) == "string"
        then

            --region Main Loop Processing

            if #idx_value > 0
            then
                ---@type number
                local idx_value_length = #idx_value
                if idx_value_length > curr_longest.length
                then
                    -- Record new longest
                    curr_longest =
                    {
                        index  = idx,
                        value  = idx_value,
                        length = idx_value_length
                    }
                end

            --endregion Main Loop Processing

            else
                -- msg.debug('Zero length string in array, index #' .. tostring(idx))
            end
        -- Handle invalid, skip warning for empty strings
        elseif idx_value == nil
        then
            -- msg.warn('[longest] Value of element string array is nil (tostring: "'.. tostring(idx_value) ..'" => '.. type(idx_value) ..')')
        elseif type(idx_value) ~= "string"
        then
            -- msg.warn('[longest] Value of element string array is not a string, or nil (tostring: "'.. tostring(idx_value) ..'" => '.. type(idx_value) ..')')
        end
        idx = idx + 1
    end

    return curr_longest.value, curr_longest.length
end

--endregion Arrays

--region Initialize Options

local Platforms = Const.platforms

-- Get better font per user operating system
---@param platform MpvPlatform
local function default_system_font(platform)
    platform = (Platforms[platform] ~= nil)
        and platform
        or Const.platform

    if platform == 'windows'
    then
        return 'Consolas'
    elseif platform == 'macos'
    then
        return 'Menlo'
    else -- default (wayland | x11)
        return 'monospace'
    end
end

-- Default options
-- (Made global for extensions subscript)
_G.opts =
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

    -- Display total history entries/position in history in prompt prefix
    prompt_hist_pos = true,
}

-- Apply user-set options
options.read_options(opts)

--endregion Initialize Options

--endregion Init

--region Script Global State

--region Forward Declares

_G.handle_enter = nil

--endregion Forward Declares

--region Refactoring to ptty.lua

---@type boolean
_G.console_active = false
---@type boolean
_G.pending_update = false
---@type string
_G.line = ''
---@type number
_G.cursor = 1
---@type LogRecord[]
_G.log_buffer = { }
---@type number
_G.global_margin_y = 0
_G.buffer_line_max = 100

--endregion Refactoring to ptty.lua

--region Refactoring to history.lua

---@type string[]
_G.history_orig = { }
---@type number
_G.history_pos = -1

--endregion Refactoring to history.lua

_G.key_bindings = { }
---@type boolean
_G.insert_mode = false

_G.update_timer = mp.add_periodic_timer(0.05, function()
    if _G.pending_update
    then
        _G.update()
    else
        _G.update_timer:kill()
    end
end)

--endregion Script Global State

_G.update_timer:kill()

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
    _G.update()
end)

--region Console Output

---
--- Basic form of log line entry that
---
---@class LogLine
---@field style string
---@field text  string

---
--- Extended form of basic log line that allows for multiple alternating style
--- and text values
---
---@alias DetailedLogLine LogLine[]

---
--- All forms of log entries—each counts as one towards the maximum stored
---
---@alias LogRecord LogLine | DetailedLogLine

---
--- Append last log entry's text instead of writing a new entry.
---
---@param text   string
---@param update boolean
function _G.log_edit(text, update)
    local curr_item = log_buffer[#log_buffer + 1]
    curr_item.text = curr_item.text .. text

    if type(update) == 'boolean' and update == true
    then
        if _G.console_active
        then
            if not _G.update_timer:is_enabled()
            then
                _G.update()
                _G.update_timer:resume()
            else
                _G.pending_update = true
            end
        end
    end
end

-- local default_console_color = 'CCCCCC'
---
--- Add a plain line to the log buffer (which is limited to 100 lines, by default)
---
---@param  text  string
---@return       nil
function _G.log_add_plain(text)
    log_buffer[#log_buffer + 1] = { style = '', text = text }
    if #log_buffer > buffer_line_max
    then
        table.remove(log_buffer, 1)
    end
end


---
--- Add a line to the log buffer (limited to 100 lines by default)
---
---@param  style  string
---@param  text   string
---@param  defer? boolean
---@return        nil
function _G.log_add(style, text, defer)
    _G.log_buffer[#_G.log_buffer + 1] = { style = style, text = text }
    if #_G.log_buffer > _G.buffer_line_max
    then
        -- @NOTE: If this code gets reworked/used for a general, multi-buffer entry case make sure
        --        to also handle the removals correctly (e.g. not hardcoded to 1)
        table.remove(log_buffer, 1)
    end

    if defer == true or not _G.console_active then return end

    if not _G.update_timer:is_enabled()
    then
        _G.update()
        _G.update_timer:resume()
    else
        _G.pending_update = true
    end
end

---
--- Add a new line to the log buffer using extended styling
---
---@param  entry DetailedLogLine
---@param  wait  boolean | nil
---@return       nil
function _G.log_add_advanced(entry, wait)
    _G.log_buffer[#_G.log_buffer + 1] = entry -- { style = style, text = text }
    if #_G.log_buffer >  _G.buffer_line_max
    then
        table.remove(_G.log_buffer, 1)
    end

    if wait == true
    then
        -- no-redraw
    elseif _G.console_active
    then
        if not _G.update_timer:is_enabled()
        then
            _G.update()
            _G.update_timer:resume()
        else
            _G.pending_update = true
        end
    end
end

--- Stores common LogLine fragments, for use with `log_add_advanced`.
local LOG_FRAGMENT =
{
    NEW_LINE = { text = "\n", style = "" }
}

--- Empty the log buffer of all messages (`Ctrl+l`)
local function clear_log_buffer()
    _G.log_buffer = {}
    _G.update()
end

--region Util

-- (Defines unimplemented escaping control for output subs)
---@class AssEscapeOptions
---@field slash         boolean?
---@field brackets      boolean?
---@field newline       boolean?
---@field leading_space boolean?

local ASS_CHAR =
{
    -- Zero-width non-breaking space
    ZWNBSP      = '\239\187\191',
    NEW_LINE    = '\\N',
    HARD_SPACE = '\\h'
}

---
--- Escape a string `str` for verbatim display on the OSD
---
---@param  str string
---@return     string
local function ass_escape(str, no_escape)

    local disable = type(no_escape) == "table" and no_escape or { }

    ---@type string
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
function _G.update()
    _G.pending_update = false

    local dpi_scale = mp.get_property_native("display-hidpi-scale", 1.0)

    dpi_scale = dpi_scale * _G.opts.scale

    local screenx, screeny, aspect = mp.get_osd_size()
    screenx = screenx / dpi_scale
    screeny = screeny / dpi_scale

    -- Clear the OSD if the Console is not active
    if not console_active
    then
        mp.set_osd_ass(screenx, screeny, '')
        return
    end

    local ass = assdraw.ass_new()
    local style = format(
        '{\\r\\1a&H00&\\3a&H00&\\4a&H99&\\1c&H%s&\\3c&H111111&\\4c&H000000&\\fn%s\\fs%s\\bord1\\xshad0\\yshad1\\fsp0\\q1}',
        'EEEEEE',
        opts.font,
        opts.font_size
    )

    -- Create the cursor glyph as an ASS drawing. ASS will draw the cursor
    -- inline with the surrounding text, but it sets the advance to the width
    -- of the drawing. So the cursor doesn't affect layout too much, make it as
    -- thin as possible and make it appear to be 1px wide by giving it 0.5px
    -- horizontal borders.
    local cursor_height = opts.font_size * 8
    local cursor_glyph = format(
        '{\\r\\1a&H44&\\3a&H44&\\4a&H99&\\1c&H%s&\\3c&Heeeeee&\\4c&H000000&\\xbord0.5\\ybord0\\xshad0\\yshad1\\p4\\pbo24}m 0 0 l 1 0 l 1 %s l 0 %s{\\p0}',
        'EEEEEE',
        cursor_height,
        cursor_height
    )
    local before_cur = ass_escape(_G.line:sub(1, cursor - 1))
    local after_cur  = ass_escape(_G.line:sub(_G.cursor))

    -- Render log messages as ASS. This will render at most screeny / font_size messages.
    local log_ass = ''
    -- @NOTE: math.ceil only takes one arg?
    local viewable_log_message_count = math.min(#_G.log_buffer, math.ceil(screeny, _G.opts.font_size))

    -- @TODO: Inline function calls if affecting speed
    -- @TODO: Return escaped string to position in line/node buffer and allow the now semi-memoized
    --        value to be passed through again instead of repeatedly processing it. This effectively
    --        adds a third kind of log buffer entry type, the (rendered) string
    --

    ---@param node table<'text' | 'style', string>
    local function process_buffer_node(node)
        -- -- Original
        -- log_ass = log_ass .. style .. node.style .. ass_escape(node.text)

        -- Faster or slower?
        log_ass = string.format('%s%s%s%s', log_ass, style, node.style or '', ass_escape(node.text))

        -- -- Faster or slower?
        -- log_ass = table.concat({log_ass, style, node.style, ass_escape(node.text)}, '')
    end

    for i = #log_buffer - viewable_log_message_count + 1, #log_buffer
    do
        -- Initial plan was going to be determining basic and extended buffer by checking for
        -- text/style table values, followed by an index value and a fallthrough (error) case,
        -- allowing for adding additional cases—if performance is an issue just check for index
        -- key, and assume its basic by default (and deal with new alternates when we get there)

        --
        -- Now have additionally learned that lua literally stores a single reference to any
        -- string used in the program—memoizing this, or possibly just leaning on the
        -- implementation's string storage totality store formatted lines instead of rerendering
        -- them (if that's even actually being done, have to look at this again)
        --

        -- Regular line: Check if item has style / text key
        if type(log_buffer[i].text) == 'string' --[[ or type(log_buffer[i].style) == 'string' ]]
        then
            -- log_ass = log_ass .. style .. node.style .. ass_escape(node.text)
            process_buffer_node(log_buffer[i])

        -- Detailed line: Check for array indicies
        elseif type(log_buffer[i][1]) == 'table'
        then
            local j = 1
            local curr = log_buffer[i][j]
            while curr ~= nil
            do
                process_buffer_node(log_buffer[i][j])
                j = j + 1
                curr = log_buffer[i][j]
            end
        else
            -- Unknown: Explode
            error('[update] Failed to determine type of log entry.')
        end
    end

    ass:new_event()
    ass:an(1)
    ass:pos(2, screeny - 2 - global_margin_y * screeny)
    ass:append(log_ass .. ASS_CHAR.NEW_LINE)

    -- Just content after initial style content of each section–still requires prepending style,
    -- or style + alpha for cursor pass
    -- @NOTE: Special case for drawing history position—if position is one over the history
    --        entry total, assume its the active input buffer, and don't draw.
    local prompt_before_body = style .. '> ' .. before_cur
    if _G.opts.prompt_hist_pos == true and (_G.history_pos ~= #_G.history_orig + 1)
    then
        local hist_len = #_G.history_orig
        local pad_num = tostring(tostring(hist_len):len())
        prompt_before_body = format(
            '[%s/%s] > %s',
            tostring(math.max(0, _G.history_pos)):pad_left(pad_num, '0'),
            tostring(#_G.history_orig):pad_left(pad_num, '0'),
            before_cur
        )
    end
    local prompt_after_body = after_cur

    ass:append(style .. prompt_before_body)
    ass:append(cursor_glyph)
    ass:append(style .. prompt_after_body)

    -- Redraw the cursor with the REPL text invisible. This will make the
    -- cursor appear in front of the text.
    ass:new_event()
    ass:an(1)
    ass:pos(2, screeny - 2 - global_margin_y * screeny)
    ass:append(style .. '{\\alpha&HFF&}' .. prompt_before_body)
    ass:append(cursor_glyph)
    ass:append(style .. '{\\alpha&HFF&}' .. prompt_after_body)

    mp.set_osd_ass(screenx, screeny, ass.text)
end

-- Set the Console visibility ("enable", Esc)
local function set_active(active)
    if active == _G.console_active then return end
    if active
    then
        _G.console_active = true
        insert_mode = false
        mp.enable_key_bindings('console-input', 'allow-hide-cursor+allow-vo-dragging')
        mp.enable_messages('terminal-default')
        _G.define_key_bindings()
    else
        _G.console_active = false
        _G.undefine_key_bindings()
        mp.enable_messages('silent:terminal-default')
        collectgarbage()
    end
    _G.update()
end

local log = msg.extend('show_and_type')
---
--- Show the repl if hidden and replace its contents with 'text'. Additionally
--- input can be executed immediately if second argument passed `true`.
--- (script-message-to repl type)
---
---@param  text             string
---@param  eval_immediately boolean | nil
local function show_and_type(text, eval_immediately)
    text = type(text) == 'string' and text or ''

    if type(eval_immediately) ~= "boolean"
    then
        eval_immediately = false
    end

    -- Save the line currently being edited, just in case
    if _G.line ~= text
       and _G.line ~= ''
       -- and history.last ~= _G.line
       and _G.history_orig[#_G.history_orig] ~= _G.line
    then
        log.debug('Saving current line to history before possibly clearing.')
        -- history:add(_G.line)
        _G.history_orig[#_G.history_orig + 1] = _G.line
    end

    _G.line = text
    _G.cursor = _G.line:len() + 1
    _G.history_pos = #_G.history_orig + 1
    _G.insert_mode = false

    -- @TODO: Best time to place this after?
    -- If immediate exec then simulate enter press
    if eval_immediately then
        log.debug('Evaluating console line immedately, calling `handle_enter`.')
        _G.handle_enter()
    end

    if _G.console_active then
        log.debug('Console is active, calling global update function.')
        _G.update()
    else
        log.debug('Making console active.')
        set_active(true)
    end
end

-- string.gmatch

--region UTF Util

---
--- Naive helper function to find the next UTF-8 character in 'str' after 'pos'
--- by skipping continuation bytes. Assumes 'str' contains valid UTF-8.
---
---@param  str string
---@param  pos number
---@return     number
local function next_utf8(str, pos)
    if pos > str:len() then return pos end
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
    if pos <= 1 then return pos end

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
    local cmdlist     = mp.get_property_native('command-list')
    local error_style = '{\\1c&H7a77f2&}'
    local output      = ''
    if param == ''
    then
        output = 'Available commands:\n'
        for _, cmd in ipairs(cmdlist)
        do
            output = output  .. '  ' .. cmd.name
        end
        output = output .. '\n'
        output = output .. 'Use "help command" to show information about a command.\n'
        output = output .. "ESC or Ctrl+d exits the console.\n"
    else
        local cmd = nil
        for _, curcmd in ipairs(cmdlist)
        do
            if curcmd.name:find(param, 1, true)
            then
                cmd = curcmd
                if curcmd.name == param
                then
                    break -- exact match
                end
            end
        end
        if not cmd
        then
            _G.log_add(error_style, 'No command matches "' .. param .. '"!')
            return
        end
        output = output .. 'Command "' .. cmd.name .. '"\n'
        for _, arg in ipairs(cmd.args)
        do
            output = output .. '    ' .. arg.name .. ' (' .. arg.type .. ')'
            if arg.optional
            then
                output = output .. ' (optional)'
            end
            output = output .. '\n'
        end
        if cmd.vararg
        then
            output = output .. 'This command supports variable arguments.\n'
        end
    end
    _G.log_add('', output)
end

--region Modded Help

---@class CommandArg
---@field public name     string
---@field public type     string | '"Time"' | '"Choice"' | '"String"' | '"Flag"' | '"ByteSize"'
---@field public optional boolean

---@class CommandInfo
---@field public name   string
---@field public args   CommandArg[]
---@field public vararg boolean

---@alias CommandList CommandInfo[] @ Native value of `command-list` property.

-- Help Display Function-copied from new console script(migration of repl.lua)
-- TODO: Make columns or something for the list outputs its horrible
---@param param string
local function help_command_custom(param)
    local dbg = Prefix.msg_method('!help', debug)

    -- Process possible dangerous optional param
    local param = param or nil
    if type(param) == 'nil'
    then
        dbg([[`param` argument appears to be nil.]])
        -- Now it can be set to a string
        param = ''
    else
        dbg(string.format('`param` equals: `%s`', tostring(param)))
    end

    ---@type CommandList
    local cmdlist = mp.get_property_native('command-list')

    -- Styles
    local cmd_style   = '{\\1c&H' .. "FFAD4C" .. '&}'
    local error_style = '{\\1c&H' .. "7a77f2" .. '&}'

    local output = ''

    -- Output Cases:
    if not param or param == ''
    then
        -- Case 1: Print Available Commands
        --   Modifications:
        --     - Print out commands with log style `cmd_style`
        --     - Limit columns of commands per line (check for longest)

        --
        output = 'Available commands:\n'
        -- Use this variable for logging commands
        local cmd_output    = ''
        -- Add all commands to this variable while getting max length
        local cmds          = { }
        -- Max char count var
        local max_cmd_chars = -1

        -- Command list iteration 1
        for _, cmd in ipairs(cmdlist)
        do
            output = output  .. '  ' .. cmd.name
        end
        output = string.format('%s%s%s%s',
            output, '\n',
            'Use "help command" to show information about a command.\n',
            "ESC or Ctrl+d exits the console.\n"
        )
        -- output = output .. '\n'
        -- output = output .. 'Use "help command" to show information about a command.\n'
        -- output = output .. "ESC or Ctrl+d exits the console.\n"
    else
        ---@type CommandInfo | nil
        local cmd = nil
        for _, curcmd in ipairs(cmdlist)
        do
            if curcmd.name:find(param, 1, true)
            then
                cmd = curcmd
                if curcmd.name == param
                then
                    break -- exact match
                end
            end
        end
        if not cmd
        then
            _G.log_add(error_style, 'No command matches "' .. param .. '"!')
            return
        end
        output = output .. 'Command "' .. cmd.name .. '"\n'
        for _, arg in ipairs(cmd.args)
        do
            output = output .. '    ' .. arg.name .. ' (' .. arg.type .. ')'
            if arg.optional
            then
                output = output .. ' (optional)'
            end
            output = output .. '\n'
        end
        if cmd.vararg
        then
            output = output .. 'This command supports variable arguments.\n'
        end
    end

    _G.log_add('', output)
end

-- Call debug etc function
script_messages.register('help', help_command_custom)
--- mp.register_script_message('help', help_command_custom)

-- Call debug etc function
script_messages.register('?', help_command_custom)
--- mp.register_script_message('?', help_command_custom)

--- Format perf sample for output
---@param memory number | PerfEventEntry
local function format_perf_memory(memory)
    local value =
        type(memory) == 'number' and memory        or
        type(memory) == 'table'  and memory.memory
            or nil

    if value == nil then error('Invalid memory size value: ' .. tostring(memory)) end

    -- Multiply by 1024 for bytecount, so divide 1024 for mb?
    local mb = (value / 1024)

    return ('%3.3fMB'):format(tostring(mb))
end

-- Display memory usage
script_messages.register('mem', function()
    -- Record fresh sample
    Perf.record('mem script-message call')
    log_add_advanced({
        {
            style = "{\\1c&HCCCCCC&}",
            text = string.format('Memory Usage: %s', format_perf_memory(Perf.last.memory))
        },
        LOG_FRAGMENT.NEW_LINE
    }, false)
end)

local log = msg.extend('reload')
local default_reload_delay = 500
--- Reload console script using trampoline helper script, if available
---@param delay_ms? number
local function reload(delay_ms)
    local delay_ms_tonumber = tonumber(delay_ms)
    local delay =
        type(delay_ms_tonumber) == 'number' and delay_ms_tonumber > 0
            and delay_ms_tonumber
            or default_reload_delay

    log.info('Sending reload script-message to trampoline script with %s delay', tostring(delay) or '[NIL]')
    mp.commandv('script-message-to', 'trampoline', 'reload-script', 'console', delay)

    log.info('Setting mp.keep_running to false...')
    mp.keep_running = false
end
script_messages.register('reload', reload)

--endregion Modded Help

--endregion Help Command

--region script-message alias

--[[ -- Testing implementation from mailling list below (may be identical)
---@param  str string
---@return     string
local function trim(str)
    return str:match('^()%s*$') and '' or str:match('^%s*(.*%S)')
end
]]--

---@type fun(string: string): string
local trim = nil
do local match = string.match
    ---@param str string
    ---@return string
    trim = function(str)
        return match(str,'^%s*$') and '' or match(str,'^%s*(.*%S)')
    end
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

-- @TODO: Ideally it should be a simple process to add additional processing passes in
--        `handle_enter`, e.g. detect and resolve on help command, or expanding `!`
--        script-message alias—atm more functionality => more code dumped into `handle_enter`.
--        Something like the array below seemed like a good solution, where continuation and
--        line transforms can be communicated via return values.

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

local log = msg.extend('handle_char_input')
-- Insert a character at the current cursor position (any_unicode, Shift+Enter)
---@param c? string
local function handle_char_input(c)

    -- @NOTE Added to fix crash on Shift+Enter (incorrect bind1 implementation), keeping for now
    if not (type(c) == 'string' and #c > 0)
    then
        log.warn('c parameter is not a string, exiting early.')
        return

    elseif not (type(c) == 'string' and #c > 0)
    then
        log.warn('c parameter is a zero length string, exiting early.')
        return
    end

    if insert_mode then
        _G.line = _G.line:sub(1, _G.cursor - 1) .. c .. _G.line:sub(next_utf8(_G.line, _G.cursor))
    else
        _G.line = _G.line:sub(1, _G.cursor - 1) .. c .. _G.line:sub(_G.cursor)
    end
    _G.cursor = _G.cursor + #c
    _G.update()
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
    if _G.cursor <= 1 then return end
    local prev = prev_utf8(_G.line, cursor)
    _G.line = _G.line:sub(1, prev - 1) .. _G.line:sub(cursor)
    _G.cursor = prev
    _G.update()
end

-- Remove the character in front of the cursor (Del)
local function handle_del()
    if _G.cursor > _G.line:len() then return end
    _G.line = _G.line:sub(1, _G.cursor - 1) .. _G.line:sub(next_utf8(_G.line, _G.cursor))
    _G.update()
end

-- Toggle insert mode (Ins)
local function handle_ins()
    insert_mode = not insert_mode
end

-- Clear the current line (Ctrl+C)
local function clear()
    _G.line = ''
    _G.cursor = 1
    insert_mode = false
    _G.history_pos = #history_orig + 1
    _G.update()
end

-- Delete from the cursor to the end of the word (Ctrl+W)
function del_word()
    local before_cur = _G.line:sub(1, _G.cursor - 1)
    local after_cur = _G.line:sub(_G.cursor)

    before_cur = before_cur:gsub('[^%s]+%s*$', '', 1)
    _G.line = before_cur .. after_cur
    _G.cursor = before_cur:len() + 1
    _G.update()
end

-- Delete from the cursor to the end of the line (Ctrl+K)
local function del_to_eol()
    _G.line = _G.line:sub(1, _G.cursor - 1)
    _G.update()
end

-- Delete from the cursor back to the start of the line (Ctrl+U)
local function del_to_start()
    _G.line = _G.line:sub(_G.cursor)
    _G.cursor = 1
    _G.update()
end

--endregion Line Editing

--region History

local log = msg.extend('go_history')

--- Go to the specified position in the command history
---@param new_pos    number
---@param no_update? boolean
local function go_history(new_pos, no_update)
    log.debug('Changing history position to %s', new_pos ~= nil and tostring(new_pos) or '[unpassed]')

    -- New position is necessary—this function should be wrapped by convenience functions
    if type(new_pos) ~= 'number'
    then
        error('go_history: new_pos parameter is not a number.')
    end

    local old_pos     = _G.history_pos
    local history_len = #_G.history_orig
    log.debug('Position before update: %s', old_pos)

    -- Restrict the position to a legal value
    if new_pos > history_len + 1
    then
        log.warn('New history position higher than current length of history entries table (%i).', history_len)
        new_pos = history_len + 1
    elseif new_pos < 1
    then
        log.warn('New history position lower than 1')
        new_pos = 1
    end

    -- Do nothing if the history position didn't actually change
    if new_pos == old_pos
    then
        log.debug('No material change in history position (%s -> %s)',
            tostring(old_pos), tostring(new_pos))
        return
    end

    -- If the user was editing a non-history line, save it as the last history
    -- entry. This makes it much less frustrating to accidentally hit Up/Down
    -- while editing a line.
    if old_pos == history_len + 1
        and _G.line                     ~= ''
        and _G.history_orig[history_len] ~= _G.line
    then
        -- As long as history length stored locally this needs to be updated
        history_len = history_len + 1
        log.debug("Current line buffer appears to be unrecorded, adding a history state before clearing.")
        -- Length value updated before use, so increment unecessary
        _G.history_orig[history_len] = _G.line
    end

    -- Now show the history line (or a blank line for #history_orig + 1)
    if new_pos <= history_len
    then
        _G.line = _G.history_orig[new_pos]
    else
        log.debug('Reached end of history, presenting fresh line.')
        _G.line = ''
    end

    _G.cursor = _G.line:len() + 1
    _G.insert_mode = false
    -- Correct?
    _G.history_pos = new_pos
    log.debug('New history position: %i/%i', new_pos, history_len)
    _G.update()
end

--- Go to the specified relative position in the command history (Up, Down)
local function move_history(amount)
    go_history(_G.history_pos + amount)
end

local hlog = msg.extend('history-prefix-search')
local hlogb = hlog.extend('back')
---
--- Move to previous history entry starting with current line content
---
---@param line                 string
---@param increment_on_failure boolean @ If no history entry with prefix is found, still increment in desired direction.
local function go_history_prefix_backward(line, increment_on_failure)
    hlogb.debug('Starting history prefix search, backward')

    -- -- Original:
    -- line = line or _G.line
    -- Condition only for debugging
    if type(line) ~= 'string'
    then
        line = _G.line
        hlogb.debug('Defaulting to current line as search prefix: «%s»', _G.line)
    end

    if type(increment_on_failure) ~= 'boolean'
    then
        increment_on_failure = true
    end

    --- @NOTE: This is assigned to the _next_ value, not current
    local search_pos     = _G.history_pos - 1
    local history_length = #_G.history_orig

    -- Exit early if line is empty
    if line == ''
    then
        hlogb.debug('Current line empty, continuing with regular history movement')
        go_history(math.max(1, history_length - 1))
        return
    end

    hlogb.debug('Searching for history entry beginning with: «%s»', line)

    -- Check if at end already
    -- (Changed from `=` to `<=` to handle pre-assigning next step in search_pos above)
    if search_pos <= 1
    then
        hlogb.debug('Already at beginning of history table.')
    end

    ---@type string
    local curr_entry = nil
    while search_pos >= 1 and search_pos <= history_length
    do
        curr_entry = _G.history_orig[search_pos]
        hlogb.debug('[search] Entry %i: «%s»', search_pos, curr_entry)
        if string.starts_with(curr_entry, line)
        then
            hlogb.debug('Found history entry with line prefix, %i: «%s»', search_pos, curr_entry)
            go_history(search_pos)
            return
        else
            search_pos = search_pos - 1
        end
    end

    if increment_on_failure
    then
        local default_next_pos = _G.history_pos - 1
        hlogb.debug("Search failed, falling back to incrementing history backward by one (%i/%i)", default_next_pos, history_length)
        go_history(default_next_pos)
    end
end

local hlogf = hlog.extend('fwd')
---
--- Move to next history entry starting with current line content
---
---@param line                 string
---@param increment_on_failure boolean @ If no history entry with prefix is found, still increment in desired direction.
local function go_history_prefix_forward(line, increment_on_failure)
    hlogf.debug('Starting history prefix search, forward')

    -- -- Original:
    -- line = line or _G.line
    -- Condition only for debugging
    if type(line) ~= 'string'
    then
        line = _G.line
        hlogf.debug('Defaulting to current line as search prefix: «%s»', _G.line)
    end

    if type(increment_on_failure) ~= 'boolean'
    then
        increment_on_failure = true
    end

    --- @NOTE: This is assigned to the _next_ value, not current
    local search_pos     = _G.history_pos + 1
    local history_length = #_G.history_orig

    -- Check if at end already
    if search_pos > history_length
    then
        hlogf.debug('Already at end of history table.')
        return
    end

    -- Exit early if line is empty
    if line == ''
    then
        hlogb.debug('Current line empty, continuing with regular history movement')
        go_history(math.min(history_length, search_pos))
        return
    end

    hlogf.debug('Searching for history entry beginning with: «%s»', line)

    ---@type string
    local curr_entry = nil
    while search_pos <= history_length
    do
        curr_entry = _G.history_orig[search_pos]
        hlogb.debug('[search] Entry %i: «%s»', search_pos, curr_entry)
        if string.starts_with(curr_entry, line)
        then
            hlogb.debug('Found history entry with line prefix, %i: «%s»', search_pos, curr_entry)
            go_history(search_pos)
            return
        else
            search_pos = search_pos + 1
        end
    end

    if increment_on_failure
    then
        local default_next_pos = _G.history_pos + 1
        hlogf.debug("Search failed, falling back to incrementing history forward by one.")
        if default_next_pos <= history_length
        then
            go_history(default_next_pos)
        else
            hlogf.debug("Already at end of history, skipping fallback increment.")
        end
    end
end

--endregion History

--region Key Handlers

-- Go to the first command in the command history (PgUp)
function _G.handle_pgup()
    go_history(1)
end

-- Stop browsing history and start editing a blank line (PgDown)
function _G.handle_pgdown()
    go_history(#history_orig + 1)
end

local save_preexpanded_line_in_history = false

local log = msg.extend('handle_enter')
---
--- Run the current command and clear the line (Enter)
---
_G.handle_enter = function()
    local line_init = _G.line
    local line_proc = line_init
    log.debug('Console line content at time of enter handle: "%s"', line_init)

    -- Exit immediately if no non-whitespace content
    local line_trimmed = line_init:gsub('^%s+', '')
                                  :gsub('%s+$', '')
    if line_trimmed == '' then return end

    -- Record (unprocessed) input line to history if option variable set true
    if save_preexpanded_line_in_history == true and history_orig[#history_orig] ~= line_init then
        history_orig[#history_orig + 1] = line_init
    end

    local preprocess_fn = console_ext.preprocess_line
    if type(preprocess_fn) == "function" then
        log.debug('Using extended input preprocessing function.')
        log.debug('Line Input:\n%q', line_init)

        local line_eval = preprocess_fn(line_init)
        log.debug('Processed:\n%q', line_eval)
        line_proc = line_eval
    end

    --region Command Processing

    --region Help Command

    local override_base_help = true

    --TODO: Move help command and further additions into extracted subfunction
    --      dedicated to any additional processing
    -- match "help [<text>]", return <text> or "", strip all whitespace
    local matched_help =
        line:match('^%s*help%s+(.-)%s*$') or (line:match('^%s*help$') and '')
    local matched_help_mod =
        line:match('^%s*help[_-]mod%s+(.-)%s*$') or (line:match('^%s*help[_-]mod$') and '')

    if matched_help_mod
    then
        msg.debug('Received input for custom help function: "%s"', tostring(matched_help_mod))
        help_command_custom(matched_help_mod)

    elseif matched_help
    then
        if override_base_help
        then
            msg.debug('Using modified help function. Input: "%s"', tostring(matched_help))
            help_command_custom(matched_help_mod)

        else
            help_command(matched_help)
        end

    --endregion Help Command

    else
        log.trace('Entered final block.')
        local processed_line, expansion_count = expand_script_message_alias(line_proc)
        if expansion_count and expansion_count > 0
        then
            log.trace('Processed ! aliases: %s', string.dquot(processed_line))
        end
        if not save_preexpanded_line_in_history
            or (processed_line ~= line_init and history_orig[#history_orig] ~= processed_line )
        then
            log.debug('Writing processed line to history')
            -- Push transformed line to history
            if history_orig[#history_orig] ~= processed_line
            then
                history_orig[#history_orig + 1] = processed_line
            end
        end

        -- Idiot check
        if #processed_line < 1
        then
            log.warn('Processed line is empty, exiting before execution and display.')
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

--- Move to the start of the current word, or if already at the start, the start
--- of the previous word. (`Ctrl+Left`)
--- This is basically the same as next_word() but backwards, so reverse the
--- string in order to do a "backwards" find. This wouldn't be as annoying
--- to do if Lua didn't insist on 1-based indexing.
function _G.prev_word()
    _G.cursor = line:len() - select(2, line:reverse():find('%s*[^%s]*', line:len() - _G.cursor + 2)) + 1
    _G.update()
end

-- Move to the end of the current word, or if already at the end, the end of
-- the next word. (Ctrl+Right)
function _G.next_word()
    _G.cursor = select(2, line:find('%s*[^%s]*', _G.cursor)) + 1
    _G.update()
end

-- Move the cursor to the next character (Right)
function _G.next_char(amount)
    _G.cursor = next_utf8(line, _G.cursor)
    _G.update()
end

-- Move the cursor to the previous character (Left)
function _G.prev_char(amount)
    _G.cursor = prev_utf8(line, _G.cursor)
    _G.update()
end

-- Move the cursor to the beginning of the line (HOME)
function _G.go_home()
    _G.cursor = 1
    _G.update()
end

-- Move the cursor to the end of the line (END)
function _G.go_end()
    _G.cursor = line:len() + 1
    _G.update()
end

--endregion Line Navigation

--region Completion

---
--- Base class of basic CompletionSet and
---
---
---@class CompletionSetBase
--- An extra string to be appended to the end of a successful completion. It is only appended if
--- final completion (which currently means a single longest completion) is resolved .
---@field public pattern string
---@field public append  string

--- List of tab-completions:
--- A Lua pattern used in string:find. Should return the start and end positions of the word to be completed in the first and second capture groups (using the empty parenthesis notation "()")
---   list:

---
--- Static completion set.
---
---@class CompletionSet: CompletionSetBase
--- A list of generated candidate completion values.
---@field public list    CompletionList

---
---
---
---@class DynCompletionSet: CompletionSetBase
---@field public resolver fun(line: string): CompletionList

---@alias Completions    CompletionSet[]
---@alias CompletionList string[]

--region Completion Value Enumeration

local log = msg.extend('build_completion')

---
--- Generate list of script messages for completions.
---
---@return CompletionList
local function build_script_message_completions()
    log.trace('[script_messages] Building script message completions')

    ---@type CompletionList
    local completions = { }

    -- Found message names in console script
    if type(script_messages.internal_names) == "table"
    then
        -- Iterate through declared script messages
        for _, name in ipairs(script_messages.internal_names)
        do
            completions[#completions + 1] = name
        end
    end

    -- Found message names in other scripts
    if type(script_messages.external_names) == "table"
    then
        -- Iterate through declared script messages
        for _, name in ipairs(script_messages.external_names)
        do
            completions[#completions + 1] = name
        end
    end

    log.trace('[script_messages] Built %i message name completions.', #completions)

    return completions
end

---@class MpvProfile
---@field public name    string
---@field public options table<string, MpvPropertyType>

---
--- Generate list of available profiles for completions.
---
---@return CompletionList
local function build_profile_completions()
    log.trace('[profiles] Building profile completion list')

    ---@type string[]
    local profile_completions = {}
    ---@type MpvProfile[]
    local raw_profiles = mp.get_property_native('profile-list')

    for _, profile in ipairs(raw_profiles)
    do
        if profile.name
        then
            profile_completions[#profile_completions + 1] = profile.name
        else
            log.warn('[profiles]  [Entry in profile list missing name]')
        end
    end

    log.trace('[profiles] Built %i profile completions.', #profile_completions)

    return profile_completions
end

---
--- Generate list of available subcommands for filter commands (`af` | `vf`)
---
---@return CompletionList
local function build_filter_subcommand_completions()
    log.trace('[filters] Building filter subcommand completion list')

    return {
        "set",
        "add",
        "remove",
        "del",
        "clr",
        "clear",
        "toggle"
    }
end

---
--- Generate list of macro symbol completions
---
---@return CompletionList
local function build_macro_completions()
    log.trace('[macros] Building macro completion list')

    ---@type CompletionList
    local macro_comps = { }

    if console_ext.macros
    then
        local macro_symbols = { }
        for symbol in pairs(console_ext.macros)
        do
            macro_symbols[#macro_symbols + 1] = symbol
        end

        -- msg.trace('[build_macro_completions] Building ' .. tostring(#macro_symbols) .. ' macro completions')

        for _, symbol in ipairs(macro_symbols)
        do
            if type(symbol) == "string"
            then
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
    log.trace('[properties] Building property and option completions')
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

    for _, opt in ipairs(mp.get_property_native('options'))
    do
        prop_list[#prop_list + 1] = 'options/' .. opt
        prop_list[#prop_list + 1] = 'file-local-options/' .. opt
        prop_list[#prop_list + 1] = 'option-info/' .. opt
        for _, p in ipairs(option_info)
        do
            prop_list[#prop_list + 1] = 'option-info/' .. opt .. Const.platform == 'windows' and [[\]] or '/' .. p
        end
    end

    log.trace('[properties] Built %i property completions.', #prop_list)

    return prop_list
end

---
--- Atm the scanning for loop this guards does work but it needs to be filtered and eventually
--- resolve subdirectory based scripts.
---
local use_test_hardcoded_path_completions = true

---
--- Generate list available script paths for `load-script`
---
---@return CompletionList
local function build_load_script_path_completions()
    log.trace('[paths] Building path completions')
    local mpv_home = get_mpv_config_dir()
    -- If no home just dip immediately
    if type(mpv_home) ~= "string" or #mpv_home < 1 then return { } end

    local mpv_script_dir = utils.join_path(mpv_home, "scripts")
    log.trace('[paths] reading entries in script dir: "' .. mpv_script_dir .. '"')
    local dirents, readdir_err = utils.readdir(mpv_script_dir)
    if type(readdir_err) ~= "nil"
    then
        log.warn('[paths] Error reading entries in path: "' .. mpv_script_dir .. '"')
        return { }
    end

    -- @TODO

    -- For now, just return the ones I know I need
    local script_dir_prefix = '~~/scripts'
    ---@param  leaf string
    ---@return      string
    local function scriptd(leaf)
        local joined = utils.join_path(script_dir_prefix, leaf)
        log.trace('[paths] [scriptd] Generated completion: "' .. joined .. '"')
        return joined
    end

    local path_list = { }

    if use_test_hardcoded_path_completions
    then
        path_list[#path_list + 1] = scriptd'console'
        path_list[#path_list + 1] = scriptd'playlistmanager'
    else
        if #dirents > 0
        then
            for i, dirent in ipairs(dirents)
            do
                path_list[#path_list + 1] = scriptd(dirent)
            end
        end
    end

    log.trace('[paths] Built %i path completions.', #path_list)

    return path_list
end

---@return CompletionList
local function build_command_completions()
    log.trace('[commands] Building command completions')

    local cmd_list = { }

    for i, cmd in ipairs(mp.get_property_native('command-list')) do
        cmd_list[i] = cmd.name
    end

    log.trace('[commands] Built %i command completions.', #cmd_list)

    return cmd_list
end
---@return Completions
local function build_completers()
    log.trace('Starting completion set enumerations')

    -- Build a list of commands, properties and options for tab-completion

    ---@type CompletionList
    local cmd_list            = build_command_completions()           or { }
    ---@type CompletionList
    local prop_list           = build_prop_completions()              or { }
    ---@type CompletionList
    local profile_list        = build_profile_completions()           or { }
    ---@type CompletionList
    local macro_list          = build_macro_completions()             or { }
    ---@type CompletionList
    local script_message_list = build_script_message_completions()    or { }
    ---@type CompletionList
    local filter_subcmd_list  = build_filter_subcommand_completions() or { }
    ---@type CompletionList
    local script_path_list    = build_load_script_path_completions()  or { }

    log.trace('Finished building completion sets.')

    --region Pattern Components

    local prefix =
    {
        set              = '^%s*set%s+',
        set_profile      = '^%s*set%s+profile%s+',
        add              = '^%s*add%s+',
        cycle            = '^%s*cycle%s+',
        cycle_values     = '^%s*cycle[-]values%s+',
        multiply         = '^%s*multiply%s+',
        load_script      = '^%s*load[-]script%s+',
        script_msg       = '^%s*script-message%s+',
        af_cmd           = '^%s*af%s+',
        vf_cmd           = '^%s*vf%s+',
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

        -- `load-script` paths
        { pattern = prefix.load_script ..  [[()]] .. token .. '()$', list = script_path_list },

        -- af/vf subcommands
        { pattern = prefix.vf_cmd ..  [[()]] .. token .. '()$', list = filter_subcmd_list },
        { pattern = prefix.af_cmd ..  [[()]] .. token .. '()$', list = filter_subcmd_list },

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
--- Use `list` to find possible tab-completions for `part`. Returns the longest
--- common prefix of all the matching list items and a flag that indicates
--- whether the match was unique or not.
---
---@param  part string
---@param  list CompletionList
---@return      string, boolean
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

local log = msg.extend('complete')

-- Complete the option or property at the cursor (TAB)
local function complete()
    ---@type string
    local before_cur = line:sub(1, _G.cursor - 1)
    ---@type string
    local after_cur = line:sub(_G.cursor)

    -- If line is empty or cursor is immediately proceeding a statement
    -- terminating `;` then just complete commands

    -- Try the first completer that works
    for ---@type number
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
                    log.trace('Completion had %s partial completions.', #partials)
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
                            while fragment_idx <= comp_fragment_limit
                            do
                                table.insert(limited_partials, fragment_idx, partials_to_complete[fragment_idx])
                                fragment_idx = fragment_idx + 1
                            end
                            partials_to_complete = limited_partials
                            log.trace('Reduced completions table to %s partials.', #partials_to_complete)
                        else
                            log.trace('Completion fragment limit not reached or disabled.')

                            -- Anything required if no reduction in partials
                            partials_to_complete = partials

                            log.trace('Total partials: ' .. #partials_to_complete)
                        end

                        -- Add heading to completion list
                        -- @TODO: Why doesn't this work?
                        log_add(comp_header_style, 'Completions:')
                        -- log_add('', "\n")

                        local pad_amount = 18

                        log.trace('Checking for longest of %s partial completions.', #partials)

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
                _G.cursor = #before_cur + 1
                line   = before_cur .. after_cur
                _G.update()
                return
            end
        end
    end
end

--endregion Main Completion Function

--endregion Completion

--region Clipboard Access

local Clipboard = require('clipboard').clipboard

local log = msg.extend('paste')
--- Paste text from the window-system's clipboard.
---@param clip boolean | nil @ Determines whether the clipboard or the primary selection buffer is used (on X11 only.)
local function paste(clip)
    local text = Clipboard.read(clip)
    if type(text) ~= 'string' or #text < 1 then
        log.warn('Returned value from clipboard read is empty, or not of string type.')
        if text ~= nil then
            log.warn('Value %q', tostring(text))
        end

        return
    end
    local before_cur = line:sub(1, _G.cursor - 1)
    local after_cur = line:sub(_G.cursor)
    line = before_cur .. text .. after_cur
    _G.cursor = _G.cursor + text:len()
    _G.update()
end

--endregion Clipboard Access

--region Keybinding Management

-- List of input bindings. This is a weird mashup between common GUI text-input
-- bindings and readline bindings.
local function get_bindings()
    -- Check if this explodes
    local bind1, thunk = nil, nil
    do local M = require[[fn]]
        bind1, thunk = M.bind1, M.thunk
    end

    local noop = function() end

    local bindings = nil

    -- @TODO Remove original bindings and all related scaffolding after this works
    local NEW_BINDINGS = true
    if NEW_BINDINGS
    then
        bindings =
        {
            { 'esc',         bind1(set_active, false) },
            { 'enter',       _G.handle_enter                        },
            { 'kp_enter',    _G.handle_enter                        },
            { 'shift+enter', bind1(handle_char_input,'\n')          },
            { 'bs',          handle_backspace                       },
            { 'shift+bs',    handle_backspace                       },
            { 'del',         handle_del                             },
            { 'shift+del',   handle_del                             },
            { 'ins',         handle_ins                             },
            { 'shift+ins',   bind1(paste, false)                    },
            { 'mbtn_mid',    bind1(paste, false)                    },
            { 'left',        thunk(_G.prev_char)                    },
            { 'right',       thunk(_G.next_char)                    },
            { 'up',          thunk(go_history_prefix_backward)      }, -- { 'up',          function() move_history(-1) end        },
            { 'wheel_up',    bind1(move_history, -1)                },
            { 'down',        thunk(go_history_prefix_forward)       }, -- { 'down',        function() move_history(1) end         },
            { 'wheel_down',  bind1(move_history, 1)                 },
            { 'wheel_left',  noop                                   },
            { 'wheel_right', noop                                   },
            { 'ctrl+left',   _G.prev_word                           },
            { 'ctrl+right',  _G.next_word                           },
            { 'tab',         complete                               },
            { 'home',        _G.go_home                             },
            { 'end',         _G.go_end                              },
            { 'pgup',        _G.handle_pgup                         },
            { 'pgdwn',       _G.handle_pgdown                       },
            { 'ctrl+c',      clear                                  },
            { 'ctrl+d',      close_console_if_empty                 },
            { 'ctrl+k',      del_to_eol                             },
            { 'ctrl+l',      clear_log_buffer                       },
            { 'ctrl+u',      del_to_start                           },
            { 'ctrl+v',      bind1(paste, true)                     },
            { 'meta+v',      bind1(paste, true)                     },
            { 'ctrl+w',      _G.del_word                            },
            { 'Ctrl+BS',     _G.del_word                            },
            { 'Alt+BS',      _G.del_word                            },
            { 'kp_dec',      bind1(handle_char_input, '.') },
            -- Console output size ++/--
            -- macOS => cmd + =
            --          cmd + -
            { 'Meta+=',      function() mp.commandv([[script-message]], [[console-size]], [[++]]) end },
            { 'Meta+-',      function() mp.commandv([[script-message]], [[console-size]], [[--]]) end },
            -- win10 => ctrl + =
            --          ctrl + -
            { 'ctrl+=',      function() mp.commandv([[script-message]], [[console-size]], [[++]]) end },
            { 'ctrl+-',      function() mp.commandv([[script-message]], [[console-size]], [[--]]) end },
        }
    else
        bindings =
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
            { 'up',          function() go_history_prefix_backward() end }, -- { 'up',          function() move_history(-1) end        },
            { 'wheel_up',    function() move_history(-1) end        },
            { 'down',        function() go_history_prefix_forward()  end }, -- { 'down',        function() move_history(1) end         },
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
            -- Console output size ++/--
            -- macOS => cmd + =
            --          cmd + -
            { 'Meta+=',      function() mp.commandv([[script-message]], [[console-size]], [[++]]) end },
            { 'Meta+-',      function() mp.commandv([[script-message]], [[console-size]], [[--]]) end },
            -- win10 => ctrl + =
            --          ctrl + -
            { 'ctrl+=',      function() mp.commandv([[script-message]], [[console-size]], [[++]]) end },
            { 'ctrl+-',      function() mp.commandv([[script-message]], [[console-size]], [[--]]) end },
        }
    end

    for i = 0, 9 do
        bindings[#bindings + 1] =
            {'kp' .. i, function() handle_char_input('' .. i) end}
    end

    return bindings
end

--region Keybindings

--region New Input Implementation

local Input = { }
do local M = { }
    M.key_bindings = { }

    function M.bind()
        if #M.key_bindings > 0 then
            return
        end
        for _, bind in ipairs(get_bindings()) do
            -- Generate arbitrary name for removing the bindings later.
            local name = "_console_" .. (#M.key_bindings + 1)
            M.key_bindings[#M.key_bindings + 1] = name
            mp.add_forced_key_binding(bind[1], name, bind[2], {repeatable = true})
        end
        mp.add_forced_key_binding("any_unicode", "_console_text", text_input,
            {repeatable = true, complex = true})
        M.key_bindings[#M.key_bindings + 1] = "_console_text"
    end

    function M.unbind()
        for _, name in ipairs(M.key_bindings)
        do
            mp.remove_key_binding(name)
        end
        M.key_bindings = { }
    end


    Input = M
end

--endregion New Input Implementation

--region @TODO: Current implementation - replace use with `Input` implementation

function _G.define_key_bindings()
    if #key_bindings > 0 then return end
    for _, bind in ipairs(get_bindings())
    do
        -- Generate arbitrary name for removing the bindings later.
        local name = "_console_" .. (#key_bindings + 1)
        key_bindings[#key_bindings + 1] = name
        mp.add_forced_key_binding(bind[1], name, bind[2], {repeatable = true})
    end

    mp.add_forced_key_binding("any_unicode", "_console_text", text_input,
        {repeatable = true, complex = true})

    key_bindings[#key_bindings + 1] = "_console_text"
end

function _G.undefine_key_bindings()
    for _, name in ipairs(key_bindings)
    do
        mp.remove_key_binding(name)
    end
    _G.key_bindings = {}
end

--endregion @TODO: Current implementation - replace use with `Input` implementation

-- Add a global binding for enabling the Console. While it's enabled, its bindings
-- will take over and it can be closed with ESC.
mp.add_key_binding(nil, 'enable', function() set_active(true) end)

--endregion Keybinding Management

--endregion Keybindings

-- Add a script-message to show the Console and fill it with the provided text
local type_script_message = nil
do
    local log = logging.Prefix.fmsg('!type', 'debug')
    function type_script_message(text, immediate)
        -- local dbg = logging.Prefix.fmsg('!type', 'debug')

        log.debug('Entered type script-message handler, calling show_and_type with text:\n"%s"', text)

        show_and_type(typed, immedidate)
    end
end
script_messages.register('type', type_script_message)

-- Redraw the Console when the OSD size changes. This is needed because the
-- PlayRes of the OSD will need to be adjusted.
mp.observe_property('osd-width',           'native', update)
mp.observe_property('osd-height',          'native', update)
mp.observe_property('display-hidpi-scale', 'native', update)

-- Enable log messages. In silent mode, mpv will queue log messages in a buffer
-- until enable_messages is called again without the silent: prefix.
mp.enable_messages('silent:terminal-default')

--region Console Log Output

--region Console Log Filter

local ConsoleLogFilter = require('LogFilter')

--endregion Console Log Filter

---@param e LogEventTable
function ingest_log_message(e)
    if ConsoleLogFilter.is_blacklisted(e) then return end

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

--endregion Console Log Output Filtering

collectgarbage()

--region Debugging

--endregion Debugging

--region Post-init

-- Prompt that alternate console script loaded
_G.log_add('{\\1c&H22CC00&\\b1}', 'Extended console loaded.\n')
Perf.record('post-init')

--endregion Post-init
