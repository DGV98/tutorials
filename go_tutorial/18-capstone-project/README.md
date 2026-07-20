# 18. Capstone Project: `puzzlerunner`

Everything so far has been exercises — single functions with a test harness
waiting for them. This module is different: you're going to build a **real
program**. `puzzlerunner` is a command-line Advent-of-Code toolkit: puzzle
solutions plug into it as types, it loads their inputs from disk, runs them
(concurrently, if you ask), times them, and prints a result table:

```
$ go run ./18-capstone-project/cmd/puzzlerunner -all
DAY  NAME            PART 1  PART 2  TIME
1    Sled Ledger     127919  107668  152µs
2    Frozen Orchard  691     22      406µs
```

It's small enough to finish, real enough to teach you the last missing
skill: **organizing a multi-package Go program**. And when December comes,
it's genuinely the harness you'd want for Advent of Code — milestone 8 is
making it yours.

## What you'll practice

Nearly the whole course, on purpose:

- interfaces as plug-in points (module 10) — the `Solver` contract
- maps + sentinel errors (modules 06, 11) — the day registry
- file I/O and error wrapping (modules 11, 15) — input loading
- structs, methods, `time.Duration` (modules 09, 15) — results & timing
- worker pools, channels, `WaitGroup` (modules 13, 14) — parallel runs
- string parsing and grid BFS (modules 07, 17) — the two puzzle solvers
- `package main`, `flag`, `text/tabwriter` — an actual CLI

## The layout (your first multi-package program)

```
18-capstone-project/
├── runner/               the engine (package runner)
│   ├── runner.go         Solver interface + Result — provided, read it first
│   ├── registry.go       milestone 1: you implement
│   ├── input.go          milestone 2: you implement
│   ├── run.go            milestones 3-5: you implement
│   └── runner_test.go    the tests that gate milestones 1-5
├── solvers/              puzzle implementations (package solvers)
│   ├── day1.go           milestone 6: you implement
│   ├── day2.go           milestone 6: you implement
│   └── solvers_test.go   examples + real-input answers
├── inputs/               day1.txt, day2.txt — the real puzzle inputs
├── cmd/puzzlerunner/     the executable (package main)
│   └── main.go           milestone 7: you implement (no tests — run it!)
└── solution/             complete reference implementation
```

Until now every module was one package. Here there are three, and the
import graph is the lesson: `cmd/puzzlerunner` imports both `runner` and
`solvers`; `solvers` imports `runner` (only for the `var _ runner.Solver`
compile-time check); `runner` imports nobody. Import paths inside a module
are just `module-name/dir/path`, so this repo's packages import as:

```go
import (
    "gotutorial/18-capstone-project/runner"
    "gotutorial/18-capstone-project/solvers"
)
```

Low-level packages never import high-level ones — dependencies point
inward, `main` sits at the top wiring everything together. That shape
scales from this project to every Go service you'll ever read.

> The `solution/` tree is the same program with one mechanical difference:
> its files import `gotutorial/18-capstone-project/solution/runner` etc.,
> because a Go import path is just the directory path. The test files are
> byte-identical copies, as in every module.

## The puzzles

**Day 1: Sled Ledger.** The elves' sled-packing ledger has one line per
sled: a comma-separated list of parcel weights, like `12,7,33,2`. Part 1:
every sled is rated by its heaviest parcel — sum the heaviest parcel over
all sleds. Part 2: a sled's *imbalance* is its heaviest parcel minus its
lightest — sum the imbalance over all sleds. (A one-parcel sled is
perfectly balanced: imbalance 0.)

**Day 2: Frozen Orchard.** A snow-dusted orchard, as a rectangular grid:
`.` is open snow, `#` is a frozen tree. Part 1: a tree is a *grove tree*
if at least 2 of its 8 neighbors (diagonals count) are also trees — count
the grove trees. Part 2: an *orchard* is a group of trees connected
up/down/left/right (diagonals do **not** count) — find the size of the
largest one. Flood fill with BFS — the same queue-and-visited-set
technique as module 17, this time on a grid.

