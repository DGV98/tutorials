----------------------------------------------------------------------
-- 05_build_a_plugin.lua — Build, load, and exercise your own mini-plugin
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • The on-disk shape of a plugin: <root>/lua/<name>/init.lua
--   • The setup(opts) convention: defaults + vim.tbl_deep_extend("force",...)
--   • Wiring a user command, a keymap, and a (grouped!) autocmd
--   • Loading it exactly the way lazy.nvim would: put root on rtp, require
--   • Driving all of it headless — proof it really works
-- HOW TO RUN
--   nvim --clean -l 05_build_a_plugin.lua      (from this directory)
--   or inside nvim:  :luafile %
-- PREREQUISITES: 01_config_anatomy.md, 04_lazy_nvim_specs.lua, module 06
----------------------------------------------------------------------
-- THE PLUGIN LIVES NEXT DOOR — open it in a split now:
--   mini_plugin/lua/scratchpad/init.lua
-- It's a scratch-buffer toggler (a baby cousin of your todos workflow):
-- one command (:Scratch), one keymap, one autocmd, ~60 lines of real code.
-- This file is the "user side": it installs, configures, and tests it.

------------------------------------------------------------ 1. what makes a directory a plugin
-- Lesson 01: a plugin is a directory on runtimepath whose subdirs have
-- magic names. Ours only needs one:
--
--   mini_plugin/                      ← the "plugin root" (goes on rtp)
--   └── lua/
--       └── scratchpad/
--           └── init.lua              ← require("scratchpad") lands here
--
-- That's the whole install format. lazy.nvim does nothing fancier: it git
-- clones a repo shaped like this into ~/.local/share/nvim/lazy/<name> and
-- prepends that path to rtp. We'll do the same by hand, minus git.

------------------------------------------------------------ 2. put it on runtimepath
-- First, find THIS script's directory so the lesson works from any cwd:
-- debug.getinfo(1, "S").source  →  "@<path this chunk was loaded from>"
local source = debug.getinfo(1, "S").source:sub(2) -- :sub(2) strips the "@"
-- vim.fn.fnamemodify(path, ":p:h")  →  Vimscript fnamemodify(): make the
--   path absolute (:p), then take its head/directory (:h). :help filename-modifiers
local here = vim.fn.fnamemodify(source, ":p:h")
local plugin_root = here .. "/mini_plugin"
print("2. plugin root:", plugin_root)

-- Before it's on rtp, require can't see it — prove it (lesson 03 §4):
local ok_before = pcall(require, "scratchpad")
print("2. require before rtp:", ok_before) -- false

-- vim.opt.runtimepath:prepend(p)  ≈  :set rtp^=p — THE line every plugin
--   manager boils down to (your init.lua does this for lazy.nvim itself!)
vim.opt.runtimepath:prepend(plugin_root)
local ok_after, scratchpad = pcall(require, "scratchpad")
print("2. require after rtp: ", ok_after, "→ a", type(scratchpad))

------------------------------------------------------------ 3. setup(opts): merging defaults with vim.tbl_deep_extend
-- The plugin ships defaults; we override a subset. Inside setup() it runs:
--   M.opts = vim.tbl_deep_extend("force", M.defaults, opts or {})
-- "force" = rightmost wins on conflicts; nested tables merge key-by-key.
-- Quick standalone demo of those semantics before we rely on them:
-- vim.tbl_deep_extend(mode, ...)  →  recursive table merge. :help vim.tbl_deep_extend()
local merged = vim.tbl_deep_extend("force",
  { a = 1, nest = { x = 1, y = 2 } }, -- defaults
  { nest = { y = 99 } }) -- user opts
print("3. deep merge kept nest.x, replaced nest.y:", vim.inspect(merged))

-- vim.g.mapleader  →  the <leader> key ≈ :let g:mapleader=" " — must exist
--   BEFORE mappings that use <leader> (lesson 01 §6, first rule!)
vim.g.mapleader = " "
-- Now configure the plugin. notify=false keeps headless output tidy:
local sp = scratchpad.setup({ notify = false, filetype = "markdown" })
print("3. merged plugin opts:", vim.inspect(sp.opts))
-- Note what we did NOT pass (name, keymap) arrived from M.defaults.

