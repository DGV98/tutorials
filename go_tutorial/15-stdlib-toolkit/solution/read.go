// Package toolkit contains the exercises for module 15: the standard
// library toolkit — reading input with bufio.Scanner from any io.Reader,
// os.ReadFile, time.Parse and Duration, regexp, and sorting with the
// slices and maps packages.
package toolkit

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
)

// ReadLines reads r to the end and returns its lines, in order, without
// their trailing line endings. Both "\n" and "\r\n" endings are handled
// (bufio.Scanner does this for you). Blank lines are kept as empty
// strings. A final line is returned whether or not the input ends in a
// newline. If r is empty, ReadLines returns nil.
//
// ReadLines deliberately ignores read errors (see scanner.Err in the
// README) — fine for puzzle code, where r is a just-opened file or an
// in-memory string.
func ReadLines(r io.Reader) []string {
	var lines []string
	sc := bufio.NewScanner(r)
	for sc.Scan() {
		lines = append(lines, sc.Text())
	}
	return lines
}

// SumNumbersInReader reads one integer per line from r and returns
// their sum. Lines are trimmed of surrounding whitespace first, and
// blank (whitespace-only) lines are skipped. If any remaining line does
// not parse as an integer, SumNumbersInReader returns (0, err) where
// err mentions the offending line quoted (use %q) and wraps the
// strconv error with %w. An empty reader sums to 0.
func SumNumbersInReader(r io.Reader) (int, error) {
	sum := 0
	sc := bufio.NewScanner(r)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		n, err := strconv.Atoi(line)
		if err != nil {
			return 0, fmt.Errorf("sum numbers: bad line %q: %w", line, err)
		}
		sum += n
	}
	return sum, nil
}

// ReadFileLines reads the whole file at path and returns its lines,
// without trailing line endings, in order. A trailing newline at the
// end of the file does not produce a final empty line.
//
// This is the module's one deliberate exception to the "take an
// io.Reader, not a filename" rule: main functions need a doorway from
// the filesystem into reader-land, and this is it. If the file cannot
// be read, ReadFileLines returns (nil, err) where err wraps the
// underlying error with the path as context.
//
// Hint: open the file with os.Open, defer f.Close(), and hand the
// *os.File to ReadLines — you already wrote the hard part.
func ReadFileLines(path string) ([]string, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("read lines from %s: %w", path, err)
	}
	defer f.Close()
	return ReadLines(f), nil
}
