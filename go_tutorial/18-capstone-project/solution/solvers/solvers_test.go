package solvers

import (
	"os"
	"path/filepath"
	"testing"
)

// readInput finds the real puzzle inputs whether the tests run from this
// directory or from solution/solvers/.
func readInput(t *testing.T, name string) string {
	t.Helper()
	for _, path := range []string{
		filepath.Join("..", "inputs", name),
		filepath.Join("..", "..", "inputs", name),
	} {
		data, err := os.ReadFile(path)
		if err == nil {
			return string(data)
		}
	}
	t.Fatalf("could not find %s in ../inputs or ../../inputs", name)
	return ""
}

func TestDay1Name(t *testing.T) {
	if (Day1{}).Name() == "" {
		t.Error(`Day1.Name() = "", want a puzzle title`)
	}
}

func TestDay1Example(t *testing.T) {
	example := "1,9,5\n4,4\n10,3,7\n"
	part1, part2, err := (Day1{}).Solve(example)
	if err != nil {
		t.Fatalf("Day1.Solve(example) error = %v, want nil", err)
	}
	if want := "23"; part1 != want {
		t.Errorf("Day1.Solve(example) part1 = %q, want %q (9 + 4 + 10)", part1, want)
	}
	if want := "15"; part2 != want {
		t.Errorf("Day1.Solve(example) part2 = %q, want %q ((9-1) + (4-4) + (10-3))", part2, want)
	}
}

func TestDay1SingleNumberLines(t *testing.T) {
	part1, part2, err := (Day1{}).Solve("5\n11\n")
	if err != nil {
		t.Fatalf("Day1.Solve error = %v, want nil", err)
	}
	if part1 != "16" || part2 != "0" {
		t.Errorf("Day1.Solve(\"5\\n11\") = %q, %q, want %q, %q", part1, part2, "16", "0")
	}
}

func TestDay1Malformed(t *testing.T) {
	_, _, err := (Day1{}).Solve("1,2\n3,oops,5\n")
	if err == nil {
		t.Fatal("Day1.Solve with a non-integer field: err = nil, want an error")
	}
}

func TestDay1RealInput(t *testing.T) {
	part1, part2, err := (Day1{}).Solve(readInput(t, "day1.txt"))
	if err != nil {
		t.Fatalf("Day1.Solve(real input) error = %v, want nil", err)
	}
	if want := "127919"; part1 != want {
		t.Errorf("Day1 part1 = %q, want %q", part1, want)
	}
	if want := "107668"; part2 != want {
		t.Errorf("Day1 part2 = %q, want %q", part2, want)
	}
}

func TestDay2Name(t *testing.T) {
	if (Day2{}).Name() == "" {
		t.Error(`Day2.Name() = "", want a puzzle title`)
	}
}

func TestDay2Example(t *testing.T) {
	example := "##..\n#.#.\n....\n.###\n"
	part1, part2, err := (Day2{}).Solve(example)
	if err != nil {
		t.Fatalf("Day2.Solve(example) error = %v, want nil", err)
	}
	if want := "4"; part1 != want {
		t.Errorf("Day2.Solve(example) part1 = %q, want %q (grove trees)", part1, want)
	}
	if want := "3"; part2 != want {
		t.Errorf("Day2.Solve(example) part2 = %q, want %q (largest 4-connected orchard)", part2, want)
	}
}

func TestDay2Malformed(t *testing.T) {
	t.Run("ragged rows", func(t *testing.T) {
		if _, _, err := (Day2{}).Solve("##.\n#.\n"); err == nil {
			t.Error("Day2.Solve with ragged rows: err = nil, want an error")
		}
	})
	t.Run("invalid character", func(t *testing.T) {
		if _, _, err := (Day2{}).Solve("#.\n.X\n"); err == nil {
			t.Error("Day2.Solve with an invalid character: err = nil, want an error")
		}
	})
}

func TestDay2RealInput(t *testing.T) {
	part1, part2, err := (Day2{}).Solve(readInput(t, "day2.txt"))
	if err != nil {
		t.Fatalf("Day2.Solve(real input) error = %v, want nil", err)
	}
	if want := "691"; part1 != want {
		t.Errorf("Day2 part1 = %q, want %q", part1, want)
	}
	if want := "22"; part2 != want {
		t.Errorf("Day2 part2 = %q, want %q", part2, want)
	}
}
