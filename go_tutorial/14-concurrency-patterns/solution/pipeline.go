package patterns

// Gen is the first stage of a pipeline (a "source"): it returns a
// receive-only channel that delivers each of nums in order and is
// then closed.
//
// Gen itself returns immediately; a goroutine it starts does the
// sending. Closing the channel when the values run out is part of the
// contract — that close is what lets a downstream `for v := range ch`
// loop terminate. Gen() with no arguments returns a channel that is
// closed without delivering anything.
func Gen(nums ...int) <-chan int {
	out := make(chan int)
	go func() {
		defer close(out) // the producer owns the channel, so it closes it
		for _, n := range nums {
			out <- n
		}
	}()
	return out
}

// Square is a middle pipeline stage: it receives every value from in,
// sends the square of each on the channel it returns (preserving
// order), and closes its output once in has been closed and drained.
//
// Like Gen it returns its output channel immediately and does the
// work in a goroutine. Note the types: it consumes a <-chan int and
// produces a <-chan int, which is exactly what lets stages snap
// together — Square(Gen(1, 2, 3)) type-checks.
func Square(in <-chan int) <-chan int {
	out := make(chan int)
	go func() {
		defer close(out)
		for v := range in {
			out <- v * v
		}
	}()
	return out
}

// Sum is the final pipeline stage (a "sink"): it receives values from
// in until the channel is closed, then returns their total. Unlike
// the other stages it blocks the calling goroutine — someone
// eventually has to sit and wait for the answer. A channel that is
// closed without ever delivering a value sums to 0.
func Sum(in <-chan int) int {
	total := 0
	for v := range in {
		total += v
	}
	return total
}
