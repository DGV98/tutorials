----------------------------------------------------------------------
-- solutions.lua — Module 03: Tables
----------------------------------------------------------------------
-- Complete solutions. Each block notes the ONE insight the exercise
-- was really about. Run with:  luajit solutions.lua
----------------------------------------------------------------------

------------------------------------------------------------ EXERCISE 1: numbered lines
-- Insight: ipairs hands you index AND value — no manual counter.
local exec_once = {
  "dbus-update-activation-environment --all",
  "waybar",
  "hyprpaper",
  "sh -c 'sleep 1 && ghostty -e nvim ~/todos.md'",
}
print("== exercise 1 ==")
for i, cmd in ipairs(exec_once) do
  print(i .. ") " .. cmd)
end

------------------------------------------------------------ EXERCISE 2: plugin list surgery
-- Insight: find-then-remove keeps the sequence dense; `list[i] = nil`
-- would have left a hole and broken # and ipairs.
local plugins = {
  "nvim-telescope/telescope.nvim",
  "pwntester/octo.nvim",
  "nvim-lualine/lualine.nvim",
  "folke/tokyonight.nvim",
}
print("== exercise 2 ==")
-- a) position first, value second — the 3-arg insert trap from lesson 05
table.insert(plugins, 1, "folke/lazy.nvim")

-- b) find, then remove by index
local octo_index
for i, name in ipairs(plugins) do
  if name == "pwntester/octo.nvim" then
    octo_index = i
    break
  end
end
table.remove(plugins, octo_index)

-- c) comparator: true when a should sort before b
table.sort(plugins, function(a, b)
  return a:match("[^/]+$") < b:match("[^/]+$")
end)

-- d)
print(table.concat(plugins, ", "))

------------------------------------------------------------ EXERCISE 3: deterministic dictionary dump
-- Insight: pairs() order is undefined, so determinism = collect keys,
-- sort them, iterate the SORTED LIST and index back into the table.
local general = {
  gaps_in = 3,
  gaps_out = 3,
  border_size = 1,
  resize_on_border = true,
  layout = "dwindle",
}
print("== exercise 3 ==")
local keys = {}
for key in pairs(general) do
  table.insert(keys, key)
end
table.sort(keys)
for _, key in ipairs(keys) do
  print(key .. " = " .. tostring(general[key]))
end

------------------------------------------------------------ EXERCISE 4: safe deep reads
-- Insight: `and` stops at the first nil (no crash); `or` supplies the
-- default. But `or` can't tell false from nil — see c).
local spec = {
  "nvim-telescope/telescope.nvim",
  opts = {
    defaults = { layout_strategy = "flex" },
  },
}
print("== exercise 4 ==")
-- a) present → the and-chain reaches the real value, or is never needed
local strategy = (spec.opts and spec.opts.defaults
    and spec.opts.defaults.layout_strategy) or "horizontal"
print("a) layout_strategy:", strategy)

-- b) missing leaf → chain yields nil → or kicks in
local winblend = (spec.opts and spec.opts.defaults
    and spec.opts.defaults.winblend) or 0
print("b) winblend:", winblend)

-- c) missing branch (no pickers table at all)
local hidden = (spec.opts and spec.opts.pickers
    and spec.opts.pickers.find_files
    and spec.opts.pickers.find_files.hidden) or false
print("c) hidden:", hidden)
-- The catch: if the config really contained `hidden = false`, the `or`
-- would "default" it to false anyway — harmless HERE because the
-- default is also false, but with `or true` you could never turn the
-- option off. When false is meaningful, test `== nil` instead of `or`.

------------------------------------------------------------ EXERCISE 5: deep_copy, proven
-- Insight: recursion detaches EVERY level; shallow copy detaches only
-- the top one. == checks identity, which is exactly what "detached"
-- means: not the same table anymore.
local hypr = {
  decoration = {
    rounding = 10,
    blur = { enabled = true, size = 3 },
  },
}
print("== exercise 5 ==")
local function deep_copy(t)
  if type(t) ~= "table" then return t end
  local copy = {}
  for key, value in pairs(t) do
    copy[key] = deep_copy(value)
  end
  return copy
