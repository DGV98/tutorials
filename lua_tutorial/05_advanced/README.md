# Module 05 — Advanced Lua: errors, patterns, iterators, coroutines, I/O

This module turns you from someone who can *write* Lua into someone who can
*operate* it: read a stack traceback and walk straight to the broken line of
your nvim config, parse and generate config-file text with Lua patterns, see
through the `for ... in` sugar to the iterator protocol underneath, and
understand the coroutine machinery that plugin authors use to make async code
read top-to-bottom. It closes with file I/O and the `os` library — the exact
write-then-verify recipe the Hyprland capstone (module 08) is built on — and a
field guide to LuaJIT itself, so Lua 5.3/5.4 blog posts stop breaking on your
machine mysteriously. It sits here because everything in it leans on closures
(module 02), tables (module 03), and metatables (module 04), and because
modules 06–07 assume all of it.

## Files

| File | What it covers |
|---|---|
| `01_error_handling.lua` | `error()` and error levels, `assert` as guard and pass-through, `pcall`/`xpcall` + `debug.traceback`, table error objects, rethrowing — and HOW TO READ a traceback line by line (your #1 nvim debugging skill) |
| `02_string_patterns.lua` | Lua patterns are NOT regex: classes `%a %d %s %w`, anchors `^ $`, greedy `*` vs lazy `-`, captures, `match`/`gmatch`/`gsub` (string, table, and function replacements), escaping magic chars, parsing `key = value` config lines |
| `03_iterators.lua` | What `for ... in` actually does (iterator fn, invariant state, control var), stateless iterators (reimplementing `ipairs`), closure-based iterators, wrapping iterators |
| `04_coroutines.lua` | `create`/`resume`/`yield`/`status`/`wrap`, value flow in both directions, producer–consumer, coroutines as iterators, and a working toy of the await-style async trick Neovim plugins use |
| `05_scope_and_env.lua` | Blocks and `do...end`, globals as fields of `_G`, a metatable tripwire for accidental globals, why `local` is faster (register/upvalue vs hash lookup) |
| `06_file_io_and_os.lua` | `io.open` modes, `read("*a"/"*l"/"*n")`, `f:lines()`, the `assert(io.open(...))` idiom, write-then-re-read into `build/`, `os.getenv`/`os.date`/`os.time` |
| `07_luajit_notes.lua` | What LuaJIT is, `jit.version`, the `bit` library (5.1 has no bitwise operators), `goto`, one line on `ffi`, and a cheat table of 5.1/LuaJIT vs 5.4 differences you'll hit in blog posts |
| `exercises.lua` | 7 exercises, from a level-2 `error()` guard up to a full config round-trip (render → write → re-read → parse, with structured error objects) |
| `solutions.lua` | Complete solutions with the key insight of each exercise |
| `build/` | Created at run time by lesson 06 and exercise 7 — generated files land here, nowhere else |

## How to run

From inside this directory:

```sh
luajit 01_error_handling.lua   # each lesson is a runnable, printing story
luajit exercises.lua           # runs clean as-is; un-comment tests as you solve
luajit solutions.lua           # all-true test lines
```

Or open a file in nvim and `:luafile %`. Lessons 06 and the exercises resolve
paths from `arg[0]`, so `build/` ends up next to the lesson files even if you
run them from elsewhere — but running from this directory keeps life simple.

Two facts verified on this machine that this module leans on: `xpcall` with
extra arguments works (LuaJIT backported it from 5.2), and `table.unpack` is
nil in both CLI `luajit` and Neovim here — use `unpack` (lesson 07 has the
full compatibility table).

## Time estimate

4–5 hours including exercises. Lessons 01 and 02 pay the highest rent —
tracebacks and patterns are daily tools; budget a second pass for the
traceback-reading section with a real error from your own config.
