local mp   = require('mp')
local util = require('mp.util')

--region lua deps

local os = assert(require 'os', 'os module not loaded.')
local io = assert(require 'io', 'io module not loaded.')

--endregion lua deps

function capture(cmd, raw)
    local f = assert(io.popen(cmd, 'r'))
    local s = assert(f:read('*a'))
    f:close()
    return s
end

local af_help_command = [[mpv --no-config --af=help]]
local af_help = os.capture(af_help_command)
assert(af_help)

return af_help
  -- if #shcmd_output > 1 then
  -- print("Output:\n"..shcmd_output)
  -- else
  -- print("No output detected. Value of output variable:\n'"..shcmd_output.."'")
  -- end

