# 04. Functions

You already know what a function is. What you don't know yet is how Go
functions differ from the ones you're used to: they return multiple
values as a matter of course, they are ordinary values you can store
and pass around, they close over variables (not copies), and Go has a
scheduling statement — `defer` — that most languages don't. Getting
comfortable with these is the single biggest step toward reading real
Go code, because the standard library uses all of them constantly.

A note on scope: a couple of exercises use `[]int` slices and one uses
a `map` for its cache. Slices get their full treatment in module 05
and maps in module 06 — for now, treat a slice as "a dynamic array you
can `range` over and `append` to" and a map as "a hash table". The
few operations you need are shown below.

## What you'll learn

- Multiple return values and why Go APIs are shaped `(result, error)`
- Named return values — and why you should usually avoid naked returns
- Variadic functions and expanding a slice with `xs...`
- Functions as first-class values: storing, passing, and returning them
- Closures, and the fact that they capture *variables*, not snapshots
- `defer`: LIFO order, and arguments evaluated at defer time
- Recursion, including the declare-then-assign trick for recursive closures

## Multiple return values

Most languages make you choose: return one value, or invent a tuple,
out-parameter, or exception. Go bakes multiple returns into the
language:

```go
func divmod(a, b int) (int, int) {
	return a / b, a % b
}

q, r := divmod(17, 5) // q = 3, r = 2
```

This is not a tuple type — there is no value you can bind to a single
variable. You must receive each result (or discard it with `_`):

```go
q, _ := divmod(17, 5) // keep the quotient, drop the remainder
```

The idiom matters because two signature shapes dominate all of Go:

```go
func Atoi(s string) (int, error)      // result + error (module 11)
func lookup(k string) (string, bool)  // result + "did it exist?"
```

Instead of throwing exceptions or returning sentinel values like `-1`,
Go functions return the answer *and* a second value saying whether the
answer is any good. The compiler forces you to receive both, so you
can't accidentally ignore failure. You'll meet `error` properly in
module 11; the shape is worth internalizing now.

## Named return values

Result parameters can be given names. They then act like variables
declared at the top of the function, initialized to their zero values,
and a bare `return` (a "naked return") returns their current values:

```go
func minMax(xs []int) (lo, hi int) {
	lo, hi = xs[0], xs[0]
	for _, x := range xs[1:] {
		lo = min(lo, x)
		hi = max(hi, x)
	}
	return // returns lo, hi
}
```

Two legitimate uses:

1. **Documentation.** `func Cut(s, sep string) (before, after string, found bool)`
   is far clearer than three unnamed `string, string, bool` results.
   You can name results purely for the doc and still write explicit
   `return before, after, found`.
2. **Letting `defer` modify the result.** A deferred function runs
   *after* the `return` statement has assigned the result values. If
   the results are named, the deferred function can still change them
   — this is the only way to alter a return value on the way out, and
   it's exactly what the `DeferOrder` exercise makes you do.

When to avoid them: naked returns in anything longer than a few lines.
The reader has to scroll up to remember what's being returned, and a
stray early assignment becomes an invisible bug. Idiomatic Go names
results for documentation or defer, but still returns explicitly.

## Variadic functions

A final parameter of type `...T` accepts any number of arguments;
inside the function it *is* a `[]T` slice:

```go
func sum(xs ...int) int {
	total := 0
	for _, x := range xs {
		total += x
	}
	return total
}

sum()            // 0 — xs is an empty (nil) slice
sum(1, 2, 3)     // 6
```

If your values are already in a slice, expand it with `...`:

```go
nums := []int{4, 8, 15, 16, 23, 42}
sum(nums...) // passes the slice as the variadic arguments
```

Two rules worth knowing:

- You cannot mix the forms: `sum(1, nums...)` does not compile. Either
  pass individual values or expand exactly one slice.
