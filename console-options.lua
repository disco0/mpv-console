local M = setmetatable({ }, {
_NAME = 'Console Options'
})

local Const = require('constants')

-- Default options
-- (Made global for extensions subscript)
M.options =
{
    --- All drawing is scaled by this value, including the text borders and the
    --- cursor. Change it if you have a high-DPI display.
    scale = 1,

    --- Set the font used for the Console and the console. This probably doesn't
    --- have to be a monospaced font.
    font = Const.default_system_font(),

    --- Set the font size used for the Console and the console. This will be
    --- multiplied by "scale."
    font_size = 8,

    -- Display total history entries/position in history in prompt prefix
    prompt_hist_pos = true,
}

return M