Both solvers must reject malformed input with a useful error (the doc
comments on `Solve` state the exact contract) — real programs don't
silently mis-parse.

## The milestones

Work top to bottom; each milestone has its own tests, so you always have a
red-to-green loop. Run everything from the repo root.

**Milestone 0 — read the contract.** Open `runner/runner.go` (provided,
complete). Two decisions worth noticing: answers are `string`s because AoC
answers aren't always numbers, and `Result` carries its `Err` as a field so
one broken day can't abort a batch run.

**Milestone 1 — the registry** (`runner/registry.go`):
`NewRegistry`, `Register`, `Get`, `Days`. Sentinel errors, comma-ok, and
sorted map keys — modules 06 and 11.

```sh
go test -run 'TestRegisterAndGet|TestDaysSorted' ./18-capstone-project/runner/
```

**Milestone 2 — input loading** (`runner/input.go`): `LoadInput`. Build the
path with `filepath.Join`, read with `os.ReadFile`, wrap the error with
`%w` (the test checks `errors.Is(err, fs.ErrNotExist)` still sees through
your wrapper), trim trailing newlines.

```sh
go test -run TestLoadInput ./18-capstone-project/runner/
```

**Milestone 3 — running one day** (`Run` in `runner/run.go`): compose
`Get` + `LoadInput` + `Solve` into a `Result`, timing only the `Solve`
call with `time.Now()`/`time.Since`. Read the doc comment carefully —
which error lands where is the whole exercise.

```sh
go test -run 'TestRunSingle|TestRunErrors' ./18-capstone-project/runner/
```

**Milestone 4 — running everything** (`RunAll`): the easy one. Ascending
day order, one `Result` per day.

```sh
go test -run TestRunAllSequential ./18-capstone-project/runner/
```

**Milestone 5 — the worker pool** (`RunAllParallel`): module 14 for real.
A `jobs` channel, `workers` goroutines, a results channel, a `WaitGroup`
to know when to close it, and a final sort by day. One test proves you
actually run solvers concurrently (all six solvers must be in flight at
once or it deadlocks and times out); another proves you sort.

```sh
go test ./18-capstone-project/runner/        # everything so far, plus:
go test -race ./18-capstone-project/runner/  # module 14 says: always -race
```

**Milestone 6 — the solvers** (`solvers/day1.go`, `solvers/day2.go`):
implement `Name` and `Solve` for both puzzles. The tests run the small
examples from the stories above first — debug against those — then the
real inputs in `inputs/`, whose expected answers are hard-coded in the
tests, just like a locked-in AoC answer.

```sh
go test ./18-capstone-project/solvers/
```

**Milestone 7 — the CLI** (`cmd/puzzlerunner/main.go`): the flags and
registry wiring are provided; you write the run-and-report logic (the
`TODO` in `main` spells out the three steps). No tests — this is the
milestone where you get to *run your program*:

```sh
go run ./18-capstone-project/cmd/puzzlerunner -all
go run ./18-capstone-project/cmd/puzzlerunner -day 2
go run ./18-capstone-project/cmd/puzzlerunner -day 9    # a useful error, not a crash
go build -o puzzlerunner ./18-capstone-project/cmd/puzzlerunner   # a real binary!
```

**Milestone 8 (open-ended) — make it yours.** Ideas, roughly in order of
ambition: add a `-json` output flag; print a `TOTAL` row summing the
times; benchmark a solver (module 16); fuzz `Day1.Solve` with random
input (module 16); add a `day3.go` solving any puzzle you like — an
[old AoC year](https://adventofcode.com/events) is perfect — and register
it in `main.go`. When Advent of Code starts, point `-inputs` at your real
puzzle inputs and solve the year inside your own harness.

## Check your work

```sh
go test ./18-capstone-project/runner/ ./18-capstone-project/solvers/   # red until you're done
go test ./18-capstone-project/solution/...                             # the reference, always green
```

Stuck? Each file in `solution/` mirrors the one you're editing. Compare
*after* your tests pass, too — seeing a second idiomatic shape for code
you already wrote is where a lot of the learning happens.
