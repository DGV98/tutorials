----------------------------------------------------------------------
-- 02_string_patterns.lua — Lua patterns (they are NOT regex)
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Why Lua patterns are a smaller, different beast than regex
--   • Character classes: %a %d %s %w (and their UPPERCASE opposites)
--   • Anchors ^ $, and the quantifiers * + ? and the lazy -
--   • Captures () and string.match / gmatch / gsub
--   • gsub with a FUNCTION as the replacement
--   • Escaping magic characters with % — and %% for a literal %
--   • Parsing "key = value" config lines (Hyprland-style) for real
-- HOW TO RUN
--   luajit 02_string_patterns.lua     (from this directory)
--   or inside nvim:  :luafile %       (with this file open)
-- PREREQUISITES: 01_error_handling.lua, module 01 strings lesson
----------------------------------------------------------------------

------------------------------------------------------------ 1. Not regex
-- Lua ships PATTERNS, not POSIX/PCRE regex. If you know grep/sed:
--   • NO alternation:        a|b        does not exist
--   • NO counted repeats:    a{2,5}     does not exist
--   • NO groups-as-units:    (ab)+      () only CAPTURES, can't repeat
--   • % is the escape char, not \       (%d not \d, %. not \.)
-- What you get instead is small, fast, and built into every string.
-- The magic characters are:  ( ) . % + - * ? [ ] ^ $
-- Everything else matches itself literally.

print("1a plain find:", string.find("hyprland.conf", "conf"))  -- start, end indexes

------------------------------------------------------------ 2. Character classes
--   .   any character            %a  letter        %d  digit
--   %s  whitespace               %w  alphanumeric  %l  lowercase
--   %u  uppercase                %p  punctuation   %x  hex digit
-- UPPERCASE class = complement:  %A  non-letter,  %D  non-digit,  %S
-- non-space... Sets: [abc], ranges [0-9a-f], negated [^,]
-- string.match(s, pat) returns the matched text (or captures) or nil.

print("2a first digit:", string.match("eDP-1 at 1920x0", "%d"))
print("2b first digit-run:", string.match("eDP-1 at 1920x0", "%d+"))
-- 2b prints "1" — the 1 inside "eDP-1"! Matching scans left to right and
-- takes the FIRST place the pattern fits, not the longest one anywhere.
print("2c first digit-run:", string.match("at 1920x0", "%d+"))   -- now 1920
print("2d first word:", string.match("  gaps_in = 3", "%w+"))   -- _ counts? no:
-- careful — %w is letters+digits ONLY. For identifiers use a set:
print("2e identifier:", string.match("  gaps_in = 3", "[%w_]+"))
print("2f non-space run:", string.match("  active_opacity 0.75", "%S+"))

------------------------------------------------------------ 3. Anchors and quantifiers
--   ^  at pattern start = "match must start at position 1"
--   $  at pattern end   = "match must end at the string's end"
-- Quantifiers (apply to ONE class/char, not a group):
--   *  zero or more, GREEDY (longest)      +  one or more, greedy
--   ?  zero or one                         -  zero or more, LAZY (shortest)
-- The - is the one regex people trip over: it's Lua's non-greedy star.

local line = "monitor = eDP-1, 1920x1080@60, 0x0, 1"
print("3a starts with 'monitor'?", string.match(line, "^monitor") ~= nil)
print("3b greedy  .*,:", string.match(line, "= (.*),"))  -- up to the LAST comma
print("3c lazy    .-,:", string.match(line, "= (.-),"))  -- up to the FIRST comma
-- Classic use of lazy -: strip one comment, match a quoted string, etc.
print("3d comment body:", string.match("exec = waybar # status bar", "#%s*(.*)$"))

------------------------------------------------------------ 4. Captures
-- Parentheses capture what they enclose; match returns the captures
-- instead of the whole match. Multiple captures return multiple values.

local key, value = string.match("border_size = 1", "^([%w_]+)%s*=%s*(.+)$")
print("4a key/value:", key, value)
-- ([%w_]+), not (%w+) — remember 2d: %w alone would stop at the "_" and
-- the whole pattern would fail on "border_size". This trap is eternal.

-- %1 in a pattern back-references capture 1 (rarely needed, nice to know):
print("4b doubled word:", string.match("the the end", "(%w+) %1"))

-- An EMPTY capture () captures the current POSITION (a number):
local pos = string.match("gaps_out = 3", "()=")
print("4c '=' is at index:", pos)

