----------------------------------------------------------------------
-- 01_error_handling.lua — Errors, pcall/xpcall, and reading tracebacks
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • How error() works and what the "file:line:" prefix means
--   • Error LEVELS: blaming your caller instead of yourself
--   • assert() as a guard AND as a pass-through (the io.open idiom)
--   • pcall / xpcall + debug.traceback — catching errors like try/catch
--   • Error objects: throwing tables instead of strings, and rethrowing
--   • HOW TO READ a stack traceback line by line — your #1 nvim
--     debugging skill
-- HOW TO RUN
--   luajit 01_error_handling.lua      (from this directory)
--   or inside nvim:  :luafile %       (with this file open)
-- PREREQUISITES: module 04 (modules, metatables)
----------------------------------------------------------------------

------------------------------------------------------------ 1. error() basics
-- error(msg) aborts the current function and unwinds the stack until
-- something catches it (or the program dies with a traceback).
-- When msg is a STRING, Lua prepends "file:line:" — the position where
-- error() was called. That prefix is your friend: it's an address.
--
-- Rule of this course (and of sane programs): demonstrate errors through
-- pcall so the file still runs to the end. pcall = "protected call".

local ok, err = pcall(function()
  error("something broke")
end)
print("1a ok:", ok)     -- false: the protected call failed
print("1a err:", err)   -- "01_error_handling.lua:NN: something broke"

-- pcall(f, ...) returns:
--   true,  ...results...   if f finished normally
--   false, error_value     if f blew up
local ok2, sum = pcall(function(a, b) return a + b end, 3, 4)
print("1b pcall success:", ok2, sum)   -- true  7

------------------------------------------------------------ 2. Error levels
-- error(msg, level) controls WHICH line gets blamed in the prefix:
--   level 1 (default) → the line where error() itself was called
--   level 2           → the line of the function that CALLED you
--   level 0           → no position prefix at all
--
-- Level 2 is what library authors use: if the caller passed garbage,
-- the bug is at the CALL SITE, not inside your validation code.
-- vim.validate() and most vim.* argument errors work exactly like this.

local function must_be_number(x)
  if type(x) ~= "number" then
    error("expected a number, got " .. type(x), 2)  -- blame the caller
  end
  return x * 2
end

