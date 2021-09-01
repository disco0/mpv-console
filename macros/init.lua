---@alias Macros table<string, string>

-- @FIXME Clean this whole folder up—tried unteasing the parts here without any
--        crazy rewites but didnt' workout

local M =
{
    _NAME = 'console-macros',
    _DESCRIPTION = 'Entry module for console macros system.',
    _VERSION = '0.0.1'
}

-- @TODO: Across all subscripts migrate live macros definition table from global macros table
--        (`_G.macros`).
-- @TODO: Return to implicit global mp?

--region Imports

local mp = require('mp')
local msg = require('log-ext').msg.extend('macros')

local is = require('util.guard').is

local defaults = require('macros.defaults')
local instance = require('macros.instance')

--endregion Imports

local log = msg.extend('init')
---
--- Must be called before any other macros related function that mananges definitions state.
function M.init()
    if instance.is_initialized()
    then
        log.warn('Macros system already initialized, skipping rest of function.')
        return
    else
        instance.MACROS_INITIALIZED = true
    end

    -- Initialize storage table, if not defined
    if not is.Table(_G.macros)
    then
        _G.macros = { }
    end

    instance.reload_macros()

    --region DRY

    -- -- Try to load macros from file, if fails laod temp copy for now
    -- local load_macro_result = instance.read_macro_file()

    -- if is.Table(load_macro_result)
    -- then
    --     log.debug([[macro file successfully loaded via require.]])
    --     _G.macros = M.ingest_macros(load_macro_result)
    -- else
    --     log.warn([[Using fallback macros desclaration inside script.]])
    --     _G.macros = M.ingest_macros(defaults.get_default_macros())
    -- end

    --endregion DRY
end

M.instance = instance
M.util =
{
    defaults = defaults
}

-- M.util = macro_util.

return M
