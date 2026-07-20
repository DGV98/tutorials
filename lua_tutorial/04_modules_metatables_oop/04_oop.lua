----------------------------------------------------------------------
-- 04_oop.lua — Classes the Lua way: Class.__index = Class, :, self, inheritance
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Lua has no `class` keyword — classes are a PATTERN built from
--     tables + __index, and you now know both halves
--   • The standard pattern: Class.__index = Class + a new() constructor
--   • Methods with `:` and `self` — and what the colon ACTUALLY desugars to
--   • Single inheritance via setmetatable(Child, {__index = Parent})
--   • Overriding methods and calling the parent's version
-- HOW TO RUN
--   luajit 04_oop.lua                (from this directory)
--   or inside nvim:  :luafile %      (with this file open)
-- PREREQUISITES: 02_metatables_index.lua, 03_metamethods.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. The idea in one breath
-- An "object" is a table holding data. A "class" is a table holding
-- methods. The link between them is one line:
--
--     setmetatable(object, Class)  where  Class.__index = Class
--
-- Read it as: "object, when asked for a key you don't have (a method),
-- go look in Class." That's the whole trick. Ten thousand plugins,
-- one line of machinery.

------------------------------------------------------------ 2. The standard class pattern
local Window = {}            -- the class: will hold methods
Window.__index = Window      -- the load-bearing line. Window doubles as
                             -- a metatable whose __index points to itself,
                             -- so instances fall back to Window for methods.

-- Constructor. By convention called `new`, defined with a dot, taking
-- explicit arguments. (Some codebases write Window:new() — see §5.)
function Window.new(title, width, height)
  local self = setmetatable({}, Window)   -- fresh table, wired to the class
  self.title = title
  self.width = width or 80
  self.height = height or 24
  return self
end

-- Methods, defined with a COLON. The colon quietly adds a first
-- parameter named `self` — these two definitions are identical:
--   function Window:area()            function Window.area(self)
function Window:area()
  return self.width * self.height
end

function Window:describe()
  return ("%s [%dx%d]"):format(self.title, self.width, self.height)
end

function Window:resize(w, h)
  self.width, self.height = w, h
end

local w1 = Window.new("nvim", 120, 40)
local w2 = Window.new("ghostty")
print("class pattern:")
print("  w1:", w1:describe(), "area:", w1:area())
print("  w2:", w2:describe(), "area:", w2:area())
w1:resize(200, 50)
print("  w1 resized:", w1:describe())
-- Each instance has its OWN data (title, width...) but they SHARE one
-- copy of every method, found via __index. Nothing is copied per object.
print("  methods shared:", rawget(w1, "area") == nil, "(area lives on Window, not w1)")

------------------------------------------------------------ 3. What the colon desugars to
-- CALL-side:        w1:resize(200, 50)   is exactly   w1.resize(w1, 200, 50)
-- DEFINITION-side:  function Window:area() ... end
--            is exactly   function Window.area(self) ... end
-- The colon is pure sugar for "pass the thing left of the colon as the
-- first argument, named self". Prove it by calling a method both ways:
print("\ncolon desugaring:")
print("  w1:area()        →", w1:area())
print("  w1.area(w1)      →", w1.area(w1))     -- identical call, spelled out

-- The classic bug: calling a method with a DOT but no explicit self.
-- Then `self` inside is whatever you passed first — here, nothing (nil):
local ok, err = pcall(function() return w1.area() end)  -- forgot w1!
print("  w1.area() (dot, no self) →", ok, err)
-- When an nvim error says "attempt to index local 'self' (a nil value)",
-- THIS is what happened — somewhere, a `.` should have been a `:` (or a
-- callback got detached from its object; wrap it: function() obj:m() end).

------------------------------------------------------------ 4. Single inheritance
-- A child class is a table that falls back to the parent for anything
-- it doesn't define. Same fallback-chain from lesson 02, one level more:
local FloatingWindow = setmetatable({}, { __index = Window })
FloatingWindow.__index = FloatingWindow
-- Two DIFFERENT metatable jobs, easy to conflate:
--   • setmetatable(FloatingWindow, {__index = Window}) — the CLASS falls
--     back to Window, so method lookup climbs child → parent.
--   • FloatingWindow.__index = FloatingWindow — INSTANCES fall back to
--     the child class first.
-- Lookup for inst:describe(): inst → FloatingWindow (its __index) →
-- Window (FloatingWindow's metatable __index). Chain, not copies.

function FloatingWindow.new(title, width, height, border)
  local self = Window.new(title, width, height)   -- reuse parent constructor...
  self.border = border or "single"                -- ...add child-specific state...
  return setmetatable(self, FloatingWindow)       -- ...then re-tag as child
end

-- Override + extend: call the parent's version explicitly through the
-- parent table. (No `super` keyword in Lua; you name the parent.)
function FloatingWindow:describe()
  return Window.describe(self) .. " {float, border=" .. self.border .. "}"
end

function FloatingWindow:set_border(b)
  self.border = b
end

local f = FloatingWindow.new("telescope", 100, 30)
f:set_border("rounded")                -- child-only method
print("\ninheritance:")
print("  f:describe():", f:describe()) -- overridden, calls parent inside
print("  f:area():    ", f:area())     -- inherited straight from Window
print("  f is a FloatingWindow:", getmetatable(f) == FloatingWindow)
-- A poor man's `instanceof` walks the chain — handy when debugging:
local function is_a(obj, class)
  local mt = getmetatable(obj)
  while mt do
    if mt == class then return true end
    local parent_mt = getmetatable(mt)
    mt = parent_mt and parent_mt.__index
  end
  return false
end
print("  is_a(f, Window):", is_a(f, Window))
print("  is_a(w1, FloatingWindow):", is_a(w1, FloatingWindow))

------------------------------------------------------------ 5. Reading other people's classes
-- Plugin code varies in spelling but not in machinery. You'll see:
--   • function Obj:new(o) o = o or {}; setmetatable(o, self);
--     self.__index = self; return o end        ← the PiL-book style;
--     colon constructor doubles as inheritance hook.
--   • local Class = require("plenary.class") / middleclass / classic —
--     tiny libraries that generate this exact pattern.
--   • lazy.nvim, telescope, lualine: grep their source for "__index"
--     and you'll recognize every line now.
-- There is no other OOP in Lua — it's this pattern wearing different
-- jackets. Learn to spot `X.__index = X` and you can read any of them.
print("\n(section 5 is commentary — see comments)")

----------------------------------------------------------------------
-- TRY IT
-- 1. Add Window:is_wide() returning true when width > 100, and call it
--    on w1, w2, and f. Which table does the lookup end in for f?
-- 2. Write Shape → Circle: Shape.new(name), Shape:describe() prints the
--    name; Circle overrides describe() to add its radius and defines
--    area() using math.pi. Reuse Shape.new inside Circle.new like §4.
-- 3. Break it on purpose: comment out `FloatingWindow.__index =
--     FloatingWindow` and predict which call in section 4 fails, then run.
-- 4. Give Window a __tostring metamethod (lesson 03) so print(w1) shows
--    describe()'s output. Hint: Window is ALREADY the instances'
--    metatable, so just define Window.__tostring.
----------------------------------------------------------------------
