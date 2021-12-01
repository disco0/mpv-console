local M = setmetatable({ }, {
_NAME = 'console-constants',
_DESCRIPTION = 'Contains constants and default enumeration functions for console.lua'
})

local mp = require('mp')

--region Platform Detection

-- @NOTE Additional platform specific properties and relevant defines in source:
--     - Windows: HAVE_WIN32_DESKTOP
--         priority
--     - Android: HAVE_EGL_ANDROID
--         android-surface-size

---
--- Returned values from console.lua detect_platform
---
---@alias MpvPlatform string
---| '"windows"'
---| '"macos"'
---| '"x11"'
---| '"wayland"'

M.platforms =
{
    windows = 'windows',
    macos   = 'macos',
    x11     = 'x11',
    wayland = 'wayland'
}

---@return MpvPlatform
local function detect_platform()
    local o = { }
    -- Kind of a dumb way of detecting the platform but whatever
    if mp.get_property_native('options/vo-mmcss-profile', o) ~= o
    then
        return 'windows'
    elseif mp.get_property_native('options/macos-force-dedicated-gpu', o) ~= o
    then
        return 'macos'
    elseif os.getenv('WAYLAND_DISPLAY')
    then
        return 'wayland'
    end
    return 'x11'
end

---@type string | table<'"detect"', fun(): MpvPlatform>
M.platform = setmetatable({ },
---@type Metatable
{
    __tostring = function(self) return platform end,
    __name     = function(self) return platform end,
    __index    = function(self, key)
        if key == 'detect'
        then
            return detect_platform
        end
    end
})

M.detect_platform = detect_platform

--- Current OS
M.platform = detect_platform()

--endregion Platform Detection

--region Default System Font

---@alias ConsoleSystemFont string
---| '"Consolas"'
---| '"Menlo"'
---| '"monospace"'

---@param  platform? MpvPlatform
---@return           ConsoleSystemFont
function M.default_system_font(platform)
    platform = (M.platforms[platform] ~= nil)
        and platform
        or M.platform

    if platform == 'windows'
    then
        return 'Consolas'
    elseif platform == 'macos'
    then
        return 'Menlo'
    else -- default (wayland | x11)
        return 'monospace'
    end
end

--endregion Default System Font

return M
