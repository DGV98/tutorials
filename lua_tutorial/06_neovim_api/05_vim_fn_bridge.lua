----------------------------------------------------------------------
-- 05_vim_fn_bridge.lua — vim.fn: the bridge to Vimscript builtins
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • vim.fn.<name>() calls the Vimscript builtin of the same name
--   • The workhorses: expand, fnamemodify, getline/setline, has,
--     executable, stdpath (+ a jobstart mention)
--   • THE TRAP: Vimscript "booleans" arrive in Lua as 0/1 numbers
--   • Choosing between plain Lua, vim.api, and vim.fn
-- HOW TO RUN
--   nvim --clean -l 05_vim_fn_bridge.lua    (from this directory)
--   or inside nvim:  :luafile %
-- PREREQUISITES: 04_buffers_windows_api.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. What vim.fn is
-- Vim ships ~600 builtin functions (:help vimscript-functions) grown
-- over 30 years: file paths, text, dates, jobs... vim.fn exposes every
-- one of them to Lua. `vim.fn.expand(x)` IS `expand(x)` from Vimscript;
-- arguments and results are converted between the two languages
-- automatically (Vim list ↔ Lua table, Vim dict ↔ Lua table).

-- vim.fn.strftime("%Y-%m-%d")  →  Vimscript builtin strftime(); like os.date()
print("strftime:", vim.fn.strftime("%Y-%m-%d"))

------------------------------------------------------------ 2. Path work: expand and fnamemodify
-- vim.fn.expand("%")  →  Vimscript expand(); expands %-codes and wildcards
--   %       current file name          %:p   full path
--   %:t     tail (basename)            %:h   head (dirname)
--   %:e     extension                  %:r   root (path minus extension)
--   ≈  :echo expand("%:p")     (:help expand()  :help filename-modifiers)
-- Under --clean -l there is no file open, so expand("%") is "":
print("expand('%'):        ", vim.inspect(vim.fn.expand("%")))
print("expand('~'):        ", vim.fn.expand("~")) -- your $HOME, like the shell

