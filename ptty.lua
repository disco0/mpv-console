local M = setmetatable({ }, {
_NAME = 'console-ptty',
_DESCRIPTION = 'Module for functionality related to drawing console.'
})

local mp = require('mp')
local utils = require('mp.utils')
---@type assdraw
local assdraw = require('mp.assdraw')

local opts = require('console-options').options

local format = string.format

---@type boolean
M.active = false
---@type boolean
M.pending_update = false
---@type string
M.line = ''
---@type number
M.cursor = 1
---@type LogRecord[]
M.log_buffer = { }
---@type number
M.global_margin_y = 0
M.buffer_line_max = 100
---
--- Used to track input state when navigating history—if repl has been cleared, or not received
--- a character generally, scrolling through history should not be prefix searched.
---
M.fresh_line = true

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
function M.log_edit(text, update)
    local curr_item = M.log_buffer[#M.log_buffer + 1]
    curr_item.text = curr_item.text .. text

    if type(update) == 'boolean' and update == true
    then
        if M.active
        then
            if not _G.update_timer:is_enabled()
            then
                M.update()
                _G.update_timer:resume()
            else
                M.pending_update = true
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
function M.log_add_plain(text)
    table.insert(M.log_buffer, { style = '', text = text })

    if #M.log_buffer > M.buffer_line_max
    then
        table.remove(M.log_buffer, 1)
    end
end

---
--- Add a line to the log buffer (limited to 100 lines by default)
---
---@param  style  string
---@param  text   string
---@param  defer? boolean
---@return        nil
function M.log_add(style, text, defer)
    table.insert(M.log_buffer, { style = style, text = text })

    if #M.log_buffer > M.buffer_line_max
    then
        -- @NOTE: If this code gets reworked/used for a general, multi-buffer entry case make sure
        --        to also handle the removals correctly (e.g. not hardcoded to 1)
        table.remove(M.log_buffer, 1)
    end

    if defer == true or not M.active then return end

    if not _G.update_timer:is_enabled()
    then
        M.update()
        _G.update_timer:resume()
    else
        M.pending_update = true
    end
end

---
--- Add a new line to the log buffer using extended styling
---
---@param  entry DetailedLogLine
---@param  wait  boolean | nil
---@return       nil
function M.log_add_advanced(entry, wait)
    table.insert(M.log_buffer, entry)

    if #M.log_buffer >  M.buffer_line_max
    then
        table.remove(M.log_buffer, 1)
    end

    if wait == true
    then
        -- no-redraw
    elseif M.active
    then
        if not _G.update_timer:is_enabled()
        then
            M.update()
            _G.update_timer:resume()
        else
            M.pending_update = true
        end
    end
end

--- Stores common LogLine fragments, for use with `log_add_advanced`.
M.LOG_FRAGMENT =
{
    NEW_LINE = { text = "\n", style = "" }
}

--- Empty the log buffer of all messages (`Ctrl+l`)
function M.clear_log_buffer()
    M.log_buffer = {}
    M.update()
end


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
    HARD_SPACE  = '\\h'
}

---
--- Escape a string `str` for verbatim display on the OSD
---
---@param  str        string
---@param  no_escape? boolean
---@return            string
local function ass_escape(str, no_escape)

    local disable = type(no_escape) == "table" and no_escape or { }

    ---@type string
    local str = str or ''

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

--- Render the Console and console as an ASS OSD
function M.update()
    M.pending_update = false

    local dpi_scale = mp.get_property_native("display-hidpi-scale", 1.0)

    dpi_scale = dpi_scale * opts.scale

    local screenx, screeny, aspect = mp.get_osd_size()
    screenx = screenx / dpi_scale
    screeny = screeny / dpi_scale

    -- Clear the OSD if the Console is not active
    if not M.active
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
    local before_cur = ass_escape(M.line:sub(1, M.cursor - 1))
    local after_cur  = ass_escape(M.line:sub(M.cursor))

    -- Render log messages as ASS. This will render at most screeny / font_size messages.
    local log_ass = ''
    -- @NOTE: math.ceil only takes one arg?
    local viewable_log_message_count = math.min(#M.log_buffer, math.ceil(screeny / opts.font_size))

    -- @TODO: Return escaped string to position in line/node buffer and allow the now semi-memoized
    --        value to be passed through again instead of repeatedly processing it. This effectively
    --        adds a third kind of log buffer entry type, the (rendered) string
    --

    ---@param node table<'text' | 'style', string>
    local function process_buffer_node(node)
        log_ass = string.format('%s%s%s%s', log_ass, style, node.style or '', ass_escape(node.text))
    end

    for i = #M.log_buffer - viewable_log_message_count + 1, #M.log_buffer
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
        if type(M.log_buffer[i].text) == 'string'
        then
            process_buffer_node(M.log_buffer[i])

        -- Detailed line: Check for array indicies
        elseif type(M.log_buffer[i][1]) == 'table'
        then
            local j = 1
            local curr = M.log_buffer[i][j]
            while curr ~= nil
            do
                process_buffer_node(M.log_buffer[i][j])
                j = j + 1
                curr = M.log_buffer[i][j]
            end
        else
            -- Unknown: Explode
            error('[update] Failed to determine type of log entry.')
        end
    end

    ass:new_event()
    ass:an(1)
    ass:pos(2, screeny - 2 - M.global_margin_y * screeny)
    ass:append(log_ass .. ASS_CHAR.NEW_LINE)

    -- Just content after initial style content of each section–still requires prepending style,
    -- or style + alpha for cursor pass
    -- @NOTE: Special case for drawing history position—if position is one over the history
    --        entry total, assume its the active input buffer, and don't draw.
    local prompt_before_body = style .. '> ' .. before_cur
    if opts.prompt_hist_pos == true and (_G.history_pos ~= #_G.history_orig + 1)
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
    ass:pos(2, screeny - 2 - M.global_margin_y * screeny)
    ass:append(style .. '{\\alpha&HFF&}' .. prompt_before_body)
    ass:append(cursor_glyph)
    ass:append(style .. '{\\alpha&HFF&}' .. prompt_after_body)

    mp.set_osd_ass(screenx, screeny, ass.text)
end


return M
