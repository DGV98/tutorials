// Completed version of the module's practice_test.go: table-driven
// tests for the three shipped functions, a behavior test, a benchmark,
// and a fuzz target. Compare it with what you wrote — differences in
// taste are fine; missing edge cases are not.
package testkit

import (
	"slices"
	"strings"
	"testing"
	"unicode/utf8"
)

func TestClamp(t *testing.T) {
	tests := []struct {
		name      string
		x, lo, hi int
		want      int
	}{
		{"below range", -5, 0, 10, 0},
		{"above range", 99, 0, 10, 10},
		{"inside range", 7, 0, 10, 7},
		{"at low boundary", 0, 0, 10, 0},
		{"at high boundary", 10, 0, 10, 10},
		{"all-negative range", -7, -10, -1, -7},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Clamp(tt.x, tt.lo, tt.hi); got != tt.want {
				t.Errorf("Clamp(%d, %d, %d) = %d, want %d",
					tt.x, tt.lo, tt.hi, got, tt.want)
			}
		})
	}
}

func TestReverse(t *testing.T) {
	tests := []struct {
		name string
		s    string
		want string
	}{
		{"empty", "", ""},
		{"single rune", "x", "x"},
		{"ascii", "hello", "olleh"},
		{"palindrome", "racecar", "racecar"},
		// The next two cases catch the byte-reversal bug the module
		// copy shipped with: reversing bytes instead of runes shreds
		// multi-byte UTF-8 characters.
		{"accented", "héllo", "olléh"},
		{"cjk", "日本語", "語本日"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Reverse(tt.s); got != tt.want {
				t.Errorf("Reverse(%q) = %q, want %q", tt.s, got, tt.want)
			}
		})
	}
}

func TestMedian(t *testing.T) {
	tests := []struct {
		name   string
		xs     []int
		want   float64
		wantOK bool
	}{
		{"empty", nil, 0, false},
		{"single", []int{7}, 7, true},
		{"odd length", []int{1, 2, 3, 4, 5}, 3, true},
		{"even length averages middles", []int{1, 2, 3, 4}, 2.5, true},
		{"unsorted input", []int{9, 1, 5}, 5, true},
		{"negatives", []int{-3, -1, -2}, -2, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, ok := Median(tt.xs)
			if got != tt.want || ok != tt.wantOK {
				t.Errorf("Median(%v) = (%v, %t), want (%v, %t)",
					tt.xs, got, ok, tt.want, tt.wantOK)
			}
		})
	}
}

// TestMedianDoesNotMutate pins down a behavior promised by the doc
// comment that the value-returning tests above can't see: the caller's
// slice must come back untouched.
func TestMedianDoesNotMutate(t *testing.T) {
	xs := []int{3, 1, 2}
	orig := slices.Clone(xs)
	Median(xs)
	if !slices.Equal(xs, orig) {
		t.Errorf("Median(%v) mutated its input to %v", orig, xs)
	}
}

func BenchmarkReverse(b *testing.B) {
	// Setup before the loop is not timed, and b.Loop keeps the call's
	// arguments and result alive, so the compiler can't optimize the
	// unused return value away.
	s := strings.Repeat("héllo wörld ", 50) // ~700 bytes, mixed rune widths
	for b.Loop() {
		Reverse(s)
	}
}

func FuzzReverse(f *testing.F) {
	for _, seed := range []string{"", "x", "racecar", "héllo", "日本語"} {
		f.Add(seed)
	}
	f.Fuzz(func(t *testing.T, s string) {
		if !utf8.ValidString(s) {
			t.Skip("Reverse's contract only covers valid UTF-8")
		}
		rev := Reverse(s)
		if !utf8.ValidString(rev) {
			t.Errorf("Reverse(%q) = %q, which is not valid UTF-8", s, rev)
		}
		if got := Reverse(rev); got != s {
			t.Errorf("Reverse(Reverse(%q)) = %q, want the original string", s, got)
		}
	})
}
