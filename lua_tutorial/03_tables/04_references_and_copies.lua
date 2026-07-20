----------------------------------------------------------------------
-- 04_references_and_copies.lua — Tables are references, not values
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Assigning a table copies a REFERENCE, never the contents.
--   • Aliasing bugs: editing "a copy" that isn't one.
--   • Functions receive table references too — callees can mutate
--     your config behind your back.
--   • Writing a shallow copy by hand, and why it's only skin deep.
--   • Deep copy by recursion.
--   • == on tables compares IDENTITY, never contents.
-- HOW TO RUN
--   luajit 04_references_and_copies.lua   (from this directory)
--   or inside nvim:  :luafile %           (with this file open)
-- PREREQUISITES: 03_nested_tables.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. Assignment copies the reference
-- Numbers, strings, booleans are copied by VALUE:
local a = 3
local b = a
b = 99
print("numbers copy by value:  a =", a, " b =", b)   -- a untouched

-- Tables are different. A table variable holds a REFERENCE — think of
-- it as a symlink, not a file. Assignment copies the symlink:
local general = { gaps_in = 3, gaps_out = 3, border_size = 1 }
local alias = general          -- NOT a copy. Same table, second name.
alias.gaps_in = 20
print("edited via alias, read via original:", general.gaps_in)  --> 20!
-- One table, two names. `ln -s general alias`, then editing through
-- either path touches the same underlying data.

------------------------------------------------------------ 2. The aliasing bug, config-shaped
-- Here's how this bites in a real Neovim config. You want the same
-- base float style for two plugins, so you "reuse" the table:
local float_style = { border = "rounded", winblend = 10 }

local telescope_opts = { layout = float_style }
local lsp_hover_opts = { layout = float_style }   -- same reference!

-- Months later you tweak telescope only... you think:
telescope_opts.layout.winblend = 0

print("telescope winblend:", telescope_opts.layout.winblend)  --> 0, good
print("lsp hover winblend:", lsp_hover_opts.layout.winblend)  --> 0, WAT
-- Both .layout fields point at the ONE float_style table. Changing it
-- "for telescope" changed it everywhere. This class of bug produces
-- the classic "my config changes something I never configured" report.

------------------------------------------------------------ 3. Functions mutate through references too
-- Arguments are passed the same way assignment works: tables arrive as
-- references. A function CAN reach in and change your table:
local function force_no_gaps(section)
  section.gaps_in = 0      -- mutates the caller's table!
  section.gaps_out = 0
end

print("before call, gaps_in =", general.gaps_in)
force_no_gaps(general)
print("after call,  gaps_in =", general.gaps_in)
-- This cuts both ways. It's how plugin setup(opts) functions work at
-- all (they receive and keep your opts table) — and it's why a
-- misbehaving function can trash a table you thought was yours.
-- When you hand a table to code you don't control and want to keep
-- your original pristine: pass a copy. So let's learn to copy.

------------------------------------------------------------ 4. Shallow copy by hand
-- There is no built-in table copy in Lua. (Neovim adds
-- vim.deepcopy() and vim.tbl_extend(); pure Lua makes you write it —
-- which is good, because then you know exactly what it does.)
local function shallow_copy(t)
  local copy = {}
  for key, value in pairs(t) do   -- pairs: every key, array part included
    copy[key] = value
  end
  return copy
end

local defaults = { rounding = 10, active_opacity = 0.75 }
local mine = shallow_copy(defaults)
mine.rounding = 0
print("copy edited:    mine.rounding =", mine.rounding)
print("original safe:  defaults.rounding =", defaults.rounding)  --> still 10

------------------------------------------------------------ 5. Why "shallow" — nested tables are still shared
-- shallow_copy copies the top-level key/value pairs. But when a VALUE
-- is itself a table, what gets copied is (say it with me) the
-- reference. The nested tables are still shared:
local deco_defaults = {
  rounding = 10,
  blur = { enabled = true, size = 3 },   -- nested table
}
local deco_mine = shallow_copy(deco_defaults)
deco_mine.blur.size = 8                  -- reaching THROUGH the shared ref

print("mine blur size:    ", deco_mine.blur.size)      --> 8
print("defaults blur size:", deco_defaults.blur.size)  --> 8. Oops.
print("same blur table?   ", deco_mine.blur == deco_defaults.blur)  --> true

------------------------------------------------------------ 6. Deep copy by recursion
-- To truly detach a nested structure, copy tables all the way down:
-- when a value is a table, recurse instead of assigning the reference.
local function deep_copy(t)
  if type(t) ~= "table" then
    return t                       -- numbers/strings/booleans: as-is
  end
  local copy = {}
  for key, value in pairs(t) do
    copy[key] = deep_copy(value)   -- the recursion is the whole trick
  end
  return copy
end

local deco_independent = deep_copy(deco_defaults)
deco_independent.blur.size = 99
print("independent blur:", deco_independent.blur.size)  --> 99
print("defaults blur:   ", deco_defaults.blur.size)     --> 8 (from §5), untouched
print("same blur table? ", deco_independent.blur == deco_defaults.blur) --> false

-- Caveats worth knowing (fine to ignore until they bite):
--   • A table that contains ITSELF sends this simple version into
--     infinite recursion. Production versions (like Neovim's
--     vim.deepcopy) track already-seen tables to handle cycles.
--   • Keys that are themselves tables are not copied here, and
--     metatables (coming in a later module) aren't either.

------------------------------------------------------------ 7. == compares identity, not contents
-- For tables, == asks "are these the SAME table?" — never "do they
-- hold the same data?":
local m1 = { name = "DP-4", mode = "1920x1080@180" }
local m2 = { name = "DP-4", mode = "1920x1080@180" }   -- identical contents
local m3 = m1                                          -- same table

print("same contents, == ?", m1 == m2)   --> false!
print("same table,    == ?", m1 == m3)   --> true

-- Want content equality? Write it (or use vim.deep_equal in Neovim):
local function shallow_equal(x, y)
  for k, v in pairs(x) do
    if y[k] ~= v then return false end   -- x has something y doesn't match
  end
  for k in pairs(y) do
    if x[k] == nil then return false end -- y has a key x lacks
  end
  return true
end
print("shallow_equal(m1, m2):", shallow_equal(m1, m2))  --> true

-- Identity-== is also USEFUL: it's how you check "is this the exact
-- sentinel table I stashed earlier?" — plugins use unique empty tables
-- as unforgeable markers precisely because == is identity.

------------------------------------------------------------ TRY IT
-- 1. Fix section 2 properly: give lsp_hover_opts its own deep_copy of
--    float_style (you'll have to move it below section 6, or move the
--    deep_copy definition up), and confirm the two winblends diverge.
-- 2. Write force_no_gaps_pure(section) that returns a MODIFIED COPY
--    and leaves the argument untouched. Prove it with prints.
-- 3. Predict, then verify: after `local x = {}; local y = {}`,
--    what does x == y print? And after `y = x`?
-- 4. Upgrade shallow_equal into deep_equal by recursing when both
--    values are tables (mirror the deep_copy trick). Test it on
--    deco_defaults vs deep_copy(deco_defaults).
