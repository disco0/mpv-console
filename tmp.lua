--[====[


local string = string

---@param  pattern string
---@return         string[]
function string:match_all(pattern)
    local result = {}
    for m in self:gmatch('[^,]+') do
        result[#result+1] = m
    end
    return result
end

local function cached_function(fn)
    assert((type(fn) == 'function'), 'Cannot cache non-function type value')

    -- Wouldn't it be nice 2 define this as table<Parameter<T>[0], ReturnType<T>>
    local cache = { }

    return function(...)
        if  cache[{...}]
    end
end

local function test()
   print(combine_vararg(1, 2, 3))
   print(combine_vararg(1, {}, 3))
end

test()

local function local_function() end
local local_variable = ''
-- function global_function() end
-- global_variable = ''
do
    print(local_function)
    print(local_function())
    print(local_variable)
    -- print(global_function)
    -- print(global_function())
    -- print(global_variable)

end



]====]--
