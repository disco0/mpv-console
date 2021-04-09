--- console2.lua -- Additional functions for mpv console script
---    "If console is so good why is there no console 2?"
---
--- Migrated from repl++ originally for repl.lua
---

--region Imports

local msg = require('mp.msg')
local utils = require('mp.utils')

--endregion Imports

--region Pull in globals

-- local log_add = _G.log_add
-- local string  = _G.string

--endregion Pull in globals

--region Declarations

---@alias BuiltinTypeLiteral string | "'string'" | "'table'" | "'number'" | "'function'"

---@alias macros table<string, string>

--endregion Declarations

--region    LIBCHECK

-- Only load when being loaded in console.lua, not as a standalone script
local extends = [[console]]

---@param  extends string
---@return         boolean
local function lib_check(extends)
    if type(extends) ~= "string" then return false end

    local function sanitize(input)
        return input:gsub('^[%s]+','' )
                    :gsub('[%s]+$','' )
                    :gsub('[^%w]', '_')
                    :gsub('%.lua$','' )
    end

    return (sanitize(extends) == sanitize(mp.get_script_name()))
end
if lib_check(extends) ~= true then
    msg.debug( 'Exiting ' .. mp.get_script_name() ..
                    ': Not loaded as library for ' .. extends .. '.')
    return
end

--endregion LIBCHECK

--region    Imports

-- function Set(t)
--     local set = {}
--     for _, l in pairs(t) do set[l] = true end
--     return set
-- end

---@type mp
local mp = mp
---@type msg
local msg     = require('mp.msg')
local assdraw = require('mp.assdraw')
local options = require('mp.options')
local utils   = require('mp.utils')

--endregion Imports

--region    INITINFO

local function get_source_file()
    return debug.getinfo(1,'S');
end

do
    local source_file = get_source_file()
    if source_file then
        local path_msg = "Script Path: \n" .. utils.to_string(source_file)

        msg.debug(path_msg)
    end
end

local function get_package_path()
    if package.path then
        return package.path:gsub('\\','/'):gsub(';+ *','\n  ')
    else
        return nil
    end
end

-- Print relevant info to debug level
local function log_package_path(level)
    local level = (level and msg[level]) or [[debug]]

    local package_path  = get_package_path()
    if type(package_path) ~= "string" then
        msg.error([[Reading package.path failed.]])
        return
    end
    msg.debug([[package_path: []]..type(package_path)..'] => '..package_path)

    local msg_method = msg[level]
    if type(msg_method) ~= "function" then
        msg.error([[Invalid method: mp.msg[]]..tostring(level)..[[]: ]]..type(msg_method))
        return
    end

    msg_method("package.path:\n") -- ..package_path)
end

if _VERSION then msg.debug( [[Lua Version: ]] .. _VERSION ) end

-- Define lua info printing function while declaring lua env related funcs
-- NOTE: vararg reserved for later options (possibly)
--- Output lua environment info to repl
---@vararg string
local function print_luainfo(...)
    -- Print header

    -- Print lua version

    -- Print package related info

    -- ...
end

--- mp.register_script_message('lua', print_luainfo)
initialize_script_message('lua', print_luainfo)

--endregion INITINFO

log_package_path()

--region    MACROS

-- Very dirty, clean up after this works
-- Define non-local macros table
---@type macros
_G.macros = {}
---@type macros
macros = _G.macros

function push_new_macros(new_macros)
    if type(new_macros) ~= "table" then return false end
    _G.macros = new_macros
    macros    = new_macros

    return true
end

-- Hardcoding macro filename for now
local macrofile_basename_def = [[macros]]
local macrofile_path_def     = [[script-opts/]]

