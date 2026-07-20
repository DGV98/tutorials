----------------------------------------------------------------------
-- 05_scope_and_env.lua — Blocks, _G, and why `local` matters
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Blocks and do...end — carving out scopes on purpose
--   • Globals are just fields of a table called _G
--   • Detecting ACCIDENTAL globals (the classic nvim-config bug)
--   • Why local is faster: registers & upvalues vs a hash lookup
--   • The "localize what you use a lot" idiom you'll see in plugins
-- HOW TO RUN
--   luajit 05_scope_and_env.lua       (from this directory)
--   or inside nvim:  :luafile %       (with this file open)
-- PREREQUISITES: module 02 (closures/upvalues), 04_coroutines.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. Blocks and do...end
-- A local lives from its declaration to the end of its BLOCK: a
-- function body, a loop body, an if-branch... or an explicit do...end.
-- do...end exists purely to create scope — like ( subshell ) in bash,
-- but for variable visibility instead of a new process.

do
  local secret = "only visible in here"
  print("1a inside:", secret)
end
print("1b outside:", secret)   -- nil: `secret` doesn't exist out here
-- (Reading an unknown name isn't an error — it's a global read that
--  finds nothing. THAT is why typos are so sneaky in Lua.)

-- Practical use: keep helper clutter out of a module's namespace.
local grand_total
do
  local a, b = 3, 4                -- scratch work, invisible below
  grand_total = a * a + b * b
end
print("1c computed:", grand_total)

-- Shadowing: an inner local with the same name hides the outer one
-- until the block ends. The outer one is untouched.
local gap = 3
do
  local gap = 10
  print("1d inner gap:", gap)
end
print("1e outer gap:", gap)

------------------------------------------------------------ 2. Globals live in _G
-- There is no "global variable" storage in Lua. There is ONE table,
-- _G, and every non-local name is sugar for a field in it:
--     x = 5        means      _G["x"] = 5
--     print(x)     means      print(_G["x"])

my_global = "hi from _G"           -- naughty on purpose (no `local`)
print("2a same thing:", my_global == _G["my_global"])   -- true
print("2b via _G:", _G.my_global)

-- _G is a normal table. You can iterate it, count it, poke it:
local n = 0
for _ in pairs(_G) do n = n + 1 end
print("2c _G holds", n, "entries (print, pairs, string, ... live here)")

_G.my_global = nil                 -- clean up after ourselves

-- WHY THIS IS A TRAP IN NEOVIM: every plugin, your init.lua, and every
-- lua/me/*.lua file share the SAME _G. Forget `local` on a variable
-- named `config` or `utils`, and you're silently overwriting (or being
-- overwritten by) any plugin that made the same mistake. The bug shows
-- up far from its cause. `local` is not style advice — it's isolation.

------------------------------------------------------------ 3. Catching accidental globals
-- Forgetting `local` (or typo-ing a variable name) creates/reads a
-- global with no warning. But _G is a table — so give it a metatable
-- (module 04!) and __newindex will fire on every CREATION of a new
-- global. Turn that into a loud complaint:

local real_G_mt = getmetatable(_G)   -- remember, to restore later

setmetatable(_G, {
  __newindex = function(t, name, v)
    print(("3! WARNING: global '%s' created (forgot `local`?)"):format(name))
    rawset(t, name, v)   -- still allow it — rawset skips this metamethod
  end,
})

whoops = 42            -- no `local` → tripwire fires        <- watch output
local fine = 43        -- `local` → nothing to intercept, no warning
print("3a whoops:", whoops, " fine:", fine)

_G.whoops = nil
setmetatable(_G, real_G_mt)          -- disarm the tripwire

-- The same trick (plus __index to catch READS of unknown globals) is
-- what strict.lua / lua-users' "strict mode" does. In Neovim you could
-- arm this at the top of init.lua while hunting a bug — just remember
-- some plugins create globals on purpose and will trip it.

------------------------------------------------------------ 4. Why local is FAST (not just clean)
-- How each kind of name is found at runtime:
--   local    → a REGISTER of the function's stack frame. The compiler
--              resolved the name at compile time; access is one indexed
--              slot read. As cheap as it gets.
--   upvalue  → a local captured from an enclosing function (closures,
--              module 02). One small indirection. Still very cheap.
--   global   → a HASH LOOKUP: _G["name"] — hash the string, probe the
--              table... EVERY single time the line runs. In a hot loop,
--              you pay it every iteration.

-- Feel it (rough numbers, LuaJIT is fast either way — the RATIO is
-- the point; run a few times, expect jitter):
local N = 3e6
local t0 = os.clock()
local acc1 = 0
for i = 1, N do
  acc1 = acc1 + math.floor(i / 7)     -- global `math`, then field lookup
end
local t_global = os.clock() - t0

local floor = math.floor              -- localize ONCE, outside the loop
t0 = os.clock()
local acc2 = 0
for i = 1, N do
  acc2 = acc2 + floor(i / 7)          -- local: register access
end
local t_local = os.clock() - t0

print(("4a global lookup loop: %.4fs"):format(t_global))
print(("4b localized loop:     %.4fs"):format(t_local))
print("4c same result:", acc1 == acc2)
-- Honesty note: LuaJIT's JIT often optimizes the global lookup away
-- once a loop gets hot, so the gap here may be small. In the
-- INTERPRETER (and in plain Lua 5.1) the gap is large and consistent.
-- The idiom survives because it is never slower and always clearer:

local format = string.format          -- you'll see these three lines
local insert = table.insert           -- at the top of countless plugins
local match  = string.match
print("4d localized stdlib:", format("gaps_in = %d", 3),
      match("border_size = 1", "%d"))

------------------------------------------------------------ 5. Scope rules worth repeating
-- • `local x = x` — a new local initialized from the OUTER (often
--   global) x. Idiomatic at the top of modules: snapshot the global,
--   then use the fast local. Looks weird exactly once.
local print = print   -- yes, even print can be localized
print("5a local print works")
-- • A local declared in a REPL/`:lua` one-liner dies at the line's end
--   — each :lua command is its own chunk (= its own block). That's why
--   `:lua local x = 1` then `:lua print(x)` prints nil in nvim.
-- • Loop variables (for i, for k,v) are ALREADY local to the loop body.
--   They don't leak, and assigning to them doesn't affect the loop.

------------------------------------------------------------ TRY IT
-- 1. Comment out the `_G.whoops = nil` cleanup in section 3 and add a
--    second `whoops = 1` assignment BEFORE the tripwire is disarmed.
--    Why does the warning fire only for a NEW global, not a re-assign?
--    (Hint: module 04 — __newindex fires only for ABSENT keys.)
-- 2. Extend the section-3 metatable with __index so READING an unknown
--    global also warns — then misspell a variable and watch it get caught.
-- 3. In section 4, raise N to 3e7 and compare runs of
--    `luajit 05_scope_and_env.lua` vs `luajit -joff 05_scope_and_env.lua`
--    (JIT disabled → interpreter only). Now the ratio tells the truth
--    from the comment above.
-- 4. Predict what this prints, then try it in a fresh file:
--    local x = 1; do local x = x + 1; print(x) end; print(x)
