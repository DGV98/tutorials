----------------------------------------------------------------------
-- 02_debugging_toolkit.lua — Every tool you need to debug your config
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • The print → :messages loop, and vim.print/vim.inspect for tables
--   • vim.notify with severity levels (and why plugins use it)
--   • Finding WHO set an option or mapping: :verbose set / :verbose map
--   • Bisecting "my config or a plugin?" with --clean and --noplugin
--   • :checkhealth and lazy.nvim's :Lazy log / profile / debug
--   • Reading a Lua error's file:line and jumping straight to it
-- HOW TO RUN
--   nvim --clean -l 02_debugging_toolkit.lua     (from this directory)
--   or inside nvim:  :luafile %
-- PREREQUISITES: 01_config_anatomy.md, module 06
----------------------------------------------------------------------

------------------------------------------------------------ 1. print and :messages
-- The humble print() is still tool #1. Where does it go?
--   • headless (`nvim -l`, like right now): straight to stdout.
--   • inside a real session: to the "message history". It may flash and
--     vanish — that's fine, because :messages replays the whole history.
-- THE WORKFLOW: sprinkle prints in your config → restart nvim → :messages.
--   :messages clear   wipes the history when it gets noisy.
print("1. print goes to :messages inside nvim, stdout out here")

-- print() concatenates its args with tabs, but it calls tostring() on each,
-- which is useless for tables:
local spec = { "nvim-telescope/telescope.nvim", lazy = true }
print("1. a table through print:", spec) -- table: 0x... — thanks for nothing

------------------------------------------------------------ 2. vim.inspect and vim.print
-- vim.inspect(t)  →  pure function: returns a human-readable STRING for any
--                    value, nested tables included. :help vim.inspect()
print("2. vim.inspect:", vim.inspect(spec))

-- vim.print(...)  ≈  print(vim.inspect(x)) for each arg, and it RETURNS its
--                    args unchanged — so you can wrap it around any
--                    expression without breaking the code. :help vim.print()
local picked = vim.print({ picker = "find_files", cwd = "~" })
print("2. vim.print returned the table:", picked.picker)

-- Wrap-in-place example — debugging what setup() receives without
-- restructuring anything:
--   require("telescope").setup(vim.print(my_opts))