local ok3, err3 = pcall(function()
  local doubled = must_be_number("oops")   -- <- level 2 points HERE
  return doubled
end)
print("2a level-2 error:", err3)
-- (Fine print: we assign to a local instead of `return must_be_number(..)`
-- because `return f(x)` is a TAIL CALL — Lua reuses the caller's stack
-- frame, so there'd be no "caller" frame left for level 2 to point at.)
-- Compare: change 2 to 1 above and re-run — the prefix moves to the
-- error() line inside must_be_number. Less useful to the caller.

local ok4, err4 = pcall(function() error("no prefix", 0) end)
print("2b level-0 error:", err4)   -- just "no prefix", no file:line

------------------------------------------------------------ 3. assert()
-- assert(v, msg) — if v is nil/false, raises msg as an error.
-- Otherwise it RETURNS ALL ITS ARGUMENTS unchanged. That pass-through
-- behavior enables the single most common Lua idiom you'll ever see:
--
--   local f = assert(io.open(path, "r"))
--
-- io.open returns nil, errmsg on failure; assert turns that pair into a
-- real error. On success, assert hands the file handle straight through.
-- (Lesson 06 uses this for real.)

local value = assert(42, "never shown")   -- truthy → passes through
print("3a assert pass-through:", value)

local ok5, err5 = pcall(function()
  assert(nil, "config file missing")      -- falsy → raises the message
end)
print("3b assert failure:", err5)
-- Note: assert raises the message through error(), so a STRING message
-- DOES get a "file:line:" prefix — pointing at the assert() line (look
-- at 3b's output). With no msg it raises "assertion failed!". A
-- non-string msg (e.g. a table — section 6) passes through untouched.

------------------------------------------------------------ 4. xpcall + debug.traceback
-- pcall's weakness: by the time it returns, the stack has already been
-- unwound. You know WHAT broke, not the call chain that led there.
-- xpcall(f, handler) runs handler(err) at the MOMENT of the error,
-- while the dead stack is still intact — so the handler can capture it.
-- The standard handler is debug.traceback.

local function level3() error("deep failure") end
local function level2fn() level3() end
local function level1fn() level2fn() end

local ok6, trace = xpcall(level1fn, debug.traceback)
print("4a xpcall ok:", ok6)
print("4b captured traceback:")
print(trace)

-- Lua version note: passing extra arguments — xpcall(f, handler, a, b)
-- — works in LuaJIT (a Lua 5.2 extension it adopted) and in Neovim,
-- but NOT in vanilla Lua 5.1. Verified on this machine: it works.
local ok7, res7 = xpcall(function(a, b) return a + b end, debug.traceback, 20, 22)
print("4c xpcall with args:", ok7, res7)

------------------------------------------------------------ 5. HOW TO READ A TRACEBACK
-- Look at the traceback printed by 4b above. It has exactly this shape
-- (NN = line numbers in this file):
--
--   01_error_handling.lua:NN: deep failure          <- THE ERROR ITSELF
--   stack traceback:                                <- header, ignore
--   [C]: in function 'error'                        <- error() is a C builtin
--   01_error_handling.lua:NN: in function 'level3'  <- error() called here
--   01_error_handling.lua:NN: in function 'level2fn'<- ...called from here
--   01_error_handling.lua:NN: in function <01_...:NN> <- ...and from here
--   [C]: in function 'xpcall'                       <- protection boundary
--   01_error_handling.lua:NN: in main chunk         <- top level of the file
--   [C]: at 0x...                                   <- the luajit binary itself
--
-- READING ORDER: top line = where it died; each line below = one step
-- back toward whoever started the call. Notes:
--   • "in function 'level3'"  — Lua guessed the name from how it was
--     called. Guessing fails for functions passed as values, which is
--     why level1fn (handed to xpcall) shows as "in function <file:NN>":
--     an anonymous-looking reference, NN = the line it was DEFINED on.
--   • "[C]" — a function written in C; no Lua line exists to show.
--   • "in main chunk" — code at a file's top level, not inside any
--     function. Your init.lua lines show up like this.
--
-- The same skeleton in a real Neovim error looks like:
--
--   E5108: Error executing lua .../lua/me/remap.lua:12: attempt to
--          index a nil value (global 'telescope')
--   stack traceback:
--     .../lua/me/remap.lua:12: in main chunk            <- YOUR file, line 12
--     [C]: in function 'require'                        <- loaded via require
--     .../lua/me/init.lua:1: in main chunk              <- require("me.remap")
--     [C]: in function 'require'
--     ~/.config/nvim/init.lua:15: in main chunk         <- require("me")
--
-- Strategy: scan top-down and stop at the FIRST line that is YOUR code —
-- that file:line is where to put your cursor. "in main chunk" = code at
-- the top level of a file (not inside any function). Lines through
-- plugin directories before your first line usually mean a plugin called
-- your callback; your bug is still at your own line.

------------------------------------------------------------ 6. Error objects (tables)
-- error() accepts ANY value, not just strings. Throw a table and it
-- arrives untouched — no "file:line:" prefix is added to non-strings.
-- Useful when the catcher needs structured data (an error code, the
-- offending path, ...) instead of parsing a message string.

local ok8, eobj = pcall(function()
  error({ code = "ENOENT", path = "/etc/hypr/hyprland.conf" })
end)
print("6a error object type:", type(eobj))
print("6b code:", eobj.code, "path:", eobj.path)

-- The catcher can branch on structure:
if type(eobj) == "table" and eobj.code == "ENOENT" then
  print("6c handled: missing file ->", eobj.path)
end

------------------------------------------------------------ 7. Rethrow patterns
-- Sometimes you catch an error, look at it, and decide it's not yours to
-- handle. Rethrow it. Two details matter:
--   • error(err, 0) — level 0, because the message ALREADY carries its
--     original "file:line:" prefix; level 1 would stack a second,
--     misleading prefix on top.
--   • Add context by wrapping: error("loading plugin X: " .. err, 0)

local function risky() error("disk on fire") end

local function try_and_rethrow()
  local ok9, err9 = pcall(risky)
  if not ok9 then
    -- not our problem: annotate and pass it up unchanged
    error("while running risky(): " .. err9, 0)
  end
end

local ok10, err10 = pcall(try_and_rethrow)
print("7a rethrown:", err10)
-- Note there's exactly ONE file:line in there (the original), because we
-- rethrew with level 0. Change the 0 to 1 and re-run to see the double
-- prefix problem.

------------------------------------------------------------ TRY IT
-- 1. In section 2, change the error level in must_be_number from 2 to 1
--    and re-run. Watch the blamed line number move. Which one would YOU
--    want to see if you called the function wrong?
-- 2. Make level3() error with a TABLE instead of a string, and print
--    what xpcall's debug.traceback handler produces. (Spoiler: traceback
--    can't concatenate a table — see what it does instead.)
-- 3. Write divide(a, b) that errors at level 2 when b == 0, then call it
--    through pcall with b = 0 and check the prefix points at your call.
-- 4. Paste any error you've seen from your real nvim config into a
--    comment here and annotate each traceback line like section 5 does.
