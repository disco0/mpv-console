local M = {}
for key, value in pairs({mp = require("mp"), utils = require("mp.utils"), logging = require("log-ext"), msg = (require("log-ext")).msg, constants = require("constants"), platform = (require("constants")).platform, ["script-message"] = require("script-message-tracker")}) do
  M[key] = value
end
M["initialize-command"] = function(name, command)
  _G.assert((nil ~= command), "Missing argument command on /Users/disk0/Dropbox/dev/mpv/scripts/console/commands/src/utils.fnl:23")
  _G.assert((nil ~= name), "Missing argument name on /Users/disk0/Dropbox/dev/mpv/scripts/console/commands/src/utils.fnl:23")
  if not M["script-message"].registered(name) then
    M["script-message"].register(name, command)
  else
  end
  return {command = command, name = name}
end
return M
