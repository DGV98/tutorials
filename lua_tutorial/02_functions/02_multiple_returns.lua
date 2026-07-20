----------------------------------------------------------------------
-- 02_multiple_returns.lua — Multiple return values
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Returning several values from one function
--   • "Adjustment": how the CALL SITE decides how many values survive
--   • Parentheses truncate to one value (a classic trap)
--   • select() for counting and slicing result lists
--   • Capturing results in a table, and unpack() to go back
--   • Lua version note: unpack vs table.unpack (verified on this machine)
-- HOW TO RUN
--   luajit 02_multiple_returns.lua     (from this directory)
--   or inside nvim:  :luafile %        (with this file open)
-- PREREQUISITES: 01_function_basics.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. Returning several values
-- A Lua function can return any number of values — just list them after
-- `return`. No tuples, no arrays, no boxing: the values travel "loose".
-- This is how half the standard library works: string.find returns start
-- AND end positions, pcall returns ok AND the error/result, ipairs-style
-- iterators return index AND value.

local function minmax(a, b, c)
  local lo = math.min(a, b, c)
  local hi = math.max(a, b, c)
  return lo, hi -- two values, comma-separated
end

-- Multiple assignment catches them positionally:
local lo, hi = minmax(3, 9, 5)
print("min:", lo, "max:", hi)

-- Too many variables? Extras get nil. Too few? Extras are dropped.
-- Exactly the same rules as function parameters in lesson 01:
local a, b, c = minmax(3, 9, 5)
print("a,b,c:", a, b, c)      -- 3  9  nil
local only_min = minmax(3, 9, 5)
print("only_min:", only_min)  -- 3   (the 9 was dropped)

-- The most important multi-return in the language: pcall. It calls a
-- function in "protected mode" and returns ok(boolean) + error-or-results.
-- This is how we demonstrate errors in this course without crashing:
local ok, err = pcall(function() error("boom") end)
print("pcall gave:", ok, err)

------------------------------------------------------------ 2. Adjustment: context decides how many values survive
-- Here's the rule that explains everything in this lesson. A call that
-- returns multiple values is "adjusted" depending on WHERE it appears:
--
--   • As the LAST thing in an expression list → ALL its values are used.
--   • Anywhere else (middle of a list, operand of .. or +, etc.)
--     → truncated to exactly ONE value.

local function two() return "first", "second" end

print(two())            -- last in print's arg list → both values
print(two(), "tail")    -- NOT last → truncated:  first   tail
print("head", two())    -- last again → head  first  second

