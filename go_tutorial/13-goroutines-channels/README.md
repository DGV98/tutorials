# 13. Goroutines & Channels

Concurrency is Go's headline feature, and it looks nothing like threads-and-locks
in most other languages. Instead of sharing memory and guarding it, idiomatic Go
starts cheap **goroutines** and lets them talk over **channels** — typed pipes
whose send and receive operations synchronize the two sides for you. The Go
proverb sums it up: *"Don't communicate by sharing memory; share memory by
communicating."*

This module covers the mechanics: what `go` actually does, why your program may
exit before a goroutine runs, how to wait properly, and how channels block,
buffer, close, and combine under `select`. Module 14 builds real patterns
(worker pools, mutexes, `context`) on top of this foundation.

## What you'll learn

- What `go f()` does — and why `main` won't wait for it
- Joining goroutines with `sync.WaitGroup` (and the loop-variable capture story)
- Channel send/receive as a rendezvous: both sides block until both are ready
- Buffered channels, and what buffering does *not* fix
- `close`, the `v, ok := <-ch` form, and why receiving from a closed channel never blocks
- `for v := range ch` to consume a channel until it closes
- `select` to wait on several channels at once
- Directional channel types (`chan<- T`, `<-chan T`) as compiler-checked documentation
- How to read the `all goroutines are asleep - deadlock!` crash

## `go` starts a goroutine — and `main` does not wait

A goroutine is a lightweight, runtime-managed thread of execution. It starts
with a tiny stack (a few KB, grown on demand), and the Go runtime multiplexes
thousands of them onto a handful of OS threads. Starting one is a statement:

```go
go fmt.Println("hello from a goroutine")
```

Two things surprise everyone at first:

1. **There is no implicit join.** When `main` returns, the process exits and
   every other goroutine is killed mid-flight, silently:

   ```go
   func main() {
       go fmt.Println("you may never see this")
       // main returns; the program exits right here.
   }
   ```

2. **Arguments are evaluated now, the call runs later.** In `go f(x)`, `x` is
   evaluated at the `go` statement, but `f` runs whenever the scheduler gets to
   it. There is no handle, no return value, no way to ask "is it done?" — if
   you need results or completion, you use a channel or a `WaitGroup`.

## Waiting properly: `sync.WaitGroup`

A `WaitGroup` is a thread-safe counter: `Add(n)` increments it, `Done()`
decrements it, and `Wait()` blocks until it hits zero.

```go
var wg sync.WaitGroup
for _, f := range files {
    wg.Add(1)
    go func() {
        defer wg.Done()
        process(f)
    }()
}
wg.Wait() // blocks until every goroutine has called Done
```

Rules that keep this correct:

- Call `Add` **before** the `go` statement, not inside the goroutine. If the
  goroutine hasn't run yet when you reach `Wait()`, the counter would still be
  zero and `Wait` would return early.
- Pair `Add(1)` with `defer wg.Done()` as the goroutine's first line, so the
  counter is decremented even if the body panics or returns early.
- Never copy a `WaitGroup` (pass `*sync.WaitGroup` if it crosses a function
  boundary) — `go vet` flags copies.

Since Go 1.25 there's a shorthand that does the `Add`/`go`/`Done` dance for
you, and it's now the preferred form when it fits:

```go
var wg sync.WaitGroup
wg.Go(func() { process(f) })
wg.Wait()
```

### The loop-variable capture story

For a decade, this was Go's most famous bug:

```go
for _, v := range []int{1, 2, 3} {
    go func() { fmt.Println(v) }()
}
```

**Before Go 1.22**, `v` was a *single* variable reused across iterations. The
goroutines usually didn't run until the loop finished, so all three printed the
last value: `3 3 3`. The fixes were to shadow it (`v := v` — yes, that line was
idiomatic) or pass it as an argument (`go func(v int) {...}(v)`).

**Go 1.22 changed the language**: each iteration now gets a fresh `v`, so the
code above prints `1`, `2`, `3`. You will still meet `v := v` in older
codebases; it's harmless now, just unnecessary.

Note what did *not* change: the **order** of the output is still up to the
scheduler. `1 2 3`, `3 1 2`, … all happen. Never assert on cross-goroutine
ordering — design results to be order-independent (sums, sets, sorted slices).

## Channels: send and receive block until both sides are ready

