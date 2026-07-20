// Package parsing is the Advent-of-Code input-parsing toolkit: turning raw
// puzzle text into ints, maps, and structured records using the strings and
// strconv packages.
package parsing

import (
	"fmt"
	"strconv"
	"strings"
)

// ParseInts parses a comma-separated list of integers, e.g. "1,2,3" or
// "1, -2 , 3" (whitespace around each number is ignored).
//
// It returns the numbers in order. If the input is empty or contains only
// whitespace, it returns (nil, nil). If any field is empty or is not a valid
// integer, it returns (nil, error) — never a partial result.
func ParseInts(s string) ([]int, error) {
	// Handle the empty case up front: Split("", ",") would return [""],
	// one empty field, not an empty slice.
	if strings.TrimSpace(s) == "" {
		return nil, nil
	}
	fields := strings.Split(s, ",")
	nums := make([]int, 0, len(fields))
	for _, f := range fields {
		n, err := strconv.Atoi(strings.TrimSpace(f))
		if err != nil {
			return nil, fmt.Errorf("parsing ints: bad field %q: %v", f, err)
		}
		nums = append(nums, n)
	}
	return nums, nil
}

// ParseKeyValue parses newline-separated "key=value" lines into a map.
//
// Blank (or whitespace-only) lines are skipped. Keys and values are trimmed
// of surrounding whitespace. Only the FIRST '=' separates key from value, so
// the value may itself contain '=' ("a=b=c" means key "a", value "b=c").
// If a later line repeats a key, its value overwrites the earlier one.
//
// If any non-blank line contains no '=', or its key is empty after trimming,
// ParseKeyValue returns (nil, error). Valid input always yields a non-nil
// (possibly empty) map.
func ParseKeyValue(input string) (map[string]string, error) {
	m := make(map[string]string)
	for _, line := range strings.Split(input, "\n") {
		if strings.TrimSpace(line) == "" {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			return nil, fmt.Errorf("parsing key/value: no '=' in line %q", line)
		}
		key = strings.TrimSpace(key)
		if key == "" {
			return nil, fmt.Errorf("parsing key/value: empty key in line %q", line)
		}
		m[key] = strings.TrimSpace(value)
	}
	return m, nil
}

// Move is a single movement instruction: a direction and a distance.
//
// (Structs get their full introduction in module 09 — for now, treat Move as
// a small bundle of two named values.)
type Move struct {
	Dir  rune // one of 'U', 'D', 'L', 'R'
	Dist int  // always >= 1
}

// ParseMoves parses whitespace-separated move tokens such as "R5 L3 U2" into
// a slice of Moves. Any whitespace (spaces, tabs, newlines, runs of them)
// separates tokens.
//
// Each token must be a single uppercase direction letter — 'U', 'D', 'L', or
// 'R' — immediately followed by a positive integer distance ("R5" means
// {Dir: 'R', Dist: 5}). Input that is empty or all whitespace yields
// (nil, nil). Any malformed token ("X5", "R", "R5x", "R0", "R-2") makes
// ParseMoves return (nil, error) — never a partial result.
func ParseMoves(s string) ([]Move, error) {
	var moves []Move
	for _, tok := range strings.Fields(s) {
		// The direction is a single ASCII letter, so tok[0] (a byte)
		// is safe to inspect and convert to a rune.
		dir := rune(tok[0])
		if !strings.ContainsRune("UDLR", dir) {
			return nil, fmt.Errorf("parsing moves: bad direction in %q", tok)
		}
		dist, err := strconv.Atoi(tok[1:])
		if err != nil {
			return nil, fmt.Errorf("parsing moves: bad distance in %q: %v", tok, err)
		}
		if dist < 1 {
			return nil, fmt.Errorf("parsing moves: distance must be positive in %q", tok)
		}
		moves = append(moves, Move{Dir: dir, Dist: dist})
	}
	return moves, nil
}
