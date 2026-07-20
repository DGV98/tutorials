----------------------------------------------------------------------
-- 08_vim_utilities.lua — the utility belt
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Table tools: vim.tbl_deep_extend, tbl_keys/values/contains, list_extend
--   • String tools: vim.split, vim.trim, vim.startswith/endswith
--   • vim.iter — lazy chains over tables (0.10+)
--   • vim.json encode/decode, vim.notify
--   • vim.schedule / vim.defer_fn and WHY (fast event contexts)
--   • vim.system — run shell commands properly; vim.uv at a glance
-- HOW TO RUN
--   nvim --clean -l 08_vim_utilities.lua    (from this directory)
--   or inside nvim:  :luafile %
-- PREREQUISITES: modules 02 (functions) & 03 (tables), lesson 01 here
----------------------------------------------------------------------
-- None of these touch the editor screen — they're pure-Lua helpers that
-- Neovim ships because every plugin needs them. No :set/:map equivalents
-- exist for most; where one does, it's noted.

------------------------------------------------------------ 1. Merging tables: tbl_deep_extend
-- THE config idiom. Every plugin's setup() merges your opts over its
-- defaults with exactly this call.
-- vim.tbl_deep_extend(behavior, ...) — recursive merge; "force" = later
--   tables win on conflict ("keep" = earlier win, "error" = collide loudly)
--   (:help vim.tbl_deep_extend())
local defaults = { ui = { border = "rounded", icons = true }, limit = 10 }
local user = { ui = { border = "single" } }
local merged = vim.tbl_deep_extend("force", defaults, user)
print("deep merge:", vim.inspect(merged)) -- border overridden, icons/limit kept

-- Sibling trap: vim.tbl_extend (no "deep") merges only the TOP level —
-- with it, user's `ui` table would REPLACE defaults' ui entirely,
-- silently dropping icons. Deep for nested config, shallow for flat.
local shallow = vim.tbl_extend("force", defaults, user) -- vim.tbl_extend: one-level merge
print("shallow merge loses ui.icons:", vim.inspect(shallow.ui))

------------------------------------------------------------ 2. Table odds and ends
local pack = { name = "telescope", lazy = true, priority = 50 }

