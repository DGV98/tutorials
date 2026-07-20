package capstone

import (
	"os"
	"path/filepath"
	"testing"
)

// readInput loads a real puzzle input file. It tries name as-is first
// (running from the module root) and then ../name (running from
// solution/), so this file passes verbatim from both directories.
func readInput(t *testing.T, name string) string {
	t.Helper()
	data, err := os.ReadFile(name)
	if err != nil {
		data, err = os.ReadFile(filepath.Join("..", name))
	}
	if err != nil {
		t.Fatalf("readInput(%q): %v", name, err)
	}
	return string(data)
}

// ---- Day 1: Candy Cane Accounting -----------------------------------------

const exampleDay1 = `tinsel 10 -2 3
jolly 5 5
tinsel 1
`

func TestSolveDay1Part1(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  int
	}{
		{"three-line example", exampleDay1, 22},
		{"single elf, one line", "solo 1 2 3\n", 6},
		{"totals can be negative", "grinchy -5 -6\njolly 4\n", -7},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := SolveDay1Part1(tt.input); got != tt.want {
				t.Errorf("SolveDay1Part1(%s) = %d, want %d", tt.name, got, tt.want)
			}
		})
	}
	t.Run("real input", func(t *testing.T) {
		input := readInput(t, "input1.txt")
		if got, want := SolveDay1Part1(input), 10295; got != want {
			t.Errorf("SolveDay1Part1(input1.txt) = %d, want %d", got, want)
		}
	})
}

func TestSolveDay1Part2(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{"three-line example", exampleDay1, "tinsel"}, // tinsel 12 beats jolly 10
		{"single elf, negative total", "solo -5\n", "solo"},
		{"every total negative", "frosty -9 -9\nblitzen -2\n", "blitzen"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := SolveDay1Part2(tt.input); got != tt.want {
				t.Errorf("SolveDay1Part2(%s) = %q, want %q", tt.name, got, tt.want)
			}
		})
	}
	t.Run("real input", func(t *testing.T) {
		input := readInput(t, "input1.txt")
		if got, want := SolveDay1Part2(input), "holly"; got != want {
			t.Errorf("SolveDay1Part2(input1.txt) = %q, want %q", got, want)
		}
	})
}

// ---- Day 2: The Lantern Grove ----------------------------------------------

const exampleDay2A = `.T.
.L.
T..
`

const exampleDay2B = `..T..
.TL.T
..T..
`

// Two lanterns whose beams overlap on the same three snow cells.
const exampleDay2C = `L...L
`

func TestSolveDay2Part1(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  int
	}{
		{"example A: two lit trees", exampleDay2A, 2},
		{"example B: far tree unlit", exampleDay2B, 3},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := SolveDay2Part1(tt.input); got != tt.want {
				t.Errorf("SolveDay2Part1(%s) = %d, want %d", tt.name, got, tt.want)
			}
		})
	}
	t.Run("real input", func(t *testing.T) {
		input := readInput(t, "input2.txt")
		if got, want := SolveDay2Part1(input), 253; got != want {
			t.Errorf("SolveDay2Part1(input2.txt) = %d, want %d", got, want)
		}
	})
}

func TestSolveDay2Part2(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  int
	}{
		{"example A: three beams escape", exampleDay2A, 3},
		{"example B: trees block almost everything", exampleDay2B, 1},
		{"example C: overlapping beams count once", exampleDay2C, 3},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := SolveDay2Part2(tt.input); got != tt.want {
				t.Errorf("SolveDay2Part2(%s) = %d, want %d", tt.name, got, tt.want)
			}
		})
	}
	t.Run("real input", func(t *testing.T) {
		input := readInput(t, "input2.txt")
		if got, want := SolveDay2Part2(input), 2114; got != want {
			t.Errorf("SolveDay2Part2(input2.txt) = %d, want %d", got, want)
		}
	})
}

// ---- Day 3: The Clockwork Carousel -----------------------------------------

const exampleDay3A = `abcde
swap 0 4
spin 2
`

