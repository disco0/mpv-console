local _local_1_ = require("commands.utils")
local mp = _local_1_["mp"]
local utils = _local_1_["utils"]
local logging = _local_1_["logging"]
local msg = _local_1_["msg"]
local constants = _local_1_["constants"]
local initialize_command = _local_1_["initialize-command"]
local command_name = "print-native"
local cmd_msg = msg.extend(command_name)
local function command(property)
  _G.assert((nil ~= property), "Missing argument property on /Users/disk0/Dropbox/dev/mpv/scripts/console/commands/src/print-native.fnl:17")
  if ((type(property) == "string") and (#property > 1)) then
    local failure = {}
    local value = mp.get_property_native(property, failure)
    if (value == failure) then
      return cmd_msg.warn("Failed to get native value for property %q.", property)
    else
      local out = string.format("%s:\n%s", property, utils.to_string(value))
      msg.info(out)
      mp.commandv("print-text", out)
      return mp.commandv("show-text", out)
    end
  else
    return nil
  end
end
return initialize_command(command_name, command)
