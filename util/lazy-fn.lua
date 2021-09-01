local M = { }

---@alias LazyTag string | '"thunk"'
---@alias LazyPart string | '"first"' | '"rest"'

function M.makeThunk(f, args)
    return { tag = "thunk", f = f, args = args }
end

function M.evalThunk(t)
    return t.f(unpack(t.args))
end

function M.cons(first, rest)
    return { first = first, rest = rest }
end

function M.range(b, e, s)
    b = b or 0
    s = s or 1

    if e == nil or b <= e
    then
        return M.cons(b, M.makeThunk(M.range, { b + s, e, s }))
    end
end

---@param part LazyPart
function M.evalPart(t, part)
    if t == nil
    then
        return nil
    elseif type(t[part]) == "table" and t[part].tag == "thunk"
    then
        t[part] = M.evalThunk(t[part])
    end

    return t[part]
end

function M.first(t)
    return M.evalPart(t, "first")
end

function M.rest(t)
    return M.evalPart(t, "rest")
end

function M.nth(t, n)
    if n == 0
    then
        return M.first(t)
    end

    return M.nth(M.rest(t), n - 1)
end

function M.map(f, l)
    return M.cons(f(M.first(l)), M.makeThunk(M.map, { f, M.rest(l) }))
end

function M.filter(f, l)
    while not f(M.first(l)) do
        l = M.rest(l)
    end
    return M.cons(M.first(l), M.makeThunk(M.filter, { f, M.rest(l) }))
end

--[[ Examples --------------------------------------------------------------------

function M.fact(n, f)
    n = n or 1
    f = f or 1
    return cons(n, makeThunk(fact, { n * f, f + 1 }))
end

function M.fib(a, b)
    a = a or 0
    b = b or 1
    return cons(a, makeThunk(fib, { b, a + b }))
end

-- > a = fib()
-- > print(nth(a, 0))
-- 0
-- > print(nth(a, 1))
-- 1
-- > print(nth(a, 2))
-- 1
-- > print(nth(a, 3))
-- 2
-- > print(nth(a, 13))
-- 233

--]]

-- Continuations ---------------------------------------------------------------

function M.sum(n, cont)
    if n <= 1 then
        return M.makeThunk(cont, { 1 })
    end
    local function newCont(v)
        return M.makeThunk(cont, { v + n })
    end

    return M.makeThunk(sum, { n - 1, newCont })
end

function M.trampoline(thunk)
    while true
    do
        if type(thunk) ~= "table"
        then
            return thunk
        elseif thunk.tag == "thunk"
        then
            thunk = M.evalThunk(thunk)
        end
    end
end
