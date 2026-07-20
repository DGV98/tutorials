// Package pointers is the exercise package for module 08: taking addresses,
// dereferencing, nil guards, and knowing when a pointer is (not) needed.
package pointers

// Increment adds 1 to the int that p points to. If p is nil, Increment
// does nothing.
func Increment(p *int) {
	if p == nil {
		return
	}
	*p++ // an IncDec statement works through a dereference
}

// Swap exchanges the values that a and b point to. If either pointer is
// nil, Swap does nothing (the other value is left untouched).
func Swap(a, b *int) {
	if a == nil || b == nil {
		return
	}
	*a, *b = *b, *a
}

// SafeDeref dereferences p safely: it returns the value p points to and
// true. If p is nil, it returns 0 and false instead of panicking.
func SafeDeref(p *int) (int, bool) {
	if p == nil {
		return 0, false
	}
	return *p, true
}

// DoubleAll multiplies every element of xs by 2, in place. The caller sees
// the changes even though xs is passed by value, because a slice header
// already contains a pointer to its backing array — no *[]int required.
// A nil or empty slice is a no-op.
func DoubleAll(xs []int) {
	// Index into the slice; a `for _, x := range xs` value variable would
	// be a copy and doubling it would change nothing.
	for i := range xs {
		xs[i] *= 2
	}
}

// ResetToZero sets the int that p points to back to 0. If p is nil,
// ResetToZero does nothing.
func ResetToZero(p *int) {
	if p == nil {
		return
	}
	*p = 0
}

// MoveToward nudges the point (*x, *y) one step toward the target (tx, ty):
// each coordinate independently moves by exactly 1 in the direction of its
// target, and stays put if it already matches. Called in a loop, it walks
// the point to the target like a chess king. If either pointer is nil,
// MoveToward does nothing.
func MoveToward(x, y *int, tx, ty int) {
	if x == nil || y == nil {
		return
	}
	*x += step(*x, tx)
	*y += step(*y, ty)
}

// step returns the unit direction (-1, 0, or +1) that moves cur toward target.
func step(cur, target int) int {
	switch {
	case cur < target:
		return 1
	case cur > target:
		return -1
	default:
		return 0
	}
}
