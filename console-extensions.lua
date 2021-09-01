--- console2.lua -- Additional functions for mpv console script
---    "If console is so good why is there no console 2?"
---
--- Migrated from repl++ originally for repl.lua
---

--region Imports

local mp = mp
local msg    = require('log-ext').msg
local Prefix = require('log-ext').Prefix
local assdraw = require('mp.assdraw')
local utils = require('mp.utils')
local is = require('util.guard').is
local script_messages = require('script-message-tracker')

local opts = require('console-options').options

local macro = require('console.macros')
local default_macro_table_factory = macro.util.defaults.get_default_macros

--region External Command Scripts

require('commands.log-hooks')

--endregion External Command Scripts

--endregion Imports

--region Declarations

---@alias BuiltinTypeLiteral string | "'string'" | "'table'" | "'number'" | "'function'"

---@alias macros table<string, string>

--endregion Declarations

--region libcheck

do
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
end

--endregion libcheck

--region Script Info

-- Define lua info printing function while declaring lua env related funcs
-- NOTE: vararg reserved for later options (possibly)
--- Output lua environment info to repl
---@vararg string
local function print_luainfo(...)
    -- Print:
    -- Header
    -- mpv Version
    -- Lua Version
    -- ~~Print package related info~~

    local message_lines =
    {
        'mpv Lua Environment:',
        '    Lua Version:    ' .. mp.get_property('mpv-version', '[UNKNOWN]'),
        '    mpv Version:    ' .. tostring(_VERSION)
    }

    msg.info(table.concat(message_lines, '\n'))
    log_add('{\\1c&HFF9900&}', message_lines[1] .. '\n')
    log_add('', message_lines[2] .. '\n')
    log_add('', message_lines[3])
end

--- mp.register_script_message('lua', print_luainfo)
script_messages.register('lua', print_luainfo)

--endregion Script Info

--region Utils

---
--- Toggle property passed in `name`, intended for true|false but takes w/e
---
---@param name string
---@param val1 any
---@param val2 any
local function toggle_property(name, val1, val2)
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

--endregion Utils

--region Macros

-- Initialize
-- @NOTE: `console` prefix needed to fix LSP finding user's macros.lua in script-opts
macro.init()

-- For printing/log
local proc_arrow = '=>'
-- Blacklist of words for use in various macros
local blacklist = { "set", "cycle", "cycle-values" }

---
--- Get tokens from current line input and try expanding them
---
---@param line string
---@return nil
local function print_line(line)
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
    str = is.String(str) and str or ''
    for w in str:gmatch("%S+")
    do
    -- if w ~= "set" then
        if not blacklist[w]
        then
            local proptype = mp.get_property(tostring(w))
            print(proptype)
            local cmd = "print-text \"" .. w .. " ::= " ..  proptype .. "\""
            mp.command(cmd)
        end
    end
    update()
    return
end

local gt_log = msg.extend('get_type')
-- local gt_log = Prefix.fmsg('get_type')
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
    default_value = is.String(default_value) and default_value or ''
    str           = is.String(str)           and str           or ''

    gt_log.debug('Input string: "' .. str .. '"')
    -- if w ~= "set" then~
    local token = str:match("[a-zA-Z_\\/-]+") or ""

    gt_log.debug('Checking for property name (matched string) "' .. token .. '"')

    if token and #token > 0 and blacklist[token] == nil
    then
        local prop_value = mp.get_property_native(w, nil)
        if prop_value ~= nil
        then
            local prop_type = type(prop_value)
            gt_log.debug('mp.get_property_native("%s") => %s', token, tostring(prop_value))
            gt_log.debug('    Type: ' .. prop_type)
            return prop_type
        else
            gt_log.debug('mp.get_property_native("%s") => [nil]', token)
            return default_value
        end
    end
end

