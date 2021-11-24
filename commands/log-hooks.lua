local _local_1_ = require("commands.utils")
local mp = _local_1_["mp"]
local utils = _local_1_["utils"]
local logging = _local_1_["logging"]
local msg = _local_1_["msg"]
local constants = _local_1_["constants"]
local initialize_command = _local_1_["initialize-command"]
local hook_types = {"on_load", "on_load_fail", "on_preloaded", "on_unload", "on_before_start_file", "on_after_end_file"}
local cmd_log = msg.extend("hook-demo-init")
local hook_log = msg.extend("hook-demo")
local command_name = "show-hooks"
local function command()
  for _, hook_type in ipairs(hook_types) do
    cmd_log.debug("Registering hook: %s", hook_type)
    local function _2_()
      return hook_log.info("Hook called: %s", hook_type)
    end
    mp.add_hook(hook_type, 0, _2_)
  end
  return nil
end
return initialize_command(command_name, command)
