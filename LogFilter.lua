--[[
    @TODO
    Fixed infinitely recursing tracing for now, maybe check later if the detection is oversensitive
]]

---@alias BlacklistRuleset      string[]
---@alias BlacklistLevelRuleset table<MessageLevel, boolean | nil>

---@class LogFilterRule
---@field public prefixes BlacklistRuleset      | nil @ Filters matching beginning of message
---@field public patterns BlacklistRuleset      | nil @ Filters matching pattern on message
---@field public levels   BlacklistLevelRuleset | nil @ Filters matching level of log event
---@field public never    boolean               | nil @ Filter enabling a global blacklist of messages from a log source

---@class LogEventTable
---@field prefix string
---@field level  MessageLevel
---@field text   string

local logging = require('log-ext')
local ctx_log = logging.Prefix.fmsg
local ib_log = logging.Prefix.fmsg('is_blacklist')

local script_name = mp.get_script_name()

local GLOBAL_FILTER_IDENT = '*'

---
--- Check if trace level logging should be performed for an event. Predicates in this check should
--- be static, global exceptions
---
---@param  log_event LogEventTable
---@return           boolean
local function should_never_trace(log_event)
    return log_event ~= nil
        and not (
            log_event.prefix == script_name
                or log_event.prefix == 'overflow'
                or log_event.level == 'trace'
                or log_event.level == 'fatal'
        )
end

local ConsoleLogFilter = nil -- Predeclaration for self-reference
ConsoleLogFilter =
{
    trace_logging = false,

    ---@type table<string, LogFilterRule>
    rules =
    {
        osc =
        {
            -- Ignore log messages from the OSD because of paranoia, since writing them
            -- to the OSD could generate more messages in an infinite loop.
            never = true
        },

        cplayer =
        {
            prefixes =
            {
                "Cannot find main.* for",
                "Can't load unknown script:",
                "Saving State."
            }
        },

        -- Ignore messages output by this script.
        [script_name] =
        {
            never = true
        },

        -- Ignore buffer overflow warning messages. Overflowed log messages would
        -- have been offscreen anyway.
        overflow =
        {
            never = true,
            silent = true
        },

        -- Global rule
        [GLOBAL_FILTER_IDENT] =
        {
            levels =
            {
                trace = true
            }
       }
    },

    ---
    --- Blacklist checker
    ---
    ---@param  event LogEventTable
    ---@return       boolean
    is_blacklisted = function(event)
        ---@type string[]
        local target_rules = { }

        --- Temp wrapper function to figuring out why some trace events are still going through
        --- when they shouldn't
        local function should_trace_event(event, rule)
            -- If rule isn't its never going to be explicitly silent
            rule = rule or { silent = false }
            return rule.silent == false and not should_never_trace(event)
        end

        -- Start by checking more coarse filtering rules first (level, prefix), and in the process
        -- also collect list of relevant rulesets to for finer filters below
        for rule_name, rule in pairs(ConsoleLogFilter.rules)
        do
            if event.prefix == rule_name or rule_name == GLOBAL_FILTER_IDENT
            then
                target_rules[#target_rules + 1] = rule_name
                if rule.never == true
                then
                    -- Only add log message if not console related
                    -- @TODO: Add a silent property on filter rule definitions to disable trace logging
                    if should_trace_event(event, rule)
                    then
                        ib_log.trace('script_name  => %s', script_name)
                        ib_log.trace('event.level  => %s', event.level)
                        ib_log.trace('event.prefix => %s', event.prefix)
                        ib_log.trace('[LogFilter:never] Matched: %s == %s', event.prefix, rule_name)
                    end
                    return true
                end
            end
        end

        local text = event.text

        -- Main scan loop for each prefix ruleset
        for _, rule_name in ipairs(target_rules)
        do
            local rule = ConsoleLogFilter.rules[rule_name]

            -- Event level match
            if type(rule.levels) == 'table'
            then
                for level, enabled in pairs(rule.levels)
                do
                    if event.level == level and should_trace_event(event, rule)
                    then
                        ib_log.trace('[LogFilter:%s:level] Matched: %s', event.level, level)
                        return true
                    end
                end
            end

            -- Prefix blacklist match
            if type(rule.prefixes) == "table"
            then
                for _, prefix in ipairs(rule.prefixes)
                do
                    if text:starts_with(prefix)
                    then
                        if should_trace_event(event, rule)
                        then
                            ib_log.trace('[LogFilter:%s:prefixes] Matched: %s', event.prefix, prefix)
                        end
                        return true
                    end
                end
            end

            -- Pattern blacklist match
            -- NOTE: Untested, no patterns defined atm
            if type(rule.patterns) == "table" then
                for _, pattern in ipairs(rule.patterns) do
                    if text:find(pattern) then
                        if should_trace_event(event, rule)
                        then
                            ib_log.trace('[LogFilter:%s:patterns] Matched: %s', event.prefix, prefix)
                        end
                        return true
                    end
                end
            end
        end
    end
}

return ConsoleLogFilter
