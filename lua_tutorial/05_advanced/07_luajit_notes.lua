----------------------------------------------------------------------
-- 07_luajit_notes.lua — LuaJIT: what you're actually running
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • What LuaJIT is and how to interrogate it (jit.version & friends)
--   • Bitwise ops via the `bit` library (Lua 5.1 has NO operators)
--   • goto: a 5.2 feature LuaJIT backported — you have it
--   • ffi exists (one line, not a lesson)
--   • A reference table: Lua 5.1/LuaJIT vs 5.4 — the traps you'll hit
--     reading blog posts written for newer Lua
-- HOW TO RUN
--   luajit 07_luajit_notes.lua        (from this directory)
--   or inside nvim:  :luafile %       (with this file open)
-- PREREQUISITES: the rest of this module
----------------------------------------------------------------------

------------------------------------------------------------ 1. What LuaJIT is
-- LuaJIT (Mike Pall) is an independent implementation of Lua 5.1 with a
-- Just-In-Time compiler: it starts out interpreting your code, watches
-- for hot paths (loops, hot functions), and compiles those to native
-- machine code on the fly. It is famously fast — one big reason Neovim
-- chose to embed it. Language-wise it is 5.1 plus a curated set of 5.2
-- features and its own extensions (bit, ffi, jit.*).

print("1a _VERSION:", _VERSION)        -- "Lua 5.1" — the LANGUAGE version
print("1b jit.version:", jit.version)  -- the IMPLEMENTATION version
print("1c platform:", jit.os, jit.arch)
print("1d JIT active:", jit.status())  -- false under `luajit -joff`
-- In nvim, check yours with  :lua print(jit.version)
-- (jit.status() actually returns a flag plus a list of CPU features;
--  print shows them all.)

------------------------------------------------------------ 2. The bit library
-- Lua 5.1 has NO bitwise operators. Code like `a & b` or `x << 2` from
-- a Lua 5.3+ blog post is a SYNTAX ERROR here. LuaJIT's answer is the
-- built-in `bit` module:

local bit = require("bit")

local a, b_ = 0xC, 0xA                     -- 12 = 1100, 10 = 1010
print("2a band:", bit.band(a, b_))         -- 8     (1000)  ~  a & b
print("2b bor:", bit.bor(a, b_))           -- 14    (1110)  ~  a | b
print("2c bxor:", bit.bxor(a, b_))         -- 6     (0110)  ~  a ~ b
print("2d bnot:", bit.bnot(0))             -- -1            ~  ~0
print("2e lshift:", bit.lshift(1, 4))      -- 16            ~  1 << 4
print("2f rshift:", bit.rshift(256, 4))    -- 16            ~  256 >> 4
print("2g tohex:", bit.tohex(255))         -- 000000ff (as a string)
-- Also: bit.arshift (keeps the sign bit), bit.rol/bit.ror (rotate),
-- bit.bswap (byte order). Everything works on 32-bit integer views of
-- Lua numbers. Where you'll meet these in nvim: permission bits like
-- 438 (= 0666) in vim.uv.fs_open calls, flag masks in some APIs.

------------------------------------------------------------ 3. goto — yes, you have it
-- goto arrived in Lua 5.2, and LuaJIT backported it. Its one respectable
-- job in Lua: "continue" for loops, which the language otherwise lacks.

local total = 0
for i = 1, 10 do
  if i % 3 == 0 then goto continue end   -- skip multiples of 3
  total = total + i
  ::continue::                            -- a label, in double colons
end
print("3a sum skipping x3:", total)       -- 1+2+4+5+7+8+10 = 37
-- Rules: you can only jump forward to a label in scope, never into a
-- block or past a local's declaration. Treat it as `continue` and move on.

------------------------------------------------------------ 4. ffi — know it exists
-- LuaJIT ships `ffi`, which can call C functions and use C data types
-- directly, no glue code. It's how some plugins get native speed. Not a
-- lesson here — just recognize `local ffi = require("ffi")` when you
-- see it and know it's LuaJIT-only (plain Lua doesn't have it).
print("4a ffi available:", pcall(require, "ffi"))

