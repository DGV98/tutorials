----------------------------------------------------------------------
-- 06_logic_and_idioms.lua — and/or, defaults, and comparison rules
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • and / or return their OPERANDS, not booleans (short-circuit)
--   • The x = x or default idiom (all over Neovim plugins)
--   • The cond and a or b "ternary" — and its famous false/nil pitfall
--   • == and ~=, and Lua's strict comparison rules
-- HOW TO RUN
--   luajit 06_logic_and_idioms.lua   (from this directory)
--   or inside nvim:  :luafile %      (with this file open)
-- PREREQUISITES: 05_control_flow.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. and / or return VALUES
-- Lua spells them as words: and, or, not (no && || !).
-- The crucial part: `and` and `or` don't return true/false — they
-- return ONE OF THEIR OPERANDS, using the truthiness rules from
-- lesson 05 (only nil and false are falsy):
--
--   a and b   → if a is falsy, result is a; otherwise result is b
--   a or  b   → if a is truthy, result is a; otherwise result is b
--
-- Exactly like bash's `cmd1 && cmd2` / `cmd1 || cmd2`: the second
-- operand only runs when needed (SHORT-CIRCUIT), and the "result" is
-- whatever the deciding side produced.

print("1 and 2:      ", 1 and 2)          -- 2   (1 truthy → evaluate b)
print("nil and 2:    ", nil and 2)        -- nil (a falsy → stop, return a)
print("false and 2:  ", false and 2)      -- false
print("1 or 2:       ", 1 or 2)           -- 1   (a truthy → stop, return a)
print("nil or 'plan B':", nil or "plan B")

-- `not` DOES return a real boolean:
print("not nil:      ", not nil, "   not 0:", not 0)   -- true, false (0 truthy!)
-- Idiom: `not not x` collapses any value to a clean true/false.
print("not not 'hi': ", not not "hi")

-- Short-circuit proof: the right side never even runs when the left
-- side decides. error() would crash the program — but it's never called:
local safe = false and error("this never runs")
print("short-circuit safe:", safe)

------------------------------------------------------------ 2. x = x or default
-- THE most common Lua idiom. Since `or` returns its left operand when
-- truthy and the right one otherwise, this fills in a default:

local gaps          -- imagine this came from a config file... it's nil
gaps = gaps or 3
print("gaps:", gaps)

local border = 1    -- this one WAS set
border = border or 999
print("border:", border)   -- keeps 1; the default is ignored

