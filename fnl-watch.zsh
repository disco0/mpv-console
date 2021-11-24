#!/usr/bin/env zsh

local script_dir=${0:A:h}
local target_dir=${script_dir}

# TOOD: Place fnl source files in src subfolder, compile and output to parent ./src => ./
# TOOD: Separate out macros
local source_subdir=src
local macro_subdir=macros

#region Dependencies

local req_cmds=( watchexec fennel )
foreach req ( $^req_cmds )
    if [[ ! -e =${req} ]]
    then
        builtin print -P -- "%F{1}Failed to resolve command on path: %B${req}%b%f"
        return 1
    fi
end

#endregion Dependencies

# Expected parameter name to be passed through via environment
# (WATCHEXEC_WRITTEN_PATH => File modifications)
local target_param='WATCHEXEC_WRITTEN_PATH'

###
 # Reads in a file path, and compiles to the same directory—less crusty version of original inline
 # zsh script
 ##
function compile-fennel()
{
    if [[ -z $1 ]]
    then
        builtin print -Pu2 '%F{167}Missing or zero-length first argument.%f'
        if [[ -n $2 ]]
        then
            builtin print -Pu2 "%F{167}Second argument: %{$2%}%f"
        fi
        return 2

    elif [[ ! -f $1 ]]
    then
        builtin print -Pu2 "%F{1}Path passed in first argument does not exist: %U%B%{$1%}%u%b"
        if [[ -n $2 ]]
        then
            builtin print -Pu2 "%F{167}Second argument: %{$2%}%f"
        fi
        return 3
    fi

    local outfile=${${1:h}%%([\/]|)${source_subdir}([\/]|)}/${1:t:r}.lua
    ${commands[fennel]} --compile $1 > $outfile

    # # Original, longer version
    # builtin print -Pu2 "%F{32}Updated: %U%B%{${1/#${PWD}([\/]|)/.\/}%u%b%} -> %{%U%B${outfile/#${PWD}([\/]|)/.\/}%}%u%b%f"
    builtin print -Pu2 -- " %F{249}->%f %F{32}%U%B%{${outfile/#${PWD}([\/]|)/.\/}%}%u%b%f"
}

local watchexec_args=(
    --postpone
    --watch $target_dir
    --filter "**/${source_subdir}/*"
    --ignore "**/${macro_subdir}/*"
    --exts fnl
)

builtin print -Pu2 -- "Watching directory: %U%B%{${target_dir}%}%u%b"
command watchexec $^watchexec_args echo $"${target_param}" \
    | while { read fnl_path } {
        compile-fennel $fnl_path
    }
