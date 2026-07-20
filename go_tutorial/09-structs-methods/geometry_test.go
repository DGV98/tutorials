package records

import "testing"

// Note the anonymous struct type declared inline for each table: defining
// a one-off named type for test rows would be pure ceremony. This is the
// single most common use of anonymous structs in Go.

func TestManhattan(t *testing.T) {
	tests := []struct {
		name string
		p, q Point
		want int
	}{
		{"same point", Point{X: 3, Y: 3}, Point{X: 3, Y: 3}, 0},
		{"along one axis", Point{X: 0, Y: 0}, Point{X: 5, Y: 0}, 5},
		{"diagonal", Point{X: 1, Y: 2}, Point{X: 4, Y: 6}, 7},
		{"negative coordinates", Point{X: -2, Y: -3}, Point{X: 2, Y: 3}, 10},
		{"order does not matter", Point{X: 4, Y: 6}, Point{X: 1, Y: 2}, 7},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := tt.p.Manhattan(tt.q); got != tt.want {
				t.Errorf("%v.Manhattan(%v) = %d, want %d", tt.p, tt.q, got, tt.want)
			}
		})
	}
}

func TestRectArea(t *testing.T) {
	tests := []struct {
		name string
		r    Rect
		want int
	}{
		{"unit square", Rect{Min: Point{X: 0, Y: 0}, Max: Point{X: 1, Y: 1}}, 1},
		{"3 by 4", Rect{Min: Point{X: 1, Y: 1}, Max: Point{X: 4, Y: 5}}, 12},
		{"negative corner", Rect{Min: Point{X: -2, Y: -2}, Max: Point{X: 2, Y: 2}}, 16},
		{"degenerate", Rect{Min: Point{X: 2, Y: 2}, Max: Point{X: 2, Y: 2}}, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := tt.r.Area(); got != tt.want {
				t.Errorf("Rect%v.Area() = %d, want %d", tt.r, got, tt.want)
			}
		})
	}
}

func TestRectPerimeter(t *testing.T) {
	tests := []struct {
		name string
		r    Rect
		want int
	}{
		{"unit square", Rect{Min: Point{X: 0, Y: 0}, Max: Point{X: 1, Y: 1}}, 4},
		{"3 by 4", Rect{Min: Point{X: 1, Y: 1}, Max: Point{X: 4, Y: 5}}, 14},
		{"degenerate", Rect{Min: Point{X: 2, Y: 2}, Max: Point{X: 2, Y: 2}}, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := tt.r.Perimeter(); got != tt.want {
				t.Errorf("Rect%v.Perimeter() = %d, want %d", tt.r, got, tt.want)
			}
		})
	}
}

func TestRectContains(t *testing.T) {
	box := Rect{Min: Point{X: 0, Y: 0}, Max: Point{X: 10, Y: 10}}
	tests := []struct {
		name string
		p    Point
		want bool
	}{
		{"interior", Point{X: 5, Y: 5}, true},
		{"min corner", Point{X: 0, Y: 0}, true},
		{"max corner", Point{X: 10, Y: 10}, true},
		{"on left edge", Point{X: 0, Y: 7}, true},
		{"outside right", Point{X: 11, Y: 5}, false},
		{"outside below", Point{X: 5, Y: -1}, false},
		{"x inside but y outside", Point{X: 5, Y: 11}, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := box.Contains(tt.p); got != tt.want {
				t.Errorf("Rect%v.Contains(%v) = %t, want %t", box, tt.p, got, tt.want)
			}
		})
	}
}
