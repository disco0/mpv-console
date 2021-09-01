local M =
{
    _NAME = 'console-macros-instance',
    _DESCRIPTION = 'Contains state related functions and values for macros system.',
    _VERSION = '0.0.1'
}

--region Imports

local mp = require('mp')
local msg = require('log-ext').msg.extend('macros')

local macro_util = require('macros.util')
local defaults = require('macros.defaults')

local is = require('util.guard').is

--endregion Imports

-- @NOTE: (Besides init) if it should have a guard, it should go in this file

--region Init Guard

M.MACROS_INITIALIZED = false

local function assert_initialized()
    assert(M.MACROS_INITIALIZED == true, "Macro system initialization not yet started")
end

---@return boolean
function M.is_initialized()
    return M.MACROS_INITIALIZED == true
end

--endregion Init Guard

---
--- Clobbers active macro definitions table with table passed in `new_macros` parameter.
---
--- Returns false and exits before clobbering if `new_macros` is not a table.
---
---@param new_macros macros
---@return boolean
function M.push_new_macros(new_macros)
    assert_initialized()

    if not is.Table(new_macros) then return false end
    _G.macros = new_macros

    return true
end

local log = msg.extend('read_macro_file')
---
--- Loads and returns macro definition table using `mp.load_config_file`. If fails, move to
--- `package.searchpath`
---
--- Should be located in script-opts only for now, later possibly in a child dir of this script.
--- @NOTE: Why did I write this
---
---@param name string | nil
---@param path string | nil
---@return macros | nil
function M.read_macro_file(name, path)
    name = name or defaults.config_file.basename
    path = path or defaults.config_file.mpvhome_subdir

    if is.String(name) and #name > 0 and
       is.String(path) and #path > 0
    then
        local macros_relative_path = path .. name .. [[.lua]]
        log.debug([[Checking for macrofile via mp.find_config_file(%q)...]], macros_relative_path)
        local macrofile_path = mp.find_config_file(macros_relative_path)

        if macrofile_path
        then
            log.debug([[Macro file path: %s]], macrofile_path)
            log.debug([[Loading file...]])

            ---@type macros | nil
            local loaded_macros = nil
            pcall(function() loaded_macros = dofile(macrofile_path) end)
            return loaded_macros
        else
            log.warn([[mp.find_config_file(%s) failed.]], macros_relative_path)
        end
    end
end

local log = msg.extend('reload_macros')
---
--- Reload user macros config file and return true. On an error/failure, updating will be stopped on
--- an error, and false will be returned instead.
---
---@return boolean
function M.reload_macros()
    assert_initialized()

    local newmacros = M.read_macro_file()
    if not is.Table(newmacros)
    then
        log.error([[Error at macro file load: resulting value from reading macro file is not a table.]])
        return false
    end

    log.trace([[macro file successfully loaded via require.]])

    local parsed_newmacros = M.ingest_macros(newmacros)
    if not is.Table(parsed_newmacros)
    then
        log.error([[Error ingesting macros from reloaded file.]])
        return false
    end

    log.debug([[Updating live macros list...]])

    if M.push_new_macros(parsed_newmacros)
    then
        log.debug([[macro file successfully reloaded.]])
    else
        log.error([[Error updating live macros list.]])
        return false
    end

    log.debug('Ending macros refresh with ' .. #_G.macros .. ' macros registered.')
    return true
end

--- Cleanup function for macros-trims whitespace that otherwise causes
--- problems on repl.
function M.ingest_macros(raw_macros)
    local macros = is.Table(raw_macros) and raw_macros or nil
    if not raw_macros then return end

    local function trim(s)
        return s:match'^()%s*$'
                and ''
                or s:match'^%s*(.*%S)'
    end

    local function table_len(_table)
        if is.Table(_table)
        then
            local count = 0
            for _ in pairs(_table) do count = count + 1 end
            return count
        else
            return false
        end
    end

    local function join_lines(list)
        local len = table_len(list)
        if len == 0 then return "" end
        local string = list[1]
        for i = 2, len
        do
            string = string .. "\n" .. list[i]
        end
        return string
    end

    local function trim_lines(str)
        local sep, fields = "\n", {}
        local pattern = string.format("([^%s]+)", sep)
        str:gsub(pattern, function(c) fields[#fields+1] = trim(c) end)
        return fields
    end

    local function handle_macro(macro)
        local lines = trim_lines(macro)
        if #lines < 1
        then
            print([[ERROR: No lines parsed for macro ]] .. symbol)
        elseif #lines < 2
        then
            return lines[1]
        else
            return join_lines(lines)
        end
    end

    -- Trim beginning whitespace
    for symbol, value in pairs(macros)
    do
        macros[symbol] = handle_macro(value)
    end

    return macros
end

local log = msg.extend('macros', 'get_current_macros')
---
--- Wrapper for reading macro definition table.
---
--- @TODO: Probably unneccessary after refactor from _G.macros storage.
---
---@return macros
function M.get_current_macros()
    assert_initialized()

    local defs = _G.macros

    -- @NOTE: Theoretically this check can get removed with assert guard
    if is.Table(defs)
    then
        return defs
    else
        log.warn('Macro definition storage variable is not a table, returning empty default.')
        return { }
    end
end

return M
