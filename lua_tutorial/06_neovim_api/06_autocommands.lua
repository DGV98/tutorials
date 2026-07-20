----------------------------------------------------------------------
-- 06_autocommands.lua — events, autocmds, and augroups
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • vim.api.nvim_create_autocmd: run code when the editor does things
--   • The events you'll actually use: BufWritePre, FileType, BufEnter,
--     LspAttach, VimEnter
--   • pattern vs buffer, callback vs command, once
--   • augroups with clear = true — and WHY (re-sourcing duplicates!)
--   • The :autocmd Vimscript equivalents throughout
-- HOW TO RUN
--   nvim --clean -l 06_autocommands.lua     (from this directory)
--   or inside nvim:  :luafile %
-- PREREQUISITES: 03_keymaps.lua, 04_buffers_windows_api.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. The idea
-- An autocommand is a hook: "when EVENT happens (matching PATTERN), run
-- THIS". It's the editor's equivalent of a Hyprland `bind = ...` or a
-- zsh precmd hook — declarative "when X, do Y" config.
-- Event catalog: :help autocmd-events (there are ~120; you need ~10).
--
-- The ones you'll actually use:
--   BufWritePre   just BEFORE saving a file    (format-on-save lives here)
--   BufWritePost  just AFTER saving            (linters, reloaders)
--   FileType      filetype was detected        (per-language settings/maps)
--   BufEnter      you switched into a buffer
--   LspAttach     an LSP client attached       (buffer-local LSP keymaps)
--   VimEnter      startup finished             (your ghostty+todos trick territory)

------------------------------------------------------------ 2. Augroups FIRST — because of re-sourcing
-- vim.api.nvim_create_augroup(name, { clear = true }) → group id
--   ≈  :augroup MyGroup | autocmd! | augroup END
-- WHY clear = true: every time this file is sourced (`:luafile %`, or
-- lazy.nvim reloading, or you re-running :so), nvim_create_autocmd adds
-- ANOTHER copy of each hook. Save once, format twice, then four times...
-- `clear = true` wipes the group's old autocmds first, so re-sourcing
-- replaces instead of accumulates. The `autocmd!` in the Vimscript
-- equivalent is the same medicine. ALWAYS group, always clear.
local group = vim.api.nvim_create_augroup("DavidLessons", { clear = true })

------------------------------------------------------------ 3. Anatomy: callback + pattern
-- vim.api.nvim_create_autocmd(event, opts) → autocmd id  (:help nvim_create_autocmd())
--   ≈  :autocmd DavidLessons FileType lua,markdown <do something>
vim.api.nvim_create_autocmd("FileType", {
  group = group, -- attach to our cleared group
  pattern = { "lua", "markdown" }, -- which filetypes; "*" = all  ≈ the :autocmd pattern slot
  desc = "Per-language indent", -- shows in :autocmd listings — always set it
  callback = function(ev)
    -- Every callback receives one table (:help event-args):
    --   ev.event = "FileType", ev.buf = buffer that triggered,
    --   ev.match = what matched the pattern (here: the filetype),
    --   ev.file  = filename.
    -- vim.bo[ev.buf] — buffer-local options for THE buffer that fired
    --   (lesson 02)  ≈  :setlocal shiftwidth=2
    vim.bo[ev.buf].shiftwidth = 2
    print(("FileType fired: match=%s buf=%d -> shiftwidth=2"):format(ev.match, ev.buf))
  end,
})

-- Trigger it for real, headless: setting the filetype option fires the
-- FileType event, exactly like opening a .lua file would.
-- vim.bo.filetype = "lua"   ≈  :setlocal filetype=lua  (fires FileType!)
vim.bo.filetype = "lua"
print("shiftwidth after FileType:", vim.bo.shiftwidth)

------------------------------------------------------------ 4. pattern vs buffer
-- pattern matches names (file globs like "*.lua", or filetype names for
-- FileType, etc.). `buffer` pins the autocmd to ONE buffer instead —
-- you cannot use both at once.
--   pattern = "*.lua"    ≈  :autocmd BufWritePre *.lua ...
--   buffer  = 0          ≈  :autocmd BufWritePre <buffer> ...
-- Buffer-local autocmds are the natural partner of buffer-local keymaps:
-- inside LspAttach you get ev.buf, and everything you create should be
-- scoped to it. Sketch of the standard block from real configs:
--
--   vim.api.nvim_create_autocmd("LspAttach", {
--     group = group,
--     callback = function(ev)
--       vim.keymap.set("n", "K", vim.lsp.buf.hover, { buffer = ev.buf })
--       -- more LSP maps, all { buffer = ev.buf } ...
--     end,
--   })
-- (Comment-only: no LSP server under --clean, so nothing would fire.)

