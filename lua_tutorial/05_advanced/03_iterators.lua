----------------------------------------------------------------------
-- 03_iterators.lua — What the generic for loop really does
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • The 3-part protocol behind `for ... in ...`: iterator function,
--     invariant state, control variable
--   • Stateless iterators — reimplement ipairs from scratch
--   • Closure-based (stateful) iterators — the pattern you'll write most
--   • Why string.gmatch and pairs "just work" in a for loop
-- HOW TO RUN
--   luajit 03_iterators.lua           (from this directory)
--   or inside nvim:  :luafile %       (with this file open)
-- PREREQUISITES: 02_string_patterns.lua, module 02 (closures)
----------------------------------------------------------------------

------------------------------------------------------------ 1. The protocol
-- This loop:
--
--   for a, b in EXPR do ... end
--
-- is pure sugar. Lua evaluates EXPR expecting THREE values:
--
--   local f, s, ctrl = EXPR     -- iterator fn, invariant state, control var
--   while true do
--     local a, b = f(s, ctrl)   -- call the iterator each round
--     if a == nil then break end
--     ctrl = a                  -- first result becomes next control value
--     ...loop body...
--   end
--
-- That's ALL a for-in loop is: repeatedly call f(s, ctrl) until the
-- first result is nil. `s` never changes (that's why it's "invariant");
-- `ctrl` is threaded through automatically.
-- bash analogy: `while read line; do ...; done` — read is f, the file
-- descriptor is s, and the position in the file plays the role of ctrl
-- (except Lua passes position explicitly instead of hiding it in the fd).

-- Proof: drive an iterator BY HAND, no for loop at all.
local t = { "waybar", "hyprpaper", "ghostty" }
local f, s, ctrl = ipairs(t)
print("1a manual:", f(s, 0))    -- 1  waybar
print("1b manual:", f(s, 1))    -- 2  hyprpaper
print("1c manual:", f(s, 2))    -- 3  ghostty
print("1d manual:", f(s, 3))    -- no values at all → reads as nil → a
                                -- for loop would stop here

------------------------------------------------------------ 2. Stateless iterators
-- ipairs' iterator keeps NO state of its own — everything it needs
-- arrives as arguments (the table s, the previous index ctrl). Such
-- iterators are "stateless": one function object can serve any number
-- of simultaneous loops. Let's reimplement ipairs.

local function my_ipairs_iter(tbl, i)
  i = i + 1
  local v = tbl[i]
  if v ~= nil then
    return i, v          -- i becomes the next control variable
  end
  -- fall through: return nothing → nil → loop ends
end

local function my_ipairs(tbl)
  return my_ipairs_iter, tbl, 0   -- fn, invariant state, initial control
end

for i, v in my_ipairs(t) do
  print("2a my_ipairs:", i, v)
end

-- pairs works the same way: pairs(t) returns next, t, nil — and next(t, k)
-- returns the key after k plus its value. Also drivable by hand:
local opts = { rounding = 10, blur = true }
local k1, v1 = next(opts, nil)          -- nil → "give me the first key"
print("2b next:", k1, v1)
print("2c next:", next(opts, k1))       -- the key after k1
-- (Which key comes first is unspecified — hash order. Never rely on it.)

------------------------------------------------------------ 3. Closure-based iterators
-- Stateless is elegant but cramped: all state must fit in (s, ctrl).
-- The everyday alternative: return a CLOSURE that keeps its own state in
-- upvalues, and ignore the s/ctrl machinery entirely. The for loop
-- doesn't care — it just calls whatever function it got.

local function range(from, to, step)
  step = step or 1
  local i = from - step
  return function()          -- this closure IS the iterator
    i = i + step
    if i <= to then return i end
  end
end

for n in range(1, 5) do io.write("3a range: ", n, "  ") end
print()
for n in range(10, 30, 10) do io.write("3b step:  ", n, "  ") end
print()

-- A more useful one: iterate key=value pairs out of a config string.
-- (Patterns from lesson 02 + closures = a tiny parser.)
local function config_pairs(text)
  local pos = 1
  return function()
    -- string.match takes an optional 3rd argument: the index to START
    -- searching from (string.find has the same, lesson 02 §7). The
    -- empty capture () at the pattern's end reports the position just
    -- past the match (lesson 02 §4) — our starting point next call.
    local k, v, nextpos =
      string.match(text, "([%w_]+)%s*=%s*([^\n]+)()", pos)
    if not k then return nil end
    pos = nextpos
    return k, v
  end
end

local cfg = "gaps_in = 3\ngaps_out = 3\nborder_size = 1"
for k, v in config_pairs(cfg) do
  print("3c config:", k, "=", v)
end

-- This is exactly what string.gmatch does for you — it returns a closure
-- that remembers the string and the current position:
for k, v in string.gmatch(cfg, "([%w_]+)%s*=%s*([^\n]+)") do
  print("3d gmatch:", k, "=", v)
end

------------------------------------------------------------ 4. Iterators over iterators
-- Because iterators are just functions, you can wrap them. A filter:

local function filtered(iter_fn, keep)
  return function()
    for v in iter_fn do   -- careful: iter_fn must be a closure iterator
      if keep(v) then return v end
    end
  end
end

local function is_even(n) return n % 2 == 0 end
for n in filtered(range(1, 10), is_even) do
  io.write("4a even: ", n, "  ")
end
print()

-- Neovim ships this idea as a library: vim.iter() (module 06 uses it).
-- Understanding THIS lesson is what makes vim.iter readable.

------------------------------------------------------------ 5. Gotchas worth engraving
-- • The loop stops at the first nil RESULT — so an array with a nil hole
--   ends ipairs early. (pairs still visits everything, in hash order.)
local holey = { "a", nil, "c" }
local count = 0
for _ in ipairs(holey) do count = count + 1 end
print("5a ipairs saw", count, "of 3 (stops at the nil hole)")
-- • Don't ADD keys to a table while pairs() is walking it — Lua may
--   error or skip entries. (Changing the VALUE of an existing key is fine.)
-- • A closure iterator is single-use: it has private state. Call the
--   factory (range(...), gmatch(...)) again for a fresh pass.

------------------------------------------------------------ TRY IT
-- 1. Drive my_ipairs by hand like section 1 does — call the returned
--    f(s, ctrl) yourself three times and print the results.
-- 2. Write chars(s) returning a closure that yields the string one
--    character at a time (string.sub(s, i, i) is your friend).
-- 3. Write reverse_ipairs(t) — a STATELESS version that walks t from
--    #t down to 1. You only get (s, ctrl) to work with; that's enough.
-- 4. Make range() error("step must not be 0", 2) when step == 0 — then
--    prove with pcall that the blamed line is the CALLER's (lesson 01).
