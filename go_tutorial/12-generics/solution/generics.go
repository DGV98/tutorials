// Package generics is the exercise package for module 12: type parameters,
// constraints, and generic data structures.
package generics

import "cmp"

// MaxOf returns the larger of a and b, comparing with >.
// If a and b are equal, it returns a.
func MaxOf[T cmp.Ordered](a, b T) T {
	if b > a {
		return b
	}
	return a
}

// Map returns a new slice of the same length as xs in which every element
// is f applied to the corresponding element of xs. It never modifies xs.
// For an empty or nil xs it returns a slice of length 0.
//
// This is the real version of MapInts from module 05: the element type T
// and the result type U are now type parameters, so one Map works for
// every pair of types.
func Map[T, U any](xs []T, f func(T) U) []U {
	out := make([]U, len(xs))
	for i, x := range xs {
		out[i] = f(x)
	}
	return out
}

// Filter returns a new slice containing, in order, every element x of xs
// for which keep(x) is true. It never modifies xs. If no elements are
// kept (or xs is empty), Filter returns nil.
//
// This generalizes the int-only Filter from module 05.
func Filter[T any](xs []T, keep func(T) bool) []T {
	// Starting from a nil slice means "nothing kept" is nil for free.
	var out []T
	for _, x := range xs {
		if keep(x) {
			out = append(out, x)
		}
	}
	return out
}

// Reduce folds xs into a single value of type U. It starts with
// acc = initial and, for each element x of xs in order, sets
// acc = f(acc, x). It returns the final acc. For an empty or nil xs it
// returns initial unchanged.
func Reduce[T, U any](xs []T, initial U, f func(U, T) U) U {
	acc := initial
	for _, x := range xs {
		acc = f(acc, x)
	}
	return acc
}

// Keys returns a slice containing each key of m exactly once. The order
// of the returned keys is unspecified (map iteration order is random).
// For an empty or nil map it returns a slice of length 0.
func Keys[K comparable, V any](m map[K]V) []K {
	keys := make([]K, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}

// Contains reports whether target is one of the elements of xs.
// An empty or nil slice contains nothing.
//
// The standard library's slices.Contains is exactly this function; we
// write it once by hand to see what comparable buys us.
func Contains[T comparable](xs []T, target T) bool {
	for _, x := range xs {
		if x == target {
			return true
		}
	}
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
	// var sum T starts at the zero value of whatever T turns out to be:
	// 0 for the integer types, 0.0 for float64.
	var sum T
	for _, x := range xs {
		sum += x
	}
	return sum
}
