----------------------------------------------------------------------
-- 03_dsl.lua — An ergonomic layer on top of the serializer
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Constructor functions: bind(...) and monitor{ named = fields }
--   • The f{...} call — Lua lets you drop parens around a table argument
--   • Metatables doing real work: __tostring/__concat for $variables,
--     __index for methods, __call for a touch of sugar
--   • A Config object that remembers insertion order (fixing pairs() for good)
--   • Proving a refactor safe: assert(old_output == new_output)
-- HOW TO RUN
--   luajit 03_dsl.lua                   (from this directory)
--   or inside nvim:  :luafile %          (with this file open)
-- PREREQUISITES: 02_serializer.lua, module 04 (metatables)
----------------------------------------------------------------------

------------------------------------------------------------ 1. Reuse lesson 02
-- dofile() runs a file and hands us its return value — the serializer's
-- export table. We locate it relative to THIS script via arg[0], so it
-- works from any working directory.
local here = ((arg and arg[0]) or ""):match("^(.*[/\\])") or "./"
local S = dofile(here .. "02_serializer.lua")

------------------------------------------------------------ 2. Why bother with a DSL?
-- Lesson 02 already works, but writing raw strings has two problems:
--   "eDP-1, 1920x1080@60, 0x0, 1"   -- which field is which? what if you
--                                   -- forget the scale? typo the comma?
--   "$minMod, Q, exec, ghostty"     -- typo'd variable: hyprland fails at
--                                   -- runtime, Lua never noticed.
-- A DSL = small functions + metatables that construct those strings FOR
-- you, catching mistakes at generation time (assert) instead of WM-reload
-- time. Same output, safer fingers.

------------------------------------------------------------ 3. Var: a $variable that renders itself
local Var = {}
Var.__index = Var                     -- method lookup (module 04)

-- __tostring: what tostring(v) — and therefore our serializer — prints.
Var.__tostring = function(v) return "$" .. v.name end

-- __concat: lets `mod .. " SHIFT"` build "$mainMod SHIFT". Lua consults
-- this metamethod whenever either side of .. is not a string/number.
Var.__concat = function(a, b) return tostring(a) .. tostring(b) end

function Var.new(name, value)
  assert(name:match("^[%w_]+$"), "bad variable name: " .. tostring(name))
  return setmetatable({ name = name, value = value }, Var)
end

------------------------------------------------------------ 4. bind(): the 4-tuple, checked
-- bind = MODS, key, dispatcher, params
local function bind(mods, key, dispatcher, ...)
  assert(dispatcher and dispatcher ~= "", "bind() needs a dispatcher")
  local parts = { tostring(mods), tostring(key), dispatcher }
  local n = select("#", ...)                    -- vararg count (module 02)
  for i = 1, n do
    parts[#parts + 1] = tostring((select(i, ...)))
  end
  local line = table.concat(parts, ", ")
  if n == 0 then
    line = line .. ","   -- hyprland's default config writes `killactive,` —
                         -- the comma marks "no params". Optional; kept for
                         -- smaller diffs against real-world configs.
  end
  return line
end

------------------------------------------------------------ 5. monitor{}: named fields, sane defaults
-- Lua sugar: when a function's only argument is a table literal (or a
-- string), the parentheses are optional — monitor{ name = "eDP-1" } is
-- exactly monitor({ name = "eDP-1" }). This is THE trick behind every
-- Lua DSL you've seen (lazy.nvim specs included).
local function monitor(spec)
  assert(type(spec) == "table" and spec.name, "monitor{} needs a name field")
  local res = spec.res or "preferred"
  if spec.hz then res = res .. "@" .. spec.hz end
  return string.format("%s, %s, %s, %s",
                       spec.name, res, spec.pos or "auto", spec.scale or 1)
end

------------------------------------------------------------ 6. Config: a model that remembers order
-- The plain model needed a hand-written __order list. The Config object
-- builds it automatically: first time you touch a top-level key, it's
-- appended to __order. Insertion order preserved — pairs() finally tamed.
local Config = {}
Config.__index = Config

function Config.new()
  return setmetatable({ model = { __order = {} } }, Config)
end

