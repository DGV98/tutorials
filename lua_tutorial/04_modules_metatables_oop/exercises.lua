----------------------------------------------------------------------
-- exercises.lua — Modules, metatables, and OOP: your turn
----------------------------------------------------------------------
-- HOW TO WORK
--   Fill in each TODO, then un-comment the test lines under it and run:
--     luajit exercises.lua           (from this directory)
--   The file runs clean as-is; every un-commented test should keep it
--   that way. Solutions live in solutions.lua — struggle first.
-- PREREQUISITES: lessons 01–05 of this module
----------------------------------------------------------------------

-- Path setup so require() can find mylib/ regardless of where you run
-- this from (see 01_modules.lua §2; the guard covers :luafile in nvim,
-- where arg[0] is nil — there, run from this directory):
local here = (arg and arg[0] or ""):match("(.*[/\\])") or "./"
package.path = here .. "?.lua;" .. here .. "?/init.lua;" .. package.path

print("== exercises: modules, metatables, oop ==\n")

------------------------------------------------------------
-- EXERCISE 1: reload(name) — beat the require cache
------------------------------------------------------------
-- Write reload(name): evict `name` from package.loaded, require it
-- again, and return the fresh module. This is THE debugging move for
-- editing nvim config without restarting.
local function reload(name)
  -- TODO: 2 lines. (Lesson 01 §5.)
end

-- TEST (un-comment): requiring twice normally prints "loaded fresh"
-- only once; your reload must make it print again.
-- local g1 = require("mylib.greet")
-- local g2 = reload("mylib.greet")
-- print("E1:", g1 ~= g2, "(true means reload returned a FRESH table)")
print("E1: TODO")

------------------------------------------------------------
-- EXERCISE 2: counter table with a default of 0
------------------------------------------------------------
-- Build `counts` so that reading ANY missing key gives 0 (not nil),
-- then count the words of the sentence below in one clean loop —
-- no `or 0` allowed anywhere.
local sentence = "big gaps small gaps big blur big"

-- TODO: local counts = setmetatable(...)
-- TODO: loop with sentence:gmatch("%a+") and do counts[w] = counts[w] + 1
--       (gmatch = iterate every pattern match, one word per loop turn;
--       lesson 05 §1 shows the exact loop — patterns proper: module 05)

-- TEST (un-comment):
-- print("E2:", counts.big == 3, counts.gaps == 2, counts.nope == 0)
print("E2: TODO")

------------------------------------------------------------
-- EXERCISE 3: a table that computes — env
------------------------------------------------------------
-- Make `env` behave like a read-only view of os.getenv: env.HOME
-- returns os.getenv("HOME"), env.SHELL returns os.getenv("SHELL"),
-- for any key, without storing anything. (Just like vim.env in nvim.)
-- Bonus thought: why must __index be a function here, not a table?

-- TODO: local env = setmetatable({}, ...)

-- TEST (un-comment):
-- print("E3:", env.HOME == os.getenv("HOME"), rawget(env, "HOME") == nil)
print("E3: TODO")

------------------------------------------------------------
-- EXERCISE 4: finish the Vector
------------------------------------------------------------
-- Below is the Vector from lesson 03, stripped down. Add:
--   • __div  : v / 2       → vec(v.x/2, v.y/2)  (scalar on the right only)
--   • __concat : "at " .. v and v .. "!" must BOTH work — check which
--     operand is the string (lesson 03 §3 did this dance for __mul)
--   • __eq   : value equality
local Vector = {}
Vector.__index = Vector
local function vec(x, y) return setmetatable({ x = x, y = y }, Vector) end
function Vector.__tostring(v) return ("(%g, %g)"):format(v.x, v.y) end

-- TODO: Vector.__div = ...
-- TODO: Vector.__concat = ...
-- TODO: Vector.__eq = ...

-- TEST (un-comment):
-- local v = vec(8, 6)
-- print("E4:", tostring(v / 2) == "(4, 3)",
--       ("at " .. v) == "at (8, 6)",
--       (v .. "!") == "(8, 6)!",
--       v == vec(8, 6))
print("E4: TODO")

------------------------------------------------------------
-- EXERCISE 5: a Stack class
------------------------------------------------------------
-- Standard class pattern (lesson 04 §2). Build Stack with:
--   Stack.new()      → empty stack
--   s:push(v)        → adds on top
--   s:pop()          → removes and RETURNS the top (nil when empty)
--   s:peek()         → returns top without removing
--   s:size()         → item count
-- Store items in self.items; #self.items is your friend.
local Stack = {}
-- TODO: Stack.__index = ...
-- TODO: constructor + four methods

-- TEST (un-comment):
-- local s = Stack.new()
-- s:push("a"); s:push("b"); s:push("c")
-- print("E5:", s:size() == 3, s:pop() == "c", s:peek() == "b",
--       s:size() == 2, Stack.new():pop() == nil)
print("E5: TODO")

------------------------------------------------------------
-- EXERCISE 6: inheritance — Shape → Circle
------------------------------------------------------------
-- Shape.new(name) stores the name; Shape:describe() returns
-- "shape: <name>". Circle inherits from Shape (lesson 04 §4):
--   Circle.new(radius) → a Shape named "circle" with a radius field
--   Circle:area()      → math.pi * r^2
--   Circle:describe()  → Shape's describe PLUS " r=<radius>", by
--                        calling the parent's method explicitly.
local Shape = {}
Shape.__index = Shape
-- TODO: Shape.new, Shape:describe

local Circle -- = setmetatable(...)
-- TODO: wire Circle to Shape, then Circle.new, Circle:area, Circle:describe

-- TEST (un-comment):
-- local c = Circle.new(2)
-- print("E6:", c:describe() == "shape: circle r=2",
--       math.floor(c:area()) == 12,
--       Shape.new("blob"):describe() == "shape: blob")
print("E6: TODO")

------------------------------------------------------------
-- EXERCISE 7 (the sting): a class() factory
------------------------------------------------------------
-- Every plugin author rebuilds lesson 04 by hand. Build the generator:
--   local Animal = class()          → a fresh class
--   local Dog    = class(Animal)    → a subclass
-- Requirements:
--   • Calling the CLASS constructs an instance: Animal("Rex") — so the
--     class table needs __call in ITS metatable (lesson 03 §2), which
--     is ALSO where the parent fallback lives (lesson 04 §4). One
--     metatable, two jobs.
--   • If the class (or an ancestor) defines :init(...), the constructor
--     calls it with the arguments.
--   • Methods inherit; instances answer to child methods first.
-- Sketch: class(parent) → C; C.__index = C;
--         setmetatable(C, { __index = parent, __call = ... })
local function class(parent)
  -- TODO: ~7 lines that replace lesson 04 entirely.
end

-- TEST (un-comment):
-- local Animal = class()
-- function Animal:init(name) self.name = name end
-- function Animal:speak() return self.name .. " makes a sound" end
-- local Dog = class(Animal)
-- function Dog:speak() return Animal.speak(self) .. ": woof" end
-- local rex = Dog("Rex")
-- print("E7:", rex.name == "Rex",
--       rex:speak() == "Rex makes a sound: woof",
--       Animal("Cow"):speak() == "Cow makes a sound")
print("E7: TODO")

print("\nDone. Un-comment tests as you solve; compare with solutions.lua when stuck.")
