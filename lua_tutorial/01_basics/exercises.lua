----------------------------------------------------------------------
-- exercises.lua — Module 01: Lua fundamentals
----------------------------------------------------------------------
-- Work through these IN ORDER; they ramp up. Everything you need is in
-- lessons 01–06 of this module. Replace the TODO parts, re-run after
-- each exercise:
--   luajit exercises.lua
-- The file runs clean as-is — your job is to make it print the right
-- things, not to make it stop crashing. Solutions in solutions.lua
-- (no peeking until you've fought each one for a few minutes).
----------------------------------------------------------------------

print("== EXERCISE 1: introduce yourself =====================")
-- Lessons 01–02. Declare three locals: your name (string), your shell
-- (string), and the year you first used Linux (number). Print one line:
--   david uses zsh (since 2015)
-- built with .. concatenation. Then print the type() of each variable.

-- TODO: your code here

print("== EXERCISE 2: path surgery ===========================")
-- Lesson 03. From this path, using string library functions:
local path = "/home/david/.config/hypr/hyprland.conf"
-- (a) print just the filename        -> hyprland.conf
-- (b) print just the extension       -> conf
-- (c) print the filename UPPERCASED, without its extension -> HYPRLAND
-- Hints: string.match with "[^/]+$" gets the filename; from there
-- match "%w+" or use find/sub around the dot.

-- TODO: your code here

print("== EXERCISE 3: aligned status lines ===================")
-- Lesson 03 (string.format). Print these three programs and their
-- memory use as neatly aligned columns, one format string reused
-- three times — name left-aligned in 10 columns, number right-aligned
-- with one decimal place, like:
--   waybar      |   42.5 MB
--   hyprpaper   |   12.0 MB
--   nvim        |  156.3 MB
local prog1, mem1 = "waybar", 42.5
local prog2, mem2 = "hyprpaper", 12
local prog3, mem3 = "nvim", 156.31

-- TODO: your code here

print("== EXERCISE 4: uptime formatter =======================")
-- Lesson 04. Turn this many seconds into days, hours, minutes, seconds
-- using ONLY math.floor and %. Print exactly:
--   1d 03h 46m 40s
-- with string.format ("%02d" pads the small fields).
local uptime = 100000

-- TODO: your code here

print("== EXERCISE 5: skip list ==============================")
-- Lesson 05. Print the numbers 1..20 on ONE line (io.write), but skip
-- multiples of 4 — using the goto continue idiom (yes, even though a
-- flipped if would work: the point is to practice the idiom).
-- Expected: 1 2 3 5 6 7 9 10 11 13 14 15 17 18 19

-- TODO: your code here
print()  -- keep this: ends the io.write line

print("== EXERCISE 6: truthiness lie detector ================")
-- Lessons 05–06. A bash-brained coworker wrote this check for "the
-- user gave no input":
local user_input = ""       -- also test with: nil, "0", "text"
if user_input then
  print("BUGGY check says: got input:", user_input)
else
  print("BUGGY check says: no input")
end
-- (a) Run it. Why does "" count as input here even though it's empty?
-- (b) Write a CORRECT check below: treat both nil and "" as "no
--     input", anything else as input. Re-test with all four values.

-- TODO: your correct check here

print("== EXERCISE 7: the false-proof default (stinger) ======")
-- Lesson 06. Settings can come from three places, first one set wins:
-- the user's config, the project's config, then the built-in default.
local user_animations = false     -- user EXPLICITLY disabled animations
local project_animations = true
local builtin_animations = true
--
-- (a) First try the "obvious" one-liner and print it:
--       local animations = user_animations or project_animations or builtin_animations
--     What do you get? Why is it wrong? (The user said false!)
-- (b) Now write it correctly: pick the first value that is NOT NIL
--     (false must win over the fallbacks). if/elseif is fine.
--     Print the result — it must be false.
-- (c) Prove your version still works when the user is silent: set
--     user_animations = nil, project_animations = false → expect false;
--     and all three nil... wait, builtin is never nil. Make sure
--     nil, nil, true → true.

-- TODO: your code here

print("== done — compare with solutions.lua ==================")
