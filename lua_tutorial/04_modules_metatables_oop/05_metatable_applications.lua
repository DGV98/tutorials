----------------------------------------------------------------------
-- 05_metatable_applications.lua — Four real-world metatable patterns
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Default-value tables (never write `t[k] = (t[k] or 0) + 1` again)
--   • Read-only tables: a proxy that errors on write (demoed via pcall)
--   • Memoization: a cache that computes missing entries on first read
--   • A tracking proxy that logs every read AND write — conceptually,
--     this is how vim.opt intercepts `vim.opt.number = true`
-- HOW TO RUN
--   luajit 05_metatable_applications.lua   (from this directory)
--   or inside nvim:  :luafile %            (with this file open)
-- PREREQUISITES: 02_metatables_index.lua, 03_metamethods.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. Default-value tables
-- Counting things in plain Lua needs a nil-guard on every bump:
--   counts[word] = (counts[word] or 0) + 1
-- Give the table a default instead, and missing keys READ as 0:
local function defaulting(default)
  return setmetatable({}, { __index = function() return default end })
end

local counts = defaulting(0)
-- gmatch iterates every match of a pattern ("%a+" = each run of letters);
-- it's string.match's loop-friendly sibling — properly taught in module 05.
for word in ("the quick the lazy the dog the"):gmatch("%a+") do
  counts[word] = counts[word] + 1     -- read falls back to 0; write stores for real
end
print("default-value table:")
print("  the:", counts.the, " dog:", counts.dog, " never-seen:", counts.zebra)
-- Note: the default is only a READ-time answer, never stored. rawget
-- still says the truth: rawget(counts, "zebra") is nil.
-- Variant for nested tables — auto-create inner tables on first touch:
local autotable = setmetatable({}, {
  __index = function(t, k)
    local inner = {}
    rawset(t, k, inner)   -- store it so nested writes have a real home
    return inner
  end,
})
autotable.monitors.count = 5          -- no "attempt to index nil" — inner
autotable.monitors.primary = "DP-1"   -- table sprang into existence
print("  autotable.monitors:", autotable.monitors.count, autotable.monitors.primary)

------------------------------------------------------------ 2. Read-only tables
-- Trap from lesson 03: __newindex only fires for keys the table does
-- NOT have. To catch writes to EXISTING keys too, use a PROXY: an empty
-- front table the user touches, with the real data hidden behind it.
-- Every read misses (proxy is empty) → __index serves it; every write
-- misses → __newindex fires. Total interception.
local function readonly(data)
  return setmetatable({}, {
    __index = data,
    __newindex = function(_, k, _)
      error("attempt to modify read-only table (key: " .. tostring(k) .. ")", 2)
    end,
    __metatable = "readonly",   -- also block getmetatable/setmetatable snooping
  })
end

local config = readonly({ gaps_in = 3, gaps_out = 3, border_size = 1 })
print("\nread-only table:")
print("  reading works:", config.gaps_in, config.border_size)
local ok, err = pcall(function() config.gaps_in = 999 end)
print("  writing fails: ", ok, err)
-- The real table never changed — and callers can't reach it to cheat:
print("  still intact:  ", config.gaps_in)
-- Neovim uses this idea for things like vim.v (try vim.v.count = 5 in
-- nvim: "Key is read-only"). Cost of the proxy: #config and pairs() see
-- an empty table on 5.1 — a real limitation to know about.

------------------------------------------------------------ 3. Memoization cache
-- __index as a function can COMPUTE the answer for a missing key, and
-- rawset can remember it — so the second lookup is a plain table hit.
-- The table becomes a cache that fills itself on demand.
local function memoized(fn)
  return setmetatable({}, {
    __index = function(cache, k)
      print(("    (computing %s...)"):format(tostring(k)))  -- so you SEE the misses
      local v = fn(k)
      rawset(cache, k, v)   -- store; future reads never reach __index
      return v
    end,
  })
end

local slow_square = memoized(function(n) return n * n end)
print("\nmemoization:")
print("  first read of 12: ", slow_square[12])   -- computes
print("  second read of 12:", slow_square[12])   -- cache hit, no "computing" line
print("  first read of 7:  ", slow_square[7])    -- computes
-- This pattern hides inside require() itself (package.loaded IS a memo
-- cache keyed by module name) and in plugins that lazily build
-- highlight groups, LSP client wrappers, etc.

------------------------------------------------------------ 4. A tracking proxy — how vim.opt works, conceptually
-- Combine everything: a proxy that forwards reads and writes to a
-- hidden backing store, logging each access. Nothing is ever stored in
-- the proxy itself, so EVERY access goes through the metamethods.
local function tracked(name, backing)
  local accesses = {}
  local proxy = setmetatable({}, {
    __index = function(_, k)
      accesses[#accesses + 1] = ("read  %s.%s"):format(name, tostring(k))
      return backing[k]                 -- forward the read
    end,
    __newindex = function(_, k, v)
      accesses[#accesses + 1] = ("write %s.%s = %s"):format(name, tostring(k), tostring(v))
      backing[k] = v                    -- forward the write (could validate here!)
    end,
  })
  return proxy, accesses
end

local opt, log = tracked("opt", { number = false, tabstop = 8 })
print("\ntracking proxy:")
opt.number = true                -- intercepted write
opt.tabstop = 2                  -- intercepted write
local _ = opt.number             -- intercepted read
print("  backing value of tabstop:", opt.tabstop)
print("  access log:")
for _, line in ipairs(log) do print("    " .. line) end

-- Now squint at vim.opt: `vim.opt.number = true` is NOT storing `true`
-- in a table. vim.opt is a (nearly) empty proxy; its __newindex handler
-- receives ("number", true), validates the option exists, coerces the
-- value, and calls Neovim's C-level option setter. Reading
-- vim.opt.tabstop goes through __index, which asks Neovim and wraps the
-- answer in an Option object (that's why you need :get() on it —
-- `vim.opt.tabstop:get()` — while plain vim.o.tabstop, a simpler proxy,
-- hands you the raw value). vim.bo/vim.wo are the same trick scoped to
-- a buffer/window. When a plugin README says "just set vim.opt.foo",
-- you now know real code runs the moment that `=` executes.

------------------------------------------------------------ 5. Choosing your weapon
-- One-screen recap:
--   defaults for missing keys        → __index (table or function)
--   compute-once caches              → __index function + rawset
--   forbid/validate/log writes       → __newindex (+ empty-proxy trick
--                                      when existing keys must be caught)
--   value types (==, +, tostring)    → __eq, arithmetic, __tostring
--   classes                          → Class.__index = Class (lesson 04)
-- If a Lua library feels magical, it is one of these five, guaranteed.

----------------------------------------------------------------------
-- TRY IT
-- 1. Make `tracked` validate: writing a key that didn't already exist
--    in `backing` should error("unknown option: " .. k, 2). Test both
--    the good and the bad path with pcall — like real vim.opt, which
--    errors on vim.opt.tpyo.
-- 2. Change memoized() to also count cache hits vs misses and expose
--    the counts (hint: keep the counters in upvalues, add a report
--    function — you can't store them in the cache table itself... or
--    can you, with rawset and a weird key?).
-- 3. Write deep_readonly(data) that wraps nested tables too: when
--    __index would return a table, return deep_readonly(that table).
--    Verify config.sub.x = 1 fails through two levels.
-- 4. In nvim, run :lua vim.opt.number = true then
--    :lua print(vim.opt.number:get()) and :lua print(vim.o.number) —
--    map each line onto section 4's proxy.
----------------------------------------------------------------------
