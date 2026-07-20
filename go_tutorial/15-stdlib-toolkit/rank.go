package toolkit

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
	// TODO: implement
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
	// TODO: implement
	return nil
}