---
--- Cycle all boolean properties passed in string input
---
---@param line string
---@return nil
local function cycle_line(line)
    local cmd = ""
    for w in line:gmatch("%S+")
    do
        if not blacklist[w] then
            local prop = mp.get_property(tostring(w))
            if prop == "yes" or prop == "no"
            then
                toggle_property(w, "yes", "no")
                local cmd = "print-text \"" .. w .. " " .. proc_arrow .. " ${" .. w .. "}\" "
                mp.command(cmd)
            else
                _G.log_add('{\\1c&H66ccff&}', w .. " != Bool\n")
            end
        end
    end
    _G.update()
end

---
--- Naive implementation for (pre|ap)pending to each word in string input
---
---@param prefix  string
---@param line    string
---@param postfix string
---@return nil
function cons_line(prefix, line, postfix)
    go_home()
    prefix:gsub(".", function(c) handle_char_input(c) end)
    go_end()
    if postfix then
        postfix:gsub(".", function(c)
            handle_char_input(c)
        end)
        prev_char(postfix.len)
    end
    update()
end

--endregion Macros

--region    eval++

local log = msg.extend('eval_line')
---
--- Current implementation only looks for instruction symbol in first
--- non-whitespace char of line, and passes it into switch
--- TODO: Tokenize to some extent where possibly useful, possibly
---      eval word by word into valid chunks for existing switch
---
---@param line string
---@return nil
local function eval_line(line)
    log.debug('Evaluating line:\n"""\n%s\n"""', line)

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
        if line:match("[^%s]") == "#" and line:find("^[%s]*#[^%s#;]+")
        then
            local symbol_read = line:match("^[%s]*#[^%s#;]+"):sub(2)

            if _G.macros[symbol_read]
            then
                line = line:gsub(
                    "^([^#]*)(#[^%s]+)(.*)$",
                    function( pre, macro, post )
                        -- not sure if you can just return a string held together with spit in lua
                        local  expanded_line =  pre .. _G.macros[symbol_read] .. post
                        return expanded_line
                    end
                )

            end
        end
    end
    -- ! => script-message
    if line:match('[^"]*!')
    then
        -- lol
        return (do_line(line))
    else --????? Why did this go away
        return line
    end

    --endregion Main Function Block
end

