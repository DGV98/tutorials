----------------------------------------------------------------------
-- 03_common_errors.lua — The five errors your config will actually throw
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • How to READ a Lua error: every part of the message means something
--   • The five classics: index nil, index field, call nil,
--     module not found, concatenate nil
--   • For each: the 3 most likely causes in a Neovim config, and the fix
-- HOW TO RUN
--   nvim --clean -l 03_common_errors.lua      (from this directory)
--   or inside nvim:  :luafile %
-- PREREQUISITES: 02_debugging_toolkit.lua
----------------------------------------------------------------------
-- Every error here is reproduced FOR REAL, caught with pcall so the file
-- still exits 0, and then dissected. When one of these hits you at startup,
-- come back to the matching section.

-- Tiny helper: run a buggy function, show the caught message.
local function show(label, buggy)
  -- pcall  →  protected call: returns ok, err instead of exploding
  local ok, err = pcall(buggy)
  print(label .. (ok and "  (no error?!)" or ""))
  print("   → " .. tostring(err))
end

------------------------------------------------------------ 1. attempt to index a nil value
show("1. attempt to index local 'x' (a nil value)", function()
  local x -- declared, never assigned: x is nil
  return x.y -- "indexing" = using . or [] on it
end)
-- ANATOMY:  03_common_errors.lua:31: attempt to index local 'x' (a nil value)
--   file:line     → where it blew up (lesson 02 §9: gF jumps there)
--   "index"       → you did x.something or x[something]
--   "local 'x'"   → Lua NAMES the variable — read this part first!
--   "a nil value" → x held nil at that moment
-- TOP 3 CAUSES IN A CONFIG:
--   a) require("foo") returned nil-ish because the module file forgot
--      `return M` at the bottom (then foo is `true`, and foo.setup errors
--      with "index ... (a boolean value)" — same family).
--   b) An API call that can return nil: vim.fn.getenv, nvim_get_current_buf
--      wrappers, table lookups like servers[name].
--   c) A typo'd LOCAL name — you assigned `telescop` and indexed `telescope`.
-- FIX: find the named variable, ask "why is it nil HERE?", then either fix
-- the assignment or guard:  if x then ... end  /  local y = x and x.y

------------------------------------------------------------ 2. attempt to index field 'y' (a nil value)
show("2. attempt to index field 'window' (a nil value)", function()
  local config = { picker = { theme = "dropdown" } }
  -- We reach for config.window.width — but there IS no 'window' key.
  return config.window.width
end)
-- ANATOMY: "field 'window'" — subtly different from case 1! Lua indexed
--   config fine, got nil for the FIELD named 'window', then tried to index
--   THAT nil. So: everything left of the named field existed; the named
--   field itself is the hole. In a.b.c.d chains, the message names exactly
--   which link broke — read it like a stack of Russian dolls.
-- TOP 3 CAUSES IN A CONFIG:
--   a) Copy-pasted plugin options from a README of a DIFFERENT version —
--      the option tree moved (e.g. defaults.layout_config vs defaults.layout).
--   b) Assuming setup() created nested defaults before you merged yours.
--   c) Plain misspelling of the middle key: confg, keymaps vs keymap.
-- FIX: vim.print(config) right before the line (lesson 02 §2) and LOOK at
-- what's really in the table; or use vim.tbl_get which returns nil safely:
-- vim.tbl_get(t, "a", "b")  →  t.a.b or nil, no error. :help vim.tbl_get()
local config = { picker = { theme = "dropdown" } }
print("   safe version:", tostring(vim.tbl_get(config, "window", "width")))

------------------------------------------------------------ 3. attempt to call a nil value
show("3. attempt to call field 'sett' (a nil value)", function()
  -- vim.keymap.set exists; vim.keymap.sett does not. Typo = nil, then "()".
  vim.keymap.sett("n", "<leader>x", ":echo 1<CR>")
end)
-- ANATOMY: "call" — you put () after something that held nil.
--   "field 'sett'" → the nil came out of a table lookup (vim.keymap.sett);
--   for a bare name you'd see "global 'sett'" or "local 'sett'" instead.
--   ("global" in that spot is often ITSELF the clue: you forgot `local`
--   somewhere, or typo'd a local so Lua fell back to reading _G.)
-- TOP 3 CAUSES IN A CONFIG:
--   a) Typo'd API name: nvim_craete_autocmd, vim.keymap.sett, tbl_deep_extned.
--   b) Renamed/removed plugin function after an update (setup vs init).
--   c) Deprecated & deleted API: vim.loop.fs_stat in new code → use vim.uv;
--      vim.highlight → vim.hl. Old blog posts are full of these.
-- FIX: inside nvim, `:=vim.keymap` (lesson 02 §3) prints the table — you'll
-- SEE the real function names. Or :help vim.keymap.set() for the signature.

