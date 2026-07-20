// Package records is the exercise package for module 09: defining struct
// types, attaching behavior with value and pointer receivers, constructor
// functions, and composition through embedding.
package records

// Point is a 2D grid coordinate — the bread and butter of Advent of Code
// maps. It is a small value type: pass it and store it by value, and
// compare Points directly with ==.
type Point struct {
	X, Y int
}

// Manhattan returns the Manhattan (taxicab) distance between p and q:
// |p.X-q.X| + |p.Y-q.Y|. The result is never negative, and it is 0
// exactly when p == q.
func (p Point) Manhattan(q Point) int {
	// TODO: implement
	return 0
}

// Rect is an axis-aligned rectangle spanning the corners Min and Max.
// A well-formed Rect satisfies Min.X <= Max.X and Min.Y <= Max.Y; the
// methods below assume that.
type Rect struct {
	Min, Max Point
}

// Area returns the geometric area of r: (Max.X-Min.X) * (Max.Y-Min.Y).
// A Rect whose Min equals its Max has area 0.
func (r Rect) Area() int {
	// TODO: implement
	return 0
}

// Perimeter returns the perimeter of r: 2 * (width + height), where
// width = Max.X-Min.X and height = Max.Y-Min.Y. A Rect whose Min equals
// its Max has perimeter 0.
func (r Rect) Perimeter() int {
	// TODO: implement
	return 0
}

// Contains reports whether p lies within r. The bounds are inclusive:
// points on any edge — including the Min and Max corners themselves —
// count as inside.
func (r Rect) Contains(p Point) bool {
	// TODO: implement
	return false
}
