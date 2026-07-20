# 14. Concurrency Patterns

Module 13 gave you the parts: goroutines, channels, `WaitGroup`, `select`.
This module assembles them into the handful of shapes that cover almost all
concurrent Go you will ever write or read — the **worker pool**, the
**pipeline**, and **fan-out/fan-in** — then crosses the aisle to the other
philosophy: protecting shared memory directly with `sync.Mutex` and
`sync/atomic`. Along the way you'll meet the two tools that keep concurrent
code honest: the **race detector**, which catches unsynchronized memory access
at runtime, and **`context.Context`**, Go's universal mechanism for saying
"stop working" across goroutine boundaries.

The payoff of learning these as *named patterns* is that you stop designing
concurrency from scratch. Real Go code is remarkably uniform: once you can
write a worker pool with a clean shutdown, you can read half the concurrent
code on GitHub.

## What you'll learn

- The worker pool: a jobs channel, a results channel, and a `WaitGroup` that
  closes the output exactly once
- Pipelines: composing stages that each own and close their output channel
- Fan-out (many goroutines reading one channel) and fan-in (merging many
  channels into one)
- Locks the Go way: `sync.Mutex`, `sync.RWMutex`, and the "mutex above the
  fields it guards" convention
- `sync/atomic` for counters and flags too small to deserve a lock
- What a data race *actually* is, and how `go test -race` catches them
- `context.Context` for cancellation and timeouts, `ctx.Done()` /
  `ctx.Err()`, and the ctx-first-parameter convention

## The worker pool

The problem: you have N independent jobs and want at most W of them running
at once — because each job is expensive, or hits a rate-limited API, or
because 10,000 goroutines hammering one resource is worse than 8. The
solution is the single most common concurrency shape in Go:

```go
jobs := make(chan job)        // every worker receives from this
results := make(chan result)  // every worker sends to this

var wg sync.WaitGroup
for range workers {
    wg.Go(func() {            // Go 1.25+: Add(1) + go + defer Done()
        for j := range jobs { // ends when jobs is closed and drained
            results <- process(j)
        }
    })
}

go func() {                   // feeder
    for _, j := range pending {
        jobs <- j
    }
    close(jobs)               // "no more work" — releases the range loops
}()

go func() {                   // closer
    wg.Wait()
    close(results)            // exactly once, after the LAST worker exits
}()

for r := range results {      // the caller collects as results arrive
    use(r)
}
```

Every line placement here is load-bearing:

- **`close(jobs)` after the last send.** Workers consume with
  `for j := range jobs`; without the close, every worker blocks forever once
  the work runs out, and `wg.Wait()` never returns.
- **The closer goroutine.** `results` must be closed so the collection loop
  can end, but no *worker* may close it — the first one to finish would
  strand its colleagues sending on a closed channel (a panic). The rule from
  module 13 generalizes: many senders → one dedicated closer that waits for
  all of them.
- **The feeder goroutine.** If the caller fed `jobs` inline, it couldn't
  simultaneously drain `results`; as soon as every worker was busy and one
  tried to deliver a result, everything would deadlock. Feeding from its own
  goroutine keeps the caller free to collect.
- **Results arrive in completion order, not submission order.** That's the
  price of parallelism. Design the results to be order-independent (sums,
  sets, or values tagged with their input) — the tests for this module's
  `WorkerPool` sort before comparing for exactly this reason.

## Pipelines: composing channel stages

A pipeline breaks a computation into stages connected by channels. Each stage
is a function that receives from an input channel, does one thing, and sends
to an output channel that *it creates, owns, and closes*:

```go
func gen(nums ...int) <-chan int {    // source: makes values from nothing
    out := make(chan int)
    go func() {
        defer close(out)
        for _, n := range nums {
            out <- n
        }
    }()
    return out
}

func square(in <-chan int) <-chan int { // transform: 1-in, 1-out
    out := make(chan int)
    go func() {
        defer close(out)
        for v := range in {
            out <- v * v
        }
    }()
    return out
}
```