------------------------------------------------------------ 5. callback vs command
-- Instead of a Lua callback you may hand over an EX-COMMAND string —
-- that's the literal payload a Vimscript :autocmd would run:
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "LessonDemo",
  desc = "command= demo",
  command = "echomsg 'ran as an ex-command'", -- ≈ the rhs of a classic :autocmd
})
-- Use callback for Lua (almost always); command when porting a one-liner.

-- The "User" event is a freebie namespace for YOUR OWN events — plugins
-- fire e.g. `User LazyDone`. You can listen for and fire them yourself:
-- vim.api.nvim_exec_autocmds(event, opts) fires autocmds by hand
--   ≈  :doautocmd User LessonDemo
vim.api.nvim_exec_autocmds("User", { pattern = "LessonDemo" })

------------------------------------------------------------ 6. once, and a real BufWritePre shape
-- once = true: run a single time, then self-delete.  ≈  :autocmd ... ++once
local boot_count = 0
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "Boot",
  once = true, -- ≈ ++once
  callback = function() boot_count = boot_count + 1 end,
})
vim.api.nvim_exec_autocmds("User", { pattern = "Boot" }) -- ≈ :doautocmd User Boot
vim.api.nvim_exec_autocmds("User", { pattern = "Boot" }) -- second firing: nobody listens
print("once-handler ran", boot_count, "time(s) despite 2 firings")

-- The classic format-on-save shape (works verbatim in your config):
--   ≈  :autocmd DavidLessons BufWritePre *.lua lua trim_trailing()
vim.api.nvim_create_autocmd("BufWritePre", {
  group = group,
  pattern = "*.lua",
  desc = "Trim trailing whitespace before save",
  callback = function(ev)
    -- Read all lines, strip trailing blanks, write back (lesson 04 API):
    local lines = vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false) -- read buffer (0-indexed)
    for i, line in ipairs(lines) do
      lines[i] = line:gsub("%s+$", "") -- plain Lua does the string work
    end
    vim.api.nvim_buf_set_lines(ev.buf, 0, -1, false, lines) -- write buffer back
    print("BufWritePre: trimmed", #lines, "lines")
  end,
})

-- Prove it works without writing any real file: put whitespace-damaged
-- text in the current (memory-only) buffer and fire the event manually.
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "clean line", "trailing spaces   " }) -- (lesson 04)
vim.api.nvim_exec_autocmds("BufWritePre", { pattern = "*.lua" }) -- ≈ :doautocmd BufWritePre *.lua
print("line 2 is now:", vim.inspect(vim.api.nvim_buf_get_lines(0, 1, 2, false)[1]))

------------------------------------------------------------ 7. Listing and deleting
-- vim.api.nvim_get_autocmds({ group = "DavidLessons" }) → table of specs
--   ≈  :autocmd DavidLessons   (the listing command)
print("autocmds now in group:", #vim.api.nvim_get_autocmds({ group = "DavidLessons" }))
-- Why 4? The FileType one counts TWICE (a list pattern registers one
-- autocmd per pattern), plus User LessonDemo and BufWritePre. The once=
-- handler from section 6 already deleted itself after firing.
-- Also: nvim_del_autocmd(id) deletes one (create returns the id);
-- nvim_clear_autocmds({group=...}) is `clear = true` on demand.
--   ≈  :autocmd! DavidLessons

------------------------------------------------------------ TRY IT
-- 1. Add a BufEnter autocmd (pattern "*") to the group that prints
--    ev.file, then fire it with nvim_exec_autocmds and watch the arg.
-- 2. Comment out `clear = true`, run this file's logic twice by
--    duplicating the BufWritePre block, and fire BufWritePre — count
--    how many times it trims. Now you've SEEN the duplicate bug.
-- 3. Rewrite the command= autocmd from section 5 as a callback that
--    calls vim.notify instead of echomsg.
-- 4. In your real config: find where lazy.nvim runs setup and add a
--    `User VeryLazy` listener that prints "plugins done". (Look up
--    :help User first to see why plugins love this event.)
