# Lua: Zero to Hero (for Neovim & Hyprland)

A hands-on Lua course built for one specific journey:

1. **Learn Lua** properly, from nothing.
2. **Debug your Neovim config** with confidence (`lua/me/*`, `lua/plugins/*`, lazy.nvim).
3. **Port your Hyprland config** to Lua — a generator that emits `hyprland.conf`.

Every lesson is a runnable `.lua` file. The files are the textbook *and* the
lab: open them in nvim, read them, run them, break them, re-run them.

## Why LuaJIT, not `lua`?

Neovim embeds **LuaJIT**, which implements **Lua 5.1** (plus extensions). Your
system `lua` is Lua 5.5 — a *different, newer* language dialect that Neovim
does not run. This course always uses `luajit`, so what you learn is exactly
what your editor speaks. Lessons flag the 5.1-vs-newer traps as they come up.

## How to run a lesson

```sh
# From a module directory — the primary way for modules 01–05 and 08:
luajit 01_hello_world.lua

# Modules 06–07 need Neovim's Lua (the vim.* API doesn't exist in plain luajit):
nvim --clean -l 01_hello_neovim.lua
```

And inside a running Neovim session, with a lesson file open:

```vim
:luafile %       " run the current file
:lua print(1+1)  " run one line
:=vim.opt.number " evaluate + pretty-print an expression
:messages        " re-read any print() output you missed
```

## The path

Work the modules in order. Each one assumes the previous ones.

| Module | What it unlocks | Runner |
|---|---|---|
| `01_basics/` | Values, strings, numbers, control flow, truthiness traps | `luajit` |
| `02_functions/` | Closures, varargs, higher-order functions — the shape of every nvim callback | `luajit` |
| `03_tables/` | **The** data structure. Your entire nvim config is tables | `luajit` |
| `04_modules_metatables_oop/` | `require`, `__index`, OOP — the machinery behind `vim.opt` and plugins | `luajit` |
| `05_advanced/` | Error handling & tracebacks, string patterns, iterators, coroutines, file I/O | `luajit` |
| `06_neovim_api/` | The `vim.*` API: options, keymaps, buffers, autocmds, user commands, utilities | `nvim --clean -l` |
| `07_neovim_config/` | Your config's anatomy, the debugging toolkit, lazy.nvim specs, write a mini-plugin | `nvim --clean -l` |
| `08_capstone_hyprland/` | Capstone: a Lua DSL that generates your `hyprland.conf` | `luajit` |

Each module contains:

- Numbered lesson files (`01_…lua`, `02_…lua`, …) — read and run in order.
- `exercises.lua` — a runnable skeleton with TODOs. Do these. Really.
- `solutions.lua` — full solutions, for after you've tried.
- `README.md` — the module's map and time estimate.

Also at the root: **`CHEATSHEET.md`** — dense quick-reference for Lua syntax,
the `vim.*` namespace map, and a Vimscript → Lua translation table. Keep it
open in a split while you work.

## Suggested cadence

- One module ≈ 2–4 focused sessions. Don't binge modules 01–03; the basics
  need to settle before metatables make sense.
- After module 05 you can read most plugin source. After 07 you can debug your
  own config. Module 08 is a project — give it a weekend.

## Tips that pay off immediately

- **Run everything.** Every claim in a lesson is demonstrated by a `print()`.
  Change the code, predict the output, re-run. Being wrong is the lesson.
- In nvim, `:help lua-guide` and `:help vim.keymap.set()` style lookups are a
  first-class skill — the lessons cite `:help` tags as you go.
- When something errors, *read the traceback top line*: `file:line:` is a
  clickable address, not noise. Module `05_advanced/01_error_handling.lua`
  teaches you to dissect it; module 07 applies it to your real config.
