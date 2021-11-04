local msg = require('mp.msg')

--- @NOTE: Has to be loaded earlier no later than subscripts—otherwise
---        no script messages outside of main script will be completed
--- @TODO: Find out if there's a builtin property/method to query for registered
---        script messages, even in javascript realm

---
--- Store defined script messages for completion value generation
---
---@type string[]
local script_message_names = { }

---
--- Store parsed script message names for completion value generation
---
--- TODO: Implement script searcher/parser to generate values
---
---@type string[]
local external_script_message_names =
{
    -- curvesman
    'tone-toggle',
    'tone-up',
    'tone-down',
    'tone-show',
    'tone-upper',
    'tone-shift',
    'tone-reset',

    'temp-show',
    'temp-upper',
    'temp-cooler',
    'temp-shift',

    'curves-quiet',
    'curves-restart',
    'curves-dbg',
    'curves-quit',
}

--region Script-Message Wrapper

---
--- Wrapper for `mp.register_script_message` that records the message name
--- for enumeration in completion builder
---
---@see mp.register_script_message
---@param name string
---@param fn   function
local function initialize_script_message(name, fn)
    mp.register_script_message(name, fn)

    -- Check if message name already in list before appending (still registering
    -- all new handler functions before this above)
    -- new script-message regardless)
    for _, existing_name in ipairs(script_message_names) do
        if name == existing_name then
            msg.debug(string.format('Skipping adding message name %q to script-message name table, found previous instance.', name))
            return
        end
    end

    script_message_names[#script_message_names + 1] = name
end

--endregion Script-Message Wrapper

--region Management

---
--- Check if string `name` has been registered as a script-message. If optional
--- external parameter is passed `true` the external registry is searched.
---
---@param name string
---@param external? boolean
local function check_initialized(name, external)
    local search_table =
        external and external_script_message_names
                 or  script_message_names
    for _, defined_name in ipairs(search_table)
    do
        if name == defined_name
        then
            return true
        end
    end

    return false
end

--endregion Management

return {
    register       = initialize_script_message,
    internal_names = script_message_names,
    external_names = external_script_message_names,
    registered     = check_initialized
}
