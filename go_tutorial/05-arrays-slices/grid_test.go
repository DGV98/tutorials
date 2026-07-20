package slicing

import (
	"reflect"
	"strings"
	"testing"
)

// parseGrid turns lines of text into a [][]rune grid, one row per line.
func parseGrid(lines ...string) [][]rune {
	grid := make([][]rune, len(lines))
	for i, line := range lines {
		grid[i] = []rune(line)
	}
	return grid
}

// gridString renders a grid as its rows joined with "|", for readable
// failure messages: [][]rune{{'.','#'},{'#','.'}} becomes ".#|#.".
func gridString(grid [][]rune) string {
	rows := make([]string, len(grid))
	for i, row := range grid {
		rows[i] = string(row)
	}
	return strings.Join(rows, "|")
}

func TestNewGrid(t *testing.T) {
	tests := []struct {
		name       string
		rows, cols int
		fill       rune
		want       [][]rune
	}{
		{"2x3 of dots", 2, 3, '.', parseGrid("...", "...")},
		{"1x1 hash", 1, 1, '#', parseGrid("#")},
		{"3x2 of stars", 3, 2, '*', parseGrid("**", "**", "**")},
		{"zero rows", 0, 5, '.', nil},
		{"negative cols", 3, -1, '.', nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := NewGrid(tt.rows, tt.cols, tt.fill)
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("NewGrid(%d, %d, %q) = %q, want %q",
					tt.rows, tt.cols, tt.fill, gridString(got), gridString(tt.want))
			}
		})
	}

	t.Run("rows are independent", func(t *testing.T) {
		g := NewGrid(2, 2, '.')
		if len(g) != 2 {
			t.Fatalf("NewGrid(2, 2, '.') = %q, want a 2x2 grid", gridString(g))
		}
		g[0][0] = '#'
		if g[1][0] == '#' {
			t.Errorf("NewGrid(2, 2, '.'): writing g[0][0] also changed g[1][0] — rows share memory")
		}
	})
}

func TestCountNeighbors(t *testing.T) {
	tests := []struct {
		name  string
		lines []string
		r, c  int
		want  int
	}{
		{"all dots", []string{"...", "...", "..."}, 1, 1, 0},
		{"fully surrounded", []string{"###", "#.#", "###"}, 1, 1, 8},
		{"cell itself not counted", []string{"###", "###", "###"}, 1, 1, 8},
		{"corner", []string{".#", "#."}, 0, 0, 2},
		{"top edge", []string{"#.#", ".#.", "..."}, 0, 1, 3},
		{"single cell", []string{"#"}, 0, 0, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := CountNeighbors(parseGrid(tt.lines...), tt.r, tt.c)
			if got != tt.want {
				t.Errorf("CountNeighbors(%q, %d, %d) = %d, want %d",
					tt.lines, tt.r, tt.c, got, tt.want)
			}
		})
	}
}
