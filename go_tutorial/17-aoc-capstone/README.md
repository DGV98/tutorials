# 17. Advent of Code Capstone

Sixteen modules of syntax, idioms, and stdlib — this is where they pay off.
This module is four original puzzles written in the authentic Advent of Code
format: a short story, a real input file, a Part One, and a Part Two that
reuses your parsing but demands more thought. No new Go features are
introduced here on purpose. Everything you need is behind you; the skill being
trained is *assembling* it under puzzle conditions — read a spec carefully,
parse hostile-looking text, pick the right data structure, and know when brute
force will not cut it.

Work them like real AoC days: get the tiny examples in `capstone_test.go`
passing first, then unleash your code on the real `inputN.txt`. The expected
answers for the real inputs are hard-coded in the tests, exactly like the
answer box on the website.

## What you'll learn

- Turning a raw multi-line input string into numbers, grids, and structs
  without ceremony (modules 03, 05, 07, 15)
- Using maps as accumulators and as sets (module 06)
- Scanning 2D grids: neighbor checks, bounds checks, walking rays (module 05)
- Cycle detection: solving "run this a billion times" in milliseconds
  (modules 05, 06)
- Structured parsing with `strings.Cut` into structs, and breadth-first
  search over a `map[string][]string` graph (modules 07, 09, 06)
- The AoC workflow itself: examples first, then the real input, then Part Two

---

## Day 1: Candy Cane Accounting

The North Pole mailroom runs on candy canes, and the mailroom runs on chaos.
Every elf scribbles a shift report on whatever paper is nearby: their name,
then how many candy canes they moved that shift — positive numbers for
deliveries, negative for "quality control incidents" (snacking). The reports
have all been dumped into one file, one shift per line:

```
tinsel 10 -2 3
jolly 5 5
tinsel 1
```

**Part One.** The head accountant needs the grand total: the sum of *every*
number in the file. For the example above that is `10 + (-2) + 3 + 5 + 5 + 1 =
22`.

**Part Two.** The elf with the highest personal total wins the Golden Ladle.
Elves appear on multiple lines — `tinsel` above worked two shifts for a total
of `12`, beating `jolly`'s `10` — so you must aggregate per elf before
comparing. Answer with the winner's *name*.

*Modules that apply:* `strings.Fields` and `strconv.Atoi` (07, 15) shred a
line in two calls; a `map[string]int` (06) is the canonical accumulator for
Part Two. Watch out: personal totals can be negative, so "start the maximum
at 0" is a bug.

## Day 2: The Lantern Grove

South of the workshop lies the lantern grove, mapped as a rectangular grid:
`.` is open snow, `T` a fir tree, `L` a lantern.

```
.T.
.L.
T..
```

**Part One.** A tree is *decorated* if at least one of its up-to-eight
neighbors (including diagonals) is a lantern. Count the decorated trees. In
the example, both trees touch the central lantern: `2`.

**Part Two.** At dusk each lantern shines a beam in each of the four cardinal
directions. A beam lights every consecutive `.` cell and stops at the first
cell that is not `.` — a tree or another lantern (the blocker is not lit) —
or at the grid's edge. Count the *distinct* `.` cells that end up lit. In the
example the beam going up hits the tree immediately, and the other three
light one snow cell each: `3`. Overlapping beams light a cell only once.

*Modules that apply:* index the grid as a `[]string` of rows and remember that
`row[c]` is a `byte` (05, 07). Bounds-check before you peek — Go slices and
strings panic on out-of-range indexes, they don't return a sentinel. For
Part Two, a `map[cell]bool` used as a set (06, 09) makes "count distinct"
trivial; struct keys work in maps because structs are comparable.

## Day 3: The Clockwork Carousel

Inside Santa's music box, tin figurines ride a carousel with numbered slots
(slot 0 on the left). The winding card lists maintenance instructions that run
every time the crank completes one turn. The first line of your input is the
starting arrangement; each remaining line is an instruction:

