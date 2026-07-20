----------------------------------------------------------------------
-- 01_hello_world.lua — Hello, Lua
----------------------------------------------------------------------
-- WHAT YOU'LL LEARN
--   • print() — your workhorse for the whole course
--   • Comments: single-line and block (and why block comments look weird)
--   • What a "chunk" is (Lua's unit of execution)
--   • Every way you'll actually run Lua: luajit CLI, nvim -l, :luafile, :lua
-- HOW TO RUN
--   luajit 01_hello_world.lua        (from this directory)
--   or inside nvim:  :luafile %      (with this file open)
-- PREREQUISITES: none — this is lesson one.
----------------------------------------------------------------------

------------------------------------------------------------ 1. print()
-- print() writes its arguments to stdout, separated by TABS, and adds
-- a newline. It's Lua's `echo`. Unlike bash's echo, it takes any value
-- (numbers, booleans, nil...) and converts it to text for you.

print("Hello, David!")
print("multiple", "arguments", "get", "tabs")
print(1 + 2) -- expressions are evaluated first, like $((1 + 2))

-- print() with no arguments prints just a blank line:
print()

------------------------------------------------------------ 2. Comments
-- A single-line comment starts with two dashes and runs to end of line.
-- It's Lua's `#`. You've been reading them this whole time.

print("code") -- comments can trail code, just like `echo hi  # comment`

--[[
This is a BLOCK comment: it starts with --[[ and ends with the matching
double square brackets. Everything in between is ignored, across as many
lines as you like. Handy for commenting out a whole region while testing.
]]

--[==[
Variant: you can put any number of equals signs between the brackets,
as long as open and close match. Why? So you can comment out code that
itself contains ]] without ending the comment early. You'll see the
same bracket trick again with "long strings" in lesson 03.
]==]

print("comments:", "still running fine")
--[[
------------------------------------------------------------ 3. What is a chunk?
-- A "chunk" is Lua's unit of compilation and execution: this whole file
-- is one chunk. So is a one-liner you pass to `luajit -e`, and so is
-- every `:lua` command you type in Neovim.
--
-- Think of it like a bash script: the file is the unit. But Lua goes one
-- step further — internally, a chunk is compiled as the BODY OF AN
-- ANONYMOUS FUNCTION. That has real consequences you'll meet in lesson 02:
-- variables declared `local` in a chunk are private to that chunk, exactly
-- like locals in a bash function vs. exported environment variables.
--
-- Statements in a chunk run top to bottom. No boilerplate is required:
-- no main(), no shebang, no imports for the basics. The line below is a
-- complete, legal Lua program on its own.
--]]
print("a chunk runs top to bottom, and this is the 3rd section")
--[[
------------------------------------------------------------ 4. All the ways to run Lua
-- You will use all of these during this course. From your zsh prompt:
--
--   luajit 01_hello_world.lua     Run a file. LuaJIT is the SAME engine
--                                 Neovim embeds, so what works here works
--                                 in your config (Lua 5.1 semantics).
--
--   luajit -e 'print(2^10)'       One-liner, like `bash -c '...'`. Great
--                                 for quick experiments.
--
--   luajit                        No args = interactive REPL (a Lua
--                                 prompt, like typing `python` or just
--                                 experimenting in zsh). Ctrl-D to quit.
--
--   nvim -l 01_hello_world.lua    Neovim as a Lua interpreter! Runs the
--                                 file headlessly with the full `vim.*`
--                                 API available. `nvim --clean -l file`
--                                 skips your config for a clean run.
--
-- And from INSIDE a running Neovim session:
--
--   :luafile %                    Run the current file as Lua. `%` means
--                                 "current file", same as in `:!chmod +x %`.
--   :source %                     Also works — :source understands .lua.
--   :lua print("hi")              Run one line of Lua right now.
--   :lua =vim.o.laststatus        `:lua =expr` PRINTS the expression's
--                                 value — perfect for inspecting your
--                                 config. (:help :lua)
--
-- Try `:luafile %` on this very file after reading it here. The printed
-- output shows up in Neovim's message area (:messages to review it).

print("run me every way listed above -- same output each time")
------------------------------------------------------------ 5. A note on semicolons
-- Statements don't need semicolons or line-end markers. Newlines are
-- enough, and even those are optional — Lua can tell where a statement
-- ends. Semicolons are legal but idiomatic Lua omits them.

print("no")
print("semicolons") -- legal, but nobody writes this
print("needed")
--]]
----------------------------------------------------------------------
-- TRY IT
-- 1. Change the greeting in section 1 to include your name, then run
--    the file with `luajit 01_hello_world.lua` AND with
--    `nvim -l 01_hello_world.lua` (`%` only means "current file" inside
--    nvim — from nvim, `:!luajit %` works too).
-- 2. Wrap sections 4 and 5 in a block comment --[[ ... ]] and re-run.
--    Which print lines disappear from the output?
-- 3. In a running nvim session, try `:lua print("from inside nvim")`
--    then `:messages` to see where the output went.
----------------------------------------------------------------------