Because every stage takes `<-chan int` and returns `<-chan int`, they snap
together like shell pipes, and a final *sink* blocks until the answer is
ready:

```go
total := sum(square(gen(2, 3, 4))) // 4 + 9 + 16 = 29
```

Two properties worth internalizing:

- **The close propagates.** `gen` closes its output → `square`'s range loop
  ends → its deferred close runs → the sink's loop ends. One `close` at the
  source shuts down the whole line.
- **Unbuffered channels give you backpressure for free.** `gen` can only send
  as fast as `square` receives; nothing piles up in memory. A slow consumer
  automatically slows the producers.

## Fan-out and fan-in

When one stage is the bottleneck, run several copies of it reading from the
*same* input channel — that's **fan-out**. It works because a channel with
multiple receivers delivers each value to exactly one of them; two `square`
stages sharing one `gen` never see the same number twice. Merging their
outputs back into a single channel is **fan-in** — module 13's `Merge` is
precisely that, one forwarding goroutine per input plus a `WaitGroup`-guarded
close:

```go
in := gen(nums...)                    // one source
s1, s2, s3 := square(in), square(in), square(in) // fan out: 3 workers
total := sum(Merge3(s1, s2, s3))      // fan in, then sink
```

Fan-out costs you ordering — values re-interleave by completion time — which
is why it pairs so naturally with order-independent sinks like `sum`. If you
squint, a worker pool *is* fan-out/fan-in with the stages hidden inside one
function.

## Shared memory the other way: `sync.Mutex` and `sync.RWMutex`

Channels move data *between* goroutines; sometimes you just have one blob of
state that many goroutines poke at — a counter, a cache, a "seen" set. For
that, idiomatic Go uses a plain mutex, and the idiom is rigid enough to
recite:

```go
type cache struct {
    mu sync.Mutex        // guards m — declared directly above what it protects
    m  map[string]int
}

func (c *cache) set(k string, v int) {
    c.mu.Lock()
    defer c.mu.Unlock()  // unlock survives panics and early returns
    c.m[k] = v
}
```

The rules:

- **The zero value is ready to use.** No constructor needed; `var mu
  sync.Mutex` is an unlocked mutex. (This is why `SafeCounter`'s zero value
  works in the exercise.)
- **Methods take pointer receivers.** Copying a struct that contains a mutex
  copies the lock state — `go vet`'s `copylocks` check flags it.
- **Every access locks, reads included.** A read racing a write is just as
  much a data race as two writes. There are no "safe enough" unlocked reads.
- **Go mutexes are not reentrant.** A method that holds the lock must not
  call another method that takes it — that's a self-deadlock. The usual fix
  is unexported unlocked helpers called by exported locking wrappers.

`sync.RWMutex` splits the lock in two: any number of readers may hold
`RLock()` simultaneously, while `Lock()` (writers) is exclusive. Use it when
reads vastly outnumber writes *and* profiling shows contention; for anything
else, a plain `Mutex` is simpler and often faster.

## `sync/atomic`: counters without locks

For a lone integer or boolean, even a mutex is ceremony. The `sync/atomic`
types perform single operations that are indivisible at the hardware level:

```go
var hits atomic.Int64
hits.Add(1)          // safe from any number of goroutines
n := hits.Load()     // safe to read concurrently

var found atomic.Bool
found.Store(true)    // e.g. "some worker found the answer"
```

The boundary is precise: atomics protect **one value, one operation at a
time**. The moment two fields must stay consistent with each other — or you
need check-then-act like "increment only if under the limit" — you need a
mutex; there is no atomic way to hold two values still at once. This module's
tests use `atomic.Int64` to count `fn` calls made from many workers — a plain
`int` there would be a data race in the test itself.

## What a data race actually is — and `go test -race`

A **data race** is: two goroutines access the same memory location
concurrently, at least one access is a write, and nothing (channel operation,
mutex, atomic, `WaitGroup`) forces an order between them. This innocent line
is the canonical example:

