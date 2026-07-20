# Module 06 — The `vim.*` API

Five modules of pure Lua later, this is the payoff: the same language, now driving
your editor. Everything Neovim can do hangs off one global table — `vim` — and this
module tours its neighborhoods one lesson at a time: options, keymaps, the raw
`vim.api` layer, the `vim.fn` bridge to Vimscript builtins, autocommands, user
commands, the utility belt, and the glue (`vim.cmd`, variable scopes, highlights).
It is ordered here because every lesson leans on earlier Lua skills (tables,
functions-as-values, modules) and because module 07 — where you rebuild and extend
your real config — assumes all of it. House rule, kept throughout: **every `vim.*`
call carries a comment with its Vimscript/ex-command equivalent** where one exists,
so this directory doubles as the translation reference you can grep forever.

## Files

| File | What it covers |
|---|---|
| `01_hello_neovim.lua` | Running Lua in nvim (`:lua`, `:luafile %`, `:=`, `nvim -l`), `print` vs `vim.print`, `vim.inspect`, where output goes (`:messages`) |
| `02_options.lua` | `vim.o` / `vim.opt` / `vim.bo` / `vim.wo` / `vim.g`: which door for which job; `append`/`prepend`/`remove`/`:get()`; `:set`/`:setlocal` equivalents throughout |
| `03_keymaps.lua` | `vim.keymap.set`/`del`: modes, string vs Lua-function rhs, the opts table, leader keys, `<Plug>`, and the fn vs fn() bug revisited |
| `04_buffers_windows_api.lua` | The low-level `vim.api` / `nvim_*` namespace: buffer lines, scratch buffers, a floating window (created, read back, closed), cursor, and the 0-indexing rules |
| `05_vim_fn_bridge.lua` | `vim.fn.*` calls Vimscript builtins: `expand`, `fnamemodify`, `getline`/`setline`, `stdpath` — and the 0/1-is-not-a-boolean trap |
| `06_autocommands.lua` | `nvim_create_autocmd`: the events you'll actually use, pattern vs buffer, callback vs command, `once`, and augroups with `clear = true` (and WHY) |
| `07_user_commands.lua` | `nvim_create_user_command`: `nargs`, `args`/`fargs`/`bang`/`range`, tab-completion, two commands worth keeping |
| `08_vim_utilities.lua` | The utility belt: `vim.tbl_*`, `vim.split`/`trim`/`startswith`, `vim.iter`, `vim.json`, `vim.notify`, `vim.schedule`/`defer_fn`, `vim.system`, `vim.uv` at a glance |
| `09_vim_cmd_and_g.lua` | `vim.cmd` and `vim.cmd.colorscheme()`, the `g:`/`b:`/`v:` variable scopes, `nvim_set_hl` (your transparent background, explained), and the general Vimscript→Lua recipe |
| `exercises.lua` | 8 exercises ramping from options to a full vimrc-to-Lua translation; runs clean as-is |
| `solutions.lua` | Complete solutions, each annotated with the key insight |

## How to run

This module's runner is Neovim itself in headless script mode — `luajit` no longer
works here, because the global `vim` table only exists inside Neovim:

```sh
cd 06_neovim_api
nvim --clean -l 01_hello_neovim.lua
```

`--clean` skips your real config (so lessons can't break it and it can't break
lessons); `-l` runs the file and exits. Alternatively, open any lesson in a live
nvim session and run `:luafile %` — a few demos (the floating window, keymaps) are
more fun that way. If output scrolls away in a live session, `:messages` has it.

## Time estimate

Roughly **4–6 hours**: 20–30 minutes per lesson including the TRY IT prompts, plus
an hour or so for the exercises. Natural split: lessons 01–05 in one sitting,
06–09 plus exercises in another.
