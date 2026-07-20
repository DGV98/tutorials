// Package generics is the exercise package for module 12: type parameters,
// constraints, and generic data structures.
package generics

import "cmp"

// MaxOf returns the larger of a and b, comparing with >.
// If a and b are equal, it returns a.
func MaxOf[T cmp.Ordered](a, b T) T {
	// TODO: implement
	var zero T
	return zero
}

// Map returns a new slice of the same length as xs in which every element
// is f applied to the corresponding element of xs. It never modifies xs.
// For an empty or nil xs it returns a slice of length 0.
//
// This is the real version of MapInts from module 05: the element type T
// and the result type U are now type parameters, so one Map works for
// every pair of types.
func Map[T, U any](xs []T, f func(T) U) []U {
	// TODO: implement
	return nil
}

// Filter returns a new slice containing, in order, every element x of xs
// for which keep(x) is true. It never modifies xs. If no elements are
// kept (or xs is empty), Filter returns nil.
//
// This generalizes the int-only Filter from module 05.
func Filter[T any](xs []T, keep func(T) bool) []T {
	// TODO: implement
	return nil
}

// Reduce folds xs into a single value of type U. It starts with
// acc = initial and, for each element x of xs in order, sets
// acc = f(acc, x). It returns the final acc. For an empty or nil xs it
// returns initial unchanged.
func Reduce[T, U any](xs []T, initial U, f func(U, T) U) U {
	// TODO: implement
	var zero U
	return zero
}

// Keys returns a slice containing each key of m exactly once. The order
// of the returned keys is unspecified (map iteration order is random).
// For an empty or nil map it returns a slice of length 0.
func Keys[K comparable, V any](m map[K]V) []K {
	// TODO: implement
	return nil
}

// Contains reports whether target is one of the elements of xs.
// An empty or nil slice contains nothing.
func Contains[T comparable](xs []T, target T) bool {
	// TODO: implement
	return false
}

// Number is a constraint satisfied by any type whose underlying type is
// int, int64, or float64 — including named types like `type Fuel int`,
// thanks to the ~ in each term.
type Number interface {
	~int | ~int64 | ~float64
}

// SumNumbers returns the sum of all elements of xs. The sum of an empty
// or nil slice is the zero value of T.
func SumNumbers[T Number](xs []T) T {
	// TODO: implement
	var zero T
	return zero
}
