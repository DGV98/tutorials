----------------------------------------------------------------------
-- 02_variables_and_types.lua — Values, types, and local vs global
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • The four basic types: nil, boolean, number, string
--   • Dynamic typing and the type() function
--   • Multiple assignment
--   • local vs global — and why globals are a trap in Neovim configs
-- HOW TO RUN
--   luajit 02_variables_and_types.lua   (from this directory)
--   or inside nvim:  :luafile %         (with this file open)
-- PREREQUISITES: 01_hello_world.lua
----------------------------------------------------------------------

------------------------------------------------------------ 1. Variables hold values
-- Assignment looks like bash without the `$` on the right side and
-- without the "no spaces around =" rule:
--
--   bash:  name="david"       (spaces forbidden!)
--   lua:   local name = "david"   (spaces fine, and please use them)
--
-- The keyword `local` matters enormously — section 5 is all about it.
-- For now: ALWAYS write `local`. Treat a bare assignment as a bug.

local name = "david"
local editor = "neovim"
local city = "Chicago"
print("hello,", name, "user of", editor, "from", city)

------------------------------------------------------------ 2. The basic types
-- Lua has 8 types total. This module covers the four scalar ones;
-- tables and functions get whole modules of their own later.
--
--   nil       "no value". THE representation of absence.
--   boolean   true / false. Real booleans, not "0"/"1" strings like bash.
--   number    all numbers — 1, 3.14, -0.5 (details in lesson 04)
--   string    text — "like this" (details in lesson 03)
--
-- type(v) returns the type of a value AS A STRING:

print("type of nil:     ", type(nil))
print("type of true:    ", type(true))
print("type of 42:      ", type(42))
print("type of 'hi':    ", type("hi"))
print("type of type:    ", type(type)) -- functions are values too!

------------------------------------------------------------ 3. Dynamic typing
-- Variables have no fixed type — VALUES have types, variables just hold
-- whatever you put in them. Same as bash, where everything's a string;
-- unlike bash, Lua actually distinguishes 42 from "42".

local x = 42
print("x is", x, "of type", type(x))
x = "now a string"
print("x is", x, "of type", type(x))
x = true
print("x is", x, "of type", type(x))

-- Important distinction bash blurs: the NUMBER 42 and the STRING "42"
-- are different values with different types:
print("42 vs '42':", type(42), type("42"))

------------------------------------------------------------ 4. nil — the absence of value
-- Reading a variable that was never assigned doesn't error; it gives nil.
-- (In bash, $undefined_var silently expands to ""; in Lua you get nil,
-- which you can actually test for.)

local never_set
print("never_set is:", never_set) -- nil

-- Assigning nil to a variable erases its value:
local temp = "something"
temp = nil
print("temp after nil:", temp)

-- nil is not the same as false, and not the same as 0 or "":
print("nil == false?", nil == false) -- false! different types
-- Lesson 05 covers how nil and false behave in conditions ("truthiness").

------------------------------------------------------------ 5. Multiple assignment
-- Lua can assign several variables at once. This is how functions return
-- multiple values later in the course, so get comfortable with the shape:

local a, b = 1, 2
print("a, b =", a, b)

-- Swap without a temp variable (all right-hand sides are evaluated first):
a, b = b, a
print("swapped:", a, b)

-- Too few values on the right? The leftovers get nil. No error:
local p, q, r = "only one"
print("p, q, r =", p, q, r)

------------------------------------------------------------ 6. local vs global — THE trap
-- Any assignment WITHOUT `local` creates (or overwrites) a GLOBAL:

leaked = "oops, I am global" -- no `local` → global. Don't do this.
print("leaked:", leaked)

-- Globals live in one shared table called _G. These are the same thing:
print("same value via _G:", _G.leaked)
print("even print is global:", _G.print == print)

-- Why this is a NEOVIM CONFIG TRAP, specifically:
-- Your entire Neovim session — init.lua, lua/me/*.lua, and every one of
-- your lua/plugins/*.lua specs, PLUS all plugin code (telescope, lualine,
-- treesitter, ...) — runs in ONE Lua state sharing ONE _G. A global is
-- like `export VAR` in a shell that every script on the machine sources:
--
--   • If your lua/me/opts.lua does `config = {...}` (forgot local) and a
--    plugin also uses a global named `config`, you silently clobber each
--    other. No error. Just weird behavior three plugins away.
--   • Globals also never get garbage-collected and are slower to access.
--
-- Rule: `local` on every declaration. In real configs the linter
-- (lua_ls, which you'll meet via lsp-config) warns on accidental globals —
-- one more reason lesson files here always write `local`.

leaked = nil -- clean up our mess: deleting a global = assigning nil
print("leaked after cleanup:", leaked)

------------------------------------------------------------ 7. Local scope
-- A `local` lives from its declaration to the end of the enclosing block
-- (a chunk, a function body, a do...end, a loop body...). You can open a
-- block explicitly with do ... end:

do
	local inner = "visible only in this block"
	print("inside block:", inner)
end
print("outside block:", inner) -- nil — `inner` doesn't exist out here
-- (Reading an unknown NAME falls through to globals: _G.inner is nil.)

-- Remember lesson 01: a file is a chunk, compiled as a function body.
-- So file-level locals are private to the file. That's why every plugin
-- can have its own `local config` without collisions — IF they use local.

----------------------------------------------------------------------
-- TRY IT
-- 1. Add a `local city = ...` with your city and extend the greeting in
--    section 1 to print it.
-- 2. Predict the output of: local m, n = 5; print(n). Then add it at the
--    bottom and check.
-- 3. Remove `local` from `inner` in section 7 and re-run. What does the
--    "outside block" line print now, and why is that exactly the trap
--    section 6 warned about?
----------------------------------------------------------------------
