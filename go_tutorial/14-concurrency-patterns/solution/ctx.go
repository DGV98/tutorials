package patterns

import (
	"context"
	"time"
)

// DoWithTimeout runs work, giving it at most timeout to finish.
//
// It derives a context from context.Background() with the given
// timeout, releases the context's resources when done (defer the
// CancelFunc — go vet has a check dedicated to forgetting this), runs
// work(ctx) in a new goroutine, and waits for whichever happens
// first:
//
//   - work returns v: the result is (v, nil).
//   - the context expires: the result is (0, ctx.Err()), and after a
//     timeout ctx.Err() is exactly context.DeadlineExceeded — callers
//     test for it with errors.Is.
//
// Hint: send work's result over a channel with capacity 1. A buffered
// channel lets the work goroutine deliver its answer and exit even
// after DoWithTimeout has stopped listening; unbuffered, that
// goroutine would block forever — a goroutine leak.
//
// DoWithTimeout is the boundary where a context is born. Below that
// boundary, work follows the convention used by all ctx-aware Go
// code: context is the first parameter, named ctx.
func DoWithTimeout(timeout time.Duration, work func(ctx context.Context) int) (int, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	// Capacity 1: if the deadline wins, the work goroutine can still
	// drop its late result into the buffer and exit instead of blocking
	// forever on a send nobody will receive.
	done := make(chan int, 1)
	go func() {
		done <- work(ctx)
	}()

	select {
	case v := <-done:
		return v, nil
	case <-ctx.Done():
		return 0, ctx.Err() // context.DeadlineExceeded after a timeout
	}
}

// CancelableSum receives ints from nums and adds them up, stopping at
// whichever of these happens first:
//
//   - nums is closed: it returns (total, nil).
//   - ctx is canceled or times out: it returns the sum accumulated so
//     far and ctx.Err() — context.Canceled after a cancel(),
//     context.DeadlineExceeded after a timeout.
//
// The shape is a for loop around a two-case select: one case receives
// from nums with the comma-ok form (to notice when it closes), the
// other receives from ctx.Done(). That loop-around-select is THE
// pattern for long-running channel consumers that must be stoppable —
// and, per convention, ctx is the first parameter.
func CancelableSum(ctx context.Context, nums <-chan int) (int, error) {
	total := 0
	for {
		select {
		case <-ctx.Done():
			return total, ctx.Err()
		case n, ok := <-nums:
			if !ok {
				return total, nil
			}
			total += n
		}
	}
}
