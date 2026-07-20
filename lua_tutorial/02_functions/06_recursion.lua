----------------------------------------------------------------------
-- 06_recursion.lua — Recursion
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Recursion basics: base case + smaller subproblem
--   • The `local function f` vs `local f = function()` self-reference gotcha
--   • Stack overflow, and how proper tail calls avoid it
--   • Mutual recursion with forward declarations
--   • A tiny recursive table printer — a teaser for vim.inspect
-- HOW TO RUN
--   luajit 06_recursion.lua            (from this directory)
--   or inside nvim:  :luafile %        (with this file open)
-- PREREQUISITES: 05_higher_order_functions.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. The shape of recursion
-- A recursive function calls itself on a SMALLER version of the problem,
-- and has a BASE CASE where it stops calling and just answers. Both parts
-- are mandatory: no base case (or one you never reach) means the calls
-- never stop.

local function factorial(n)
  if n <= 1 then
    return 1 -- base case: smallest problem, answered directly
  end
  return n * factorial(n - 1) -- recursive case: shrink toward the base
end
print("factorial(5):", factorial(5))

-- Trace it in your head: factorial(3) waits for factorial(2), which waits
-- for factorial(1) = 1; then 2*1 = 2 comes back, then 3*2 = 6. Each waiting
-- call sits on the call stack until its sub-answer arrives.

-- Recursion shines when data is NESTED — and nested tables are everywhere
-- in Neovim: your lazy.nvim plugin specs contain tables inside tables
-- inside tables. Loops handle flat lists; recursion handles trees.

------------------------------------------------------------ 2. The self-reference gotcha
-- Lesson 01 promised this one. Recall:
--
--   local function f() ... end          -- form A
--   local f = function() ... end        -- form B
--
-- Form A desugars to `local f; f = function() ... end` — the NAME exists
-- before the body, so the body's `f` refers to the local. Recursion works.
--
-- Form B creates the function FIRST, then declares the local. While the
-- body is being compiled, no local `f` exists — so `f` inside the body
-- means the GLOBAL f. At call time that global is nil → crash.

local broken = function(n)
  if n <= 0 then return 0 end
  return n + broken(n - 1) -- `broken` here = _G.broken = nil. Boom.
end

local ok, err = pcall(broken, 3)
print("form B recursion:", ok, "|", err)
-- "attempt to call global 'broken'" — note GLOBAL: proof the body never
-- saw the local. In a Neovim config this surfaces as a config that loads
-- fine and only errors when the recursive path actually runs (a keypress,
-- an autocmd) — load-time success, runtime landmine.

-- Fix 1 (the default): use form A.
local function fixed(n)
  if n <= 0 then return 0 end
  return n + fixed(n - 1)
end
print("form A recursion:", pcall(fixed, 3))

-- Fix 2 (when you must use assignment, e.g. storing into a table):
-- declare first, assign second — form A's desugaring, written by hand:
local helper
helper = function(n)
  if n <= 0 then return 0 end
  return n + helper(n - 1)
end
print("declare-then-assign:", helper(3))

------------------------------------------------------------ 3. Stack overflow and tail calls
-- Every non-tail recursive call stacks a frame. Recurse too deep and the
-- stack overflows — a real error, catchable with pcall:

local function deep(n)
  return 1 + deep(n + 1) -- must wait to do "+1", so the frame stays stacked
end
local ok2, err2 = pcall(deep, 1)
print("runaway recursion:", ok2, "|", err2)

-- But Lua has PROPER TAIL CALLS: when a function's very last act is
-- `return f(...)` — nothing left to do afterwards, not even an addition —
-- Lua REPLACES the current frame instead of stacking a new one. Constant
-- stack, any depth. A million levels, no sweat:

local function countdown(n)
  if n == 0 then return "done" end
  return countdown(n - 1) -- tail call: `return f(x)` exactly
end
print("countdown(1e6):", countdown(1e6))

-- Beware near-misses that are NOT tail calls:
--   return 1 + f(x)     -- addition pending → stacks a frame
--   return (f(x))       -- parens adjust the result (lesson 02) → not a tail call
--   f(x)                -- no return: results discarded, and frame stacked

------------------------------------------------------------ 4. Mutual recursion needs a forward declaration
-- Two functions calling EACH OTHER hit the form-B problem in one
-- direction no matter the order you define them. The cure is the same
-- declare-first pattern from Fix 2:

local is_even, is_odd -- forward declarations: names exist, values pending

function is_even(n) -- sugar for is_even = function(n); assigns the LOCAL above
  if n == 0 then return true end
  return is_odd(n - 1)
end

function is_odd(n)
  if n == 0 then return false end
  return is_even(n - 1)
end

print("is_even(10):", is_even(10), "| is_odd(7):", is_odd(7))

------------------------------------------------------------ 5. Teaser: a recursive table printer
-- print() is useless on tables: you get `table: 0x...`. Inside Neovim
-- you'd reach for vim.inspect:
--   print(vim.inspect(tbl))   -- vim.inspect(t) → returns a readable string
--                             -- for any nested table.  :help vim.inspect
--   :lua =tbl                 -- the `=` sugar runs vim.inspect for you
-- Out here in plain luajit we have neither — so let's build the seed of
-- it. A table can contain tables, which contain tables... a tree. The
-- recursive move: print scalars directly; for a table value, recurse one
-- level deeper with bigger indentation.

local function dump(value, indent)
  indent = indent or "" -- default: top level, no indent (lesson 01 idiom)
  if type(value) ~= "table" then
    print(indent .. tostring(value))
    return
  end
  -- pairs(t) visits EVERY key/value in t (the generic-for + pairs combo is
  -- module 03 material — here, just read it as "for each field in value").
  for k, v in pairs(value) do
    if type(v) == "table" then
      print(indent .. tostring(k) .. ":")
      dump(v, indent .. "  ") -- the recursive descent
    else
      print(indent .. tostring(k) .. " = " .. tostring(v))
    end
  end
end

-- A slice of Hyprland config as nested Lua tables (module 08 territory):
local hypr = {
  general = { gaps_in = 3, gaps_out = 3, border_size = 1, layout = "dwindle" },
  decoration = {
    rounding = 10,
    active_opacity = 0.75,
    blur = { enabled = true, size = 4 },
  },
}
print("--- dump(hypr) ---")
dump(hypr)

-- Honest limitations (all handled by the real vim.inspect):
--   • a table containing itself (a cycle) recurses forever — real
--     inspectors track visited tables;
--   • pairs() order is unspecified, so runs may print keys in any order;
--   • strings print without quotes, so "3" and 3 look identical.
-- Rebuilding dump WITH cycle protection is this module's final exercise.

-- TRY IT ------------------------------------------------------------
-- 1. Add a print(indent, "->", n) as factorial's first line and re-run:
--    watch the descent. Then make factorial(0.5) — which case is hit?
--    Why does the base case use n <= 1 and not n == 1?
-- 2. Break `fixed` by renaming only its `local function fixed` to
--    `local function fixed2` (leave the body's call as fixed). Predict the
--    pcall output before running. Fix it back.
-- 3. Make countdown print n when n % 250000 == 0 so you can see it churn
--    through a million frames'-worth of calls without overflowing.
-- 4. Give dump a `depth` parameter and stop recursing below depth 2,
--    printing "..." instead — vim.inspect has this too ({ depth = 2 }).
