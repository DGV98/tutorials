package pointers

import (
	"slices"
	"testing"
)

func TestIncrement(t *testing.T) {
	tests := []struct {
		name  string
		start int
		want  int
	}{
		{"positive", 5, 6},
		{"zero", 0, 1},
		{"negative", -3, -2},
		{"minus one to zero", -1, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			v := tt.start
			Increment(&v)
			if v != tt.want {
				t.Errorf("Increment(&%d) = %d, want %d", tt.start, v, tt.want)
			}
		})
	}

	t.Run("nil pointer is a no-op", func(t *testing.T) {
		Increment(nil) // must not panic
	})
}

func TestSwap(t *testing.T) {
	tests := []struct {
		name         string
		a, b         int
		wantA, wantB int
	}{
		{"distinct values", 1, 2, 2, 1},
		{"negative and positive", -7, 4, 4, -7},
		{"zero and nonzero", 0, 9, 9, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			a, b := tt.a, tt.b
			Swap(&a, &b)
			if a != tt.wantA || b != tt.wantB {
				t.Errorf("Swap(&%d, &%d) = (%d, %d), want (%d, %d)",
					tt.a, tt.b, a, b, tt.wantA, tt.wantB)
			}
		})
	}

	t.Run("nil first argument is a no-op", func(t *testing.T) {
		b := 42
		Swap(nil, &b)
		if b != 42 {
			t.Errorf("Swap(nil, &42) changed b to %d, want 42 (unchanged)", b)
		}
	})

	t.Run("nil second argument is a no-op", func(t *testing.T) {
		a := 7
		Swap(&a, nil)
		if a != 7 {
			t.Errorf("Swap(&7, nil) changed a to %d, want 7 (unchanged)", a)
		}
	})
}

func TestSafeDeref(t *testing.T) {
	tests := []struct {
		name   string
		val    int  // pointed-to value when p is non-nil
		useNil bool // pass nil instead of &val
		want   int
		wantOK bool
	}{
		{"points at 42", 42, false, 42, true},
		{"points at a negative", -5, false, -5, true},
		{"points at zero", 0, false, 0, true},
		{"nil pointer", 0, true, 0, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var p *int
			if !tt.useNil {
				p = &tt.val
			}
			got, ok := SafeDeref(p)
			if got != tt.want || ok != tt.wantOK {
				t.Errorf("SafeDeref(%v) = (%d, %t), want (%d, %t)",
					p, got, ok, tt.want, tt.wantOK)
			}
		})
	}
}

func TestDoubleAll(t *testing.T) {
	tests := []struct {
		name string
		xs   []int
		want []int
	}{
		{"several elements", []int{1, 2, 3}, []int{2, 4, 6}},
		{"zeros and negatives", []int{0, -2, 5}, []int{0, -4, 10}},
		{"single element", []int{7}, []int{14}},
		{"empty", nil, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := slices.Clone(tt.xs)
			DoubleAll(got)
			if !slices.Equal(got, tt.want) {
				t.Errorf("DoubleAll(%v) = %v, want %v", tt.xs, got, tt.want)
			}
		})
	}
}

func TestResetToZero(t *testing.T) {
	tests := []struct {
		name  string
		start int
	}{
		{"positive", 5},
		{"negative", -9},
		{"already zero", 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			v := tt.start
			ResetToZero(&v)
			if v != 0 {
				t.Errorf("ResetToZero(&%d) = %d, want 0", tt.start, v)
			}
		})
	}

	t.Run("nil pointer is a no-op", func(t *testing.T) {
		ResetToZero(nil) // must not panic
	})
}

func TestMoveToward(t *testing.T) {
	tests := []struct {
		name         string
		x, y         int
		tx, ty       int
		wantX, wantY int
	}{
		{"diagonal step up-right", 0, 0, 3, 3, 1, 1},
		{"only x differs", 2, 5, 8, 5, 3, 5},
		{"only y differs", 4, 9, 4, 2, 4, 8},
		{"step down-left", 5, 5, 0, 0, 4, 4},
		{"mixed directions", 5, 1, 0, 7, 4, 2},
		{"one step away", 1, 1, 2, 0, 2, 0},
		{"already at target", 3, 3, 3, 3, 3, 3},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			x, y := tt.x, tt.y
			MoveToward(&x, &y, tt.tx, tt.ty)
			if x != tt.wantX || y != tt.wantY {
				t.Errorf("MoveToward(&%d, &%d, %d, %d) = (%d, %d), want (%d, %d)",
					tt.x, tt.y, tt.tx, tt.ty, x, y, tt.wantX, tt.wantY)
			}
		})
	}

	t.Run("nil pointer is a no-op", func(t *testing.T) {
		y := 5
		MoveToward(nil, &y, 10, 10)
		if y != 5 {
			t.Errorf("MoveToward(nil, &5, 10, 10) changed y to %d, want 5 (unchanged)", y)
		}
	})

	t.Run("reaches the target when looped", func(t *testing.T) {
		x, y := 0, 4
		for range 10 {
			MoveToward(&x, &y, 6, 1)
		}
		if x != 6 || y != 1 {
			t.Errorf("looping MoveToward from (0, 4) toward (6, 1) ended at (%d, %d), want (6, 1)", x, y)
		}
	})
}
