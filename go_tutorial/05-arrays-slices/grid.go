package slicing

// NewGrid returns a rows x cols grid of runes with every cell set to fill.
// Each row must be its own independent slice: writing to grid[0][0] must
// not affect any other row. NewGrid returns nil if rows <= 0 or cols <= 0.
func NewGrid(rows, cols int, fill rune) [][]rune {
	// TODO: implement
	return nil
}

// CountNeighbors returns how many of the up-to-8 cells surrounding
// grid[r][c] (horizontally, vertically, and diagonally adjacent) contain
// a rune other than '.'. Cells outside the grid are simply not counted,
// so corner and edge positions have fewer neighbors to examine. The cell
// at (r, c) itself is never counted.
func CountNeighbors(grid [][]rune, r, c int) int {
	// TODO: implement
	return 0
}
