----------------------------------------------------------------------
-- 05_higher_order_functions.lua — Higher-order functions
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • Passing functions INTO functions (callbacks, predicates)
--   • Building map / filter / reduce by hand
--   • table.sort with a comparator — a higher-order stdlib function
--   • fn vs fn(): passing a REFERENCE vs calling it on the spot
--   • The classic Neovim keymap bug this distinction causes
-- HOW TO RUN
--   luajit 05_higher_order_functions.lua   (from this directory)
--   or inside nvim:  :luafile %            (with this file open)
-- PREREQUISITES: 04_closures_and_upvalues.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. Functions that take functions
-- "Higher-order function" is just: a function that receives a function as
-- an argument (or returns one — you already built those in lesson 04's
-- factories). Since functions are plain values, nothing new is needed;
-- the pattern just gets a name.

local function apply_twice(fn, x)
  return fn(fn(x))
end
print("apply_twice(double, 3):", apply_twice(function(n) return n * 2 end, 3))

-- This is the "find -exec" of Lua: the outer function owns the traversal,
-- you hand it the action to perform. Caller supplies WHAT, callee decides
-- WHEN and HOW OFTEN.

------------------------------------------------------------ 2. map: transform every element
-- Lua's stdlib has no map/filter/reduce. You build them once (or a library
-- like plenary provides them; Neovim ships vim.tbl_map / vim.tbl_filter).
-- Building them by hand teaches you to READ them everywhere.

local function map(t, fn)
  local out = {}
  for i = 1, #t do
    out[i] = fn(t[i])
  end
  return out
end

local nums = { 1, 2, 3, 4, 5 }
local squared = map(nums, function(n) return n * n end)
-- table.concat(t, sep) joins an array into one string (table library: module 03)
print("squared:", table.concat(squared, ", "))

-- Any single-argument function works, including stdlib ones — pass the
-- function value itself, no wrapper needed when signatures already match:
local words = { "wl-paste", "hyprctl", "waybar" }
print("upper:", table.concat(map(words, string.upper), ", "))

------------------------------------------------------------ 3. filter: keep some elements
-- The callback here is a PREDICATE: takes a value, returns true/false.
-- Note: kept elements are appended at out[#out + 1] — not stored at i —
-- so the result stays packed 1..n with no holes (lesson 03 taught you why
-- holes are poison).

local function filter(t, pred)
  local out = {}
  for i = 1, #t do
    if pred(t[i]) then
      out[#out + 1] = t[i]
    end
  end
  return out
end

local evens = filter(nums, function(n) return n % 2 == 0 end)
print("evens:", table.concat(evens, ", "))

------------------------------------------------------------ 4. reduce: boil a list down to one value
-- reduce (a.k.a. fold) threads an accumulator through the list. sum, max,
-- "join", counting — they're all reduce with a different combining step.

local function reduce(t, fn, init)
  local acc = init
  for i = 1, #t do
    acc = fn(acc, t[i])
  end
  return acc
end

print("sum:", reduce(nums, function(a, b) return a + b end, 0))
print("product:", reduce(nums, function(a, b) return a * b end, 1))

-- And they compose — read inside-out: square, keep > 5, then sum:
local total = reduce(
  filter(map(nums, function(n) return n * n end), function(n) return n > 5 end),
  function(a, b) return a + b end,
  0
)
print("sum of squares > 5:", total)

------------------------------------------------------------ 5. Callbacks in the stdlib: table.sort
-- table.sort(t) sorts ascending. table.sort(t, cmp) is higher-order: cmp
-- receives two elements and returns true when the first should come FIRST.
-- Comparators + closures = sort by anything:

local plugins = {
  { name = "telescope", stars = 15000 },
  { name = "conform", stars = 3000 },
  { name = "lualine", stars = 6000 },
}
table.sort(plugins, function(a, b) return a.stars > b.stars end)
-- ipairs(t) drives the loop over t[1], t[2], ... in order (module 03 topic)
for i, p in ipairs(plugins) do
  print("rank " .. i .. ":", p.name, p.stars)
end

------------------------------------------------------------ 6. fn vs fn() — reference vs call
-- THE distinction of this lesson. Bare `fn` is the function VALUE — a
-- thing you can hand over to be called later. `fn()` CALLS it right now,
-- and what you hand over is whatever it RETURNED.
--
-- Shell instinct check: in zsh, writing a command's name runs it — there's
-- no "command as value". In Lua the name alone is inert; ONLY parentheses
-- execute. Unlearn the shell reflex here.

local function get_answer() return 42 end

local as_reference = get_answer   -- a function
local as_result = get_answer()    -- 42
print("reference:", type(as_reference), "| result:", type(as_result))

-- Now the classic bug. Here's a miniature vim.keymap.set — a table of
-- "when this key is pressed, call this" — so you can watch the failure
-- mechanics outside of nvim:

local keymap = {}
local function keymap_set(lhs, rhs)
  keymap[lhs] = rhs -- store the rhs to call at keypress time
end
local function press(lhs)
  local rhs = keymap[lhs]
  if type(rhs) ~= "function" then
    return false, "rhs for " .. lhs .. " is " .. tostring(rhs) .. " (" .. type(rhs) .. "), not a function"
  end
  return true, rhs()
end

local function open_todos()
  return "opening ~/todos.md"
end

-- CORRECT: pass the reference. Nothing runs yet; it runs at keypress:
keymap_set("<leader>t", open_todos)
print("press <leader>t:", press("<leader>t"))

-- BUG: parentheses. open_todos runs NOW, DURING setup, and its return
-- value (a string) gets stored as the rhs:
keymap_set("<leader>x", open_todos())
print("press <leader>x:", press("<leader>x"))

-- In real Neovim this exact mistake looks like:
--
--   -- vim.keymap.set("n", lhs, rhs)  ≈  :nnoremap, but rhs may be a Lua function
--   vim.keymap.set("n", "<leader>ff", builtin.find_files)     -- ✓ reference
--   vim.keymap.set("n", "<leader>ff", builtin.find_files())   -- ✗ BUG
--
-- The buggy line OPENS THE PICKER WHILE YOUR CONFIG LOADS (startup!), and
-- binds the key to find_files' return value — usually nil, so nvim errors
-- or the key does nothing. The symptom is famously confusing: "a Telescope
-- window flashes when I start nvim, and my mapping is dead."
--
-- And when you DO need arguments? That's not a license for parentheses —
-- it's the job of a closure (lesson 04): wrap the call so the wrapper is
-- the reference:

keymap_set("<leader>g", function() return open_todos() .. " at line 10" end)
print("press <leader>g:", press("<leader>g"))

-- Rule: an rhs/callback slot takes a FUNCTION. If you feel the urge to
-- type `(` after its name, wrap the whole call in `function() ... end`.

-- TRY IT ------------------------------------------------------------
-- 1. Write `any(t, pred)` and `all(t, pred)` using a plain loop, then use
--    them: is any plugin over 10000 stars? Are all over 1000?
-- 2. Rewrite `map` using reduce. (Hint: the accumulator is the out-table;
--    return it from the combining function.)
-- 3. Reproduce the bug: change the CORRECT keymap_set line to pass
--    open_todos() and re-run. Find both symptoms in the output (ran too
--    early / rhs is not a function).
-- 4. Sort `plugins` by name length, shortest first, using a comparator.
--    Tie-break alphabetically — this needs an `if` inside the comparator.
