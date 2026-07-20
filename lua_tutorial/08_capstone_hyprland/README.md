# 08 — Capstone: generate `hyprland.conf` from Lua

Hyprland does **not** speak Lua. Its config language is **hyprlang** — the
`key = value` / `section { ... }` format you already have ~390 lines of in
`~/.config/hypr/hyprland.conf`. You can't port that config *to* Lua, but you
can do something better: write a Lua program that **generates** it. Lua
becomes your source of truth; `hyprland.conf` becomes a build artifact, like a
compiled binary you'd never edit by hand.

## Why this is the perfect capstone

Every earlier module earns its keep here:

| Lua skill | Where it pays off |
|---|---|
| Tables (module 03) | `general { gaps_in = 3 }` **is** a nested Lua table |
| Arrays + `ipairs` | 5 `monitor =` lines, 4 `exec-once =` lines, dozens of `bind =` lines are just arrays |
| `string.format` (module 01) | rendering each `key = value` line |
| Loops | 18 workspace binds from 4 lines of Lua — the single best argument for this whole idea |
| Metatables (module 04) | `$mainMod` variables that render themselves, a config object with a pleasant API |
| `io` / files (module 05) | writing `build/hyprland.conf` |

## The workflow

1. Edit the Lua config (`04_port_your_config.lua` is your starting template).
2. Run the generator: `luajit 04_port_your_config.lua` → writes `build/hyprland.conf`.
3. Diff against reality: `diff build/hyprland.conf ~/.config/hypr/hyprland.conf`.
4. Port one section at a time until the diff is empty (or only harmless noise).
5. Only then — by hand, after a backup — copy or symlink the generated file
   into `~/.config/hypr/` and run `hyprctl reload`.

## Safety rule (non-negotiable)

**Nothing in this module ever touches `~/.config/hypr/`.** Every script
writes only into this directory's `build/` subfolder. The final copy into
your real config is always a manual step *you* take, after
`cp ~/.config/hypr/hyprland.conf ~/.config/hypr/hyprland.conf.bak`.
Never wire the generator up to auto-overwrite the live file — a typo in the
generator should cost you a diff, not a working session.

## Files

| File | What it does |
|---|---|
| `01_model_the_config.lua` | Your real config re-expressed as plain Lua data tables; prints a summary |
| `02_serializer.lua` | The engine: walks a model table and emits hyprlang text; snapshot-tests itself; writes `build/hyprland.conf` |
| `03_dsl.lua` | The ergonomic layer: `bind()`, `monitor{}`, `$var` objects via metatables; proves it produces byte-identical output |
| `04_port_your_config.lua` | The full worked example — your monitors, exec-once lines, general/decoration — plus diff/test instructions |
| `05_stretch_goals.md` | hyprlock/hyprpaper generators, Makefile, file-watching, shared color palette |
| `exercises.lua` | Extend the DSL yourself: media binds, workspace loops, windowrules, env, palette, per-host merge |
| `solutions.lua` | Complete solutions with the key insight noted for each |

Note: `02`, `03`, and `04` all write `build/hyprland.conf` — whichever you ran
last owns the file. Run `04` before diffing against your real config.
`03`, `04`, `exercises` and `solutions` load earlier lessons with `dofile`,
so keep the files together in this directory.

## How to run

```sh
cd 08_capstone_hyprland
luajit 01_model_the_config.lua
luajit 02_serializer.lua
luajit 03_dsl.lua
luajit 04_port_your_config.lua
luajit exercises.lua      # then edit it, following the TODOs
luajit solutions.lua
```

## Time estimate

Lessons: 2.5–3.5 hours. Exercises: ~1 hour. Actually porting the remaining
~390 lines of your real config: an evening of pleasant diffing.