------------------------------------------------------------ 5. Version-difference cheat table
-- You will constantly read Lua material written for 5.3/5.4. This
-- table is what to do when their code breaks on your 5.1/LuaJIT.
-- (Every LuaJIT-column claim below was verified on THIS machine, both
-- in CLI luajit and in nvim 0.12.4 — builds differ, so trust but verify
-- on other machines.)
--
--  Feature (5.2+/5.3+/5.4)      | Your LuaJIT (Neovim)        | Portable fix / note
--  -----------------------------|-----------------------------|--------------------------------------
--  a & b, a | b, a ~ b, <<, >>  | SYNTAX ERROR                | require("bit"): band/bor/bxor/shifts
--  a // b   (floor division)    | SYNTAX ERROR                | math.floor(a / b)
--  integers vs floats subtype   | one number type (double)    | math.type == nil here; 1 prints "1"
--    (math.type, 3/2 → 1.5 vs   |                             | not "1.0"; don't fear float == int
--     tointeger, overflow wrap) |                             |
--  table.unpack                 | nil (!) — use unpack        | local unpack = unpack or table.unpack
--  table.pack                   | nil                         | {n = select("#", ...), ...}
--  goto / ::labels::            | AVAILABLE (backported)      | fine to use
--  xpcall(f, handler, args...)  | AVAILABLE (backported)      | fine to use
--  io.read("a"/"l" — no star)   | AVAILABLE (backported)      | "*a"/"*l" work everywhere; prefer them
--  string.rep(s, n, sep)        | AVAILABLE (backported)      | fine to use
--  \x41 hex escapes in strings  | AVAILABLE (backported)      | fine to use
--  os.exit(true/false)          | AVAILABLE (backported)      | fine to use
--  setfenv / getfenv            | 5.1 feature: PRESENT here   | REMOVED in 5.2+ (replaced by _ENV);
--                               |                             | old plugin code may use them
--  _ENV                         | not a thing on 5.1          | 5.2+ only; blog code using it breaks
--  utf8.* library (5.3)         | nil (nvim adds vim.str_*)   | use vim.fn / vim.str_utfindex etc.
--  math.maxinteger/mininteger   | nil (5.3)                   | 2^53 is the safe integer ceiling
--  string.format("%q") multiline| minor formatting diffs      | rarely matters
--
-- The two that ACTUALLY bite weekly when copying snippets:
--   1. table.unpack  → use `unpack`
--   2. bitwise/integer-division operators → bit library / math.floor

-- Prove the big ones, live:
print("5a table.unpack is:", tostring(table.unpack))       -- nil on this machine
print("5b unpack exists:", type(unpack))                   -- "function"
local unpack_ = unpack or table.unpack                      -- THE portable line
print("5c portable unpack:", unpack_({ "eDP-1", "DP-1" }))
print("5d one number type:", 3 / 2, 10 / 5)                -- 1.5  2 (no "2.0"!)
print("5e no math.type:", tostring(math.type))
-- And 5.4 syntax really is a load-time error — catch it with loadstring
-- (5.1's name for load-a-chunk-from-a-string; 5.2+ renamed it `load`):
local fn, syntax_err = loadstring("return 5 // 2")
print("5f floor-div parses?", fn ~= nil, "|", syntax_err)
local fn2, syntax_err2 = loadstring("return 5 & 2")
print("5g bitwise-and parses?", fn2 ~= nil, "|", syntax_err2)

------------------------------------------------------------ TRY IT
-- 1. Run this file as `luajit -joff 07_luajit_notes.lua` and spot what
--    changed in section 1's output.
-- 2. Write mask(perms) using bit.band to test whether the 0400 bit is
--    set in the octal-ish permission number 438 (which is 0666).
--    Hint: 0400 octal = 256 decimal.
-- 3. Rewrite section 3's loop without goto (plain if). Which reads
--    better? (There's no wrong answer; now you can read both styles.)
-- 4. Take any Lua 5.4 snippet from a blog post that uses // or &,
--    paste it here under loadstring like 5f/5g, and then PORT it so it
--    runs. That's the whole skill this lesson teaches.
