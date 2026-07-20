package channels

import (
	"slices"
	"testing"
	"time"
)

// withTimeout runs f in its own goroutine and fails the test if f has
// not returned within a generous deadline. Correct solutions finish in
// microseconds; the deadline exists only as a failsafe that turns an
// accidental deadlock into a readable test failure instead of a hung
// test binary. No test in this file depends on timing for correctness.
func withTimeout(t *testing.T, what string, f func()) {
	t.Helper()
	done := make(chan struct{})
	go func() {
		defer close(done)
		f()
	}()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatalf("%s did not finish within 2s — likely a deadlock or an unclosed channel", what)
	}
}

// preloaded returns a closed channel already holding vals, so tests can
// feed exact inputs without starting extra goroutines.
func preloaded(vals ...int) <-chan int {
	ch := make(chan int, len(vals))
	for _, v := range vals {
		ch <- v
	}
	close(ch)
	return ch
}

func TestSumConcurrent(t *testing.T) {
	big := make([]int, 1000)
	for i := range big {
		big[i] = i + 1 // 1..1000 sums to 500500
	}

	tests := []struct {
		name    string
		xs      []int
		workers int
		want    int
	}{
		{"single worker", []int{1, 2, 3, 4}, 1, 10},
		{"even split", []int{1, 2, 3, 4, 5, 6}, 2, 21},
		{"uneven split", []int{5, 5, 5, 5, 5}, 2, 25},
		{"more workers than elements", []int{1, 2, 3}, 8, 6},
		{"workers < 1 treated as 1", []int{4, 4}, 0, 8},
		{"negative values", []int{10, -3, -7, 2}, 3, 2},
		{"empty slice", nil, 4, 0},
		{"1..1000 with 7 workers", big, 7, 500500},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var got int
			withTimeout(t, "SumConcurrent", func() {
				got = SumConcurrent(tt.xs, tt.workers)
			})
			if got != tt.want {
				t.Errorf("SumConcurrent(len(xs)=%d, workers=%d) = %d, want %d",
					len(tt.xs), tt.workers, got, tt.want)
			}
		})
	}
}

func TestGenerate(t *testing.T) {
	tests := []struct {
		name string
		n    int
		want []int
	}{
		{"n=5", 5, []int{1, 2, 3, 4, 5}},
		{"n=1", 1, []int{1}},
		{"n=0 closes immediately", 0, nil},
		{"negative n closes immediately", -3, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ch := Generate(tt.n)
			if ch == nil {
				t.Fatalf("Generate(%d) = nil, want a non-nil channel", tt.n)
			}
			var got []int
			withTimeout(t, "draining Generate", func() {
				for v := range ch {
					got = append(got, v)
				}
			})
			if !slices.Equal(got, tt.want) {
				t.Errorf("Generate(%d) yielded %v, want %v", tt.n, got, tt.want)
			}
			// The range loop above only ends because the channel was
			// closed. A further receive must not block: it reports the
			// zero value and ok == false.
			if v, ok := <-ch; ok || v != 0 {
				t.Errorf("Generate(%d): receive after close = (%d, %t), want (0, false)", tt.n, v, ok)
			}
		})
	}
}

func TestMerge(t *testing.T) {
	tests := []struct {
		name string
		a, b []int
		want []int // the merged values, sorted
	}{
		{"both carry values", []int{1, 3, 5}, []int{2, 4}, []int{1, 2, 3, 4, 5}},
		{"first input empty", nil, []int{7, 8}, []int{7, 8}},
		{"second input empty", []int{9}, nil, []int{9}},
		{"both empty", nil, nil, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			out := Merge(preloaded(tt.a...), preloaded(tt.b...))
			if out == nil {
				t.Fatal("Merge(a, b) = nil, want a non-nil channel")
			}
			var got []int
			withTimeout(t, "draining Merge", func() {
				for v := range out {
					got = append(got, v)
				}
			})
			// The interleaving of a and b is scheduler-dependent, so
			// compare as a multiset: sort before checking.
			slices.Sort(got)
			if !slices.Equal(got, tt.want) {
				t.Errorf("Merge(%v, %v) yielded (sorted) %v, want %v", tt.a, tt.b, got, tt.want)
			}
		})
	}
}

func TestCollect(t *testing.T) {
	tests := []struct {
		name string
		vals []int
		want []int
	}{
		{"several values in order", []int{3, 1, 4, 1, 5}, []int{3, 1, 4, 1, 5}},
		{"single value", []int{42}, []int{42}},
		{"closed empty channel", nil, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var got []int
			withTimeout(t, "Collect", func() {
				got = Collect(preloaded(tt.vals...))
			})
			if !slices.Equal(got, tt.want) {
				t.Errorf("Collect(channel carrying %v) = %v, want %v", tt.vals, got, tt.want)
			}
		})
	}
}

func TestFirstValue(t *testing.T) {
	tests := []struct {
		name         string
		aVals, bVals []string
		want         string
	}{
		{"value ready on a", []string{"alpha"}, nil, "alpha"},
		{"value ready on b", nil, []string{"beta"}, "beta"},
		{"both ready with the same value", []string{"tie"}, []string{"tie"}, "tie"},
	}
	// mk builds the test input: a buffered channel already holding
	// vals, or — when vals is empty — an open, unbuffered channel that
	// never delivers anything. The silent channel must stay open: a
	// closed channel is always ready to receive (yielding "" and
	// ok == false), which would make select nondeterministic here.
	mk := func(vals []string) chan string {
		ch := make(chan string, len(vals))
		for _, v := range vals {
			ch <- v
		}
		return ch
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			a, b := mk(tt.aVals), mk(tt.bVals)
			var got string
			withTimeout(t, "FirstValue", func() {
				got = FirstValue(a, b)
			})
			if got != tt.want {
				t.Errorf("FirstValue(a=%v, b=%v) = %q, want %q", tt.aVals, tt.bVals, got, tt.want)
			}
		})
	}
}

func TestDoubleAll(t *testing.T) {
	tests := []struct {
		name string
		in   []int
		want []int
	}{
		{"doubles and preserves order", []int{1, 2, 3}, []int{2, 4, 6}},
		{"negative and zero", []int{-2, 0, 9}, []int{-4, 0, 18}},
		{"empty input", nil, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			out := DoubleAll(preloaded(tt.in...))
			if out == nil {
				t.Fatal("DoubleAll(in) = nil, want a non-nil channel")
			}
			var got []int
			withTimeout(t, "draining DoubleAll", func() {
				for v := range out {
					got = append(got, v)
				}
			})
			if !slices.Equal(got, tt.want) {
				t.Errorf("DoubleAll(channel carrying %v) yielded %v, want %v", tt.in, got, tt.want)
			}
		})
	}
}

// TestPipeline chains the exercises the way real channel pipelines
// compose: generator -> transform stage -> sink.
func TestPipeline(t *testing.T) {
	var got []int
	withTimeout(t, "Collect(DoubleAll(Generate(5)))", func() {
		got = Collect(DoubleAll(Generate(5)))
	})
	want := []int{2, 4, 6, 8, 10}
	if !slices.Equal(got, want) {
		t.Errorf("Collect(DoubleAll(Generate(5))) = %v, want %v", got, want)
	}
}
