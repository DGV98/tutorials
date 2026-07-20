# Module 02 — Functions: values, closures, varargs, higher-order

This module is where Lua stops looking like "a config language with ifs" and
starts being Lua. Functions here are ordinary values: you store them in
variables and tables, pass them around, return them, and let them capture the
variables around them (closures). That one idea powers essentially all of a
Neovim config — every keymap rhs, every autocmd callback, every lazy.nvim
`config = function()` is a function value, usually a closure. It comes right
after the basics module because everything later (tables-as-modules, the
stdlib, Neovim's API) assumes you read `function() ... end` as fluently as a
number.

## Files

| File | What it covers |
| --- | --- |
| `01_function_basics.lua` | Defining/calling, missing args become nil & extras dropped, `return` and early return, functions as values, `local function` vs `local f = function` |
| `02_multiple_returns.lua` | Returning several values, how the call site adjusts them, the parentheses trap, `select()`, `{f()}`, `unpack` (with an empirically verified 5.1 vs 5.2+ version note) |
| `03_varargs.lua` | `...`, `select("#", ...)`, `{...}`, forwarding varargs through wrappers, why nil holes are tricky and the robust patterns |
| `04_closures_and_upvalues.lua` | Capturing locals, counters and factories, loop-variable capture, why closures are THE Neovim keymap/callback pattern |
| `05_higher_order_functions.lua` | map/filter/reduce built by hand, `table.sort` comparators, `fn` vs `fn()` and the classic keymap bug |
| `06_recursion.lua` | Base cases, the `local function` self-reference gotcha, stack overflow vs proper tail calls, mutual recursion, a recursive table printer (vim.inspect teaser) |
| `exercises.lua` | 8 exercises with scaffolding and commented-out CHECK lines; runs clean as-is |
| `solutions.lua` | Complete solutions with the key insight noted per exercise |

## How to run

Everything in this module runs under LuaJIT (the same Lua Neovim embeds),
from inside this directory:

```sh
cd 02_functions
luajit 01_function_basics.lua
```

Or from inside Neovim with a file open: `:luafile %`. Read each lesson top to
bottom in nvim, run it, then do the `-- TRY IT` prompts at the end — edit the
file itself and re-run.

For `exercises.lua`: fill in one TODO, uncomment its CHECK lines, re-run,
repeat. Peek at `solutions.lua` only after a real attempt.

## Time estimate

Roughly 2.5–4 hours: 15–25 minutes per lesson including the TRY IT edits,
plus about an hour for the exercises (the last one, `compose`, is meant to
take a while).
