# 01 — Config Anatomy: how Neovim finds, loads, and runs *your* config

> **WHAT YOU'LL LEARN**
> - What `runtimepath` is and why every mystery in Neovim ends there
> - How `~/.config/nvim/init.lua` gets found (and when it doesn't)
> - How `require("me")` resolves to `lua/me/init.lua` — the exact search rules
> - The precise order things happen when YOUR config starts
> - Why `require` caches, and what that means when you edit a file
>
> **HOW TO READ THIS**: open your real config in a split
> (`:vsplit ~/.config/nvim/init.lua`) and match each section against it.
> Prerequisites: module 04 (modules & `require`), module 06 (the `vim.*` API).

---

## 1. runtimepath: the `$PATH` of Neovim

You know `$PATH` from zsh: a list of directories searched in order when you
type a command. Neovim has the same idea for *config assets*, called
**runtimepath** (`:help 'runtimepath'`, abbreviated `rtp`). See yours with:

```vim
:set runtimepath?
" or the readable version:
:lua vim.print(vim.opt.runtimepath:get())
```

On your machine the interesting entries are, in order:

```
~/.config/nvim                     ← YOUR config (first = highest priority)
~/.local/share/nvim/lazy/lazy.nvim ← prepended by your init.lua bootstrap
~/.local/share/nvim/lazy/<plugin>  ← one entry per plugin, added by lazy.nvim
$VIMRUNTIME                        ← Neovim's own runtime files
.../after directories              ← "last word" overrides, loaded at the end
```

Inside each runtimepath entry, *subdirectory names have meaning*:

| Subdir     | What Neovim does with it |
| ---------- | ------------------------ |
| `lua/`     | Where `require()` looks for Lua modules (this is the big one) |
| `plugin/`  | Every script in here is run automatically at startup |
| `after/`   | Same structure again, but loaded after everything else |
| `doc/`     | Help files; `:help` tags come from here |
| `colors/`  | Colorschemes — `colorscheme tokyonight-night` finds `colors/tokyonight-night.lua` on some rtp entry (the tokyonight plugin's) |
| `ftplugin/`| Per-filetype scripts, e.g. `ftplugin/markdown.lua` |

A "plugin" is nothing magical: it is a directory shaped like this, placed on
`runtimepath`. Your config directory is shaped like this too. **Your config is
just the first plugin.**

## 2. How init.lua is found

Neovim asks the XDG spec where config lives: `$XDG_CONFIG_HOME/nvim`, which on
your Arch box is `~/.config/nvim` (check with `:echo stdpath("config")`, or in
Lua `vim.fn.stdpath("config")`). Inside it, Neovim loads **one** entry point:

- `init.lua` — yours, or
- `init.vim` — legacy Vimscript (having *both* is an error, `:help E5422`)

That's it. Nothing else in your config runs unless `init.lua` (directly or
indirectly) causes it to run — with two exceptions you now recognize:
`plugin/**/*.lua` and `after/plugin/**/*.lua` are auto-sourced because of the
special subdir names from section 1.

Flags that change this, which you'll use for debugging in lesson 02:

- `nvim --clean` — skip user config AND plugins entirely (pristine Neovim)
- `nvim --noplugin` — load your `init.lua` but skip `plugin/` auto-sourcing
- `nvim -u other_init.lua` — use a different entry point (bisecting tool)

## 3. How `require("me")` becomes `lua/me/init.lua`

From module 04 you know `require` in plain Lua walks `package.path`. Inside
Neovim there's an extra, more important searcher that walks **runtimepath**
(`:help lua-require`). For `require("me")` it checks, in each rtp entry:

```
<rtp-entry>/lua/me.lua
<rtp-entry>/lua/me/init.lua      ← this is what matches in ~/.config/nvim
```

For `require("me.remap")`, dots become directory separators:

```
<rtp-entry>/lua/me/remap.lua     ← matches ~/.config/nvim/lua/me/remap.lua
<rtp-entry>/lua/me/remap/init.lua
```

Three consequences worth tattooing somewhere:

1. **The `lua/` prefix is implicit.** You `require("me.remap")`, never
   `require("lua.me.remap")`. If you ever see `module 'lua.me.remap' not
   found`, that's the bug.
2. **First match on runtimepath wins.** If two plugins both ship
   `lua/util.lua`, whichever is earlier in rtp shadows the other — one reason
   plugin authors namespace everything.
3. **`require` caches.** The result is stored in `package.loaded["me.remap"]`;
   a second `require` returns the cached table *without re-running the file*.
   So editing `lua/me/remap.lua` and re-running `:source ~/.config/nvim/init.lua`
   does NOT pick up your change — the cache serves the old module. Either
   restart nvim, or clear the cache first:
   `:lua package.loaded["me.remap"] = nil` then re-require. (lazy.nvim also
   enables `vim.loader`, a byte-compiling cache on disk — same rules, faster.)

## 4. The guided tour of YOUR config

Your layout:

```
~/.config/nvim/
├── init.lua              ← entry point: bootstrap, require("me"), lazy, colors
├── lazy-lock.json        ← lazy.nvim's pin file (exact commit per plugin)
└── lua/
    ├── me/
    │   ├── init.lua      ← requires the three siblings below
    │   ├── remap.lua     ← your keymaps
    │   ├── opts.lua      ← your options (vim.opt.*)
    │   └── todos.lua     ← your todo-file helpers
    └── plugins/          ← ONE lazy.nvim spec file per plugin
        ├── telescope.lua     treesitter.lua    lsp-config.lua
        ├── autocomplete.lua  conform.lua       lualine.lua
        ├── neotree.lua       comment.lua       todo.lua
        ├── octo.lua          markview.lua      mdx.lua
        └── tokyonight.lua
```

And what `init.lua` does, step by step:

**Step 1 — bootstrap lazy.nvim.** Compute
`lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"`
(→ `~/.local/share/nvim/lazy/lazy.nvim`), `git clone` it if the directory
doesn't exist yet, then the crucial line:

```lua
vim.opt.rtp:prepend(lazypath)
```

*Before* this line, `require("lazy")` would fail with `module 'lazy' not
found` — lazy.nvim's directory isn't on runtimepath yet. *After* it, section 3
rules kick in: `require("lazy")` finds
`~/.local/share/nvim/lazy/lazy.nvim/lua/lazy/init.lua`. Bootstrap is nothing
but "make the searcher able to find it."

**Step 2 — `require("me")`.** Resolves to `lua/me/init.lua`, which is just
three requires: `me.remap`, `me.opts`, `me.todos`. This runs your keymaps and
options **before any plugin loads** — deliberate, because `vim.g.mapleader`
must be set before plugins define `<leader>` mappings, and lazy.nvim warns you
if it isn't.

**Step 3 — `require("lazy").setup("plugins")`.** The string `"plugins"` tells
lazy.nvim: *import every Lua module in `lua/plugins/`*. It globs
`lua/plugins/*.lua` on your runtimepath, requires each one, and expects each
file to `return` a spec table (lesson 04 dissects specs). Adding a plugin to
your setup = dropping one more file in that directory. No central list to
edit — the directory *is* the list.

**Step 4 — colors.** `vim.cmd([[colorscheme tokyonight-night]])` can only work
now, after step 3, because the `colors/tokyonight-night.lua` file lives inside
the tokyonight plugin's rtp entry. Then two highlight overrides:

```lua
vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
```

clear the background so your terminal's transparency shows through. Order
matters here too: a `colorscheme` command *resets* highlight groups, so these
lines must come after it — put them before and tokyonight would stomp them.

## 5. The startup, as a tree

```
nvim
└── ~/.config/nvim/init.lua                (found via stdpath("config"))
    │
    ├── 1. BOOTSTRAP
    │   ├── lazypath = stdpath("data").."/lazy/lazy.nvim"
    │   ├── git clone ... (first run only)
    │   └── vim.opt.rtp:prepend(lazypath)   ← require("lazy") now resolvable
    │
    ├── 2. require("me")                    → lua/me/init.lua
    │   ├── require("me.remap")             → lua/me/remap.lua   (keymaps, leader)
    │   ├── require("me.opts")              → lua/me/opts.lua    (options)
    │   └── require("me.todos")             → lua/me/todos.lua   (todo helpers)
    │
    ├── 3. require("lazy").setup("plugins")
    │   ├── glob lua/plugins/*.lua          (telescope.lua, treesitter.lua, ...)
    │   ├── each file returns a spec table  (lesson 04)
    │   ├── install missing plugins to ~/.local/share/nvim/lazy/<name>
    │   └── load now, or arm lazy triggers  (event= / cmd= / keys= / ft=)
    │
    ├── 4. vim.cmd([[colorscheme tokyonight-night]])
    │       (resets highlight groups — that's why step 5 must follow)
    │
    └── 5. nvim_set_hl(0, "Normal",      { bg = "none" })  ┐ transparent
            nvim_set_hl(0, "NormalFloat", { bg = "none" })  ┘ background
```

## 6. Load-order rules of thumb

- **Leader before plugins** — `vim.g.mapleader` in `me.remap`, required in
  step 2, before `lazy.setup` in step 3. Move it later and every plugin
  `<leader>` mapping silently binds to the default `\`.
- **Options can be overwritten later.** If `me/opts.lua` sets something and a
  plugin (or ftplugin) changes it afterwards, the plugin wins because it runs
  later. Lesson 02's `:verbose set <option>?` tells you *who* set it last.
- **Highlights after colorscheme** — see step 4/5 above.
- **`require` runs a file once.** If `me/opts.lua` seems ignored after an
  edit, remember the `package.loaded` cache (section 3.3): restart, don't
  re-source.

## TRY IT

1. In a real nvim session, run `:lua vim.print(vim.opt.runtimepath:get())`
   and find: your config, lazy.nvim, tokyonight, and `$VIMRUNTIME`.
2. Run `:lua vim.print(vim.tbl_keys(package.loaded))` and spot `me`,
   `me.remap`, `me.opts`, `me.todos`, and a pile of `lazy.*` modules.
3. Predict, then verify with `:messages`, what happens if you move the two
   `nvim_set_hl` lines *above* the `colorscheme` line in your `init.lua`.
   (Put them back.)
4. Create `~/.config/nvim/plugin/probe.lua` containing
   `print("plugin/ auto-sourced!")`, restart nvim, run `:messages`, and
   confirm it ran without any `require`. Then delete it — surprise files in
   `plugin/` are how configs get haunted.
