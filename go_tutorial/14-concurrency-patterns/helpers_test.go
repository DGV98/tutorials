package patterns

import (
	"testing"
	"time"
)

// withTimeout runs f in its own goroutine and fails the test if f has
// not returned within a generous deadline. Correct solutions finish in
// milliseconds; the deadline exists only as a failsafe that turns an
// accidental deadlock into a readable test failure instead of a hung
// test binary. No test in this module depends on timing for
// correctness.
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
		t.Fatalf("%s did not finish within 2s — likely a deadlock, an unclosed channel, or an ignored context", what)
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
