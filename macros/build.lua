local M = setmetatable({ }, {
_NAME = 'macro-building-utils',
_DESCRIPTION = 'DSL-like utility function set for building macros with multiple/nested statements.'
})

--region Debugging

local trace_macro_build = true
-- Should be able to use modules in console dir, don't want to load the workspace atm
local log = trace_macro_build
    and (function(mpmsg)
            return function(...) mpmsg.debug(string.format(...)) end
        end)(require('mp.msg'))
    or function() end

--endregion Debugging

---@alias TRUE  boolean | "true"
---@alias FALSE boolean | "false"

--region Generation Utils

---@param  str string
---@return     string
local function normalize_statement_terminator(str) return str:gsub("[; ]*$", '; ') end

local function trim_end(str) return (str or ''):gsub('%s+$', '') end

--endregion Generation Utils

--region Macro Building Components

-- @TODO Build a expression builder that combines statements/strings for
-- concatenation, quoting, and eventual output for a macro definition

---
--- Send both print-text and show-text commands with supplied argument `message`
---
--- @TODO
---
---@param  message string | string[]
---@return nil
function M.show_and_print(message)
    -- Input validation
    local m = message or nil
    if not m then return false end
end

---
--- Concatenate a list of statement strings into a single command string, with semicolon statement
--- terminals as delimiters
---
---@return             nil
---@vararg             string
---@overload fun(statements: string[]): nil
function M.statements(...)
    ---@type string[]
    local args = {...}
    if #args == 1 then
        local first = args[1]
        if type(first) == 'string' then
            return normalize_statement_terminator(first) -- :gsub([[;*$]], ';')
        end
        if type(first) == 'table' then
            return M.statements(unpack(first))
        end
    end

    -- For now multiple values must mean being passed values (which are strings, for now), not
    -- tables of values
    local function valid_line_value(value)
        return type(value) == 'string'
    end

    local lines = { }
    local curr_index = -1

    local push_statement = function(line, index)
        if not valid_line_value(line) then
            local line_index_str = ''
            if type(index) == 'number' and index >= 1 then
                line_index_str = string.format('#%s', index)
            end
            error(string.format('Line value %s failed validation: %s',
                line_index_str,
                tostring(line)
            ))
        end

        local trimmed = trim_end(line)
        log('[statements:push_statement] Pushing %s%q',
            (type(index) == 'number' and index >= 1)
                and string.format('#%s ', index)
                or '',
            trimmed)
        -- Trim stray terminators
        lines[#lines + 1] = trimmed
    end

    -- require "croissant.debugger"()
    for i, v in ipairs(args) do curr_index = i push_statement(v, curr_index) end

    local result = table.concat({unpack(lines)}, '; ') .. ';'
    log('[statements]  Generated => %q', result)
    return result
end

local raw_quote_concat_str = ''
---@overload fun(strings: string[]): string
---@vararg string
---@return string
function M.raw_quote(...)
    local args = {...}
    if #args == 0
    then
        return ''
    -- Recurse with vararg of strings in first argument as arguments (otherwise single argument
    -- should be string type and will get processed below).
    elseif #args == 1 and type(args[1]) == 'table'
    then
        -- Recurse spreading first argument's array of strings
        return M.raw_quote(unpack(args[1]))
    end

    -- @NOTE: Not sure if lua's builtin double quoting semantics will be 1-1 here
    return string.format([[%q]], table.concat({[[$>]], ...}, raw_quote_concat_str))
end

--endregion Macro Building Components

return M
