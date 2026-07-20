package solvers

import (
	"fmt"
	"strconv"
	"strings"

	"gotutorial/18-capstone-project/solution/runner"
)

// Day2 solves "Day 2: Frozen Orchard".
type Day2 struct{}

var _ runner.Solver = Day2{}

// Name returns the puzzle title shown in the CLI's output table.
func (Day2) Name() string { return "Frozen Orchard" }

// Solve parses the grid and returns both answers as decimal strings.
func (Day2) Solve(input string) (part1, part2 string, err error) {
	grid, err := parseGrid(input)
	if err != nil {
		return "", "", err
	}
	return strconv.Itoa(countGroveTrees(grid)), strconv.Itoa(largestOrchard(grid)), nil
}

func parseGrid(input string) ([][]byte, error) {
	var grid [][]byte
	for i, line := range strings.Split(strings.TrimSpace(input), "\n") {
		for _, c := range line {
			if c != '.' && c != '#' {
				return nil, fmt.Errorf("line %d: invalid character %q", i+1, c)
			}
		}
		if len(grid) > 0 && len(line) != len(grid[0]) {
			return nil, fmt.Errorf("line %d: rows must all be the same length", i+1)
		}
		grid = append(grid, []byte(line))
	}
	return grid, nil
}

// countGroveTrees counts '#' cells with at least 2 of their 8 neighbors
// also '#'.
func countGroveTrees(grid [][]byte) int {
	count := 0
	for r, row := range grid {
		for c, cell := range row {
			if cell != '#' {
				continue
			}
			neighbors := 0
			for dr := -1; dr <= 1; dr++ {
				for dc := -1; dc <= 1; dc++ {
					if dr == 0 && dc == 0 {
						continue
					}
					rr, cc := r+dr, c+dc
					if rr >= 0 && rr < len(grid) && cc >= 0 && cc < len(row) && grid[rr][cc] == '#' {
						neighbors++
					}
				}
			}
			if neighbors >= 2 {
				count++
			}
		}
	}
	return count
}

// largestOrchard returns the size of the biggest 4-connected group of '#'
// cells, found by flood-filling each unvisited tree with BFS.
func largestOrchard(grid [][]byte) int {
	visited := make([][]bool, len(grid))
	for r := range visited {
		visited[r] = make([]bool, len(grid[r]))
	}

	deltas := [][2]int{{-1, 0}, {1, 0}, {0, -1}, {0, 1}}
	best := 0
	for r, row := range grid {
		for c, cell := range row {
			if cell != '#' || visited[r][c] {
				continue
			}
			size := 0
			queue := [][2]int{{r, c}}
			visited[r][c] = true
			for len(queue) > 0 {
				cur := queue[0]
				queue = queue[1:]
				size++
				for _, d := range deltas {
					rr, cc := cur[0]+d[0], cur[1]+d[1]
					if rr >= 0 && rr < len(grid) && cc >= 0 && cc < len(grid[rr]) &&
						grid[rr][cc] == '#' && !visited[rr][cc] {
						visited[rr][cc] = true
						queue = append(queue, [2]int{rr, cc})
					}
				}
			}
			best = max(best, size)
		}
	}
	return best
}
