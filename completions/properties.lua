--[[
Experiment with deferred completion style—on completion pattern match, function will receive
the body of the current statement for completion enumeration.
]]

---@type mp
local mp = require('mp')
---@type utils
local utils = require('mp.utils')
local logging = require('log-ext')
local Const = require('constants')

local M = setmetatable({ }, {
_NAME = 'console-completions-properties'
})

---
--- Generate list of macro symbol completions
---
---@param statement string
---@return CompletionList
local function complete_props(statement)
    --- Some optimizations will be attemped if line passed
    ---@type string | false
    local text = statement or false
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

    --- @TODO Optimization WIP
    --- [1] This is a p hot loop, table.concat might be appropriate for string building
    --- [2] Conditionally complete variations

    --- [Optimization:2] Precalculate conditions to complete variations
    local comp_opts
    local complete_flopts
    local comp_optinfo = comp

    for _, opt in ipairs(mp.get_property_native('options')) do
        prop_list[#prop_list + 1] = 'options/' .. opt
        prop_list[#prop_list + 1] = 'file-local-options/' .. opt
        prop_list[#prop_list + 1] = 'option-info/' .. opt
        for _, p in ipairs(option_info) do
            prop_list[#prop_list + 1] = 'option-info/' .. opt .. Const.platform == 'windows' and [[\]] or '/' .. p
        end
    end

    msg.trace(string.format('Built %i property completions.', #prop_list))

    return prop_list
end

M.complete_props = complete_props

return M