-- vim.fn.fnamemodify(path, mods)  →  Vimscript fnamemodify(); applies the
--   same :t/:h/:e modifiers to ANY string, not just the current file
--   ≈  :echo fnamemodify("/a/b/c.lua", ":t")
local p = "/home/david/.config/nvim/init.lua"
print("fnamemodify :t ->", vim.fn.fnamemodify(p, ":t")) --> init.lua
print("fnamemodify :h ->", vim.fn.fnamemodify(p, ":h")) --> /home/david/.config/nvim
print("fnamemodify :e ->", vim.fn.fnamemodify(p, ":e")) --> lua
-- bash near-equivalents: basename, dirname, ${p##*.} — but portable.

-- vim.fn.stdpath("config")  →  where Neovim looks for your config
--   no Vimscript ancestor — a Neovim addition, but it lives in vim.fn
--   ("config" → ~/.config/nvim, "data" → ~/.local/share/nvim, also
--    "state", "cache", "run"; :help stdpath())
print("stdpath config:", vim.fn.stdpath("config"))
print("stdpath data:  ", vim.fn.stdpath("data"))
-- This is how your init.lua finds lazy.nvim:
--   vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

------------------------------------------------------------ 3. Text: getline and setline
-- These are the 1-INDEXED, "current buffer" cousins of the api calls
-- from lesson 04. Handy for quick scripts; vim.api for serious work.

-- vim.fn.setline(lnum, text_or_list)  →  Vimscript setline(); writes line(s)
--   ≈  :call setline(1, ["first", "second"])
vim.fn.setline(1, { "first line via setline", "second line" })

-- vim.fn.getline(lnum [, end])  →  Vimscript getline(); "." = cursor line,
--   "$" = last line. With two args returns a LIST (Lua table).
--   ≈  :echo getline(1)  /  :echo getline(1, "$")
print("getline(1):     ", vim.fn.getline(1))
print("getline(1,'$'): ", vim.inspect(vim.fn.getline(1, "$")))

------------------------------------------------------------ 4. THE TRAP: 0/1 is not false/true
-- Vimscript has no real booleans — its functions return 0 or 1.
-- Those cross the bridge as Lua NUMBERS. And in Lua (module 01!) every
-- number is truthy — INCLUDING 0.

-- vim.fn.has("nvim")  →  Vimscript has(); feature test, returns 0 or 1
--   ≈  :echo has("nvim")
print("has('nvim') =", vim.fn.has("nvim"), "type:", type(vim.fn.has("nvim")))

-- vim.fn.executable("cmd")  →  Vimscript executable(); is cmd on $PATH? 0/1
--   ≈  :echo executable("rg")   (like `command -v rg` in zsh)
local have_nope = vim.fn.executable("definitely-not-a-real-binary")
print("executable(nope) =", have_nope)

-- THE BUG:
if have_nope then
  print("BUG: this prints even though the answer was 'no' — 0 is truthy in Lua!")
end
-- THE FIX: always compare vim.fn results to 1 (or 0):
if have_nope == 1 then
  print("(never printed)")
else
  print("FIX: `== 1` gives the real answer: not executable")
end
-- Grep your config for `if vim.fn.` and check every hit for this.

------------------------------------------------------------ 5. Jobs: a mention, not a habit
-- vim.fn.jobstart({"cmd", ...}, {on_stdout = ...})  →  Vimscript jobstart();
--   runs a process async, callbacks receive output   (:help jobstart())
-- You'll see it in older plugins. For NEW code prefer vim.system()
-- (lesson 08): real Lua API, saner callbacks, sync `:wait()` mode.
-- Also in the same family: vim.fn.system("ls") returns output as one
-- string, blocking — like $(...) in zsh:
--   ≈  :echo system("ls")
print("fn.system:", vim.trim(vim.fn.system({ "echo", "hello from fn.system" })))
-- (vim.trim — lesson 08 — strips the trailing newline, like $(...) does.)

------------------------------------------------------------ 6. vim.fn vs vim.api vs plain Lua
-- Three toolboxes overlap. A decision recipe:
--
--   1. Plain Lua first (string.*, table.*, os.*): fastest, portable,
--      no editor involved. Formatting a string? Not vim.fn's job.
--   2. vim.api when a REAL API exists for the editor operation:
--      precise handles, real booleans, real errors. (Lesson 04.)
--   3. vim.fn when the Vimscript builtin is simply the best tool:
--      expand/fnamemodify have no api equivalent; getline is fine for
--      quick "current buffer" scripts.
--
-- Comparison of the same job, all three ways — count buffer lines:
print("plain-ish api:", vim.api.nvim_buf_line_count(0)) -- nvim_buf_line_count ≈ line("$")
print("vim.fn:       ", vim.fn.line("$")) -- vim.fn.line(".") / ("$")  ≈  :echo line("$")
-- (No pure-Lua way — line count is editor state, so vim.* it must be.)
--
-- Style note: vim.fn returns 1-indexed, current-buffer-centric answers
-- (Vim's world view); vim.api returns 0-indexed, handle-centric answers
-- (a programmer's world view). Mixing them is fine — just re-read the
-- indexing rules when you do.

------------------------------------------------------------ TRY IT
-- 1. Use vim.fn.fnamemodify + vim.fn.expand("~") to print the path of
--    your real init.lua, then check it exists with
--    vim.fn.filereadable(...) == 1  (filereadable ≈ test -r — and yes,
--    it returns 0/1, prove it with type()).
-- 2. Write is_executable(name) that wraps vim.fn.executable and returns
--    a REAL boolean. Test with "zsh" and "not-a-thing".
-- 3. Predict what vim.fn.getline(1, "$") returns when the buffer is
--    empty of your setline text — then :luafile this in a live nvim
--    session on a real file and compare.
-- 4. Look up :help expand() and find the <cword> special. What zsh
--    concept does %-expansion remind you of? (Hint: history expansion.)
