// Shipped tests for the two ordinary exercises (histogram.go). These
// are also your worked example of the table-driven style before you
// write practice_test.go yourself.
package testkit

import (
	"maps"
	"testing"
)

func TestRuneHistogram(t *testing.T) {
	tests := []struct {
		name string
		s    string
		want map[rune]int
	}{
		{"empty", "", map[rune]int{}},
		{"single rune", "g", map[rune]int{'g': 1}},
		{"repeats", "banana", map[rune]int{'b': 1, 'a': 3, 'n': 2}},
		{"case sensitive", "Aa", map[rune]int{'A': 1, 'a': 1}},
		{"multi-byte runes count once", "héé", map[rune]int{'h': 1, 'é': 2}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := RuneHistogram(tt.s); !maps.Equal(got, tt.want) {
				t.Errorf("RuneHistogram(%q) = %v, want %v", tt.s, got, tt.want)
			}
		})
	}
}

// checkMostCommon is a test helper: it calls MostCommon and reports
// any mismatch. t.Helper() makes a failure point at the line in the
// test that called checkMostCommon rather than at the Errorf below —
// see the README's "Test helpers" section.
func checkMostCommon(t *testing.T, s string, wantR rune, wantN int) {
	t.Helper()
	r, n := MostCommon(s)
	if r != wantR || n != wantN {
		t.Errorf("MostCommon(%q) = (%q, %d), want (%q, %d)", s, r, n, wantR, wantN)
	}
}

func TestMostCommon(t *testing.T) {
	tests := []struct {
		name  string
		s     string
		wantR rune
		wantN int
	}{
		{"empty", "", 0, 0},
		{"single rune", "x", 'x', 1},
		{"clear winner", "banana", 'a', 3},
		{"tie smallest rune wins", "abab", 'a', 2},
		{"all distinct", "cba", 'a', 1},
		{"unicode", "日本日", '日', 2},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			checkMostCommon(t, tt.s, tt.wantR, tt.wantN)
		})
	}
}