A channel is a typed conduit. `make(chan int)` creates an **unbuffered** one:

```go
ch := make(chan int)

go func() {
    ch <- 42 // send: blocks until someone is ready to receive
}()

v := <-ch // receive: blocks until someone sends
```

On an unbuffered channel, a send and a receive are a *rendezvous*: neither
completes until both sides arrive. That blocking is not a limitation — it's
the point. The receive above doubles as synchronization ("the goroutine got
this far") and communication ("...and produced 42"), with no locks in sight.

This is also why the guarantee in the previous section matters: if `main` had
not received from `ch`, the send would block forever.

## Buffered channels

`make(chan int, 3)` gives the channel a buffer of capacity 3:

- Sends complete immediately while the buffer has room; they block when full.
- Receives complete immediately while the buffer has values; they block when empty.

```go
results := make(chan int, len(jobs)) // one slot per producer
```

That pattern — capacity equal to the number of pending sends — lets every
producer deliver its result and exit without waiting for the consumer, which is
exactly what `SumConcurrent` wants.

A warning from experience: **a buffer is not a bug fix**. If your program
deadlocks with an unbuffered channel, adding a buffer usually just delays the
deadlock until the buffer fills. Buffers change *when* blocking happens, never
*whether* the communication logic is right.

## `close`, and receiving from a closed channel

`close(ch)` marks a channel as "no more values will ever be sent."

```go
close(ch)

v, ok := <-ch // once closed and drained: v is the zero value, ok is false
```

The rules:

- **Only the sender closes.** The receiver can't know if another send is
  coming; the sender does. For a channel fed by many goroutines, exactly one
  place closes it (see `Merge`).
- **Sending on a closed channel panics.** So does closing twice. This is why
  ownership matters.
- **Receiving from a closed channel never blocks.** It yields any buffered
  values first, then `(zero value, false)` forever.
- **You don't have to close channels.** They're garbage-collected like
  anything else. Close only when receivers need the "no more values" signal —
  which they do whenever they `range`.

## `range` over a channel

```go
for v := range ch {
    fmt.Println(v)
}
```

This receives repeatedly until the channel is **closed and drained**, then the
loop ends. It's the idiomatic consumer for producer-goroutine channels
(`Generate`, `DoubleAll`). The flip side: if nobody ever closes `ch`, the loop
blocks forever, and if that was the last runnable goroutine you get the
deadlock crash below.

## `select`: waiting on several channels at once

A plain `<-ch` can only wait on one channel. `select` waits on many and runs
whichever case becomes ready first:

```go
select {
case v := <-a:
    fmt.Println("a said", v)
case v := <-b:
    fmt.Println("b said", v)
}
```

- If **no** case is ready, `select` blocks until one is.
- If **several** are ready, one is chosen at **random** — deliberately, so no
  channel can starve the others. Never write code that depends on which case
  wins a tie.
- An optional `default` case runs when nothing is ready, turning `select` into
  a non-blocking poll. Use sparingly; a `default` in a loop is a busy-wait.

A common companion is a timeout case:

```go
select {
case v := <-results:
    use(v)
case <-time.After(5 * time.Second):
    return errors.New("timed out")
}
```

In this course's tests we use exactly that shape as a *failsafe* — a correct
solution never comes near the deadline; it only converts an accidental
deadlock into a readable failure.

## Directional channel types

A bare `chan int` allows both operations. The directional forms restrict it:

- `chan<- int` — send-only (the arrow points *into* the chan)
- `<-chan int` — receive-only (the arrow points *out of* the chan)

A bidirectional channel converts implicitly to either directional type, never
the other way. Use them in signatures as documentation the compiler enforces:

```go
func Generate(n int) <-chan int      // "you only consume this"
func worker(jobs <-chan job, out chan<- result)
```

A caller holding a `<-chan int` *cannot* send on it or close it — the compiler
refuses. That makes the ownership story ("the producer closes") checkable
instead of a comment.

## Deadlocks and how to read the panic

When **every** goroutine is blocked, the runtime kills the program:

```text
fatal error: all goroutines are asleep - deadlock!

goroutine 1 [chan receive]:
main.main()
        /home/you/main.go:8 +0x2c
```

How to read it:

- `goroutine 1` is always `main`. Each blocked goroutine gets a stack trace.
- The bracketed state says *how* it's blocked: `[chan receive]`,
  `[chan send]`, `[select]`, or `[sync.WaitGroup.Wait]` for a stuck `Wait`.
- The `file.go:8` line is where it's blocked. Go there and ask: *who was
  supposed to unblock this, and why didn't they?*

The usual suspects: sending on an unbuffered channel with no receiver (or
vice versa), `range` over a channel nobody closes, and `wg.Wait()` with a
missing `Done`. Note the detector only fires when *all* goroutines are stuck —
one goroutine blocked forever while others run is a silent leak, which is why
this module's exercises are strict about closing channels and joining workers.

## Gotchas & idioms

- **`go` + closure evaluates nothing early except arguments.** `go f(x)`
  snapshots `x` now; `go func() { use(x) }()` reads `x` whenever the goroutine
  runs. If `x` mutates in between, that's a race.
- **Operations on a `nil` channel block forever.** A stub that returns `nil`
  instead of `make(chan int)` produces hangs, not errors. (Module 14 shows the
  one place this is useful: disabling a `select` case.)
- **Close from exactly one place.** Many senders → have a coordinator
  (`WaitGroup` + closer goroutine) do it, as in `Merge`.
- **Don't sleep to synchronize.** `time.Sleep` "works" until it doesn't;
  channels and `WaitGroup`s express *happens-before* precisely and are what
  the race detector understands.
- **Run tests with `-race`.** The race detector catches real data races at
  runtime with near-zero false positives. Make it a habit for any concurrent
  code.
- **Channels aren't always the answer.** For a plain shared counter or cache,
  a mutex (module 14) is simpler. Channels shine for handing *ownership* of
  data from one goroutine to another.

## In Advent of Code

Most AoC puzzles run in microseconds single-threaded — reach for goroutines
only when brute force is the intended path: cracking hash prefixes (2015 day
4), searching a huge parameter space, or simulating many independent starting
states. The pattern is always the shape of `SumConcurrent`: split the search
space, one goroutine per chunk, partial results over a channel, combine —
order-independent by design. And occasionally a puzzle *is* concurrency: the
2019 Intcode problems wire multiple computers together in feedback loops, and
the natural Go solution is one goroutine per machine with channels as the
wires, exactly the `Generate`/`Merge`/pipeline shapes you build here.

## Exercises

Work in `channels.go`; each function's doc comment is the full contract.

- **`SumConcurrent(xs []int, workers int) int`** — split `xs` into `workers`
  contiguous chunks, sum each in its own goroutine, send partials over a
  channel, add them up. Hints: `lo, hi := w*n/workers, (w+1)*n/workers` gives a
  balanced split (empty chunks are fine); a buffer of `workers` slots lets
  every worker finish immediately; receiving exactly `workers` partials is
  your join — no `WaitGroup` needed here.
- **`Generate(n int) <-chan int`** — return a channel yielding `1..n`, then
  closed. Make the channel, start a producer goroutine with `defer close(ch)`,
  return the channel immediately. `n < 1` means close without sending.
- **`Merge(a, b <-chan int) <-chan int`** — fan-in: forward everything from
  both inputs to one output, closing the output only after *both* inputs are
  drained. One forwarding goroutine per input, a `sync.WaitGroup`, and a third
  goroutine that does `wg.Wait(); close(out)`.
- **`Collect(ch <-chan int) []int`** — drain a channel into a slice with
  `range`. The sink at the end of every pipeline.
- **`FirstValue(a, b <-chan string) string`** — return the first value to
  arrive on either channel. This is a two-case `select` and nothing else.
- **`DoubleAll(in <-chan int) <-chan int`** — a pipeline stage: receive from
  `in`, send `2*v` on the output, close the output when `in` closes. Same
  skeleton as `Generate`, but ranging over an input instead of counting. When
  everything works, `Collect(DoubleAll(Generate(5)))` is `[2 4 6 8 10]`.

The tests never assert on timing or ordering across goroutines: parallel
results are compared as sums or sorted slices, and a generous select-timeout
failsafe turns any deadlock you write into a clear failure message.

## Check your work

From the repository root:

```sh
go test ./13-goroutines-channels/
go test -race ./13-goroutines-channels/   # always worth it for concurrent code
```

When everything passes — or you want to compare notes — read the reference
implementations in `solution/`, which pass the identical tests:

```sh
go test ./13-goroutines-channels/solution/
```
