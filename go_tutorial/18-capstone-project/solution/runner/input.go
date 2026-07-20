package runner

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// LoadInput reads the puzzle input for the given day from dir.
// Inputs live in files named day1.txt, day2.txt, ... inside dir.
//
// The returned string has any trailing newline characters stripped.
// The %w wrapping keeps the underlying *fs.PathError reachable, so
// errors.Is(err, fs.ErrNotExist) still works for callers.
func LoadInput(dir string, day int) (string, error) {
	path := filepath.Join(dir, fmt.Sprintf("day%d.txt", day))
	data, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("load input for day %d: %w", day, err)
	}
	return strings.TrimRight(string(data), "\n"), nil
}
