----------------------------------------------------------------------
-- 02_metatables_index.lua — Metatables and __index: the fallback machinery
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • setmetatable / getmetatable — attaching behavior to a table
--   • __index as a TABLE: "if the key is missing, look over there"
--   • __index as a FUNCTION: compute an answer for missing keys
--   • Fallback chains: metatables on metatables
--   • rawget/rawset — reading and writing WITHOUT triggering metamethods
--   • Why this is the machinery behind vim.opt, vim.bo, and plugin classes
-- HOW TO RUN
--   luajit 02_metatables_index.lua   (from this directory)
--   or inside nvim:  :luafile %      (with this file open)
-- PREREQUISITES: 01_modules.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. What a metatable is
-- Normally, reading a key that a table doesn't have gives nil. End of
-- story. A METATABLE lets you change that story: it's a second, ordinary
-- table whose specially-named fields ("__index", "__newindex", "__add",
-- ...) act as event handlers. Lua consults it when the default behavior
-- would otherwise kick in. Think of it like shell option handling: the
-- table is your command, the metatable is the trap handler that fires
-- on events the command didn't handle itself.
local plain = {}
print("missing key on a plain table:", plain.anything)   -- nil, no drama

local mt = {}                       -- metatables are just tables
local t = setmetatable({}, mt)      -- attach; setmetatable returns the table
print("getmetatable(t) == mt:", getmetatable(t) == mt)
-- An empty metatable changes nothing yet — behavior comes from the
-- __ fields we now add.

------------------------------------------------------------ 2. __index as a table
-- The single most important metamethod. When you read t[k] and t has no
-- k, Lua checks t's metatable for __index:
--   • if __index is a TABLE, Lua retries the lookup THERE,
--   • if it's a FUNCTION, Lua calls it (next section).
local defaults = { gaps_in = 3, gaps_out = 3, border_size = 1 }
local overrides = setmetatable({ border_size = 2 }, { __index = defaults })

print("\n__index as table (defaults pattern):")
print("  border_size:", overrides.border_size)  -- 2   : found directly, no fallback
print("  gaps_in:    ", overrides.gaps_in)      -- 3   : missing → fetched from defaults
print("  rounding:   ", overrides.rounding)     -- nil : missing in BOTH

-- Key facts:
--   • Only MISSING keys trigger the fallback. Present keys (even ones
--     set to false!) win. Only nil means "missing".
--   • Nothing is copied. Change defaults and overrides sees it live:
defaults.gaps_in = 10
print("  gaps_in after editing defaults:", overrides.gaps_in)  -- 10
-- This layered-config shape is everywhere: plugin setup() functions do
-- exactly this to merge your opts over their defaults.

------------------------------------------------------------ 3. __index as a function
-- If __index is a function, Lua calls it as f(table, key) and uses the
-- return value. Now missing keys can be COMPUTED — the table becomes an
-- interface, not storage.
local squares = setmetatable({}, {
  __index = function(_, k)
    return k * k
  end,
})
print("\n__index as function:")
print("  squares[9]:", squares[9])     -- computed on the fly: 81
print("  squares[12]:", squares[12])   -- 144; nothing is ever stored

-- THIS is the trick behind vim.bo, vim.wo, vim.env, vim.fn: none of
-- them is a giant pre-filled table. vim.fn.expand exists because
-- vim.fn's __index function receives "expand" and builds a wrapper for
-- the Vimscript function of that name, on demand. vim.opt does the same
-- kind of interception (plus __newindex, next lesson) — reading
-- vim.opt.number runs code that asks Neovim for the option.

------------------------------------------------------------ 4. Fallback chains
-- If the __index table ALSO has a metatable with __index, the search
-- keeps climbing. This chain is exactly how class inheritance will work
-- in 04_oop.lua, so meet it here without the OOP costume:
local base    = { kind = "base",  greet = function() return "hi from base" end }
local middle  = setmetatable({ kind = "middle" }, { __index = base })
local top     = setmetatable({},                  { __index = middle })

print("\nfallback chain (top → middle → base):")
print("  top.kind:  ", top.kind)      -- "middle": first hit wins on the way up
print("  top.greet():", top.greet())  -- found two levels up, in base
-- Lookup order for top.greet: top itself → middle (via __index) →
-- base (via middle's __index). First non-nil answer wins; if the chain
-- ends without a hit you get plain nil.

------------------------------------------------------------ 5. rawget / rawset — bypassing the machinery
-- Sometimes you need the truth: is this key REALLY stored in this
-- table, or is __index answering for it? rawget skips metamethods.
print("\nraw access:")
print("  top.kind:          ", top.kind)             -- "middle" (via fallback)
print("  rawget(top, 'kind'):", rawget(top, "kind")) -- nil: top itself is empty
print("  rawget(squares, 9): ", rawget(squares, 9))  -- nil: squares stores nothing
-- rawset(t, k, v) is the writing twin (matters once __newindex exists —
-- next lesson). You'll meet both inside plugin source when authors need
-- to sidestep their own metamethods.

------------------------------------------------------------ 6. Inspecting and protecting
-- getmetatable returns the metatable — handy for spelunking in plugins:
local squares_mt = getmetatable(squares)
print("\ninspection:")
print("  type of squares' metatable:", type(squares_mt))
print("  __index is a:", type(squares_mt.__index))

-- Authors can hide a metatable by setting __metatable; then getmetatable
-- returns that value instead and setmetatable refuses to replace it:
local locked = setmetatable({}, { __metatable = "not your business" })
print("  getmetatable(locked):", getmetatable(locked))
local ok, err = pcall(setmetatable, locked, {})
print("  replacing it fails:", ok, err)

----------------------------------------------------------------------
-- TRY IT
-- 1. In section 2, set overrides.gaps_in = false and re-run. Which value
--    wins now, and why? (Re-read "only nil means missing".)
-- 2. Build fahrenheit = setmetatable({}, {__index = function(_, c) ... end})
--    so that fahrenheit[100] returns 212 and fahrenheit[0] returns 32.
-- 3. Add a fourth level below `top` in section 4 and confirm a key
--    defined only in `base` is still reachable from it.
-- 4. In nvim, run :lua print(type(getmetatable(vim.fn).__index)) and
--    :lua print(type(getmetatable(vim.bo).__index)) — the machinery from
--    section 3, live in your editor.
----------------------------------------------------------------------
