// Package capstone holds the solutions for module 17: four original
// Advent-of-Code-style puzzles that exercise everything from the
// course so far.
package capstone

import (
	"strconv"
	"strings"
)

// inputLines splits raw puzzle input into lines, dropping the trailing
// newline that input files conventionally end with.
func inputLines(input string) []string {
	return strings.Split(strings.TrimSpace(input), "\n")
}

// mustInt converts s to an int and panics on failure. Puzzle input is
// trusted: a parse error means the parser is wrong, not the data, so a
// panic that points straight at the bug beats threading an error value
// through every solver.
func mustInt(s string) int {
	n, err := strconv.Atoi(s)
	if err != nil {
		panic(err)
	}
	return n
}

// SolveDay1Part1 returns the grand total of every amount in the ledger:
// the sum of every signed integer on every line. Each line is an elf
// name followed by one or more space-separated signed integers.
func SolveDay1Part1(input string) int {
	total := 0
	for _, line := range inputLines(input) {
		for _, f := range strings.Fields(line)[1:] {
			total += mustInt(f)
		}
	}
	return total
}

// SolveDay1Part2 returns the name of the elf whose amounts, summed
// across every line bearing their name, are strictly the largest.
func SolveDay1Part2(input string) string {
	totals := make(map[string]int)
	for _, line := range inputLines(input) {
		fields := strings.Fields(line)
		for _, f := range fields[1:] {
			totals[fields[0]] += mustInt(f)
		}
	}
	// Track the best explicitly instead of starting bestTotal at 0:
	// every elf's total could be negative.
	best, bestTotal := "", 0
	for name, total := range totals {
		if best == "" || total > bestTotal {
			best, bestTotal = name, total
		}
	}
	return best
}
