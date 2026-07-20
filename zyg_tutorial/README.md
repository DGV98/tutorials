# Zig: Zero to Advent of Code

A hands-on Zig course you work through entirely in nvim. Thirteen modules take
you from "never seen Zig" to comfortably solving Advent-of-Code-style problems,
ending with a capstone project — your own reusable AoC toolkit. Every exercise
is test-driven: you open a file, implement the `TODO`s, and run the tests until
they pass.

**Toolchain:** Zig 0.16.0 + zls 0.16.0, both installed in `~/.local/bin`.
Zig's std library changed a lot in 0.15/0.16 — read
[docs/zig-0.16-notes.md](docs/zig-0.16-notes.md) before trusting any tutorial
or LLM answer you find elsewhere.

## The loop

1. `cd` into a module and read its `README.md` — that's the lesson.
2. Open the first exercise in nvim. The header comment says what to do.
3. Implement the `TODO`s, then run the tests:

   ```sh
   zig test 01_hello.zig        # from inside the module directory
   ```

   In nvim, `:!zig test %` runs the tests for the current file without
   leaving the editor (or make a keymap, e.g.
   `vim.keymap.set("n", "<leader>zt", ":!zig test %<CR>")`).
4. Red → implement → green. Then move to the next file.
5. Stuck? Each exercise has a reference answer in `solutions/` mirroring the
   same path. Try honestly first — the struggle is the learning.

`./check.sh 03` runs every exercise in module 03 and prints a pass/fail
summary; `./check.sh all` sweeps the whole course.

## Modules

| #  | Module                     | You learn                                                            |
| -- | -------------------------- | -------------------------------------------------------------------- |
| 01 | `01_basics`                | values, const/var, integers & floats, casts, printing/formatting      |
| 02 | `02_control_flow`          | if/switch as expressions, while, for, labels, defer                   |
| 03 | `03_functions_errors`      | functions, error sets, error unions, try/catch/errdefer               |
| 04 | `04_optionals`             | `?T`, orelse, unwrap-if, unwrap-while, optional pointers              |
| 05 | `05_arrays_slices_strings` | arrays, slices, sentinels, string handling with `std.mem`/`std.fmt`   |
| 06 | `06_structs_enums_unions`  | structs & methods, enums, tagged unions, switch payload capture       |
| 07 | `07_memory_allocators`     | pointers, the allocator interface, arenas, leak detection             |
| 08 | `08_collections`           | ArrayList, HashMaps, getOrPut, sorting, PriorityQueue                 |
| 09 | `09_comptime_generics`     | comptime, generic functions & types, inline for, reflection           |
| 10 | `10_io_and_build`          | the `Io` interface, files, stdin/stdout, args, build.zig projects     |
| 11 | `11_advanced_patterns`     | iterators, state machines, packed structs & bit tricks, reflection    |
| 12 | `12_aoc_gauntlet`          | five full AoC-style problems: parsing, grids, counting, BFS, sim      |
| 13 | `13_capstone`              | capstone: build your own AoC toolkit (library + CLI runner) and use it |

Work them in order — each module assumes the ones before it. Modules 1–6 are
the language core; 7–9 are what make Zig *Zig*; 10–12 turn knowledge into the
ability to ship a solution to a real problem; 13 consolidates everything into
a multi-file project you'll keep using for real Advent of Code.

## Reading the compiler, not fighting it

Zig's compile errors are the primary teaching tool of this course. When a test
fails to compile, read the first error top-to-bottom: it names the file, line,
and almost always the exact fix. `unused local` means delete or use it;
`error union is discarded` means you forgot `try`.

Two commands worth knowing from day one:

```sh
zig fmt .          # formats every .zig file in place — run it habitually
zig run file.zig   # for exercises with a main() instead of tests
```

## nvim

zls (Zig language server) is installed and enabled — you get diagnostics,
completion, go-to-definition, and hover docs out of the box. Zig ships its own
tooling philosophy: save the file, and zls surfaces most compile errors
without running anything.

The Zig language reference for exactly this version:
<https://ziglang.org/documentation/0.16.0/> — and the std lib source itself is
readable and worth grepping: `~/.local/share/zig-0.16.0/lib/std/`. In nvim,
`gd` (go to definition) on any `std.` symbol jumps straight into the std
source — reading it is a core Zig skill, not a workaround.
