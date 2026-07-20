----------------------------------------------------------------------
-- 04_lazy_nvim_specs.lua — A lazy.nvim spec is just a table
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • The anatomy of a plugin spec: it's pure data (module 03's tables!)
--   • [1] repo string, opts vs config — and the opts-AND-config mistake
--   • dependencies, lazy-loading via event/cmd/keys/ft, init vs config
--   • Version pinning and what lazy-lock.json is for
-- HOW TO RUN
--   nvim --clean -l 04_lazy_nvim_specs.lua      (from this directory)
--   or inside nvim:  :luafile %
-- PREREQUISITES: 01_config_anatomy.md, module 03 (tables)
----------------------------------------------------------------------
-- NOTE: lazy.nvim is NOT installed under --clean, so this file never calls
-- lazy itself. It BUILDS spec tables — the exact tables your
-- lua/plugins/*.lua files return — inspects them, and simulates the two
-- ways lazy consumes them. Everything here still applies verbatim to your
-- real config; only the `require("lazy")` part is missing on purpose.

------------------------------------------------------------ 1. the smallest possible spec
-- Each file in your lua/plugins/ returns ONE table (or a list of them).
-- The minimal spec is a table whose [1] element (module 03: array part!)
-- is the GitHub "owner/repo" shorthand:
local minimal = { "folke/tokyonight.nvim" }
print("1. minimal spec:", vim.inspect(minimal)) -- vim.inspect → table to string
-- That alone means: clone github.com/folke/tokyonight.nvim into
-- ~/.local/share/nvim/lazy/tokyonight.nvim and put it on runtimepath.
-- Everything else is optional keys in the hash part of the same table.

------------------------------------------------------------ 2. opts vs config
-- 90% of plugins follow one convention: they expose require("x").setup(tbl).
-- lazy gives you two ways to feed that:
--
--   opts = { ... }            -- DATA: lazy itself calls
--                             --   require("x").setup(opts)  after loading.
--   config = function() end   -- CODE: lazy calls YOUR function instead and
--                             --   does NOT call setup for you.
--
-- Rule of thumb: use `opts` (data beats code — mergeable, inspectable,
-- overridable). Reach for `config` only when you need statements: requiring
-- the module to call other functions, conditional logic, keymaps after load.
local with_opts = {
  "folke/tokyonight.nvim",
  opts = { style = "night", transparent = false }, -- → setup({style=...})
}
print("2. opts-style spec:", vim.inspect(with_opts))

-- THE CLASSIC MISTAKE — supplying BOTH, with a config that ignores opts:
local clobbering = {
  "folke/tokyonight.nvim",
  opts = { style = "night" },                -- you THINK this is applied...
  config = function()
    -- ...but config REPLACES lazy's default behavior. lazy evaluates opts
    -- and passes them as a 2nd argument — this function ignores them:
    -- require("tokyonight").setup({})       -- opts silently thrown away!
  end,
}
-- The fix if you truly need a config function: accept and forward opts.
--   config = function(_, opts) require("tokyonight").setup(opts) end
-- Let's simulate lazy's loader to make the clobbering visible:
local function simulate_lazy(spec, fake_module)
  if spec.config then
    spec.config(spec, spec.opts or {}) -- lazy calls config(plugin, opts)
  elseif spec.opts then
    fake_module.setup(spec.opts) -- lazy's default: setup(opts)
  end
  return fake_module.received
end
-- (note: fake must exist BEFORE the closure that captures it — module 02!)
local fake = { received = "never called" }
fake.setup = function(o) fake.received = o end
print("2. clobbering spec: setup received:", vim.inspect(simulate_lazy(clobbering, fake)))
fake.received = "never called"
print("2. opts-only spec:  setup received:", vim.inspect(simulate_lazy(with_opts, fake)))
-- (Lesson 06 has a broken spec like this for you to fix.)

------------------------------------------------------------ 3. init vs config
--   init   = function running at STARTUP, before the plugin loads.
--            For vim.g.* globals that legacy plugins read on load.
--   config = function running AFTER the plugin loads (maybe much later,
--            if lazy-loaded).
-- Mnemonic: init = "prepare the world for it", config = "set it up".
local legacy_style = {
  "some/legacy-plugin",
  init = function()
    -- vim.g.NAME = value  ≈  :let g:NAME = value  (plugin reads it on load)
    vim.g.legacy_plugin_mode = "fast"
  end,
}
print("3. init runs early; config runs after load:", vim.inspect(legacy_style))

------------------------------------------------------------ 4. a realistic spec: your telescope.lua, annotated
-- This is the shape of ~/.config/nvim/lua/plugins/telescope.lua:
local telescope_spec = {
  -- [1]: repo shorthand — lazy names the plugin "telescope.nvim"
  "nvim-telescope/telescope.nvim",

  -- Pin a release: "0.1.x" means "any 0.1 patch, never 0.2".
  -- Also legal: version = "*" (latest stable tag), or commit/branch/tag keys.
  -- Exact installed commits are recorded in lazy-lock.json either way —
  -- `:Lazy restore` rolls back to it. Commit that file to git.
  version = "0.1.x",

  -- dependencies: specs (or repo strings) loaded BEFORE this plugin.
  -- Not a package manager's dependency solver — just "load these first".
  dependencies = { "nvim-lua/plenary.nvim" },

  -- LAZY-LOADING TRIGGERS: without any, the plugin loads at startup.
  -- With them, lazy arms cheap stubs and loads the real thing on demand:
  --   event = "VeryLazy"        after startup finishes (lazy's own event)
  --   event = "InsertEnter"     any autocmd event works (module 06!)
  --   cmd   = { "Telescope" }   first :Telescope invocation loads it
  --   ft    = { "markdown" }    on that filetype (how your markview.lua works)
  --   keys  = { ... }           on a keypress — best of all: it DEFINES the
  --                             mapping, so the keymap lives with the plugin.
  cmd = { "Telescope" },
  keys = {
    -- Each entry: { lhs, rhs, desc = ... } — vim.keymap.set args as data.
    -- (Another "tables all the way down": mappings as data, like specs.)
    { "<leader>ff", function() print("would open find_files") end, desc = "Find files" },
    { "<leader>fg", function() print("would open live_grep") end, desc = "Live grep" },
  },

  -- opts: becomes require("telescope").setup(opts) — see section 2.
  opts = {
    defaults = {
      layout_strategy = "horizontal",
      sorting_strategy = "ascending",
    },
  },
}
print("4. telescope-ish spec:")
print(vim.inspect(telescope_spec))

------------------------------------------------------------ 5. specs are data → you can lint them yourself
-- Because a spec is a plain table, plain Lua can sanity-check it. A tiny
-- linter for the mistakes from this lesson:
local function lint_spec(spec)
  local warnings = {}
  if type(spec[1]) ~= "string" then
    table.insert(warnings, "spec[1] should be an 'owner/repo' string")
  end
  if spec.opts and spec.config then
    table.insert(warnings, "both opts AND config: make config forward opts, or drop one")
  end
  if spec.config and type(spec.config) ~= "function" then
    table.insert(warnings, "config must be a function (did you mean opts = {...}?)")
  end
  return warnings
end
print("5. lint(clobbering):", vim.inspect(lint_spec(clobbering)))
print("5. lint(telescope): ", vim.inspect(lint_spec(telescope_spec)))
-- lazy.nvim does deeper versions of these checks: `:checkhealth lazy`.

------------------------------------------------------------ TRY IT
-- 1. Write a spec table for "folke/which-key.nvim" that loads on the
--    "VeryLazy" event with opts = { delay = 300 }. Lint it.
-- 2. Break telescope_spec: set config = function() end while keeping opts,
--    re-run, and watch both the simulation (section 2) and the linter flag it.
-- 3. Extend lint_spec to warn when `dependencies` is a string instead of a
--    table (lazy accepts it, but consistency helps grep-ability).
-- 4. Open your real lua/plugins/tokyonight.lua side by side with section 4.
--    Which keys does yours use? Is the transparent background done via opts,
--    or via the nvim_set_hl calls in init.lua (lesson 01 step 5)? Why does
--    that difference matter when you change colorschemes?