local log = msg.extend('preprocess_line')
---
--- New line eval code
---
---@param _line string
---@return nil
local function preprocess_line(_line)

    ---@type string
    local line_init, line_proc = _line, _line

    -- Pull current line value if line argument not a string value
    if type(_line) ~= 'string'
    then
        log.warn('line parameter passed into eval_line is not a string, using global line value as a fallback.')
        if type(_G.line) ~= "string"
        then
            log.warn('Global line state (_G.line) also is not of string type.')
        end
    end

    -- local line_init = type(_line) == "string" and _line or _G.line

    local e_log = Prefix.fmsg('Line Eval')
    local dbg,         dbg_err,     warn  =
          e_log.trace, e_log.error, e_log.warn

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
        Prefix.fmsg_method('parse_statements', 'trace')('Parsed %i statements.', #statements)
        return statements
    end

    -- -- Macro block logging function
    -- --@param log_text string
    -- function dbg_macros( log_text )
    --     local debug_prefix = '[macros]'
    --     log_text = (type(log_text) and log_text) or ''
    --     msg.debug(debug_prefix .. ' ' .. log_text)

    -- end

    local t_log = log.extend('trim_macro_padding')
    ---@param  macro_text string
    ---@return            string
    local function trim_macro_padding(macro_text)
        macro_text = type(macro_text) == "string" and macro_text or ''
        if #macro_text < 1
        then
            msg.warn('[trim_macro_padding] macro_text is zero-length or non-string.')
            return ''
        else

            t_log.debug([[trim_macro_whitespace() called.]])

            -- To count the number of matches for spaces after new lines
            -- (Remove/comment this after everything appears to be working)
            local macro_text_clean, sub_count = macro_text:gsub([[%s+\n]] , "\n")

            t_log.debug('%i lines corrected.', tostring(sub_count))
            t_log.debug([[Corrected macro output:]])
            t_log.debug('  ' .. macro_text_clean )

            return macro_text_clean

            -- -- Direct substitution only
            -- macro_text:gsub( '\n[%s]+' , '\n')
        end
    end

    ---@param  raw_line string
    ---@return          string
    local function expand_macros(raw_line)

        local exp_log = log.extend('expand_macros')

        exp_log.debug('Entering macro expansion block.')

        if type(raw_line) ~= "string"
        then
            exp_log.warn('Value of line passed in raw_line argument is non-string type (%s).', type(raw_line))
            return ''

        --region Has macro-like tokens
        elseif raw_line:match("[^%s]") == "#" and raw_line:find("^[%s]*#[^%s#;]+") then
            local symbol_read = raw_line:match("^[%s]*#[^%s#;]+"):sub(2)

            exp_log.trace([[`#` prefix found in line. ]])
            exp_log.trace([[  raw_line:match("^[%%s]*#[^%%s#;]+"):sub(2) => %s]], string.dquot(symbol_read))

            if _G.macros[symbol_read]
            then
                -- Format macro value for repl after confirming the matched
                -- symbol does exist in the table
                local raw_macro_value = _G.macros[symbol_read]
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
                        -- local  expanded_line =  pre .. _G.macros[symbol_read] .. post
                        return expanded_line
                end)

                exp_log.trace([[ _G.macros["%s"]:%s"%s"."]], symbol_read, "\n", macro_value)

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
        local dbg = log.extend('do_line')

        dbg.trace(string.format('Processing line input: "%s"', line))

        -- Check for statement terminators, break down statements
        if line:match(';') then
            dbg.trace('Found semicolons in line, treating it like it contains multiple substatements.')
            local statements = parse_statements(line)
            if statements then
                local line_ = ""
                for _, s in ipairs(statements)
                do
                    dbg.trace('  Statement: %s', string.dquot(s))
                    --   Can't remember if originally script-message
                    -- prefixes to be tokens, full on prefixes, or both,
                    -- but majority use is as a prefix char to the token
                    -- so its going to be only that for now (with the
                    -- whitespace friendly version commented out for
                    -- later, of course.)
                    -- if s:match('![ ]*([^ ].*)') then
                    -- if s:match('!([^ ].*)') then
                    if s:match('^[%s]*!([^ ].*)')
                    then
                        dbg.trace('Expanding "!" script-message aliases for substatement.')
                        line_ = line_ .. (s:gsub('^[%s]*![%s]*', "script-message "))
                    else
                        line_ = line_ .. s
                    end
                end

                dbg.trace('Final line content: "%s"', line_)

                return line_
            end
        -- Handle line as one big statement if no terminators found
        else
            ---@type string
            local _line = ''
            dbg.trace('Treating line as one single statement.')
            if line:match('![ ]*([^ ].*)') then
                dbg.trace('Expanding "!" script-message aliases.')
                _line = (line:gsub('!', "script-message "))
            else
                dbg.trace('No script-message "!" aliases found to expand.')
                _line = line
            end

            dbg.trace('Final line content: %s', string.dquot(_line))

            return _line
        end
    end

    --endregion Subfunctions

    --region Main function block

    log.trace('About to enter macro expansion.')
    log.trace('  Line Input:')
    log.trace('    ' .. string.dquot(line_init) .. '')

    -- Expand all found macros initial line content
    line_proc = expand_macros(line_init)

    if type(line_proc) ~= "string" or #line_proc == 0
    then
        log.error('expand_macros returned empty or non-string line value. (type: ' .. tostring(type(line_proc)) .. ')')
        log.warn('Restoring original value of line after bad return value from expand_macros')
        line_proc = line_init
    else
        log.trace('Completed macro expansion')
        log.trace('  Line Output:')
        log.trace([[    '%s']], line_proc)
    end

    --[=[
    do
        --> TODO:   I think the issue with the repl not drawing immediately
        ---       might be in the macro block, at the moment its currently
        ---       replacing the whole line instead the macro token ( even
        ---       if this isn't the reason, its retarded )
        dbg( [[ Entering macro expansion block. ]] )
        if line:match("[^%s]") == "#" and line:find("^[%s]*#[^%s#;]+") then
            local symbol_read = line:match("^[%s]*#[^%s#;]+"):sub(2)

            dbg( [[ # prefix found in line. ]] )
            dbg( [[ line:match("^[%s]*#[^%s#;]+"):sub(2) => ']] .. symbol_read .. "'" )

            if _G.macros[symbol_read] then
                line = line:gsub(
                    '^([^#]*)(#[^%s]+)(.*)$',
                    function( pre, macro, post )
                        -- not sure if you can just return a string held together with spit in lua
                        local  expanded_line =  pre .. _G.macros[symbol_read] .. post
                        return expanded_line
                end)

                dbg( [[ [new] Result using line:gsub to expand macro in place instead of replacing the whole line => ]] .. "\n\t"  .. line )
                -- dbg( [[ [old] Established, lazier method => ]] .. "\n\t"  .. line )
                dbg( [[ Replacing value of line with _G.macros[]] .. symbol_read .. '].' )
                dbg( [[ _G.macros[" ]] .. symbol_read .. [[ "] => ']] ..  _G.macros[symbol_read] .. "'.'" )
                dbg( [[ This is still debug output, if you have not seen a second copy of the macro expansion (or its byproducts in the log) there is still a issue." ]] )
            end
        end
    end
    -- ! => script-message
    ]=]--

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
local function device_info(text)
    if not text or text == "a" then
        plist = mp.get_property_native("audio-device-list")
    else
        plist = mp.get_property_osd(text)
    end
    pdbg(plist)
end

local fi_log = Prefix.fmsg('filterinfo')
---
--- Audio Filter View
---
---@param  filter string
---@return nil
local function af_filter_info(filter)
    local do_filter = type(filter) == "string" and #filter > 0

    local styles =
    {
        heading = '{\\1c&HFF8409&}',
        accent  = '{\\b600\\1c&H40C010&}',
        delim   = '{\\1c&HAAAAAA&}',
        base    = '{\\1c&HBBBBBB&}',
        key     = '{\\1c&HFFEEDD&}',
        value   = '{\\1c&H5500DD&}', -- '{\\1c&H77DD66&}',
        dim     = '{\\1c&H444444&}',
    }

    ---@type AudioFilterNode[]
    local af_data = mp.get_property_native("af", {})

    for k, v in ipairs(af_data) do

        ---@type DetailedLogLine
        local entry = { }
        ---@param block LogLine
        local function append(block)
            entry[#entry + 1] =
            {
                style = (block.style or styles.base),
                text = block.text or ""
            }
        end

        append{ style = '' , text = ' ' }
        -- If tagged with a label
        if v.label
        then
            append{ style = styles.heading,
                    text  = '@' .. v.label }
        -- Otherwise filter index
        else
            append{ style = styles.base,
                    text  = tostring(k) }
        end
        append{ style = styles.base,   text = ' - ' }
        append{ style = styles.accent, text = v.name }

        if not v.enabled then
            append{ style = styles.base, text = ' '           }
            append{ style = styles.dim,  text = ' [disabled]' }
        else
            -- append{ style = styles.base, text = '' }
        end


        local params_added = 0
        local total = #v.params

        msg.fdebug('Processing %s parameters in filter %s', total, v.label or k)
        append{ style = styles.delim, text = ' { ' }
        for key, value in pairs(v.params) do
            append{ style = styles.key,   text = key }
            append{ style = styles.delim, text = "=" }
            append{ style = styles.value, text = tostring(value) }

            -- Append an additional key-values separator
            append{ style = styles.delim, text = ',' }

            -- Increment added count
            params_added = params_added + 1
        end

        -- Strip last comma node if params_added ever ticked up
        -- @NOTE: Might be better to always remove the last node, and then check the opposite
        --        before adding the closing bracket—(I think) in the case of no params it would
        --        remove the opening bracket, and then skip adding the closing one.
        if params_added > 0 then
            entry[#entry] = nil
        end

        append{ style = styles.delim, text = ' }' }

        append{ style = '', text = '\n' }

        -- Push constructred complex log history item
        log_add_advanced(entry)
    end
end

---@class AudioFilterNode
---@field public enabled boolean
---@field public name    string  | nil
---@field public label   string | nil
---@field public params  table<string, string>

---
--- A/V Device Explorer
---
--- mp.register_script_message('devices', function(text)
script_messages.register('afi', function(text) af_filter_info(text) end)

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
    if as_lines
    then
        local line_itr = assert(f:lines())
        local lines = { }

        for entry in f:lines()
        do
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
local function retreive_af_info_table()
    -- mpv command to generate info
    local af_help_command = [[mpv --no-config --af=help]]
    local af_help = os.capture(af_help_command)
end

local function print_af_help()
    msg.warn('[get-af-help] Unimplemented (possibly removed)')
end
--- mp.register_script_message('get-af-help', print_af_help)
script_messages.register('get-af-help', print_af_help)

---
--- Spew audio devices
---
---@param text string
local function audio_devices(text)
    plist = mp.get_property_osd("audio-device-list")
    --print(plist)
    utils.to_string(plist)
end

-- List (read: spew) audio devices
--- mp.register_script_message('print-devices', function(text)
script_messages.register('print-devices', function(text) audio_devices() end)

---
--- Loads script with the filename supplied via `script_name` argument.
--- Will attempt to remove lua file extension.
--- Currently no error checking as it won't crash the repl++ script,
--- but completion would be p great.
---
-- ---@ param script_name string
-- function load_mpv_script(script_name, keep_extension)
--     local plist = mp.get_property_osd("audio-device-list", '')
--     --print(plist)
--     utils_to_string(plist)
-- end

---
--- List (read: spew) audio devices
---
--- mp.register_script_message('print-devices', function(text)
script_messages.register('print-devices', function(text)
    audio_devices()
end)

--region    List macros

-- Pattern checking for flag to show definitions in output
local print_macros_with_def_flag_pattern = [[^(-d|--defs?|defs?|definitions?)$]]

---@param  first string
---@vararg       string
local function print_macros(first, ...)

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
        for symbol, _ in pairs(_G.macros) do
            -- NOTE: Moved to regex matching
            local found = (symbol:match(filter) and true or false)
            if found then
                msg.debug([[Adding ]]..symbol..[[ to display list.]])
                macro_list[symbol] = macros[symbol]
            end
        end
    else
        macro_list = _G.macros
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
script_messages.register('macros', function(...)
    print_macros(...)
end)

--endregion List macros

--region Expand macro into prompt buffer

---@param  token string
---@return       string
local function expand_macro(token)
    -- Exit if no argument string
    local token = (token or false)
    if not token then return end

    -- -- Check macro table for exact match and return its value if found
    local macros = _G.macros

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
    local dbg = Prefix.msg_method('type_macro', 'trace')
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
script_messages.register('macro-expand', function(token) return type_macro(token) end)
script_messages.register('type-macro',   function(token) return type_macro(token) end)

--endregion Expand macro into prompt buffer

--region Reload

local log = Prefix.fmsg('reload_resume')
-- special thanks to reload.lua (https://github.com/4e6/mpv-reload/)
local function reload_resume()
    log.debug('Starting reload procedure')

    local playlist_pos    = mp.get_property_number("playlist-pos")
    local reload_duration = mp.get_property_native("duration", -1)
    local time_pos        = mp.get_property("time-pos")

    mp.set_property_number("playlist-pos", playlist_pos)

    -- Tries to determine live stream vs. pre-recordered VOD. VOD has non-zero
    -- duration property. When reloading VOD, to keep the current time position
    -- we should provide offset from the start. Stream doesn't have fixed start.
    -- Decent choice would be to reload stream from it's current 'live' positon.
    -- That's the reason we don't pass the offset when reloading streams.
    if reload_duration and reload_duration > 0
    then
        local function seeker()
            mp.commandv("seek", time_pos, "absolute")
            mp.unregister_event(seeker)
        end
        mp.register_event("file-loaded", seeker)
    end
end

script_messages.register('reload', reload_resume)

--endregion Reload

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

--endregion Debug print function

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

local console_font_size_interval = 1
---
--- Update font size of console output, accepts a positive integer, or `++`/`--` as shorthands
--- for incrementing size up and down by an interval (1, hfor now)
---
---@param text string
function set_console_font_size(text)
    if     text == '++'
    then
        opts.font_size = math.max(1, opts.font_size + 1)
        log_get_set("Console font size: " .. opts.font_size .. "\n" )
    elseif text == '--'
    then
        opts.font_size = math.max(1, opts.font_size - 1)
        log_get_set("Console font size: " .. opts.font_size .. "\n" )
    elseif tonumber(text) ~= nil
    then
        opts.font_size = tonumber(text)
        log_get_set("Console font size: " .. opts.font_size .. "\n" )
    else
        log_add( '{\\1c&H66CCFF&}', text .. " is not a number.\n" )
    end

    update()
end

--- mp.register_script_message('get-console-size', get_console_font_size)
script_messages.register('get-console-size', get_console_font_size)

--- mp.register_script_message('set-console-size', function(text) set_console_font_size(text) end)
script_messages.register('set-console-size', function(text) set_console_font_size(text) end)

--- mp.register_script_message('console-size', function(text)
script_messages.register('console-size', function(text)
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
script_messages.register('get-console-font', function(text)
    get_console_font_name()
end)

--- mp.register_script_message('set-console-font', function(text)
script_messages.register('set-console-font', function(text)
    set_console_font_name(text)
end)

--- mp.register_script_message('console-font', function(text)
script_messages.register('console-font', function(text)
    if text then set_console_font_name(text)
            else get_console_font_name()
    end
end)

--- mp.register_script_message('reload-macros', function()
script_messages.register('reload-macros', function()
    local success = reload_macros()
    local cmd = ( success and [[print-text "[reload-macros] macros updated."]]
                            or  [[print-text "[reload-macros] Updating macros failed."]] )
    mp.command(cmd)
end)

-- Idiot checking
--- mp.register_script_message('debug-macro', function(token)
script_messages.register('debug-macro', function(token)
    local global_macros = _G.macros
    msg.info('_G.macros: ' .. type(global_macros))

    local outer_macros = macros
    msg.info('macros: ' .. type(outer_macros))
end)

-- Temporary wrapper for running macros until I can fix the main eval system
--- mp.register_script_message('run-macro', function(token)
script_messages.register('run-macro', function(token)
    if type(_G.macros) ~= "table" or #macros < 1
    then
        msg.warn("[!run-macro] Macros table empty or non-table type.")
        for k, v in ipairs(_G.macros) do
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

--endregion builtin macros function

return { get_type = get_type,
         eval_line = eval_line,
         preprocess_line = preprocess_line,
         cons_line = cons_line,
         print_line = print_line,
         cycle_line = cycle_line,
         get_macros = macro.instance.get_current_macros,
         reload_macros = reload_macros,
         macros = _G.macros,
         set_console_font_size = set_console_font_size,
         set_console_font_name = set_console_font_name,
         get_console_font_size = get_console_font_size,
         get_console_font_name = get_console_font_name  }
