----------------------------------------------------------------------
-- 04_buffers_windows_api.lua — the low-level vim.api namespace
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • What vim.api / nvim_* is, and its naming conventions
--   • Reading and writing buffer text: nvim_buf_get_lines / set_lines
--   • Creating scratch buffers and a floating window (headless-safe!)
--   • Moving the cursor: nvim_win_set_cursor and its indexing trap
--   • How to find any of this yourself in :help api
-- HOW TO RUN
--   nvim --clean -l 04_buffers_windows_api.lua   (from this directory)
--   or inside nvim:  :luafile %   (it opens+closes a float too fast to see)
-- PREREQUISITES: 01_hello_neovim.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. What vim.api is
-- vim.api is the RAW editor API — the same functions plugins written in
-- any language call over RPC. Everything else you've met (vim.opt,
-- vim.keymap) is a friendly wrapper over this layer. Naming conventions:
--
--   nvim_buf_*    operates on a buffer   (first arg: buffer handle, 0 = current)
--   nvim_win_*    operates on a window   (first arg: window handle, 0 = current)
--   nvim_tabpage_*, nvim_ui_*, plain nvim_*  (editor-global)
--
-- Handles are just integers. Buffer = file contents in memory; window =
-- a viewport showing a buffer (one buffer can be in many windows).
-- Discovery: :help api   :help api-buffer   :help nvim_buf_get_lines()

-- vim.api.nvim_get_current_buf() → handle of the current buffer
--   ≈  :echo bufnr()   (Vimscript builtin bufnr())
local cur = vim.api.nvim_get_current_buf()

-- vim.api.nvim_list_bufs() → all buffer handles
--   ≈  :ls  (roughly; :ls shows only listed buffers, this returns ALL)
print("current buf:", cur, "| all bufs:", vim.inspect(vim.api.nvim_list_bufs()))

------------------------------------------------------------ 2. Reading and writing lines
-- THE indexing rule of vim.api: line ranges are 0-INDEXED and
-- END-EXCLUSIVE, like a C for-loop (and like string.sub is NOT).
-- (start=0, end=-1) means "the whole buffer". Burn this in now:
-- almost every off-by-one in plugin code is this rule.

-- vim.api.nvim_buf_set_lines(buf, start, end_, strict, lines)
--   replaces the range with `lines`   ≈  :call setline(1, [...]) + :delete for the rest
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "alpha",
  "bravo",
  "charlie",
})

-- vim.api.nvim_buf_get_lines(buf, start, end_, strict) → list of lines
--   ≈  :echo getline(1, "$")   (Vimscript getline() — but 0-indexed here!)
local all = vim.api.nvim_buf_get_lines(0, 0, -1, false)
print("whole buffer:  ", vim.inspect(all))

-- Just line 2 ("bravo"): 0-indexed start=1, end-exclusive end=2.
local second = vim.api.nvim_buf_get_lines(0, 1, 2, false)
print("line 2 only:   ", vim.inspect(second))

-- Append at the end: start = end_ = -1 inserts before "one past the end".
vim.api.nvim_buf_set_lines(0, -1, -1, false, { "delta (appended)" })

-- vim.api.nvim_buf_line_count(buf) → number of lines
--   ≈  :echo line("$")
print("line count now:", vim.api.nvim_buf_line_count(0))

-- The `strict` flag: true = error if the range is out of bounds,
-- false = clamp quietly. Use false unless you WANT the error.

------------------------------------------------------------ 3. Creating a scratch buffer
-- vim.api.nvim_create_buf(listed, scratch) → new buffer handle
--   listed=false: hidden from :ls    scratch=true: no file, no swap, throwaway
--   ≈  :new + :setlocal buftype=nofile bufhidden=hide noswapfile  (in one call)
local scratch = vim.api.nvim_create_buf(false, true)
print("created scratch buffer:", scratch)

