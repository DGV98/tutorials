// Package mapping is the exercise package for module 06: maps.
package mapping

// WordCount returns a map from each word in text to the number of times
// it appears. Words are the whitespace-separated substrings of text as
// split by strings.Fields (any run of spaces, tabs, or newlines is a
// separator), compared case-sensitively. If text contains no words,
// WordCount returns an empty (or nil) map.
func WordCount(text string) map[string]int {
	// TODO: implement
	return nil
}

// FirstRepeated returns the first value of xs to appear a second time
// when scanning left to right, and true. If no value repeats (or xs is
// empty), it returns (0, false). For example,
// FirstRepeated([]int{1, 2, 3, 2, 1}) = (2, true): 2 completes a repeat
// before 1 does.
func FirstRepeated(xs []int) (int, bool) {
	// TODO: implement
	return 0, false
}

// Intersect treats a and b as sets and returns the values present in
// both, each value at most once, sorted ascending. Duplicates within a
// or b have no effect on the result. If the sets are disjoint (or
// either slice is empty), Intersect returns an empty or nil slice.
func Intersect(a, b []int) []int {
	// TODO: implement
	return nil
}

// GroupAnagrams groups words that are anagrams of one another (the same
// characters with the same multiplicities; comparison is
// case-sensitive). Within a group, words keep their input order; groups
// appear in order of the first input word belonging to them. A word
// that occurs twice in the input occurs twice in its group.
// GroupAnagrams returns nil if words is empty.
func GroupAnagrams(words []string) [][]string {
	// TODO: implement
	return nil
}

// Mode returns the value that occurs most often in xs and true. If
// several values tie for the highest count, the smallest of them is
// returned (map iteration order is random, so the tie-break must not
// depend on it). If xs is empty, Mode returns (0, false).
func Mode(xs []int) (int, bool) {
	// TODO: implement
	return 0, false
}

// Invert returns the inverse of m: for every pair k -> v in m, the
// result maps v -> k. If several keys share the same value, the
// lexicographically smallest key wins. Inverting an empty or nil map
// yields an empty (or nil) map.
func Invert(m map[string]int) map[int]string {
	// TODO: implement
	return nil
}

// TwoSum returns indices i < j with xs[i]+xs[j] == target, and true, or
// (0, 0, false) if no such pair exists. An element cannot pair with
// itself, but two equal values at different indices can. If several
// pairs work, the one with the smallest j wins; if several i work for
// that j, the smallest i wins. Use a map from value to index so the
// whole search is a single O(n) pass — that is the point of the
// exercise.
func TwoSum(xs []int, target int) (int, int, bool) {
	// TODO: implement
	return 0, 0, false
}
