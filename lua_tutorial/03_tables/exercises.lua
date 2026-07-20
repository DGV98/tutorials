----------------------------------------------------------------------
-- exercises.lua — Module 03: Tables
----------------------------------------------------------------------
-- HOW TO WORK
--   Fill in each TODO, then run:   luajit exercises.lua
--   The file runs clean as-is; your job is to make the printed
--   output match the "want:" notes. Solutions in solutions.lua —
--   but wrestle first. Tables ARE Neovim config; this is the module
--   to over-practice.
-- PREREQUISITES: lessons 01–06 of this module
----------------------------------------------------------------------

------------------------------------------------------------ EXERCISE 1: numbered lines (warm-up)
-- Print each exec-once command as "N) command" using ipairs.
-- want:
--   1) dbus-update-activation-environment --all
--   2) waybar
--   3) hyprpaper
--   4) sh -c 'sleep 1 && ghostty -e nvim ~/todos.md'
local exec_once = {
  "dbus-update-activation-environment --all",
  "waybar",
  "hyprpaper",
  "sh -c 'sleep 1 && ghostty -e nvim ~/todos.md'",
}
print("== exercise 1 ==")
-- TODO: your ipairs loop here


------------------------------------------------------------ EXERCISE 2: plugin list surgery
-- Start from this list and, using table functions only (no rewriting
-- the constructor):
--   a) insert "folke/lazy.nvim" at position 1
--   b) find the index of "pwntester/octo.nvim" with a loop, then
--      table.remove it (do NOT hardcode the index)
--   c) sort the list by the part AFTER the "/" (hint: s:match("[^/]+$"))
--   d) print the result as one line, separated by ", "
local plugins = {
  "nvim-telescope/telescope.nvim",
  "pwntester/octo.nvim",
  "nvim-lualine/lualine.nvim",
  "folke/tokyonight.nvim",
}
print("== exercise 2 ==")
-- TODO: a) insert at position 1

-- TODO: b) find index of octo, then remove it

-- TODO: c) table.sort with a comparator on the repo name

-- TODO: d) print(table.concat(...))


------------------------------------------------------------ EXERCISE 3: deterministic dictionary dump
-- pairs() order is undefined — bad for config files you want to diff.
-- Print the general section as "key = value" lines in ALPHABETICAL
-- key order. (Collect keys, sort them, then loop the sorted keys.)
-- want:
--   border_size = 1
--   gaps_in = 3
--   gaps_out = 3
--   layout = dwindle
--   resize_on_border = true
local general = {
  gaps_in = 3,
  gaps_out = 3,
  border_size = 1,
  resize_on_border = true,
  layout = "dwindle",
}
print("== exercise 3 ==")
-- TODO: collect keys into a list

-- TODO: sort the list

-- TODO: loop the sorted keys, print "key = value" (tostring the value)


------------------------------------------------------------ EXERCISE 4: safe deep reads
-- Using and-chains (NOT pcall), read these from `spec` without ever
-- crashing, falling back to the given default with `or`:
--   a) spec.opts.defaults.layout_strategy      (default "horizontal")
--   b) spec.opts.defaults.winblend             (default 0)
--   c) spec.opts.pickers.find_files.hidden     (default false — careful,
--      what goes wrong if the real value were false and you used `or`?
--      Leave a one-line comment with your answer.)
local spec = {
  "nvim-telescope/telescope.nvim",
  opts = {
    defaults = { layout_strategy = "flex" },
    -- note: no pickers table at all
  },
}
print("== exercise 4 ==")
-- TODO: a)

-- TODO: b)

-- TODO: c)  (+ the comment)


------------------------------------------------------------ EXERCISE 5: deep_copy, proven
-- Write deep_copy(t) (recursive — lesson 04 has the skeleton in your
-- head already). Then PROVE all three properties with prints:
--   a) mutating copy.decoration.blur.size does not change the original
--   b) copy ~= original            (identity differs)
--   c) copy.decoration.blur ~= original.decoration.blur
local hypr = {
  decoration = {
    rounding = 10,
    blur = { enabled = true, size = 3 },
  },
}
print("== exercise 5 ==")
-- TODO: define deep_copy(t)

-- TODO: make the copy, mutate copy.decoration.blur.size = 99

-- TODO: three prints proving a), b), c)


------------------------------------------------------------ EXERCISE 6: dedupe, order preserved
-- These keybind lhs strings have duplicates (a real hazard when you
-- merge keymap tables from two files). Build `deduped`: same order of
-- FIRST appearance, no repeats. Use a set (t[key] = true) to remember
-- what you've seen — no nested loops allowed.
-- want: <leader>ff, <leader>fg, <leader>e, <leader>gd
local lhs_list = {
  "<leader>ff", "<leader>fg", "<leader>ff", "<leader>e",
  "<leader>fg", "<leader>gd", "<leader>e",
}
print("== exercise 6 ==")
-- TODO: build `deduped` using one loop + a `seen` set

-- TODO: print(table.concat(deduped, ", "))


------------------------------------------------------------ EXERCISE 7: setup(), for real
-- Write my_plugin.setup(opts) the way real plugins do:
--   • opts = opts or {}
--   • deep-merge opts over the defaults below (write tbl_deep_extend
--     yourself — lesson 06 — or reuse your deep_copy insight)
--   • store the result in `config` and return it
-- Then run the three calls at the bottom and make the prints match:
--   setup()                                  → border=rounded width=40
--   setup({ window = { width = 80 } })       → border=rounded width=80
--     (the nested default `border` must SURVIVE — that's the deep part)
--   setup({ greeting = "yo" })               → greeting=yo
local my_plugin = {}
local plugin_defaults = {
  greeting = "hello",
  window = { border = "rounded", width = 40 },
}
print("== exercise 7 ==")
-- TODO: local function tbl_deep_extend(base, override) ... end

-- TODO: function my_plugin.setup(opts) ... end

-- Uncomment these once setup() exists:
-- local c1 = my_plugin.setup()
-- print("call 1:", c1.window.border, c1.window.width)
-- local c2 = my_plugin.setup({ window = { width = 80 } })
-- print("call 2:", c2.window.border, c2.window.width)
-- local c3 = my_plugin.setup({ greeting = "yo" })
-- print("call 3:", c3.greeting)


------------------------------------------------------------ EXERCISE 8: the sting — render a config tree
-- Write render(tbl, indent) that turns a nested table into
-- hyprland-style text, DETERMINISTICALLY:
--   • scalar entries print as  "key = value"  (alphabetical by key)
--   • table entries print AFTER the scalars (alphabetical too), as
--         key {
--             ...recursively rendered, indented 4 more spaces...
--         }
--   • indent is a string of spaces to prefix every line with
-- Build the output as a list of lines (table.insert) and return
-- table.concat(lines, "\n") — do NOT print inside render.
-- want (exactly):
--   rounding = 10
--   blur {
--       enabled = true
--       passes = 1
--   }
--   shadow {
--       range = 4
--   }
-- Hints: two passes over pairs (one collecting scalar keys, one
-- collecting table keys), sort both; type(v) == "table" decides;
-- recursion returns MULTI-line strings — think about how to indent
-- them (easiest: pass indent .. "    " down and let recursion prefix).
local decoration = {
  rounding = 10,
  shadow = { range = 4 },
  blur = { enabled = true, passes = 1 },
}
print("== exercise 8 ==")
-- TODO: define render(tbl, indent)

-- Uncomment once render exists:
-- print(render(decoration, ""))

print("\nexercises.lua ran to the end — now go fill in the TODOs.")