--
-- Load macros via mp.load_config_file.  If fails, move to `package.searchpath`
--
-- Should be located in script-opts only for now,
-- later possibly in a child dir of this script.
--
---@param _name string | nil
---@param _path string | nil
function load_macro_file(_name, _path)
    local name = _name or macrofile_basename_def
    local path = _path or macrofile_path_def

    if name and path then
        local macros_relative_path = path .. name .. [[.lua]]
        msg.debug( [[Checking for macrofile via mp.find_config_file(]] .. macros_relative_path .. ')...')
        local macrofile_path = mp.find_config_file(macros_relative_path)

        if macrofile_path then
            msg.debug([[Macro file path: ]] .. macrofile_path)
            msg.debug([[Loading file...]])
            return dofile(macrofile_path) or nil
        else
            msg.warn( [[mp.find_config_file(]] .. macros_relative_path .. ') failed.' )
        end
    end
end

function reload_macros()
    -- if type(macros) ~= "table" then return end

    local newmacros = load_macro_file()
    if type(newmacros) ~= "table" then
        msg.error([[Error at macro file load.]])
        return false
    end

    msg.debug([[macro file successfully loaded via require.]])

    parsed_newmacros = ingest_macros(newmacros)
    if type(parsed_newmacros) ~= "table" then
        msg.error([[Error ingesting macros from reloaded file.]])
        return false
    else
    end

    msg.debug([[Updating live macros list...]])

    if push_new_macros(parsed_newmacros) then
        msg.debug([[macro file successfully reloaded.]])
        return true
    else
        msg.error([[Error updating live macros list.]])
        return false
    end

    msg.debug('Ending macros refresh with ' .. #_G.macros .. ' macros registered.')
end

-- For printing/log
local proc_arrow = '=>'
-- Blacklist of words for use in various macros
local blacklist = { "set", "cycle", "cycle-values" }

-- Cleanup function for macros-trims whitespace that otherwise causes
-- problems on repl.
function ingest_macros(_macros)
    local macros = _macros or nil
    if type(macros) ~= [[table]] then return end

    local function trim(s) return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)' end

    local function table_len(_table)
        if type(_table) == 'table' then
            local count = 0
            for _ in pairs(_table) do count = count + 1 end
            return count
        else
            return false
        end
    end

    local function join_lines(list)
        local len = table_len(list)
        if len == 0 then return "" end
        local string = list[1]
        for i = 2, len do
            string = string .. "\n" .. list[i]
        end
        return string
    end

    local function trim_lines(str)
        local sep, fields = "\n", {}
        local pattern = string.format("([^%s]+)", sep)
        str:gsub(pattern, function(c) fields[#fields+1] = trim(c) end)
        return fields
    end

    local function handle_macro(macro)
        local lines = trim_lines(macro)
        if #lines < 1 then
            print([[ERROR: No lines parsed for macro ]] .. symbol)
        elseif #lines < 2 then
            return lines[1]
        else
            return join_lines(lines)
        end
    end

    -- Trim beginning whitespace
    for symbol, value in pairs(macros) do
        macros[symbol] = handle_macro(value)
    end

    return macros
end

-- Try to load macros from file, if fails laod temp copy for now
local load_macro_result = load_macro_file()

if type(load_macro_result) == 'table' then
    msg.debug([[macro file successfully loaded via require.]])
    macros = ingest_macros(macros)
else
    msg.warn([[Using fallback macros desclaration inside script.]])

    macros = ingest_macros(macros)
end

--endregion MACROS

---
--- Get tokens from current line input and try expanding them
---
---@param line string
---@return nil
function print_line(line)
    local to_print = line
    local cmd      = ""
    for w in to_print:gmatch("%S+") do
    -- if w ~= "set" then
        if not blacklist[w] then
            cmd = "print-text \"" .. w .. " " .. proc_arrow .. " ${" .. w .. "}\" "
            mp.command(cmd)
        end
    end
    update()
end
--

---
--- Check for mpv property `prop_name`, and if defined print its type to
--- output. If property `prop_name` not found then nothing is printed.
---
--- (Split off from original `get_type`—at some point previous it returned a
--- `tostring`'ed representation of the type but when returning to this code it
--- was returning `nil`.)
---
--@param str           string
--@param default_value string | nil
--@return nil
function print_prop_type(str, default_value)
    default_value = default_value or ''
    ---@type string
    local cmd = ""
    str = type(str) and str or ''
    for w in str:gmatch("%S+") do
    -- if w ~= "set" then
        if not blacklist[w] then
            local proptype = mp.get_property(tostring(w))
            print(proptype)
            local cmd = "print-text \"" .. w .. " ::= " ..  proptype .. "\""
            mp.command(cmd)
        end
    end
    update()
    return
end

---@param msg_body string
local function gt_dbg(msg_body)
    msg.trace('[get_type] ' .. msg_body)
end
---
--- Attempt to get (mpv property) type of first token-like string in
--- `prop_name`, if defined return its type in string form.
---
--- If property `prop_name` not found, returns a default type representation
--- string (`''`, set with `default_value` parameter).
---
---@param  str string
---@return     string
function get_type(str, default_value)
    default_value = type(default_value)   and default_value or ''
    str           = type(str) == "string" and str           or ''

    gt_dbg('Input string: "' .. str .. '"')
    -- if w ~= "set" then~
    local token = str:match("[a-zA-Z_\\/-]+") or ""

    gt_dbg('Checking for property name (matched string) "' .. token .. '"')

    if token and #token > 0 and blacklist[token] == nil then
        local prop_value = mp.get_property_native(w, nil)
        if prop_value ~= nil then
            local prop_type = type(prop_value)
            gt_dbg('mp.get_property_native("' .. token ..'") =>' .. tostring(prop_value))
            gt_dbg('    Type: ' .. prop_type)
            return prop_type
        else
            gt_dbg('mp.get_property_native("' .. token ..'") => [nil]')
            return default_value
        end
    end
end
--

---
--- Cycle all boolean properties passed in string input
---
---@param line string
---@return nil
function cycle_line(line)
    local cmd = ""
    for w in line:gmatch("%S+") do
        if not blacklist[w] then
            local prop = mp.get_property(tostring(w))
            if prop == "yes" or prop == "no" then
                toggle_property(w, "yes", "no")
                local cmd = "print-text \"" .. w .. " " .. proc_arrow .. " ${" .. w .. "}\" "
                mp.command(cmd)
            else
                log_add('{\\1c&H66ccff&}', w .. " != Bool\n")
            end
        end
    end
    update()
end
--


---
--- Naive implementation for (pre|ap)pending to each word in string input
---
---@param prefix  string
---@param line    string
---@param postfix string
---@return nil
function cons_line(prefix, line, postfix)
    go_home()
    prefix:gsub(".", function(c)
        handle_char_input(c)
    end)
    go_end()
    if postfix then
        postfix:gsub(".", function(c)
            handle_char_input(c)
        end)
        prev_char(postfix.len)
    end
    update()
end


--region    eval++

---
--- Current implementation only looks for instruction symbol in first
--- non-whitespace char of line, and passes it into switch
--- TODO: Tokenize to some extent where possibly useful, possibly
---      eval word by word into valid chunks for existing switch
---
---@param line string
---@return nil
function eval_line(line)
    msg.debug('Evaluating line:\n"""\n' .. line .. '\n"""')

    -- Subfunctions to parse lines and statements for `!` substitution
    --   TODO: - Generalize beyond single symbol case,
    --         - Integrate do_line() code into body?
    local function parse_statements(line)
        local statements = {}
        for statement in line:gmatch('[^ ;][^;]*[;]?') do
            if #statement > 0 then
                if statement:sub(-1):match(';') then
                    statements[#statements + 1] = statement
                else
                    statements[#statements + 1] = statement .. ';'
                end
            end
        end
        update()
        return statements
    end

    local function do_line(line)
        if line:match(';') then
            local statements = parse_statements(line)
            if statements then
                local line_ = ""
                for _, s in ipairs(statements) do
                    if s:match('![ ]*([^ ].*)') then
                        line_ = line_ .. (s:gsub('![%s]*', "script-message "))
                    else
                        line_ = line_ .. s
                    end
                end
                return line_
            end
        else
            if line:match('![ ]*([^ ].*)') then
                line = (line:gsub('!', "script-message "))
                return line
            else
                return line
            end
        end
    end
    --

    --region    Main function block
    do
        -- New logging stuff
        local log_prefix = '[macros]'

        if line:match("[^%s]") == "#" and line:find("^[%s]*#[^%s#;]+") then
            local symbol_read = line:match("^[%s]*#[^%s#;]+"):sub(2)

            if macros[symbol_read] then
                line = line:gsub(
                    "^([^#]*)(#[^%s]+)(.*)$",
                    function( pre, macro, post )
                        -- not sure if you can just return a string held together with spit in lua
                        local  expanded_line =  pre .. macros[symbol_read] .. post
                        return expanded_line
                    end
                )

            end
        end
    end
    -- ! => script-message
    if line:match('[^"]*!') then
        -- lol
        return (do_line(line))
    else --????? Why did this go away
        return line
    end

    --endregion Main Function Block
end

---
--- New line eval code
---
---@param _line string
---@return nil
function eval_line_new(_line)

    ---@type string
    local line_init, line_proc = _line, _line

    -- Pull current line value if line argument not a string value
    if type(_line) ~= 'string' then
        warn('line parameter passed into eval_line is not a string, using global line value as a fallback.')
        if type(_G.line) ~= "string" then
            warn('Global line state (_G.line) also is not of string type.')
        end
    end

    -- local line_init = type(_line) == "string" and _line or _G.line

    local dbg     = titled_dbg_msg('Line Eval', 'trace')
    local dbg_err = titled_dbg_msg('Line Eval', 'error')
    local warn    = titled_dbg_msg('Line Eval', 'warn')

    --region Subfunctions

    -- Subfunctions to parse lines and statements for `!` substitution
    --   TODO: - Generalize beyond single symbol case,
    --         - Integrate do_line() code into body?

    ---@param  line string
    ---@return      string[]
    local function parse_statements(line)
        ---@type string[]
        local statements = {}
        for statement in line:gmatch('[^ ;][^;]*[;]?') do
            if #statement > 0 then
                if statement:sub(-1):match(';') then
                    statements[#statements + 1] = statement
                else
                    statements[#statements + 1] = statement .. ';'
                end
            end
        end
        update()
        titled_dbg_msg('parse_statements', 'trace')(string.format('Parsed %i statements.', #statements))
        return statements
    end

    -- -- Macro block logging function
    -- --@param log_text string
    -- function dbg_macros( log_text )
    --     local debug_prefix = '[macros]'
    --     log_text = (type(log_text) and log_text) or ''
    --     msg.debug(debug_prefix .. ' ' .. log_text)

    -- end

    ---@param  macro_text string
    ---@return            string
    local function trim_macro_padding(macro_text)
        macro_text = type(macro_text) == "string" and macro_text or ''
        if #macro_text < 1 then
            msg.warn('[trim_macro_padding] macro_text is zero-length or non-string.')
            return ''
        else

            dbg([[ trim_macro_whitespace() called. ]])

            -- To count the number of matches for spaces after new lines
            -- (Remove/comment this after everything appears to be working)
            local macro_text_clean, sub_count = macro_text:gsub([[%s+\n]] , "\n")

            dbg(string.format('%i lines corrected.', tostring(sub_count)))
            dbg([[Corrected macro output:]])
            dbg('  ' .. macro_text_clean )

            return macro_text_clean

            -- -- Direct substitution only
            -- macro_text:gsub( '\n[%s]+' , '\n')
        end
    end

    ---@param  raw_line string
    ---@return          string
    local function expand_macros(raw_line)

        local dbg  = titled_dbg_msg('expand_macros', 'trace')
        local warn = titled_dbg_msg('expand_macros', 'warn')

        dbg('[Entering macro expansion block.]')

        if type(raw_line) ~= "string" then
            warn(string.format('Value of line passed in raw_line argument is non-string type (%s).', type(raw_line)))
            return ''

        --region Has macro-like tokens
        elseif raw_line:match("[^%s]") == "#" and raw_line:find("^[%s]*#[^%s#;]+") then
            local symbol_read = raw_line:match("^[%s]*#[^%s#;]+"):sub(2)

            dbg([[`#` prefix found in line. ]])
            dbg(string.format([[  raw_line:match("^[%%s]*#[^%%s#;]+"):sub(2) => %s]], dquote(symbol_read)))

            if macros[symbol_read] then
                -- Format macro value for repl after confirming the matched
                -- symbol does exist in the table
                local raw_macro_value = macros[symbol_read]
                local macro_value = trim_macro_padding( raw_macro_value )

                -- Replace the first valid macro notation found with value
                --[[ TODO:
                        I remember why I never actually have this working on
                        more than one symbol per expression now this garbo
                ]]--
                local expanded = raw_line:gsub(
                    '^([^#]*)(#[^%s]+)(.*)$',
                    function( pre, macro_match, post )
                        local  expanded_line =  pre .. macro_value .. post
                        -- local  expanded_line =  pre .. macros[symbol_read] .. post
                        return expanded_line
                end)

                dbg(string.format([[ macros["%s"]:%s"%s"."]], symbol_read, "\n", macro_value))

                return expanded
            end
        --endregion Has macro-like tokens
        else
        --region No macro-like tokens

            return raw_line

        --endregion No macro-like tokens
        end
    end

    ---@param line string
    local function do_line(line)
        local dbg = titled_dbg_msg('do_line', 'trace')

        dbg(string.format('Processing line input: "%s"', line))

        -- Check for statement terminators, break down statements
        if line:match(';') then
            dbg('Found semicolons in line, treating it like it contains multiple substatements.')
            statements = parse_statements(line)
            if statements then
                local line_ = ""
                for _, s in ipairs(statements) do
                    dbg(string.format('  Statement: %s', dquote(s)))
                    --   Can't remember if originally script-message
                    -- prefixes to be tokens, full on prefixes, or both,
                    -- but majority use is as a prefix char to the token
                    -- so its going to be only that for now (with the
                    -- whitespace friendly version commented out for
                    -- later, of course.)
                    -- if s:match('![ ]*([^ ].*)') then
                    -- if s:match('!([^ ].*)') then
                    if s:match('^[%s]*!([^ ].*)') then
                        dbg('Expanding "!" script-message aliases for substatement.')
                        line_ = line_ .. (s:gsub('^[%s]*![%s]*', "script-message "))
                    else
                        line_ = line_ .. s
                    end
                end

                dbg(string.format('Final line content: "%s"', line_))
                return line_
            end
        -- Handle line as one big statement if no terminators found
        else
            ---@type string
            local _line = ''
            dbg('Treating line as one single statement.')
            if line:match('![ ]*([^ ].*)') then
                dbg('Expanding "!" script-message aliases.')
                _line = (line:gsub('!', "script-message "))
            else
                dbg('No script-message "!" aliases found to expand.')
                _line = line
            end

            dbg(string.format('Final line content: %s', dquote(_line)))
            return _line
        end
    end

    --endregion Subfunctions

    --region Main function block

    dbg('About to enter macro expansion.')
    dbg('  Line Input:')
    dbg('    ' .. dquote(line_init) .. '')

    -- Expand all found macros initial line content
    line_proc = expand_macros(line_init)

    if type(line_proc) ~= "string" or #line_proc == 0 then
        dbg_err('expand_macros returned empty or non-string line value. (type: ' .. tostring(type(line_proc)) .. ')')
        dbg('Restoring original value of line after bad return value from expand_macros')
        line_proc = line_init
    else
        dbg('Completed macro expansion')
        dbg('  Line Output:')
        dbg('    "' .. line_proc .. '"')
    end

    -- do
        -- --> TODO:   I think the issue with the repl not drawing immediately
        -- ---       might be in the macro block, at the moment its currently
        -- ---       replacing the whole line instead the macro token ( even
        -- ---       if this isn't the reason, its retarded )
        -- dbg( [[ Entering macro expansion block. ]] )
        -- if line:match("[^%s]") == "#" and line:find("^[%s]*#[^%s#;]+") then
        --     local symbol_read = line:match("^[%s]*#[^%s#;]+"):sub(2)

        --     dbg( [[ # prefix found in line. ]] )
        --     dbg( [[ line:match("^[%s]*#[^%s#;]+"):sub(2) => ']] .. symbol_read .. "'" )

        --     if macros[symbol_read] then
        --         line = line:gsub(
        --             '^([^#]*)(#[^%s]+)(.*)$',
        --             function( pre, macro, post )
        --                 -- not sure if you can just return a string held together with spit in lua
        --                 local  expanded_line =  pre .. macros[symbol_read] .. post
        --                 return expanded_line
        --         end)

        --         dbg( [[ [new] Result using line:gsub to expand macro in place instead of replacing the whole line => ]] .. "\n\t"  .. line )
        --         -- dbg( [[ [old] Established, lazier method => ]] .. "\n\t"  .. line )
        --         dbg( [[ Replacing value of line with macros[]] .. symbol_read .. '].' )
        --         dbg( [[ macros[" ]] .. symbol_read .. [[ "] => ']] ..  macros[symbol_read] .. "'.'" )
        --         dbg( [[ This is still debug output, if you have not seen a second copy of the macro expansion (or its byproducts in the log) there is still a issue." ]] )
        --     end
        -- end
    -- end
    -- ! => script-message
    if string.match(line_proc, '[^"]*!') then
        -- lol
        return (do_line(line_proc))
    else
        return (do_line(line_proc))
        -- return line
    end

    --endregion Main function block
end

--endregion eval++

---
--- Device explorer
---
---@param text string
---@return nil
function device_info(text)
    if not text or text == "a" then
        plist = mp.get_property_native("audio-device-list")
    else
        plist = mp.get_property_osd(text)
    end
    pdbg(plist)
end

---
--- Audio Filter View
---
---@param  filter string
---@return nil
function filter_info(filter)
    local do_filter = type(filter) == "string" and #filter > 0

    local styles =
    {
        heading = '{\\1c&HFF8409&}',
        accent    = '{\\1c&H40C010&}',
        base    = '{\\1c&Heeeeee&}',
        dim    = '{\\1c&H444444&}',
    }
    ---@type AudioFilterNode[]
    local af_data = mp.get_property_native("af")
    for k, v in ipairs(af_data) do
        log_add('',  ' ')
        log_add(styles.heading, (v.label and ('@' .. v.label) or tostring(k)) .. "\n")
        log_add(styles.base, '  - ')
        log_add(styles.accent, v.name)
        if not v.enabled then
            log_add(styles.base, ' ')
            log_add(styles.dim, '[disabled]\n')
        else
            log_add(styles.base, '\n')
        end



        -- (Newer version before I rememered its all escaped)
        -- log_add('', string.format(
        --     '- %s%s%s\n',
        --     styles.heading,
        --     (v.label and ('@' .. v.label) or tostring(k)),
        --     styles.base
        -- ))
        -- log_add(styles.base, string.format(
        --     '|   - %s %s\n',
        --     v.name,
        --     (v.enabled == false and "[disabled]" or '')
        -- ))
    end
end



---@class AudioFilterNode
---@field enabled boolean
---@field name    string  | nil
---@field label   string | nil
---@field params  table<string, string>

---
--- A/V Device Explorer
---
--- mp.register_script_message('devices', function(text)
initialize_script_message('afi', function(text)
    filter_info(text)
end)

---
--- Capture command output
---
---@param  cmd string
---@overload fun(cmd: string, as_lines: true): string[]
---@return     string
function os.capture(cmd)
    local as_lines = as_lines or false
    local cmd      = (type(cmd) == "string" and cmd) or nil
    assert(cmd)

    -- Invoke command and read output
    local f = assert(io.popen(cmd, 'r'))

    -- If lines arg is passed true, return iterator of lines
    if as_lines then
        local line_itr = assert(f:lines())
        local lines = {}

        for entry in f:lines() do
            lines[#lines + 1] = entry
        end
        f:close()

        return lines
    else
        local s = assert(f:read('*a'))
        f:close()

        return s
    end
end

---@param cmd string
---@return    string[]
function os.capture_lines(cmd)
    return os.capture(cmd, true)
end

---
--- Enumerate Audio Filter Data
---
---@return string
function retreive_af_info_table()
    -- mpv command to generate info
    local af_help_command = [[mpv --no-config --af=help]]
    local af_help = os.capture(af_help_command)
end

--- mp.register_script_message('get-af-help', print_af_help)
initialize_script_message('get-af-help', print_af_help)

---
--- Spew audio devices
---
---@param text string
function audio_devices(text)
    plist = mp.get_property_osd("audio-device-list")
    --print(plist)
    utils.to_string(plist)
end

-- List (read: spew) audio devices
--- mp.register_script_message('print-devices', function(text)
initialize_script_message('print-devices', function(text)
    audio_devices()
end)

---
--- Loads script with the filename supplied via `script_name` argument.
--- Will attempt to remove lua file extension.
--- Currently no error checking as it won't crash the repl++ script,
--- but completion would be p great.
---
-- ---@param script_name string
-- function load_mpv_script(script_name, keep_extension)
--     local plist = mp.get_property_osd("audio-device-list", '')
--     --print(plist)
--     utils_to_string(plist)
-- end

---
--- List (read: spew) audio devices
---
--- mp.register_script_message('print-devices', function(text)
initialize_script_message('print-devices', function(text)
    audio_devices()
end)

--region    List macros

-- Pattern checking for flag to show definitions in output
local print_macros_with_def_flag_pattern = [[^(-d|--defs?|defs?|definitions?)$]]

---@param  first string
---@vararg       string
function print_macros(first, ...)

    -- @TODO: Generalize option checking for multiple options in this function
    -- Check for parameter to display definitions
    ---@type boolean
    local display_macro_defs = type(first) == "string"
        and #first > 0
        and (print_macros_with_def_flag_pattern:match(first) ~= nil)

    if display_macro_defs then
        msg.debug(string.format([[`%s` flag passed, listing macro definitions.]], first))
    end

    local macro_list = {}

    -- Filter macros using arg as search term
    local filter = false
    if display_macro_defs then
        local next = ...
        if next and type(next) == "string" then filter = next end
    else
        if first and type(first) == "string" then filter = first end
    end

    msg.debug(string.format('Filter: %s', tostring(filter)))

    if type(filter) == "string" then
        msg.debug([[Filtering macros matching string `]] .. filter .. [[`]])
        for symbol, _ in pairs(macros) do
            -- NOTE: Moved to regex matching
            local found = (symbol:match(filter) and true or false)
            if found then
                msg.debug([[Adding ]]..symbol..[[ to display list.]])
                macro_list[symbol] = macros[symbol]
            end
        end
    else
        macro_list = macros
    end

    -- Output formatting for command
    -- Color Format: #BBGGRR
    macro_color = "FFAD4C"
    value_color = "FFFFFF"

    -- Functions for each listing mode
    local function print_macro_symbol_and_value(macro_symbol, macro_value)

        log_add( '{\\1c&H' .. macro_color .. '&}',
                    string.format("%s:\n", macro_symbol)  )
        log_add( '{\\1c&H' .. value_color .. '&}',
                    string.format("%s\n",  macro_value)   )

    end
    local function print_macro_symbol(macro_symbol)

        log_add( '{\\1c&H' .. macro_color .. '&}',
                    string.format("%s\n", macro_symbol)  )

    end

    -- Apply appropriate function for context
    local print_macro = (display_macro_defs and print_macro_symbol_and_value or print_macro_symbol)

    -- Iterate through macros
    -- Should make this a class w/ fields now
    for macro_symbol, macro_value in pairs(macro_list) do
        msg.debug(macro_symbol..": \n"..macro_value)

        print_macro(macro_symbol, macro_value)
    end

    -- Update repl on completion
    update()
end

--- mp.register_script_message('macros', function(...)
initialize_script_message('macros', function(...)
    print_macros(...)
end)

--endregion List macros

--region    Expand macro into prompt buffer

---@param  token string
---@return       string
local function expand_macro(token)
    -- Exit if no argument string
    local token = (token or false)
    if not token then return end

    -- -- Check macro table for exact match and return its value if found
    -- local macros = macros

    msg.debug('[expand_macro] Indexing through macro list for `' .. token .. '`')
    local itr = 1
    for symbol, _ in pairs(macros) do
        local debug_prefix = '[expand_macro]  [' .. itr .. '] '
        msg.trace(debug_prefix..[[ => `]] .. symbol .. [[`]])
        -- NOTE: Moved to regex matching
        if symbol == token then
            msg.trace(debug_prefix..[[Detected matching macro: `]]..symbol..[[` == `]]..token..[[`, returning.]])
            return macros[symbol]
        end

        itr = itr + 1
    end
end

---
---@param token string
local function type_macro(token)
    local dbg = titled_dbg_msg('type_macro', 'trace')
    dbg(string.format('Checking for macro with symbol "%s"', token))

    if not token or type(token) ~= "string" then return end

    local expansion = expand_macro(token)
    if type(expansion) ~= "string" then expansion = "" end

    if #expansion > 0 then
        dbg(string.format('Typing expansion of given macro symbol "%s" into console with type script-message.', token))
        mp.commandv('script-message-to', 'console', 'type', expansion)
    else
        local style = '{\\1c&H66ccff&}'
        local msg   = string.format('Macro with symbol `%s` does not exist.', token)
        log_add(style, msg)
    end
end

--- mp.register_script_message('macro-expand', type_macro)
initialize_script_message('macro-expand', function(token) return type_macro(token) end)
initialize_script_message('type-macro',   function(token) return type_macro(token) end)

--endregion Expand macro into prompt buffer

--region Dump table to string

---@param  tbl table
---@return     string
function table2string(tbl)
    return utils.format_table(tbl)
end

--endregion Dump table to string

--region Debug print function

function pdbg(toPrint)
    local function pdbg_rec(toPrint)
        if type(toPrint) == "table" then
            for _, p in ipairs(toPrint) do pdbg_rec(p) end
        else
            log_add('{\\1c&H66ccff&}', toPrint)
        end
    end
    if type(toPrint) == "table" then
        msg.debug('pdbg: Printing table')
        for n, p in ipairs(toPrint) do
            if type(p) == "table" then
                log_add('{\\1c&H66ccff&}', to_string(n) )
                -- log_add('{\\1c&H66ffcc&}', table2string(toPrint) ) --#ffcc66 #cc66ff #66ffcc
                log_add('{\\1c&H66ffcc&}', utils.format_table(toPrint) ) --#ffcc66 #cc66ff #66ffcc
                -- pdbg_rec(p)
            end
        end
    else
        msg.debug('pdbg: Printing string')
        log_add('{\\1c&H66ccff&}', toPrint)
    end
    update()
end
-- Call debug etc function
--- mp.register_script_message('dbg', function(text)
initialize_script_message('dbg', function(text)
    dbg_etc(text)
end)

--endregion Debug print function

--region Help

-- ---
-- --- Help Display Function-copied from new console script(migration of repl.lua)
-- --- TODO: Make columns or something for the list outputs its horrible
-- ---
-- ---@param param string
-- ---@return nil
-- function help_command(param)

--     --TODO make a class/generator for scoped header logging messages
--     local function dbgmsg(...)
--         msg.debug(table.concat({'[help_command]',...}, ' '))
--     end

--     -- Process possible dangerous optional param
--     local param = param or 1
--     if type(param) == 'number' then
--         dbgmsg([[`param` argument appears to be nil.]])
--         -- Now it can be set to a string
--         param = ''
--     else
--         dbgmsg([[`param` equals: `]]..tostring(param)..[[`]])
--     end

--     local cmdlist = mp.get_property_native('command-list')

--     -- Styles
--     local cmd_style   = '{\\1c&H' .. "FFAD4C" .. '&}'
--     local error_style = '{\\1c&H' .. "7a77f2" .. '&}'

--     local output = ''
--     -- Output Cases:
--     if not param or param == '' then
--         -- Case 1: Print Available Commands
--         --   Modifications:
--         --     - Print out commands with log style `cmd_style`
--         --     - Limit columns of commands per line (check for longest)
--         output = 'Available commands:\n'
--         -- Use this variable for logging commands
--         local cmd_output    = ''
--         -- Add all commands to this variable while getting max length
--         local cmds          = {}
--         -- Max char count var
--         local max_cmd_chars = -1

--         -- Command list iteration 1
--         for _, cmd in ipairs(cmdlist) do
--             output = output  .. '  ' .. cmd.name
--         end
--         output = output .. '\n'
--         output = output .. 'Use "help command" to show information about a command.\n'
--         output = output .. "ESC or Ctrl+d exits the console.\n"
--     else
--         local cmd = nil
--         for _, curcmd in ipairs(cmdlist) do
--             if curcmd.name:find(param, 1, true) then
--                 cmd = curcmd
--                 if curcmd.name == param then
--                     break -- exact match
--                 end
--             end
--         end
--         if not cmd then
--             log_add(error_style, 'No command matches "' .. param .. '"!')
--             return
--         end
--         output = output .. 'Command "' .. cmd.name .. '"\n'
--         for _, arg in ipairs(cmd.args) do
--             output = output .. '    ' .. arg.name .. ' (' .. arg.type .. ')'
--             if arg.optional then
--                 output = output .. ' (optional)'
--             end
--             output = output .. '\n'
--         end
--         if cmd.vararg then
--             output = output .. 'This command supports variable arguments.\n'
--         end
--     end
--     log_add('', output)
--     update()
-- end

-- Call debug etc function
-- mp.register_script_message('help', help_command)
-- Call debug etc function
--- mp.register_script_message('?', help_command)
-- initialize_script_message('?', help_command)


--endregion Help

---
--- Native debug print function test
---
---@param toPrint string
function utils_to_string( toPrint )
    local selectPrint = utils.parse_json( utils.to_string(toPrint) )
    if selectPrint < 0 then
        selectPrint = utils.to_string(toPrint) .. " "
    end
    log_add( '{\\1c&H66ccff&}', "utils_to_string output: " .. selectPrint .. "\n" )
    pdbg(selectPrint)
    -- log_add( '{\\1c&H66ccff&}', "utils_to_string output: " .. selectPrint .. "\n" )
    --    log_add( '{\\1c&H66ccff&}', "utils_to_string output: " .. utils.to_string(toPrint)                                     .. "\n" )
end
--

---
--- repl draw setting get/set
---
---@param msg string
local function log_get_set(msg)
    local style = get_set_style or ''
    log_add(style, msg)
end

---
--- Show/Set console font size
---
function get_console_font_size()
    log_get_set("Console font size: " .. opts.font_size .. "\n" )
    update()
end

---@param text string
function set_console_font_size(text)
    if tonumber(text) ~= nil then
        opts.font_size = tonumber(text)
        log_get_set("Console font size: " .. opts.font_size .. "\n" )
    else
        log_add( '{\\1c&H66CCFF&}', text .. " is not a number.\n" )
    end
    update()
end

--- mp.register_script_message('get-console-size', get_console_font_size)
initialize_script_message('get-console-size', get_console_font_size)

--- mp.register_script_message('set-console-size', function(text) set_console_font_size(text) end)
initialize_script_message('set-console-size', function(text) set_console_font_size(text) end)

--- mp.register_script_message('console-size', function(text)
initialize_script_message('console-size', function(text)
    if text then set_console_font_size(text)
            else get_console_font_size()
    end
end)

---
--- Display console font name
---
function get_console_font_name()
    log_get_set(string.format("Console font: %s\n", opts.font))
    update()
end

---
--- Set console font name
---
function set_console_font_name(text)
    opts.font = text or opts.font
    log_get_set(string.format("Console font: %s\n", opts.font))
    update()
end

--- mp.register_script_message('get-console-font', function(text)
initialize_script_message('get-console-font', function(text)
    get_console_font_name()
end)

--- mp.register_script_message('set-console-font', function(text)
initialize_script_message('set-console-font', function(text)
    set_console_font_name(text)
end)

--- mp.register_script_message('console-font', function(text)
initialize_script_message('console-font', function(text)
    if text then set_console_font_name(text)
            else get_console_font_name()
    end
end)

--- mp.register_script_message('reload-macros', function()
initialize_script_message('reload-macros', function()
    local success = reload_macros()
    local cmd = ( success and [[print-text "[reload-macros] macros updated."]]
                            or  [[print-text "[reload-macros] Updating macros failed."]] )
    mp.command(cmd)
end)

-- Idiot checking
--- mp.register_script_message('debug-macro', function(token)
initialize_script_message('debug-macro', function(token)
    local global_macros = _G.macros
    msg.info('_G.macros: ' .. type(global_macros))

    local outer_macros = macros
    msg.info('macros: ' .. type(outer_macros))
end)

-- Temporary wrapper for running macros until I can fix the main eval system
--- mp.register_script_message('run-macro', function(token)
initialize_script_message('run-macro', function(token)
    if type(_G.macros) ~= "table" or #macros < 1 then
        msg.warn("[!run-macro] Macros table empty or non-table type.")
        for k, v in ipairs(macros) do
            msg.warn(tostring(k) .. ": '" .. v .. "'")
        end
        return
    end

    local expanded = expand_macro(token)
    msg.trace(string.format('[!run-macro] Expanded macro "%s" to "%s"', token, tostring(expanded)))
    if #expanded >= 1 then
        msg.trace(string.format('[!run-macro] Running expanded command: "%s"', expanded))
        mp.command(expanded)
    end
end)

--region Etc debug functions - for whatever

local function _log(str, alt_log_color)
    local logColor = alt_log_color or "5555DD" --#DD5555 #55DD55 #5555DD
    log_add( '{\\1c&H' .. logColor .. '&}', str )
end

local function log_line(str, alt_log_color)
    _log( str, alt_log_color )
    _log( "\n" )
end

function dbg_etc(text, alt_log_color)
    local alt_log_color = alt_log_color or "FFCC55" --#55CCFF #55FFCC #FFCC55 #FF55CC #CCFF55 #CC55FF

    log_line( text, alt_log_color )
end

--endregion Etc debug functions - for whatever

---
--- Toggle property passed in `name`, intended for true|false but takes w/e
---
---@param name string
---@param val1 any
---@param val2 any
function toggle_property(name, val1, val2)
    local val = mp.get_property(name)
    if(val == val1) then
        mp.set_property(name, val2)
        mp.osd_message(name .. ': ' .. val2)
    elseif(val == val2) then
        mp.set_property(name, val1)
        mp.osd_message(name .. ': ' .. val1)
    else
        mp.set_property(name, val1)
        mp.osd_message(name .. ': ' .. val .. ' => ' .. val1)
    end
end


--region builtin macros function

--- Return table containing builtin macro list
---@return macros
local function default_macro_table_factory()
    ---@type macros
    local macros = {}

      -- Player and Script Control Macros
        macros["font"]       = 'script-message repl-font'

        macros["size"]       = 'script-message repl-size'
        macros["con+"]      = 'script-message repl-size 45'

        macros["bbox"]       = '!repl-hide; !Blackbox;'
        macros["cbox"]       = '!repl-hide; !Colorbox;'
        macros["box"]        = '#bbox ;'

        macros["scale"]      = 'cycle-values scale ewa_lanczos lanczos bilinear'
        macros["hi"]         = 'set scale ewa_lanczos; cycle-values sharpen 1 .66 .33 0'

        macros["pitchshift"] = 'cycle audio-pitch-correction; set speed "${speed}" ;'
        macros["normalize"]  = 'cycle-values af "lavfi=[loudnorm]" "lavfi=[dynaudnorm=s=30]" ""'
        macros["an"]         = macros["normalize"]
        macros["acon5"]      = 'set af acontrast=5'
        macros["acon10"]     = 'set af acontrast=10'
        macros["acon20"]     = 'set af acontrast=20'
        macros["ac"]         = macros["acon10"]

        macros["screen"]     = 'async screenshot;'


        macros["safe"]       = 'define_section "no_accidents" "q ignore\nQ ignore\nENTER ignore\nq-q-q quit\n" "force"; enable-section "no_accidents"; print-text "Press q three times to exit as normal."'
        macros["safep"]      = '!type define_section "no_accidents" "q ignore\nQ ignore\nENTER ignore\nq-q-q quit\n" "force"; enable-section "no_accidents";  print-text "Press q three times to exit as normal."'
        macros["nosafe"]     = 'disable_section "no_accidents"; show-text "no_accidents section disabled."; print-text "no_accidents section disabled.";'

        macros["tonecmds"]   = '!type "set contrast ${contrast}; set brightness ${brightness}; set gamma ${gamma}; set saturation ${saturation};"'
        macros["toneab"]     = [[!type "define-section \"toggle_tone\" \"alt+t cycle-values contrast 0 ${contrast} ; cycle-values brightness 0 ${brightness} ; cycle-values gamma 0 ${gamma} ; cycle-values saturation 0 ${saturation} ; ]] ..
                                 [[ show-text \\\"contrast:   $$$${contrast$$$}\\\\nbrightness: $$$${brightness$$$}\\\\ngamma:      $$$${gamma$$$}\\\\nsaturation: $$$${saturation$$$}\\\"; ]] ..
                                 [[ print-text \\\"c/b/g/s $$$${contrast$$$}/$$$${brightness$$$}/$$$${gamma$$$}/$$$${saturation$$$}\\\"; ]] ..
                                 [[ \" \"force\" ; enable_section \"toggle_tone\" ;" ]]
        macros["ab"]         = macros["toneab"]
        macros["c"]          = macros["toneab"]
        macros["tonereset"]  = [[!type "set contrast 0; set brightness 0; set gamma 0; set saturation 0;"]]
        macros["levels"]     = [[ cycle-values video-output-levels limited full; ]]
        macros["levels"]     = macros["levels"]

        macros["lsize"]      = [[!list-max ]]

        macros["curveskill"] = [[!curves_kill]]
        macros["cq"]         = [[!curves-quiet]]
        macros["ce"]         = [[!curves-quit]]
        macros["cr"]         = [[!curves-restart]]

        macros["curvesoff"]  = macros["curveskill"]
        macros["nocurve"]    = macros["curveskill"]
        macros["cup"]        = [[!tone-upper ]]

      -- Info Macros
        macros["shrpscl"]    = 'print-text "[sharp] oversample <-> linear (triangle) <-> catmull_rom <-> mitchell <-> gaussian <-> bicubic [smooth]"'
        macros["vf"]         = "print-text 'Example vf command => vf set perspective=0:0.32*H:W:0:0:H:W:.8*H';"
        macros["vfex"]       = [[ !type "vf set perspective=0:0.32*H:W:0:0:H:W:.8*H" ]]
        macros["curves"]     =
                [[ print-text "## Commands, invoked with `script-message` ##";
                print-text "curves-brighten-show => Enter|Exit brightness mode";
                print-text "curves-cooler-show   => Enter|Exit temperature mode";
                print-text "curves-brighten      => Adjust brightness of video. Param: +/-1";
                print-text "curves-brighten-tone => Change the tone base [x] Param: +/-1";
                print-text "curves-temp-cooler   => Adjust the temperature by changing";
                print-text "▏                       R,G,B curve values";
                print-text "curves-temp-tone     => Change the tone base [x]";
                print-text "## Usage ##";
                print-text "In mpv, press b|y key to start manipulating color curves";
                print-text "Use arrow keys to move the point in the curve";
                print-text "r => Reset curves state";
                print-text "d => Delete the filter";
                print-text "Press b, y keys again to exit the curve mode."
                ]]
        macros["cacheinfo"]  =
                [[ print-text "#### Properties: Cache"
                print-text "cache                   => ${=cache}";
                print-text "cache-backbuffer        => ${=cache-backbuffer}";
                print-text "cache-default           => ${=cache-default}";
                print-text "cache-file              => ${=cache-file}";
                print-text "cache-file-size         => ${=cache-file-size}";
                print-text "cache-initial           => ${=cache-initial}";
                print-text "cache-pause             => ${=cache-pause}";
                print-text "cache-pause-initial     => ${=cache-pause-initial}";
                print-text "cache-pause-wait        => ${=cache-pause-wait}";
                print-text "cache-secs              => ${=cache-secs}";
                print-text "cache-seek-min          => ${=cache-seek-min}";
                print-text "demuxer-seekable-cache  => ${=demuxer-seekable-cache}";
                ]]
        macros["videoinfo"] =
                [[ print-text "#### Properties: Video"
                print-text "no-video                           => ${=no-video}";
                print-text "video                              => ${=video}";
                print-text "video-align-x                      => ${=video-align-x}";
                print-text "video-align-y                      => ${=video-align-y}";
                print-text "video-aspect                       => ${=video-aspect}";
                print-text "video-aspect-method                => ${=video-aspect-method}";
                print-text "video-latency-hacks                => ${=video-latency-hacks}";
                print-text "video-osd                          => ${=video-osd}";
                print-text "video-output-levels                => ${=video-output-levels}";
                print-text "video-pan-x                        => ${=video-pan-x}";
                print-text "video-pan-y                        => ${=video-pan-y}";
                print-text "video-rotate                       => ${=video-rotate}";
                print-text "video-sync                         => ${=video-sync}";
                print-text "video-sync-adrop-size              => ${=video-sync-adrop-size}";
                print-text "video-sync-max-audio-change        => ${=video-sync-max-audio-change}";
                print-text "video-sync-max-video-change        => ${=video-sync-max-video-change}";
                print-text "video-timing-offset                => ${=video-timing-offset}";
                print-text "video-unscaled                     => ${=video-unscaled}";
                print-text "video-zoom                         => ${=video-zoom}";
                print-text "demuxer-mkv-probe-video-duration   => ${=demuxer-mkv-probe-video-duration}";
                print-text "demuxer-rawvideo-codec             => ${=demuxer-rawvideo-codec}";
                print-text "demuxer-rawvideo-format            => ${=demuxer-rawvideo-format}";
                print-text "demuxer-rawvideo-fps               => ${=demuxer-rawvideo-fps}";
                print-text "demuxer-rawvideo-h                 => ${=demuxer-rawvideo-h}";
                print-text "demuxer-rawvideo-mp-format         => ${=demuxer-rawvideo-mp-format}";
                print-text "demuxer-rawvideo-size              => ${=demuxer-rawvideo-size}";
                print-text "demuxer-rawvideo-w                 => ${=demuxer-rawvideo-w}";
                print-text "image-subs-video-resolution        => ${=image-subs-video-resolution}";
                ]]
        macros["windowinfo"] =
                [[ print-text "window-dragging             => ${=window-dragging}";
                print-text "window-scale                => ${=window-scale}";
                print-text "scale-window                => ${=scale-window}";
                print-text "cscale-window               => ${=cscale-window}";
                print-text "dscale-window               => ${=dscale-window}";
                print-text "tscale-window               => ${=tscale-window}";
                print-text "force-window                => ${=force-window}";
                print-text "force-window-position       => ${=force-window-position}";
                print-text "snap-window                 => ${=snap-window}";
                print-text "keepaspect-window           => ${=keepaspect-window}";
                print-text "hidpi-window-scale          => ${=hidpi-window-scale}";
                ]]
        macros['oscinfo'] =
                [[ print-text "## OSCINFO ##";
                print-text "layout             =>  ${=layout} [Def: 'bottombar']";
                print-text "▏   The layout for the OSC. Currently available are: box, slimbox,";
                print-text "▏   bottombar and topbar. Default pre-0.21.0 was 'box'.";
                print-text "seekbarstyle       =>  ${=seekbarstyle} [Def: 'bar']";
                print-text "▏   Sets seekbar style: Slider (diamond marker) [Default pre-0.21.0]";
                print-text "▏                       Knob   (circle marker with guide)";
                print-text "▏                       Bar    (fill)";
                print-text "seekbarkeyframes   =>  ${=seekbarkeyframes} [Def: 'yes']";
                print-text "▏   Controls the mode used to seek when dragging the seekbar. By default,";
                print-text "▏   keyframes are used. If set to false, exact seeking on mouse drags";
                print-text "▏   will be used instead. Keyframes are preferred, but exact seeks may be";
                print-text "▏   useful in cases where keyframes cannot be found. Note that using exact";
                print-text "▏   seeks can potentially make mouse dragging much slower.";
                print-text "deadzonesize       =>  ${=deadzonesize} [Def: '0.5']";
                print-text "▏   Size of the deadzone. The deadzone is an area that makes the mouse act";
                print-text "▏   like leaving the window. Movement there won't make the OSC show up and";
                print-text "▏   it will hide immediately if the mouse enters it. The deadzone starts";
                print-text "▏   at the window border opposite to the OSC and the size controls how much";
                print-text "▏   of the window it will span. Values between 0.0 and 1.0, where 0 means the";
                print-text "▏   OSC will always popup with mouse movement in the window, and 1 means the";
                print-text "▏   OSC will only show up when the mouse hovers it. Default pre-0.21.0 was 0.";
                print-text "minmousemove       =>  ${=minmousemove} [Def: '0']";
                print-text "▏   Minimum amount of pixels the mouse has to move between ticks to make";
                print-text "▏   the OSC show up. Default pre-0.21.0 was 3.";
                print-text "showwindowed       =>  ${=showwindowed} [Def: 'yes']";
                print-text "▏   Enable the OSC when windowed";
                print-text "showfullscreen     =>  ${=showfullscreen} [Def: 'yes']";
                print-text "▏   Enable the OSC when fullscreen";
                print-text "scalewindowed      =>  ${=scalewindowed} [Def: '1.0']";
                print-text "▏   Scale factor of the OSC when windowed.";
                print-text "scalefullscreen    =>  ${=scalefullscreen} [Def: '1.0']";
                print-text "▏   Scale factor of the OSC when fullscreen";
                print-text "scaleforcedwindow  =>  ${=scaleforcedwindow} [Def: '2.0']";
                print-text "▏   Scale factor of the OSC when rendered on a forced (dummy) window";
                print-text "vidscale           =>  ${=vidscale} [Def: 'yes']";
                print-text "▏   Scale the OSC with the video";
                print-text "▏   `no` tries to keep the OSC size constant as much as the window size allows";
                print-text "valign             =>  ${=valign} [Def: '0.8']";
                print-text "▏   Vertical alignment, -1 (top) to 1 (bottom)";
                print-text "halign             =>  ${=halign} [Def: '0.0']";
                print-text "▏   Horizontal alignment, -1 (left) to 1 (right)";
                print-text "barmargin          =>  ${=barmargin} [Def: '0']";
                print-text "▏   Margin from bottom (bottombar) or top (topbar), in pixels";
                print-text "boxalpha           =>  ${=boxalpha} [Def: '80']";
                print-text "▏   Alpha of the background box, 0 (opaque) to 255 (fully transparent)";
                print-text "hidetimeout        =>  ${=hidetimeout} [Def: '500']";
                print-text "▏   Duration in ms until the OSC hides if no mouse movement, must not be";
                print-text "▏   negative";
                print-text "fadeduration       =>  ${=fadeduration} [Def: '200']";
                print-text "▏   Duration of fade out in ms, 0 = no fade";
                print-text "title              =>  ${=title} [Def: '${media-title}']";
                print-text "▏   String that supports property expansion that will be displayed as";
                print-text "▏   OSC title.";
                print-text "▏   ASS tags are escaped, and newlines and trailing slashes are stripped.";
                print-text "tooltipborder      =>  ${=tooltipborder} [Def: '1']";
                print-text "▏   Size of the tooltip outline when using bottombar or topbar layouts";
                print-text "timetotal          =>  ${=timetotal} [Def: 'no']";
                print-text "▏   Show total time instead of time remaining";
                print-text "timems             =>  ${=timems} [Def: 'no']";
                print-text "▏   Display timecodes with milliseconds";
                print-text "seekranges         =>  ${=seekranges} [Def: 'yes']";
                print-text "▏   Display seekable ranges on the seekbar";
                print-text "visibility         =>  ${=visibility} [Def: 'auto']";
                print-text "▏   Also supports `never` and `always`";
                print-text "boxmaxchars        =>  ${=boxmaxchars} [Def: '80']";
                print-text "▏   Max chars for the osc title at the box layout. mpv does not measure the";
                print-text "▏   text width on screen and so it needs to limit it by number of chars. The";
                print-text "▏   default is conservative to allow wide fonts to be used without overflow.";
                print-text "▏   However, with many common fonts a bigger number can be used. YMMV.";
                ]]
        macros['excerpt'] =
            [[ print-text "#### excerpt.lua"
            print-text "## Basics"
            print-text "▏This script allows to create excerpts of videos in mpv."
            print-text "▏ Press `i` to mark `begin`[ing] time value for excerpt output."
            print-text "▏ Press `o` to mark `end` time value for excerpt output."
            print-text "▏ Press `I` to jump to `begin` location, and initalize playback."
            print-text "▏ Press `O` to jump to `end` location, and pause."
            print-text "▏ Press `x` to start excerpt generation using an ffmpeg command"
            print-text "▏   using os.execute(), passing the following parameters: "
            print-text "▏   $1 => begin"
            print-text "▏   $2 => duration "
            print-text "▏   $3 => source filename"
            print-text "## Keybindings"
            print-text "▏   i            excerpt_mark_begin       [Forced]"
            print-text "▏   Shift+i (I)  excerpt_seek_begin       [Forced]"
            print-text "▏   o            excerpt_mark_end         [Forced]"
            print-text "▏   Shift+o (O)  excerpt_seek_end         [Forced]"
            print-text "▏   x            excerpt_write            [Forced]"
            print-text "▏   Shift+Right  excerpt_keyframe_forward (Repeatable, Complex)"
            print-text "▏   Shift+Left   excerpt_keyframe_back    (Repeatable, Complex)"
            print-text "▏   Right        excerpt_frame_forward    (Repeatable, Complex)"
            print-text "▏   Left         excerpt_frame_back       (Repeatable, Complex)"
            print-text "▏   e            excerpt_zoom_in          (Repeatable)"
            print-text "▏   w            excerpt_zoom_out         (Repeatable)"
            print-text "▏   Ctrl+Right   excerpt_pan_Right        (Repeatable)"
            print-text "▏   Ctrl+Left    excerpt_pan_left         (Repeatable)"
            print-text "▏   Ctrl+Up      excerpt_pan_up           (Repeatable)"
            print-text "▏   Ctrl+Down    excerpt_pan_down         (Repeatable)"
            print-text "## Script Messages ( invoked with `script-message`, or `!` prefix )"
            print-text "▏   `script-message in`,           `!in`           excerpt_mark_begin"
            print-text "▏   `script-message out`,          `!out`          excerpt_mark_end"
            print-text "▏   `script-message excerpt`,      `!excerpt`      excerpt_write"
            print-text "▏   `script-message excerpt-test`, `!excerpt-test` excerpt_test"
            ]]
    return macros
end

---
--- Wrapper for initial macro completion—just returns macro list
---
---@return macros
function get_macros()
    local dbg = titled_dbg_msg('get_macros', 'debug')

    if type(_G.macros) == "table" then
        dbg('Returning _G.macros table')
        return _G.macros

    elseif type(macros) == "table" then
        dbg('Returning macros table')
        return macros

    else
        titled_dbg_msg('get_macros', 'warn')('_G.macros and macros both did not resolve to table values.')
        return { }
    end
end


return { get_type = get_type,
         eval_line = eval_line,
         eval_line_new = eval_line_new,
         cons_line = cons_line,
         print_line = print_line,
         cycle_line = cycle_line,
         get_macros = get_macros,
         reload_macros = reload_macros,
         macros = macros,
         set_console_font_size = set_console_font_size,
         set_console_font_name = set_console_font_name,
         get_console_font_size = get_console_font_size,
         get_console_font_name = get_console_font_name  }
