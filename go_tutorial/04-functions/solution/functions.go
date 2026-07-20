// Package functions contains the solutions for module 04: multiple
// return values, variadic functions, first-class functions, closures,
// defer, and recursion.
package functions

// MinMax returns the smallest and largest value in xs, in that order.
//
// If xs is empty, it returns (0, 0). A single-element slice returns
// that element twice. xs is never modified.
func MinMax(xs []int) (int, int) {
	if len(xs) == 0 {
		return 0, 0
	}
	lo, hi := xs[0], xs[0]
	for _, x := range xs[1:] {
		// min and max are builtins since Go 1.21.
		lo = min(lo, x)
		hi = max(hi, x)
	}
	return lo, hi
}

// Clamp returns x limited to the inclusive range [lo, hi]: it returns
// lo if x < lo, hi if x > hi, and x otherwise.
//
// Callers must ensure lo <= hi; behavior is unspecified otherwise.
func Clamp(x, lo, hi int) int {
	return min(max(x, lo), hi)
}

// SumAll returns the sum of all its arguments.
//
// Called with no arguments it returns 0. Because it is variadic, it
// accepts both individual values, SumAll(1, 2, 3), and an expanded
// slice, SumAll(xs...).
func SumAll(xs ...int) int {
	total := 0
	for _, x := range xs {
		total += x
	}
	return total
}

// MakeCounter returns a function that returns 1 on its first call,
// 2 on its second, and so on.
//
// Each call to MakeCounter produces an independent counter: advancing
// one must not affect any other.
func MakeCounter() func() int {
	n := 0 // each MakeCounter call gets its own n; the closure keeps it alive
	return func() int {
		n++
		return n
	}
}

// MakeAccumulator returns a function that keeps a running total,
// initialized to start. Each call adds its argument to the total and
// returns the new total.
//
// Each call to MakeAccumulator produces an independent accumulator.
func MakeAccumulator(start int) func(int) int {
	total := start
	return func(delta int) int {
		total += delta
		return total
	}
}

// Compose returns the function h such that h(x) = f(g(x)).
//
// Note the order: g runs first, then f — the same convention as
// mathematical composition f ∘ g. Both f and g must be non-nil.
func Compose(f, g func(int) int) func(int) int {
	return func(x int) int {
		return f(g(x))
	}
}

// MakeFibonacci returns a function fib where fib(n) is the n-th
// Fibonacci number: fib(0) = 0, fib(1) = 1, and
// fib(n) = fib(n-1) + fib(n-2) for n >= 2. For n < 0 it returns 0.
//
// The returned function must memoize: it caches every result it
// computes, so repeated and overlapping calls are fast. fib(50) must
// return practically instantly (naive recursion would take minutes).
func MakeFibonacci() func(int) int {
	cache := map[int]int{} // maps get full coverage in module 06

	// A closure that calls itself must be declared before it is
	// assigned: with :=, the name fib would not yet exist inside
	// the function literal.
	var fib func(int) int
	fib = func(n int) int {
		if n < 0 {
			return 0
		}
		if n < 2 {
			return n
		}
		if v, ok := cache[n]; ok {
			return v
		}
		v := fib(n-1) + fib(n-2)
		cache[n] = v
		return v
	}
	return fib
}

// DeferOrder returns the numbers n down to 1, in that order, as proof
// that deferred calls run last-in-first-out.
//
// Implementation requirement: loop i from 1 to n and DEFER an append
// of each i onto the result slice — do not build the countdown
// directly. Because the deferred appends run in LIFO order after
// return, the result comes out as [n, n-1, ..., 1]. You will need a
// named return value so the deferred closures can modify the result
// after the return statement executes.
//
// For n <= 0 it returns an empty (or nil) slice.
func DeferOrder(n int) (order []int) {
	for i := 1; i <= n; i++ {
		// Since Go 1.22 each iteration has a fresh i, so every
		// deferred closure captures its own value.
		defer func() {
			order = append(order, i)
		}()
	}
	// The deferred appends run after this return, newest first.
	// Only a NAMED result lets them modify what the caller sees.
	return
}
