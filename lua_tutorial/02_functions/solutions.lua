----------------------------------------------------------------------
-- solutions.lua — Module 02: Functions — complete solutions
----------------------------------------------------------------------
-- HOW TO RUN
--   luajit solutions.lua               (from this directory)
-- Try each exercise yourself in exercises.lua BEFORE reading these.
-- Every solution notes its key insight in one or two lines.
----------------------------------------------------------------------

print("== Module 02 solutions ==")

------------------------------------------------------------ EXERCISE 1: clamp
-- Key insight: `x or default` fills in missing args, and clamping is just
-- max-then-min (raise to the floor, then cap at the ceiling).

local function clamp(n, lo, hi)
  lo = lo or 0
  hi = hi or 1
  return math.max(lo, math.min(n, hi))
end

print("\n-- exercise 1: clamp")
print(clamp(5, 1, 10) == 5)
print(clamp(-3, 1, 10) == 1)
print(clamp(99, 1, 10) == 10)
print(clamp(2) == 1)

------------------------------------------------------------ EXERCISE 2: divmod
-- Key insight: one `return` can carry both values; the CALLER decides how
-- many to keep (adjustment, lesson 02).

local function divmod(a, b)
  local q = math.floor(a / b)
  return q, a - q * b
end

print("\n-- exercise 2: divmod")
local q, r = divmod(17, 5)
print(q == 3 and r == 2)
print(select("#", divmod(17, 5)) == 2)

------------------------------------------------------------ EXERCISE 3: pick
-- Key insight: select(i, ...) returns everything from i ON — the parens
-- adjust that list down to exactly one value (lesson 02's "trap", used
-- deliberately). And select never loses nil holes, unlike ({...})[i]...
-- well, indexing preserves nil too, but # and ipairs on {...} would lie.

local function pick(i, ...)
  return (select(i, ...))
end

print("\n-- exercise 3: pick")
print(pick(2, "a", "b", "c") == "b")
print(pick(3, "a", nil, "c") == "c")
print(select("#", pick(1, "x", "y")) == 1)

------------------------------------------------------------ EXERCISE 4: make_stepper
-- Key insight: `current` is an upvalue — each make_stepper call creates a
-- fresh one, so every stepper carries private, persistent state.

local function make_stepper(start, step)
  step = step or 1
  local current = start
  return function()
    local value = current
    current = current + step
    return value
  end
end

print("\n-- exercise 4: make_stepper")
local s = make_stepper(10, 5)
print(s() == 10, s() == 15, s() == 20)
local down = make_stepper(3, -1)
print(down() == 3, down() == 2)
local d1, d2 = make_stepper(0), make_stepper(0)
d1()
print(d2() == 0)

------------------------------------------------------------ EXERCISE 5: sum_even_squares
-- Key insight: each helper returns a plain table/value, so they nest like
-- shell pipes read right-to-left: filter | map | reduce.

local function map(t, fn)
  local out = {}
  for i = 1, #t do out[i] = fn(t[i]) end
  return out
end
local function filter(t, pred)
  local out = {}
  for i = 1, #t do
    if pred(t[i]) then out[#out + 1] = t[i] end
  end
  return out
end
local function reduce(t, fn, init)
  local acc = init
  for i = 1, #t do acc = fn(acc, t[i]) end
  return acc
end

local function sum_even_squares(t)
  return reduce(
    map(
      filter(t, function(n) return n % 2 == 0 end),
      function(n) return n * n end
    ),
    function(a, b) return a + b end,
    0
  )
end
-- (Squaring after filtering does less work; squaring first then filtering
-- with n > 5-style predicates would need care. Either order sums to the
-- same 56 here since squares of evens are exactly the even squares.)

print("\n-- exercise 5: sum_even_squares")
print(sum_even_squares({ 1, 2, 3, 4, 5, 6 }) == 56)
print(sum_even_squares({}) == 0)

------------------------------------------------------------ EXERCISE 6: fix the keymap bug
-- Key insight: an rhs slot needs a function VALUE. `reload_config` is one;
-- `reload_config()` is its return value. When the action needs an
-- argument, wrap the call in a closure so the WRAPPER is the value.

local keymap = {}
local function keymap_set(lhs, rhs)
  keymap[lhs] = rhs
end
local function press(lhs)
  local rhs = keymap[lhs]
  if type(rhs) == "function" then return rhs() end
  return "DEAD KEY (rhs is " .. type(rhs) .. ")"
end

local function reload_config()
  return "config reloaded"
end
local function open_file(path)
  return "opened " .. path
end

keymap_set("<leader>r", reload_config)                            -- was correct
keymap_set("<leader>o", function() return open_file("~/todos.md") end) -- closure bakes the arg
keymap_set("<leader>R", reload_config)                            -- drop the ()

print("\n-- exercise 6: keymap bug")
print(press("<leader>r"))
print(press("<leader>o"))
print(press("<leader>R"))

------------------------------------------------------------ EXERCISE 7: flatten
-- Key insight: recursion mirrors the data — table element? descend.
-- plain value? append. The inner helper shares ONE `out` via capture, so
-- there's nothing to merge afterwards. `local function` makes the
-- self-call work (lesson 06).

local function flatten(t)
  local out = {}
  local function walk(list)
    for i = 1, #list do
      local v = list[i]
      if type(v) == "table" then
        walk(v) -- descend
      else
        out[#out + 1] = v -- append
      end
    end
  end
  walk(t)
  return out
end

print("\n-- exercise 7: flatten")
local flat = flatten({ 1, { 2, { 3, 4 } }, 5 })
print(table.concat(flat, ",") == "1,2,3,4,5")
print(#flatten({}) == 0)

------------------------------------------------------------ EXERCISE 8: compose
-- Key insight: capture the function list once ({...} is safe — functions
-- are never nil here), then fold over it INSIDE the returned closure,
-- right-to-left. The innermost call forwards ALL arguments; after that a
-- single value flows outward.

local function compose(...)
  local fns = { ... }
  local n = select("#", ...)
  return function(...)
    if n == 0 then return ... end -- compose() = identity, multi-value even
    local value = fns[n](...) -- innermost gets every argument
    for i = n - 1, 1, -1 do -- walk outward, right-to-left
      value = fns[i](value)
    end
    return value
  end
end

print("\n-- exercise 8: compose")
local add1 = function(n) return n + 1 end
local dbl = function(n) return n * 2 end
print(compose(add1, dbl)(5) == 11)
print(compose(dbl, add1)(5) == 12)
print(compose(add1)(1) == 2)
print(compose()(7) == 7)
print(compose(add1, function(a, b) return a + b end)(3, 4) == 8)

print("\nAll solutions ran.")
