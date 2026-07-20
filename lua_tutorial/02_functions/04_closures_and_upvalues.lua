----------------------------------------------------------------------
-- 04_closures_and_upvalues.lua — Closures and upvalues
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Functions capture the local variables around them ("upvalues")
--   • Captured variables are ALIVE — closures can read and write them
--   • Counters and factories: making functions that make functions
--   • Each closure gets its own upvalues; siblings can share
--   • Why closures are THE core pattern for Neovim keymaps & callbacks
-- HOW TO RUN
--   luajit 04_closures_and_upvalues.lua   (from this directory)
--   or inside nvim:  :luafile %           (with this file open)
-- PREREQUISITES: 03_varargs.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. Functions capture their surroundings
-- When you create a function INSIDE a scope, the function can see the
-- local variables of that scope — and it KEEPS seeing them even after the
-- scope is gone. A function value plus the outer locals it uses is called
-- a closure; each captured variable is an "upvalue" of the closure.

local greeting = "hello"
local function greet(name)
  -- `greeting` is not a parameter and not a local here: it's an upvalue,
  -- captured from the surrounding chunk.
  print(greeting .. ", " .. name)
end
greet("David")

greeting = "hey" -- the closure sees the LIVE variable, not a copy
greet("again")

-- That last point is the one to internalize: capture is by VARIABLE, not
-- by value. The closure and the outer code share the same box.

------------------------------------------------------------ 2. Upvalues outlive their scope: the counter
-- Here `count` is a local inside make_counter. Normally a local dies when
-- its function returns — but the returned closure still uses it, so Lua
-- keeps it alive. Private, persistent state with no classes and no
-- globals. This is the closure "hello world":

local function make_counter()
  local count = 0
  return function()
    count = count + 1 -- reads AND writes the upvalue
    return count
  end
end

local tick = make_counter()
print("tick:", tick()) -- 1
print("tick:", tick()) -- 2
print("tick:", tick()) -- 3

-- Nothing outside can touch `count` — there is no name for it out here.
-- Compare with a global counter: any plugin, any file, any typo can
-- clobber a global. The closure's state is airtight.

------------------------------------------------------------ 3. Each call to the factory = fresh upvalues
-- Every CALL to make_counter creates a brand-new `count`, so every
-- returned closure has independent state:

local c1 = make_counter()
local c2 = make_counter()
print("c1:", c1(), c1()) -- 1  2
print("c2:", c2())       -- 1   — not 3! c2 has its own count

-- Factories take parameters too. This is "partial application": bake some
-- arguments in now, supply the rest later.
local function make_adder(n)
  return function(x) return x + n end -- n is baked in
end
local add10 = make_adder(10)
local add99 = make_adder(99)
print("add10(5):", add10(5), "| add99(1):", add99(1))

-- Closures returned from the SAME call share that call's locals. Two doors
-- to one room — a tiny module with shared private state:
local function make_account(balance)
  local deposit = function(n) balance = balance + n return balance end
  local withdraw = function(n) balance = balance - n return balance end
  return deposit, withdraw
end
local put, take = make_account(100)
print("deposit 50:", put(50))   -- 150
print("withdraw 30:", take(30)) -- 120 — same balance upvalue

------------------------------------------------------------ 4. Loops: each iteration is a fresh variable
-- In Lua, the control variable of a for loop is a NEW local on every
-- iteration. So closures made in a loop each capture their own `i` —
-- you get 1, 2, 3, not 3, 3, 3 (the infamous bug from pre-ES6 JavaScript
-- `var` doesn't happen here):

local fns = {}
for i = 1, 3 do
  fns[i] = function() return i * 10 end
end
print("loop captures:", fns[1](), fns[2](), fns[3]()) -- 10 20 30

-- But a local declared OUTSIDE the loop is one single box, shared by all:
local shared = 0
local bump = {}
for i = 1, 3 do
  bump[i] = function() shared = shared + 1 return shared end
end
print("shared box:", bump[1](), bump[2](), bump[3]()) -- 1 2 3, one counter

------------------------------------------------------------ 5. Why this is THE Neovim pattern
-- Open your own config: almost every `vim.keymap.set` and every plugin
-- `config = function() ... end` is a closure. Two reasons why.
--
-- Reason 1: APIs want "a function to call later", but YOU want to call
-- something WITH ARGUMENTS. A closure wraps the call and bakes the
-- arguments in. From a real telescope setup (comments only — this file
-- runs under plain luajit):
--
--   local builtin = require("telescope.builtin")
--   -- vim.keymap.set("n", lhs, rhs)  ≈  :nnoremap — but rhs can be a Lua function
--   -- vim.fn.getcwd()  →  calls Vimscript builtin getcwd(); the editor's
--   --                     current working directory (:help getcwd())
--   vim.keymap.set("n", "<leader>fg", function()
--     builtin.live_grep({ cwd = vim.fn.getcwd() })   -- args baked into the closure
--   end)
--
-- The closure captures `builtin` (an upvalue!) and carries your arguments
-- until the moment the key is pressed. Without closures you'd need some
-- global registry of "things to call with what" — closures ARE that
-- registry, one function at a time.
--
-- Reason 2: state that survives between calls without globals. A toggle
-- keymap needs to remember on/off. Module-local + closure does it:
--
--   local diagnostics_on = true
--   vim.keymap.set("n", "<leader>td", function()
--     diagnostics_on = not diagnostics_on          -- writes the upvalue
--     vim.diagnostic.enable(diagnostics_on)        -- enable/disable diagnostics
--   end)
--
-- Let's build that toggle mechanic for real, with a fake "editor" so it
-- runs here:

local editor = { diagnostics = "on" } -- stand-in for the nvim side
local function make_toggler(target, field, a, b)
  return function()
    target[field] = (target[field] == a) and b or a
    print("toggled " .. field .. " -> " .. target[field])
  end
end

local toggle_diag = make_toggler(editor, "diagnostics", "on", "off")
toggle_diag() -- off
toggle_diag() -- on
toggle_diag() -- off  — state lives in the upvalues, not in any global

-- When you later see `callback = function() ... end` in an autocmd, or a
-- lazy.nvim spec's `config = function() ... end`, read it as: "here is a
-- closure; whatever locals it mentions travel with it."

-- TRY IT ------------------------------------------------------------
-- 1. Give make_counter a `step` parameter (default 1, lesson 01 idiom) and
--    make a countdown counter with step -1.
-- 2. Add a third function `peek` to make_account that returns the balance
--    without changing it. Confirm all three share one balance.
-- 3. Predict first, then test: move `local i2 = i` inside the section 4
--    loop and capture i2 instead of i. Does anything change? Why not?
-- 4. Write make_once(fn): returns a closure that calls fn the FIRST time
--    only and returns nothing on later calls. (This is how plugin setup
--    guards against double-initialization.)
