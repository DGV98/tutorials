----------------------------------------------------------------------
-- 03_metamethods.lua — The rest of the metamethods, on a small Vector type
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • __newindex: intercepting WRITES (the other half of vim.opt's trick)
--   • __call: tables you can call like functions (require("lazy").setup, etc.)
--   • __tostring: controlling what print() shows
--   • __eq: making == compare by value instead of identity
--   • Arithmetic metamethods (__add, __sub, __mul, __unm) on a Vector
--   • Lua version note: __len and # on tables
-- HOW TO RUN
--   luajit 03_metamethods.lua        (from this directory)
--   or inside nvim:  :luafile %      (with this file open)
-- PREREQUISITES: 02_metatables_index.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. __newindex — intercepting writes
-- __index fires on reads of missing keys; __newindex fires on WRITES to
-- missing keys. Same rule: only keys the table does not already have.
-- With it you can validate, log, or redirect assignments.
local log = {}
local watched = setmetatable({}, {
  __newindex = function(t, k, v)
    log[#log + 1] = ("set %s = %s"):format(tostring(k), tostring(v))
    rawset(t, k, v)   -- rawset: store WITHOUT re-triggering __newindex
  end,
})
watched.rounding = 10
watched.blur = true
watched.rounding = 12   -- NOT logged: 'rounding' now exists, so no event fires
print("__newindex log:")
for _, line in ipairs(log) do print("  " .. line) end
print("  values:", watched.rounding, watched.blur)
-- Inside the handler you MUST use rawset (or write to a different
-- table). A plain t[k] = v would re-fire __newindex: the key is still
-- missing when the assignment retries, so it recurses until LuaJIT
-- stops it with "stack overflow". (Verified: swap the rawset above for
-- t[k] = v and the FIRST write blows up.) Habit: rawset in handlers.
-- This is how `vim.opt.number = true` can DO something instead of just
-- storing `true` in a table: the assignment is intercepted and turned
-- into a call into Neovim's option code. Full pattern in lesson 05.

------------------------------------------------------------ 2. __call — callable tables
-- If a table's metatable has __call, then t(args) works: Lua invokes
-- __call(t, args...). This lets a module be both a bag of functions AND
-- itself callable — you've used this shape: require("lualine").setup{...}
-- is a plain function call, but some libraries let you do
-- require("thing")(opts) directly. Now you know what powers it.
local counter = setmetatable({ count = 0 }, {
  __call = function(self, step)
    self.count = self.count + (step or 1)
    return self.count
  end,
})
print("\n__call:")
print("  counter():  ", counter())      -- 1
print("  counter(10):", counter(10))    -- 11
print("  it's still a table:", counter.count)

------------------------------------------------------------ 3. A Vector type
-- One small type, five metamethods. This is the standard way to build a
-- value type in Lua; every plugin "Class" is a variation on it.
local Vector = {}
Vector.__index = Vector   -- explained fully in 04_oop.lua; for now:
                          -- "instances look in Vector for methods"

local function vec(x, y)
  return setmetatable({ x = x, y = y }, Vector)
end

-- __tostring: what tostring()/print() produce. Without it you get the
-- useless "table: 0x7f...". With it, debugging output becomes readable —
-- this is why vim.inspect exists for big tables, and why nice plugin
-- objects print nicely.
function Vector.__tostring(v)
  return ("(%g, %g)"):format(v.x, v.y)
end

-- Arithmetic metamethods: fire when an operand has one in its metatable.
-- Each receives BOTH operands.
function Vector.__add(a, b) return vec(a.x + b.x, a.y + b.y) end
function Vector.__sub(a, b) return vec(a.x - b.x, a.y - b.y) end
function Vector.__unm(a)    return vec(-a.x, -a.y) end          -- unary minus
function Vector.__mul(a, b)
  -- Support both vec * 2 and 2 * vec: Lua tries the LEFT operand's
  -- metatable first, then the right's — so a may be the number.
  if type(a) == "number" then a, b = b, a end
  assert(type(b) == "number", "Vector * Vector isn't defined; use a scalar")
  return vec(a.x * b, a.y * b)
end

-- __eq: makes == compare by value. Lua 5.1 note: __eq is only consulted
-- when both operands are tables that share the same __eq metamethod —
-- comparing a Vector to a plain table or a number just returns false,
-- your handler never runs. (5.3+ is more permissive; LuaJIT is 5.1.)
function Vector.__eq(a, b)
  return a.x == b.x and a.y == b.y
end

-- Ordinary methods live on Vector too, reached via __index:
function Vector.length(v)
  return math.sqrt(v.x * v.x + v.y * v.y)
end

------------------------------------------------------------ 4. The Vector in action
local a, b = vec(3, 4), vec(1, 2)
print("\nVector demo:")
print("  a:        ", tostring(a))          -- __tostring
print("  a + b:    ", tostring(a + b))      -- __add
print("  a - b:    ", tostring(a - b))      -- __sub
print("  a * 2:    ", tostring(a * 2))      -- __mul
print("  2 * a:    ", tostring(2 * a))      -- __mul, operands swapped
print("  -a:       ", tostring(-a))         -- __unm
print("  a length: ", a:length())           -- method via __index (that colon: 04_oop.lua)
print("  a == vec(3,4):", a == vec(3, 4))   -- __eq: true, different objects, same value
print("  a == b:       ", a == b)           -- false

-- print(a) uses __tostring directly, same as tostring(a):
print("  print(a) itself:", a)

-- Concatenating a table into a string still fails unless you define
-- __concat — a good excuse to watch an error safely through pcall:
local ok, err = pcall(function() return "vector: " .. a end)
print("  '..' without __concat:", ok, err)

------------------------------------------------------------ 5. Lua version note: __len
-- In Lua 5.1, the # operator IGNORES __len on tables:
local sized = setmetatable({}, { __len = function() return 99 end })
print("\n__len on tables under LuaJIT (5.1):", #sized)   -- 0, handler never runs
-- Lua 5.2+ honors __len for tables. LuaJIT can be compiled with
-- "5.2-compat" extensions that enable it (plus table.unpack and more),
-- and many distros build Neovim that way — but VERIFIED ON YOUR ARCH
-- SETUP: both CLI luajit AND nvim's embedded LuaJIT lack the compat
-- build, so #sized is 0 and table.unpack is nil in both. Check yours:
--   nvim --clean -l 03_metamethods.lua      (compare this line)
--   luajit -e 'print(type(table.unpack))'   → nil here; use unpack()
-- Why care: plugin code written on a compat build (or copied from a
-- Lua 5.4 tutorial) may use table.unpack / rely on __len and then break
-- on your machine. Suspect this whenever an error says
-- "attempt to call field 'unpack' (a nil value)".

----------------------------------------------------------------------
-- TRY IT
-- 1. Add Vector.__div so a / 2 halves both components, and __concat so
--    "pos: " .. a works (return "pos: " .. tostring(a) after checking
--    which operand is the vector).
-- 2. Make counter (section 2) also log the time of each call using
--    os.time() into a self.history table.
-- 3. Predict, then verify: what does vec(1,2) == {x=1, y=2} print, and
--    why doesn't your __eq run? (Re-read the 5.1 note in section 3.)
-- 4. Run this file with `nvim --clean -l 03_metamethods.lua` and compare
--    the __len line with the CLI luajit output. (On this Arch setup
--    they should agree — knowing HOW to check is the skill.)
----------------------------------------------------------------------