------------------------------------------------------------ 4. exercise the user command
-- setup() registered :Scratch via nvim_create_user_command. Run it exactly
-- as you would by hand:
-- vim.cmd("Scratch")  ≈  typing :Scratch<CR>
vim.cmd("Scratch")
-- vim.api.nvim_buf_get_name(0)  →  name of buffer 0 (= current buffer)
print("4. after :Scratch, current buffer:", vim.api.nvim_buf_get_name(0))
-- vim.bo.filetype  →  buffer-local option read  ≈  :echo &filetype
print("4. its filetype:", vim.bo.filetype)
-- The autocmd (BufEnter on scratchpad://*) fired and counted the visit:
print("4. autocmd counted enters:", sp.stats.enters)

-- :Scratch again toggles back to where we were:
vim.cmd("Scratch")
print("4. toggled back to:", vim.inspect(vim.api.nvim_buf_get_name(0))) -- "" = the unnamed start buffer

------------------------------------------------------------ 5. exercise the keymap — headless!
-- You can press keys without a keyboard. Two-step incantation:
-- vim.api.nvim_replace_termcodes(s, ...)  →  turns "<leader>ss" into the
--   real bytes a terminal would send. :help nvim_replace_termcodes()
local keys = vim.api.nvim_replace_termcodes("<leader>ss", true, false, true)
print("") -- quirk: feedkeys' redraw eats the previous newline in -l mode
-- vim.api.nvim_feedkeys(keys, "x", false)  →  feed keys and ("x") flush
--   until fully consumed — like typing them. :help nvim_feedkeys()
vim.api.nvim_feedkeys(keys, "x", false)
print("5. after pressing <leader>ss:", vim.api.nvim_buf_get_name(0))
print("5. enters is now:", sp.stats.enters)

------------------------------------------------------------ 6. re-running setup is safe (the augroup lesson)
-- Because the plugin's autocmd lives in an augroup created with
-- { clear = true }, calling setup() again REPLACES the old autocmd instead
-- of stacking a duplicate. Watch:
scratchpad.setup({ notify = false })
scratchpad.setup({ notify = false })
-- vim.api.nvim_get_autocmds({group=...})  →  list autocmds, filtered
local autos = vim.api.nvim_get_autocmds({ group = "Scratchpad" })
print("6. autocmds after 3 total setups:", #autos, "(1 = no duplicates)")
-- Without the group this would print 3 — and in a real config, re-sourcing
-- would fire your callback 3× per event. Lesson 06 makes you fix that bug.

------------------------------------------------------------ 7. how you'd ship it
-- To use this for real, EITHER add one line to your init.lua after the
-- lazy bootstrap:
--   vim.opt.rtp:prepend(vim.fn.expand("~/personal/tutorials/lua_tutorial/07_neovim_config/mini_plugin"))
--   require("scratchpad").setup({})
-- OR treat it as a local lazy.nvim plugin — a spec with `dir`:
--   -- lua/plugins/scratchpad.lua
--   return {
--     dir = "~/personal/tutorials/lua_tutorial/07_neovim_config/mini_plugin",
--     name = "scratchpad",
--     opts = {},                    -- lazy calls require("scratchpad").setup(opts)
--     keys = { { "<leader>ss", desc = "Toggle scratchpad" } },
--   }
-- Same table anatomy as lesson 04 — dir instead of [1] repo string.
print("7. ship it: see comments for the init.lua / lazy spec versions")

------------------------------------------------------------ TRY IT
-- 1. Pass { keymap = false } to setup() in section 3 and confirm section 5
--    stops toggling (buffer name stays ""). Why doesn't :Scratch break too?
-- 2. Add an option `start_lines = { "# scratch", "" }` to M.defaults, and in
--    ensure_buf() write it into new buffers with nvim_buf_set_lines
--    (module 06). Verify here by printing nvim_buf_get_lines after :Scratch.
-- 3. Add a second command :ScratchInfo that vim.print()s M.opts and
--    M.stats. Re-run this file, call it in section 4.
-- 4. Delete `return M` from the plugin (temporarily!) and re-run this file.
--    Which lesson-03 error do you get, and at which line HERE? Put it back.
