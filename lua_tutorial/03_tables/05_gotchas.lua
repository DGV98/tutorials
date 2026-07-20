----------------------------------------------------------------------
-- 05_gotchas.lua — Table traps that bite real configs
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • # is UNDEFINED when a sequence has nil holes — not "wrong", undefined.
--   • ipairs stops dead at the first nil.
--   • The real rule for mutating a table while pairs() iterates it
--     (deleting: allowed; ADDING: undefined behavior).
--   • table.insert's positional form, and the argument-order trap.
--   • Trailing commas are legal — and why you should always use them
--     in config tables.
-- HOW TO RUN
--   luajit 05_gotchas.lua            (from this directory)
--   or inside nvim:  :luafile %      (with this file open)
-- PREREQUISITES: 04_references_and_copies.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. nil holes make # undefined
-- # is only defined for a SEQUENCE: keys 1..n with no gaps. Put a nil
-- in the middle and # may return ANY boundary (an index i where t[i]
-- is non-nil and t[i+1] is nil). It depends on internal layout —
-- not on anything you can reason about.
local plugins = { "telescope", "treesitter", nil, "lualine" }
print("#with a hole:", #plugins)
-- On this machine it printed 4 when this lesson was written. It is
-- ALLOWED to print 2. Same table, either answer, both "correct".
-- Different LuaJIT/Lua versions — or the same table built a different
-- way — can and do disagree:
local plugins2 = {}
plugins2[1] = "telescope"
plugins2[2] = "treesitter"
plugins2[4] = "lualine"          -- same data, built by assignment
print("#same data, built differently:", #plugins2)

-- How holes happen in real life: you "remove" a plugin from a list
-- with `list[3] = nil` instead of table.remove(list, 3). The first
-- keeps the hole; the second shifts everything left and keeps the
-- sequence dense. USE table.remove FOR LISTS.

-- Need to count everything regardless of holes? pairs() and a counter:
local count = 0
for _ in pairs(plugins2) do count = count + 1 end
print("honest count via pairs:", count)

------------------------------------------------------------ 2. ipairs stops at the first nil
-- ipairs walks 1, 2, 3, ... and stops BEFORE the first missing index.
-- With the hole at [3], item [4] is silently never visited:
print("-- ipairs over the holey list --")
for i, name in ipairs(plugins) do
  print("  ", i, name)
end
print("(lualine was never printed — no error, it just... wasn't there)")
-- Silent data loss is the worst kind of bug: imagine a lazy.nvim spec
-- list where a conditional left a nil — every plugin after the hole
-- would simply not load, with zero error messages.

-- The fix is upstream: never leave holes. If a value might be absent,
-- either table.insert it conditionally, or store `false` instead of
-- nil (false is a real value; it doesn't break the sequence):
local maybe = { "always", false, "also always" }
print("#with false placeholder:", #maybe)   --> 3, sequence intact

------------------------------------------------------------ 3. Mutating a table while pairs() walks it
-- The rule, straight from the manual, is more precise than folklore:
--   • You MAY set an EXISTING key to nil (delete) during traversal.
--   • You may NOT ADD a key that wasn't there — behavior is undefined:
--     it might work today and corrupt the traversal after the next
--     rehash. "Undefined" means no error is guaranteed either.

-- Deleting during pairs — legal and handy (strip disabled plugins):
local specs = {
  telescope = { enabled = true },
  neotree   = { enabled = false },
  lualine   = { enabled = true },
  octo      = { enabled = false },
}
for name, spec in pairs(specs) do
  if not spec.enabled then
    specs[name] = nil            -- deleting the CURRENT key: allowed
  end
end
print("-- survivors after in-place delete --")
for name in pairs(specs) do print("  " .. name) end

-- ADDING during pairs — never do this:
--   for name in pairs(specs) do
--     specs[name .. "_backup"] = true    -- UNDEFINED BEHAVIOR
--   end
-- It won't reliably crash. It will reliably ruin an afternoon.
--
-- Safe pattern when a mutation is anything but "delete current key":
-- collect first, mutate after. Two phases, zero doubt:
local to_add = {}
for name in pairs(specs) do
  table.insert(to_add, name .. "_backup")
end
for _, key in ipairs(to_add) do   -- iteration over specs is finished
  specs[key] = true
end
print("-- after two-phase add --")
for name in pairs(specs) do print("  " .. name) end

------------------------------------------------------------ 4. table.insert: the positional form's trap
-- Two legitimate shapes:
--   table.insert(t, value)           -- append
--   table.insert(t, position, value) -- insert AT position, shift right
-- The trap: in the 3-argument form the POSITION COMES FIRST. Muscle
-- memory from insert(t, value) makes people write insert(t, value, pos).
local order = { "first", "second" }
table.insert(order, 1, "zeroth")     -- correct: position 1, then value
print("after insert at 1:", table.concat(order, ", "))

-- Get it backwards with a string value and Lua saves you — "zeroth"
-- is not a valid position, so it throws (caught here with pcall):
local ok, err = pcall(function()
  table.insert(order, "oops", 2)     -- value where position should be
end)
print("backwards args:", ok, "→", err)

-- The genuinely nasty case is when BOTH args are numbers — then
-- nothing can save you and you silently insert the wrong number at
-- the wrong place. Worse: LuaJIT (5.1) doesn't even bounds-check the
-- position, so table.insert(t, 99, 2) on a 3-item list quietly writes
-- t[99] = 2 — a nil-hole factory (see section 1). Lua 5.3+ raises
-- "position out of bounds" for that; 5.1 shrugs. Read your 3-arg
-- inserts twice.
local sneaky = { 10, 20, 30 }
table.insert(sneaky, 99, 2)          -- swapped args: meant insert 99 at [2]
print("silent damage:", table.concat(sneaky, ","), "| t[99] =", sneaky[99])
-- Also: exactly 2 or 3 args. Four is an immediate error:
local ok2, err2 = pcall(function()
  table.insert(order, 1, "a", "b")
end)
print("four args:", ok2, "→", err2)

------------------------------------------------------------ 5. Trailing commas: legal, encouraged
-- Lua allows a comma after the LAST entry of any table constructor:
local exec_once = {
  "waybar",
  "hyprpaper",
  "sh -c 'sleep 1 && ghostty -e nvim ~/todos.md'",   -- ← trailing comma: fine
}
print("entries:", #exec_once)

-- Always write it in multi-line config tables. Two reasons:
--   1. Appending a line never requires touching the previous line —
--      cleaner diffs in your dotfiles repo, no "forgot the comma"
--      syntax error at 1am.
--   2. Reordering lines (dd/p in nvim!) never breaks the syntax.
-- Every well-kept plugin spec you'll read does this. Semicolons also
-- work as separators ({1; 2; 3}) but nobody uses them — stick to commas.

-- Lua version note: unrelated to tables-the-syntax but living in the
-- table library — on Lua 5.2+ the function is table.unpack, while
-- LuaJIT (5.1) has the global unpack. Verified on THIS machine: both
-- CLI luajit AND nvim (--clean -l) have only the global `unpack`;
-- table.unpack is nil. That's not an Arch quirk: Neovim builds its
-- bundled LuaJIT WITHOUT the optional 5.2-compat mode, so official
-- Neovim release binaries lack table.unpack too. Only LuaJIT builds
-- that opt into LUAJIT_ENABLE_LUA52COMPAT (some distros/projects do)
-- have it. Never assume either name — portable plugin code writes:
--   local unpack = table.unpack or unpack
print("table.unpack here:", tostring(table.unpack), "| global unpack:", type(unpack))

------------------------------------------------------------ TRY IT
-- 1. In section 1, replace the nil in `plugins` with the string
--    "comment" and confirm # becomes trustworthy (4) and ipairs visits
--    all four entries.
-- 2. Break section 3 on purpose: move `specs[name .. "_backup"] = true`
--    INSIDE the pairs loop. Run it a few times. Does it crash? Work?
--    Both? That inconsistency IS the lesson — put it back after.
-- 3. Start with t = {10, 20, 30} and compare table.insert(t, 2, 99)
--    (correct: 99 lands at position 2) against table.insert(t, 3, 2)
--    (swapped in your head: 2 lands at position 3). Print with
--    table.concat after each. Neither errors — only one is what you
--    meant. Which is which?
