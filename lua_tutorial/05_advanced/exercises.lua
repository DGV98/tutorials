----------------------------------------------------------------------
-- exercises.lua — Advanced Lua: your turn
----------------------------------------------------------------------
-- HOW TO WORK
--   Fill in each TODO, then un-comment the test lines under it and run:
--     luajit exercises.lua           (from this directory)
--   The file runs clean as-is; every un-commented test should keep it
--   that way. Solutions live in solutions.lua — struggle first.
-- PREREQUISITES: lessons 01–07 of this module
----------------------------------------------------------------------

-- Exercise 7 writes files; make paths relative to THIS file (lesson 06 §1):
local here = arg and arg[0] and arg[0]:match("^(.*)/") or "."
local build_dir = here .. "/build"
os.execute("mkdir -p '" .. build_dir .. "'")

print("== exercises: advanced lua ==\n")

------------------------------------------------------------
-- EXERCISE 1: must_get(t, key) — blame the caller
------------------------------------------------------------
-- Write must_get(t, key): return t[key], but if it's nil, raise
-- "missing key: <key>" — at error LEVEL 2, so the file:line prefix
-- points at the CALLER, not at your error() line (lesson 01 §2).
local function must_get(t, key)
  -- TODO: ~3 lines.
end

-- TEST (un-comment):
-- local cfg = { border_size = 1 }
-- local ok, err = pcall(function()
--   local v = must_get(cfg, "gaps_in")   -- level 2 should blame THIS line
--   return v
-- end)
-- print("E1:", must_get(cfg, "border_size") == 1, ok == false,
--       err:match("missing key: gaps_in") ~= nil)
print("E1: TODO")

------------------------------------------------------------
-- EXERCISE 2: parse_mode(s) — captures + tonumber
------------------------------------------------------------
-- Your monitor lines carry modes like "1920x1080@60". Write
-- parse_mode(s) returning width, height, refresh as three NUMBERS,
-- or nil if the string isn't that shape (e.g. "auto").
-- Anchor the pattern at both ends (lesson 02 §3–4).
local function parse_mode(s)
  -- TODO: one match with three captures, then tonumber each.
end

-- TEST (un-comment):
-- local w, h, hz = parse_mode("2560x1440@60")
-- print("E2:", w == 2560, h == 1440, hz == 60,
--       parse_mode("auto") == nil, parse_mode("1920x1080") == nil)
print("E2: TODO")

------------------------------------------------------------
-- EXERCISE 3: expand(s, vars) — $variable substitution
------------------------------------------------------------
-- Write expand(s, vars): replace every $name in s with vars[name],
-- leaving UNKNOWN $names untouched. One gsub does the whole job —
-- remember what gsub does with a table replacement when the lookup
-- comes back nil (lesson 02 §6). Mind that $ is a magic character.
local function expand(s, vars)
  -- TODO: one line (two if you count `return`).
end

-- TEST (un-comment):
-- local out = expand("exec = $term -e $editor $missing",
--                    { term = "ghostty", editor = "nvim" })
-- print("E3:", out == "exec = ghostty -e nvim $missing")
print("E3: TODO")

------------------------------------------------------------
-- EXERCISE 4: reverse_ipairs(t) — a STATELESS iterator
------------------------------------------------------------
-- Write reverse_ipairs(t) that walks t from #t down to 1. Stateless
-- means: return (iterator_fn, t, initial_control) and keep NO state in
-- closures — the iterator gets everything from its two arguments
-- (lesson 03 §2). What must the initial control value be?
local function reverse_ipairs(t)
  -- TODO: an iterator function + `return iter, t, <initial>`.
end

