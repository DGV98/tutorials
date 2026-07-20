# Module 12 — The AoC Gauntlet

Five original Advent-of-Code-style problems. No new Zig here: this module is
where everything from modules 1–11 gets used in anger, the way you'd use it
on a real December morning.

## The AoC workflow

Every problem in this genre plays out the same way, and each directory here
is set up to match:

1. **Read the problem** — `README.md` in the problem directory. It ends with
   a small worked example and the example's expected answers.
2. **Parse the input** — `input.txt` is your personal puzzle input. The
   starter `solve.zig` already embeds it at compile time
   (`@embedFile("input.txt")`), so there's no I/O to write and no
   working-directory games: `zig test solve.zig` from the problem directory
   is all you ever run.
3. **Solve Part 1** — implement `part1()`. Get the example test green first;
   the example is small enough to check by hand when you disagree with it.
4. **Solve Part 2** — the twist. Part 2 always reuses your parsing and most
   of your Part 1 thinking, then bends one rule.

## The tests are the answer checker

On the real AoC website you type a number into a box and get a yes/no. Here,
the bottom of each `solve.zig` plays that role: the `"part1 example"` /
`"part2 example"` tests assert the worked example from the README, and the
`"part1"` / `"part2"` tests assert the *actual answers* for your
`input.txt`. Red means wrong answer, green means solved. Work example-first:

```sh
cd 01_supply_packs
zig test solve.zig        # or :!zig test % from nvim
```

Everything runs with `std.testing.allocator`, so a leak fails the test even
when the answer is right. That's deliberate — clean up what you allocate.

## Hint policy

The starter comments give you parsing hints and name the technique and the
module that taught it. They will *not* hand you the Part 2 twist — spotting
the twist is the actual puzzle. If you're truly stuck, `solutions/`
mirrors this tree, but treat it like the morning-after solutions thread:
reading it before you've fought the problem is how you learn nothing.

## What each problem leans on

| Problem            | Core skills                                      | Modules    |
| ------------------ | ------------------------------------------------ | ---------- |
| `01_supply_packs`  | blank-line groups, parseInt, max/top-3           | 02, 03, 05 |
| `02_signal_grid`   | flat-slice 2D grids, directional scans           | 02, 05     |
| `03_badge_audit`   | string halves/groups, u64 bitsets, @ctz          | 05, 11     |
| `04_hill_route`    | BFS, ArrayList-as-queue, allocated dist arrays   | 07, 08     |
| `05_worry_engine`  | stanza parsing, tagged unions, simulation, u64   | 05, 06, 08 |

They escalate: 1 is a warm-up, 5 is a proper fight. Do them in order.

Once all five are green, the course closes with module 13 (`13_capstone`),
where you distill what you did here into a reusable AoC toolkit.