- `spin X` — the ring rotates right: the last `X` figurines move, in order,
  to the front. `spin 2` turns `abcde` into `deabc`.
- `swap I J` — the figurines in slots `I` and `J` trade places.
- `reverse I J` — the run of figurines in slots `I` through `J` inclusive
  reverses order.

All indices refer to *slots*, never to letters. Example:

```
abcde
swap 0 4
spin 2
```

**Part One.** What does the carousel show after one full turn of the crank?
The example: `swap 0 4` gives `ebcda`, then `spin 2` gives `daebc`.

**Part Two.** The elves left the machine running overnight:
**1,000,000,000** turns. A 180-instruction card times 10⁹ turns is ~10¹¹
operations — simulating it is hopeless. But the arrangement is a finite state
updated by a fixed rule, so the sequence of after-each-turn states *must*
eventually revisit one it has seen before, and from there it loops forever.
Record each state in a `map[string]int` (state → turn number when first
seen); the moment you meet a repeat you know the cycle's start and length,
and modular arithmetic jumps you straight to turn one billion. The example
cycles every 6 turns, and `1e9 % 6 = 4`, so the answer is the arrangement
after 4 turns: `dacbe`.

*Modules that apply:* strings are immutable (07), so convert to `[]byte`,
mutate, convert back. Building the spin with `append` onto a *fresh* slice
avoids the aliasing trap from module 05 — appending a slice to itself
overwrites bytes you still need to read. The seen-states map is module 06;
keys must be `string`, not `[]byte`, because slices aren't comparable.

## Day 4: The Reindeer Express

The Reindeer Express timetable lists every sleigh route in the mountains.
Routes are strictly **one-way** — reindeer refuse to fly a route backwards —
and each line follows this exact grammar:

```
route R-1: NORTH-POLE => ICE-FALLS | distance 10 | toll 2
route R-2: ICE-FALLS => SANTAS-WORKSHOP | distance 20 | toll 9
route R-3: NORTH-POLE => SANTAS-WORKSHOP | distance 99 | toll 6
```

An id, origin `=>` destination, a distance in miles, and a toll in candy
canes. Station names are single hyphenated tokens — no spaces inside a name.

**Part One.** The elves' travel budget only covers routes with a toll of at
most 5. What is the total distance of all budget routes? In the example only
`R-1` qualifies: `10`.

**Part Two.** Santa needs the fastest paperwork, not the shortest flight:
find the minimum *number of routes* to get from `NORTH-POLE` to
`SANTAS-WORKSHOP`, respecting direction. If the workshop is unreachable,
answer `-1`. In the example the direct route `R-3` wins with `1` hop even
though it is the longest in miles. Fewest edges on an unweighted graph is
breadth-first search: a queue of stations to visit plus a visited set. A
plain slice is a fine queue — `q = append(q, next)` to push,
`cur, q := q[0], q[1:]` to pop.

*Modules that apply:* parse each line into a `route` struct (09) with
`strings.Cut` / `strings.TrimPrefix` (07) — Part Two needs the endpoints, so
resist the urge to grab just the two numbers. The graph is a
`map[string][]string` adjacency list and the visited set another map (06).

---

## Gotchas & idioms

- **Trim before you split.** Input files end with a newline, so a naive
  `strings.Split(input, "\n")` yields a phantom empty last line — and
  `strings.Fields("")[0]` or `line[0]` on it panics. The one-liner
  `strings.Split(strings.TrimSpace(input), "\n")` kills the whole class of
  bug. Every solver in this module wants it, so write it once as a helper.
- **Puzzle inputs are trusted.** Threading `error` returns through eight
  solvers buys nothing here — if `strconv.Atoi` fails, your *parser* is
  wrong. A tiny `mustInt` helper that panics keeps solver bodies about the
  puzzle, not about plumbing. (In production code you'd do the opposite;
  module 11 explained when each stance is right.)
- **`grid[r][c]` on a `[]string` gives a `byte`.** Compare against `'T'`
  (byte literal), not `"T"` (string). Fine here because the grids are pure
  ASCII; revisit module 07 before trying this on Unicode input.
