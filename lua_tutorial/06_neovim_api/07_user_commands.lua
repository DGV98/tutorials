----------------------------------------------------------------------
-- 07_user_commands.lua — your own :Commands
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • vim.api.nvim_create_user_command: define :Something
--   • nargs, and what arrives in opts.args / fargs / bang / range
--   • Tab-completion for your command's arguments (complete=)
--   • Two practical commands you could keep
--   • The :command Vimscript equivalents
-- HOW TO RUN
--   nvim --clean -l 07_user_commands.lua    (from this directory)
--   or inside nvim:  :luafile %
-- PREREQUISITES: 04_buffers_windows_api.lua, 06_autocommands.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. The smallest command
-- vim.api.nvim_create_user_command(name, handler, opts)
--   ≈  :command! -nargs=0 Hello lua print("hello")
--   (:help nvim_create_user_command())
-- Rule: user command names MUST start with an uppercase letter — that's
-- how Vim keeps them from colliding with builtins.
vim.api.nvim_create_user_command("Hello", function()
  print("Hello from your own :Hello command")
end, {})

-- Run it. vim.cmd("...") executes any ex-command from Lua (lesson 09):
--   ≈  typing :Hello in the cmdline
vim.cmd("Hello")

------------------------------------------------------------ 2. Arguments: nargs, args, fargs
-- nargs declares the arity, same values as Vimscript's -nargs=
--   0 (default) none | 1 exactly one | "?" zero or one
--   "*" any number   | "+" one or more
-- The handler receives ONE table (call it `opts`), with:
--   opts.args   the raw argument STRING, exactly as typed
--   opts.fargs  the arguments SPLIT into a Lua list ("f" = as if <f-args>)
--   ≈  :command! -nargs=* Greet echo <q-args>  (and <f-args> for the split form)
vim.api.nvim_create_user_command("Greet", function(opts)
  print("raw  opts.args :", vim.inspect(opts.args))
  print("list opts.fargs:", vim.inspect(opts.fargs))
  for _, name in ipairs(opts.fargs) do
    print("  hello,", name)
  end
end, { nargs = "*", desc = "Greet everyone named on the cmdline" })

vim.cmd("Greet Alice Bob") -- ≈ :Greet Alice Bob

------------------------------------------------------------ 3. bang and range
-- bang = true allows :Cmd! ; the handler sees opts.bang (a real boolean).
-- range = true allows :1,3Cmd ; the handler sees:
--   opts.range  how many range parts were given (0, 1 or 2)
--   opts.line1  start line   opts.line2  end line
--   ≈  :command! -bang -range Upper <line1>,<line2>call ...
vim.api.nvim_create_user_command("Upper", function(opts)
  if opts.range == 0 then
    print("Upper: no range given — try :%Upper or :1,2Upper")
    return
  end
  -- Convert Vim's 1-indexed inclusive range to the API's 0-indexed
  -- end-exclusive range (lesson 04's rule: subtract 1 from start only).
  local lines = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false) -- read range
  for i, l in ipairs(lines) do
    -- bang decides HOW MUCH to shout: ! upper-cases, plain capitalizes
    lines[i] = opts.bang and l:upper() or (l:gsub("^%l", string.upper))
  end
  vim.api.nvim_buf_set_lines(0, opts.line1 - 1, opts.line2, false, lines) -- write range back
  print(("Upper%s on lines %d-%d"):format(opts.bang and "!" or "", opts.line1, opts.line2))
end, { nargs = 0, bang = true, range = true, desc = "Capitalize (or ! SHOUT) the range" })

-- Give it something to chew on (lesson 04 API), then call it both ways:
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first line", "second line", "third line" })
vim.cmd("1,2Upper") -- ≈ :1,2Upper     capitalize lines 1-2
vim.cmd("%Upper!") -- ≈ :%Upper!      SHOUT the whole buffer (% = 1,$)
print("buffer now:", vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, false)))

------------------------------------------------------------ 4. Tab-completion: complete=
-- complete can be a builtin kind ("file", "buffer", "help", ... — see
-- :help :command-complete) or a Lua function returning candidates.
--   ≈  :command! -nargs=1 -complete=customlist,s:Candidates Theme ...
vim.api.nvim_create_user_command("Theme", function(opts)
  print("would switch theme to:", opts.args)
  -- In real config the body would be: vim.cmd.colorscheme(opts.args)  (lesson 09)
end, {
  nargs = 1,
  desc = "Pick a theme with tab-completion",
  complete = function(arglead, cmdline, cursorpos)
    -- arglead = the partial word being completed; filter with it.
    local themes = { "tokyonight-night", "tokyonight-storm", "default", "habamax" }
    -- vim.startswith(s, prefix) — utility belt, lesson 08; ≈ s:sub(1,#p)==p
    return vim.tbl_filter(function(t) return vim.startswith(t, arglead) end, themes)
    -- vim.tbl_filter(fn, list) — keep entries where fn returns true (lesson 08)
  end,
})
vim.cmd("Theme default") -- completion is interactive-only; calling still works

------------------------------------------------------------ 5. A practical keeper: :Scratch
-- Everything from lesson 04 in one useful command: open a scratch
-- buffer in a split, ready for notes/output. Steal this for your config.
vim.api.nvim_create_user_command("Scratch", function()
  local buf = vim.api.nvim_create_buf(false, true) -- scratch buffer (lesson 04); ≈ :new + :setlocal buftype=nofile
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "-- scratch --" }) -- seed it (lesson 04)
  -- In a UI session you'd show it:  vim.cmd.split() then
  -- vim.api.nvim_win_set_buf(0, buf)  ≈  :buffer {buf}
  -- Headless we just report:
  print("Scratch created buffer", buf, "— :buffer " .. buf .. " to visit it")
end, { desc = "Create a scratch buffer" })
vim.cmd("Scratch")

------------------------------------------------------------ 6. Housekeeping
-- vim.api.nvim_del_user_command(name)   ≈  :delcommand Hello
vim.api.nvim_del_user_command("Hello")
local ok, err = pcall(vim.cmd, "Hello") -- pcall: show the failure, still exit 0
print("after delcommand, :Hello fails:", ok, "->", tostring(err):match("E%d+[^\n]*"))
-- Buffer-local variant exists too: nvim_buf_create_user_command(buf, ...)
--   ≈  :command -buffer ...   (great inside FileType autocmds, lesson 06)
-- List what's defined:  :command   (no args = list all user commands)

------------------------------------------------------------ TRY IT
-- 1. Give :Greet a default — with nargs="*", make it greet "world" when
--    opts.fargs is empty (module 01's `or` idiom, or #fargs == 0).
-- 2. Add :Lower as the mirror of :Upper. Extract the shared range logic
--    into a local function both commands call (module 02 skills).
-- 3. Extend :Theme's completion list, then load this file in a LIVE
--    nvim (:luafile %) and type `:Theme tok<Tab>` to feel it work.
-- 4. Write :TodoAdd {text} — nargs="+", appends "- [ ] {text}" to the
--    END of the current buffer (nvim_buf_set_lines with -1,-1 — see
--    lesson 04 section 2). This is 80% of a todos.md plugin already.
