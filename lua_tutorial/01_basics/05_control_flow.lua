----------------------------------------------------------------------
-- 05_control_flow.lua — if, loops, and truthiness
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • if / elseif / else
--   • Truthiness: ONLY nil and false are falsy (0 and "" are TRUE!)
--   • while, repeat/until, and the numeric for loop
--   • break — and the goto-based "continue" idiom
-- HOW TO RUN
--   luajit 05_control_flow.lua       (from this directory)
--   or inside nvim:  :luafile %      (with this file open)
-- PREREQUISITES: 04_numbers_and_math.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. if / elseif / else
-- Shape: if COND then ... elseif COND then ... else ... end
-- No parentheses needed around the condition, no braces — the block
-- runs from `then` to the matching `end`. It's bash's if/elif/else/fi
-- with `then`+`end` instead of `then`+`fi`, and real expressions
-- instead of [ ] tests.

local hour = 14
if hour < 12 then
  print("morning")
elseif hour < 18 then
  print("afternoon")     -- this one prints
else
  print("evening")
end

-- Note it's `elseif`, one word. `else if` also compiles but nests a
-- second if inside the else — meaning you'd need one extra `end` per
-- branch. Use `elseif`.

------------------------------------------------------------ 2. Truthiness — READ THIS TWICE
-- In a condition, ONLY two values count as false: nil and false.
-- EVERYTHING else is true. Including 0. Including "".
--
--   bash: [ -z "$s" ] treats empty as false-ish; C treats 0 as false.
--   Lua:  0 is true. "" is true. "false" (a string!) is true.
--
-- This is the #1 beginner bug source coming from bash/C. Burn it in:

-- (This defines a tiny helper function so the demo reads clearly.
-- Functions get their own module next, 02_functions — for now just read
-- truthy(v) as "run the if-test on v and hand back a string".)
local function truthy(v)
  if v then return "TRUE" else return "false" end
end
print("nil    ->", truthy(nil))
print("false  ->", truthy(false))
print("0      ->", truthy(0))        -- TRUE!
print("\"\"     ->", truthy(""))       -- TRUE!
print("\"false\"->", truthy("false")) -- TRUE! (non-empty string)

-- The payoff: `if x then` is the idiomatic "does x exist?" test,
-- because unset variables are nil. In Neovim config terms:
--   if vim.g.loaded_myplugin then return end   -- "already loaded?"
-- But when 0 or false are VALID values for x, you must compare
-- explicitly: `if x ~= nil then`. Lesson 06 digs into this trap.

------------------------------------------------------------ 3. while
-- while COND do ... end — checks the condition BEFORE each pass:

local n = 1
while n <= 5 do
  io.write(n, " ")   -- io.write = print without the newline/tabs
  n = n * 2
end
print("<- while doubled n until it passed 5")

------------------------------------------------------------ 4. repeat / until
-- repeat ... until COND — the body always runs at LEAST once, and the
-- loop stops when COND becomes TRUE (mind the inversion vs while!).
-- Like bash's until-loop, but test-at-the-bottom.

local tries = 0
repeat
  tries = tries + 1
until tries >= 3
print("repeat ran", tries, "times")

-- Use it when "do the thing, then check if it worked" is the natural
-- order — e.g. keep generating a filename until it's unused.

------------------------------------------------------------ 5. Numeric for
-- for VAR = start, stop, step do ... end
-- Counts from start to stop INCLUSIVE. step is optional (default 1).
-- It's `for i in {1..5}` from zsh, with a real step and real numbers.

io.write("up:   ")
for i = 1, 5 do io.write(i, " ") end
print()

io.write("down: ")
for i = 10, 0, -2 do io.write(i, " ") end
print()

io.write("floats work: ")
for x = 0, 1, 0.25 do io.write(x, " ") end
print()

-- The loop variable is automatically LOCAL to the loop and gone after:
for i = 1, 3 do end
print("i after the loop:", i)   -- nil — no leak, unlike bash's $i

-- Also: reassigning the loop variable inside the body does NOT change
-- the iteration count; the start/stop/step are fixed on entry.
--
-- (There is a second `for` — `for k, v in pairs(t)` — for walking
-- tables. That's module 03, taught alongside tables themselves.)

------------------------------------------------------------ 6. break
-- break exits the INNERMOST loop immediately. Same word as bash.

local found
for i = 1, 100 do
  if i * i > 50 then
    found = i
    break
  end
end
print("first n with n^2 > 50:", found)

-- There is no `break 2` to leave nested loops (bash has that); the
-- clean Lua answers are a function+return (later) or goto (below).

------------------------------------------------------------ 7. continue — the goto idiom
-- Lua has NO `continue` keyword. The idiom is a goto that jumps to a
-- label at the BOTTOM of the loop body:
--
-- LUA VERSION NOTE: goto was added in Lua 5.2, so plain Lua 5.1 lacks
-- it — but LuaJIT backported it, so it works in Neovim and here. If a
-- style guide says "Lua 5.1 has no goto", Neovim is the exception.

io.write("odd numbers only: ")
for i = 1, 10 do
  if i % 2 == 0 then goto continue end   -- skip the rest of this pass
  io.write(i, " ")
  ::continue::   -- a label: any name between double colons
end
print()

-- Rules of the road: the label must be the LAST thing in the loop body
-- (a label can close a block even after local declarations), you can
-- only jump forward/outward sensibly, and `continue` is just a
-- conventional label name — ::skip:: works the same. Use this idiom
-- sparingly; often flipping the if is cleaner:
io.write("same, no goto:    ")
for i = 1, 10 do
  if i % 2 ~= 0 then
    io.write(i, " ")
  end
end
print()

------------------------------------------------------------ 8. Putting it together: FizzBuzz
-- The classic. Multiples of 3 print Fizz, of 5 Buzz, of both FizzBuzz.
-- Note the ORDER: the combined case must be tested first.

for i = 1, 15 do
  if i % 15 == 0 then
    io.write("FizzBuzz ")
  elseif i % 3 == 0 then
    io.write("Fizz ")
  elseif i % 5 == 0 then
    io.write("Buzz ")
  else
    io.write(i, " ")
  end
end
print()

----------------------------------------------------------------------
-- TRY IT
-- 1. In section 2, predict then verify: what does truthy(0/0) print?
--    (NaN from lesson 04 — is it falsy?)
-- 2. Rewrite the `while` in section 3 as a numeric for... you can't,
--    directly (the step isn't constant — it doubles). Rewrite it as
--    repeat/until instead and match the output.
-- 3. Change section 7's goto loop to skip multiples of 3 instead.
-- 4. Extend FizzBuzz to 1..30 and add "Bazz" for multiples of 7 (and
--    think about what 21 = 3*7 should print — order matters!).
----------------------------------------------------------------------