------------------------------------------------------------ 4. module 'plugins.foo' not found
show("4. module 'plugins.foo' not found", function()
  -- No lua/plugins/foo.lua anywhere on runtimepath or package.path:
  require("plugins.foo")
end)
-- ANATOMY: this error is a TRACE of every place require looked (module 04 +
-- lesson 01 §3). Reading a few lines of it:
--   no field package.preload['plugins.foo'] → not preloaded in-memory
--   no file './plugins/foo.lua'             → package.path entries, one per line
--   no file '/usr/share/lua/5.1/...'        → more package.path
-- In your REAL config (lazy.nvim enables vim.loader) you'll also see:
--   cache_loader: module 'plugins.foo' not found     → the byte-cache
--   cache_loader_lib: ...                            → and its .so variant
-- The rtp searcher checked <every-rtp-entry>/lua/plugins/foo.lua too, but
-- SILENTLY — on a miss it adds no trace line, so don't hunt for rtp paths
-- in the list; their absence doesn't mean rtp wasn't searched.
-- TOP 3 CAUSES IN A CONFIG:
--   a) Path/name mismatch: require("me.remaps") but the file is remap.lua —
--      the require string must mirror the path under lua/ EXACTLY.
--   b) The file isn't under a lua/ dir on runtimepath (e.g. you created
--      ~/.config/nvim/me/remap.lua, missing the lua/ level).
--   c) It's a plugin module and the plugin isn't installed/loaded yet —
--      classic when calling require("telescope") at startup while telescope
--      is lazy-loaded (lesson 04 fixes this with keys/cmd triggers).
-- FIX: check the exact on-disk path against the require string, then
-- `:=vim.api.nvim_get_runtime_file("lua/plugins/foo.lua", true)` to ask
-- nvim "can YOU see this file?".

------------------------------------------------------------ 5. attempt to concatenate a nil value
show("5. attempt to concatenate local 'branch' (a nil value)", function()
  local branch -- imagine: vim.fn.FugitiveHead() returned nothing
  return "on branch: " .. branch
end)
-- ANATOMY: `..` requires strings/numbers on both sides (module 01). One side
--   was nil; the message names WHICH variable when it can.
-- TOP 3 CAUSES IN A CONFIG:
--   a) An environment/option read that came back nil:
--      vim.env.SOMETHING .. "/path", vim.g.some_flag .. "".
--   b) A vim.fn.* call returning empty/nil on your machine (statusline
--      snippets: git branch, LSP name) — worked in the author's config.
--   c) String building in a loop where one element is optional.
-- FIX: tostring() the suspect, or provide a default with `or`:
local branch = nil
print('   fix: "on branch: " .. (branch or "?") →', "on branch: " .. (branch or "?"))

------------------------------------------------------------ 6. the E5113 wrapper you'll see at startup
-- When these errors happen while nvim loads your config, they arrive
-- wrapped:  E5113: Error while calling lua chunk: <the real message>
-- ...often followed by "stack traceback:". Read the traceback BOTTOM-UP:
-- the top line is where it exploded, lines below are who called whom —
-- usually ending in your init.lua. The FIRST line that mentions a file
-- you wrote is where to start looking.
print("6. see comments: E5113 wraps startup errors; traceback reads top=crash site")

------------------------------------------------------------ TRY IT
-- 1. In section 1, change `local x` to `local x = {}` — which section-2-style
--    error do you get from x.y.z now? Predict before running.
-- 2. Recreate cause 3a for real: write require("me.remap") here and run.
--    Read all trace lines and count how many places were searched.
-- 3. Make section 5 crash differently: concatenate a table instead of nil.
--    What does the message name it? ("a table value" — same grammar.)
-- 4. Trigger a REAL (uncaught) error: put `local t t.x = 1` at the end of
--    this file, run, and watch the exit code (`echo $?` in zsh) become
--    nonzero. That's why the course wraps demos in pcall. Remove it after.