-- Same rule inside a table constructor. `{ ... }` builds a table, Lua's
-- one container type — module 03 covers them fully; today you just need:
-- t[1] reads the first slot, and #t counts the slots.
local t1 = { two() }          -- at the end → both land in the table
local t2 = { two(), "x" }     -- not at the end → only "first" survives
print("#t1:", #t1, "| #t2:", #t2, "=", t2[1], t2[2])

-- Same rule when passing along to another function:
local function count_args(...) return select("#", ...) end
print("count_args(two()):", count_args(two()))        -- 2
print("count_args(two(), 0):", count_args(two(), 0))  -- 2: (first, 0)

-- TRAP: wrapping a call in parentheses adjusts it to ONE value.
-- `(f())` is an expression, and an expression is a single value.
print("parens truncate:", (two())) -- only "first"
-- You'll see this used ON PURPOSE: in lesson 01, first_line returned
-- `(s:match(...))` — the parens deliberately discard any extra values
-- match might produce. Handy idiom, nasty surprise when accidental.

------------------------------------------------------------ 3. select(): counting and slicing value lists
-- select is a tiny builtin with two jobs:
--   select("#", ...)  → how many values were passed (counts nils correctly!)
--   select(n, ...)    → every value from position n onward

print("how many:", select("#", two()))        -- 2
print("from 2nd on:", select(2, "a", "b", "c")) -- b  c

-- Because select counts actual arguments, it can see a trailing nil that
-- almost nothing else can:
print("with nil, select sees:", select("#", 1, nil, 3), "values")
-- We'll lean on this hard in lesson 03 (varargs).

------------------------------------------------------------ 4. Capturing results in a table
-- Sometimes you need results as a "thing" you can store or iterate. Wrap
-- the call in a table constructor (remember: works fully only in the LAST
-- position):
local results = { minmax(8, 1, 5) }
print("results[1]:", results[1], "results[2]:", results[2])

-- Careful: if the function can return nils, {f()} has holes and #results
-- becomes unreliable (# is undefined on tables with holes). The robust
-- 5.1 pattern stores the count alongside — this is exactly what Lua 5.2's
-- table.pack does, built by hand:
local function pack(...)
  return { n = select("#", ...), ... }
end
local packed = pack("x", nil, "z")
print("packed.n:", packed.n, "| #packed would lie:", #packed)

------------------------------------------------------------ 5. unpack: from table back to loose values
-- unpack is the inverse of {...}: it explodes a table (an array-part
-- sequence) back into multiple values.

local unpack = table.unpack or unpack -- see version note below
local args = { 2, 10 }
print("math.max of unpacked:", math.max(unpack(args)))

local function stats() return 1, 2, 3 end
local saved = { stats() }
print("re-spread:", unpack(saved))

-- LUA VERSION NOTE — unpack vs table.unpack -------------------------
-- Lua 5.1 has a GLOBAL `unpack`. Lua 5.2+ moved it to `table.unpack`.
-- Verified empirically on this machine (2026-07):
--   • `luajit` CLI:          unpack ✓    table.unpack ✗ (nil)
--   • `nvim --clean -l`:     unpack ✓    table.unpack ✗ (nil)
-- So on YOUR system, both runners are pure 5.1 here: only the global
-- exists. (LuaJIT *can* be compiled with 5.2 compat, which adds
-- table.unpack — some distros/builds do, so code found online may use
-- it.) The portable one-liner you'll see in plugins, used above:
--
--   local unpack = table.unpack or unpack
--
-- works everywhere: it prefers table.unpack when present and falls back
-- to the 5.1 global. Same story for table.pack: it doesn't exist here,
-- which is why we built pack() by hand in section 4.

-- unpack with explicit range (useful with the pack() pattern, since
-- packed.n is the true count even with nil holes):
print("unpack range:", unpack({ "a", "b", "c", "d" }, 2, 3)) -- b  c
print("packed round-trip:", unpack(packed, 1, packed.n))     -- x  nil  z

------------------------------------------------------------ 6. Multiple returns in the wild
-- string.find returns TWO numbers (start and finish). If you only bind
-- one, you silently get just the start — fine if that's what you wanted,
-- confusing if you forgot:
local s, e = string.find("hello world", "world")
print("find:", s, e)

-- The "nil, message" convention: Lua libraries signal soft failure by
-- returning nil AND a reason. io.open is the classic (like checking $?
-- and stderr in shell, but in one step):
local f, msg = io.open("/no/such/file")
print("io.open:", f, "|", msg)
-- That's why you'll write:  local f = assert(io.open(path))  — assert
-- passes values through on success and turns nil+msg into a real error.

-- TRY IT ------------------------------------------------------------
-- 1. Write `divmod(a, b)` returning the quotient (math.floor(a/b)) and the
--    remainder. Capture both, then call it inside print() in the middle
--    position and watch the remainder vanish.
-- 2. Predict the output of  print((minmax(3, 9, 5)))  — inner parens! —
--    then add the line and check yourself.
-- 3. Change `pack("x", nil, "z")` to end with TWO nils. What does packed.n
--    say now? What does #packed say? Which one do you trust?
-- 4. Use select(2, minmax(3, 9, 5)) to grab just the max without a
--    throwaway variable.
