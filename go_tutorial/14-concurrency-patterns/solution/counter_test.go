package patterns

import (
	"sync"
	"testing"
)

func TestSafeCounterSequential(t *testing.T) {
	var c SafeCounter // the zero value must be ready to use
	if got := c.Value("missing"); got != 0 {
		t.Errorf(`Value("missing") on a fresh counter = %d, want 0`, got)
	}
	c.Inc("gold")
	c.Inc("gold")
	c.Inc("silver")
	if got := c.Value("gold"); got != 2 {
		t.Errorf(`after Inc("gold") twice: Value("gold") = %d, want 2`, got)
	}
	if got := c.Value("silver"); got != 1 {
		t.Errorf(`after Inc("silver") once: Value("silver") = %d, want 1`, got)
	}
	if got := c.Value("bronze"); got != 0 {
		t.Errorf(`Value("bronze") without any Inc = %d, want 0`, got)
	}
}

// TestSafeCounterConcurrent hammers one counter from many goroutines.
// Run it with -race: an unsynchronized counter might still land on the
// right total by luck, but the race detector flags the unlocked map
// access every time.
func TestSafeCounterConcurrent(t *testing.T) {
	const (
		goroutines   = 8
		perGoroutine = 1000
	)
	var c SafeCounter
	var wg sync.WaitGroup
	for range goroutines {
		wg.Go(func() {
			for range perGoroutine {
				c.Inc("hits")
			}
		})
	}
	withTimeout(t, "concurrent Inc", wg.Wait)
	if got, want := c.Value("hits"), goroutines*perGoroutine; got != want {
		t.Errorf(`Value("hits") after %d goroutines x %d Inc = %d, want %d`,
			goroutines, perGoroutine, got, want)
	}
}

// TestSafeCounterConcurrentReadsAndWrites mixes readers and writers:
// concurrent map reads race with writes just as surely as two writes
// do, so Value must lock exactly like Inc.
func TestSafeCounterConcurrentReadsAndWrites(t *testing.T) {
	var c SafeCounter
	var wg sync.WaitGroup
	for range 4 {
		wg.Go(func() {
			for range 500 {
				c.Inc("k")
			}
		})
		wg.Go(func() {
			for range 500 {
				_ = c.Value("k") // any value is fine; it just must not race
			}
		})
	}
	withTimeout(t, "concurrent Inc and Value", wg.Wait)
	if got, want := c.Value("k"), 2000; got != want {
		t.Errorf(`Value("k") after 4 goroutines x 500 Inc = %d, want %d`, got, want)
	}
}
