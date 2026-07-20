# Module 03 — Tables: the only data structure, and everything it can do

Lua has exactly one data structure, and this is it. Arrays, dictionaries,
sets, stacks, queues, objects, modules, and — the reason you're here — every
plugin spec, every `opts = {}` block, and every option group in a Neovim
config are all tables. Master this module and Neovim config files stop being
incantations and become plain data you can read, reshape, and debug. It sits
here in the course because everything after it (functions organized into
modules, the `vim.*` API, generating your Hyprland config) is just doing
things *to* tables.

## Files

| File | What it covers |
| --- | --- |
| `01_arrays.lua` | Sequence tables, **1-based indexing** (drilled), `#`, `ipairs`, `table.insert/remove/concat/sort` (incl. custom comparators) |
| `02_dictionaries.lua` | Key/value pairs, `pairs()` and its undefined order, `t.x` vs `t["x"]`, any-type keys, `nil` deletes, mixed array+hash tables |
| `03_nested_tables.lua` | Deep structures shaped like real plugin specs and hyprland sections; building, reading, and-chain safe navigation |
| `04_references_and_copies.lua` | Tables are references; aliasing bugs; shallow copy by hand; deep copy by recursion; `==` is identity |
| `05_gotchas.lua` | `#` with nil holes, `ipairs` stops at nil, mutating while iterating `pairs`, `table.insert` positional traps, trailing commas |
| `06_patterns.lua` | Sets via `t[key] = true`, stacks/queues, hand-rolled merges → previewing `vim.tbl_deep_extend`, the `opts = opts or {}` setup() pattern |
| `exercises.lua` | 8 exercises, easy → stinging (runs clean as a skeleton; fill in the TODOs) |
| `solutions.lua` | Complete, commented solutions |

Read the lessons in order — each builds on the last.

## How to run

From inside this directory:

```sh
luajit 01_arrays.lua      # and so on for each file
```

Or from inside Neovim with the file open: `:luafile %`. Every file runs to
completion and exits 0, including `exercises.lua` before you touch it.

## Time estimate

Roughly 2.5–4 hours: ~20 minutes per lesson (read, run, do the TRY IT
prompts), plus an hour or so for the exercises. Exercise 8 is meant to take
a while — it's a miniature of the config generator you'll build in module 08.
