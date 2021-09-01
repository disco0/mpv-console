-- local mp = require('mp')
-- local msg = require('mp.msg')
-- debugging outside of mpv
local print = _G.print -- mp.msg.info

local ignore_patterns = { 'modules/', 'modules.js/', '@types/' }
local ignore_paths    = {  }

---
---@param searchdir string
---@return string[], number
---
function scan_dir(searchdir)
    local directory = {}

    local scan_cmd = 'ls -1vp ' .. string.format('%q', searchdir) .. ' 2>/dev/null'
    print(string.format('Running shell command:\n%s', scan_cmd))

    --list all files, using universal utilities and flags available on both Linux and macOS
    --  ls: -1 = list one file per line, -p = append "/" indicator to the end of directory names, -v = display in natural order
    --  stderr messages are ignored by sending them to /dev/null
    --  hidden files ("." prefix) are skipped, since they exist everywhere and never contain media
    --  if we cannot list the contents (due to no permissions, etc), this returns an empty list
    local popen, err = io.popen(scan_cmd)

    local i = 0

    if popen then
        for direntry in popen:lines() do
            local matchedignore = false
            for k, pattern in pairs(ignore_patterns) do
                if direntry:find(pattern) then
                    print('Ignoring ' .. direntry)
                    matchedignore = true
                    break --don't waste time scanning further patterns
                end
            end
            if not matchedignore and not ignore_patterns[searchdir --[[ replaces path ???]]..direntry] then
                directory[i] = direntry
                i = i + 1
            end
        end
        popen:close()
    else
        print("Could not scan for files :"..(err or ""))
    end
    return directory, i
end

---@param dir string
function find_script_files(dir)
    ---@type string, number
    local base_items, count = scan_dir(dir)
    if count then
        print(string.format('Enumerated %s entries', tostring(count)))
    end

    local base_scripts = { }
    local script_paths = { }

    for _, entry in ipairs(base_items) do
        -- print(string.format(' -> %s', entry))
        if entry:match('.js$') then
            base_scripts[#base_scripts + 1] = entry
            script_paths[#script_paths + 1] = entry

        elseif entry:match('.lua$') then
            base_scripts[#base_scripts + 1] = entry
            script_paths[#script_paths + 1] = entry

        elseif entry:sub(#entry):find('[/\\]') then
            -- Just return for now, but need to check for correct file in
            -- subdirectory
            script_paths[#script_paths + 1] = entry
            -- print('Directory: ' .. entry)
        end
    end

    return script_paths
end

local input_dir = os.getenv('MPV_HOME') .. '/scripts'

print('Results:')
for _, path in ipairs(find_script_files(input_dir)) do
    print(string.format('  -> %s', path))
end
-- return {
--     scan_dir = scan_dir
-- }
