----------------------------------------------------------------------
-- exercises.lua — Module 07 exercises (debugging, specs, config hygiene)
----------------------------------------------------------------------
-- HOW TO RUN
--   nvim --clean -l exercises.lua        (from this directory)
-- This file runs clean AS-IS: every unfinished exercise prints TODO.
-- Replace the TODOs, re-run, and turn every line into PASS.
-- Solutions (with the key insight for each) live in solutions.lua.
----------------------------------------------------------------------

-- Tiny scorer. PASS = your code works; TODO/FAIL = keep going.
local score, total = 0, 0
local function check(name, cond, hint)
  total = total + 1
  if cond then
    score = score + 1
    io.write("PASS  " .. name .. "\n")
  else
    io.write("TODO  " .. name .. "   (" .. hint .. ")\n")
  end
end

------------------------------------------------------------ EXERCISE 1: read a table like a debugger
-- Below is a config-shaped nested table. Somewhere inside it is a width
-- value. First print the whole thing with vim.inspect (lesson 02 §2) to SEE
-- the structure, then set `found_width` to the actual value by indexing.
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

-- print(vim.inspect(plugin_state))   -- ← uncomment while exploring
local found_width = nil -- TODO: index your way to the 0.87
check("1: found_width", found_width == 0.87,
  "chain the keys: plugins → telescope → opts → ...")

------------------------------------------------------------ EXERCISE 2: warnf — a formatted notifier
-- Write warnf(fmt, ...) that:
--   • builds a message with string.format(fmt, ...)
--   • sends it with vim.notify at WARN level (lesson 02 §4)
--   • RETURNS the formatted message (so code — and this check — can reuse it)
local function warnf(fmt, ...)
  -- TODO (3 lines-ish)
end

local got = warnf("disk %d%% full on %s", 93, "/home")
check("2: warnf returns message", got == "disk 93% full on /home",
  "string.format first, vim.notify(msg, vim.log.levels.WARN), then return msg")

------------------------------------------------------------ EXERCISE 3: parse_error — file and line from a message
-- Lesson 02 §9 showed the anatomy: "path/to/file.lua:12: what happened".
-- Write parse_error(err) returning (file, line-as-NUMBER), or (nil, nil)
-- when the message has no location. Patterns are in module 05; remember
-- %d+ and the lazy (.-) capture, and tonumber().
local function parse_error(err)
  -- TODO
  return nil, nil
end

local f, l = parse_error("lua/me/opts.lua:12: attempt to index field 'x' (a nil value)")
check("3a: parses file", f == "lua/me/opts.lua", 'match "^(.-):(%d+):"')
check("3b: line is a number", l == 12, "tonumber() the second capture")
local f2 = parse_error("some bare message with no location")
check("3c: no-location gives nil", f2 == nil, "match returns nil — pass it through")

------------------------------------------------------------ EXERCISE 4: write a lazy spec (as data)
-- Build the spec table for folke/which-key.nvim (lesson 04) such that:
--   • [1] is the repo string "folke/which-key.nvim"
--   • it lazy-loads on the "VeryLazy" event
--   • opts sets delay = 300
--   • NO config key (data over code!)
local which_key_spec = nil -- TODO: replace with your spec table

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
-- Write register_trim() so that calling it ANY number of times leaves
-- exactly ONE autocmd registered — the fix for capstone BUG 4. Requirements:
--   • augroup named "ExTrim" (created with clear = true)
--   • autocmd on BufWritePre, pattern "*.lua"
--   • desc = "trim trailing whitespace (ex5)"  ← the check counts by this
--   • callback can be an empty function
local function register_trim()
  -- TODO: nvim_create_augroup + nvim_create_autocmd (lesson 05 §6 shows one)
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

------------------------------------------------------------ EXERCISE 6: safe_require and reload (this one stings)
-- Two helpers every config tinkerer eventually writes.
--
-- safe_require(name):
--   • returns the module when require succeeds
--   • on failure returns nil AND vim.notify()s ONLY THE FIRST LINE of the
--     error (the trace is noise here — take everything before the first \n;
--     careful: a message with NO newline must survive too) at ERROR level
-- reload(name):
--   • forces a fresh load even though require caches (lesson 01 §3.3):
--     clear the cache entry in package.loaded, then require again
--   • returns the freshly loaded module
--
-- Test rig: a fake module that counts how many times its body runs —
-- registered via package.preload, the same trick as the capstone's harness.
local loads = { n = 0 }
package.preload["ex6mod"] = function()
  loads.n = loads.n + 1
  return { greeting = "hi #" .. loads.n }
end

local function safe_require(name)
  -- TODO: pcall(require, name) ...
end

local function reload(name)
  -- TODO: package.loaded[name] = nil ...
end

local m1 = safe_require("ex6mod")
check("6a: safe_require loads", type(m1) == "table" and m1.greeting == "hi #1",
  "return the module on success")
local missing = safe_require("plugins.does_not_exist")
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
  or "keep going: edit this file, re-run, watch TODOs turn to PASS."))
