// Package runner is the engine of the puzzlerunner CLI: it defines the
// Solver contract, keeps a registry of solvers by day, loads puzzle inputs
// from disk, and runs solvers — sequentially or in parallel — while timing
// them.
//
// This file defines the shared contract and is complete; you implement the
// rest of the package (registry.go, input.go, run.go) milestone by milestone.
package runner

import "time"

// Solver is implemented by every puzzle solution. Any type with these two
// methods can be registered and run — the runner never needs to know which
// concrete puzzle it is executing.
type Solver interface {
	// Name returns a short human-readable puzzle title, e.g. "Sled Ledger".
	Name() string

	// Solve computes both answers for the puzzle from the raw input text.
	// Answers are returned as strings because Advent-of-Code answers are
	// not always numbers. A non-nil error means the input could not be
	// solved (e.g. it failed to parse) and both answers are meaningless.
	Solve(input string) (part1, part2 string, err error)
}

// Result records the outcome of running one solver on one input.
type Result struct {
	Day     int           // which day was run
	Name    string        // the solver's Name(), if the day was known
	Part1   string        // first answer (empty if Err != nil)
	Part2   string        // second answer (empty if Err != nil)
	Elapsed time.Duration // how long Solve took (zero if it never ran)
	Err     error         // lookup, input-loading, or solving failure
}
