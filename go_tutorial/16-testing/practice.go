// Package testkit is the exercise package for module 16: testing.
//
// This module inverts the usual flow. The three functions in this file
// are already implemented, and YOUR job is to write the tests for them
// in practice_test.go. Their doc comments below are the contracts to
// test against — and exactly one of the three implementations does not
// live up to its contract. Thorough tests will catch it; once yours
// do, fix the function.
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
	b := []byte(s)
	for i, j := 0, len(b)-1; i < j; i, j = i+1, j-1 {
		b[i], b[j] = b[j], b[i]
	}
	return string(b)
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
