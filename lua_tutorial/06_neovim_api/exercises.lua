----------------------------------------------------------------------
-- exercises.lua — Module 06: The vim.* API — exercises
----------------------------------------------------------------------
-- HOW TO WORK
--   Each EXERCISE block has TODO markers. Fill them in, then uncomment
--   the CHECK lines and re-run until every check reports what it wants.
--   This file runs clean AS-IS — your job is to make it actually work.
-- HOW TO RUN
--   nvim --clean -l exercises.lua           (from this directory)
--   or inside nvim:  :luafile %
-- PREREQUISITES: lessons 01–09 of this module (each exercise names its
--   lesson). Difficulty ramps up; exercise 8 is the capstone.
----------------------------------------------------------------------

-- The <leader> mappings below need this set FIRST (lesson 03, section 4:
-- <leader> is expanded when the mapping is DEFINED, not when pressed):
vim.g.mapleader = " " --  ≈  :let g:mapleader = " "

------------------------------------------------------------ EXERCISE 1: options two ways (lesson 02)
-- a) Set scrolloff to 8 the vim.o way — and write its :set equivalent
--    in a comment next to it (this module's house rule).
-- b) Append "**" to the 'path' option the vim.opt way (this is what
--    makes :find search recursively).
-- c) The CHECK lines read both back to prove the writes took.

-- TODO a: vim.o....
-- TODO b: vim.opt....:append(...)

-- CHECK (uncomment when done):
-- print("E1 scrolloff:", vim.o.scrolloff) -- vim.o read-back  ≈ :echo &scrolloff — expect 8
-- print("E1 path:", vim.inspect(vim.opt.path:get())) -- :get() → Lua list — expect "**" inside
print("EXERCISE 1: options — fill in the TODOs above")

------------------------------------------------------------ EXERCISE 2: real booleans from vim.fn (lesson 05)
-- vim.fn.executable() answers 0 or 1 — and 0 is TRUTHY in Lua.
-- Make is_executable(name) return a REAL Lua boolean.
local function is_executable(name)
  -- TODO: wrap vim.fn.executable(name)   ≈  :echo executable(name)  (returns 0/1!)
  return false -- placeholder so the file runs as-is; replace it
end

-- CHECK (uncomment when done):
-- print("E2 sh:  ", is_executable("sh")) -- expect true
-- print("E2 nope:", is_executable("definitely-not-a-binary")) -- expect false
-- assert(is_executable("sh") == true, "E2: must be a REAL boolean, not 1")
print("EXERCISE 2: is_executable —", is_executable("sh") == true and "looks done" or "TODO")

------------------------------------------------------------ EXERCISE 3: a toggling keymap (lesson 03)
-- Map <leader>n (normal mode) to a Lua function that toggles line
-- numbers for the current window (vim.wo.number), with a desc.
-- Remember the fn vs fn() bug: pass the FUNCTION, don't call it!
local function toggle_number()
  -- TODO: flip vim.wo.number   ≈  :setlocal number!  (window-local, lesson 02)
end

-- TODO: vim.keymap.set(...)   ≈  :nnoremap <leader>n ...  (Lua fn rhs, no parens!)

-- CHECK (uncomment when done):
-- local info = vim.fn.maparg("<leader>n", "n", false, true) -- ≈ Vimscript maparg() → dict
-- print("E3 desc:", info.desc) -- expect the desc you wrote
-- print("E3 before:", vim.wo.number); toggle_number(); print("E3 after:", vim.wo.number)
print("EXERCISE 3: keymap toggle — fill in the TODOs above")

------------------------------------------------------------ EXERCISE 4: buffer surgery (lesson 04)
-- Write number_lines(buf): read ALL lines of `buf`, prefix each with
-- "N: " (its 1-based line number), and write them back.
-- Remember lesson 04's rule: nvim_buf_get_lines/set_lines are 0-indexed
-- and end-exclusive, and (0, -1) means "the whole buffer".
local function number_lines(buf)
  -- TODO: vim.api.nvim_buf_get_lines → transform → vim.api.nvim_buf_set_lines
end

-- Scaffolding: seed the current buffer so there is something to number.
-- vim.api.nvim_buf_set_lines(0, 0, -1, false, {...}) replaces the whole
-- buffer  ≈  :%delete + :call setline(1, [...])
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "bravo", "charlie" })
number_lines(0) -- safe to call while it's still empty (does nothing yet)
-- vim.api.nvim_buf_get_lines(0, 0, -1, false) reads it back  ≈  getline(1, "$")
-- vim.inspect: any Lua value → readable string (lesson 01; no ex-command twin)
print("EXERCISE 4 buffer now:", vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, false)))
-- expect: { "1: alpha", "2: bravo", "3: charlie" }

------------------------------------------------------------ EXERCISE 5: augroups & the re-source bug (lesson 06)
-- Write install_counter(): create augroup "Ex5" WITH clear = true, and
-- inside it an autocmd on the User event, pattern "Ping", whose callback
-- does `pings = pings + 1`. The scaffolding simulates re-sourcing your
-- config — exactly what :luafile % or a plugin reload does.
local pings = 0
local function install_counter()
  -- TODO: vim.api.nvim_create_augroup("Ex5", { clear = true })
  --         ≈  :augroup Ex5 | autocmd! | augroup END
  -- TODO: vim.api.nvim_create_autocmd("User", { group=..., pattern="Ping", callback=... })
  --         ≈  :autocmd Ex5 User Ping <increment>
