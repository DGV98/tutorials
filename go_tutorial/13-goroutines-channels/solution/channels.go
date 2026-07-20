// Package channels contains the exercises for module 13: starting
// goroutines, waiting with sync.WaitGroup, unbuffered and buffered
// channels, close and range, select, and directional channel types.
package channels

import "sync"

// SumConcurrent returns the sum of xs, computed by workers goroutines
// working in parallel.
//
// Split xs into workers contiguous chunks, as evenly as possible; if
// workers > len(xs) some chunks are simply empty. Each worker sums its
// own chunk and sends the partial sum over a channel, and the caller
// adds the partials together. Addition is commutative, so the order in
// which partials arrive does not matter — that is what makes this safe
// to parallelize.
//
// A workers value < 1 is treated as 1. An empty or nil xs returns 0.
// SumConcurrent must not return until every worker has finished;
// receiving exactly one partial per worker guarantees that.
func SumConcurrent(xs []int, workers int) int {
	if workers < 1 {
		workers = 1
	}
	n := len(xs)

	// Buffered with one slot per worker, so a worker can deliver its
	// partial and exit even if the collector has not caught up yet.
	partials := make(chan int, workers)

	for w := range workers {
		// Balanced split: worker w owns xs[w*n/workers : (w+1)*n/workers].
		// Chunk sizes differ by at most one, and empty chunks are fine.
		lo, hi := w*n/workers, (w+1)*n/workers
		go func() {
			sum := 0
			for _, v := range xs[lo:hi] {
				sum += v
			}
			partials <- sum
		}()
	}

	// Receiving exactly one partial per worker both assembles the
	// answer and joins every goroutine before we return.
	total := 0
	for range workers {
		total += <-partials
	}
	return total
}

// Generate returns a channel that yields 1, 2, ..., n in order and is
// then closed. If n < 1 the channel is closed without yielding any
// values. The returned channel is never nil.
//
// Generate starts a producer goroutine and returns immediately; the
// producer makes progress only as fast as the consumer receives.
// Closing the channel is what lets consumers range over it and know
// when to stop.
func Generate(n int) <-chan int {
	ch := make(chan int)
	go func() {
		// defer guarantees the close even if the loop body grew an
		// early return later; the producer owns the channel, so the
		// producer closes it.
		defer close(ch)
		for i := 1; i <= n; i++ {
			ch <- i
		}
	}()
	return ch
}

// Merge fans in: the returned channel carries every value received
// from a and every value received from b, in whatever order they
// arrive. It is closed only after BOTH inputs have been closed and
// drained, and it is never nil.
//
// Hint: start one forwarding goroutine per input, and use a
// sync.WaitGroup plus one more goroutine to close the output once both
// forwarders are done. Exactly one goroutine may close a channel;
// closing it from two places would panic.
func Merge(a, b <-chan int) <-chan int {
	out := make(chan int)

	forward := func(c <-chan int) {
		for v := range c {
			out <- v
		}
	}

	var wg sync.WaitGroup
	wg.Go(func() { forward(a) }) // wg.Go (Go 1.25+) is Add(1) + go + Done
	wg.Go(func() { forward(b) })

	// A dedicated closer goroutine: waiting inside Merge itself would
	// block Merge's caller, and letting each forwarder close the
	// channel would close it twice — a panic.
	go func() {
		wg.Wait()
		close(out)
	}()
	return out
}

// Collect receives from ch until it is closed and returns the received
// values in arrival order. A channel that is closed without any values
// yields an empty (possibly nil) slice.
//
// Collect blocks until ch is closed — only pass it a channel that some
// goroutine is responsible for closing.
func Collect(ch <-chan int) []int {
	var out []int
	for v := range ch {
		out = append(out, v)
	}
	return out
}

// FirstValue blocks until a value arrives on either a or b and returns
// the first value received. If both channels have a value ready,
// either may win — callers must not depend on which.
//
// Use a select statement: it waits on several channels at once,
// something a plain receive expression cannot do.
func FirstValue(a, b <-chan string) string {
	select {
	case v := <-a:
		return v
	case v := <-b:
		return v
	}
}

// DoubleAll is a pipeline stage: the returned channel yields 2*v for
// every v received from in, preserving order, and is closed once in
// has been closed and drained. The returned channel is never nil.
//
// Like Generate, DoubleAll returns immediately and does its work in a
// goroutine, so stages compose:
//
//	Collect(DoubleAll(Generate(3))) // []int{2, 4, 6}
func DoubleAll(in <-chan int) <-chan int {
	out := make(chan int)
	go func() {
		defer close(out)
		for v := range in {
			out <- v * 2
		}
	}()
	return out
}
