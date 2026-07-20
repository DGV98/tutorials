----------------------------------------------------------------------
-- 01_arrays.lua — Tables as arrays (sequences)
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Lua has ONE data structure: the table. Used one way, it's an array.
--   • Indexing starts at 1. Not 0. This is drilled until it hurts.
--   • The length operator #, and looping with ipairs.
--   • table.insert / table.remove / table.concat / table.sort
--     (sort with a custom comparator).
-- HOW TO RUN
--   luajit 01_arrays.lua             (from this directory)
--   or inside nvim:  :luafile %      (with this file open)
-- PREREQUISITES: modules 01_basics and 02_functions (values, loops, functions)
----------------------------------------------------------------------

------------------------------------------------------------ 1. One structure to rule them all
-- Bash gives you arrays AND associative arrays. Python gives you lists,
-- dicts, sets, tuples. Lua gives you exactly one thing: the table.
-- A table is a bag of key→value pairs, and by convention, a table whose
-- keys are 1, 2, 3, ... n is called a SEQUENCE (or array). That's this
-- lesson. Your entire Neovim config — every plugin spec, every option
-- block — is tables all the way down.

-- The {} constructor. Listing values without keys assigns them to
-- indices 1, 2, 3, ... — exactly like the exec-once lines in your
-- hyprland.conf, in order:
local exec_once = {
  "dbus-update-activation-environment --all",
  "waybar",
  "hyprpaper",
  "sh -c 'sleep 1 && ghostty -e nvim ~/todos.md'",
}
-- (Yes, that trailing comma after the last item is legal and GOOD style
-- in config tables — more on why in 05_gotchas.lua.)

------------------------------------------------------------ 2. Indexing starts at 1 (drill this)
-- Read this three times: THE FIRST ELEMENT IS AT INDEX 1.
-- Lua was designed for describing data (it started life as a config
-- language), so it counts the way humans do: first = 1.
print("index 1 (the FIRST item):", exec_once[1])
print("index 4 (the LAST item): ", exec_once[4])

-- Index 0 is not an error — it's just an unused key, so you get nil.
-- This is the sneaky part: off-by-one bugs don't crash, they silently
-- hand you nil, and the crash happens LATER when you use that nil.
print("index 0 is:", exec_once[0])   --> nil (no error! just... nothing)

-- Drill: if you catch yourself writing t[0], or looping "from 0 to n-1",
-- stop. In Lua it's t[1], and loops run "from 1 to n".

------------------------------------------------------------ 3. The length operator #
-- # gives the length of a sequence. For a clean, hole-free array it's
-- exactly what you expect:
print("#exec_once =", #exec_once)    --> 4

-- The last element is therefore t[#t] — a very common idiom:
print("last item via t[#t]:", exec_once[#exec_once])

-- (If the array has nil "holes" in the middle, # becomes untrustworthy.
-- That trap gets its own section in 05_gotchas.lua. For now: keep your
-- arrays hole-free and # is reliable.)

------------------------------------------------------------ 4. Looping with ipairs
-- ipairs(t) walks indices 1, 2, 3, ... in order, stopping before the
-- first missing index. It hands you BOTH the index and the value:
print("-- exec-once lines, in order --")
for i, cmd in ipairs(exec_once) do
  print(string.format("  exec-once[%d] = %s", i, cmd))
end

-- A numeric for loop over 1..#t does the same job when you need more
-- control (stepping backwards, skipping, etc.):
for i = #exec_once, 1, -1 do
  print("reversed:", i, exec_once[i])
end

------------------------------------------------------------ 5. table.insert and table.remove
-- Arrays grow and shrink with table.insert / table.remove.
-- Think of your lazy.nvim plugin list: one name per entry.
local plugins = {
  "nvim-telescope/telescope.nvim",
  "nvim-treesitter/nvim-treesitter",
  "nvim-lualine/lualine.nvim",
}

-- insert(t, value) appends to the END:
table.insert(plugins, "folke/tokyonight.nvim")
print("after append, #plugins =", #plugins)
print("appended:", plugins[#plugins])

-- insert(t, position, value) inserts AT that position and shifts the
-- rest right. Position first, value second — easy to get backwards
-- (that trap is also in 05_gotchas.lua):
table.insert(plugins, 1, "folke/lazy.nvim")   -- bootstrap goes first
print("new first plugin:", plugins[1])

-- remove(t) pops the LAST element and returns it:
local popped = table.remove(plugins)
print("popped from the end:", popped)

-- remove(t, position) removes at that position, shifts the rest left,
-- and returns what it removed:
local removed = table.remove(plugins, 1)
print("removed from the front:", removed)

------------------------------------------------------------ 6. table.concat — array → string
-- table.concat(t, separator) glues a sequence of strings together.
-- It's how you'd render a Lua table back into a config-file line —
-- exactly what module 08 does to your hyprland.conf.
local monitor = { "DP-4", "1920x1080@180", "1920x0", "1" }
print("monitor = " .. table.concat(monitor, ", "))
--> monitor = DP-4, 1920x1080@180, 1920x0, 1   (a real hyprland line!)

-- With "\n" as the separator you get one item per line:
print(table.concat(plugins, "\n"))

------------------------------------------------------------ 7. table.sort — with a comparator
-- table.sort(t) sorts IN PLACE (it mutates the table), ascending by
-- default:
local gaps = { 10, 3, 7, 1 }
table.sort(gaps)
print("sorted numbers:", table.concat(gaps, ", "))

-- The real power: pass a comparator function. It receives two elements
-- and must return true when the FIRST should come BEFORE the second.
-- Sort your monitors by refresh rate, fastest first:
local refresh_rates = { 60, 180, 60, 180 }  -- eDP-1, DP-4, DP-1, DP-3
table.sort(refresh_rates, function(a, b)
  return a > b            -- "a before b when a is bigger" = descending
end)
print("refresh rates, fastest first:", table.concat(refresh_rates, ", "))

-- Comparators can look inside strings, too — sort plugin names by the
-- part after the "/" so telescope.nvim sorts under "t", not under "n":
table.sort(plugins, function(a, b)
  local name_a = a:match("[^/]+$")   -- everything after the last /
  local name_b = b:match("[^/]+$")
  return name_a < name_b
end)
print("plugins sorted by repo name:")
for i, p in ipairs(plugins) do
  print("  " .. i .. ". " .. p)
end

-- One rule: the comparator must be consistent (a strict "less than").
-- Returning true for BOTH (a,b) and (b,a) can crash sort with
-- "invalid order function for sorting".

------------------------------------------------------------ TRY IT
-- 1. Add a fifth entry to exec_once (maybe "hyprlock"?) with
--    table.insert, then re-run and watch #exec_once change.
-- 2. Change exec_once[1] in section 2 to exec_once[0] and re-run.
--    Notice: no error, just nil. Feel the danger. Change it back.
-- 3. Sort `plugins` by string LENGTH (shortest first) by editing the
--    comparator in section 7.
-- 4. Use table.concat to print exec_once as real config lines, i.e.
--    each prefixed with "exec-once = ". (Hint: build a NEW table of
--    prefixed strings with a loop + table.insert, then concat.)
