package patterns

import (
	"slices"
	"testing"
)

func TestGen(t *testing.T) {
	tests := []struct {
		name string
		nums []int
	}{
		{"several values in order", []int{3, 1, 4, 1, 5}},
		{"single value", []int{42}},
		{"no values closes immediately", nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ch := Gen(tt.nums...)
			if ch == nil {
				t.Fatalf("Gen(%v) = nil, want a non-nil channel", tt.nums)
			}
			var got []int
			withTimeout(t, "draining Gen", func() {
				for v := range ch {
					got = append(got, v)
				}
			})
			if !slices.Equal(got, tt.nums) {
				t.Errorf("Gen(%v) yielded %v, want %v", tt.nums, got, tt.nums)
			}
		})
	}
}

func TestSquare(t *testing.T) {
	tests := []struct {
		name string
		in   []int
		want []int
	}{
		{"squares preserve order", []int{1, 2, 3, 4}, []int{1, 4, 9, 16}},
		{"negatives square positive", []int{-3, 0, 5}, []int{9, 0, 25}},
		{"empty input", nil, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			out := Square(preloaded(tt.in...))
			if out == nil {
				t.Fatalf("Square(channel carrying %v) = nil, want a non-nil channel", tt.in)
			}
			var got []int
			withTimeout(t, "draining Square", func() {
				for v := range out {
					got = append(got, v)
				}
			})
			if !slices.Equal(got, tt.want) {
				t.Errorf("Square(channel carrying %v) yielded %v, want %v", tt.in, got, tt.want)
			}
		})
	}
}

func TestSum(t *testing.T) {
	tests := []struct {
		name string
		in   []int
		want int
	}{
		{"several values", []int{1, 2, 3, 4}, 10},
		{"negatives cancel", []int{5, -5, 7}, 7},
		{"single value", []int{9}, 9},
		{"closed empty channel", nil, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var got int
			withTimeout(t, "Sum", func() {
				got = Sum(preloaded(tt.in...))
			})
			if got != tt.want {
				t.Errorf("Sum(channel carrying %v) = %d, want %d", tt.in, got, tt.want)
			}
		})
	}
}

// TestPipeline snaps the three stages together the way real pipelines
// compose: source -> transform -> sink.
func TestPipeline(t *testing.T) {
	var got int
	withTimeout(t, "Sum(Square(Gen(1, 2, 3)))", func() {
		got = Sum(Square(Gen(1, 2, 3)))
	})
	if want := 14; got != want {
		t.Errorf("Sum(Square(Gen(1, 2, 3))) = %d, want %d", got, want)
	}
}
