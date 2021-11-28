--region CUT
---@diagnostic disable

---@type mp
local mp = mp
---@type msg
local msg = msg or nil
---@type utils
local utils = utils  or nil

if type(mp) == "table" then
    if     type(mp)    ~= "table" then mp    = require('mp')
    elseif type(utils) ~= "table" then utils = require('mp.utils')
    elseif type(msg)   ~= "table" then msg   = require('mp.msg')
    end
    msg.debug('mpv context detected.')
else
    -- Non-mpv env stub, might be unncessary
    mp = { }
end

---@diagnostic enable
--endregion CUT

---@alias OSCapture fun(cmd: string, raw: boolean | nil): string

---@type OSCapture
local capture = (function()
    --region mpv

    if type(mp) == "table" then
        ---@type mp
        local mp = assert(mp, 'Failed to load mp module.')
        ---@type utils
        local utils = assert(require('mp.util'), 'Failed to load mp.utils module.')

        ---@param  cmd string
        ---@param  raw boolean | nil
        ---@return     string
        return function(cmd, raw)
            ---@type SubprocessParameters
            local subprocess = {
                args =
                {
                    'zsh', '-c', cmd
                },
                capture_stdout = true,
                capture_stderr = true
            }
            local res = utils.subprocess(subprocess)

            -- Assume success if stdout has output (for now)
            if type(res.stdout) == "string" and #res.stdout > 0 then
                msg.debug(string.format('[capture] Captured output from command "%s":\n"""\n%s\n"""', cmd, res.stdout))
                return res.stdout
            -- Assume failure if below is not true
            else
                msg.warn(string.format('[capture] No captured stdout from command "%s"', cmd))
                -- Check for actual error
                -- (Branch is for different logic later based on status, not for logging)
                if res.status ~= 0 then
                    msg.warn(string.format('[capture]     Error code returned: %s', res.status))
                else
                    msg.warn(string.format('[capture]     No error code returned: %s', res.status))
                end

                return ""
            end
        end

    --endregion mpv

    else

    --region builtin

        local os = require 'os'
        local io = require 'io'
        assert(os, 'os module not loaded.')
        assert(io, 'io module not loaded.')

        ---@param  cmd string
        ---@param  raw boolean | nil
        ---@return     string
        return function(cmd, raw)
            local f = assert(io.popen(cmd, 'r'))
            local s = assert(f:read('*a'))
            f:close()
            return s
        end

    end

    --endregion builtin
end)()


local af_help_command = [[mpv --no-config --af=help]]
local af_help = os.capture(af_help_command)
assert(af_help)

return af_help
  -- if #shcmd_output > 1 then
  -- print("Output:\n"..shcmd_output)
  -- else
  -- print("No output detected. Value of output variable:\n'"..shcmd_output.."'")
  -- end

