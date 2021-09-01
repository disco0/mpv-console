local clipboard =
{
    _VERSION     = '0.1',
    _DESCRIPTION = 'Clipboard wrapper for mpv scripts',
    -- @TODO
    _URL         = 'https://github.com/disco0/mpv-clip.lua',
    _LICENSE     = 'MIT'
}

--region Environment

local unpack = table.unpack or unpack

local mp = require('mp')
-- local utils = require('mp.utils')
local subprocess = require('mp.utils').subprocess

---@type string
local platform = require('constants').platform
local logging = require('log-ext')
local msg = logging.msg

--endregion Environment

local M = { }

--region Clipboard Command Definitions

---@alias WindowsClipboardBin '"pwsh"' | '"powershell"'

---@class WindowsClipboardCommandUtil
---@field public resolved_bin         WindowsClipboardBin        | nil
---@field public command              table<WindowsClipboardBin, string>
---@field public get_bin              fun(): WindowsClipboardBin | nil
---@field public get_subprocess_table fun(): string[]            | nil

--region Windows Clipboard
--endregion Windows Clipboard

---@type WindowsClipboardCommandUtil
local win_clip = { }
win_clip =
{
    ---@type WindowsClipboardBin
    resolved_bin = nil,

    ---@type table<WindowsClipboardBin, string>
    command =
    {
        pwsh       = '. { Get-Clipboard -ErrorAction SilentlyContinue -Raw }',
        powershell = ([[& {
            Trap {
                Write-Error -ErrorRecord $_
                Exit 1
            }

            $clip = ""
            if (Get-Command "Get-Clipboard" -errorAction SilentlyContinue) {
                $clip = Get-Clipboard -Raw -Format Text -TextFormatType UnicodeText
            } else {
                Add-Type -AssemblyName PresentationCore
                $clip = [Windows.Clipboard]::GetText()
            }

            $clip = $clip -Replace "`r",""
            $u8clip = [System.Text.Encoding]::UTF8.GetBytes($clip)
            [Console]::OpenStandardOutput().Write($u8clip, 0, $u8clip.Length)
        }]]):gsub('^        ', '')
    },

    ---@return WindowsClipboardBin
    get_bin = function()
        if type(win_clip.resolved_bin) == "string" and #win_clip.resolved_bin > 0 then
            return win_clip.resolved_bin
        end
        local res = subprocess({
            args = { 'where.exe', 'pwsh.exe' },
            playback_only = false
        })
        if res.status ~= 0 then
            msg.debug('Shell command "where.exe pwsh.exe" returned non-zero exit code.')
            win_clip.resolved_bin = 'powershell.exe'
        else
            msg.debug('Shell command "where.exe pwsh.exe" was successful')
            win_clip.resolved_bin = 'pwsh.exe'
        end

        msg.debug('Storing resolved powershell command: ' .. win_clip.resolved_bin)
        return win_clip.resolved_bin
    end,

    ---@return string[] | nil
    get_subprocess_table = function()
        return (function(resolved_bin)
            local resolved_comand = win_clip.command[resolved_bin]
            if type(resolved_bin) == 'string' and resolved_command then
                return {

                    args =
                    {
                        resolved_bin,
                        '-NoProfile',
                        '-NoLogo',
                        '-Command',
                        command
                    },

                    playback_only = false

                }
            end
        end)(win_clip.get_bin())
    end
}

local log = msg.extend('get_clipboard')
--- Returns a string of UTF-8 text from the clipboard (or the primary selection)
---@param  clip                 boolean | nil
---@param  returnErrorOnFailure boolean | nil
---@return                      string  | nil
local function get_clipboard(clip, returnErrorOnFailure)

    log.trace('Checking for clipboard procedure for current platform: ' .. tostring(platform))
    if platform == 'x11' then
        local res = subprocess({
            args = { 'xclip', '-selection', clip and 'clipboard' or 'primary', '-out' },
            playback_only = false
        })

        if not res.error then
            return res.stdout
        else
            log.warn('Clipboard command returned error: %s', tostring(res.error))
            return (returnErrorOnFailure == true and res.error) or nil
        end
    end
    if platform == 'wayland' then
        local res = subprocess({
            args = { 'wl-paste', clip and '-n' or  '-np' },
            playback_only = false,
        })

        if not res.error then
            return res.stdout
        else
            log.warn('Clipboard command returned error: %s', tostring(res.error))
        end

    elseif platform == 'windows' then
        -- local winpwsh = win_clip.windows.powershell
        -- local powershell_bin = get_windows_pwsh_bin()
        -- -- Use faster bin and command if wholesome 100 big chungus powershell
        -- -- desktop compat unnecessary
        -- local command = powershell_bin:starts_with('pwsh')
        --                     and winpwsh.command.pwsh
        --                     or  winpwsh.command.powershell
        local subprocess_params = win_clip.get_subprocess_table()
        if subprocess_params == nil then
            msg.error('Failed to resolve a subprocess parameter table, or possibly binary and argument set for Windows powershell/pwsh paste command.')
            return nil
        end
        local res = subprocess(subprocess_params)

        if not res.error then
            return res.stdout
        else
            if type(res.stderr) == "string" then
                log.error('Clipboard stderr:\n```%s\n```', res.stderr)
            end
            log.warn('Clipboard command returned error: ' .. tostring(res.error))
        end

    elseif platform == 'macos' then
        local res = subprocess({
            args = { 'pbpaste' },
            playback_only = false,
        })

        if not res.error then
            return res.stdout
        else
            log.warn('Clipboard command returned error: ' .. tostring(res.error))
        end
    end

    log.warn('Reached fallthrough after all platform checks.')
    return ''
end

local log = msg.extend('set_clipboard')
local function set_clipboard(text)
    log.warn('Clipboard setter function unimplemented.')
end

---@class Clipboard
--- Read clipboard using platform-specfic scripts.
---@field public read fun(clip?: boolean, returnErrorOnFailure?: boolean): string
---@field public set  fun(text: string): nil @ _*Unimplemented*_
M.clipboard =
{
    read = get_clipboard,
    set  = set_clipboard
}

return M

-- ---@ return WindowsClipboardBin
-- local function get_windows_pwsh_bin()
--     if type(win_clip.resolved_bin) == "string" and #win_clip.resolved_bin > 0 then
--         return win_clip.resolved_bin
--     end
--     local res = subprocess({
--         args = { 'where.exe', 'pwsh.exe' },
--         playback_only = false
--     })
--     if res.status ~= 0 then
--         msg.debug('Shell command "where.exe pwsh.exe" returned non-zero exit code.')
--         win_clip.resolved_bin = 'powershell.exe'
--     else
--         msg.debug('Shell command "where.exe pwsh.exe" was successful')
--         win_clip.resolved_bin = 'pwsh.exe'
--     end

--     msg.debug('Storing resolved powershell command: ' .. win_clip.resolved_bin)
--     return win_clip.resolved_bin
-- end

-- win_clip.get_subprocess_table = function()
--     return (function(resolved_bin)
--         local resolved_comand = win_clip.command[resolved_bin]
--         if type(resolved_bin) == 'string' and resolved_command then
--             return {
--                 resolved_bin,
--                 '-NoProfile',
--                 '-NoLogo',
--                 '-Command',
--                 command
--             }
--         end
--     end)(get_windows_pwsh_bin())
-- end
--endregion Clipboard Command Definitions
