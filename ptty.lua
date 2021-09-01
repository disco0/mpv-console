local M =
{
    _NAME = 'mpv-console-ptty',
    _DESCRIPTION = ([[
        Console output state, configuration, and management functions.

        @TODO Any function or variable used to configure/effect ASS drawing should be migrated
        to this submodule.
    ]]):gsub('        ', '')
}

--region Declarations

---
--- Base of LogLine subtypes
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

--endregion Declarations

-- (Actually initialize M.update timer here instead)
M.update_timer = _G.update_timer

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

--region Buffer Modification

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
            if not M.update_timer:is_enabled()
            then
                M.update()
                M.update_timer:resume()
            else
                M.pending_update = true
            end
        end
    end
end

-- local default_console_color = 'CCCCCC'

---
--- Add a line to the log buffer (which is limited to 100 lines, by default)
---
---@param  style string
---@param  text  string
---@return       nil
function M.log_add(style, text)
    M.log_buffer[#M.log_buffer + 1] = { style = style, text = text }
    if #M.log_buffer >  M.buffer_line_max
    then
        table.remove(M.log_buffer, 1)
    end

    if M.active
    then
        if not M.update_timer:is_enabled()
        then
            M.update()
            M.update_timer:resume()
        else
            M.pending_update = true
        end
    end
end

---
--- Add a new line to the log buffer using extended styling
---
---@param  entry DetailedLogLine
---@param  wait  boolean | nil
---@return       nil
function M.log_add_advanced(entry, wait)
    M.log_buffer[#M.log_buffer + 1] = entry -- { style = style, text = text }
    if #M.log_buffer >  M.buffer_line_max  then
        table.remove(M.log_buffer, 1)
    end

    if wait == true
    then
        -- no-redraw
    elseif M.active
    then
        if not M.update_timer:is_enabled() then
            M.update()
            M.update_timer:resume()
        else
            pending_update = true
        end
    end
end

--- Empty the log buffer of all messages (`Ctrl+l`)
function M.clear_log_buffer()
    M.log_buffer = { }
    M.update()
end

--endregion Buffer Modification
