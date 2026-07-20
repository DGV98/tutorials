// Package slicing is the exercise package for module 05: arrays, slices,
// and 2D grids.
package slicing

// Sum returns the sum of all elements of xs.
// The sum of an empty or nil slice is 0.
func Sum(xs []int) int {
	total := 0
	for _, x := range xs {
		total += x
	}
	return total
}

// Max returns the largest element of xs and true.
// If xs is empty or nil, it returns 0 and false.
func Max(xs []int) (int, bool) {
	if len(xs) == 0 {
		return 0, false
	}
	best := xs[0]
	for _, x := range xs[1:] {
		if x > best {
			best = x
		}
	}
	return best, true
}

// ReverseInPlace reverses the order of the elements of xs, modifying the
// slice it was given (it allocates nothing). Empty and single-element
// slices are left as they are.
func ReverseInPlace(xs []int) {
	// Two indices walk toward each other, swapping as they go.
	for i, j := 0, len(xs)-1; i < j; i, j = i+1, j-1 {
		xs[i], xs[j] = xs[j], xs[i]
	}
}

// Filter returns a new slice containing, in order, every element x of xs
// for which keep(x) is true. It never modifies xs. If no elements are
// kept (or xs is empty), Filter returns nil.
func Filter(xs []int, keep func(int) bool) []int {
	var kept []int // stays nil if nothing is appended — exactly the contract
	for _, x := range xs {
		if keep(x) {
			kept = append(kept, x)
		}
	}
	return kept
}

// MapInts returns a new slice of the same length as xs in which every
// element is f applied to the corresponding element of xs. It never
// modifies xs. For an empty or nil xs it returns a slice of length 0.
func MapInts(xs []int, f func(int) int) []int {
	// The output length is known up front, so allocate it all at once
	// instead of growing with append.
	out := make([]int, len(xs))
	for i, x := range xs {
		out[i] = f(x)
	}
	return out
}

// Chunk splits xs into consecutive chunks of length size and returns them
// in order; the final chunk is shorter when len(xs) is not a multiple of
// size. Chunk returns nil if xs is empty or size <= 0. The returned
// chunks may share memory with xs (subslices are fine).
func Chunk(xs []int, size int) [][]int {
	if len(xs) == 0 || size <= 0 {
		return nil
	}
	var chunks [][]int
	for start := 0; start < len(xs); start += size {
		end := min(start+size, len(xs))
		// Three-index slice: capping cap(chunk) at end means a later
		// append to a chunk reallocates instead of scribbling on xs.
		chunks = append(chunks, xs[start:end:end])
	}
	return chunks
}

// Rotate returns a new slice with the elements of xs rotated left by k
// positions: Rotate([1 2 3 4 5], 2) is [3 4 5 1 2]. k may be negative
// (which rotates right) or larger than len(xs); it is normalized modulo
// len(xs). Rotate never modifies xs, and returns nil if xs is empty.
func Rotate(xs []int, k int) []int {
	n := len(xs)
	if n == 0 {
		return nil
	}
	k = ((k % n) + n) % n // normalize: Go's % keeps the sign of k, so add n
	out := make([]int, 0, n)
	out = append(out, xs[k:]...)
	out = append(out, xs[:k]...)
	return out
}
