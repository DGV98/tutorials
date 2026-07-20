----------------------------------------------------------------------
-- solutions.lua — Module 06: The vim.* API — solutions
----------------------------------------------------------------------
-- Complete, runnable solutions to exercises.lua. Each block starts with
-- the KEY INSIGHT the exercise was built around. Peek only after trying.
-- HOW TO RUN
--   nvim --clean -l solutions.lua           (from this directory)
--   or inside nvim:  :luafile %
----------------------------------------------------------------------

-- <leader> expands at definition time, so the leader comes first (lesson 03):
vim.g.mapleader = " " --  ≈  :let g:mapleader = " "

------------------------------------------------------------ EXERCISE 1: options two ways
-- KEY INSIGHT: vim.o for single values, vim.opt for list-shaped options —
-- both are doors to the same option (lesson 02's rule of thumb).
vim.o.scrolloff = 8 --  ≈  :set scrolloff=8
vim.opt.path:append("**") --  ≈  :set path+=**   (makes :find recurse)

print("E1 scrolloff:", vim.o.scrolloff) -- vim.o read-back  ≈  :echo &scrolloff
print("E1 path:", vim.inspect(vim.opt.path:get())) -- :get() → natural Lua list (lesson 02); vim.inspect → readable string (lesson 01)

------------------------------------------------------------ EXERCISE 2: real booleans from vim.fn
-- KEY INSIGHT: vim.fn results cross the bridge as 0/1 NUMBERS, and 0 is
-- truthy in Lua. `== 1` is the whole fix (lesson 05, section 4).
local function is_executable(name)
  return vim.fn.executable(name) == 1 -- vim.fn.executable: on $PATH? 0/1  ≈  :echo executable(name)
end

print("E2 sh:  ", is_executable("sh")) --> true
print("E2 nope:", is_executable("definitely-not-a-binary")) --> false
assert(is_executable("sh") == true, "must be a REAL boolean") -- proves it's not the number 1

------------------------------------------------------------ EXERCISE 3: a toggling keymap
-- KEY INSIGHT: a Lua-function rhs is passed WITHOUT parens — the mapping
-- stores the function and calls it on keypress (lesson 03's fn vs fn()).
local function toggle_number()
  vim.wo.number = not vim.wo.number --  ≈  :setlocal number!  (window-local, lesson 02)
end

-- vim.keymap.set("n", ...)  ≈  :nnoremap <leader>n ...  (Lua fn rhs — no parens!)
vim.keymap.set("n", "<leader>n", toggle_number, { desc = "Toggle line numbers" })

local info = vim.fn.maparg("<leader>n", "n", false, true) -- ≈ Vimscript maparg(...) → dict about the mapping
print("E3 desc:", info.desc)
print("E3 before:", vim.wo.number) -- vim.wo read-back (lesson 02)
toggle_number() -- calling it directly works too — it's just a function
print("E3 after: ", vim.wo.number)

------------------------------------------------------------ EXERCISE 4: buffer surgery
-- KEY INSIGHT: (0, -1) spans the whole buffer; the API range is
-- 0-indexed and end-exclusive, but the RESULT is a normal 1-indexed Lua
-- list — so ipairs gives you the human line number for free (lesson 04).
local function number_lines(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false) -- read all lines  ≈  getline(1, "$")
  for i, l in ipairs(lines) do
    lines[i] = ("%d: %s"):format(i, l) -- plain Lua does the string work
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines) -- write all back  ≈  setline(1, [...])
end

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha", "bravo", "charlie" }) -- seed  ≈  :%d + setline (lesson 04)
number_lines(0) -- 0 = current buffer, the vim.api convention
print("E4 buffer:", vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, false))) -- read back  ≈  getline(1,"$")

------------------------------------------------------------ EXERCISE 5: augroups & the re-source bug
-- KEY INSIGHT: clear = true wipes the group's OLD autocmds each time the
-- file is sourced — re-sourcing REPLACES instead of ACCUMULATES. Without
-- it, the second install adds a duplicate and pings would reach 3.
local pings = 0
local function install_counter()
  -- vim.api.nvim_create_augroup(name, {clear=true})  ≈  :augroup Ex5 | autocmd! | augroup END
  local grp = vim.api.nvim_create_augroup("Ex5", { clear = true })
  -- vim.api.nvim_create_autocmd("User", ...)  ≈  :autocmd Ex5 User Ping <increment>
  vim.api.nvim_create_autocmd("User", {
    group = grp,
    pattern = "Ping",
    desc = "count pings",
    callback = function() pings = pings + 1 end,
  })
end

install_counter() -- first source
vim.api.nvim_exec_autocmds("User", { pattern = "Ping" }) -- fire by hand  ≈  :doautocmd User Ping
install_counter() -- the "re-source": clear=true removed the old handler first
vim.api.nvim_exec_autocmds("User", { pattern = "Ping" }) -- ≈  :doautocmd User Ping
print("E5 pings:", pings, "(2 = correct; without clear = true it would be 3)")

