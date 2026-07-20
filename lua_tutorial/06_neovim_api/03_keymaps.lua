----------------------------------------------------------------------
-- 03_keymaps.lua — vim.keymap.set and friends
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • vim.keymap.set(mode, lhs, rhs, opts) and its :map-family equivalents
--   • String rhs vs Lua function rhs — and the fn vs fn() bug, revisited
--   • The opts table: desc, silent, buffer, expr, remap
--   • Leader keys and WHY mapleader must be set before your mappings
--   • Inspecting and deleting maps: vim.fn.maparg, vim.keymap.del
-- HOW TO RUN
--   nvim --clean -l 03_keymaps.lua          (from this directory)
--   or inside nvim:  :luafile %
-- PREREQUISITES: 02_options.lua (vim.g.mapleader appears there)
----------------------------------------------------------------------

------------------------------------------------------------ 1. Anatomy of a mapping
-- vim.keymap.set(mode, lhs, rhs, opts)   (:help vim.keymap.set())
--   mode: "n", "i", "v", "x", "t", "c" ... or a LIST of them
--   lhs:  the keys you press          (left-hand side)
--   rhs:  what happens                (right-hand side: string OR Lua function)
--
-- Crucial default: vim.keymap.set is NON-recursive, i.e. it behaves
-- like :noremap, not :map. The rhs is taken literally, not re-expanded
-- through other mappings. That's almost always what you want.

-- Leader first! (Section 4 explains why this MUST come before the maps.)
vim.g.mapleader = " " --  ≈  :let g:mapleader = " "

-- vim.keymap.set("n", ...)  ≈  :nnoremap  (with better defaults; rhs may be a Lua fn)
vim.keymap.set("n", "<leader>w", "<Cmd>write<CR>", { desc = "Save file" })

-- Multiple modes at once — Vimscript needs two commands, Lua needs a list:
-- vim.keymap.set({"n","v"}, ...)  ≈  :nnoremap + :vnoremap in one call
vim.keymap.set({ "n", "v" }, "<leader>y", '"+y', { desc = "Yank to system clipboard" })

print("defined <leader>w and <leader>y")

------------------------------------------------------------ 2. String rhs vs Lua function rhs
-- A STRING rhs is keystrokes — exactly what you'd type after :nnoremap.
-- A FUNCTION rhs is Lua — the mapping calls your function when pressed.
-- Functions are why Lua config wins: no more stringly-typed <C-u>:call... noise.

-- vim.keymap.set with a Lua fn rhs  ≈  :nnoremap <lhs> <Cmd>lua ...<CR>, minus the ceremony
vim.keymap.set("n", "<leader>d", function()
  print("today is " .. os.date("%Y-%m-%d"))
end, { desc = "Print the date" })

