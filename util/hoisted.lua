local M =
{
    _NAME = 'guarded-function-binding',
    _DESCRIPTION = 'For debugging hoisted function definitions. If called before the following (actual) definition a warning message will be logged.'
}

---
--- Creates a no-op function that displays a labeled warning when called (before
--- actual implementation replaces it)
---
---@param  name       string
---@param  msg_level? MessageLevel
---@return fun(...):  nil
function M.hoisted_function_declaration(name, msg_level)
    local prefix    = name and '['..tostring(name)..'] ' or ''
    local msg_level =
        msg_level and type(mp.msg[msg_level]) == 'function'
            and msg_level
            or 'warn'

    local msg_method = mp.msg[msg_level]
    local msg = ('%sHoisted local declaration called before implementation loaded.')
                  :format(prefix)

    return function(...) msg_method(msg) end
end

return M
