# Module 04 — Modules, require, Metatables, and OOP

This is the module where Lua stops looking like "a scripting language" and
starts looking like the language your Neovim config is written in. First you
learn how code is split into files and glued back together (`require`,
`package.path`, and the `package.loaded` cache — including why editing
`lua/me/opts.lua` and re-sourcing often "does nothing"). Then metatables: the
single mechanism behind default values, operator overloading, proxies like
`vim.opt`, and every plugin's `Class`. It sits here because modules need
functions and tables (modules 02–03), and everything Neovim-specific in
modules 06–07 assumes you can read `__index` without flinching.

## Files

| File | What it covers |
|---|---|
| `01_modules.lua` | The `local M = {}` pattern, `require` semantics, `package.path`, the `package.loaded` cache, how `require("me.opts")` finds `lua/me/opts.lua` |
| `mylib/init.lua` | Tiny real package used by lesson 01 — `require("mylib")` lands here |
| `mylib/greet.lua` | Leaf module — `require("mylib.greet")` lands here; prints when (re)loaded so you can SEE the cache |
| `02_metatables_index.lua` | `setmetatable`/`getmetatable`, `__index` as table and as function, fallback chains, `rawget` — the machinery behind `vim.opt`/`vim.bo` |
| `03_metamethods.lua` | `__newindex`, `__call`, `__tostring`, `__eq`, arithmetic metamethods on a small `Vector` type; `__len` version note |
| `04_oop.lua` | The standard class pattern (`Class.__index = Class`), constructors, `:` and `self` desugaring, single inheritance, calling parent methods |
| `05_metatable_applications.lua` | Default-value tables, read-only proxies, memoization caches, a tracking proxy — conceptually how `vim.opt` intercepts assignments |
| `exercises.lua` | 7 exercises, from cache-busting `reload()` up to writing your own `class()` factory |
| `solutions.lua` | Complete solutions with the key insight of each exercise |

## How to run

From inside this directory:

```sh
luajit 01_modules.lua        # each lesson is a runnable, printing story
luajit exercises.lua         # runs clean as-is; un-comment tests as you solve
luajit solutions.lua         # all-true test lines
```

Or open a file in nvim and `:luafile %`. Run lessons from THIS directory —
lesson 01 explains why the working directory matters for `require` (and then
makes the files immune to it).

Verified fact for this machine (worth remembering): both CLI `luajit` and
Neovim's embedded LuaJIT here are plain Lua 5.1 — no 5.2-compat build. So
`table.unpack` is nil (use `unpack`) and `#` ignores `__len` on tables, in
both environments.

## Time estimate

3–4 hours including exercises. Lessons 02 and 04 deserve a second pass — the
`__index` chain is the one idea the rest of the course leans on.