- **Maps have no order.** Day 1 Part Two scans a map for the maximum — that's
  deterministic only because the maximum is unique. If you ever need "first"
  or "smallest key wins" semantics, sort the keys first.
- **The zero value is not always a safe seed.** Finding a maximum that can be
  negative means `best := 0` silently wins over every elf. Seed from the
  first element, or track "have I seen anything yet".
- **Appending a slice to itself aliases.** `s = append(s[n-x:], s[:n-x]...)`
  reads memory that the append may have already overwritten. Copy into a
  fresh slice when rotating.
- **A billion iterations is a design smell, not a performance problem.** When
  Part Two multiplies the step count by a million, AoC is telling you the
  state space is small: find the cycle (day 3), use a map instead of a giant
  slice, or find the closed form. Optimizing the inner loop is the trap.
- **Copy the examples into tests before touching the real input.** The tests
  here already do it — that's the habit to steal. A 3×3 grid you can check by
  hand localizes a bug in seconds; a 60×70 grid cannot.

## In Advent of Code

This module *is* Advent of Code, minus the leaderboard. The shapes repeat
every December: day 1 is always a warm, line-parsing handshake; a grid puzzle
like day 2 shows up in the first week; a "now do it a billion times"
simulation like day 3 is a mid-month rite of passage; and dense line grammars
feeding graph or set logic like day 4 fill the back half. The meta-skills
transfer directly too — build parsing you can reuse for Part Two, test
against the worked example before the real input, and when the numbers get
astronomical, look for structure instead of speed.

## Exercises

All eight functions take the raw input text (the entire file as one string)
and are stubbed in `day1.go` … `day4.go`. The real inputs are `input1.txt` …
`input4.txt` in this directory; the tests load them for you.

- **`SolveDay1Part1(input string) int`** — sum every integer on every line.
  Hints: `strings.Fields` per line; skip `fields[0]`, `Atoi` the rest.
- **`SolveDay1Part2(input string) string`** — name of the elf with the
  largest per-elf total. Hints: `map[string]int` accumulator; beware
  negative totals when picking the max.
- **`SolveDay2Part1(input string) int`** — trees with a lantern in their
  8-neighborhood. Hints: two nested loops over the grid, two more (`-1..1`)
  over the neighborhood; bounds-check first, skip `(0,0)`.
- **`SolveDay2Part2(input string) int`** — distinct snow cells lit by
  cardinal beams. Hints: from each `L`, walk each of 4 directions while in
  bounds and on `'.'`; record cells in a set; return `len(set)`.
- **`SolveDay3Part1(input string) string`** — arrangement after one run of
  the card. Hints: parse instructions once into a `[]instruction` of your
  own struct; work on `[]byte`; the three ops are 3–5 lines each.
- **`SolveDay3Part2(input string) string`** — arrangement after 10⁹ runs.
  Hints: reuse Part One's "run the card once" function; store every state in
  `map[string]int` plus a `[]string` history; on the first repeat, the
  answer is `history[first+(target-first)%cycleLen]`.
- **`SolveDay4Part1(input string) int`** — total distance where toll ≤ 5.
  Hints: `strings.Cut` peels the line apart left to right; parse into a
  struct with all five fields even though Part One uses two.
- **`SolveDay4Part2(input string) int`** — fewest one-way routes from
  `NORTH-POLE` to `SANTAS-WORKSHOP`, `-1` if unreachable. Hints: build
  `map[string][]string`; BFS with a slice queue and a `map[string]int`
  distance table that doubles as the visited set.

## Check your work

```
go test ./17-aoc-capstone/
```

Run it from the repository root. All 8 tests fail on the stubs; make them
green one day at a time — `go test -run 'Day1' ./17-aoc-capstone/` scopes the
run to one day. Reference implementations live in `solution/`
(`go test ./17-aoc-capstone/solution/` passes with the same test file), but
they are worth more *after* your own stars are in the bag.