```go
counter := 0
var wg sync.WaitGroup
for range 1000 {
    wg.Go(func() { counter++ }) // DATA RACE
}
wg.Wait()
fmt.Println(counter) // usually less than 1000 — and that's the GOOD outcome
```

`counter++` is three steps — load, add, store — and two goroutines
interleaving them lose updates. But the deeper problem is that a racy program
has **no defined meaning at all**: the compiler and CPU are allowed to
reorder, cache, and duplicate memory operations on the assumption that no
race exists. Torn values, impossible states, code that "worked for months"
failing on the day it matters — a race is not a bug with a small blast
radius. "It usually passes" is not evidence of correctness.

The race detector instruments every memory access and reports races **that
actually occur during the run**, with near-zero false positives:

```sh
go test -race ./14-concurrency-patterns/
go run -race main.go
```

A report names both accesses and both goroutine stacks:

```text
WARNING: DATA RACE
Write at 0x00c00001c090 by goroutine 8:
  patterns.(*SafeCounter).Inc()
      counter.go:31 +0x44
Previous read at 0x00c00001c090 by goroutine 7:
  patterns.(*SafeCounter).Value()
      counter.go:42 +0x38
```

Two caveats: it only sees code paths that execute (so tests should hammer
concurrent code from many goroutines, as this module's do), and it costs
roughly 2–20× in speed — fine for tests, not for production builds. Make
`-race` a reflex for any package that says `go` anywhere.

## `context.Context`: cancellation and timeouts

A goroutine cannot be killed from outside — and that's deliberate; it could
be holding locks or half-written state. It can only be *asked* to stop, and
`context.Context` is the standard way to ask. A context is an immutable
value, derived from a parent, that becomes "done" when it's canceled or its
deadline passes:

```go
ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
defer cancel() // ALWAYS — releases the timer; go vet's lostcancel check
               // flags a forgotten cancel

ctx2, cancel2 := context.WithCancel(ctx) // cancellation flows parent → child
```

The consuming side watches `ctx.Done()`, a channel that closes when the
context is done — and a closed channel is exactly the "broadcast to everyone"
primitive from module 13. After it closes, `ctx.Err()` says why:
`context.Canceled` after a `cancel()`, `context.DeadlineExceeded` after a
timeout — test with `errors.Is`. The consumer shape is a loop around a
two-case `select`:

```go
func consume(ctx context.Context, in <-chan job) error {
    for {
        select {
        case <-ctx.Done():
            return ctx.Err() // asked to stop
        case j, ok := <-in:
            if !ok {
                return nil   // input exhausted: normal completion
            }
            handle(j)
        }
    }
}
```

That loop-around-select is THE pattern for stoppable channel consumers —
`CancelableSum` in this module is its minimal form.

The conventions around `context` are unusually strict, and Go code everywhere
follows them:

- **First parameter, named `ctx`.** `func Fetch(ctx context.Context, url
  string) error`. Not second, not in a struct field, not optional.
- **Never pass `nil`.** At the top of the program, where no context exists
  yet, create one with `context.Background()`.
- **Pass it down, don't store it.** A context describes one call tree; a
  function that receives `ctx` hands the same (or a derived) context to
  everything it calls.

## Gotchas & idioms

- **Timeout selects leak goroutines unless the result channel is buffered.**
  In the `DoWithTimeout` shape, if the deadline wins and `done` is
  unbuffered, the work goroutine blocks forever on its send. `make(chan int,
  1)` lets it deliver into the void and exit. Cheap insurance, always worth
  it.
- **`select` ties are random.** If a value and a cancellation are both ready,
  either case may win — don't write code (or tests) that depends on
  cancellation having priority. This module's tests are built so only one
  case can ever be ready.
- **Disable a `select` case with a `nil` channel.** Receiving from a `nil`
  channel blocks forever, so setting a channel variable to `nil` makes its
  case permanently not-ready — the classic way to keep selecting from the
  *other* inputs after one closes:

  ```go
  for a != nil || b != nil {
      select {
      case v, ok := <-a:
          if !ok { a = nil; continue } // a is done; stop watching it
          use(v)
      case v, ok := <-b:
          if !ok { b = nil; continue }
          use(v)
      }
  }
  ```

- **Don't hold a lock while doing slow work.** Lock, touch the shared data,
  unlock. Holding a mutex across I/O or channel operations serializes
  everything behind it (and holding it across a channel send can deadlock).
- **A `RWMutex` is an optimization, not a default.** Start with `Mutex`;
  reach for read/write splitting only when many concurrent readers are
  measured to contend.
- **`defer cancel()`, even when the work finishes early.** Cancel is
  idempotent and releases the deadline timer immediately; without it the
  timer lingers until it fires.
- **Channels or mutexes?** Rule of thumb: use a channel to transfer
  *ownership* of data or coordinate *events*; use a mutex to guard *state*
  that stays put. Forcing either job onto the other tool is how baroque
  concurrency bugs are born.

## In Advent of Code

Most puzzles don't need any of this — but the ones that do fit these patterns
exactly. Brute-force searches (the MD5-mining puzzles of 2015 day 4 and 2016
days 5/14, or "try every starting configuration" problems) are worker pools:
candidates go down the jobs channel, hits come back on results, and because
results are order-independent you just aggregate them. A shared "best answer
so far" or a memoization map updated by several workers is `SafeCounter`'s
mutex idiom verbatim. And `context` gives brute force an early exit: derive a
`WithCancel` context, have every worker check `ctx.Done()` between
candidates, and call `cancel()` the moment one finds the answer — the close
of `Done()` broadcasts "stop" to the whole pool, which is `CancelableSum`'s
loop wearing a different hat.

## Exercises

Work through `pool.go`, `counter.go`, `pipeline.go`, and `ctx.go`; each doc
comment is the full contract.

- **`WorkerPool(jobs []int, workers int, fn func(int) int) []int`**
  (`pool.go`) — the classic pool: workers range over a jobs channel, send
  `fn(j)` to a results channel, and a `wg.Wait()`-then-close goroutine ends
  the collection loop. Results may arrive in any order (the tests sort). Mind
  the hints in the doc comment — each one is a deadlock you're stepping over.
- **`SafeCounter`** (`counter.go`) — `Inc(key)` and `Value(key)` on a
  mutex-guarded map. The zero value must work, so `Inc` lazily allocates the
  map inside the lock. The tests hammer one counter from 8 goroutines and mix
  readers with writers; run them with `-race`.
- **`Gen(nums ...int) <-chan int`, `Square(in <-chan int) <-chan int`,
  `Sum(in <-chan int) int`** (`pipeline.go`) — a three-stage pipeline. `Gen`
  and `Square` each start a goroutine, send, and `defer close` their output;
  `Sum` is the blocking sink. When they compose, `Sum(Square(Gen(1, 2, 3)))`
  is 14.
- **`DoWithTimeout(timeout time.Duration, work func(ctx context.Context) int)
  (int, error)`** (`ctx.go`) — derive a `WithTimeout` context (defer the
  cancel!), run `work(ctx)` in a goroutine that sends into a **capacity-1**
  channel, and `select` between the result and `ctx.Done()`. On timeout,
  return `(0, ctx.Err())` — the tests check `errors.Is(err,
  context.DeadlineExceeded)`.
- **`CancelableSum(ctx context.Context, nums <-chan int) (int, error)`**
  (`ctx.go`) — the loop-around-select consumer: accumulate values until
  `nums` closes (return the total and `nil`) or `ctx` is done (return the
  partial sum and `ctx.Err()`).

The tests never rely on timing or cross-goroutine ordering: parallel results
are sorted before comparison, cancellations are arranged so only one `select`
case can fire, and a generous 2-second failsafe converts any deadlock you
write into a readable failure instead of a hung test run.

## Check your work

From the repository root:

```sh
go test ./14-concurrency-patterns/
go test -race ./14-concurrency-patterns/   # non-negotiable for this module
```

When everything passes — or you want to compare notes — read the reference
implementations in `solution/`, which pass the identical tests:

```sh
go test -race ./14-concurrency-patterns/solution/
```
