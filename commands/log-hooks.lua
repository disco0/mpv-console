local mp = require("mp")
local utils = require("mp.utils")
local logging = require("log-ext")
local msg = logging.msg
local constants = require("constants")
local platform = constants.platform
local script_message = require("script-message-tracker")
local hook_types = {"on_load", "on_load_fail", "on_preloaded", "on_unload", "on_before_start_file", "on_after_end_file"}
local cmd_log = msg.extend("hook-demo-init")
local hook_log = msg.extend("hook-demo")
local command_name = "show-hooks"
local function command()
  for _, hook_type in ipairs(hook_types) do
    cmd_log.debug("Registering hook: %s", hook_type)
    local function _1_()
      return hook_log.info("Hook called: %s", hook_type)
    end
    mp.add_hook(hook_type, 0, _1_)
  end
  return nil
end
if not script_message.registered(command_name) then
  script_message.register(command_name, command)
end
return {command = command}