-- TEST (un-comment):
-- local acc = {}
-- for i, v in reverse_ipairs({ "a", "b", "c" }) do
--   acc[#acc + 1] = i .. v
-- end
-- print("E4:", table.concat(acc, " ") == "3c 2b 1a")
print("E4: TODO")

------------------------------------------------------------
-- EXERCISE 5: walk(t) — a coroutine generator
------------------------------------------------------------
-- Write walk(t) using coroutine.wrap: it yields every NON-table value
-- found in t, descending into nested tables in array order (use
-- ipairs). This is lesson 04 §4's "generators for free" claim — a
-- recursive helper function that yields is the whole trick.
local function walk(t)
  -- TODO: coroutine.wrap around a recursive local function.
end

-- TEST (un-comment):
-- local got = {}
-- for v in walk({ 1, { 2, { 3, 4 } }, 5 }) do got[#got + 1] = v end
-- print("E5:", table.concat(got, " ") == "1 2 3 4 5")
print("E5: TODO")

------------------------------------------------------------
-- EXERCISE 6: find_leaks(f) — catch forgotten `local`s
------------------------------------------------------------
-- Write find_leaks(f): call f() and return a SORTED array of the names
-- of every NEW global f created. Recipe (lesson 05 §3):
--   1. save getmetatable(_G), arm a __newindex that records the name
--      and rawset()s the value through,
--   2. call f with pcall (so a crash can't leave _G booby-trapped),
--   3. restore the saved metatable, delete the leaked globals,
--   4. table.sort the names; rethrow f's error if there was one.
local function find_leaks(f)
  -- TODO: the four steps above (~12 lines).
end

-- This intentionally-buggy function is your test subject:
local function buggy()
  leak_b = 2                -- oops, no `local`
  local fine = 1            -- this one is properly local
  leak_a = fine + 1         -- oops again
end

-- TEST (un-comment):
-- local names = find_leaks(buggy)
-- print("E6:", #names == 2, names[1] == "leak_a", names[2] == "leak_b",
--       rawget(_G, "leak_a") == nil, rawget(_G, "leak_b") == nil)
print("E6: TODO")

------------------------------------------------------------
-- EXERCISE 7 (the sting): config round-trip through build/
------------------------------------------------------------
-- The full pipeline, module-05 edition. Given this data:
local sections = {
  { name = "general",
    settings = { { "gaps_in", 3 }, { "gaps_out", 3 }, { "border_size", 1 } } },
  { name = "decoration",
    settings = { { "rounding", 10 }, { "active_opacity", "0.75" } } },
}
-- (a) render(secs) → one string of Hyprland-style text:
--         general {
--             gaps_in = 3
--             ...
--         }
--     Build lines in a table, table.concat once (lesson 06 §5).
-- (b) Write it to build_dir .. "/exercise_roundtrip.conf" with the
--     assert(io.open(...)) idiom; don't forget f:close().
-- (c) parse(path) → nested table: result.general.gaps_in == "3" etc.
--     Read with io.lines, keep a "current section" variable, and
--     recognize three line shapes ("name {", "}", "key = value") after
--     stripping # comments; skip blank lines. On any OTHER line,
--     error() with a TABLE { line = n, text = line } (lesson 01 §6) so
--     the caller can report the exact line number.
local function render(secs)
  -- TODO
end

local function parse(path)
  -- TODO
end

-- TEST (un-comment):
-- local conf_path = build_dir .. "/exercise_roundtrip.conf"
-- local f = assert(io.open(conf_path, "w"))
-- f:write(render(sections))
-- f:close()
-- local parsed = parse(conf_path)
-- -- Now a malformed file must produce a structured error:
-- local bad_path = build_dir .. "/exercise_bad.conf"
-- local bf = assert(io.open(bad_path, "w"))
-- bf:write("general {\n    gaps_in = 3\n    what even is this line\n}\n")
-- bf:close()
-- local okbad, eobj = pcall(parse, bad_path)
-- print("E7:", parsed.general.gaps_in == "3",
--       parsed.decoration.rounding == "10",
--       parsed.decoration.active_opacity == "0.75",
--       okbad == false, type(eobj) == "table", eobj.line == 3)
print("E7: TODO")

print("\nDone. Un-comment tests as you solve; compare with solutions.lua when stuck.")