------------------------------------------------------------ EXERCISE 6: the :Stamp user command
-- KEY INSIGHT: with nargs="?" a missing argument arrives as "" (empty
-- string), so `~= "" and ... or ...` supplies the default. And opts.bang
-- is a REAL boolean — the api layer, unlike vim.fn, never does 0/1.
-- vim.api.nvim_create_user_command  ≈  :command! -nargs=? -bang Stamp ...
vim.api.nvim_create_user_command("Stamp", function(opts)
  local text = opts.args ~= "" and opts.args or os.date("%Y-%m-%d")
  local line = ("== %s =="):format(text)
  if opts.bang then line = line:upper() end -- :Stamp! shouts
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { line }) -- (-1,-1) appends at end  ≈  :call append("$", line)
end, { nargs = "?", bang = true, desc = "Append a stamp line to the buffer" })

vim.cmd("Stamp release notes") -- vim.cmd runs an ex-command  ≈  typing :Stamp release notes
vim.cmd("Stamp!") -- ≈  :Stamp!   (no arg → dated, bang → upper-cased)
print("E6 tail:", vim.inspect(vim.api.nvim_buf_get_lines(0, -3, -1, false))) -- last two lines (negative = from end)

------------------------------------------------------------ EXERCISE 7: the utility belt on Hyprland data
-- KEY INSIGHT: vim.iter chains read like a shell pipeline —
-- split | filter | map | collect — one pass, no temporary tables.
local spec = "eDP-1@60,DP-1@60,DP-4@180,DP-3@180,HDMI-A-1@60"

local fast = vim.iter(vim.split(spec, ",")) -- vim.split: string → list (lesson 08)  ≈  Vimscript split()
  :filter(function(m) return vim.endswith(m, "@180") end) -- vim.endswith: real-boolean suffix test (lesson 08)
  :map(function(m) return vim.split(m, "@")[1] end) -- keep the name before the "@"
  :totable()
print("E7 fast monitors:", vim.inspect(fast)) --> { "DP-4", "DP-3" }

-- KEY INSIGHT (b): DEEP extend merges nested tables key-by-key; plain
-- vim.tbl_extend would replace `decoration` wholesale and lose rounding.
local defaults = { decoration = { rounding = 10, blur = true }, gaps = 3 }
local override = { decoration = { blur = false } }
-- vim.tbl_deep_extend("force", ...): recursive merge, later tables win (lesson 08)
local merged = vim.tbl_deep_extend("force", defaults, override)
print("E7 merged:", vim.inspect(merged)) --> rounding=10 kept, blur=false, gaps=3

------------------------------------------------------------ EXERCISE 8: translate a vimrc — the stinger
-- KEY INSIGHT: every vimrc line maps to one recipe step (lesson 09,
-- section 5) — and the verification itself re-uses half the module:
-- maparg's dict fields are 0/1 (trap!), nvim_get_hl returns numbers.

-- 1. set wildignore+=*.tmp            → recipe step 1: vim.opt
vim.opt.wildignore:append("*.tmp") --  ≈  :set wildignore+=*.tmp

-- 2. nnoremap <silent> <leader>x :bdelete<CR>   → step 2: vim.keymap.set
--    A string rhs stays a string — defining it is safe; nothing presses it here.
vim.keymap.set("n", "<leader>x", ":bdelete<CR>", { silent = true, desc = "Delete buffer" })
--  ≈  :nnoremap <silent> <leader>x :bdelete<CR>

-- 3. autocmd FileType markdown setlocal wrap    → step 3: autocmd + augroup
local grp8 = vim.api.nvim_create_augroup("Ex8", { clear = true }) --  ≈  :augroup Ex8 | autocmd! | augroup END
vim.api.nvim_create_autocmd("FileType", { --  ≈  :autocmd Ex8 FileType markdown setlocal wrap
  group = grp8,
  pattern = "markdown",
  desc = "wrap prose",
  callback = function()
    vim.wo.wrap = true --  ≈  :setlocal wrap  ('wrap' is window-local)
  end,
})
vim.wo.wrap = false -- known starting state  ≈  :setlocal nowrap
vim.bo.filetype = "markdown" -- setting 'filetype' FIRES FileType (lesson 06 trick)  ≈  :setlocal filetype=markdown

-- 4. highlight Comment guifg=#888888   → step 7: nvim_set_hl
-- Remember lesson 09's trap: this REPLACES the whole group definition.
vim.api.nvim_set_hl(0, "Comment", { fg = "#888888" }) --  ≈  :highlight Comment guifg=#888888

-- The checks:
print("E8.1:", vim.tbl_contains(vim.opt.wildignore:get(), "*.tmp")) -- vim.tbl_contains: real boolean (lesson 08)
local m = vim.fn.maparg("<leader>x", "n", false, true) -- ≈ maparg() → dict; its fields are 0/1, NOT booleans
print("E8.2:", m.silent == 1 and m.noremap == 1) -- the vim.fn 0/1 trap, one last time
print("E8.3:", vim.wo.wrap) -- the autocmd fired and set it  ≈  :echo &wrap
local hl = vim.api.nvim_get_hl(0, { name = "Comment" }) -- read a highlight group back  ≈  :hi Comment (listing)
print("E8.4:", hl.fg == 0x888888) -- colors come back as NUMBERS; 0x888888 == 8947848

print("\nAll solutions ran. Diff them against your exercises.lua attempts.")
