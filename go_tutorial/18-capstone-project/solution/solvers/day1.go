// Package solvers holds the puzzle implementations that plug into the
// runner. Each day is a small type satisfying runner.Solver.
package solvers

import (
	"fmt"
	"strconv"
	"strings"

	"gotutorial/18-capstone-project/solution/runner"
)

// Day1 solves "Day 1: Sled Ledger".
type Day1 struct{}

var _ runner.Solver = Day1{}

// Name returns the puzzle title shown in the CLI's output table.
func (Day1) Name() string { return "Sled Ledger" }

// Solve parses the ledger and returns both answers as decimal strings.
func (Day1) Solve(input string) (part1, part2 string, err error) {
	var total, spread int
	for i, line := range strings.Split(strings.TrimSpace(input), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		var lo, hi int
		for j, field := range strings.Split(line, ",") {
			n, err := strconv.Atoi(strings.TrimSpace(field))
			if err != nil {
				return "", "", fmt.Errorf("line %d: %w", i+1, err)
			}
			if j == 0 {
				lo, hi = n, n
			} else {
				lo, hi = min(lo, n), max(hi, n)
			}
		}
		total += hi
		spread += hi - lo
	}
	return strconv.Itoa(total), strconv.Itoa(spread), nil
}