- `xs...` does not copy the slice — the function sees the same backing
  array. (What that means precisely is module 05's topic.)

The most famous variadic functions in Go are `fmt.Println(a ...any)`
and `append(s, elems...)` — you've been using this feature all along.

## Functions as first-class values

A function is a value with a function type. You can assign it, pass
it, return it, and put it in slices and maps:

```go
double := func(x int) int { return x * 2 } // function literal
apply := func(f func(int) int, x int) int { return f(x) }

apply(double, 21) // 42
```

There's no special lambda syntax and no capture list — `func(...) ...`
literals are the only form, and they may reference anything in scope.
Named top-level functions are values too: `f := strings.ToUpper` works.

Function types can get noisy; a named type tames them (that's a type
*definition* — a true alias would be `type IntFunc = func(int) int`):

```go
type IntFunc func(int) int

func compose(f, g IntFunc) IntFunc {
	return func(x int) int { return f(g(x)) }
}
```

Two limitations compared to what you may be used to: functions are not
comparable (you can only compare a function value to `nil`), and Go has
no overloading and no default arguments — two behaviors means two
function names.

## Closures capture variables

A function literal that references a variable from its enclosing scope
*closes over* that variable. Crucially, it captures the variable
itself, not a copy of its value:

```go
func makeCounter() func() int {
	n := 0
	return func() int {
		n++ // still refers to THIS n, even after makeCounter returned
		return n
	}
}

c := makeCounter()
c() // 1
c() // 2
d := makeCounter()
d() // 1 — a separate n
```

In a language with stack-only locals this would be a dangling
reference. Go's compiler notices that `n` outlives `makeCounter` and
moves it to the heap automatically ("escape analysis") — you never
think about it. Each call to `makeCounter` creates a fresh `n`, so
each returned closure has private, persistent state. This is the
lightweight end of object-orientation: state plus one behavior,
no struct required.

Capture-by-variable cuts both ways: if two closures capture the same
variable, they see each other's writes. That's what makes the counter
work, and also what makes the loop-variable gotcha below possible.

## defer

`defer f(args)` schedules the call `f(args)` to run when the
surrounding *function* returns — whether via `return`, falling off the
end, or a panic. Its main job is cleanup that stays next to setup:

```go
f, err := os.Open("input.txt")
if err != nil {
	return err
}
defer f.Close() // guaranteed to run, no matter which return fires
```

Three rules define its semantics:

1. **LIFO order.** Multiple defers run newest-first, like unwinding a
   stack. Acquire A then B; release B then A.

	```go
	func order() {
		defer fmt.Println("first deferred, runs last")
		defer fmt.Println("second deferred, runs first")
	}
	```

2. **Arguments are evaluated at `defer` time**, not at run time. Only
   the *call* is delayed:

	```go
	i := 1
	defer fmt.Println(i) // prints 1, even though...
	i = 2                // ...i changes afterward
	```

	To evaluate late, defer a closure — it captures the variable, so
	it sees the final value: `defer func() { fmt.Println(i) }()`
	prints 2.

3. **Deferred closures run after `return` assigns the results**, so
   they can modify *named* results (see above) — the standard trick
   for turning a panic into an error, or for post-processing a result.

One trap: defers run at function exit, not block exit. A `defer`
inside a loop piles up one pending call per iteration and none of them
run until the whole function returns — usually a bug when the resource
is a file handle, though the `DeferOrder` exercise uses the pile-up
deliberately.

## Recursion

Recursion works exactly as you expect, with no special syntax and no
practical depth limit to worry about for AoC-sized inputs (goroutine
stacks grow dynamically). The one Go-specific wrinkle: a *closure*
that calls itself can't be declared with `:=`, because the name
doesn't exist yet inside its own body. Declare first, then assign:

```go
var fib func(int) int
fib = func(n int) int {
	if n < 2 {
		return n
	}
	return fib(n-1) + fib(n-2)
}
```

Naive `fib` recomputes the same subproblems exponentially many times.
The classic fix is **memoization**: keep a cache of computed answers
inside the closure. The two map operations you need (full story in
module 06):

```go
cache := map[int]int{}      // empty hash table: int -> int
v, ok := cache[n]           // lookup; ok reports whether n was present
cache[n] = v                // store
```

Because the cache lives in the closure, it persists across calls and
is invisible to callers — the memoized function has the same signature
as the naive one, it's just fast.

## Gotchas & idioms

- **`defer` evaluates arguments immediately.** `defer wg.Done()`,
  `defer f.Close()` — fine. `defer fmt.Println(result)` — prints the
  value `result` had at the defer statement. Wrap in a closure to
  evaluate late.
- **Loop variables and closures.** Since Go 1.22 (this course uses
  1.26), each `for` iteration gets a *fresh* loop variable, so closures
  created in a loop capture distinct values. In pre-1.22 code you'll
  see the workaround `i := i` inside loops all over the internet — you
  don't need it anymore, but recognize it.
- **Naked returns don't scale.** Fine in a five-line function whose
  named results are documentation; a readability hazard beyond that.
  Name results, return explicitly.
- **`sum(1, xs...)` doesn't compile.** Slice expansion must supply
  *all* the variadic arguments.
- **Functions compare only to `nil`.** `f == g` is a compile error;
  `if f != nil` is the only comparison you get. Calling a nil function
  value panics.
- **No overloading, no default arguments.** Idiomatic Go writes
  `ParseFile(name)` and `ParseFileStrict(name)` rather than flags with
  defaults.
- **`min` and `max` are builtins** (since Go 1.21) for any ordered
  type — no need to hand-roll two-value helpers, though avoid naming
  your own variables `min`/`max` where you also need the builtin.

## In Advent of Code

Almost every AoC solution is a pipeline of small functions, and this
module is its toolbox. Part 1 and part 2 usually share 90% of their
logic — write `solve(input string, part2 bool) int`, or pass the
varying step in as a `func` parameter. `MinMax` over parsed numbers is
day-one material (literally: AoC 2020 day 1, 2021 day 7). Memoized
recursion is *the* technique for the yearly "count the ways" puzzle —
counting adapter arrangements (2020 day 10) or possible towel designs
(2024 day 19) is intractable naive and instant memoized. And once you
read files (module 15), `defer f.Close()` right after every open will
be muscle memory.

## Exercises

Implement the stubs in `functions.go`. The tests define the contract
precisely; read them.

- **`MinMax(xs []int) (int, int)`** — smallest and largest element,
  `(0, 0)` for an empty slice. One pass, track both. Hint: seed both
  results with `xs[0]`, then range over `xs[1:]`.
- **`Clamp(x, lo, hi int) int`** — limit `x` to `[lo, hi]`. Can you
  write it without an `if`? (Think builtins.)
- **`SumAll(xs ...int) int`** — sum of all arguments; zero arguments
  sum to 0. The tests call it both with literal arguments and with a
  slice expanded via `...`.
- **`MakeCounter() func() int`** — returns a closure yielding 1, 2, 3,
  … Independent counters must not share state: where you declare the
  count variable decides this.
- **`MakeAccumulator(start int) func(int) int`** — like `MakeCounter`,
  but the running total starts at `start` and each call adds its
  argument and returns the new total.
- **`Compose(f, g func(int) int) func(int) int`** — return `h` with
  `h(x) = f(g(x))`. Mind the order: `g` first. The whole body is a
  single `return func(...)`.
- **`MakeFibonacci() func(int) int`** — return a *memoized* Fibonacci
  function backed by a cache that lives in the closure. You'll need
  the declare-then-assign trick so the closure can recurse, and the
  map mini-primer above. The `fib(50)` test will hang for minutes if
  your cache isn't actually being hit.
- **`DeferOrder(n int) []int`** — return `[n, n-1, ..., 1]`, but you
  must build it by *deferring* an append of each `i` in a 1-to-n loop
  and letting LIFO execution produce the countdown. Requires a named
  return value — a plain `[]int` result is already copied out by the
  time your defers run, and the test will see `nil`.

## Check your work

Run the module's tests from the repo root:

```sh
go test ./04-functions/
```

Fresh stubs compile but fail every test; make them pass one exercise
at a time (`go test ./04-functions/ -run TestMinMax` narrows the run).
When everything is green — or when you're stuck — compare your code
with `solution/`, which passes the byte-identical test file:

```sh
go test ./04-functions/solution/
```