function Config:_remember(key)               -- leading _ = "private by convention"
  if self.model[key] == nil then
    local order = self.model.__order
    order[#order + 1] = key
  end
end

-- Scalars and whole sections: conf:set("general", { gaps_in = 3 })
function Config:set(key, value)
  self:_remember(key)
  self.model[key] = value
  return self                                -- returning self enables chaining
end

-- Repeated keys: conf:add("exec-once", "waybar", "hyprpaper")
function Config:add(key, ...)
  self:_remember(key)
  local list = self.model[key] or {}
  self.model[key] = list
  for i = 1, select("#", ...) do
    list[#list + 1] = tostring((select(i, ...)))   -- tostring: Var objects render here
  end
  return self
end

-- Variables: registers `$name = value` AND hands back a Var to use in binds.
function Config:var(name, value)
  local v = Var.new(name, value)
  self:set("$" .. name, value)
  return v
end

function Config:render()
  return S.serialize(self.model)
end

function Config:write(filename)
  return S.write(filename, self:render())
end

------------------------------------------------------------ 7. Demo + proof of equivalence
local IS_MAIN = ((arg and arg[0]) or ""):find("03_dsl", 1, true) ~= nil

if IS_MAIN then
  -- (a) lesson 02's demo model, hand-written (comments omitted):
  local plain = {
    __order = { "$mainMod", "monitor", "exec-once", "general", "bind" },
    ["$mainMod"] = "SUPER",
    monitor = {
      "eDP-1, 1920x1080@60, 0x0, 1",
      "DP-1, 2560x1440@60, auto-up, 1",
    },
    ["exec-once"] = { "waybar", "hyprpaper" },
    general = { gaps_in = 3, gaps_out = 3, border_size = 1,
                resize_on_border = true, layout = "dwindle" },
    bind = {
      "$mainMod, Q, exec, ghostty",
      "$mainMod, C, killactive,",
    },
  }

  -- (b) the same thing through the DSL — no raw strings, no __order:
  local conf = Config.new()
  local mod = conf:var("mainMod", "SUPER")
  print("mod renders as:      " .. tostring(mod))
  print("mod .. ' SHIFT' ->   " .. (mod .. " SHIFT"))     -- __concat at work

  conf:add("monitor",
      monitor{ name = "eDP-1", res = "1920x1080", hz = 60, pos = "0x0" },
      monitor{ name = "DP-1",  res = "2560x1440", hz = 60, pos = "auto-up" })
  conf:add("exec-once", "waybar"):add("exec-once", "hyprpaper")  -- chaining
  conf:set("general", { gaps_in = 3, gaps_out = 3, border_size = 1,
                        resize_on_border = true, layout = "dwindle" })
  conf:add("bind",
      bind(mod, "Q", "exec", "ghostty"),
      bind(mod, "C", "killactive"))

  -- (c) the payoff: byte-identical output. This is how you refactor a
  -- generator fearlessly — keep the old path around and assert equality.
  local old, new = S.serialize(plain), conf:render()
  assert(old == new, "DSL output diverged from the plain model!")
  print("\nDSL output is byte-identical to lesson 02's model. Proof:")
  print(new)

  -- The DSL also catches mistakes early — via pcall so we still exit 0:
  local ok, err = pcall(monitor, { res = "1920x1080" })  -- forgot name
  print("monitor{} without a name ->", ok, err)

  local path = conf:write("hyprland.conf")
  print("wrote " .. path)
end

------------------------------------------------------------ TRY IT
-- 1. Add `pos = "auto-left"` to a third monitor{} line and re-run. Then
--    delete the res field: what default kicks in, and is it valid hyprlang?
-- 2. Give Var a __eq metamethod so two Vars with the same name compare
--    equal, and test it with assert.
-- 3. Break the equality proof on purpose (change one gaps_in to 4) and
--    read the failure. Cheap regression tests like this are the reason
--    the DSL can keep evolving in lesson 04 and the exercises.

------------------------------------------------------------ 8. Export for lesson 04 + exercises
local M = {
  Config    = Config,
  Var       = Var,
  bind      = bind,
  monitor   = monitor,
  serialize = S.serialize,
  write     = S.write,
  BUILD     = S.BUILD,
}
-- __call sugar: hypr() reads better than hypr.Config.new() in a config file.
return setmetatable(M, { __call = function() return Config.new() end })
