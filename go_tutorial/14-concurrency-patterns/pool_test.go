package patterns

import (
	"slices"
	"sync/atomic"
	"testing"
	"time"
)

func TestWorkerPool(t *testing.T) {
	double := func(n int) int { return n * 2 }
	tests := []struct {
		name    string
		jobs    []int
		workers int
		fn      func(int) int
		want    []int // expected results, sorted
	}{
		{"doubles with several workers", []int{1, 2, 3, 4, 5}, 3, double, []int{2, 4, 6, 8, 10}},
		{"single worker", []int{5, 6, 7}, 1, double, []int{10, 12, 14}},
		{"more workers than jobs", []int{1, 2}, 8, double, []int{2, 4}},
		{"workers < 1 treated as 1", []int{3}, 0, double, []int{6}},
		{"duplicates survive", []int{7, 7, 7}, 2, func(n int) int { return n }, []int{7, 7, 7}},
		{"empty jobs", nil, 4, double, nil},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var got []int
			withTimeout(t, "WorkerPool", func() {
				got = WorkerPool(tt.jobs, tt.workers, tt.fn)
			})
			// Workers deliver in whatever order they finish, so compare
			// as a multiset: sort before checking.
			slices.Sort(got)
			if !slices.Equal(got, tt.want) {
				t.Errorf("WorkerPool(%v, %d, fn) = (sorted) %v, want %v",
					tt.jobs, tt.workers, got, tt.want)
			}
		})
	}
}

func TestWorkerPoolCallsFnOncePerJob(t *testing.T) {
	jobs := make([]int, 100)
	for i := range jobs {
		jobs[i] = i
	}
	// fn runs on several goroutines at once, so the call counter must
	// be atomic — a plain int here would itself be a data race.
	var calls atomic.Int64
	fn := func(n int) int {
		calls.Add(1)
		return n
	}
	var got []int
	withTimeout(t, "WorkerPool", func() {
		got = WorkerPool(jobs, 5, fn)
	})
	if len(got) != len(jobs) {
		t.Errorf("WorkerPool(100 jobs, 5 workers, fn) returned %d results, want %d", len(got), len(jobs))
	}
	if n := calls.Load(); n != int64(len(jobs)) {
		t.Errorf("WorkerPool(100 jobs, 5 workers, fn) called fn %d times, want %d", n, len(jobs))
	}
}

// TestWorkerPoolRunsJobsConcurrently proves there really is a pool: the
// two jobs rendezvous inside fn — one call's send pairs with the other
// call's receive — which can only happen if two calls to fn are in
// flight at the same time. An implementation that processes jobs one
// after another leaves each call stuck until its escape-hatch timer
// fires, and the test fails.
func TestWorkerPoolRunsJobsConcurrently(t *testing.T) {
	barrier := make(chan struct{})
	var failed atomic.Bool
	fn := func(n int) int {
		select {
		case barrier <- struct{}{}:
		case <-barrier:
		case <-time.After(500 * time.Millisecond):
			failed.Store(true)
		}
		return n
	}
	var got []int
	withTimeout(t, "WorkerPool", func() {
		got = WorkerPool([]int{1, 2}, 2, fn)
	})
	if failed.Load() {
		t.Error("WorkerPool([1 2], 2, fn) never had two fn calls in flight at once — jobs must run concurrently")
	}
	slices.Sort(got)
	if want := []int{1, 2}; !slices.Equal(got, want) {
		t.Errorf("WorkerPool([1 2], 2, fn) = (sorted) %v, want %v", got, want)
	}
}
