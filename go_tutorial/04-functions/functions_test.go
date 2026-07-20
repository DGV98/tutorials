package functions

import (
	"fmt"
	"slices"
	"testing"
)

func TestMinMax(t *testing.T) {
	tests := []struct {
		name    string
		xs      []int
		wantMin int
		wantMax int
	}{
		{"single element", []int{7}, 7, 7},
		{"already sorted", []int{1, 2, 3, 4}, 1, 4},
		{"mixed signs", []int{3, -1, 4, -1, 5}, -1, 5},
		{"all equal", []int{2, 2, 2}, 2, 2},
		{"empty", nil, 0, 0},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			gotMin, gotMax := MinMax(tt.xs)
			if gotMin != tt.wantMin || gotMax != tt.wantMax {
				t.Errorf("MinMax(%v) = (%d, %d), want (%d, %d)",
					tt.xs, gotMin, gotMax, tt.wantMin, tt.wantMax)
			}
		})
	}
}

func TestClamp(t *testing.T) {
	tests := []struct {
		name            string
		x, lo, hi, want int
	}{
		{"inside range", 5, 0, 10, 5},
		{"below range", -3, 0, 10, 0},
		{"above range", 42, 0, 10, 10},
		{"at low bound", 0, 0, 10, 0},
		{"at high bound", 10, 0, 10, 10},
		{"degenerate range", 7, 3, 3, 3},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Clamp(tt.x, tt.lo, tt.hi); got != tt.want {
				t.Errorf("Clamp(%d, %d, %d) = %d, want %d",
					tt.x, tt.lo, tt.hi, got, tt.want)
			}
		})
	}
}

func TestSumAll(t *testing.T) {
	tests := []struct {
		name string
		xs   []int
		want int
	}{
		{"no arguments", nil, 0},
		{"one argument", []int{5}, 5},
		{"several arguments", []int{1, 2, 3}, 6},
		{"negatives", []int{-1, 1, -2}, -2},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Expanding a slice with xs... is how you feed parsed
			// input into a variadic function.
			if got := SumAll(tt.xs...); got != tt.want {
				t.Errorf("SumAll(%v...) = %d, want %d", tt.xs, got, tt.want)
			}
		})
	}

	// Individual arguments work too, of course.
	if got := SumAll(2, 4, 6); got != 12 {
		t.Errorf("SumAll(2, 4, 6) = %d, want 12", got)
	}
}

func TestMakeCounter(t *testing.T) {
	count := MakeCounter()
	if count == nil {
		t.Fatal("MakeCounter() = nil, want a function")
	}
	for i, want := range []int{1, 2, 3} {
		if got := count(); got != want {
			t.Errorf("counter call %d = %d, want %d", i+1, got, want)
		}
	}

	// Each counter must own independent state.
	fresh := MakeCounter()
	if got := fresh(); got != 1 {
		t.Errorf("fresh counter first call = %d, want 1", got)
	}
	if got := count(); got != 4 {
		t.Errorf("original counter after fresh one made = %d, want 4", got)
	}
}

func TestMakeAccumulator(t *testing.T) {
	acc := MakeAccumulator(100)
	if acc == nil {
		t.Fatal("MakeAccumulator(100) = nil, want a function")
	}
	steps := []struct{ add, want int }{
		{1, 101},
		{10, 111},
		{-11, 100},
	}
	for _, s := range steps {
		if got := acc(s.add); got != s.want {
			t.Errorf("acc(%d) = %d, want %d", s.add, got, s.want)
		}
	}

	// Independent state, as with counters.
	fresh := MakeAccumulator(0)
	if got := fresh(5); got != 5 {
		t.Errorf("fresh accumulator acc(5) = %d, want 5", got)
	}
}

func TestCompose(t *testing.T) {
	double := func(x int) int { return x * 2 }
	inc := func(x int) int { return x + 1 }

	tests := []struct {
		name string
		f, g func(int) int
		x    int
		want int
	}{
		{"double after inc", double, inc, 5, 12}, // double(inc(5)) = double(6)
		{"inc after double", inc, double, 5, 11}, // inc(double(5)) = inc(10)
		{"same function twice", double, double, 3, 12},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			h := Compose(tt.f, tt.g)
			if h == nil {
				t.Fatal("Compose(f, g) = nil, want a function")
			}
			if got := h(tt.x); got != tt.want {
				t.Errorf("Compose(f, g)(%d) = %d, want %d", tt.x, got, tt.want)
			}
		})
	}
}

func TestMakeFibonacci(t *testing.T) {
	fib := MakeFibonacci()
	if fib == nil {
		t.Fatal("MakeFibonacci() = nil, want a function")
	}
	tests := []struct{ n, want int }{
		{0, 0},
		{1, 1},
		{2, 1},
		{7, 13},
		{10, 55},
		{20, 6765},
		// Without the cache, naive recursion on n=50 makes ~2^50
		// calls and takes minutes. Memoized, it is instant.
		{50, 12586269025},
	}
	for _, tt := range tests {
		t.Run(fmt.Sprintf("fib(%d)", tt.n), func(t *testing.T) {
			if got := fib(tt.n); got != tt.want {
				t.Errorf("fib(%d) = %d, want %d", tt.n, got, tt.want)
			}
		})
	}

	// Asking again must hit the cache and still agree.
	if got := fib(20); got != 6765 {
		t.Errorf("fib(20) on second call = %d, want 6765", got)
	}
}

func TestDeferOrder(t *testing.T) {
	tests := []struct {
		n    int
		want []int
	}{
		{0, nil},
		{1, []int{1}},
		{3, []int{3, 2, 1}},
		{5, []int{5, 4, 3, 2, 1}},
	}
	for _, tt := range tests {
		t.Run(fmt.Sprintf("n=%d", tt.n), func(t *testing.T) {
			got := DeferOrder(tt.n)
			// slices.Equal treats nil and empty as equal, so an
			// implementation may return either for n <= 0.
			if !slices.Equal(got, tt.want) {
				t.Errorf("DeferOrder(%d) = %v, want %v", tt.n, got, tt.want)
			}
		})
	}
}
