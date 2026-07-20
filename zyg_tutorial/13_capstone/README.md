# Module 13 — Capstone: Build Your Own AoC Toolkit

Everything you wrote in modules 1–12 was throwaway. Each exercise parsed its
input from scratch, hand-rolled its own grid indexing, wrote BFS one more
time — and then you closed the file and never ran it again. That was the
point: reps build fluency.

This module is the opposite. You build the tool you keep: a small library of
the moves that every Advent-of-Code-style puzzle reuses, plus a CLI runner
that loads any puzzle's input at runtime, solves it, and times it. Then you
prove the toolkit works by cracking one final three-part puzzle with it.
When December comes, you clone this project, add a `day01.zig`, and go.

It's also the module where the pieces of the course stop being separate
topics. Iterators (11) feed BFS (12) which allocates through parameters (7)
inside a generic type (9) that a build script (10) wires into tests (3) —
one project, all of it at once.

## The project

```
13_capstone/
├── README.md              you are here
├── build.zig              complete — you don't touch the build system
├── build.zig.zon          complete
├── input/
│   └── final.txt          your puzzle input (grid + calibration log)
└── src/
    ├── main.zig           the runner — Milestone 4 (three TODO gaps)
    ├── lib/
    │   ├── parse.zig      input helpers — Milestone 1 (stubbed)
    │   ├── grid.zig       generic Grid(T) — Milestone 2 (stubbed)
    │   └── algo.zig       bfs, Counter, topK — Milestone 3 (stubbed)
    └── puzzles/
        └── final.zig      the mega-puzzle — Milestone 5 (stubbed)
```

Every file compiles as shipped. The test suite does not pass as shipped —
that's the to-do list. Each stub carries a `TODO` comment with hints and a
pointer back to the module that taught the technique.

### Build targets

| Command                                  | What it does                                |
| ---------------------------------------- | ------------------------------------------- |
| `zig build test`                         | every test in the project                   |
| `zig build test-parse`                   | just `src/lib/parse.zig` (Milestone 1)      |
| `zig build test-grid`                    | just `src/lib/grid.zig` (Milestone 2)       |
| `zig build test-algo`                    | just `src/lib/algo.zig` (Milestone 3)       |
| `zig build test-final`                   | just the puzzle's answer checker (M5)       |
| `zig build run -- final`                 | run the mega-puzzle on `input/final.txt`    |
| `zig build run -- final some/other.txt`  | same puzzle, explicit input file            |

Run everything from the project directory (`13_capstone/`). The build
script pins the working directory so `input/final.txt` resolves correctly.

