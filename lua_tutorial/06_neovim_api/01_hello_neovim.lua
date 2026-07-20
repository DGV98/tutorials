----------------------------------------------------------------------
-- 01_hello_neovim.lua — Running Lua inside Neovim
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • The four ways to run Lua in nvim: :lua, :luafile %, :=, nvim -l
--   • print vs vim.print, and vim.inspect for tables
--   • Where output actually goes (:messages)
--   • A first tour of the global `vim` table — the map for this module
-- HOW TO RUN
--   nvim --clean -l 01_hello_neovim.lua     (from this directory)
--   or inside nvim:  :luafile %             (with this file open)
-- PREREQUISITES: modules 01–05 (pure Lua). From here on, Lua runs
--   INSIDE Neovim — `luajit file.lua` will no longer work, because the
--   global `vim` table only exists when Neovim is the host.
----------------------------------------------------------------------

------------------------------------------------------------ 1. Where you are
-- When Neovim starts, it embeds a LuaJIT interpreter (the same 5.1
-- semantics you learned in modules 01–05) and injects ONE global: `vim`.
-- Everything Neovim can do is reachable through that table. Think of it
-- like `$PATH` for the editor: one entry point, everything hangs off it.

-- type() is plain Lua — `vim` is just a table (with some clever metatables).
print("type of vim:", type(vim)) --> table

-- vim.version() returns a table describing the running Neovim.
--   ≈  :version   (the ex-command that prints version info)
local v = vim.version()
print(("Neovim %d.%d.%d says hello"):format(v.major, v.minor, v.patch))

------------------------------------------------------------ 2. The four ways to run Lua
-- You are running this file with `nvim --clean -l <file>`: headless
-- script mode. `--clean` skips your init.lua; `-l` runs the file and
-- exits. It's the `lua script.lua` of the Neovim world — great for
-- testing config snippets without touching your real session.
--
-- Inside a real nvim session you have three more (try them later):
--
--   :lua print("hi")          -- run one line of Lua       ≈ :call for Vimscript
--   :lua =1 + 1               -- `=expr` pretty-prints the expression's value
--   := 1 + 1                  -- shorthand for :lua =       (:help :=)
--   :luafile %                -- run the CURRENT FILE       ≈ :source % for Vimscript
--   :source %                 -- also works: nvim sources .lua natively (:help :source)
--
-- `:= vim.opt.number` style one-liners are how you'll poke at your
-- config interactively. Get `:=` into your fingers early.

print("running under -l, so this line goes straight to your terminal")

------------------------------------------------------------ 3. Where output goes
-- Plain print() inside an interactive nvim session does NOT print to a
-- terminal — it lands in the message area (the line at the bottom) and
-- is recorded in the message history. When it scrolls away:
--
--   :messages                 -- show the message history  (:help :messages)
--
-- Under `nvim -l` (like right now), print() ALSO writes to stdout, so
-- scripts behave like normal command-line programs. Both are true at
-- once: the lines you see in the terminal are in :messages too.

-- vim.fn.execute() runs an ex-command and RETURNS its output as a string.
--   ≈  :echo execute("messages")   (Vimscript builtin execute())
local history = vim.fn.execute("messages")
print("messages history so far contains", #vim.split(history, "\n"), "lines")
-- (vim.split is covered in 08_vim_utilities.lua — it splits a string into a table.)

------------------------------------------------------------ 4. print vs vim.print vs vim.inspect
-- print() on a table gives you the useless address you met in module 04:
local opts = { number = true, shiftwidth = 4, langs = { "lua", "bash" } }
print("plain print:", opts) --> table: 0x...

-- vim.inspect(value) returns a STRING: human-readable Lua-ish source for
-- any value, nested tables included. No Vimscript equivalent — this is
-- pure Lua convenience shipped with Neovim.  (:help vim.inspect())
print("vim.inspect:\n" .. vim.inspect(opts))

-- vim.print(...) = print(vim.inspect(x)) for each argument, and it
-- RETURNS its arguments, so you can wrap it around any expression
-- mid-pipeline without breaking the code.  (:help vim.print())
--   ≈  :echo x  (Vimscript :echo pretty-prints lists/dicts natively;
--      vim.print is the Lua-side equivalent of that convenience)
local sw = vim.print(opts).shiftwidth -- prints the table AND lets you keep using it
print("still got shiftwidth back:", sw)

-- Debugging workflow you'll use forever:
--   := some_table            -- in a live session
--   vim.print(some_table)    -- in a script or config file

------------------------------------------------------------ 5. A map of the vim table
-- The rest of this module is a guided tour of these neighborhoods:
--
--   vim.o / vim.opt / vim.bo / vim.wo   options            (02_options.lua)
--   vim.keymap                          mappings           (03_keymaps.lua)
--   vim.api                             raw editor API     (04_buffers_windows_api.lua)
--   vim.fn                              Vimscript builtins (05_vim_fn_bridge.lua)
--   autocmds & user commands            (06_..., 07_...)
--   vim.tbl_* / vim.iter / vim.system   utility belt       (08_vim_utilities.lua)
--   vim.cmd / vim.g / vim.v             glue & variables   (09_vim_cmd_and_g.lua)

-- Prove they exist right now, using plain Lua over the vim table:
for _, name in ipairs({ "api", "fn", "opt", "keymap", "cmd", "g", "uv" }) do
  print(("vim.%-6s -> %s"):format(name, type(vim[name])))
end

-- The single most useful help tag in Neovim:
--   :help lua-guide      -- the official "Lua for config" walkthrough
--   :help vim.print()    -- yes, help tags exist for Lua functions too
-- Reading :help from inside nvim is a skill this course builds — every
-- lesson from here on names the tags to look up.

------------------------------------------------------------ TRY IT
-- 1. Open this file in nvim (`nvim 01_hello_neovim.lua`) and run it with
--    :luafile % — then run :messages and find the output again.
-- 2. In the same session, run `:= vim.version()` and compare it with
--    `:lua print(vim.version())`. Which one is readable, and why?
-- 3. Add a nested table (a table inside a table inside a table) to
--    `opts` above and re-run the file. Does vim.inspect stay readable?
-- 4. Run `:help lua-guide` and skim the first screen. Find the section
--    about :lua — it documents the `=` trick from section 2.
