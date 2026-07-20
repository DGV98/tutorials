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
	return abs(p.X-q.X) + abs(p.Y-q.Y)
}

// abs returns |x|. The standard library's math.Abs works on float64 only,
// so integer-heavy code routinely defines its own tiny helper.
func abs(x int) int {
	if x < 0 {
		return -x
	}
	return x
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
	return (r.Max.X - r.Min.X) * (r.Max.Y - r.Min.Y)
}

// Perimeter returns the perimeter of r: 2 * (width + height), where
// width = Max.X-Min.X and height = Max.Y-Min.Y. A Rect whose Min equals
// its Max has perimeter 0.
func (r Rect) Perimeter() int {
	return 2 * ((r.Max.X - r.Min.X) + (r.Max.Y - r.Min.Y))
}

// Contains reports whether p lies within r. The bounds are inclusive:
// points on any edge — including the Min and Max corners themselves —
// count as inside.
func (r Rect) Contains(p Point) bool {
	return r.Min.X <= p.X && p.X <= r.Max.X &&
		r.Min.Y <= p.Y && p.Y <= r.Max.Y
}
