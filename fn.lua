local M =
{
    _NAME = 'Functional Library',
    _SOURCE =
    {
        _URL = 'http://lua-users.org/wiki/FunctionalLibrary',
        _AUTHOR = 'Shimomura Ikkei',
        _DATE = '2005/05/18'
    },
    _DESCRIPTION = 'Module form of source file. Original description:\n"""\nPorting several convenience functional utilities form Haskell, Python etc..\n"""\n'
}

---
--- ```lua
--- map(double, {1,2,3})    --> {2,4,6}
--- ```
---@generic T: any, R: any
---@param  tbl  T[]
---@param  func fun(t: T): R
---@return R[]
function M.map(func, tbl)
     local newtbl = {}
     for i,v in pairs(tbl) do
         newtbl[i] = func(v)
     end
     return newtbl
end

---
--- ``` lua
--- filter(is_even, {1,2,3,4}) --> {2,4}
--- ```
---
---@generic T: any
---@param   func fun(t: T): boolean
---@param   tbl  T[]
---@return  T[]
function M.filter(func, tbl)
     local newtbl= {}
     for i,v in pairs(tbl) do
         if func(v) then
	     newtbl[i]=v
         end
     end
     return newtbl
end

---
--- ```
--- head({1,2,3}) --> 1
--- ```
---
---@generic T
---@param   tbl T[]
---@return  T
function M.head(tbl)
     return tbl[1]
end

---
--- ```lua
--- tail({1,2,3}) --> {2,3}
--- ```
---
--- @NOTE This is a BAD and ugly implementation, should return the address to next pointer, like in C (arr+1)
---@generic V: any
---@param   tbl V[]
---@return  V[]
function M.tail(tbl)

    -- if type(tbl) == 'table' and #tbl > 0
    -- then

    -- else
    --     return nil
    -- end

    --region Original

    if length(tbl) < 1
    then
        return nil
    else
        local newtbl = {}
        local tblsize = length(tbl)
        local i = 2
        while (i <= tblsize) do
            table.insert(newtbl, i-1, tbl[i])
            i = i + 1
        end

        return newtbl
    end

    --endregion Original
end
-- foldr(function, default_value, table)
---
--- ```lua
--- foldr(operator.mul, 1, {1,2,3,4,5}) --> 120
--- ```
---
function M.foldr(func, val, tbl)
     for i,v in pairs(tbl) do
         val = func(val, v)
     end
     return val
end

---
--- ```lua
--- reduce(operator.add, {1,2,3,4}) --> 10
--- ```
---
function M.reduce(func, tbl)
     return foldr(func, head(tbl), tail(tbl))
end

---
--- ```lua
--- printf = curry(io.write, string.format)
---          --> function(...) return io.write(string.format(unpack(arg))) end
--- ```
---
function M.curry(f, g)
     return function (...)
         return f(g(unpack(arg)))
     end
end

---
--- Bind argument(s) and return new function. See also STL's functional, Boost's Lambda, Combine, Bind.
---
--- ```lua
--- local mul5 = bind1(operator.mul, 5) -- mul5(10) is 5 * 10
--- ```
---
--- @NOTE Check if its possible yet to properly type these
---@generic F: fun(arg: any): any
---@param   func F
---@param   val1 any
---@return  F
function M.bind1(func, val1)
     return function (...)
         return func(val1, ...)
     end
end

---@see M.bind1
---
--- ```lua
--- local sub2 = bind2(operator.sub, 2) -- sub2(5) is 5 -2
--- ```
---
--- @NOTE Check if its possible yet to properly type these
---@generic F: fun(arg: any, arg2: any): any
---@param   func F
---@param   val2 any
---@return  F
function M.bind2(func, val2) -- bind second argument.
    return function (val1)
        return func(val1, val2)
    end
end

---
--- Effective bind0
---
---@generic RT: any
---@param   func fun(): RT
---@return  fun(): RT
function M.thunk(func)
    return function()
        return func()
    end
end

---
--- Check function generator. Returns the function to return `boolean`, if the condition was expected then `true`, else `false`.
---
--- ```lua
--- local is_table = is(type, "table")
--- local is_even = is(bind2(math.mod, 2), 1)
--- local is_odd = is(bind2(math.mod, 2), 0)
--- ```
---
--- @NOTE Check if its possible yet to properly type these
---
---@generic E: any, C: fun(value: any): boolean
---@param check    C
---@param expected E
---@return fun(value: any): boolean
M.is = function(check, expected)
     return function (...)
         if (check(unpack(arg)) == expected) then
             return true
         else
             return false
         end
     end
end

-- operator table.
-- @see also python's operator module.
M.operator =
{
    mod = math.modf; -- Was mod?
    pow = math.pow;
    add = function(n,m) return n + m end;
    sub = function(n,m) return n - m end;
    mul = function(n,m) return n * m end;
    div = function(n,m) return n / m end;
    ---@param n number
    ---@param m number
    ---@return boolean
    gt  = function(n,m) return n > m end;
    ---@param n number
    ---@param m number
    ---@return boolean
    lt  = function(n,m) return n < m end;
    ---@param n number
    ---@param m number
    ---@return boolean
    eq  = function(n,m) return n == m end;
    ---@param n number
    ---@param m number
    ---@return boolean
    le  = function(n,m) return n <= m end;
    ---@param n number
    ---@param m number
    ---@return boolean
    ge  = function(n,m) return n >= m end;
    ---@param n number
    ---@param m number
    ---@return boolean
    ne  = function(n,m) return n ~= m end;

}

---
--- ```lua
--- enumFromTo(1, 10) --> {1,2,3,4,5,6,7,8,9}
--- ```
---
--- @TODO How to lazy evaluate in Lua? (thinking with coroutine)
---
---@param  from  number
---@param  to    number
---@return number[]
M.enumFromTo = function (from,to)
     local newtbl = { }
     local step = bind2(operator[(from < to) and "add" or "sub"], 1)
     local val = from
     while val <= to
     do
         table.insert(newtbl, table.getn(newtbl)+1, val)
         val = step(val)
     end
     return newtbl
end

---
--- Makes function to take variant arguments in place of a table. This does not mean expand the arguments of function received,
--- but expands the function's spec:
--- ```lua
--- function(tbl) --> function(...)
--- ```
---
--- @TODO: Not 100% on the grammar replacement in description
---
--- @NOTE Check if its possible yet to properly type these
---
---@generic TV: any
---@param func fun(tbl: TV[]): any
---@return fun(...): any
function M.expand_args(func)
    ---@vararg TV[]
    return function(...) return func(arg) end
end

return M
