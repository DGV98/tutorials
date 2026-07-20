----------------------------------------------------------------------
-- 03_strings.lua — Strings and the string library
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Quoting styles: "double", 'single', and [[long strings]]
--   • Escapes, concatenation with .., length with #
--   • Strings are immutable — methods return NEW strings
--   • The core string library: sub, upper, lower, rep, format, find, match
--   • The s:method() colon sugar you'll see everywhere in Neovim configs
-- HOW TO RUN
--   luajit 03_strings.lua            (from this directory)
--   or inside nvim:  :luafile %      (with this file open)
-- PREREQUISITES: 02_variables_and_types.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. Quoting styles
-- Double and single quotes are IDENTICAL in Lua — no bash-style
-- "interpolation in double, literal in single" difference. Pick one and
-- be consistent; use the other when your text contains your quote char.

local d = "double quotes"
local s = 'single quotes'
local mixed = 'she said "hello"'      -- no escaping needed this way
print(d, "|", s)
print("mixed:", mixed)

-- There is NO variable interpolation at all: "$name" is just five chars.
-- You build strings with concatenation (section 3) or format (section 6).

------------------------------------------------------------ 2. Long strings [[...]]
-- Double square brackets make a "long string": multi-line, and NO escape
-- sequences are processed — like a quoted heredoc (<<'EOF') in bash.

local block = [[
line one
line two, with \n printed literally and "quotes" needing no escape
]]
print("long string:")
print(block)

-- Same equals-sign trick as block comments: [==[ ... ]==] lets the text
-- contain ]] unescaped. You'll use long strings in your config for things
-- like vim.cmd([[colorscheme tokyonight-night]]) — exactly this syntax.
local tricky = [==[ this contains ]] safely ]==]
print("tricky:", tricky)

-- Gotcha: a newline IMMEDIATELY after [[ is skipped (that's why `block`
-- above doesn't start with a blank line).

------------------------------------------------------------ 3. Escapes and concatenation
-- In normal quotes, backslash escapes work like you'd expect:
--   \n newline   \t tab   \\ backslash   \" quote   \065 byte by decimal

print("escapes:", "a\tb\nsecond line, quote: \" backslash: \\")

-- Concatenation uses .. (two dots) — NOT +. Numbers are auto-converted:
local user = "david"
print("greeting: " .. "hello, " .. user)
print("mixing types: " .. 2 .. " dots for concat")   -- number → string

-- But + on strings is an ERROR (bash would happily mash text together;
-- Lua wants you to be explicit). We PROVE it with pcall, Lua's "try":
-- pcall(f) calls f and returns false + the error message instead of
-- crashing. You'll learn it properly later; for now it's our seatbelt.
local ok, err = pcall(function() return "1" + "abc" end)
print("'1' + 'abc' worked?", ok, "->", err)

------------------------------------------------------------ 4. Length and immutability
-- #s is the length of s in BYTES (like ${#var} in bash):

local word = "hyprland"
print("length of " .. word .. ":", #word)
print("empty string length:", #"")

-- Byte, not character: UTF-8 chars can be several bytes. Fine for config
-- work; know it exists ("ü" is 2 bytes long, not 1).

-- Strings are IMMUTABLE: no function changes a string in place — they
-- all return a NEW string, and the original is untouched:
local original = "immutable"
local shouty = string.upper(original)
print("original:", original)     -- unchanged
print("new value:", shouty)
-- Consequence: you always ASSIGN the result. string.upper(x) alone,
-- without `x = ...`, does nothing useful.

------------------------------------------------------------ 5. The string library: the greatest hits
-- All functions live in the `string` table. Indices are 1-BASED (first
-- char is 1, not 0) and negative counts from the end (-1 = last char).

local path = "/home/david/.config/nvim/init.lua"

-- string.sub(s, i, j) — substring from i to j inclusive (like ${var:off:len})
print("sub(1, 5):     ", string.sub(path, 1, 5))
print("sub(-8):       ", string.sub(path, -8))      -- last 8 chars
print("upper/lower:   ", string.upper("shout"), string.lower("WHISPER"))
print("rep('-', 20):  ", string.rep("-", 20))       -- great for dividers

------------------------------------------------------------ 6. string.format — printf for Lua
-- Same directives as printf(1) in your shell: %s string, %d integer,
-- %f float, %x hex, %% literal percent. Widths and padding work too.

print(string.format("format: %s uses %d%% of %s", "waybar", 3, "one core"))
print(string.format("padded: |%-10s|%10s|", "left", "right"))
print(string.format("floats: %.2f  hex: 0x%X  zero-pad: %04d", math.pi, 255, 42))
-- This is THE tool for building aligned output and config lines --
-- module 08 generates hyprland.conf lines exactly this way.

------------------------------------------------------------ 7. find and match — a first taste of patterns
-- string.find(s, pat) returns the START and END positions of the first
-- match (or nil). string.match(s, pat) returns the matched TEXT itself.
-- Patterns are Lua's regex-lite (they use % where regex uses \):
--   %a letter   %d digit   %w alphanumeric   %s space   .  any char
--   +  one or more   *  zero or more   (...)  capture

print("find 'nvim':   ", string.find(path, "nvim"))          -- 21 24
print("match filename:", string.match(path, "[^/]+$"))       -- init.lua
print("match version: ", string.match("NVIM v0.12.4", "%d+%.%d+%.%d+"))

-- Captures pull out pieces — here's a hyprland.conf-style line.
-- (Note [%w_]: %w alone means letters+digits, NOT underscore — with
-- plain %w+ this would match just "size"!)
local key, value = string.match("border_size = 1", "([%w_]+)%s*=%s*(%w+)")
print("parsed:        ", key, "->", value)
-- Patterns get a full lesson in module 05; find/match/sub cover 90% of
-- config parsing until then.

------------------------------------------------------------ 8. The colon sugar: s:method()
-- Because every string shares the `string` table as its methods, you can
-- call library functions ON the string with a colon:
--
--   string.upper(s)   ==   s:upper()      (the colon passes s for you)

local branch = "feature/lua-course"
print("colon sugar:   ", branch:upper())
-- gsub = global replace. It returns TWO values (result, replacement
-- count); the extra parentheses keep only the first one:
print("chains nicely: ", (branch:sub(9):gsub("-", " ")))
print("on literals:   ", ("%d ms"):format(16))          -- parens required!
-- A bare literal like "hi":upper() is a syntax error; wrap it in parens.
-- Neovim configs use colon style almost exclusively — read
-- `line:match("^%s*$")` as `string.match(line, "^%s*$")`.

----------------------------------------------------------------------
-- TRY IT
-- 1. Build `local me = "..."` from your username and hostname using ..
--    and print it as user@host, then redo it with string.format.
-- 2. Use path:match with a pattern to extract "nvim" (the directory name
--    between the last two slashes). Hint: "([^/]+)/[^/]+$".
-- 3. Print a right-aligned table of three program names using
--    string.format("%12s", ...) — one per line.
-- 4. Predict what #"\n" and #[[a
--    b]] are, then print them to check.
----------------------------------------------------------------------
