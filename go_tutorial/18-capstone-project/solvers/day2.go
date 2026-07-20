package solvers

import (
	"gotutorial/18-capstone-project/runner"
)

// Day2 solves "Day 2: Frozen Orchard" — see the module README for the story.
//
// The input is a rectangular grid of '.' (snow) and '#' (frozen trees).
// Part 1 counts the trees with at least 2 trees among their 8 neighbors
// (a "grove tree"). Part 2 is the size of the largest orchard: a group of
// trees connected up/down/left/right (4-connected, not diagonal).
type Day2 struct{}

var _ runner.Solver = Day2{}

// Name returns the puzzle title shown in the CLI's output table.
func (Day2) Name() string {
	// TODO: implement
	return ""
}

// Solve parses the grid and returns both answers as decimal strings.
// Leading/trailing blank lines are ignored. Return an error if the rows
// are not all the same length, or if the grid contains any character
// other than '.' and '#' (name the 1-based line number in the message).
//
// Hint: part 2 is a flood fill — BFS with a queue and a visited set,
// the module 17 technique applied to a grid.
func (Day2) Solve(input string) (part1, part2 string, err error) {
	// TODO: implement
	return "", "", nil
}
