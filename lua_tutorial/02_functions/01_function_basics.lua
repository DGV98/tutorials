----------------------------------------------------------------------
-- 01_function_basics.lua — Defining and calling functions
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Defining functions and calling them
--   • Parameters: missing arguments become nil, extras are dropped
--   • return, and returning early
--   • Functions are ordinary VALUES you can assign to locals
--   • Two spellings: `local function f()` vs `local f = function()`
-- HOW TO RUN
--   luajit 01_function_basics.lua      (from this directory)
--   or inside nvim:  :luafile %        (with this file open)
-- PREREQUISITES: module 01 (values, variables, control flow)
----------------------------------------------------------------------

------------------------------------------------------------ 1. Defining and calling
-- A function is a block of code with a name (usually) and a parameter list.
-- Think of it like a shell function in zsh: `greet() { echo "hi $1" }`,
-- except Lua parameters have real names instead of $1, $2.
--
-- Always `local`! A bare `function greet()` would create a GLOBAL, and in a
-- Neovim config every plugin shares the same global table `_G` — a global
-- named `greet` in your config can collide with (or be clobbered by) any
-- plugin. Locals are private to this file (chunk). Make `local` a reflex.

local function greet(name)
  print("hello, " .. name)
end

greet("David") -- calling: parentheses, arguments in order

------------------------------------------------------------ 2. Missing args become nil, extras are dropped
-- Lua NEVER complains about arity. Call with too few arguments and the
-- missing parameters are just nil. Call with too many and the extras are
-- silently thrown away. No error either way — which is flexible, but it
-- means typos in call sites fail LATER (when you use the nil), not at the
-- call. This is behind a huge share of real-world Neovim config bugs:
-- "attempt to concatenate a nil value" three lines away from the real typo.

local function describe(a, b)
  print("a =", a, "| b =", b)
end

describe(1, 2)       -- a = 1  | b = 2
describe(1)          -- a = 1  | b = nil   (missing → nil)
describe(1, 2, 3, 4) -- a = 1  | b = 2     (3 and 4 dropped, no warning)

-- The standard idiom for a default value uses `or` (from module 01:
-- `x or default` yields default when x is nil or false):
local function pad(text, width)
  width = width or 10 -- default width when caller omits it
  return text .. string.rep(".", width - #text)
end
print("pad default:", pad("hi"))
print("pad explicit:", pad("hi", 5))

-- Watch out: `or` also replaces `false`. For boolean parameters where the
-- caller might legitimately pass false, test for nil explicitly:
local function toggle(state)
  if state == nil then state = true end -- only replace MISSING, not false
  return state
end
print("toggle():", toggle())       -- true  (defaulted)
print("toggle(false):", toggle(false)) -- false (respected!)

------------------------------------------------------------ 3. return, and returning early
-- `return` hands a value back to the caller and exits the function
-- immediately. A function with no `return` (or a bare `return`) returns
-- nothing — reading its "result" gives nil.

local function sign(n)
  if n > 0 then
    return "positive" -- early return: we're done, skip the rest
  end
  if n < 0 then
    return "negative"
  end
  return "zero"
end

print("sign(42):", sign(42))
print("sign(-7):", sign(-7))
print("sign(0):", sign(0))

-- Early returns are the idiomatic Lua way to handle "bail out" cases first,
-- exactly like `[[ -z "$1" ]] && return 1` at the top of a shell function:
local function first_line(s)
  if type(s) ~= "string" then
    return nil, "expected a string" -- guard clause; more on the 2nd value in lesson 02
  end
  return (s:match("[^\n]*"))
end
print("first_line:", first_line("line1\nline2"))
print("first_line(42):", first_line(42))

-- Syntax detail: `return` must be the LAST statement in its block. You
-- can't put code after it (Lua rejects the file at load time). If you want
-- an early return mid-block, that's fine — `if ... then return x end` is a
-- complete block of its own.

------------------------------------------------------------ 4. Functions are values
-- This is THE big idea of this module. A function is a value like 42 or
-- "hi": you can store it in a variable, put it in a table, pass it to
-- another function, return it from a function. `greet` above isn't "a
-- function named greet" — it's a local VARIABLE that currently holds a
-- function value.

local shout = function(s) -- an anonymous function, assigned like any value
  return s:upper() .. "!"
end
print("shout:", shout("hello"))

-- Because it's just a value, you can make another name for the SAME function:
local yell = shout
print("yell is shout?", yell == shout) -- true — same function value
print("yell:", yell("hey"))

-- ...and you can overwrite it. The old function isn't "renamed" — the
-- variable simply points at a new value now:
shout = function(s) return s .. "?!" end
print("new shout:", shout("hello"))
print("yell unchanged:", yell("hello")) -- yell still holds the ORIGINAL

-- Functions in tables is how every Lua "module" works. When you write
-- vim.keymap.set(...) in your config, `vim` is a table, `keymap` is a table
-- inside it, and `set` is a key whose value is a function. No magic:
-- (Tables get their own module, 03. All you need today: `{}` creates an
-- empty table, and `t.name = value` / `t.name` store and fetch a field.)
local mymath = {}
mymath.double = function(n) return n * 2 end
function mymath.triple(n) return n * 3 end -- sugar for mymath.triple = function...
print("mymath.double(21):", mymath.double(21))
print("mymath.triple(14):", mymath.triple(14))

------------------------------------------------------------ 5. `local function f` vs `local f = function`
-- Two ways to write the same thing... almost.
--
--   local function f(x) ... end
-- is sugar for
--   local f
--   f = function(x) ... end
--
-- The subtle difference: with `local function`, the name `f` is already in
-- scope INSIDE the body, so the function can call itself. With
-- `local f = function() ... end`, the name only exists after the whole
-- statement — the body can't see it. This matters for recursion, and
-- lesson 06 is built around exactly this gotcha. For now, the rule of
-- thumb: prefer `local function name(...)` for named functions.

local function count_up(from, to)
  for i = from, to do
    io.write(i, " ") -- io.write: like print but no newline / no tabs
  end
  io.write("\n")
end
count_up(1, 5)

-- TRY IT ------------------------------------------------------------
-- 1. Add a third parameter `c` to `describe` and re-run. Which calls now
--    print an extra nil, and why?
-- 2. Write `local function clamp(n, lo, hi)` that returns n limited to the
--    range [lo, hi]. Make lo default to 0 and hi default to 1. Test it.
-- 3. In section 4, add `mymath.halve` two different ways: once with
--    `mymath.halve = function...` and once with `function mymath.halve...`.
--    Confirm both work; delete one.
-- 4. Move the `return "zero"` line in `sign` ABOVE the two ifs and re-run.
--    Explain the output you get before you fix it back.
