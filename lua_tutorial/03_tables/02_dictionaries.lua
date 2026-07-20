----------------------------------------------------------------------
-- 02_dictionaries.lua — Tables as dictionaries (key/value maps)
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • String keys: the { key = value } constructor.
--   • t.x is sugar for t["x"] — and when only brackets will do.
--   • pairs() walks EVERY key... in NO guaranteed order.
--   • Keys can be any type (except nil): numbers, booleans, even tables.
--   • Assigning nil to a key DELETES it.
--   • Mixed tables: array part + hash part in one table — the shape of
--     every lazy.nvim plugin spec.
-- HOW TO RUN
--   luajit 02_dictionaries.lua       (from this directory)
--   or inside nvim:  :luafile %      (with this file open)
-- PREREQUISITES: 01_arrays.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. Key = value: a config section IS a dictionary
-- Look at the general{} block in your hyprland.conf:
--
--     general {
--         gaps_in = 3
--         gaps_out = 3
--         border_size = 1
--         resize_on_border = true
--         layout = dwindle
--     }
--
-- That is, character for character, almost valid Lua. As a table:
local general = {
  gaps_in = 3,
  gaps_out = 3,
  border_size = 1,
  resize_on_border = true,
  layout = "dwindle",     -- strings need quotes in Lua; hyprland's don't
}
-- The only differences: commas between entries, and quoted strings.
-- This is why Lua makes such a good config language — and why module 08
-- can generate your hyprland.conf FROM tables like this one.

print("gaps_in:      ", general.gaps_in)
print("layout:       ", general.layout)
print("resize border:", general.resize_on_border)

------------------------------------------------------------ 2. t.x is sugar for t["x"]
-- These two lines read the exact same entry:
print("dot syntax:    ", general.border_size)
print("bracket syntax:", general["border_size"])

-- The dot form only works when the key is a string that would be a
-- valid identifier (letters, digits, underscores; not starting with a
-- digit). Brackets are the general form and handle everything else:

local waybar_modules = {}
-- Waybar module names contain slashes and dashes — dot syntax can't
-- express these, brackets can:
waybar_modules["custom/power"] = { format = "⏻" }
waybar_modules["battery"]      = { format = "{capacity}%" }
print("custom/power format:", waybar_modules["custom/power"].format)
-- waybar_modules.custom/power  ← syntax error: Lua reads that as
-- (waybar_modules.custom) / (power), a division!

-- Brackets are also how you use a key stored in a VARIABLE:
local which = "gaps_out"
print("dynamic lookup of '" .. which .. "':", general[which])
-- general.which would look up the literal key "which" (nil here).
-- Rule of thumb: dot for keys you know while writing the code,
-- brackets for keys that arrive at runtime.

-- In constructors, the bracket form lets you build non-identifier keys:
local binds = {
  ["SUPER, Q"]      = "killactive",
  ["SUPER, Return"] = "exec, ghostty",
}
print("SUPER, Q does:", binds["SUPER, Q"])

------------------------------------------------------------ 3. pairs() — every key, NO promised order
-- ipairs only walks 1, 2, 3, ... — it sees NOTHING in a dictionary
-- like `general`. To visit string keys you need pairs():
print("-- general section via pairs() --")
for key, value in pairs(general) do
  print("  " .. key .. " = " .. tostring(value))
end

-- IMPORTANT: the order you just saw is whatever the hash table felt
-- like. It can differ between runs, between machines, and after
-- adding/removing keys. NEVER write code that depends on pairs()
-- order. If order matters (it does when generating a config file you
-- want to diff!), collect the keys, sort them, then loop:
local keys = {}
for key in pairs(general) do        -- you may ignore the second value
  table.insert(keys, key)
end
table.sort(keys)
print("-- same section, deterministic order --")
for _, key in ipairs(keys) do
  print("  " .. key .. " = " .. tostring(general[key]))
