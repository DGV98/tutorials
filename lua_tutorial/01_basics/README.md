# Module 01 — Lua Fundamentals

Your first contact with Lua: values, strings, numbers, control flow, and the
handful of idioms (`x = x or default`, the `and/or` ternary) that make up half
of every Neovim config on the internet. It comes first because everything
later — tables, functions, modules, the `vim.*` API — is built out of exactly
these pieces. The dialect taught here is **LuaJIT / Lua 5.1**, the one Neovim
actually embeds; version notes flag the spots where newer-Lua blog posts will
lie to you (`//`, integers, `goto`).

## Files

| File | What it covers |
| --- | --- |
| `01_hello_world.lua` | `print()`, comments, chunks, every way to run Lua (luajit, `nvim -l`, `:luafile`, `:lua`) |
| `02_variables_and_types.lua` | nil/boolean/number/string, `type()`, dynamic typing, local vs global and the Neovim `_G` trap |
| `03_strings.lua` | Quoting, `[[long strings]]`, escapes, `..`, `#`, immutability, `string.*` tour, `s:method()` sugar |
| `04_numbers_and_math.lua` | Everything's a double, no `//` (use `math.floor`), `%`, `math.*`, `tonumber`/`tostring` |
| `05_control_flow.lua` | `if/elseif/else`, truthiness (0 and "" are TRUE), `while`, `repeat/until`, numeric `for`, `break`, goto-continue |
| `06_logic_and_idioms.lua` | `and`/`or` short-circuit, `or`-defaults, the ternary idiom and its false/nil pitfall, `==`/`~=`, comparison rules |
| `exercises.lua` | 7 exercises, ramping from hello-variables to a false-proof config default |
| `solutions.lua` | Complete solutions with the key insight of each exercise |

## How to run

From this directory:

```sh
luajit 01_hello_world.lua      # and so on for each file
```

Or open a file in Neovim and run `:luafile %` (output lands in `:messages`).
`nvim --clean -l <file>` works too — same engine.

Every file runs clean top to bottom and prints a readable story; read the
comments, run the file, then do the `-- TRY IT` prompts at the bottom by
editing the file itself and re-running.

## Time estimate

Roughly 2.5–3.5 hours: 15–25 minutes per lesson including the TRY IT edits,
plus about an hour for the exercises.