The three lib files also work with the bare test runner you've used all
course — `zig test src/lib/parse.zig` — because they only import downward.
`src/puzzles/final.zig` is the one exception: its `../lib/` imports reach
*above* the file, which Zig only allows inside a module rooted higher up.
`zig build test-final` handles that (build.zig builds the full test binary
and filters it down to the puzzle's tests).

### Two rules, same as module 12

1. **Tests are the answer checker.** The tests in each lib file are the
   specification for what you're building; the tests in `final.zig` pin the
   example answers and the real answers for your input. Red = wrong,
   green = solved. Never edit a test to make it pass.
2. **Everything runs under `std.testing.allocator`.** A leak fails the
   test even when the answer is right. `defer`/`errdefer` discipline
   (module 7) is part of the exercise.

And one workflow habit worth keeping: solve **example-first**. Every part
of the puzzle has an example test over a six-line input you can check by
hand, and a real test over 57 KB you can't. Get the small one green before
you look at the big one.

## The mega-puzzle: The Relay Network

You've inherited an abandoned signal-relay field on a ridge. The site
survey is one file, two sections, separated by a blank line.

**Section 1 — the survey map.** A rectangular character grid: `.` is open
ground, `#` is debris you cannot cross, and the digits `0`–`9` mark the ten
relay stations (each digit appears exactly once). You can walk on stations
and open ground.

**Section 2 — the calibration log.** One record per line, written by
someone who clearly wasn't planning on parsing it later:

```
station 6 report: gain=9140, echo -6841, load: 161696, drift: 106920
```

Only the integers matter. **The first integer in a line is the station id;
every other integer is a calibration reading** of that record. Readings can
be negative. Stations appear in many records — the flaky ones get rechecked
constantly.

### Part 1 — Echo check

Some reading values repeat across the log; technicians call them echoes.
Find the reading value that occurs most often (the input guarantees a
unique winner). **Answer: that value multiplied by its number of
occurrences.** Mind the definition: station ids are *not* readings, and the
log is built to punish counting them.

### Part 2 — First link

Restore the line of sight between station `0` and station `9`. **Answer:
the fewest steps from `0` to `9`**, moving only up/down/left/right, never
entering `#`.

### Part 3 — Backbone load

A station's *calibration* is the sum of every reading in every one of its
records. The three best-calibrated stations become the network backbone,
and each pair among them gets a link. A link's *load* is the fewest-steps
distance between its two stations multiplied by the sum of their two
calibrations. **Answer: the total load of the three links.** Calibrations
run around 10^7 and there are three products to sum — this is i64
territory, which is why every part returns one.

### Worked example

```
0..#...9
.#.#.#..
.#...#.3
.#.###..
.#....7.
...#....

station 0: cal 5, drift -2, gain 5
station 3: cal 12, drift 5 [gain -7]
station 7: cal 5, drift 3
station 9: cal -2, gain 12, spike 5
station 3: recheck -7, cal 4
station 7: boost 10, cal 5
```

*Part 1:* the readings (ids excluded) contain `5` six times — no other
value comes close. Answer: `5 * 6 = 30`.

*Part 2:* the shortest `0` → `9` route threads between the `#` walls in
**11** steps.

*Part 3:* calibrations are station 0: `5-2+5 = 8`, station 3:
`12+5-7-7+4 = 7`, station 7: `5+3+10+5 = 23`, station 9: `-2+12+5 = 15`.
The backbone is stations 7, 9, 0. Distances: `d(7,9) = 5`, `d(7,0) = 10`,
`d(9,0) = 11`. Load: `5*(23+15) + 10*(23+8) + 11*(15+8) = 190 + 310 + 253 =
753`.

These three numbers — 30, 11, 753 — are pinned by the `example` tests in
`src/puzzles/final.zig`, so you can debug against an input you can trace
by hand.

## Milestone plan

Do the milestones in order; each one builds on the last. Finish one per
sitting and the capstone takes five sittings — there's no prize for
rushing it.

Before you start, get a baseline:

```sh
cd 13_capstone
zig build test        # a handful pass by accident; most of the suite is red
zig build run -- final    # runs! ...and reports -1 for every part
```

That red wall is the project. Each milestone turns one file green.

### Milestone 1 — parse.zig

```sh
zig build test-parse      # target: 14/14
```

Five tools: a `lines` iterator, a `blankLineBlocks` iterator,
`parseIntLines`, `extractInts`, and `fields`/`field`. The test suite at the
bottom of the file is the exact specification — read it before writing
anything.

Hints, if you want them:

- Both iterators are the module 11 exercise-01 pattern: state in the
  struct, `next()` returns `?[]const u8`, callers loop
  `while (it.next()) |line|`. The state here is just "the text I haven't
  consumed yet".
- `extractInts` is the single most valuable function in the file. Scan
  byte-by-byte; a digit — or a `-` immediately followed by a digit —
  starts a number. Module 5's `std.fmt.parseInt` finishes the job. Get the
  `"minus rules"` test green last.
- Owned-slice returns (`parseIntLines`, `extractInts`) are the module 7/8
  combo: `ArrayList` + `errdefer deinit` + `toOwnedSlice`.

### Milestone 2 — grid.zig

```sh
zig build test-grid       # target: 13/13
```

`Grid(T)` packages module 12's flat-slice trick: one allocation,
`rows * cols` cells, cell `(r, c)` at flat index `r * cols + c`. You fill
in `index`, `fromText`, `inBounds`, `find`, the neighbor iterator's
`next()`, and `dump`.

- `index` first — `at`/`set` are already written in terms of it, so one
  line turns several tests from bizarre to merely red.
- `fromText` wants two passes over `std.mem.tokenizeScalar(u8, text, '\n')`
  (module 5): validate and measure, then copy. The error cases
  (`NotRectangular`, `EmptyGrid`) have their own tests.
- The neighbor iterator is module 11 exercise 01 again, plus the
  signed/unsigned dance: `center.row` is `usize`, the deltas are signed.
  Widen to `i64`, add, bounds-check, then `@intCast` back.
- `dump` looks like a throwaway; it isn't. When part 3 misbehaves, printing
  the grid you *think* you parsed is the fastest bug-finder there is.

### Milestone 3 — algo.zig

```sh
zig build test-algo       # target: 25/25 (grid's 13 ride along via the import)
```

- `bfs` is module 12's hill-route search, promoted to a library function.
  The queue is an `ArrayList(Pos)` plus a head index you only increment;
  distances live in an allocated `[]u32` @memset to a sentinel. The new
  idea is the `comptime canStep: fn (u8, u8) bool` parameter — the caller
  decides what a legal step is, exactly like `std.mem.sort` takes a
  comparator (module 9). The climbing-rule test shows why this matters:
  same grid, two rules, two different answers.
- `Counter(K)` wraps the `getOrPut` counting idiom from module 8 so you
  never type it again. `mostCommon` is a max-scan over `map.iterator()`.
- `topK` is dupe + `std.mem.sort` descending + keep the first k. Wrapping
  the caller's `lessThan` in a flipped comparator is a one-struct-fn trick
  worth knowing.

### Milestone 4 — the runner

```sh
zig build run -- final    # target: real input size, real timings, -1 answers
```

`src/main.zig` runs as shipped, but three marked gaps degrade it:
`TODO(runner-1)` (puzzle lookup that can actually say no),
`TODO(runner-2)` (read the input file at runtime), and `TODO(runner-3)`
(wall-clock timings). Fix them in order; each is a few lines.

- runner-1: `std.mem.eql` over the `puzzles` table (module 5). The
  `findPuzzle` tests in the same file check both directions —
  `zig build test` runs them.
- runner-2: `std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(...))`
  — module 10, and the exact shape is in `docs/zig-0.16-notes.md`. This is
  the line that makes the toolkit real-AoC-ready: module 12 baked inputs
  in with `@embedFile`; a tool that needs recompiling per input isn't a
  tool.
- runner-3: two `std.Io.Clock.awake.now(io)` timestamps around the call
  and `durationTo` between them — module 11's `05_perf_habits.zig` did
  exactly this. (`std.time.Timer` from older tutorials is gone in 0.16.)

Done when `zig build run -- final` prints the input's true byte count and
per-part timings — with `-1` answers, because the puzzle is still stubs.

### Milestone 5 — the puzzle

```sh
zig build test-final      # target: all six answer tests green
```

Now spend the toolkit. Implement `part1`, `part2`, `part3` in
`src/puzzles/final.zig`, one at a time, example test first each time. If
you built the library, none of the three parts is longer than ~30 lines,
and none of them contains a single hand-rolled loop over raw input bytes —
that's the whole argument for owning a toolkit.

Rough shapes: part 1 is `blankLineBlocks` + `lines` + `extractInts` +
`Counter`. Part 2 is `Grid.fromText` + `find` + `bfs`. Part 3 is all of the
above plus `topK`, and it's the one that punishes an i32 anywhere in the
chain.

When all six are green, take the victory lap:

```sh
zig build test                                # the whole suite, green
zig build run -- final                        # three answers, three timings
zig build -Doptimize=ReleaseFast run -- final # flags go BEFORE the step name;
                                              # watch the timings collapse
```

## Build-system notes

`build.zig` is fully written and commented; module 10's wordcount walkthrough
covers most of it. The three things it does that wordcount didn't:

- **One module, file-relative imports.** wordcount split lib and exe into
  two named modules. Here `main.zig` reaches everything through relative
  paths (`@import("lib/parse.zig")`), which keeps the bare
  `zig test src/lib/whatever.zig` workflow from modules 1–12 working.
- **`setCwd(b.path("."))`** on every run step: the runner and the answer
  tests open `input/final.txt` by relative path at runtime, so their
  working directory must be the project root no matter where `zig build`
  is invoked from.
- **Focused test steps.** `test-parse`/`test-grid`/`test-algo` are small
  modules rooted at each lib file; `test-final` reuses the full test build
  with a name filter (`.filters`), because `final.zig` can't be a module
  root (see above).

Also note the last `test { _ = @import(...); }` block in `main.zig`: test
blocks only run for files the test build actually references, so the
runner's root file explicitly pulls each file in. Forget that in your own
projects and a whole file's tests silently stop running.

## Where to go next

The course is over. The toolkit isn't — it's designed to grow. In rough
order of payoff:

- **Play a real Advent of Code.** adventofcode.com, any past year;
  December is better with company. The loop this project trained:
  `src/puzzles/day01.zig` with `part1`/`part2`, one line in main.zig's
  table, input file in `input/`, example test first, `zig build run --
  day01`. No build.zig changes needed — that was the point of the table.
- **Grow `algo.zig` the honest way** — when a puzzle demands it, not
  before. First candidates: Dijkstra (BFS + `std.PriorityQueue` — see the
  0.16 notes; weighted grids show up every year), memoized recursion (an
  `AutoHashMap` cache threaded through a recursive count — the "lanternfish
  problem" family), and `binarySearch` over a monotone answer space
  ("minimum X such that...").
- **Grow `grid.zig`**: a `Pos3`/`Grid3` for the annual 3D puzzle, a
  `Dir` enum with `turnLeft`/`turnRight` for walking-robot puzzles, an
  iterator over all cells matching a predicate.
- **Read the std source you now have taste for.** You've used
  `std.mem.tokenizeScalar` fifty times; go read it —
  `~/.local/share/zig-0.16.0/lib/std/mem.zig` — and notice it's the same
  iterator pattern you wrote in `parse.zig`. `std.Io.Writer` and
  `std.ArrayList` are the next best reads. The standard library is the
  best Zig codebase you have free access to.
- **ziglings** (https://codeberg.org/ziglings/exercises) if you want more
  reps on language corners this course moved past quickly.

If you get stuck, `solutions/13_capstone/` mirrors this whole project in
working form. Same policy as module 12: it's the morning-after solutions
thread. Fight first.
