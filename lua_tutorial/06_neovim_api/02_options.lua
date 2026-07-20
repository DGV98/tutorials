----------------------------------------------------------------------
-- 02_options.lua — vim.opt, vim.o, vim.g, vim.bo, vim.wo
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • vim.o vs vim.opt: two front doors to the same options
--   • vim.opt's object interface: append / prepend / remove / get()
--   • Buffer-local and window-local options: vim.bo, vim.wo, vim.opt_local
--   • vim.g is NOT options — it's g: variables (mapleader, plugin config)
--   • The :set / :setlocal Vimscript equivalent for every line
-- HOW TO RUN
--   nvim --clean -l 02_options.lua          (from this directory)
--   or inside nvim:  :luafile %
-- PREREQUISITES: 01_hello_neovim.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. vim.o — options as plain values
-- vim.o reads/writes options exactly like :set does, as simple Lua
-- values: booleans, numbers, strings. This is the door your
-- lua/me/opts.lua uses most.

vim.o.number = true          --  ≈  :set number
vim.o.shiftwidth = 4         --  ≈  :set shiftwidth=4
vim.o.mouse = "a"            --  ≈  :set mouse=a
print("number:", vim.o.number, "| shiftwidth:", vim.o.shiftwidth, "| mouse:", vim.o.mouse)

-- Reading is just as direct:
--   vim.o.shiftwidth         ≈  :echo &shiftwidth   (Vimscript &option syntax)
print("&shiftwidth via vim.o:", vim.o.shiftwidth)

-- Boolean options are REAL booleans here, unlike vim.fn results
-- (a trap covered in 05_vim_fn_bridge.lua).

------------------------------------------------------------ 2. vim.opt — options as objects
-- Many options are secretly LISTS ("wildignore=*.o,*.pyc"), FLAG SETS
-- ("shortmess=tF"), or DICTS ("listchars=tab:> ,trail:-") crammed into
-- one comma string. Through vim.o you'd be doing string surgery — the
-- same pain as editing $PATH with sed. vim.opt wraps each option in an
-- object that understands its own structure.  (:help vim.opt)

vim.opt.wildignore = { "*.o", "*.pyc" }   --  ≈  :set wildignore=*.o,*.pyc
-- vim.opt.wildignore:append(...)             ≈  :set wildignore+=*.swp
vim.opt.wildignore:append("*.swp")
-- vim.opt.wildignore:prepend(...)            ≈  :set wildignore^=node_modules/*
vim.opt.wildignore:prepend("node_modules/*")
-- vim.opt.wildignore:remove(...)             ≈  :set wildignore-=*.pyc
vim.opt.wildignore:remove("*.pyc")

-- :get() converts the option back into a NATURAL Lua value:
-- list option -> array table, flag option -> set table, dict option -> dict.
-- (:help vim.opt:get())   No Vimscript equivalent; &wildignore gives the raw string.
print("wildignore as Lua list:", vim.inspect(vim.opt.wildignore:get()))
print("wildignore raw string: ", vim.o.wildignore) -- same option, string view

-- Flag-set option: each flag becomes a key.
vim.opt.shortmess:append("I")             --  ≈  :set shortmess+=I  (skip intro screen)
print("shortmess set-table:", vim.inspect(vim.opt.shortmess:get()))

-- Dict option: assign a Lua table, read a Lua table.
vim.opt.listchars = { tab = "> ", trail = "-" } --  ≈  :set listchars=tab:>\ ,trail:-
print("listchars dict:", vim.inspect(vim.opt.listchars:get()))

-- Rule of thumb: WRITE structured options with vim.opt, READ simple
-- values with vim.o. Both touch the same underlying option.

------------------------------------------------------------ 3. Global vs buffer vs window options
-- Options have scopes, exactly like :set vs :setlocal in Vimscript:
--   global        (mouse)          one value for the whole editor
--   buffer-local  (shiftwidth)     per file being edited
--   window-local  (number, wrap)   per split showing a file
--
-- vim.bo[buf]  buffer-local options   ≈  :setlocal for buffer options
-- vim.wo[win]  window-local options   ≈  :setlocal for window options
-- Index 0 (or omit the index) means "current buffer/window".

vim.bo.expandtab = true      --  ≈  :setlocal expandtab      (current buffer)
vim.wo.wrap = false          --  ≈  :setlocal nowrap         (current window)
print("bo.expandtab:", vim.bo.expandtab, "| wo.wrap:", vim.wo.wrap)

-- vim.bo[0].shiftwidth reads the CURRENT buffer's value explicitly:
print("bo[0].shiftwidth:", vim.bo[0].shiftwidth)

-- vim.opt_local is vim.opt's :setlocal twin — same append/remove tricks,
-- buffer/window scope.   ≈  :setlocal ...      (:help vim.opt_local)
vim.opt_local.spell = false  --  ≈  :setlocal nospell
print("spell (window-local):", vim.wo.spell)
-- vim.opt_global also exists (≈ :setglobal) but you'll rarely need it.

-- Why care? A FileType autocmd (see 06_autocommands.lua) that sets
-- vim.o.shiftwidth would change the GLOBAL default for every future
-- buffer; vim.bo.shiftwidth changes only the file that triggered it.
-- Same bug class as `export VAR` vs a local shell variable.

------------------------------------------------------------ 4. vim.g — variables, not options
-- vim.g is a different beast: it reads/writes GLOBAL VARIABLES, the
-- g:things of Vimscript. No :set involved. Two big uses:
--
-- 1) The leader key (lesson 03 of this module explains the timing rule):
vim.g.mapleader = " "        --  ≈  :let g:mapleader = " "
-- 2) Old-school plugin configuration (pre-Lua plugins read g: vars):
vim.g.netrw_banner = 0       --  ≈  :let g:netrw_banner = 0
print("mapleader is set to:", vim.inspect(vim.g.mapleader))

-- Unset variables are nil, not an error:
print("undefined g:var reads as:", tostring(vim.g.this_never_existed))
-- More vim.g/vim.b/vim.v in 09_vim_cmd_and_g.lua.

------------------------------------------------------------ 5. Which door do I use? (cheat table)
--   set an on/off or single-value option        vim.o.x = v        :set x=v
--   add/remove from a list/flag/dict option     vim.opt.x:append   :set x+=v
--   option for THIS buffer/window only          vim.bo.x / vim.wo.x  :setlocal
--   read an option in an `if`                   vim.o.x  (or vim.opt.x:get())
--   g:variable (leader, plugin switches)        vim.g.x            :let g:x
--
-- Your lua/me/opts.lua is (almost certainly) a page of vim.o/vim.opt
-- lines. After this lesson, open it and you should be able to give the
-- :set equivalent of every line from memory.

------------------------------------------------------------ TRY IT
-- 1. Add `vim.opt.path:append("**")` here, print vim.opt.path:get(),
--    and write its `:set` equivalent in a comment. (It's the option that
--    makes `:find` recurse — handy.)
-- 2. Predict what vim.opt.shortmess:get() prints AFTER you also
--    :append("W"), then run and check yourself.
-- 3. Set vim.o.shiftwidth = 4 and vim.bo.shiftwidth = 2, then print
--    both vim.o.shiftwidth and vim.bo.shiftwidth. Which one did the
--    buffer-local write change? (:help global-local explains the rest.)
-- 4. In a live nvim: `:= vim.opt.listchars:get()` — then change one key
--    with :set listchars+=eol:$ and inspect again.