const exampleDay3B = `abc
spin 1
`

const exampleDay3C = `abcde
reverse 1 3
`

func TestSolveDay3Part1(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{"swap then spin", exampleDay3A, "daebc"},
		{"lone spin", exampleDay3B, "cab"},
		{"reverse a middle segment", exampleDay3C, "adcbe"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := SolveDay3Part1(tt.input); got != tt.want {
				t.Errorf("SolveDay3Part1(%s) = %q, want %q", tt.name, got, tt.want)
			}
		})
	}
	t.Run("real input", func(t *testing.T) {
		input := readInput(t, "input3.txt")
		if got, want := SolveDay3Part1(input), "jcghdbfaei"; got != want {
			t.Errorf("SolveDay3Part1(input3.txt) = %q, want %q", got, want)
		}
	})
}

func TestSolveDay3Part2(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		// Cycle length 6; a billion passes land on pass 4's arrangement.
		{"swap then spin", exampleDay3A, "dacbe"},
		// Cycle length 3; 1,000,000,000 % 3 == 1, i.e. one pass.
		{"lone spin", exampleDay3B, "cab"},
		// Cycle length 2; a billion passes undo themselves.
		{"reverse a middle segment", exampleDay3C, "abcde"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := SolveDay3Part2(tt.input); got != tt.want {
				t.Errorf("SolveDay3Part2(%s) = %q, want %q", tt.name, got, tt.want)
			}
		})
	}
	t.Run("real input", func(t *testing.T) {
		input := readInput(t, "input3.txt")
		if got, want := SolveDay3Part2(input), "dbcijfgeah"; got != want {
			t.Errorf("SolveDay3Part2(input3.txt) = %q, want %q", got, want)
		}
	})
}

// ---- Day 4: The Reindeer Express -------------------------------------------

const exampleDay4A = `route R-1: NORTH-POLE => ICE-FALLS | distance 10 | toll 2
route R-2: ICE-FALLS => SANTAS-WORKSHOP | distance 20 | toll 9
route R-3: NORTH-POLE => SANTAS-WORKSHOP | distance 99 | toll 6
`

const exampleDay4B = `route R-1: SANTAS-WORKSHOP => NORTH-POLE | distance 5 | toll 1
route R-2: NORTH-POLE => ELF-ACADEMY | distance 7 | toll 1
route R-3: ELF-ACADEMY => COCOA-SPRINGS | distance 7 | toll 8
route R-4: COCOA-SPRINGS => SANTAS-WORKSHOP | distance 3 | toll 1
`

const exampleDay4C = `route R-1: NORTH-POLE => ICE-FALLS | distance 10 | toll 2
`

func TestSolveDay4Part1(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  int
	}{
		{"example A: one cheap route", exampleDay4A, 10},
		{"example B: three cheap routes", exampleDay4B, 15},
		{"example C: single route", exampleDay4C, 10},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := SolveDay4Part1(tt.input); got != tt.want {
				t.Errorf("SolveDay4Part1(%s) = %d, want %d", tt.name, got, tt.want)
			}
		})
	}
	t.Run("real input", func(t *testing.T) {
		input := readInput(t, "input4.txt")
		if got, want := SolveDay4Part1(input), 3928; got != want {
			t.Errorf("SolveDay4Part1(input4.txt) = %d, want %d", got, want)
		}
	})
}

func TestSolveDay4Part2(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  int
	}{
		{"example A: direct beats two hops", exampleDay4A, 1},
		{"example B: routes are one-way", exampleDay4B, 3},
		{"example C: workshop unreachable", exampleDay4C, -1},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := SolveDay4Part2(tt.input); got != tt.want {
				t.Errorf("SolveDay4Part2(%s) = %d, want %d", tt.name, got, tt.want)
			}
		})
	}
	t.Run("real input", func(t *testing.T) {
		input := readInput(t, "input4.txt")
		if got, want := SolveDay4Part2(input), 3; got != want {
			t.Errorf("SolveDay4Part2(input4.txt) = %d, want %d", got, want)
		}
	})
}