end
-- (The `_` name is the Lua convention for "I must accept this variable
--  but I don't care about it" — you'll see it everywhere in plugins.)

------------------------------------------------------------ 4. Keys can be (almost) any type
-- Any value except nil can be a key. NaN is also banned (it isn't
-- equal to itself, so you could never find the entry again).
local grab_bag = {}
grab_bag["name"] = "string key"
grab_bag[42]     = "number key"
grab_bag[true]   = "boolean key"
local marker = {}                -- even a table can be a key!
grab_bag[marker] = "table key"
print("42 →", grab_bag[42], "| true →", grab_bag[true], "| marker →", grab_bag[marker])

-- Trap: the STRING "1" and the NUMBER 1 are different keys.
local t = {}
t[1]   = "number one"
t["1"] = "string one"
print('t[1] vs t["1"]:', t[1], "|", t["1"])
-- Bites hard when keys come from user input or file parsing, where
-- everything arrives as a string. Convert deliberately with tonumber().

------------------------------------------------------------ 5. Assigning nil DELETES a key
-- There is no delete() function. Setting a key to nil removes it:
local decoration = {
  rounding = 10,
  active_opacity = 0.75,
  inactive_opacity = 0.6,
  drop_shadow = true,      -- pretend this option was removed upstream
}
print("before delete, drop_shadow =", decoration.drop_shadow)
decoration.drop_shadow = nil          -- gone.
print("after delete,  drop_shadow =", decoration.drop_shadow)

-- Flip side: reading a key that was never set is ALSO nil, not an
-- error. "Absent" and "set to nil" are indistinguishable in Lua.
-- That's why plugin docs say "set option x to false to disable" —
-- false is storable, nil means "not configured, use the default".
print("false vs nil:", decoration.rounding ~= nil, decoration.no_such_key ~= nil)

-- Count keys with pairs (there's no # for dictionaries — # counts only
-- the array part):
local count = 0
for _ in pairs(decoration) do count = count + 1 end
print("decoration now has", count, "keys; #decoration is", #decoration)

------------------------------------------------------------ 6. Mixed tables: array part + hash part
-- One table can hold BOTH list items and named keys. This isn't a
-- hack — it's the designed shape of a lazy.nvim plugin spec:
local telescope_spec = {
  "nvim-telescope/telescope.nvim",        -- [1]: positional item
  "nvim-lua/plenary.nvim",                -- [2]: positional item
  name = "telescope",                     -- named keys ride alongside
  lazy = true,
  opts = { defaults = { layout_strategy = "flex" } },
}
-- lazy.nvim reads spec[1] as the repo, and .name/.lazy/.opts as config.
print("repo (index 1):  ", telescope_spec[1])
print("second positional:", telescope_spec[2])
print("named key 'lazy': ", telescope_spec.lazy)
print("#spec counts ONLY the array part:", #telescope_spec)  --> 2

-- ipairs sees only the array part; pairs sees everything:
print("-- ipairs view --")
for i, v in ipairs(telescope_spec) do print("  [" .. i .. "] " .. tostring(v)) end
print("-- pairs view --")
for k, v in pairs(telescope_spec) do print("  " .. tostring(k) .. " → " .. tostring(v)) end
-- Notice pairs() visits 1 and 2 too — the array part is just keys 1
-- and 2, nothing more magical than that.

------------------------------------------------------------ TRY IT
-- 1. Add `allow_tearing = false` to `general`, re-run, and find it in
--    both the pairs() dump and the sorted dump.
-- 2. Delete `layout` from `general` with nil, then print
--    general.layout before and after to see it vanish.
-- 3. Add a bind for "SUPER, F" → "fullscreen" to `binds` using bracket
--    syntax, then print it back.
-- 4. In section 6, add `dependencies = { "nvim-lua/plenary.nvim" }` to
--    telescope_spec and print #telescope_spec again. Why didn't the
--    count change? (Answer: dependencies is a NAMED key, not [3].)
