----------------------------------------------------------------------
-- 06_patterns.lua — Table patterns every plugin uses
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Sets: t[key] = true — membership tests without loops.
--   • Stacks and queues out of plain tables.
--   • Merging config tables by hand: shallow, then deep — and how
--     that IS Neovim's vim.tbl_deep_extend, which you'll preview.
--   • The `opts = opts or {}` defaulting pattern behind every
--     plugin's setup() function.
-- HOW TO RUN
--   luajit 06_patterns.lua           (from this directory)
--   or inside nvim:  :luafile %      (with this file open)
-- PREREQUISITES: 05_gotchas.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. Sets: keys ARE the membership test
-- Lua has no set type — you don't need one. Store each member as a
-- KEY with value true; lookup is then one hash access, no searching.
-- Config-shaped example: filetypes where you want format-on-save off:
local no_format_on_save = {
  ["markdown"] = true,
  ["text"]     = true,
  ["mdx"]      = true,
}

-- Membership check reads like English (nil is falsy, remember):
local ft = "markdown"
if no_format_on_save[ft] then
  print(ft .. ": formatting DISABLED")
end
print("lua in the set?", no_format_on_save["lua"] ~= nil)   --> false

-- Compare with the list version — a loop, every single time you ask:
local list_version = { "markdown", "text", "mdx" }
local found = false
for _, name in ipairs(list_version) do
  if name == ft then found = true; break end
end
print("list scan found it too:", found, "(but it walked the list to do it)")

-- Converting list → set is two lines, and a very common opening move
-- in plugin code that receives a list from the user's opts:
local set = {}
for _, name in ipairs(list_version) do set[name] = true end
print("converted, text in set?", set["text"] == true)

-- Add: set[k] = true.  Remove: set[k] = nil.  You already know both.

