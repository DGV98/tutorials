----------------------------------------------------------------------
-- exercises.lua — Module 02: Functions
----------------------------------------------------------------------
-- HOW TO WORK
--   Fill in the TODOs one exercise at a time, then re-run:
--     luajit exercises.lua             (from this directory)
--   Each exercise has CHECK lines commented out below it. Uncomment them
--   as you go — they print `true` (or the expected value) when your code
--   is right. The file runs clean as-is; nothing errors until you make it.
-- PREREQUISITES: lessons 01–06 of this module
----------------------------------------------------------------------

print("== Module 02 exercises ==")

------------------------------------------------------------ EXERCISE 1: clamp (defaults)
-- Write clamp(n, lo, hi): return n, but no lower than lo and no higher
-- than hi. lo defaults to 0 and hi defaults to 1 when omitted (lesson 01).

local function clamp(n, lo, hi)
  -- TODO: apply defaults, then clamp (math.min/math.max help)
  return n
end

print("\n-- exercise 1: clamp")
-- CHECK: uncomment when ready
-- print(clamp(5, 1, 10) == 5)    -- expect true
-- print(clamp(-3, 1, 10) == 1)   -- expect true
-- print(clamp(99, 1, 10) == 10)  -- expect true
-- print(clamp(2) == 1)           -- expect true (defaults 0..1)

------------------------------------------------------------ EXERCISE 2: divmod (multiple returns)
-- Write divmod(a, b): return the integer quotient AND the remainder as
-- TWO values (math.floor for the quotient; remainder = a - quotient*b,
-- or use the % operator).

local function divmod(a, b)
  -- TODO
end

print("\n-- exercise 2: divmod")
-- CHECK:
-- local q, r = divmod(17, 5)
-- print(q == 3 and r == 2)                 -- expect true
-- print(select("#", divmod(17, 5)) == 2)   -- expect true: really two values

------------------------------------------------------------ EXERCISE 3: pick (select)
-- Write pick(i, ...): return ONLY the i-th vararg — exactly one value,
-- even when later varargs exist. select(i, ...) gets you "from i on";
-- lesson 02 showed two ways to keep just the first of those.
-- It must survive nil holes: pick(2, "a", nil, "c") is nil, but
-- pick(3, "a", nil, "c") is "c".

local function pick(i, ...)
  -- TODO
end

print("\n-- exercise 3: pick")
-- CHECK:
-- print(pick(2, "a", "b", "c") == "b")           -- expect true
-- print(pick(3, "a", nil, "c") == "c")           -- expect true
-- print(select("#", pick(1, "x", "y")) == 1)     -- expect true: ONE value out

------------------------------------------------------------ EXERCISE 4: make_stepper (closures)
-- Write make_stepper(start, step): return a function that, on each call,
-- returns the current value and then advances by step (lesson 04's
-- counter, generalized). step defaults to 1.

local function make_stepper(start, step)
  -- TODO: return a closure
end

print("\n-- exercise 4: make_stepper")
-- CHECK:
-- local s = make_stepper(10, 5)
-- print(s() == 10, s() == 15, s() == 20)   -- expect true true true
-- local down = make_stepper(3, -1)
-- print(down() == 3, down() == 2)          -- expect true true
-- local d1, d2 = make_stepper(0), make_stepper(0)
-- d1() print(d2() == 0)                    -- expect true: independent state

------------------------------------------------------------ EXERCISE 5: sum of squares of evens (map/filter/reduce)
-- map, filter, reduce are provided (from lesson 05). Combine them in ONE
-- expression to compute the sum of the squares of the even numbers in t.
-- For { 1..6 } that's 4 + 16 + 36 = 56.

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
  -- TODO: one return statement combining the three helpers
end

print("\n-- exercise 5: sum_even_squares")
-- CHECK:
-- print(sum_even_squares({ 1, 2, 3, 4, 5, 6 }) == 56)  -- expect true
-- print(sum_even_squares({}) == 0)                     -- expect true

------------------------------------------------------------ EXERCISE 6: fix the keymap bug (fn vs fn())
-- Below is a miniature keymap system (from lesson 05) and THREE
-- registrations. Two of them contain the classic reference-vs-call bug.
-- Fix the registrations — do NOT change keymap_set, press, or the two
-- action functions. One of the fixes needs a closure (the action takes
-- an argument!).

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

-- TODO: fix the buggy registrations below
keymap_set("<leader>r", reload_config)              -- (this one is correct)
keymap_set("<leader>o", open_file("~/todos.md"))    -- BUG: runs at setup time
keymap_set("<leader>R", reload_config())            -- BUG: same disease

print("\n-- exercise 6: keymap bug")
-- CHECK: all three should print an action string, no DEAD KEY:
-- print(press("<leader>r"))   -- expect: config reloaded
-- print(press("<leader>o"))   -- expect: opened ~/todos.md
-- print(press("<leader>R"))   -- expect: config reloaded

------------------------------------------------------------ EXERCISE 7: flatten (recursion)
-- Write flatten(t): t is an array whose elements are values OR nested
-- arrays, any depth. Return a flat array of all the values in order.
-- flatten({1, {2, {3, 4}}, 5}) → {1, 2, 3, 4, 5}.
-- Hints: `local function` so it can recurse (lesson 06). Either build the
-- output with a helper(out, t), or concatenate results — helper is easier.

local function flatten(t)
  -- TODO
end

print("\n-- exercise 7: flatten")
-- CHECK:
-- local flat = flatten({ 1, { 2, { 3, 4 } }, 5 })
-- print(table.concat(flat, ",") == "1,2,3,4,5")   -- expect true
-- print(#flatten({}) == 0)                        -- expect true

------------------------------------------------------------ EXERCISE 8 (the stinger): compose
-- Write compose(...): takes ANY number of functions and returns ONE
-- function that applies them right-to-left, math style:
--   compose(f, g, h)(x)  ==  f(g(h(x)))
-- Requirements:
--   • works for any count, including compose() (returns its input as-is)
--   • the composed function should pass along multiple values where it
--     can (at minimum: the INNERMOST function receives all arguments)
-- Everything you need: {...} or select (lesson 03), closures (lesson 04),
-- and either a loop or recursion (lesson 06).

local function compose(...)
  -- TODO
end

print("\n-- exercise 8: compose")
-- CHECK:
-- local add1 = function(n) return n + 1 end
-- local dbl = function(n) return n * 2 end
-- print(compose(add1, dbl)(5) == 11)         -- f(g(x)): (5*2)+1
-- print(compose(dbl, add1)(5) == 12)         -- order matters: (5+1)*2
-- print(compose(add1)(1) == 2)               -- single function
-- print(compose()(7) == 7)                   -- identity
-- print(compose(add1, function(a, b) return a + b end)(3, 4) == 8)
--                                            -- innermost gets BOTH args

print("\nDone. Uncomment the CHECK lines as you solve each exercise.")
