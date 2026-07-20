package interfaces

import (
	"math"
	"reflect"
	"testing"
)

// almostEqual compares floats with a small tolerance; exact == is
// unreliable after floating-point arithmetic.
func almostEqual(a, b float64) bool {
	return math.Abs(a-b) <= 1e-9
}

// constShape satisfies Shape with a fixed, explicit area. Any type
// with an Area() float64 method is a Shape — even one declared inside
// a test file. That is implicit satisfaction at work.
type constShape struct {
	area float64
}

func (c constShape) Area() float64 { return c.area }

func TestCircleArea(t *testing.T) {
	tests := []struct {
		name   string
		radius float64
		want   float64
	}{
		{"unit circle", 1, math.Pi},
		{"radius 2", 2, 4 * math.Pi},
		{"fractional radius", 0.5, math.Pi / 4},
		{"zero radius", 0, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			c := Circle{Radius: tt.radius}
			if got := c.Area(); !almostEqual(got, tt.want) {
				t.Errorf("Circle{Radius: %v}.Area() = %v, want %v",
					tt.radius, got, tt.want)
			}
		})
	}
}

func TestSquareArea(t *testing.T) {
	tests := []struct {
		name string
		side float64
		want float64
	}{
		{"unit square", 1, 1},
		{"side 3", 3, 9},
		{"fractional side", 1.5, 2.25},
		{"zero side", 0, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			s := Square{Side: tt.side}
			if got := s.Area(); !almostEqual(got, tt.want) {
				t.Errorf("Square{Side: %v}.Area() = %v, want %v",
					tt.side, got, tt.want)
			}
		})
	}
}

func TestTotalArea(t *testing.T) {
	tests := []struct {
		name   string
		shapes []Shape
		want   float64
	}{
		{"nil slice", nil, 0},
		{"single circle", []Shape{Circle{Radius: 1}}, math.Pi},
		{"single square", []Shape{Square{Side: 2}}, 4},
		{
			"mixed shapes",
			[]Shape{Circle{Radius: 1}, Square{Side: 2}, constShape{area: 0.5}},
			math.Pi + 4 + 0.5,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := TotalArea(tt.shapes); !almostEqual(got, tt.want) {
				t.Errorf("TotalArea(%v) = %v, want %v", tt.shapes, got, tt.want)
			}
		})
	}
}

func TestSortByArea(t *testing.T) {
	tests := []struct {
		name   string
		shapes []Shape
		want   []Shape
	}{
		{
			"reverse order",
			[]Shape{constShape{3}, constShape{2}, constShape{1}},
			[]Shape{constShape{1}, constShape{2}, constShape{3}},
		},
		{
			"mixed implementations",
			// Areas: square 16, circle ~3.14, square 1.
			[]Shape{Square{Side: 4}, Circle{Radius: 1}, Square{Side: 1}},
			[]Shape{Square{Side: 1}, Circle{Radius: 1}, Square{Side: 4}},
		},
		{"already sorted", []Shape{constShape{1}, constShape{2}}, []Shape{constShape{1}, constShape{2}}},
		{"single element", []Shape{constShape{5}}, []Shape{constShape{5}}},
		{"nil slice", nil, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := append([]Shape(nil), tt.shapes...) // sort a copy
			SortByArea(got)
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("SortByArea(%v) = %v, want %v", tt.shapes, got, tt.want)
			}
		})
	}
}

func TestFilterShapes(t *testing.T) {
	t.Run("keep only circles", func(t *testing.T) {
		shapes := []Shape{Circle{Radius: 1}, Square{Side: 2}, Circle{Radius: 3}}
		// A type assertion inside a closure: the predicate keeps a
		// shape only if its dynamic type is Circle.
		isCircle := func(s Shape) bool {
			_, ok := s.(Circle)
			return ok
		}
		got := FilterShapes(shapes, isCircle)
		want := []Shape{Circle{Radius: 1}, Circle{Radius: 3}}
		if !reflect.DeepEqual(got, want) {
			t.Errorf("FilterShapes(%v, isCircle) = %v, want %v", shapes, got, want)
		}
	})

	t.Run("keep large areas", func(t *testing.T) {
		shapes := []Shape{constShape{1}, constShape{10}, constShape{5}}
		got := FilterShapes(shapes, func(s Shape) bool { return s.Area() >= 5 })
		want := []Shape{constShape{10}, constShape{5}}
		if !reflect.DeepEqual(got, want) {
			t.Errorf("FilterShapes(%v, area >= 5) = %v, want %v", shapes, got, want)
		}
	})

	t.Run("nothing matches", func(t *testing.T) {
		shapes := []Shape{constShape{1}, constShape{2}}
		got := FilterShapes(shapes, func(Shape) bool { return false })
		if len(got) != 0 {
			t.Errorf("FilterShapes(%v, keep nothing) = %v, want empty", shapes, got)
		}
	})

	t.Run("input is not modified", func(t *testing.T) {
		shapes := []Shape{constShape{2}, constShape{1}}
		FilterShapes(shapes, func(s Shape) bool { return s.Area() > 1 })
		want := []Shape{constShape{2}, constShape{1}}
		if !reflect.DeepEqual(shapes, want) {
			t.Errorf("FilterShapes modified its input: %v, want %v", shapes, want)
		}
	})
}
