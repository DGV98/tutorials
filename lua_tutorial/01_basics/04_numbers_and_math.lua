----------------------------------------------------------------------
-- 04_numbers_and_math.lua — Numbers, arithmetic, and math.*
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • In LuaJIT every number is a double — there is no integer type
--   • Arithmetic, and why there's no // (use math.floor(a/b))
--   • The % modulo operator and its sign behavior
--   • The math library tour: floor, ceil, abs, min/max, random, huge...
--   • Converting: tonumber() and tostring()
-- HOW TO RUN
--   luajit 04_numbers_and_math.lua   (from this directory)
--   or inside nvim:  :luafile %      (with this file open)
-- PREREQUISITES: 03_strings.lua (string.format is used for output here)
----------------------------------------------------------------------

------------------------------------------------------------ 1. One number type: double
-- In LuaJIT (= Lua 5.1 = what Neovim runs), EVERY number is an IEEE-754
-- double-precision float. 1 and 1.0 are literally the same value:

print("1 == 1.0?", 1 == 1.0)
print("type of both:", type(1), type(1.0))

-- Integer-valued doubles print without a decimal point, so it FEELS like
-- integers exist. They don't. Doubles represent integers exactly up to
-- 2^53 (about 9 quadrillion), so for config work this never bites.
print("looks like an int:", 2 ^ 46)     -- 70368744177664, no decimal point
-- Display wrinkle: print() shows ~14 significant digits, so a value as
-- big as 2^53 falls back to scientific notation EVEN THOUGH it is stored
-- exactly. string.format("%d", ...) (lesson 03) prints every digit:
print("2^53 via print:  ", 2 ^ 53)                       -- 9.007199254741e+15
print("2^53 exactly:    ", string.format("%d", 2 ^ 53))  -- 9007199254740992

-- LUA VERSION NOTE: Lua 5.3+ added a real integer subtype and
-- math.type() to tell them apart. Blog posts mentioning "integer
-- division //", "math.type", or "integer overflow" are talking about
-- 5.3+/5.4 — none of that exists in Neovim's LuaJIT:
print("math.type exists here?", math.type)   -- nil

------------------------------------------------------------ 2. Arithmetic
-- + - * / work as expected. ^ is exponentiation (NOT xor like in C).
-- Division is ALWAYS float division, like bc, not like $(( )) in bash:

print("7 / 2   =", 7 / 2)          -- 3.5  (bash $((7/2)) would say 3)
print("2 ^ 10  =", 2 ^ 10)
print("-2 ^ 2  =", -2 ^ 2)         -- -4! ^ binds tighter than unary minus

-- Number literals: decimals, exponents, and hex all work:
print("literals:", 0.5, 1e3, 0xFF)

------------------------------------------------------------ 3. No // — use math.floor
-- LUA VERSION NOTE: the // integer-division operator is Lua 5.3+.
-- In LuaJIT it's a SYNTAX ERROR. The idiom is math.floor(a / b):

print("floor(7 / 2)  =", math.floor(7 / 2))    -- 3
print("floor(-7 / 2) =", math.floor(-7 / 2))   -- -4 (floors toward -inf)

-- We can prove // is a syntax error without crashing the file, using
-- loadstring (compile a string as a chunk; returns nil + error if bad):
local chunk, err = loadstring("return 7 // 2")
print("compiling '7 // 2':", chunk, err)

-- Same story for bitwise ops: 5.3's & | ~ << >> don't exist here.
-- LuaJIT ships a `bit` library instead (bit.band, bit.bor, bit.lshift...)
-- — noted here so you recognize it; you rarely need it for configs.

------------------------------------------------------------ 4. Modulo %
-- a % b is the remainder, defined as: a - math.floor(a/b) * b.
-- The result takes the SIGN OF THE DIVISOR (unlike C, same as Python):

print("10 % 3  =", 10 % 3)
print("-7 % 3  =", -7 % 3)         -- 2, not -1! sign follows the 3
print("7.5 % 2 =", 7.5 % 2)        -- works on floats too: 1.5

-- Classic uses: cycling through a range (i % n), and digit/time math:
local seconds = 9042
local h = math.floor(seconds / 3600)
local m = math.floor(seconds % 3600 / 60)
local sec = seconds % 60
print(string.format("9042s = %d:%02d:%02d", h, m, sec))

------------------------------------------------------------ 5. The math library tour
print("floor / ceil:  ", math.floor(3.7), math.ceil(3.2))
print("abs:           ", math.abs(-5))
print("min / max:     ", math.min(3, 1, 4), math.max(3, 1, 4))
print("sqrt:          ", math.sqrt(2))
print("pi:            ", math.pi)
print("huge (infinity):", math.huge, -math.huge)

-- 0/0 is NaN ("not a number") — the only value that isn't equal to itself.
-- That inequality IS the standard NaN test:
local nan = 0 / 0
print("nan:", nan, "  nan == nan?", nan == nan)

-- Random numbers: seed once per program, then draw.
math.randomseed(os.time())            -- os.time() = seconds since epoch
print("random():      ", math.random())        -- float in [0, 1)
print("random(6):     ", math.random(6))        -- integer 1..6 (dice)
print("random(10, 20):", math.random(10, 20))   -- integer in range

------------------------------------------------------------ 6. Floats have float problems
-- The classic: 0.1 has no exact binary representation.

print("0.1 + 0.2 == 0.3?", 0.1 + 0.2 == 0.3)              -- false!
print("the actual sum:   ", string.format("%.17g", 0.1 + 0.2))

-- Rule of thumb: never == compare computed floats; compare the distance:
local close_enough = math.abs((0.1 + 0.2) - 0.3) < 1e-9
print("close enough?     ", close_enough)
-- Integer-valued math (counts, sizes, indices) is exact — only fractions
-- misbehave. Your gaps_in=3 will never turn into 2.9999.

------------------------------------------------------------ 7. tonumber and tostring
-- tonumber(s) parses a string into a number, returning NIL (not an
-- error) if it can't. That nil-on-failure shape is very Lua — you'll
-- test it with `if` constantly when reading config values:

print("tonumber('42')    =", tonumber("42"))
print("tonumber(' 3.5 ') =", tonumber(" 3.5 "))     -- whitespace ok
print("tonumber('0x1F')  =", tonumber("0x1F"))      -- hex works
print("tonumber('12px')  =", tonumber("12px"))      -- nil: trailing junk
print("tonumber('ten')   =", tonumber("ten"))       -- nil

-- Optional second argument = base:
print("tonumber('1010', 2) =", tonumber("1010", 2)) -- 10

-- tostring(v) turns ANYTHING into a string (print uses it internally):
print("tostring(3.5) .. '!' =", tostring(3.5) .. "!")

-- Lua auto-coerces between strings and numbers in arithmetic and ..,
-- but leaning on that is sloppy; convert explicitly at the boundary
-- (e.g. right after reading a line from a config file) and pass real
-- numbers around after that.
print("'10' + 5 =", "10" + 5)      -- works, but write tonumber('10') + 5

----------------------------------------------------------------------
-- TRY IT
-- 1. Compute how many milliseconds one frame lasts at 180 Hz (your DP-4
--    monitor's refresh rate) and print it with %.3f.
-- 2. Use math.floor and % to convert 100000 seconds into days/h/m/s.
-- 3. Predict math.floor(-0.5) and math.ceil(-0.5), then print them.
-- 4. tonumber("0.75") parses your hyprland active_opacity. What does
--    tonumber("0.75 # comment") give? How would you fix the input with
--    string.match before parsing? (Hint: "%d+%.?%d*")
----------------------------------------------------------------------
