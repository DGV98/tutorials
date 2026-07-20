----------------------------------------------------------------------
-- 03_nested_tables.lua — Nesting: real configs are tables of tables
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Tables inside tables: the shape of every real plugin spec.
--   • Reading deep values: chains of dots and brackets.
--   • Building deep structures incrementally without crashing.
--   • Why `a.b.c` explodes when `b` is missing — and the and-chain
--     idiom (`a and a.b and a.b.c`) that plugins use to survive it.
--   • Walking nested structures with nested loops.
-- HOW TO RUN
--   luajit 03_nested_tables.lua      (from this directory)
--   or inside nvim:  :luafile %      (with this file open)
-- PREREQUISITES: 02_dictionaries.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. A real-shaped plugin spec
-- Table values can be tables, whose values can be tables... Every file
-- in your ~/.config/nvim/lua/plugins/ returns exactly this kind of
-- structure. Here's a telescope spec like the one you already own:
local telescope = {
  "nvim-telescope/telescope.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },   -- a table in a table
  opts = {                                      -- deeper...
    defaults = {                                -- deeper still...
      layout_strategy = "flex",
      mappings = {
        i = { ["<C-u>"] = false },              -- four levels down
      },
    },
    pickers = {
      find_files = { hidden = true },
    },
  },
}

------------------------------------------------------------ 2. Reading deep values
-- Chain the accessors left to right. Each dot/bracket is just an index
-- into whatever the previous step returned:
print("repo:           ", telescope[1])
print("first dependency:", telescope.dependencies[1])
print("layout strategy: ", telescope.opts.defaults.layout_strategy)
print("hidden files?    ", telescope.opts.pickers.find_files.hidden)

-- Mix dots and brackets freely — brackets for the non-identifier key:
print("<C-u> in insert: ", tostring(telescope.opts.defaults.mappings.i["<C-u>"]))

-- Intermediate tables are ordinary values; grab one into a local to
-- shorten repeated access (and to make code readable):
local defaults = telescope.opts.defaults
print("via local:       ", defaults.layout_strategy)

------------------------------------------------------------ 3. A hyprland config as one nested table
-- Your hyprland.conf has nested sections — decoration{} contains
-- shadow{} and blur{}. Nested tables model that exactly:
local hypr = {
  general = {
    gaps_in = 3,
    gaps_out = 3,
    border_size = 1,
    resize_on_border = true,
    layout = "dwindle",
  },
  decoration = {
    rounding = 10,
    active_opacity = 0.75,
    inactive_opacity = 0.6,
    shadow = { enabled = true, range = 4, render_power = 3 },  -- nested section
    blur   = { enabled = true, size = 3, passes = 1 },         -- nested section
  },
  monitors = {   -- an ARRAY of dictionaries: five entries, one per monitor line
    { name = "eDP-1",    mode = "1920x1080@60",  position = "0x0" },
    { name = "DP-1",     mode = "2560x1440@60",  position = "auto-up" },
    { name = "DP-4",     mode = "1920x1080@180", position = "1920x0" },
    { name = "DP-3",     mode = "1920x1080@180", position = "3840x0" },
    { name = "HDMI-A-1", mode = "1920x1080",     position = "1920x0" },
  },
}
print("blur passes:      ", hypr.decoration.blur.passes)
print("third monitor:    ", hypr.monitors[3].name, hypr.monitors[3].mode)

------------------------------------------------------------ 4. Building deep structures incrementally
-- You can't assign into a level that doesn't exist yet:
local cfg = {}
local ok, err = pcall(function()
  cfg.input.kb_layout = "us"   -- cfg.input is nil → indexing nil explodes
end)
print("crash caught by pcall:", ok, "→", err)
-- "attempt to index field 'input' (a nil value)" — memorize this
-- message. It is THE most common error in a broken Neovim config, and
-- it always means: some table on the chain wasn't created/loaded.

-- The fix: create each level before writing into it...
cfg.input = {}
cfg.input.kb_layout = "us"
print("after creating the level:", cfg.input.kb_layout)

-- ...or use the ensure-a-sub-table idiom (`or {}` — the same
-- short-circuit `or` you already know, here defaulting a whole table):
cfg.input.touchpad = cfg.input.touchpad or {}
cfg.input.touchpad.natural_scroll = true
print("touchpad natural_scroll:", cfg.input.touchpad.natural_scroll)

------------------------------------------------------------ 5. Safe navigation: the and-chain
-- Reading has the same landmine. This user config has no `blur` section:
local user_overrides = {
  decoration = { rounding = 0 },     -- user only overrides rounding
}

-- Direct deep read → boom (caught here so the lesson keeps running):
local ok2, err2 = pcall(function()
  return user_overrides.decoration.blur.size
end)
print("unsafe deep read:", ok2, "→", err2)

-- The idiom: `and` short-circuits, returning its left side when that
-- side is nil/false. So the chain stops at the first missing level and
-- yields nil instead of exploding:
local blur_size = user_overrides.decoration
    and user_overrides.decoration.blur
    and user_overrides.decoration.blur.size
print("safe deep read:  ", tostring(blur_size))   --> nil, no crash

-- Combine with `or` for a default value — the shape you'll see all
-- over plugin source code:
local size = (user_overrides.decoration
    and user_overrides.decoration.blur
    and user_overrides.decoration.blur.size) or hypr.decoration.blur.size
print("blur size w/ default:", size)               --> falls back to 3

-- Neovim note: Neovim ships vim.tbl_get(t, "a", "b", "c") to do
-- this chain for you — pure LuaJIT has no equivalent, so learn the
-- and-chain; you'll read it constantly.

------------------------------------------------------------ 6. Walking nested structures
-- Nested data wants nested loops. Outer ipairs over the monitor array,
-- inner reads of each dictionary — this is half of a config generator:
print("-- monitors as hyprland lines --")
for _, mon in ipairs(hypr.monitors) do
  print(string.format("monitor = %s, %s, %s, 1", mon.name, mon.mode, mon.position))
end

-- And pairs-in-pairs for dictionary-of-dictionaries. Two levels of
-- decoration{} rendered as indented config text:
print("-- decoration section --")
for key, value in pairs(hypr.decoration) do
  if type(value) == "table" then           -- nested section → recurse a level
    print("  " .. key .. " {")
    for k2, v2 in pairs(value) do
      print("    " .. k2 .. " = " .. tostring(v2))
    end
    print("  }")
  else
    print("  " .. key .. " = " .. tostring(value))
  end
end
-- (Arbitrary-depth recursion into tables comes in 04, where you'll
-- write a deep copy — same skeleton, different payload.)

------------------------------------------------------------ TRY IT
-- 1. Add your real HDMI-A-1 refresh rate to its monitor entry as a
--    `mode` change, then re-run and check the generated line.
-- 2. Add opts.pickers.live_grep = { additional_args = { "--hidden" } }
--    to the telescope spec IN THE CONSTRUCTOR, then print the first
--    additional arg with one long accessor chain.
-- 3. Write an and-chain that safely reads
--    telescope.opts.defaults.mappings.n["<C-d>"] (note: the `n` table
--    doesn't exist). Confirm you get nil, not a crash.
-- 4. Give user_overrides a decoration.blur = { size = 8 } and watch
--    section 5's "blur size w/ default" switch from 3 to 8.