-- It's ${VAR:-default} from your shell. You'll see it in every plugin:
--   opts = opts or {}
--   vim.g.mapleader = vim.g.mapleader or " "
--
-- CAVEAT (this lesson's theme): `or` replaces nil AND false. If false
-- is a meaningful value — very common for on/off settings! — this idiom
-- silently overrides the user's explicit false:
local transparent = false          -- the user said NO transparency
local wrong = transparent or true  -- ...and we just steamrolled them
print("user said false, idiom gave:", wrong)
-- The nil-only-safe version spells it out:
local right = transparent
if right == nil then right = true end
print("nil-check version keeps:", right)

------------------------------------------------------------ 3. The and/or "ternary"
-- Lua has no  cond ? a : b  operator. The classic substitute chains
-- the section-1 rules:
--
--   cond and a or b
--
-- Read it left to right: if cond is truthy → (a or b) with a decided
-- first... in practice: truthy cond gives a, falsy cond gives b.

local hour = 14
local part = hour < 12 and "AM" or "PM"
print("14h is:", part)

local n = 1
print(string.format("%d file%s", n, n == 1 and "" or "s"))  -- pluralizing

------------------------------------------------------------ 4. ...and its famous pitfall
-- The ternary breaks when `a` — the value you want on TRUE — is itself
-- false or nil. Then `cond and a` is falsy, the `or` fires anyway, and
-- you ALWAYS get b, no matter what cond said:

local is_laptop = true
-- We WANT: laptop → false (no fancy blur), desktop → true.
local blur = is_laptop and false or true
print("expected false, got:   ", blur)    -- true. WRONG — the b branch fired!

-- Even though is_laptop is true: (true and false) is false, so `or`
-- hands us true. The condition was simply ignored.
--
-- Fixes, most idiomatic first:
-- (1) Flip the condition so the false lands in the b slot:
local blur1 = not is_laptop and true or false
print("flip-the-cond fix:     ", blur1)
-- ...here that's just a negation, so simpler still: local blur = not is_laptop
-- (2) When neither branch can safely be falsy, use a plain if:
local blur2
if is_laptop then blur2 = false else blur2 = true end
print("plain if fix:          ", blur2)
--
-- RULE: `cond and a or b` is fine ONLY when `a` can never be false/nil.
-- Strings and numbers (even 0 and "" — truthy, remember) are safe;
-- booleans and maybe-nil variables are not. When in doubt, use if.

------------------------------------------------------------ 5. == and ~=
-- Equality is == ; INEQUALITY IS ~= (tilde, not !=). Muscle-memory
-- alert: != is a syntax error, and in Vim regexland ~ means "match",
-- so read ~= as "not equal" and move on.

print("1 == 1:      ", 1 == 1)
print("1 ~= 2:      ", 1 ~= 2)
print("'a' ~= 'b':  ", "a" ~= "b")

-- Values of DIFFERENT types are never equal — no coercion happens:
print("42 == '42':  ", 42 == "42")       -- false! number vs string
print("nil == false:", nil == false)     -- false! (lesson 02 flashback)
-- Compare this with bash's [ "$x" = "42" ] where everything's a string.
-- Corollary: tonumber() what you read from files BEFORE comparing.

------------------------------------------------------------ 6. Ordering comparisons: strict
-- < <= > >= work within one type: numbers by value, strings
-- alphabetically (byte order, so uppercase sorts before lowercase):

print("3 < 10:        ", 3 < 10)
print("'abc' < 'abd': ", "abc" < "abd")
print("'Z' < 'a':     ", "Z" < "a")     -- true: byte 90 < byte 97

-- Mixing types in an ORDERING comparison is a hard ERROR, not false —
-- unlike ==. Caught with pcall (our seatbelt from lesson 03):
local ok, err = pcall(function() return 1 < "2" end)
print("1 < '2' worked?", ok, "->", err)
-- Bash quietly does string comparison when you meant numeric ([ 9 \> 10 ]
-- is true!); Lua refuses to guess. The error names the two types, which
-- makes this one of the friendlier bugs to track down.

------------------------------------------------------------ 7. Idiom round-up (spot these in the wild)
local user_setting = nil     -- pretend these came from a config table
local detected = "tokyonight"

-- (a) default chain: first truthy value wins, like ${A:-${B:-fallback}}
local theme = user_setting or detected or "default"
print("theme:        ", theme)

-- (b) guard: only touch x.y if x exists (short-circuit as nil-check)
local config = nil
local width = config and config.width or 80
print("width:        ", width)   -- no crash: `config and` stopped early
-- (Careful — that's the ternary shape, so it also has the section-4
-- pitfall if config.width could legitimately be false.)

-- (c) boolean-normalize before comparing/printing:
local raw = "yes"
print("as boolean:   ", not not raw)

----------------------------------------------------------------------
-- TRY IT
-- 1. Predict, then print:  nil and 1,  nil or false,  false or nil,
--    0 and "zero". Three of these return a falsy value — which three?
-- 2. Rewrite lesson 05's time-of-day if/elseif as a nested ternary:
--    hour < 12 and "morning" or hour < 18 and "afternoon" or "evening".
--    Is THIS one safe from the pitfall? Why? (What types are a and b?)
-- 3. Write the section-2 default pattern for a setting `animations`
--    that must default to true but respect an explicit false. Test all
--    three inputs: nil, false, true.
-- 4. Predict: does ("10" == 10) error or return false? And ("10" < 10)?
--    Verify both (pcall the second one).
----------------------------------------------------------------------
