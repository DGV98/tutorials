// Package channels contains the exercises for module 13: starting
// goroutines, waiting with sync.WaitGroup, unbuffered and buffered
// channels, close and range, select, and directional channel types.
package channels

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
	// TODO: implement
	return 0
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
	// TODO: implement
	return nil
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
	// TODO: implement
	return nil
}

// Collect receives from ch until it is closed and returns the received
// values in arrival order. A channel that is closed without any values
// yields an empty (possibly nil) slice.
//
// Collect blocks until ch is closed — only pass it a channel that some
// goroutine is responsible for closing.
func Collect(ch <-chan int) []int {
	// TODO: implement
	return nil
}

// FirstValue blocks until a value arrives on either a or b and returns
// the first value received. If both channels have a value ready,
// either may win — callers must not depend on which.
//
// Use a select statement: it waits on several channels at once,
// something a plain receive expression cannot do.
func FirstValue(a, b <-chan string) string {
	// TODO: implement
	return ""
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
	// TODO: implement
	return nil
}
