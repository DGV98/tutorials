// Package interfaces contains the exercises for module 10: defining
// and satisfying interfaces implicitly, fmt.Stringer, type assertions
// and type switches, the any type, and sorting with slices.SortFunc.
package interfaces

// Shape is anything that can report its area. It is deliberately
// tiny — one method — because small interfaces are the Go idiom
// (compare io.Reader and fmt.Stringer, both single-method).
//
// Nothing "declares" that it implements Shape: any type with an
// Area() float64 method satisfies it automatically.
type Shape interface {
	Area() float64
}

// Circle is a circle with the given radius.
type Circle struct {
	Radius float64
}

// Square is a square with the given side length.
type Square struct {
	Side float64
}

// Area returns the area of the circle, πr². Use math.Pi.
//
// A zero-value Circle has area 0.
func (c Circle) Area() float64 {
	// TODO: implement
	return 0
}

// Area returns the area of the square, side².
//
// A zero-value Square has area 0.
func (s Square) Area() float64 {
	// TODO: implement
	return 0
}

// TotalArea returns the sum of the areas of all shapes.
//
// It must work for ANY mix of Shape implementations — including ones
// defined in other packages you have never seen — so it may only call
// what the interface promises: Area(). An empty or nil slice returns 0.
func TotalArea(shapes []Shape) float64 {
	// TODO: implement
	return 0
}

// SortByArea sorts shapes in place into ascending order of area.
//
// Use slices.SortFunc with a comparison function that returns a
// negative number, zero, or a positive number as a's area is less
// than, equal to, or greater than b's — cmp.Compare does exactly
// that. Sorting a nil or single-element slice is a no-op.
func SortByArea(shapes []Shape) {
	// TODO: implement
}

// FilterShapes returns a new slice containing, in their original
// order, the shapes for which keep returns true.
//
// The input slice is never modified. If nothing matches (or shapes is
// empty), the result has length 0 — nil is fine. keep is never nil.
func FilterShapes(shapes []Shape, keep func(Shape) bool) []Shape {
	// TODO: implement
	return nil
}