------------------------------------------------------------ 5. gmatch — iterate all matches
-- string.gmatch returns an ITERATOR (lesson 03 explains that machinery)
-- that yields each match in turn. Perfect for splitting.

local monitors = "eDP-1,DP-1,DP-4,DP-3,HDMI-A-1"
for name in string.gmatch(monitors, "[^,]+") do   -- runs of non-commas
  print("5a monitor:", name)
end

-- With captures, gmatch yields the captures each round:
local settings = "gaps_in=3 gaps_out=3 border_size=1"
for k, v in string.gmatch(settings, "([%w_]+)=(%d+)") do
  print("5b pair:", k, v)
end

------------------------------------------------------------ 6. gsub — search & replace
-- string.gsub(s, pat, repl [, n]) returns the NEW string and the count
-- of replacements. repl can be:
--   • a string ("%1" refers to capture 1, "%0" to the whole match)
--   • a table  (looked up by the capture)
--   • a FUNCTION (called with the captures; its return replaces)

local s1, n1 = string.gsub("gaps_in = 3", "%d+", "10")
print("6a string repl:", s1, "(" .. n1 .. " changed)")

print("6b swap:", (string.gsub("key = value", "(%w+) = (%w+)", "%2 = %1")))

-- Table replacement: great for variable expansion.
local vars = { term = "ghostty", editor = "nvim" }
print("6c table repl:", (string.gsub("exec = $term -e $editor", "%$(%w+)", vars)))

-- FUNCTION replacement: the powerhouse. Return a string to substitute;
-- return nil/false to keep the original text untouched.
local upper_keys = string.gsub("gaps_in=3 border_size=1", "([%w_]+)=",
  function(k) return k:upper() .. "=" end)
print("6d fn repl:", upper_keys)

-- (Why the extra parens in 6b/6c? gsub returns TWO values; the parens
--  keep only the first so print doesn't also show the count.)

------------------------------------------------------------ 7. Escaping magic characters
-- To match a magic char literally, prefix it with %:
--   %.  literal dot     %%  literal percent     %-  literal dash
print("7a version:", string.match("nvim-0.12.4", "%d+%.%d+%.%d+"))
print("7b percent:", string.match("opacity is 75% today", "%d+%%"))
-- In a gsub REPLACEMENT string, % is also special (%1 etc.), so a
-- literal % there must be written %% too:
print("7c repl escape:", (string.gsub("0.75", "0%.75", "75%%")))

-- Escaping an ARBITRARY string to use inside a pattern (handy when the
-- needle comes from user input): escape every non-alphanumeric char.
local function pattern_escape(s)
  return (string.gsub(s, "%W", "%%%0"))   -- %W = non-alphanumeric
end
print("7d escaped:", pattern_escape("1920x1080@60 (main)"))
-- Alternative: string.find(s, needle, 1, true) — the 4th arg turns OFF
-- patterns entirely ("plain find"). Often the simplest fix.
print("7e plain find:", string.find("a.b.c", ".b.", 1, true))

------------------------------------------------------------ 8. Real work: parsing config lines
-- This is the exact shape of your hyprland.conf. Parse it: strip
-- comments, trim whitespace, split "key = value", skip blanks.

local config = [[
# gaps and borders
general_gaps_in = 3
general_border_size = 1        # thin border
decoration_rounding = 10

decoration_active_opacity = 0.75
]]

local function trim(s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))   -- lazy - keeps it minimal
end

local parsed = {}
for cfg_line in string.gmatch(config, "[^\n]+") do        -- split into lines
  local no_comment = string.gsub(cfg_line, "#.*$", "")    -- strip # comments
  local k, v = string.match(no_comment, "^%s*([%w_]+)%s*=%s*(.-)%s*$")
  if k then
    parsed[k] = v
    print("8a parsed:", k, "=>", v)
  end
end
print("8b lookup:", parsed.decoration_rounding)  -- "10" — still a STRING!
print("8c as number:", tonumber(parsed.decoration_rounding) + 5)

------------------------------------------------------------ TRY IT
-- 1. In section 3, change the lazy "-" in 3c to "*" and predict the
--    output before running. Then explain 3b's answer to yourself.
-- 2. Write a pattern that pulls WIDTH and HEIGHT as two captures from
--    "1920x1080@60" and print them separately.
-- 3. Extend section 8 to convert values that LOOK numeric with
--    tonumber() at parse time (hint: tonumber returns nil on failure).
-- 4. Use gsub with a function to censor every digit in a string with
--    "#" — then do it again with a plain string replacement. Which is
--    shorter and why did the function version still work?
