package slicing

// NewGrid returns a rows x cols grid of runes with every cell set to fill.
// Each row must be its own independent slice: writing to grid[0][0] must
// not affect any other row. NewGrid returns nil if rows <= 0 or cols <= 0.
func NewGrid(rows, cols int, fill rune) [][]rune {
	if rows <= 0 || cols <= 0 {
		return nil
	}
	grid := make([][]rune, rows)
	for r := range grid {
		grid[r] = make([]rune, cols) // each row gets its own backing array
		for c := range grid[r] {
			grid[r][c] = fill
		}
	}
	return grid
}

// CountNeighbors returns how many of the up-to-8 cells surrounding
// grid[r][c] (horizontally, vertically, and diagonally adjacent) contain
// a rune other than '.'. Cells outside the grid are simply not counted,
// so corner and edge positions have fewer neighbors to examine. The cell
// at (r, c) itself is never counted.
func CountNeighbors(grid [][]rune, r, c int) int {
	count := 0
	for dr := -1; dr <= 1; dr++ {
		for dc := -1; dc <= 1; dc++ {
			if dr == 0 && dc == 0 {
				continue // the cell itself, not a neighbor
			}
			nr, nc := r+dr, c+dc
			// Bounds-check the row first, then the column against that
			// row's own length — this also survives ragged grids.
			if nr < 0 || nr >= len(grid) || nc < 0 || nc >= len(grid[nr]) {
				continue
			}
			if grid[nr][nc] != '.' {
				count++
			}
		}
	}
	return count
}
