----------------------------------------------------------------------
-- solutions.lua — Modules, metatables, and OOP: worked solutions
----------------------------------------------------------------------
-- HOW TO RUN
--   luajit solutions.lua             (from this directory)
-- Every test prints trues. Read the "key insight" comment on each one.
----------------------------------------------------------------------

-- (arg-guard: :luafile in nvim doesn't set arg[0]; see 01_modules.lua §2)
local here = (arg and arg[0] or ""):match("(.*[/\\])") or "./"
package.path = here .. "?.lua;" .. here .. "?/init.lua;" .. package.path

print("== solutions: modules, metatables, oop ==\n")

------------------------------------------------------------
-- EXERCISE 1: reload(name)
------------------------------------------------------------
-- Key insight: require consults package.loaded FIRST; nil-ing the entry
-- is the only lever you need. (In nvim: package.loaded["me.opts"] = nil.)
local function reload(name)
  package.loaded[name] = nil
  return require(name)
end

local g1 = require("mylib.greet")      -- prints "loaded fresh" (first load)
local g2 = reload("mylib.greet")       -- prints it AGAIN — cache beaten
print("E1:", g1 ~= g2, "(true means reload returned a FRESH table)")

------------------------------------------------------------
-- EXERCISE 2: counter with default 0
------------------------------------------------------------
-- Key insight: __index answers READS of missing keys; the WRITE then
-- stores a real value, so the default never shadows real counts.
local sentence = "big gaps small gaps big blur big"
local counts = setmetatable({}, { __index = function() return 0 end })
for w in sentence:gmatch("%a+") do  -- gmatch: iterate every match (module 05)
  counts[w] = counts[w] + 1
end
print("E2:", counts.big == 3, counts.gaps == 2, counts.nope == 0)

------------------------------------------------------------
-- EXERCISE 3: env — a computing table
------------------------------------------------------------
-- Key insight: __index must be a FUNCTION because the answers can't be
-- enumerated up front — they depend on the key at read time. A table
-- form of __index can only hold pre-known values. vim.env, vim.fn and
-- vim.bo all need the function form for exactly this reason.
local env = setmetatable({}, {
  __index = function(_, k) return os.getenv(k) end,
})
print("E3:", env.HOME == os.getenv("HOME"), rawget(env, "HOME") == nil)

------------------------------------------------------------
-- EXERCISE 4: finish the Vector
------------------------------------------------------------
local Vector = {}
Vector.__index = Vector
local function vec(x, y) return setmetatable({ x = x, y = y }, Vector) end
function Vector.__tostring(v) return ("(%g, %g)"):format(v.x, v.y) end

function Vector.__div(v, n)
  return vec(v.x / n, v.y / n)
end

-- Key insight: __concat fires with the operands IN ORDER, and either
-- one may be the string. tostring() the vector, concat the rest as-is.
function Vector.__concat(a, b)
  if getmetatable(a) == Vector then a = tostring(a) end
  if getmetatable(b) == Vector then b = tostring(b) end
  return a .. b
end

-- Key insight: __eq only runs when BOTH operands are tables sharing
-- this metamethod (Lua 5.1 rule), so inside it we can assume fields exist.
function Vector.__eq(a, b)
  return a.x == b.x and a.y == b.y
end

local v = vec(8, 6)
print("E4:", tostring(v / 2) == "(4, 3)",
      ("at " .. v) == "at (8, 6)",
      (v .. "!") == "(8, 6)!",
      v == vec(8, 6))

------------------------------------------------------------
-- EXERCISE 5: Stack class
------------------------------------------------------------
-- Key insight: nothing here is special-cased — it's lesson 04 §2
-- verbatim. self.items[#self.items] is idiomatic top-of-stack.
local Stack = {}
Stack.__index = Stack

function Stack.new()
  return setmetatable({ items = {} }, Stack)
end

function Stack:push(v)
  self.items[#self.items + 1] = v
end

function Stack:pop()
  local top = self.items[#self.items]
  self.items[#self.items] = nil       -- remove AFTER reading
  return top
end

function Stack:peek()
  return self.items[#self.items]
end

function Stack:size()
  return #self.items
end

local s = Stack.new()
s:push("a"); s:push("b"); s:push("c")
print("E5:", s:size() == 3, s:pop() == "c", s:peek() == "b",
      s:size() == 2, Stack.new():pop() == nil)

------------------------------------------------------------
-- EXERCISE 6: Shape → Circle
------------------------------------------------------------
local Shape = {}
Shape.__index = Shape

function Shape.new(name)
  return setmetatable({ name = name }, Shape)
end

function Shape:describe()
  return "shape: " .. self.name
end

-- Key insight: two wirings, two jobs — the class falls back to Shape
-- (setmetatable line), instances fall back to Circle (__index line).
local Circle = setmetatable({}, { __index = Shape })
Circle.__index = Circle

function Circle.new(radius)
  local self = Shape.new("circle")     -- reuse the parent constructor
  self.radius = radius
  return setmetatable(self, Circle)    -- then re-tag as Circle
end

function Circle:area()
  return math.pi * self.radius ^ 2
end

function Circle:describe()
  -- "super call": name the parent explicitly, pass self yourself.
  return Shape.describe(self) .. " r=" .. self.radius
end

local c = Circle.new(2)
print("E6:", c:describe() == "shape: circle r=2",
      math.floor(c:area()) == 12,
      Shape.new("blob"):describe() == "shape: blob")

------------------------------------------------------------
-- EXERCISE 7: class() factory
------------------------------------------------------------
-- Key insight: the class's OWN metatable carries both inheritance
-- (__index = parent) and construction (__call). The instance's
-- metatable is the class itself. Two layers, cleanly separated:
--   instance --__index--> Class --__index--> parent --> ...
-- `self.init` is found through that same chain, so subclasses inherit
-- constructors for free.
local function class(parent)
  local C = {}
  C.__index = C
  return setmetatable(C, {
    __index = parent,
    __call = function(cls, ...)
      local self = setmetatable({}, cls)
      if self.init then self.init(self, ...) end
      return self
    end,
  })
end

local Animal = class()
function Animal:init(name) self.name = name end
function Animal:speak() return self.name .. " makes a sound" end

local Dog = class(Animal)
function Dog:speak() return Animal.speak(self) .. ": woof" end

local rex = Dog("Rex")                 -- __call fires, finds Animal.init via the chain
print("E7:", rex.name == "Rex",
      rex:speak() == "Rex makes a sound: woof",
      Animal("Cow"):speak() == "Cow makes a sound")

print("\nAll trues above = all exercises verified.")