------------------------------------------------------------ 3. := — the inspect-anything command
-- Inside a real session, `:=expr` evaluates a Lua expression and pretty-
-- prints it (it's sugar for :lua vim.print(expr)). :help :=
-- Try these in your real nvim:
--   :=vim.opt.runtimepath:get()
--   :=package.loaded["me.opts"]
--   :=vim.api.nvim_get_keymap("n")
-- Headless equivalent of the first one, so this file demonstrates it:
-- vim.opt.runtimepath:get()  →  option object → Lua list of rtp entries
local rtp = vim.opt.runtimepath:get()
print("3. first rtp entry (what := would show):", rtp[1])

------------------------------------------------------------ 4. vim.notify and levels
-- vim.notify(msg, level)  ≈  :echomsg / :echoerr, but routable: plugins like
--   noice or fidget can hook it and show popups. :help vim.notify()
-- Levels live in vim.log.levels: TRACE=0 DEBUG=1 INFO=2 WARN=3 ERROR=4.
-- Use it in your own config for anything a future-you should notice:
-- vim.log.levels  →  table of severity constants. :help vim.log.levels
vim.notify("4. plain notify (INFO by default)", vim.log.levels.INFO)
vim.notify("4. a WARN — shows highlighted in a real session", vim.log.levels.WARN)
-- ERROR notifications land in :messages in red and set v:errmsg. In a config
-- file, prefer notify over error() for non-fatal problems: error() aborts the
-- rest of the file; notify lets startup continue.

------------------------------------------------------------ 5. WHO set this option? :verbose
-- The single best trick for "my option keeps changing". In a real session:
--   :verbose set formatoptions?
--   → formatoptions=jcroql
--   → Last set from /usr/share/nvim/runtime/ftplugin/lua.lua line 20
-- Now you KNOW: it wasn't your me/opts.lua, it was the lua ftplugin.
-- Same trick for mappings:
--   :verbose nmap <leader>ff
--   → tells you the file:line that created the mapping (telescope.lua, say).
-- We can demo it headless by capturing command output:
-- vim.opt.number = true  ≈  :set number
vim.opt.number = true
-- vim.api.nvim_exec2(cmd, {output=true})  →  run ex-command, capture output
--   (≈ :redir in old Vimscript). :help nvim_exec2()
local out = vim.api.nvim_exec2("verbose set number?", { output = true })
print("5. verbose knows who set 'number':")
print(out.output) -- "Last set from .../02_debugging_toolkit.lua line N"

------------------------------------------------------------ 6. listing mappings
-- :map            lists every mapping in all modes (a firehose)
-- :nmap <leader>  lists normal-mode maps starting with your leader — the
--                 useful version. Also :help map-listing for the format.
-- Programmatic version, great for scripting checks:
-- vim.g.mapleader  →  the <leader> key; g: variable. ≈ :let g:mapleader=" "
vim.g.mapleader = " "
-- vim.keymap.set("n", ...)  ≈  :nnoremap (noremap by default, Lua fn rhs ok)
vim.keymap.set("n", "<leader>dd", function() print("demo map ran") end,
  { desc = "debugging demo" })
-- vim.fn.maparg(lhs, mode, abbr, dict)  →  Vimscript maparg(); with dict=true
--   returns a table describing the mapping. :help maparg()
local info = vim.fn.maparg("<leader>dd", "n", false, true)
print("6. maparg found:", info.desc, "— callback is a", type(info.callback))
-- vim.api.nvim_get_keymap("n")  →  list of ALL normal-mode maps as tables
print("6. total n-mode maps right now:", #vim.api.nvim_get_keymap("n"))

------------------------------------------------------------ 7. is it my config, or a plugin?
-- The bisection ladder — run these from zsh, cheapest first:
--   nvim --clean        pristine nvim: no config, no plugins.
--                       Bug still there?  → it's Neovim itself (rare) or the file.
--   nvim --noplugin     YOUR init.lua runs, but plugin/ scripts don't load.
--   nvim -u NORC        no init.lua, but plugins still on rtp.
-- With lazy.nvim most code loads via lazy triggers, so also try disabling
-- half your lua/plugins/*.lua specs at a time: add `enabled = false` to a
-- spec table and restart (binary search — O(log n) restarts, like git bisect).
-- Headless demo that --clean really means clean:
-- vim.env.MYVIMRC  →  environment/vim variable: path of the loaded init file
print("7. under --clean, MYVIMRC is:", tostring(vim.env.MYVIMRC)) -- nil!

------------------------------------------------------------ 8. :checkhealth and :Lazy
-- :checkhealth          runs every registered health probe (providers, lsp,
--                       treesitter, lazy, ...). Read the ERRORs, ignore most
--                       WARNINGs about optional executables. :help :checkhealth
-- :checkhealth lazy     just lazy.nvim's own checks (spec mistakes show here!)
-- lazy.nvim's dashboards (interactive session only — it's not installed
-- under --clean, so these are comments, not code):
--   :Lazy log       recent git commits per plugin — "what changed before
--                   things broke?" Pair with `git -C ~/.local/share/nvim/...`
--   :Lazy profile   startup time per plugin, sorted. Find the 200ms hog.
--   :Lazy debug     which lazy-load triggers are armed and what's loaded.
--   :Lazy restore   roll every plugin back to lazy-lock.json — the "undo
--                   button" after a bad update. Commit that file to git!
print("8. :checkhealth / :Lazy — try in a real session (see comments)")

------------------------------------------------------------ 9. reading file:line and jumping there
-- Every Lua runtime error carries WHERE it happened. Anatomy:
--     /home/david/.config/nvim/lua/me/opts.lua:12: attempt to index ...
--     └────────────── file ──────────────────┘ └line┘ └── what happened ──
-- pcall(f)  →  run f, catch errors; returns ok, err (module 05)
local ok, err = pcall(function()
  local options -- oops, never assigned
  return options.relativenumber
end)
print("9. a real error message:", err)
-- Extract the location with a string pattern (module 05: captures):
local file, line = err:match("^(.-):(%d+):")
print("9. parsed  file=" .. file .. "  line=" .. line)
-- Jumping there inside nvim:
--   • :e +12 lua/me/opts.lua        (ex-command: open at line)
--   • put the cursor on the path in :messages output and press gF —
--     'goto File' honors the :line suffix. :help gF
-- Errors during startup are shown once and gone — :messages gets them back.

------------------------------------------------------------ TRY IT
-- 1. In your real nvim: `:verbose set formatoptions?` — which runtime file
--    set it? Then `:verbose nmap <leader>ff` (or any telescope map) and find
--    the exact line in your lua/plugins/telescope.lua that created it.
-- 2. Break section 9's pattern on purpose: make the error message have no
--    file:line (hint: error("bare", 0) — the 0 suppresses position info).
--    Re-run and make the match failure not crash the print that follows.
-- 3. Run `nvim --clean` then `:=vim.opt.runtimepath:get()` and count the
--    entries; compare with your normal session. The difference IS lazy.nvim.
-- 4. Add a vim.notify(..., vim.log.levels.WARN) to the top of your real
--    me/opts.lua, restart, and find it with :messages. Remove it after.
