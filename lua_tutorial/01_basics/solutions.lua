----------------------------------------------------------------------
-- solutions.lua — Module 01: Lua fundamentals
----------------------------------------------------------------------
-- Complete solutions to exercises.lua, with the key insight of each
-- exercise called out. Run with:  luajit solutions.lua
----------------------------------------------------------------------

print("== EXERCISE 1: introduce yourself =====================")
-- Key insight: .. concatenates and auto-converts numbers, but the
-- VALUES keep their real types — type() still tells them apart.
local name = "david"
local shell = "zsh"
local since = 2015
print(name .. " uses " .. shell .. " (since " .. since .. ")")
print(type(name), type(shell), type(since))

print("== EXERCISE 2: path surgery ===========================")
-- Key insight: "[^/]+$" = "one or more non-slash characters, anchored
-- at the end" — the filename. Small patterns compose into real parsing.
local path = "/home/david/.config/hypr/hyprland.conf"
local filename = path:match("[^/]+$")
print(filename)                                    -- (a) hyprland.conf
local ext = filename:match("%.(%w+)$")             -- capture after last dot
print(ext)                                         -- (b) conf
local stem = filename:match("^(.+)%."):upper()     -- everything before the dot
print(stem)                                        -- (c) HYPRLAND
-- No-pattern alternative for (b)/(c) with find + sub:
--   local dot = filename:find("%.")               -- position of the dot
--   ext  = filename:sub(dot + 1)
--   stem = filename:sub(1, dot - 1):upper()

print("== EXERCISE 3: aligned status lines ===================")
-- Key insight: design the format string ONCE, reuse it — that's what
-- makes columns line up. %-10s pads right, %6.1f pads left.
local prog1, mem1 = "waybar", 42.5
local prog2, mem2 = "hyprpaper", 12
local prog3, mem3 = "nvim", 156.31
local row = "%-10s  | %6.1f MB"
print(string.format(row, prog1, mem1))
print(string.format(row, prog2, mem2))
print(string.format(row, prog3, mem3))
-- Note 156.31 became 156.3 and 12 became 12.0 — %.1f both rounds and
-- pads. One format string = one source of truth for the layout.

print("== EXERCISE 4: uptime formatter =======================")
-- Key insight: peel off the largest unit with floor-divide, keep the
-- remainder with %, repeat. This ladder shape handles ANY unit chain.
local uptime = 100000
local days = math.floor(uptime / 86400)
local hours = math.floor(uptime % 86400 / 3600)
local minutes = math.floor(uptime % 3600 / 60)
local seconds = uptime % 60
print(string.format("%dd %02dh %02dm %02ds", days, hours, minutes, seconds))

print("== EXERCISE 5: skip list ==============================")
-- Key insight: goto ::continue:: at the BOTTOM of the body is Lua's
-- continue. The label name is convention, not keyword.
for i = 1, 20 do
  if i % 4 == 0 then goto continue end
  io.write(i, " ")
  ::continue::
end
print()

print("== EXERCISE 6: truthiness lie detector ================")
-- Key insight: "" is TRUTHY — only nil and false are falsy. A bash
-- brain expects empty = false; Lua needs the emptiness spelled out.
local user_input = ""       -- swap in nil, "0", "text" to re-test
if user_input then
  print("BUGGY check says: got input:", user_input)
else
  print("BUGGY check says: no input")
end
-- (a) "" passed `if user_input` because it's not nil and not false.
-- (b) Correct: name both disqualifiers. #user_input == 0 also works
--     for the empty test, but only after the nil test (== short-circuits
--     via `and`, so nil never reaches the # operator):
if user_input ~= nil and user_input ~= "" then
  print("CORRECT check: got input:", user_input)
else
  print("CORRECT check: no input")
end

print("== EXERCISE 7: the false-proof default (stinger) ======")
-- Key insight: `or` tests TRUTHINESS but a config chain needs to test
-- EXISTENCE (non-nil). They differ on exactly one value — false — and
-- on/off settings hit that value all the time. This is the single most
-- common bug pattern in Neovim plugin option-merging code.
local user_animations = false
local project_animations = true
local builtin_animations = true

-- (a) The obvious one-liner is wrong:
local naive = user_animations or project_animations or builtin_animations
print("naive `or` chain:", naive)     -- true — user's false was ignored!

-- (b) First NON-NIL wins; false is a real answer:
local animations
if user_animations ~= nil then
  animations = user_animations
elseif project_animations ~= nil then
  animations = project_animations
else
  animations = builtin_animations
end
print("false-proof pick:", animations)   -- false — the user is respected

-- (c) Re-checks with other combinations (same logic, new inputs):
user_animations, project_animations = nil, false
if user_animations ~= nil then
  animations = user_animations
elseif project_animations ~= nil then
  animations = project_animations
else
  animations = builtin_animations
end
print("nil, false, true ->", animations)  -- false (project wins)

user_animations, project_animations = nil, nil
if user_animations ~= nil then
  animations = user_animations
elseif project_animations ~= nil then
  animations = project_animations
else
  animations = builtin_animations
end
print("nil, nil, true  ->", animations)   -- true (builtin default)
-- Writing that if/elseif three times hurts a little — good. Module 02
-- (functions) turns it into `first_non_nil(a, b, c)` in four lines.

print("== done ================================================")
