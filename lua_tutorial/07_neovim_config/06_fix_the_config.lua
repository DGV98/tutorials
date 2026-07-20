----------------------------------------------------------------------
-- 06_fix_the_config.lua — Capstone: six broken config snippets. Fix them.
----------------------------------------------------------------------
-- WHAT YOU'LL DO
--   • Six snippets below mimic real bug classes in YOUR config layout
--     (lua/me/*, lua/plugins/*, lazy specs, keymaps, autocmds)
--   • Each is wrapped in a check() so this file always exits 0
--   • Run the file, read the caught errors (lesson 03 taught you how),
--     fix each snippet IN PLACE at the FIXME, re-run
--   • You are done when all six lines print FIXED
-- HOW TO RUN
--   nvim --clean -l 06_fix_the_config.lua      (from this directory)
-- PREREQUISITES: everything in this module
----------------------------------------------------------------------
-- Solutions wait at the very bottom behind a SOLUTIONS divider.
-- Earn them: re-run at least twice before scrolling.

------------------------------------------------------------ test harness
-- Your real lua/me/* files can't load under --clean, so we preload stand-ins.
-- NEW TRICK: package.preload[name] = loader-fn. After a package.loaded cache
-- miss (the cache is module 04), require's FIRST searcher is package.preload —
-- consulted before any file search, which is why every "module not found"
-- trace begins with a "no field package.preload[...]" line:
package.preload["me.remap"] = function() return { name = "me.remap" } end
package.preload["me.opts"] = function() return { name = "me.opts" } end
package.preload["me.todos"] = function() return { name = "me.todos" } end
-- A fake tokyonight that records what setup() receives (for BUG 5):
package.preload["tokyonight"] = function()
  local T = { received = nil }
  T.setup = function(o) T.received = o end
  return T
end

-- vim.g.mapleader  →  <leader> key  ≈  :let g:mapleader=" " (before any maps!)
vim.g.mapleader = " "

local results = {}
local function check(label, fn)
  -- pcall  →  run the snippet, catch anything it throws (lesson 03)
  local ok, err = pcall(fn)
  results[#results + 1] = ok
  -- (io.write instead of print: some vim-internal error paths eat a pending
  --  newline in -l mode's message output; direct stdout writes never do)
  if ok then
    io.write(("FIXED         %s\n"):format(label))
  else
    io.write(("STILL BROKEN  %s\n"):format(label))
    io.write("              → " .. tostring(err) .. "\n")
  end
end

------------------------------------------------------------ BUG 1: the require that never finds your keymaps
-- Real-life symptom: nvim starts plugin-less and grey, :messages shows
--   E5113: ... module 'me.remaps' not found: no field package.preload[...
-- Your init.lua step 2 (lesson 01) dies, so steps 3-5 never run.
check("BUG 1: require path for the remap module", function()
  local remap = require("me.remaps") -- FIXME: the file is lua/me/remap.lua
  assert(remap.name == "me.remap", "loaded something unexpected")
end)

------------------------------------------------------------ BUG 2: the keymap that runs NOW instead of on keypress
-- Real-life symptom: your todos file opens the moment nvim starts (the
-- function ran while the config loaded!), and then the mapping errors:
--   rhs: expected string|function, got nil
check("BUG 2: keymap that calls the function at map time", function()
  local function open_todos()
    -- (the real one would do vim.cmd.edit("~/todos.md") ≈ :edit ~/todos.md)
    return nil
  end
  -- vim.keymap.set("n", lhs, rhs, o)  ≈  :nnoremap — rhs must be a string
  --   or a FUNCTION VALUE, not the function's return value
  vim.keymap.set("n", "<leader>td", open_todos(), { desc = "open todos" }) -- FIXME
  -- vim.fn.maparg(lhs, mode, abbr, dict)  →  mapping info table, {} if absent
  local info = vim.fn.maparg("<leader>td", "n", false, true)
  assert(info.callback ~= nil, "mapping was not created")
end)

------------------------------------------------------------ BUG 3: the option typo
-- Real-life symptom: startup error "Unknown option 'nubmer'" and every
-- option AFTER the typo in me/opts.lua never gets set (the file aborted).
check("BUG 3: option typo from me/opts.lua", function()
  -- vim.opt.number = true  ≈  :set number
  vim.opt.nubmer = true -- FIXME: vim.opt raises on unknown option names
  vim.opt.relativenumber = true -- ≈ :set relativenumber (never reached!)
  -- vim.opt.number:get()  →  read the option's current value
  assert(vim.opt.number:get() == true, "'number' is still off")
  assert(vim.opt.relativenumber:get() == true, "'relativenumber' is still off")
end)

------------------------------------------------------------ BUG 4: the autocmd that multiplies
-- Real-life symptom: after :source-ing your config a few times while
-- iterating, saving one Lua file runs your format-on-save THREE times
-- (three duplicate autocmds — each :source added another).
check("BUG 4: autocmd stacks duplicates on every re-source", function()
  local function register() -- pretend this is a chunk of your config file
    -- FIXME: no augroup — nothing clears the old registration.
    -- (hint: nvim_create_augroup(name, {clear=true}) ≈ :augroup X | au! )
    -- vim.api.nvim_create_autocmd(event, o)  ≈  :autocmd BufWritePre *.lua ...
    vim.api.nvim_create_autocmd("BufWritePre", {
      pattern = "*.lua",
      callback = function() end, -- imagine: conform format-on-save
      desc = "format lua on save (bug4)",
    })
  end
  register()
  register() -- ← simulates you :source-ing the config a second time
  -- vim.api.nvim_get_autocmds(filter)  →  list matching autocmds
  local n = 0
  for _, au in ipairs(vim.api.nvim_get_autocmds({ event = "BufWritePre" })) do
    if au.desc == "format lua on save (bug4)" then n = n + 1 end
  end
  assert(n == 1, "registered " .. n .. " times — duplicates!")
end)

------------------------------------------------------------ BUG 5: the lazy spec that clobbers its own opts
-- Real-life symptom: none. That's the evil part — no error, your carefully
-- chosen opts just silently don't apply (comments stay italic, style wrong).
-- This is your lua/plugins/tokyonight.lua shape; lesson 04 §2 is the theory.
check("BUG 5: spec with opts AND a config that ignores them", function()
  local spec = {
    "folke/tokyonight.nvim",
    opts = { style = "night", styles = { comments = { italic = false } } },
    config = function(_, opts) -- FIXME: lazy passes opts in — this drops them
      require("tokyonight").setup({})
    end,
  }
  -- Simulate exactly what lazy.nvim does with a loaded spec (lesson 04):
  if spec.config then
    spec.config(spec, spec.opts or {})
  elseif spec.opts then
    require("tokyonight").setup(spec.opts)
  end
  local got = require("tokyonight").received
  assert(got and got.style == "night", "setup() never received your opts")
end)

------------------------------------------------------------ BUG 6: the shadowed local
-- Real-life symptom: "attempt to call local 'map' (a table value)" from your
-- remap.lua — confusing, because `map` worked fine ten lines earlier.
check("BUG 6: inner local shadows the map helper", function()
  local map = vim.keymap.set -- the classic alias at the top of remap.lua
  local function telescope_maps()
    local map = { "<leader>ff", "<leader>fg" } -- FIXME: same name = shadow!
    map("n", "<leader>ff", function() end, { desc = "find files (bug6)" })
    map("n", "<leader>fg", function() end, { desc = "live grep (bug6)" })
  end
  telescope_maps()
  local info = vim.fn.maparg("<leader>ff", "n", false, true)
  assert(info.desc == "find files (bug6)", "mapping missing")
end)

------------------------------------------------------------ scoreboard
local fixed = 0
for _, ok in ipairs(results) do
  if ok then fixed = fixed + 1 end
end
io.write(("\nSCORE: %d/%d fixed%s\n"):format(fixed, #results,
  fixed == #results and " — module 07 complete, go break your REAL config on purpose"
  or " — read the errors above, fix the FIXMEs, re-run"))

------------------------------------------------------------ TRY IT
-- 1. Fix all six until the score says 6/6. Resist the solutions below.
-- 2. For BUG 4, try the WRONG fix first: an augroup WITHOUT clear=true
--    (pass {} instead of {clear=true}). Re-run. Duplicates or not? Why?
--    (:help nvim_create_augroup — read what clear defaults to.)
-- 3. Recreate BUG 1 in your real config: rename a require in
--    ~/.config/nvim/lua/me/init.lua, restart nvim, read the real E5113 with
--    :messages, then fix it. Feel the difference now that you can read it.
-- 4. Which of the six could :checkhealth lazy have caught? Which could NO
--    tool catch except your own eyes? (Hint: the silent one.)

----------------------------------------------------------------------
--
--
--
--                            SOLUTIONS
--          (scroll no further until you've re-run twice)
--
--
--
----------------------------------------------------------------------
--[==[

BUG 1 — require("me.remaps")  →  require("me.remap")
  The require string must mirror the path under lua/ exactly:
  lua/me/remap.lua ⇒ "me.remap". Plural/singular typos are THE most
  common config bug. The error's trace lines show every path tried —
  read one and the mismatch jumps out.

BUG 2 — open_todos()  →  open_todos
  With (), the function runs immediately and its RETURN VALUE (nil)
  becomes the rhs. Pass the function itself as a value (module 02:
  functions are values). Same fix shape:
    vim.keymap.set("n", "<leader>td", open_todos, { desc = "open todos" })

BUG 3 — vim.opt.nubmer  →  vim.opt.number
  vim.opt validates option names and raises "Unknown option". A typo
  doesn't just skip one option — it aborts the whole file, so every
  line after it silently never runs. That's why one typo in me/opts.lua
  can make nvim feel completely unconfigured.

BUG 4 — wrap the autocmd in a cleared group:
    local grp = vim.api.nvim_create_augroup("MyFormatOnSave", { clear = true })
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = grp,
      pattern = "*.lua",
      callback = function() end,
      desc = "format lua on save (bug4)",
    })
  clear=true wipes the group's previous contents each time the code
  runs, so re-sourcing replaces instead of stacking. (clear=true is the
  default, but write it anyway — the intent matters. Compare the
  mini-plugin's setup(), which survives being called three times.)

BUG 5 — two correct fixes, pick either:
  a) delete the config key entirely — lazy's default behavior IS
     require("tokyonight").setup(opts); or
  b) make config forward what lazy hands it:
       config = function(_, opts) require("tokyonight").setup(opts) end
  Prefer (a): data over code. Keep config functions only when they must
  do more than call setup.

BUG 6 — rename the inner variable:
    local pickers = { "<leader>ff", "<leader>fg" }
  A `local` with the same name shadows the outer one for the rest of the
  scope (module 02). The error names the variable — "local 'map' (a
  table value)" — and "a TABLE value" is the tell: your function-alias
  suddenly 'became' a table, meaning some nearer `map` won the lookup.

]==]
