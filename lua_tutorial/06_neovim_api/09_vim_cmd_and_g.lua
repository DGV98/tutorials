----------------------------------------------------------------------
-- 09_vim_cmd_and_g.lua — vim.cmd, the variable scopes, and translating
--                        any Vimscript one-liner
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • vim.cmd("...") and the vim.cmd.colorscheme("...") call syntax
--   • vim.g / vim.b / vim.w / vim.t / vim.v ↔ g: / b: / w: / t: / v:
--   • nvim_set_hl — the exact call your init.lua uses for transparency
--   • THE GENERAL RECIPE for translating any Vimscript line to Lua
-- HOW TO RUN
--   nvim --clean -l 09_vim_cmd_and_g.lua    (from this directory)
--   or inside nvim:  :luafile %
-- PREREQUISITES: everything before this — it's the capstone
----------------------------------------------------------------------

------------------------------------------------------------ 1. vim.cmd — the escape hatch
-- vim.cmd(string) executes any ex-command, exactly as if you typed it
-- after `:`. It's the universal adapter: whenever no Lua API exists (or
-- you don't know it yet), vim.cmd gets you home.  (:help vim.cmd())
--   ≈  the whole : cmdline
vim.cmd("set number") --  ≈  :set number   (but prefer vim.o.number = true, lesson 02!)
print("number after vim.cmd:", vim.o.number) -- vim.o read-back (lesson 02)

-- Multi-line scripts work too — [[...]] is module 01's long string:
vim.cmd([[
  set nonumber
  echomsg "two ex-commands, one vim.cmd"
]])
print("number after block:", vim.o.number)

------------------------------------------------------------ 2. vim.cmd.<name>() — the call syntax
-- vim.cmd is callable AND indexable: vim.cmd.write() == vim.cmd("write").
-- Arguments become command arguments. Reads much better in config:
vim.cmd.set("number") --  ≈  :set number
-- vim.cmd.colorscheme("default")  ≈  :colorscheme default
vim.cmd.colorscheme("default")
print("colorscheme applied via vim.cmd.colorscheme")

-- Your init.lua's `vim.cmd([[colorscheme tokyonight-night]])` could be
-- written `vim.cmd.colorscheme("tokyonight-night")` — same effect, and
-- the plugin name is a real string your linter can see.
-- Bang and args go in a table form when needed:
--   vim.cmd.write({ bang = true })   ≈  :write!

------------------------------------------------------------ 3. Variable scopes: g:, b:, w:, t:, v:
-- Vimscript variables have single-letter scope prefixes. Each has a Lua
-- mirror table (lesson 02 already used vim.g for mapleader):
--
--   vim.g.x   ≈  g:x   global — plugin switches, mapleader
--   vim.b.x   ≈  b:x   per BUFFER — "state about this file"
--   vim.w.x   ≈  w:x   per WINDOW
--   vim.t.x   ≈  t:x   per TAB page
--   vim.v.x   ≈  v:x   VIM-OWNED specials (mostly read-only)

vim.g.snacks_enabled = true --  ≈  :let g:snacks_enabled = 1
print("g:snacks_enabled:", vim.g.snacks_enabled)

vim.b.last_formatted = os.date("%H:%M") --  ≈  :let b:last_formatted = ...
print("b:last_formatted:", vim.b.last_formatted)
-- vim.b[bufnr].x targets another buffer by handle, like vim.bo[bufnr]
-- (lesson 02). Buffer variables die with the buffer — free cleanup.

