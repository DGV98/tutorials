----------------------------------------------------------------------
-- 03_varargs.lua — Variadic functions: ...
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Writing functions that take any number of arguments with ...
--   • select("#", ...) and select(i, ...) to inspect the list
--   • Collecting varargs with {...} — and when that's safe
--   • Forwarding ... to another function (wrappers)
--   • Why nil "holes" in ... are genuinely tricky, and the robust patterns
-- HOW TO RUN
--   luajit 03_varargs.lua              (from this directory)
--   or inside nvim:  :luafile %        (with this file open)
-- PREREQUISITES: 02_multiple_returns.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. ... — the vararg expression
-- Three dots as the last parameter makes a function variadic: it accepts
-- any number of arguments beyond the named ones. Inside the body, the
-- expression `...` stands for all of those extra values, loose, exactly
-- like a multiple-return. Shell analogy: `...` is "$@" — all the
-- arguments — while named parameters are like $1 that you've given a name.
-- print itself is variadic; that's why it takes anything you throw at it.

local function shout_all(...)
  print("got:", ...) -- `...` in last position expands to every argument
end
shout_all("a", "b", "c")
shout_all() -- zero arguments is fine too — ... is just empty

-- Named parameters and ... mix; names bind first, ... takes the rest:
local function tagged(tag, ...)
  print("[" .. tag .. "]", ...)
end
tagged("INFO", "config", "loaded", 42)

-- The adjustment rules from lesson 02 apply to `...` verbatim, because it
-- IS a multi-value expression: last position → expands, elsewhere → one.
local function first_only(...)
  print("first only:", (...)) -- parens truncate ... to its first value
end
first_only("x", "y", "z")

------------------------------------------------------------ 2. Inspecting varargs with select
-- select("#", ...) → the REAL argument count, including nils.
-- select(i, ...)   → arguments from position i onward (take the first
--                    with parens or a single assignment).

local function inspect_args(...)
  local n = select("#", ...)
  print("received " .. n .. " argument(s)")
  for i = 1, n do
    local v = select(i, ...) -- single assignment keeps just the i-th
    print("  arg " .. i .. ":", v)
  end
end
inspect_args("hello", true, nil, 3.14)
-- Note arg 3: nil was COUNTED and visited. Hold that thought for section 5.

------------------------------------------------------------ 3. Collecting varargs: {...}
-- {...} drops all the varargs into a fresh table — by far the most common
-- way to keep them around, loop over them, or pass them somewhere later.

local function sum(...)
  local values = { ... }
  local total = 0
  for i = 1, #values do
    total = total + values[i]
  end
  return total
end
print("sum(1,2,3,4):", sum(1, 2, 3, 4))

-- {...} is perfect when you KNOW no argument is nil (numbers to add,
-- strings to join, paths to check...). The moment nil can appear in the
-- middle, {...} + # becomes a trap — that's section 5.

------------------------------------------------------------ 4. Forwarding varargs
-- A wrapper function receives ... and passes it along untouched. This is
-- the backbone of logging wrappers, timing wrappers, and "call this later"
-- plumbing (which becomes huge in lesson 04/05 for Neovim callbacks).

local function log(...)
  print("LOG:", ...)
end

local function debug_call(fn, ...)
  log("calling with", select("#", ...), "arg(s)")
  return fn(...) -- forward everything, return everything: fully transparent
end

local function add(x, y) return x + y end
print("debug_call result:", debug_call(add, 20, 22))

-- Because `fn(...)` sits in return position (a tail call, see lesson 06)
-- and `...` is in last position, ALL arguments go in and ALL results come
-- out. The wrapper is invisible.
--
-- One rule to remember: `...` only exists directly inside the variadic
-- function itself. A nested function body can't see the outer `...` — if
-- an inner function needs the values, copy them first ({...} or pack) and
-- let the inner function capture the copy (capturing = lesson 04).

------------------------------------------------------------ 5. The nil-hole problem
-- Here's the sharp edge. nil in the MIDDLE of a vararg list is preserved
-- by ... itself (select saw it in section 2). But most ways of CONSUMING
-- varargs lose or mangle it:
--
--   • {...} creates a table with a hole at that position, and the length
--     operator # is UNDEFINED for tables with holes — it may return the
--     index before the hole, after it, or the true count. Whatever it
--     returns today, you must not rely on it.
--   • ipairs (the array-walking loop you'll meet properly in module 03)
--     stops at the first nil, so a loop just ends early.

local function naive_count(...)
  return #{ ... } -- looks reasonable, isn't
end
local function true_count(...)
  return select("#", ...) -- counts what the caller actually passed
end

print("naive_count(1, nil, 3):", naive_count(1, nil, 3), "(don't trust this)")
print("true_count(1, nil, 3): ", true_count(1, nil, 3))

-- Where do mid-list nils even come from? Rarely from literal nil — usually
-- from forwarding the result of something that FAILED, e.g.
--   log(io.open(path))        -- forwards nil, "no such file"
--   forward(t.missing_key, x) -- forwards nil, x
-- Your wrapper then miscounts, or a loop processes half the arguments and
-- silently skips the rest. These bugs are quiet: no error, just missing data.

-- Robust pattern #1: never use # on {...}; carry the count (the hand-made
-- table.pack from lesson 02):
local function pack(...)
  return { n = select("#", ...), ... }
end

local function count_nils(...)
  local args = pack(...)
  local nils = 0
  for i = 1, args.n do -- args.n, NOT #args
    if args[i] == nil then nils = nils + 1 end
  end
  return nils
end
print("count_nils(nil, 1, nil):", count_nils(nil, 1, nil))

-- Robust pattern #2: skip the table entirely; walk with select:
local function join(sep, ...)
  local out = ""
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if i > 1 then out = out .. sep end
    out = out .. tostring(v) -- tostring turns nil into "nil" instead of erroring
  end
  return out
end
print("join:", join(", ", "a", nil, "c"))

-- And to hand a packed list back out as loose values, give unpack the true
-- range (bare unpack guesses the length with # and can stop at the hole):
local unpack = table.unpack or unpack -- version note in lesson 02
local args = pack("x", nil, "z")
print("faithful re-spread:", unpack(args, 1, args.n))

-- Rule of thumb:
--   arguments can't be nil (99% of code) → {...} and relax.
--   arguments might contain nil          → select("#", ...) + pack/args.n.

-- TRY IT ------------------------------------------------------------
-- 1. Write `average(...)` using sum() and select("#", ...). What should it
--    do when called with zero arguments? Make it return nil, "no values"
--    (the convention from lesson 02) instead of dividing by zero.
-- 2. Predict, then run: print(pcall(sum, 1, nil, 3)). On this machine it's
--    `true 1` — no error! #values stopped at the hole, so the loop added
--    only the 1 and silently dropped the 3 (section 5's quiet-bug flavor).
--    On a LuaJIT build where # happens to say 3, the same call would crash
--    adding nil instead. Now rewrite sum's loop to walk with
--    select("#", ...) and re-run: which failure do you get, and why is the
--    loud one better?
-- 3. Write `wrap_twice(fn, ...)` that calls fn(...) two times and returns
--    the SECOND call's results. Test it with a variadic fn.
-- 4. Change join's loop to `for i, v in ipairs({...})` and re-run the
--    "a", nil, "c" call. Where does it stop, and why?
