package capstone

// SolveDay2Part1 counts the fir trees 'T' in the grid that have at
// least one lantern 'L' among their up-to-eight neighbors.
func SolveDay2Part1(input string) int {
	grid := inputLines(input)
	count := 0
	for r, row := range grid {
		for c := range len(row) {
			if row[c] == 'T' && hasLanternNeighbor(grid, r, c) {
				count++
			}
		}
	}
	return count
}

func hasLanternNeighbor(grid []string, r, c int) bool {
	for dr := -1; dr <= 1; dr++ {
		for dc := -1; dc <= 1; dc++ {
			if dr == 0 && dc == 0 {
				continue
			}
			nr, nc := r+dr, c+dc
			if nr < 0 || nr >= len(grid) || nc < 0 || nc >= len(grid[nr]) {
				continue
			}
			if grid[nr][nc] == 'L' {
				return true
			}
		}
	}
	return false
}

// SolveDay2Part2 counts the distinct open-snow '.' cells lit by at
// least one lantern beam. Every lantern shines a beam in each of the
// four cardinal directions; a beam lights consecutive '.' cells and
// stops at the first cell that is not '.' (a tree or another lantern)
// or at the edge of the grid.
func SolveDay2Part2(input string) int {
	grid := inputLines(input)
	type cell struct{ r, c int }
	// A map used as a set deduplicates cells lit by several beams.
	lit := make(map[cell]bool)
	dirs := [4]cell{{-1, 0}, {1, 0}, {0, -1}, {0, 1}}
	for r, row := range grid {
		for c := range len(row) {
			if row[c] != 'L' {
				continue
			}
			for _, d := range dirs {
				nr, nc := r+d.r, c+d.c
				for nr >= 0 && nr < len(grid) && nc >= 0 && nc < len(grid[nr]) && grid[nr][nc] == '.' {
					lit[cell{nr, nc}] = true
					nr, nc = nr+d.r, nc+d.c
				}
			}
		}
	}
	return len(lit)
}
