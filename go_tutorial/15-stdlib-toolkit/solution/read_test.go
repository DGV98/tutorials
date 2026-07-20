package toolkit

import (
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

func TestReadLines(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  []string
	}{
		{"three lines", "a\nb\nc\n", []string{"a", "b", "c"}},
		{"no trailing newline", "a\nb", []string{"a", "b"}},
		{"blank lines preserved", "a\n\nb\n", []string{"a", "", "b"}},
		{"windows line endings", "a\r\nb\r\n", []string{"a", "b"}},
		{"single line", "hello", []string{"hello"}},
		{"empty input", "", nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ReadLines(strings.NewReader(tt.input))
			if !slices.Equal(got, tt.want) {
				t.Errorf("ReadLines(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}

func TestSumNumbersInReader(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    int
		wantErr bool
	}{
		{"three numbers", "1\n2\n3\n", 6, false},
		{"negatives", "-5\n10\n", 5, false},
		{"whitespace and blank lines", "  1  \n\n2\n   \n", 3, false},
		{"single number no newline", "42", 42, false},
		{"empty input", "", 0, false},
		{"not a number", "1\nabc\n3\n", 0, true},
		{"float is not an int", "1.5\n", 0, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := SumNumbersInReader(strings.NewReader(tt.input))
			if tt.wantErr {
				if err == nil {
					t.Fatalf("SumNumbersInReader(%q) = %d, want error", tt.input, got)
				}
				return
			}
			if err != nil {
				t.Fatalf("SumNumbersInReader(%q) returned unexpected error: %v", tt.input, err)
			}
			if got != tt.want {
				t.Errorf("SumNumbersInReader(%q) = %d, want %d", tt.input, got, tt.want)
			}
		})
	}
}

// samplePath locates sample.txt so the same test file works from both
// the module directory and solution/ (one level down). go test always
// runs a package's tests with the package directory as the working
// directory, which is what makes this reliable.
func samplePath(t *testing.T) string {
	t.Helper()
	for _, p := range []string{"sample.txt", filepath.Join("..", "sample.txt")} {
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	t.Fatal("sample.txt not found in . or ..")
	return ""
}

func TestReadFileLines(t *testing.T) {
	path := samplePath(t)
	want := []string{
		"12 red apples",
		"-3 spoiled oranges",
		"40 green bananas",
		"7 golden pears",
	}
	got, err := ReadFileLines(path)
	if err != nil {
		t.Fatalf("ReadFileLines(%q) returned unexpected error: %v", path, err)
	}
	if !slices.Equal(got, want) {
		t.Errorf("ReadFileLines(%q) = %q, want %q", path, got, want)
	}
}

func TestReadFileLinesMissingFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "no-such-file.txt")
	got, err := ReadFileLines(path)
	if err == nil {
		t.Errorf("ReadFileLines(%q) = %q, want error for missing file", path, got)
	}
}