-- Fill it — note we address it by HANDLE, no need to switch to it.
-- That's the superpower over ex-commands, which mostly act on "current".
vim.api.nvim_buf_set_lines(scratch, 0, -1, false, {
  "This buffer has no file behind it.",
  "Plugins build previews, pickers and popups from these.",
})

------------------------------------------------------------ 4. A floating window (create, read back, close)
-- Floats are just windows with a `relative` config. This is how every
-- hover doc, telescope prompt, and lazy.nvim panel is drawn.
-- Works headless: the window exists even though nothing renders it.

-- vim.api.nvim_open_win(buf, enter, config) → window handle
--   no Vimscript equivalent — floats are a Neovim-API-only feature
--   (:help nvim_open_win()  :help api-floatwin)
local float = vim.api.nvim_open_win(scratch, false, {
  relative = "editor", -- position relative to the whole editor grid
  row = 2, col = 4, -- offset from that anchor (0-indexed screen cells)
  width = 50, height = 2,
  style = "minimal", -- no number column, no cursorline, etc.
  border = "rounded", -- draw a border (try "single", "double", "none")
})
print("float window:", float)

-- Read the config back:
-- vim.api.nvim_win_get_config(win) → the float's config table
local cfg = vim.api.nvim_win_get_config(float)
print(("float is %dx%d, relative to '%s'"):format(cfg.width, cfg.height, cfg.relative))

-- vim.api.nvim_win_get_buf(win) → which buffer the window shows
--   ≈  :echo winbufnr(win)
print("float shows buffer:", vim.api.nvim_win_get_buf(float))

-- vim.api.nvim_win_is_valid(win) → does the handle still point at a window?
print("valid before close:", vim.api.nvim_win_is_valid(float))

-- vim.api.nvim_win_close(win, force)   ≈  :close!  (but for ANY window by handle)
vim.api.nvim_win_close(float, true)
print("valid after close: ", vim.api.nvim_win_is_valid(float))

------------------------------------------------------------ 5. The cursor — and the (1,0) trap
-- vim.api.nvim_win_set_cursor(win, {row, col})
--   ≈  :call cursor(row, col+1)
-- TRAP: row is 1-INDEXED but col is 0-INDEXED. Yes, really — rows follow
-- Vim tradition, cols follow API tradition. {1, 0} = start of the file.
vim.api.nvim_win_set_cursor(0, { 3, 2 }) -- line 3, third character

-- vim.api.nvim_win_get_cursor(win) → {row, col}, same mixed indexing
--   ≈  :echo [line("."), col(".") - 1]
print("cursor {row,col}:", vim.inspect(vim.api.nvim_win_get_cursor(0)))

-- vim.api.nvim_get_current_line() → the line under the cursor
--   ≈  :echo getline(".")
print("line under cursor:", vim.api.nvim_get_current_line())

------------------------------------------------------------ 6. Finding your way around
--   :help api                 the full contract, grouped by prefix
--   :help api-buffer          buffer functions overview
--   := vim.api.nvim_<Tab>     tab-complete the whole namespace, live
--
-- Deprecation corner (you WILL meet these in old blog posts/plugins):
--   nvim_buf_set_option(b,'x',v)  → use vim.bo[b].x = v  (or nvim_set_option_value)
--   nvim_buf_get_option           → vim.bo[b].x
--   nvim_command("...")           → vim.cmd("...")
-- Recognize them; don't write them.

------------------------------------------------------------ TRY IT
-- 1. Change the float's border to "double" and make it 20 columns wide;
--    confirm via nvim_win_get_config before closing it.
-- 2. Write a function reverse_lines(buf) that reads all lines, reverses
--    the table (module 03 skills!), and writes them back. Test it here.
-- 3. Use nvim_buf_set_lines with start=1, end_=2 to replace ONLY line 2,
--    then print the buffer to confirm nothing else moved.
-- 4. Trigger the (1,0) trap on purpose: pcall nvim_win_set_cursor with
--    {0, 0} and print the error message it gives you.