end

install_counter() -- first source
-- vim.api.nvim_exec_autocmds fires autocmds by hand  ≈  :doautocmd User Ping
-- (uncomment the two exec lines once install_counter is written)
-- vim.api.nvim_exec_autocmds("User", { pattern = "Ping" })
install_counter() -- the "re-source"
-- vim.api.nvim_exec_autocmds("User", { pattern = "Ping" })
print("EXERCISE 5 pings:", pings, "(want 2 — if you see 3, you forgot clear = true)")

------------------------------------------------------------ EXERCISE 6: the :Stamp user command (lesson 07)
-- Create :Stamp — appends "== <text> ==" as the LAST line of the
-- current buffer. Requirements:
--   • nargs = "?"  — with no argument, use today's date: os.date("%Y-%m-%d")
--     (hint: a missing arg arrives as the EMPTY STRING, not nil)
--   • bang = true  — :Stamp! upper-cases the whole stamp line
--   • give it a desc
-- Appending hint: nvim_buf_set_lines(0, -1, -1, false, { line }).
--
-- TODO: vim.api.nvim_create_user_command("Stamp", function(opts) ... end, {...})
--         ≈  :command! -nargs=? -bang Stamp ...

-- CHECK (uncomment when done):
-- vim.cmd("Stamp release notes") -- vim.cmd runs an ex-command  ≈ typing :Stamp release notes
-- vim.cmd("Stamp!") -- ≈ :Stamp!   (dated AND shouted)
-- print("E6 tail:", vim.inspect(vim.api.nvim_buf_get_lines(0, -3, -1, false))) -- last two lines
print("EXERCISE 6: :Stamp — fill in the TODO above")

------------------------------------------------------------ EXERCISE 7: the utility belt on Hyprland data (lesson 08)
-- Your hyprland.conf runs monitors at different refresh rates. Given:
local spec = "eDP-1@60,DP-1@60,DP-4@180,DP-3@180,HDMI-A-1@60"
-- a) Produce { "DP-4", "DP-3" } — the names running at 180Hz — using
--    ONLY vim.split + a vim.iter chain (:filter, :map, :totable).
--    No for-loops! (vim.endswith is your friend.)
local fast = {} -- TODO: replace {} with the chain
print("EXERCISE 7 fast monitors:", vim.inspect(fast))
-- expect: { "DP-4", "DP-3" }

-- b) Merge these two config layers so the override wins but
--    defaults.decoration.rounding SURVIVES — one call does it:
local defaults = { decoration = { rounding = 10, blur = true }, gaps = 3 }
local override = { decoration = { blur = false } }
local merged = {} -- TODO: vim.tbl_deep_extend("force", ...)
print("EXERCISE 7 merged:", vim.inspect(merged))
-- expect: rounding = 10 kept, blur = false, gaps = 3

------------------------------------------------------------ EXERCISE 8: translate a vimrc (lessons 02/03/06/09) — the stinger
-- Four lines from a classic vimrc. Translate EACH to Lua WITHOUT using
-- vim.cmd, then make every CHECK print true.
--
--   1. set wildignore+=*.tmp
--   2. nnoremap <silent> <leader>x :bdelete<CR>
--   3. autocmd FileType markdown setlocal wrap
--   4. highlight Comment guifg=#888888
--
-- Hints: 1 → lesson 02 (:append). 2 → lesson 03 (a string rhs is fine;
-- you define it, you never press it). 3 → lesson 06 (augroup + clear;
-- fire it headlessly by setting vim.bo.filetype). 4 → lesson 09
-- (nvim_set_hl replaces the WHOLE group; nvim_get_hl returns fg as a
-- NUMBER — compare against 0x888888).

-- TODO 1:
-- TODO 2:
-- TODO 3 (augroup first!):
vim.wo.wrap = false -- start from a known state  ≈  :setlocal nowrap
-- TODO: fire your FileType autocmd (set the filetype)
-- TODO 4:

-- CHECKS (uncomment as you go — each should print true):
-- print("E8.1:", vim.tbl_contains(vim.opt.wildignore:get(), "*.tmp")) -- vim.tbl_contains: real boolean
-- local m = vim.fn.maparg("<leader>x", "n", false, true) -- ≈ maparg() → dict (fields are 0/1!)
-- print("E8.2:", m.silent == 1 and m.noremap == 1) -- the 0/1 trap again: compare to 1
-- print("E8.3:", vim.wo.wrap) -- ≈ :echo &wrap — did your autocmd fire?
-- print("E8.4:", vim.api.nvim_get_hl(0, { name = "Comment" }).fg == 0x888888) -- ≈ :hi Comment (fg is a number)
print("EXERCISE 8: the vimrc translation — the module capstone")

print("\nAll exercises loaded. Solve, uncomment CHECKs, re-run. Answers in solutions.lua.")
