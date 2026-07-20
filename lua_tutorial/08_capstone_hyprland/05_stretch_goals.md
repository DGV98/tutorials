# 05 — Stretch goals

You have a working generator. Here's where it can go next. Nothing below is
required; each item is a self-contained project sized between an evening and
a weekend. Same safety rule as always: **generators write into `build/`,
you copy by hand.**

## 1. Generate `hyprlock.conf` (106 lines in your setup)

hyprlock speaks hyprlang too, but with a twist our serializer can't express
yet: it repeats *sections*, not just keys — a lock screen has several
`label { ... }` blocks and possibly multiple `input-field { ... }` blocks.
Our convention maps one key to one table, so there's no way to say
"two `label` sections".

**Extension:** teach `emit()` a third table shape — an *array of tables*
means "repeat this section":

```lua
label = {
  { text = "$TIME",       font_size = 96, position = "0, 300" },
  { text = "Hi, David",   font_size = 24, position = "0, 150" },
}
```

In `emit()`, when `is_array(v)` is true, check the element type: strings →
repeated keys (current behavior), tables → repeated `k { ... }` blocks.
That's a ~6 line change, and it makes the serializer cover essentially all
of hyprlang. Write the result to `build/hyprlock.conf`.

## 2. Generate `hyprpaper.conf` (38 lines) — the single-source-of-truth win

hyprpaper is trivial hyprlang (`preload = path`, `wallpaper = monitor,path`),
but it *names your monitors* — the same five names living in
`04_port_your_config.lua`. Hand-maintained, the two files drift; generated,
they can't:

```lua
local monitors = dofile("monitors.lua")   -- one table both generators share
for _, m in ipairs(monitors) do
  paper:add("wallpaper", m.name .. "," .. wallpaper_for(m))
end
```

Move the monitor table into its own file that returns the table (like
lesson 02 returns its exports), and `dofile` it from both generators.
Rename a monitor once; both configs update.

## 3. A `Makefile` (or a zsh one-liner) for the regen+diff loop

The loop you'll run hundreds of times deserves a shortcut:

```make
gen:
	luajit 04_port_your_config.lua

diff: gen
	-diff -u ~/.config/hypr/hyprland.conf build/hyprland.conf

install: diff
	cp ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.bak
	cp build/hyprland.conf ~/.config/hypr/hyprland.conf
	hyprctl reload
```

(The `-` before `diff` tells make to continue even when files differ —
diff exits 1 on any difference.) Note `install` still starts with a backup,
and it's still *you* typing `make install`. Zsh alternative for your
`.zshrc`:

```sh
alias hyprgen="luajit ~/personal/tutorials/lua_tutorial/08_capstone_hyprland/04_port_your_config.lua \
  && diff -u ~/.config/hypr/hyprland.conf ~/personal/tutorials/lua_tutorial/08_capstone_hyprland/build/hyprland.conf"
```

## 4. Watch mode

Regenerate on every save while you're porting. `entr` (in the Arch repos)
is the clean way:

```sh
ls *.lua | entr -c luajit 04_port_your_config.lua
```

Or pure inotify: `while inotifywait -e close_write *.lua; do luajit 04_port_your_config.lua; done`.
Pair it with `nvim -d build/hyprland.conf ~/.config/hypr/hyprland.conf` in
another ghostty pane and `:diffupdate` after each save.

## 5. One palette table, many dotfiles

You already solved exercise 5 (a `palette` table feeding
`col.active_border`). Now aim it at everything that hard-codes your
tokyonight colors:

- **hyprland**: border colors, shadow color — via the existing serializer.
- **waybar** (`style.css`): write a tiny CSS emitter — it's just
  `string.format("@define-color %s #%s;", name, hex)` per color.
- **ghostty**: its config is `key = value` lines — an even simpler emitter.
- **hyprlock**: labels and input-field colors from the same table.

Structure: `palette.lua` returns `{ blue = "7aa2f7", bg = "1a1b26", ... }`;
one emitter per output format; a top-level `generate_all.lua` calls each.
Change one hex value, regenerate, and your whole desktop agrees. This is
the point where "config generator" quietly becomes "dotfiles framework" —
and where you'll be glad everything asserts and diffs before it deploys.

## 6. Read live state back (bridge to modules 06/07)

`hyprctl monitors -J` prints your *actual* connected monitors as JSON.
Pure LuaJIT has no JSON parser built in, but Neovim does:

```lua
-- run with: nvim --clean -l probe_monitors.lua
local out = vim.fn.system({ "hyprctl", "monitors", "-J" })  -- vim.fn.system() ≈ system() Vimscript builtin
local mons = vim.json.decode(out)                            -- built-in JSON parser
```

Generate the `monitor =` lines from what's actually plugged in, instead of
maintaining them by hand. Guard it so the generator still works when
`hyprctl` isn't available (pcall, fall back to the static table).

## 7. Version control the generator, not the artifact

When this moves into your dotfiles repo: commit the `.lua` sources, add
`build/` to `.gitignore`. The generated file is reproducible by definition —
`git diff` on Lua that *means* something beats `git diff` on 390 lines of
output. (If you symlink `~/.config/hypr/hyprland.conf` into a dotfiles repo
today, the generator slots into the same workflow — it just writes the file
the symlink points at, via your manual copy step.)
