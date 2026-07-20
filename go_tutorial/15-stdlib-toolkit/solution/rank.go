package toolkit

import (
	"cmp"
	"maps"
	"slices"
)

// A Person has a name and an age. Used by SortPeople.
type Person struct {
	Name string
	Age  int
}

// SortPeople sorts people in place: by Age ascending, and people of
// equal age by Name ascending. The two-level comparison makes the
// result fully deterministic.
//
// Hint: slices.SortFunc with a comparator built from cmp.Compare; see
// cmp.Or in the README for chaining the two keys.
func SortPeople(people []Person) {
	slices.SortFunc(people, func(a, b Person) int {
		// cmp.Or returns the first non-zero value: compare by age,
		// and only if ages are equal fall through to the name.
		return cmp.Or(
			cmp.Compare(a.Age, b.Age),
			cmp.Compare(a.Name, b.Name),
		)
	})
}

// TopN returns the keys of the n largest counts, ordered from highest
// count to lowest. Keys with equal counts are ordered alphabetically
// (ascending) so the result is deterministic even though map iteration
// order is not. If n is larger than the number of keys, all keys are
// returned. If n <= 0 or counts is empty, TopN returns nil.
//
// Hint: collect the keys (maps.Keys + slices.Collect, or a plain
// loop), sort them with slices.SortFunc, then slice off the first n.
func TopN(counts map[string]int, n int) []string {
	if n <= 0 || len(counts) == 0 {
		return nil
	}
	keys := slices.Collect(maps.Keys(counts))
	slices.SortFunc(keys, func(a, b string) int {
		// Note the swapped operands on the count comparison: b before
		// a sorts descending. The alphabetical tie-break stays a, b.
		return cmp.Or(
			cmp.Compare(counts[b], counts[a]),
			cmp.Compare(a, b),
		)
	})
	return keys[:min(n, len(keys))]
}
