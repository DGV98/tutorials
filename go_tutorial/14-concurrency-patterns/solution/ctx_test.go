package patterns

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestDoWithTimeout(t *testing.T) {
	t.Run("work finishes in time", func(t *testing.T) {
		var got int
		var err error
		withTimeout(t, "DoWithTimeout", func() {
			got, err = DoWithTimeout(time.Second, func(ctx context.Context) int {
				return 42 // returns immediately, far inside the deadline
			})
		})
		if err != nil || got != 42 {
			t.Errorf("DoWithTimeout(1s, instant work) = (%d, %v), want (42, nil)", got, err)
		}
	})

	t.Run("work receives a context that carries the deadline", func(t *testing.T) {
		var got int
		var err error
		withTimeout(t, "DoWithTimeout", func() {
			got, err = DoWithTimeout(time.Second, func(ctx context.Context) int {
				if _, ok := ctx.Deadline(); ok {
					return 1
				}
				return 0
			})
		})
		if err != nil || got != 1 {
			t.Errorf("DoWithTimeout(1s, deadline-checking work) = (%d, %v), want (1, nil) — work's ctx must carry the timeout", got, err)
		}
	})

	t.Run("work outlives the deadline", func(t *testing.T) {
		// The work blocks on a channel the test only closes AFTER
		// DoWithTimeout has returned, so during the call the deadline is
		// the only thing that can fire — no scheduling luck involved.
		release := make(chan struct{})
		defer close(release) // lets the work goroutine finish and exit
		var got int
		var err error
		withTimeout(t, "DoWithTimeout", func() {
			got, err = DoWithTimeout(20*time.Millisecond, func(ctx context.Context) int {
				<-release
				return -1
			})
		})
		if !errors.Is(err, context.DeadlineExceeded) {
			t.Errorf("DoWithTimeout(20ms, stuck work) error = %v, want context.DeadlineExceeded", err)
		}
		if got != 0 {
			t.Errorf("DoWithTimeout(20ms, stuck work) value = %d, want 0", got)
		}
	})
}

func TestCancelableSum(t *testing.T) {
	t.Run("channel closes first", func(t *testing.T) {
		// context.Background() is never canceled, so the only way out is
		// draining the channel to its close.
		var got int
		var err error
		withTimeout(t, "CancelableSum", func() {
			got, err = CancelableSum(context.Background(), preloaded(1, 2, 3, 4))
		})
		if err != nil || got != 10 {
			t.Errorf("CancelableSum(Background, closed channel carrying 1 2 3 4) = (%d, %v), want (10, nil)", got, err)
		}
	})

	t.Run("context already canceled", func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())
		cancel() // canceled before CancelableSum even starts
		// The channel stays open and silent, so only the Done case can
		// ever fire — the outcome does not depend on a select tiebreak.
		nums := make(chan int)
		var got int
		var err error
		withTimeout(t, "CancelableSum", func() {
			got, err = CancelableSum(ctx, nums)
		})
		if !errors.Is(err, context.Canceled) {
			t.Errorf("CancelableSum(canceled ctx, silent channel) error = %v, want context.Canceled", err)
		}
		if got != 0 {
			t.Errorf("CancelableSum(canceled ctx, silent channel) sum = %d, want 0", got)
		}
	})

	t.Run("canceled mid-stream keeps the partial sum", func(t *testing.T) {
		ctx, cancel := context.WithCancel(context.Background())
		nums := make(chan int) // unbuffered: a send completes only when received
		go func() {
			for _, v := range []int{5, 6, 7} {
				nums <- v
			}
			// Every send above has been received, so the sum already
			// includes all three values. The channel stays open: from
			// here on only ctx.Done() can unblock CancelableSum.
			cancel()
		}()
		var got int
		var err error
		withTimeout(t, "CancelableSum", func() {
			got, err = CancelableSum(ctx, nums)
		})
		if !errors.Is(err, context.Canceled) {
			t.Errorf("CancelableSum(ctx canceled after 5+6+7) error = %v, want context.Canceled", err)
		}
		if got != 18 {
			t.Errorf("CancelableSum(ctx canceled after 5+6+7) sum = %d, want 18", got)
		}
	})

	t.Run("deadline already expired", func(t *testing.T) {
		ctx, cancel := context.WithDeadline(context.Background(), time.Now().Add(-time.Hour))
		defer cancel()
		var got int
		var err error
		withTimeout(t, "CancelableSum", func() {
			got, err = CancelableSum(ctx, make(chan int))
		})
		if !errors.Is(err, context.DeadlineExceeded) {
			t.Errorf("CancelableSum(expired ctx, silent channel) error = %v, want context.DeadlineExceeded", err)
		}
		if got != 0 {
			t.Errorf("CancelableSum(expired ctx, silent channel) sum = %d, want 0", got)
		}
	})
}