-- THE fn vs fn() BUG, REVISITED (module 02 warned you; here's where it bites).
-- You must pass the function ITSELF, not the result of calling it:
--
--   vim.keymap.set("n", "<leader>d", print_date)     -- ✓ passes the function
--   vim.keymap.set("n", "<leader>d", print_date())   -- ✗ CALLS IT NOW, maps its
--                                                    --   return value (likely nil)
--
-- The broken version runs print_date once — while your config loads —
-- and then errors or maps nothing. If a mapping "runs at startup
-- instead of on keypress", grep your config for `)` right before the
-- opts table. Demonstrated safely with pcall (the file must still exit 0):
local ok, err = pcall(function()
  -- string.upper("x") evaluates to "X" immediately; "X" is a valid rhs,
  -- but imagine it was a function that returned nil:
  vim.keymap.set("n", "<leader>b", nil) -- what fn() usually evaluates to
end)
print("mapping a nil rhs fails as expected:", ok, "->", tostring(err):sub(1, 80))

------------------------------------------------------------ 3. The opts table
-- The 4th argument tweaks behavior. The ones you'll actually use:
--
--   desc    = "..."   shows up in :map output and which-key style plugins.
--                     ALWAYS set it; future-you greps for it.
--   silent  = true    ≈  :nnoremap <silent>   (don't echo the command)
--                     (Lua-fn rhs mappings are effectively silent already.)
--   buffer  = true    ≈  :nnoremap <buffer>   (this buffer only — the standard
--                     move inside LspAttach/FileType autocmds, see 06_)
--   expr    = true    ≈  :nnoremap <expr>     (rhs RETURNS the keys to use)
--   remap   = true    opt back INTO :map behavior — needed for <Plug> (below)

-- buffer-local mapping: gone when the buffer goes.
-- vim.keymap.set(..., { buffer = 0 })  ≈  :nnoremap <buffer>  (0 = current buffer)
vim.keymap.set("n", "<leader>t", "<Cmd>echo 'buffer-local!'<CR>", { buffer = 0, desc = "Buffer-local demo" })

-- expr mapping: the function returns a STRING OF KEYS, chosen at press time.
-- Classic example — j moves by screen line unless you gave a count:
-- vim.keymap.set(..., { expr = true })  ≈  :nnoremap <expr> j v:count == 0 ? 'gj' : 'j'
vim.keymap.set("n", "j", function()
  -- vim.v.count  ≈  v:count  (the count you typed before the key; 0 if none.
  --   vim.v — Vim's own variables — gets its full tour in lesson 09)
  return vim.v.count == 0 and "gj" or "j"
end, { expr = true, desc = "j moves by screen line unless counted" })

print("expr mapping for j installed")

------------------------------------------------------------ 4. Leader keys
-- <leader> is a placeholder expanded WHEN THE MAPPING IS DEFINED — not
-- when you press it. So vim.g.mapleader must be set BEFORE any mapping
-- that uses <leader>, or those maps bake in the default backslash.
-- That's why this file sets it at the very top of section 1, and why
-- lazy.nvim (your plugin manager) insists mapleader is set before
-- setup(): plugin keymaps are defined during setup.

-- vim.g.maplocalleader  ≈  :let g:maplocalleader = ","  (<localleader>: per-filetype maps)
vim.g.maplocalleader = ","
print("leader:", vim.inspect(vim.g.mapleader), "| localleader:", vim.inspect(vim.g.maplocalleader))

-- <Plug> mappings: plugins expose named "virtual keys" like
-- <Plug>(CommentToggle). Map yours onto them WITH remap = true, because
-- <Plug> only works through recursive expansion:
--   vim.keymap.set("n", "gcc", "<Plug>(CommentToggle)", { remap = true })
--   ≈  :nmap gcc <Plug>(CommentToggle)      (:nmap, not :nnoremap!)
-- (Comment-only: needs the plugin installed, and --clean has none.)

------------------------------------------------------------ 5. Inspecting and deleting
-- vim.fn.maparg(lhs, mode, false, true) → dict describing a mapping
--   ≈  :verbose nmap <leader>d   /  Vimscript builtin maparg()
--   (vim.fn — the bridge to Vimscript builtins — is lesson 05's whole topic;
--    heads-up: its "boolean" fields like noremap arrive as 0/1 numbers)
local info = vim.fn.maparg("<leader>d", "n", false, true)
print("maparg says:", "desc =", info.desc, "| noremap =", info.noremap, "| lua callback =", info.callback ~= nil)

-- vim.keymap.del(mode, lhs)  ≈  :nunmap <leader>d      (:help vim.keymap.del())
vim.keymap.del("n", "<leader>d")
-- maparg returns "" (empty) for a mapping that no longer exists:
print("after del, maparg finds:", vim.inspect(vim.fn.maparg("<leader>d", "n")))

-- In a live session, browse everything:
--   :map            all mappings          :nmap <leader>   your leader maps
--   :map <F5>       one specific key      :verbose map x   WHO defined it (gold
--                                         when a plugin steals your key)

------------------------------------------------------------ 6. Reading your own remap.lua
-- Your lua/me/remap.lua is a page of vim.keymap.set calls. You can now
-- read every one: mode, lhs, rhs (string or fn?), opts. For each, ask:
--   1. Does it have a desc? (Add one if not — free documentation.)
--   2. Is the rhs a function passed WITHOUT parens?
--   3. Should any be buffer-local instead of global?

------------------------------------------------------------ TRY IT
-- 1. Add a normal-mode mapping <leader>n that toggles line numbers:
--    the rhs fn should read vim.wo.number and set its negation. Verify
--    with vim.fn.maparg that your desc is attached.
-- 2. Break section 2 on purpose: write a named function and map it WITH
--    parens. Wrap in pcall, print the error, and read what it says.
-- 3. Make the j/gj expr mapping symmetric: add the same for k/gk.
-- 4. In a live nvim (not --clean): run :verbose map <Space> and find
--    which file defined each of your leader maps.
