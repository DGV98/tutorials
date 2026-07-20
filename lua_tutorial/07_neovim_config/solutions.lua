----------------------------------------------------------------------
-- solutions.lua — Module 07 solutions (complete and runnable)
----------------------------------------------------------------------
-- HOW TO RUN
--   nvim --clean -l solutions.lua        (from this directory)
-- Same checks as exercises.lua, with the solutions filled in — every
-- line must print PASS. Each exercise starts with its KEY INSIGHT;
-- compare against YOUR version, don't just read.
----------------------------------------------------------------------

-- Same tiny scorer as exercises.lua. FAIL instead of TODO, because a
-- red line in THIS file is a bug, not homework.
local score, total = 0, 0
local function check(name, cond, hint)
  total = total + 1
  if cond then
    score = score + 1
    io.write("PASS  " .. name .. "\n")
  else
    io.write("FAIL  " .. name .. "   (" .. hint .. ")\n")
  end
end

------------------------------------------------------------ EXERCISE 1: read a table like a debugger
-- KEY INSIGHT: print(vim.inspect(t)) FIRST, index SECOND. The inspect
-- output is a map of the exact chain to type — here it reads
-- plugins → telescope → opts → defaults → layout_config → width.
-- Guessing the chain without looking is how lesson-03 §2 errors happen.
local plugin_state = {
  plugins = {
    telescope = {
      spec = { "nvim-telescope/telescope.nvim", version = "0.1.x" },
      opts = {
        defaults = {
          layout_strategy = "horizontal",
          layout_config = { width = 0.87, prompt_position = "top" },
        },
      },
    },
    lualine = { spec = { "nvim-lualine/lualine.nvim" }, opts = { theme = "tokyonight" } },
  },
}

-- vim.inspect(t)  →  human-readable string of any value (lesson 02 §2)
-- print(vim.inspect(plugin_state))   -- ← the exploring step, done once
local found_width = plugin_state.plugins.telescope.opts.defaults.layout_config.width
check("1: found_width", found_width == 0.87,
  "chain the keys: plugins → telescope → opts → ...")

------------------------------------------------------------ EXERCISE 2: warnf — a formatted notifier
-- KEY INSIGHT: build the message ONCE, then both send and return it.
-- A helper that returns what it reports is reusable (statusline, logging)
-- and testable — this file's check works only because of the return.
local function warnf(fmt, ...)
  local msg = string.format(fmt, ...) -- format first: one source of truth
  -- vim.notify(msg, level)  ≈  :echomsg, but routable by UI plugins (lesson 02 §4)
  -- vim.log.levels  →  severity constants; WARN = 3. :help vim.log.levels
  vim.notify(msg, vim.log.levels.WARN)
  return msg
end

local got = warnf("disk %d%% full on %s", 93, "/home")
io.write("\n") -- quirk: in -l mode notify's echo lacks a trailing newline
check("2: warnf returns message", got == "disk 93% full on /home",
  "string.format first, vim.notify(msg, vim.log.levels.WARN), then return msg")

------------------------------------------------------------ EXERCISE 3: parse_error — file and line from a message
-- KEY INSIGHT: "path:12: message" is just text — one pattern, two captures.
--   ^(.-)   lazy capture: the SHORTEST prefix that lets the rest match,
--           so it stops at the FIRST ":<digits>:" (paths may contain dots)
--   (%d+)   the line number — but captures are STRINGS, hence tonumber()
-- When match() finds nothing it returns nil, and file stays nil — exactly
-- the (nil, nil) contract, no special case needed beyond the guard.
local function parse_error(err)
  local file, line = err:match("^(.-):(%d+):")
  if not file then return nil, nil end
  return file, tonumber(line)
end

local f, l = parse_error("lua/me/opts.lua:12: attempt to index field 'x' (a nil value)")
check("3a: parses file", f == "lua/me/opts.lua", 'match "^(.-):(%d+):"')
check("3b: line is a number", l == 12, "tonumber() the second capture")
local f2 = parse_error("some bare message with no location")
check("3c: no-location gives nil", f2 == nil, "match returns nil — pass it through")

------------------------------------------------------------ EXERCISE 4: write a lazy spec (as data)
-- KEY INSIGHT: a spec is pure data (lesson 04). [1] is the array part
-- holding the repo string; triggers and opts are hash keys in the SAME
-- table. No config key: lazy's default behavior already calls
-- require("which-key").setup(opts) — writing a config function that just
-- does that is the lesson-04 §2 clobbering trap waiting to happen.
local which_key_spec = {
  "folke/which-key.nvim",
  event = "VeryLazy", -- load after startup finishes: perfect for UI helpers
  opts = { delay = 300 },
}