-- vim.v specials you'll actually read:
--   vim.v.count    ≈ v:count    count before a mapping (lesson 03's expr map)
--   vim.v.event    ≈ v:event    extra info inside some autocmds
--   vim.v.shell_error ≈ v:shell_error   exit code of last :! / system()
print("v:progpath (this nvim binary):", vim.v.progpath) --  ≈  :echo v:progpath
-- Writing to most v: vars errors — they're Vim's, not yours (pcall proof):
local ok, err = pcall(function() vim.v.count = 5 end)
print("writing v:count fails:", ok, "->", tostring(err):match("E%d+[^']*") or err)

-- Deleting a variable: assign nil, like any Lua table (module 03):
vim.g.snacks_enabled = nil --  ≈  :unlet g:snacks_enabled
print("after unlet:", tostring(vim.g.snacks_enabled))

------------------------------------------------------------ 4. nvim_set_hl — your transparent background, explained
-- Highlight groups are named palettes ("Normal", "Comment", ...) that
-- colorschemes fill in. Your init.lua does EXACTLY this after loading
-- tokyonight to make the background transparent (so your Hyprland
-- blur/opacity shows through):
--
-- vim.api.nvim_set_hl(ns, name, attrs)  ≈  :highlight Normal guibg=NONE
--   ns = 0 means the global namespace (plugins use others for isolation)
vim.api.nvim_set_hl(0, "Normal", { bg = "none" }) --  ≈  :hi Normal guibg=NONE
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" }) --  ≈  :hi NormalFloat guibg=NONE

-- TRAP worth knowing: nvim_set_hl REPLACES the whole group definition —
-- it does not merge. { bg = "none" } also wipes any fg the theme set for
-- that group. For Normal that's fine (fg comes per-syntax-group), but if
-- you ever want to tweak one attribute, read-modify-write:
-- vim.api.nvim_get_hl(0, {name=...}) → current attrs   ≈  :hi Normal (listing)
local current = vim.api.nvim_get_hl(0, { name = "Normal" })
print("Normal now:", vim.inspect(current)) -- bg gone = transparent
-- Order matters in init.lua: colorscheme FIRST, then set_hl — a later
-- :colorscheme repaints everything and undoes your overrides. (That's
-- why those two calls sit AFTER vim.cmd([[colorscheme tokyonight-night]]).)

------------------------------------------------------------ 5. THE RECIPE: translating any Vimscript line
-- You'll meet Vimscript in READMEs, old blog posts, and :help examples
-- forever. Translate by asking, in order:
--
--   1. Is it :set …?               → vim.o / vim.opt            (lesson 02)
--      :set rnu                    → vim.o.relativenumber = true
--   2. Is it :map-family?          → vim.keymap.set             (lesson 03)
--      :nnoremap <silent> Q <Nop>  → vim.keymap.set("n","Q","<Nop>",{silent=true})
--   3. Is it :autocmd?             → nvim_create_autocmd        (lesson 06)
--   4. Is it :command?             → nvim_create_user_command   (lesson 07)
--   5. Is it :let g:x = …?         → vim.g.x = …                (this lesson)
--   6. Is it a function call, call f() or :echo f(…)? → vim.fn.f(…)   (lesson 05)
--   7. Is it :hi …?                → nvim_set_hl                (this lesson)
--   8. Anything else / not sure?   → vim.cmd("the line, verbatim") — it
--      ALWAYS works; upgrade to the proper API later.
--
-- Worked example — a classic vimrc line:
--   autocmd FileType make setlocal noexpandtab
-- Steps 3 + 1 (setlocal → vim.bo, lesson 02):
vim.api.nvim_create_autocmd("FileType", { -- ≈ :autocmd FileType make ... (lesson 06)
  group = vim.api.nvim_create_augroup("Lesson09", { clear = true }), -- ≈ :augroup + autocmd! (lesson 06)
  pattern = "make",
  callback = function(ev)
    vim.bo[ev.buf].expandtab = false --  ≈  :setlocal noexpandtab (lesson 02)
  end,
})
vim.bo.filetype = "make" -- fires FileType, ≈ :setlocal filetype=make (lesson 06 trick)
print("makefile buffers use real tabs:", not vim.bo.expandtab)

-- And the lazy fallback for the same line — one honest vim.cmd:
vim.cmd([[autocmd Lesson09 FileType make setlocal noexpandtab]]) -- works today, refactor tomorrow

------------------------------------------------------------ 6. Where you now stand
-- You can read every line of your init.lua:
--   vim.opt.rtp:prepend(lazypath)      lesson 02 (vim.opt prepend)
--   require("me") / require("lazy")    module 04 (modules)
--   vim.cmd([[colorscheme ...]])       this lesson
--   vim.api.nvim_set_hl(0, ...) ×2     this lesson
-- and every line of lua/me/remap.lua (lesson 03) and lua/me/opts.lua
-- (lesson 02). Module 07 builds on all of this to write a plugin.

------------------------------------------------------------ TRY IT
-- 1. Translate WITHOUT vim.cmd, then verify by printing the option:
--      set scrolloff=8
--      let g:loaded_netrw = 1
--      nnoremap <leader>pv :Ex<CR>       (hint: rhs can stay a string)
-- 2. Use vim.api.nvim_get_hl(0, {name="Comment"}) before and after a
--    vim.api.nvim_set_hl(0, "Comment", { italic = true }) — confirm the
--    replace-not-merge trap by watching the fg disappear.
-- 3. Store something in vim.b in this buffer, create a second buffer
--    (lesson 04), and prove the variable didn't follow you.
-- 4. Grep your real config for `vim.cmd` — for each hit, decide which
--    recipe step would replace it, and whether it's worth doing.
