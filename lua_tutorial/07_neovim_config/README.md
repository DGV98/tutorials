# Module 07 — Your Neovim Config: Anatomy, Debugging, lazy.nvim, and a Mini-Plugin

This is where the course turns back on your own machine. Modules 01–05 gave you
Lua; module 06 gave you the Neovim API. This module gives you *your config*:
how `~/.config/nvim/init.lua` is found and what happens after, how
`require("me")` becomes `lua/me/init.lua`, how lazy.nvim turns
`lua/plugins/*.lua` into installed plugins — and, most importantly, what to do
when any of that breaks. You will read real error messages, learn who to blame
(`:verbose`), bisect config-vs-plugin problems, write a tiny plugin of your
own, and finish by fixing six deliberately broken config snippets that mirror
bugs your actual layout can produce.

## Files

| File | What it covers |
| --- | --- |
| `01_config_anatomy.md` | runtimepath, how `init.lua` is found, `require` resolution, load order — a guided tour of YOUR config with an ASCII startup tree |
| `02_debugging_toolkit.lua` | `print`/`vim.print`, `:messages`, `vim.notify`, `:=`, `vim.inspect`, `:checkhealth`, `--clean`/`--noplugin` bisecting, `:verbose set/map`, `:Lazy log/profile`, reading `file:line` in errors |
| `03_common_errors.lua` | The five error messages you will actually see, reproduced and dissected: index nil, index field, call nil, module not found, concatenate nil |
| `04_lazy_nvim_specs.lua` | A lazy.nvim plugin spec is just a table — repo string, `opts` vs `config`, `dependencies`, lazy-loading triggers, `init` vs `config`, version pinning |
| `05_build_a_plugin.lua` | Build and load a real mini-plugin (`mini_plugin/lua/scratchpad/init.lua`): `setup(opts)` with defaults, a user command, a keymap, an autocmd |
| `mini_plugin/lua/scratchpad/init.lua` | The mini-plugin itself — the same shape as every plugin you install |
| `06_fix_the_config.lua` | Capstone: six broken snippets mimicking real bugs in your layout; fix them in place until every check prints FIXED |
| `exercises.lua` | 6 exercises, ramping from `vim.inspect` exploration to writing `safe_require`/`reload` helpers |
| `solutions.lua` | Complete solutions with the key insight of each exercise |

## How to run

Everything in this module runs headless with Neovim's script mode, with your
config deliberately NOT loaded (that's what `--clean` does):

```sh
cd ~/personal/tutorials/lua_tutorial/07_neovim_config
nvim --clean -l 02_debugging_toolkit.lua
```

`01_config_anatomy.md` is prose — read it first, ideally in a split next to
your real `~/.config/nvim/init.lua`. Several lessons also point at commands
(`:messages`, `:verbose`, `:Lazy profile`) that only make sense inside a real
interactive session; open your normal `nvim` for those.

## Time estimate

Roughly 3–4 hours: ~30 min for the anatomy doc against your real config,
~20–30 min per lesson file, and up to an hour for `06_fix_the_config.lua`
plus the exercises.
