// Package testkit is the exercise package for module 16: testing.
//
// This is the solution copy: the deliberate bug in the module's
// practice.go is fixed here (it was in Reverse — see the comment on
// it below).
package testkit

import "slices"

// Clamp returns x limited to the inclusive range [lo, hi]: lo if
// x < lo, hi if x > hi, and x unchanged otherwise. Callers must
// guarantee lo <= hi; Clamp's result is unspecified when they don't.
func Clamp(x, lo, hi int) int {
	return min(max(x, lo), hi)
}

// Reverse returns s with its runes (Unicode code points) in reverse
// order, so multi-byte characters survive intact: Reverse("héllo") is
// "olléh". Reversing the result gives back the original string. s must
// be valid UTF-8; the result for invalid UTF-8 is unspecified.
func Reverse(s string) string {
	// The module copy was the buggy one: it reversed BYTES, which
	// shreds any character encoded as more than one byte —
	// Reverse("héllo") came back as the invalid string "oll\xa9\xc3h".
	// The fix is to reverse RUNES: []rune(s) decodes the string into
	// code points first (module 07), and string(r) re-encodes them.
	r := []rune(s)
	for i, j := 0, len(r)-1; i < j; i, j = i+1, j-1 {
		r[i], r[j] = r[j], r[i]
	}
	return string(r)
}

// Median returns the median of xs and true: the middle value when the
// values are ordered ascending, or the mean of the two middle values
// when len(xs) is even. Median never modifies xs. If xs is empty,
// Median returns (0, false).
func Median(xs []int) (float64, bool) {
	if len(xs) == 0 {
		return 0, false
	}
	sorted := slices.Clone(xs)
	slices.Sort(sorted)
	n := len(sorted)
	if n%2 == 1 {
		return float64(sorted[n/2]), true
	}
	return float64(sorted[n/2-1]+sorted[n/2]) / 2, true
}