local function spec_ok(s)
  return type(s) == "table"
    and s[1] == "folke/which-key.nvim"
    and s.event == "VeryLazy"
    and type(s.opts) == "table" and s.opts.delay == 300
    and s.config == nil
end
check("4: which-key spec", spec_ok(which_key_spec),
  "a table: { 'owner/repo', event = ..., opts = { ... } }")

------------------------------------------------------------ EXERCISE 5: re-source-proof autocmd
-- KEY INSIGHT: an augroup created with { clear = true } wipes its own
-- previous contents every time the creating code runs — so registration
-- becomes REPLACE instead of STACK, and re-sourcing your config is safe.
-- (Same pattern as the mini-plugin's setup() and the fix for capstone BUG 4.)
local function register_trim()
  -- vim.api.nvim_create_augroup(name, {clear=true})  ≈  :augroup ExTrim | au! | augroup END
  local group = vim.api.nvim_create_augroup("ExTrim", { clear = true })
  -- vim.api.nvim_create_autocmd(event, o)  ≈  :autocmd ExTrim BufWritePre *.lua ...
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group, -- ← membership in the cleared group is what dedupes
    pattern = "*.lua",
    desc = "trim trailing whitespace (ex5)",
    callback = function() end,
  })
end

register_trim()
register_trim()
register_trim()
local trim_count = 0
-- vim.api.nvim_get_autocmds(filter)  →  list matching autocmds
for _, au in ipairs(vim.api.nvim_get_autocmds({ event = "BufWritePre" })) do
  if au.desc == "trim trailing whitespace (ex5)" then trim_count = trim_count + 1 end
end
check("5: exactly one autocmd after 3 calls", trim_count == 1,
  trim_count == 0 and "nothing registered yet — write the body"
  or ("found " .. trim_count .. " — the group must clear on each call"))

------------------------------------------------------------ EXERCISE 6: safe_require and reload
-- KEY INSIGHT (safe_require): pcall turns a crash into data (lesson 03).
-- On failure err looks like "path:line: message\nstack traceback:..." —
-- the human part is everything before the first newline. The pattern
-- "^([^\n]*)" — zero or MORE non-newline chars anchored at the start —
-- also matches a message with no newline at all (a one-or-more pattern
-- with a literal \n would return nil for those and crash the notify).
--
-- KEY INSIGHT (reload): require caches its result in package.loaded
-- (lesson 01 §3.3) and returns the cached value forever after. Nil-ing
-- that one entry is the WHOLE trick: the next require runs the loader
-- again. This is what plugin dev tools' "reload module" commands do.
-- (Test rig registered via package.preload — the capstone harness trick.)
local loads = { n = 0 }
package.preload["ex6mod"] = function()
  loads.n = loads.n + 1
  return { greeting = "hi #" .. loads.n }
end

local function safe_require(name)
  local ok, mod = pcall(require, name)
  if ok then return mod end
  local first_line = tostring(mod):match("^([^\n]*)")
  -- vim.notify(msg, vim.log.levels.ERROR)  ≈  :echoerr — red in :messages
  vim.notify(first_line, vim.log.levels.ERROR)
  return nil
end

local function reload(name)
  package.loaded[name] = nil -- forget the cached value...
  return require(name) -- ...so require runs the module body again
end

local m1 = safe_require("ex6mod")
check("6a: safe_require loads", type(m1) == "table" and m1.greeting == "hi #1",
  "return the module on success")
local missing = safe_require("plugins.does_not_exist")
io.write("\n") -- same -l newline quirk: 6b's ERROR notify above ends without one
check("6b: missing module gives nil (no crash)", missing == nil,
  "pcall, notify first line, return nil")
local m2 = safe_require("ex6mod")
check("6c: cached: body did not re-run", loads.n == 1 and m2 ~= nil,
  "plain require must still hit the cache")
local m3 = reload("ex6mod")
check("6d: reload re-runs the body", type(m3) == "table" and m3.greeting == "hi #2",
  "clear package.loaded['ex6mod'] first, then require")

------------------------------------------------------------ scoreboard
io.write(("\n%d/%d — %s\n"):format(score, total,
  score == total and "all green. Take safe_require home to your real config."
  or "a FAIL in solutions.lua is a bug — compare with exercises.lua and yell"))
