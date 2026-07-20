// Package solvers holds the puzzle implementations that plug into the
// runner. Each day is a small type satisfying runner.Solver — add a new
// day by adding a type here and registering it in cmd/puzzlerunner.
package solvers

import (
	"gotutorial/18-capstone-project/runner"
)

// Day1 solves "Day 1: Sled Ledger" — see the module README for the story.
//
// The input is one comma-separated list of positive integers per line,
// e.g. "12,7,33,2". Part 1 is the sum over all lines of each line's
// largest number. Part 2 is the sum over all lines of (largest - smallest).
type Day1 struct{}

// The compiler proves Day1 satisfies the Solver contract (module 10).
var _ runner.Solver = Day1{}

// Name returns the puzzle title shown in the CLI's output table.
func (Day1) Name() string {
	// TODO: implement
	return ""
}

// Solve parses the ledger and returns both answers as decimal strings.
// Blank lines (and leading/trailing whitespace) are ignored. If any field
// is not a valid integer, return an error that names the offending
// 1-based line number and wraps the strconv error (module 11).
func (Day1) Solve(input string) (part1, part2 string, err error) {
	// TODO: implement
	return "", "", nil
}