------------------------------------------------------------ 2. Stack: push/pop at the end
-- A stack (last in, first out) is a table plus discipline: only touch
-- the end. table.insert pushes, table.remove pops. Undo history,
-- nested-section parsing, DFS — all stacks.
-- Here: tracking nested hyprland sections while parsing a config file:
local section_stack = {}
table.insert(section_stack, "decoration")   -- push: entered decoration {
table.insert(section_stack, "blur")         -- push: entered blur {
print("depth:", #section_stack, "| innermost:", section_stack[#section_stack])

local closed = table.remove(section_stack)  -- pop: hit a }
print("closed section:", closed, "| now inside:", section_stack[#section_stack])

------------------------------------------------------------ 3. Queue: first in, first out
-- Quick version: push with table.insert(t, item), take with
-- table.remove(t, 1). Correct, but remove-at-1 shifts every element
-- left — O(n) per removal. Fine for a dozen items, bad for thousands.
local jobs = {}
table.insert(jobs, "download tokyonight")
table.insert(jobs, "build treesitter parsers")
print("serving:", table.remove(jobs, 1))     -- oldest first
print("serving:", table.remove(jobs, 1))

-- The grown-up version keeps two cursors and never shifts anything —
-- a dictionary used with numeric keys and a bit of bookkeeping:
local q = { first = 1, last = 0 }
local function q_push(item)
  q.last = q.last + 1
  q[q.last] = item
end
local function q_pop()
  if q.first > q.last then return nil end   -- empty
  local item = q[q.first]
  q[q.first] = nil                          -- release the reference
  q.first = q.first + 1
  return item
end
q_push("event 1"); q_push("event 2"); q_push("event 3")
print("q pops in order:", q_pop(), q_pop(), q_pop(), tostring(q_pop()))

------------------------------------------------------------ 4. Merging tables: defaults + user overrides
-- THE central problem of configuration: the plugin has defaults, the
-- user has overrides, produce the combined table. Shallow merge first
-- (later tables win on key conflicts):
local function tbl_extend(base, override)
  local merged = {}
  for k, v in pairs(base)     do merged[k] = v end
  for k, v in pairs(override) do merged[k] = v end   -- override wins
  return merged
end

local defaults      = { rounding = 10, active_opacity = 0.75, inactive_opacity = 0.6 }
local user          = { rounding = 0 }
local merged = tbl_extend(defaults, user)
print("merged rounding (user won):     ", merged.rounding)
print("merged active_opacity (default):", merged.active_opacity)

-- Shallow merge has the flaw you can now predict: a nested table in
-- `override` REPLACES the whole nested default, wiping siblings:
local deep_defaults = {
  rounding = 10,
  blur = { enabled = true, size = 3, passes = 1 },
}
local deep_user = {
  blur = { size = 8 },        -- user only wanted to change size...
}
local shallow = tbl_extend(deep_defaults, deep_user)
print("shallow merge, blur.size:  ", shallow.blur.size)              --> 8
print("shallow merge, blur.passes:", tostring(shallow.blur.passes))  --> nil! wiped

-- DEEP merge: when BOTH sides have a table under the same key,
-- recurse into them instead of replacing:
local function tbl_deep_extend(base, override)
  local merged = {}
  for k, v in pairs(base) do merged[k] = v end
  for k, v in pairs(override) do
    if type(v) == "table" and type(merged[k]) == "table" then
      merged[k] = tbl_deep_extend(merged[k], v)   -- merge the sub-tables
    else
      merged[k] = v                               -- otherwise override wins
    end
  end
  return merged
end

local deep = tbl_deep_extend(deep_defaults, deep_user)
print("deep merge, blur.size:  ", deep.blur.size)     --> 8   (user)
print("deep merge, blur.passes:", deep.blur.passes)   --> 1   (default survived!)

-- PREVIEW: you just reimplemented a Neovim builtin. Inside nvim:
--   vim.tbl_deep_extend("force", deep_defaults, deep_user)
--     -- vim.tbl_deep_extend(behavior, ...)  → recursive table merge;
--     --   "force" = rightmost wins, "keep" = leftmost wins,
--     --   "error" = duplicate keys raise. Takes any number of tables.
--     -- No Vimscript equivalent; pure Lua helper. :help vim.tbl_deep_extend()
-- This one function is how lazy.nvim combines a plugin's default opts
-- with the opts = {...} in YOUR spec files. You'll meet it for real in
-- module 06. (It's vim.*, so it doesn't exist under plain luajit —
-- which is exactly why we built our own here.)

------------------------------------------------------------ 5. `opts = opts or {}` — the setup() pattern
-- Open any plugin's source and setup() starts the same way. Combine
-- the or-default with the deep merge and you get the whole shape:
local my_plugin = {}                 -- a plain table we hang functions on

local plugin_defaults = {
  greeting = "hello",
  window = { border = "rounded", width = 40 },
}
local config = nil                   -- the plugin's live config, set by setup()

function my_plugin.setup(opts)
  opts = opts or {}                  -- ① nil-proof: setup() == setup({})
  config = tbl_deep_extend(plugin_defaults, opts)   -- ② defaults + user
  print(string.format("setup: greeting=%s border=%s width=%d",
    config.greeting, config.window.border, config.window.width))
end

-- Why line ①? Callers do all of these, and all must work:
my_plugin.setup()                              -- no argument at all → opts is nil
my_plugin.setup({ greeting = "yo" })           -- partial override
my_plugin.setup({ window = { width = 80 } })   -- nested partial override
-- Without `opts = opts or {}`, the first call would crash inside the
-- merge: pairs(nil) → "bad argument #1 to 'pairs'". With it, "no
-- config" and "empty config" become the same easy case.

-- The same idiom defaults a single FIELD, chained with and-safety:
local function open_float(opts)
  opts = opts or {}
  local border = opts.border or "rounded"          -- field-level default
  local title  = (opts.window and opts.window.title) or "untitled"
  print("open_float: border=" .. border .. " title=" .. title)
end
open_float()
open_float({ border = "single", window = { title = "todos.md" } })

-- One honest caveat before you sprinkle `x = x or default` everywhere:
-- `or` replaces ALL falsy values, so it can't tell false from nil.
-- If false is a meaningful user choice ("disable it"), or-defaulting
-- would silently overwrite it — test `== nil` instead:
local function set_number_option(value)
  if value == nil then value = true end   -- default true, but false is respected
  print("number option:", value)
end
set_number_option()        --> true  (defaulted)
set_number_option(false)   --> false (respected — `or` would have said true!)

------------------------------------------------------------ TRY IT
-- 1. Build a set of your disabled plugins from the list
--    { "neotree", "octo" } and write an if that prints "skipping X"
--    for any plugin name found in the set.
-- 2. Make the section_stack print a hyprland-style "breadcrumb" like
--    decoration > blur by table.concat-ing it with " > " after each
--    push and pop.
-- 3. Call my_plugin.setup({ window = { border = "none" } }) and
--    predict width BEFORE running: 40 or nil? (Deep vs shallow merge
--    is the whole question.)
-- 4. The sting: change tbl_deep_extend so lists are NOT merged —
--    when both values are tables but the override looks like an array
--    (its [1] ~= nil), REPLACE instead of merging. Then verify:
--    merging { tags = {"a","b"} } over { tags = {"x","y","z"} } should
--    yield exactly {"a","b"}, not {"a","b","z"}. (This mirrors real
--    vim.tbl_deep_extend behavior discussions — merged lists are
--    almost never what anyone wants.)