end

local copy = deep_copy(hypr)
copy.decoration.blur.size = 99
print("a) original blur.size still:", hypr.decoration.blur.size)       --> 3
print("b) copy == original?", copy == hypr)                             --> false
print("c) nested tables also detached?", copy.decoration.blur == hypr.decoration.blur) --> false

------------------------------------------------------------ EXERCISE 6: dedupe, order preserved
-- Insight: the SET answers "seen before?" in one lookup; the LIST
-- preserves order. Two structures, one loop — a very Lua pairing.
local lhs_list = {
  "<leader>ff", "<leader>fg", "<leader>ff", "<leader>e",
  "<leader>fg", "<leader>gd", "<leader>e",
}
print("== exercise 6 ==")
local seen = {}
local deduped = {}
for _, lhs in ipairs(lhs_list) do
  if not seen[lhs] then
    seen[lhs] = true
    table.insert(deduped, lhs)
  end
end
print(table.concat(deduped, ", "))

------------------------------------------------------------ EXERCISE 7: setup(), for real
-- Insight: `opts = opts or {}` makes setup() and setup({}) identical,
-- and the DEEP merge is what lets a user override window.width without
-- nuking window.border. (In Neovim this is vim.tbl_deep_extend("force",
-- defaults, opts) — vim.tbl_deep_extend(behavior, ...) = recursive
-- merge, "force": rightmost wins. :help vim.tbl_deep_extend())
local my_plugin = {}
local plugin_defaults = {
  greeting = "hello",
  window = { border = "rounded", width = 40 },
}
print("== exercise 7 ==")
local function tbl_deep_extend(base, override)
  local merged = {}
  for k, v in pairs(base) do merged[k] = v end
  for k, v in pairs(override) do
    if type(v) == "table" and type(merged[k]) == "table" then
      merged[k] = tbl_deep_extend(merged[k], v)
    else
      merged[k] = v
    end
  end
  return merged
end

local config
function my_plugin.setup(opts)
  opts = opts or {}
  config = tbl_deep_extend(plugin_defaults, opts)
  return config
end

local c1 = my_plugin.setup()
print("call 1:", c1.window.border, c1.window.width)   --> rounded 40
local c2 = my_plugin.setup({ window = { width = 80 } })
print("call 2:", c2.window.border, c2.window.width)   --> rounded 80
local c3 = my_plugin.setup({ greeting = "yo" })
print("call 3:", c3.greeting)                         --> yo

------------------------------------------------------------ EXERCISE 8: the sting — render a config tree
-- Insight: recursion + sorted keys + building lines in a list. This
-- little function is the seed of module 08's Lua→hyprland.conf
-- generator. Note scalars and sub-tables are collected SEPARATELY so
-- scalars always print first — pairs() alone could never promise that.
local decoration = {
  rounding = 10,
  shadow = { range = 4 },
  blur = { enabled = true, passes = 1 },
}
print("== exercise 8 ==")
local function render(tbl, indent)
  local scalar_keys, table_keys = {}, {}
  for key, value in pairs(tbl) do
    if type(value) == "table" then
      table.insert(table_keys, key)
    else
      table.insert(scalar_keys, key)
    end
  end
  table.sort(scalar_keys)
  table.sort(table_keys)

  local lines = {}
  for _, key in ipairs(scalar_keys) do
    table.insert(lines, indent .. key .. " = " .. tostring(tbl[key]))
  end
  for _, key in ipairs(table_keys) do
    table.insert(lines, indent .. key .. " {")
    table.insert(lines, render(tbl[key], indent .. "    "))  -- recurse deeper
    table.insert(lines, indent .. "}")
  end
  return table.concat(lines, "\n")
end

print(render(decoration, ""))