-- vim.tbl_keys(t) → list of keys (ORDER NOT GUARANTEED — pairs() rules, module 03)
print("keys:    ", vim.inspect(vim.tbl_keys(pack)))
-- vim.tbl_values(t) → list of values, same warning
print("values:  ", vim.inspect(vim.tbl_values(pack)))
-- vim.tbl_contains(t, value) → true/false, real booleans
print("contains:", vim.tbl_contains({ "lua", "vim" }, "lua"))
-- vim.tbl_count(t) → number of pairs (# only counts array part, module 03!)
print("count:   ", vim.tbl_count(pack))
-- vim.tbl_isempty(t) → is {} ?
print("isempty: ", vim.tbl_isempty({}))

-- vim.list_extend(dst, src) → appends src's items INTO dst (mutates dst!)
local langs = { "lua" }
vim.list_extend(langs, { "bash", "python" })
print("list_extend (mutated dst):", vim.inspect(langs))

------------------------------------------------------------ 3. String helpers
-- vim.split(s, sep, opts?) → table of pieces (module 05's gmatch, prepackaged)
--   like zsh: ${(s:,:)var}
print("split:", vim.inspect(vim.split("eDP-1,DP-1,DP-4", ",")))
-- opts.trimempty removes empty pieces at the ENDS only (not interior!):
print("split trimempty:", vim.inspect(vim.split(",a,,b,", ",", { trimempty = true })))

-- vim.trim(s) → strip leading/trailing whitespace (module 01's gsub, prepackaged)
print("trim: [" .. vim.trim("  spaced out  ") .. "]")

-- vim.startswith(s, prefix) / vim.endswith(s, suffix) → real booleans
print("startswith:", vim.startswith("init.lua", "init"), "| endswith:", vim.endswith("init.lua", ".lua"))

------------------------------------------------------------ 4. vim.iter — chains over tables (0.10+)
-- vim.iter(src) wraps a table/iterator in a pipeline object: chain
-- :map/:filter/:rev/:take..., finish with :totable()/:fold()/each().
-- Think shell pipes for tables.  (:help vim.iter)
local monitors = { "eDP-1 1920x1080", "DP-1 2560x1440", "DP-4 1920x1080", "HDMI-A-1 1920x1080" }

-- vim.iter():filter():map():totable() — one pass, no temp tables:
local dp_names = vim.iter(monitors)
  :filter(function(m) return vim.startswith(m, "DP-") end) -- keep DP-* (vim.startswith again)
  :map(function(m) return vim.split(m, " ")[1] end) -- keep just the name (vim.split again)
  :totable()
print("DP monitors:", vim.inspect(dp_names))

-- vim.iter():fold(init, fn) — reduce, like module 02's accumulator loops:
local total = vim.iter({ 3, 3, 1, 10 }):fold(0, function(acc, n) return acc + n end)
print("fold sum:", total)

-- Deprecation corner: old code says vim.tbl_flatten(t); modern is
-- vim.iter(t):flatten():totable() — same result:
print("flatten:", vim.inspect(vim.iter({ { 1, 2 }, { 3 } }):flatten():totable()))

------------------------------------------------------------ 5. JSON round-trips
-- Config files, LSP payloads, `curl | nvim`-style scripting: JSON is
-- everywhere, and it's built in.
-- vim.json.encode(value) → JSON string    (:help vim.json)
local j = vim.json.encode({ name = "hyprland", gaps = { inner = 3, outer = 3 } })
print("encode:", j)
-- vim.json.decode(string) → Lua value. JSON null becomes vim.NIL, a
-- sentinel (real nil would delete the key — module 03!). Compare with == vim.NIL.
local back = vim.json.decode('{"rounding":10,"shadow":null}')
print("decode:", vim.inspect(back), "| shadow is vim.NIL:", back.shadow == vim.NIL)

------------------------------------------------------------ 6. vim.notify
-- vim.notify(msg, level?) — THE way to talk to the user. Plain print in
-- disguise by default, but plugins (noice, snacks) replace it with
-- popups, and levels let them filter/color.  ≈  :echomsg / :echoerr-ish
vim.notify("all systems nominal", vim.log.levels.INFO) -- vim.log.levels: TRACE DEBUG INFO WARN ERROR
vim.notify("disk almost full (demo)", vim.log.levels.WARN)
-- Rule: print() for debugging YOU delete later; vim.notify for messages
-- meant to be seen.

------------------------------------------------------------ 7. vim.schedule and vim.defer_fn — the "later" tools
-- Some code runs in a FAST EVENT CONTEXT (:help vim.in_fast_event):
-- low-level callbacks (vim.uv timers, vim.system on_exit, ...) fire
-- while Neovim is mid-heartbeat, where most vim.api calls are FORBIDDEN
-- and will throw "E5560: must not be called in a fast event context".
--
-- vim.schedule(fn) — queue fn to run on the main loop, soon, when the
--   editor is safe to touch. The fix for E5560.
-- vim.defer_fn(fn, ms) — same, but after a delay (schedule + timer).
-- vim.schedule_wrap(fn) → a version of fn that always self-schedules —
--   handy to hand directly to uv callbacks.
local order = {}
table.insert(order, "1: direct")
vim.schedule(function() table.insert(order, "3: scheduled runs AFTER current code") end)
table.insert(order, "2: still direct")

-- vim.wait(ms, predicate?) — block, processing events, until predicate
--   is true or time is up. Perfect for making async demos deterministic
--   in scripts (rarely needed in real config).  (:help vim.wait())
vim.wait(200, function() return #order == 3 end)
print("execution order:", vim.inspect(order))

local deferred_ran = false
vim.defer_fn(function() deferred_ran = true end, 20) -- run ~20ms later
vim.wait(500, function() return deferred_ran end) -- (vim.wait again — let it fire)
print("defer_fn ran:", deferred_ran)

------------------------------------------------------------ 8. vim.system — shell out, properly
-- vim.system(cmd_list, opts?) → object; :wait() makes it synchronous.
--   Modern replacement for vim.fn.system / jobstart (lesson 05).
--   Like $(...) in zsh but with argv-list safety: no quoting bugs, no
--   shell injection, because there IS no shell unless you ask.
--   (:help vim.system())
local res = vim.system({ "uname", "-sr" }, { text = true }):wait() -- text=true → strings, not bytes
print("uname:", vim.trim(res.stdout), "| exit code:", res.code) -- (vim.trim from section 3)

-- Async form: pass a callback — it runs in a fast event context, which
-- is exactly why section 7 exists. Note the schedule inside:
local done = false
vim.system({ "echo", "async says hi" }, { text = true }, function(out)
  -- fast context here! vim.api calls would throw E5560 — route any
  -- editor work through vim.schedule:
  vim.schedule(function()
    print("async result:", vim.trim(out.stdout)) -- main loop again: everything allowed
    done = true
  end)
end)
vim.wait(1000, function() return done end) -- keep the script alive until it lands

------------------------------------------------------------ 9. vim.uv at a glance
-- vim.uv is libuv — the raw event loop under Neovim: filesystem, timers,
-- TCP, processes. It REPLACED vim.loop: same table, new name (old blog
-- posts say vim.loop; in 0.12 that's just an alias — write vim.uv).
-- You'll mostly meet it in plugin code; two calls worth knowing:
print("uv.cwd():", vim.uv.cwd()) -- current dir  ≈ :pwd / getcwd()
local stat = vim.uv.fs_stat("08_vim_utilities.lua") -- file info or nil  ≈ test -e + stat(1)
print("this file exists:", stat ~= nil, stat and ("size " .. stat.size .. " bytes") or "")
-- The lazy.nvim bootstrap in your init.lua uses exactly this fs_stat
-- pattern to check whether lazy.nvim is already cloned.

------------------------------------------------------------ TRY IT
-- 1. Merge THREE layers with tbl_deep_extend: defaults, "work profile",
--    "today's override". Verify the middle layer survives where the
--    top layer is silent.
-- 2. Use vim.iter on vim.split of "eDP-1:60,DP-1:60,DP-4:180,DP-3:180"
--    to produce only the names with refresh rate 180. (Chain split →
--    iter → filter → map.)
-- 3. Round-trip: vim.json.decode a string with null, re-encode it, and
--    check the null survived (vim.NIL encodes back to null).
-- 4. In section 8's async callback, pcall a real API write like
--    vim.api.nvim_buf_set_lines(0, 0, -1, false, {"x"}) WITHOUT
--    vim.schedule and print the caught error — you want to RECOGNIZE
--    E5560 in the wild. (print itself is one of the few safe calls,
--    which is why the demo doesn't crash without schedule.)
