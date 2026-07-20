// Package slicing is the exercise package for module 05: arrays, slices,
// and 2D grids.
package slicing

// Sum returns the sum of all elements of xs.
// The sum of an empty or nil slice is 0.
func Sum(xs []int) int {
	// TODO: implement
	return 0
}

// Max returns the largest element of xs and true.
// If xs is empty or nil, it returns 0 and false.
func Max(xs []int) (int, bool) {
	// TODO: implement
	return 0, false
}

// ReverseInPlace reverses the order of the elements of xs, modifying the
// slice it was given (it allocates nothing). Empty and single-element
// slices are left as they are.
func ReverseInPlace(xs []int) {
	// TODO: implement
}

// Filter returns a new slice containing, in order, every element x of xs
// for which keep(x) is true. It never modifies xs. If no elements are
// kept (or xs is empty), Filter returns nil.
func Filter(xs []int, keep func(int) bool) []int {
	// TODO: implement
	return nil
}

// MapInts returns a new slice of the same length as xs in which every
// element is f applied to the corresponding element of xs. It never
// modifies xs. For an empty or nil xs it returns a slice of length 0.
func MapInts(xs []int, f func(int) int) []int {
	// TODO: implement
	return nil
}

// Chunk splits xs into consecutive chunks of length size and returns them
// in order; the final chunk is shorter when len(xs) is not a multiple of
// size. Chunk returns nil if xs is empty or size <= 0. The returned
// chunks may share memory with xs (subslices are fine).
func Chunk(xs []int, size int) [][]int {
	// TODO: implement
	return nil
}

// Rotate returns a new slice with the elements of xs rotated left by k
// positions: Rotate([1 2 3 4 5], 2) is [3 4 5 1 2]. k may be negative
// (which rotates right) or larger than len(xs); it is normalized modulo
// len(xs). Rotate never modifies xs, and returns nil if xs is empty.
func Rotate(xs []int, k int) []int {
	// TODO: implement
	return nil
}
