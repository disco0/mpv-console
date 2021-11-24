-- (Original lua version of command declaration before moving to fennel)

local mp = require('mp')
local utils = require("mp.utils")

local logging = require("log-ext")
local msg = logging.msg

local constants = require("constants")
local platform = constants.platform
local script_message = require("script-message-tracker")
local command_name = 'print-native'
local cmd_msg =  msg.extend('print-native')

---
--- Outputs native value of given property `property` to console
--- for inspection.
---
---@param property string
local function command(property)
    if type(property) ~= 'string'
    then
        return
    end

    local failure = { }
    local value = mp.get_property_native(property, failure)
    if value == failure
    then
        cmd_msg.warn('Failed to get native value for property %q.', property)
    end

    local out = ('%s:\n%s'):format(property, utils.to_string(value))
    msg.info(out)
    -- mp.command(([[print-text "$>%q"]]):format(utils.to_string(out)))
    -- mp.command(([[show-text "$>%q"]]):format(utils.to_string(out)))
    mp.commandv([[print-text]], out)
    mp.commandv([[show-text]],  out)
end

if not script_message.registered(command_name) then
    script_message.register(command_name, command)
end
