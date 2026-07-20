# 12. Generics

For its first twelve years Go had no generics at all, and the community wrote
`MapInts`, `MapStrings`, `MaxInt`, `MaxFloat64`… or reached for `interface{}`
and type assertions. Since Go 1.18, functions and types can take **type
parameters**, and by now (Go 1.26) generics are settled, idiomatic territory:
the standard library's `slices`, `maps`, and `cmp` packages are built on them.
You already felt the pain they solve — in module 05 you wrote `Filter` and
`MapInts` that only worked on `[]int`. In this module you write the real
ones, once, for every type.

Go's take on generics is deliberately modest compared to C++ templates or
Rust traits: no specialization, no operator overloading, no metaprogramming.
A type parameter plus a constraint that says what you're allowed to do with
it — that's the whole feature. The flip side is a short learning curve and a
strong idiom: **use generics when you'd otherwise copy-paste code that's
identical except for types; otherwise don't.**

## What you'll learn

- Declaring type parameters on functions: `func F[T any](x T)`
- The built-in constraints `any` and `comparable`, and `cmp.Ordered`
- Writing custom constraints with type sets: `~int | ~float64`
- Type inference — why call sites almost never mention the type
- Generic types like `Stack[T]`, and methods on them
- Getting a zero value of `T` with `var zero T`
- When *not* to use generics

## Type parameters on functions

A type parameter list goes in square brackets between the function name and
the ordinary parameters. Each parameter has a **constraint** stating which
types are allowed; `any` (an alias for `interface{}`) allows all of them:

```go
func First[T any](xs []T) T {
	return xs[0]
}

n := First([]int{1, 2, 3})        // n is an int
s := First([]string{"a", "b"})    // s is a string
```

Inside `First`, the compiler knows nothing about `T` beyond its constraint.
With `any`, that means you can declare variables of type `T`, assign them,
pass them around — and that's it. No `+`, no `==`, no method calls. If you
try, the compiler stops you at the *definition*, not at the call site. This
is the big contrast with C++ templates: a generic Go function must type-check
against its constraint once and for all, so misuse errors are local and
readable.

## Constraints

A constraint is an interface. The interface's *type set* — every type that
satisfies it — is what a type argument must belong to.

### `any` and `comparable`

- `any` permits everything, and therefore lets you *do* almost nothing.
  Ideal for container code that only stores and returns values (`First`,
  `Map`, `Stack`).
- `comparable` is a built-in constraint permitting every type that supports
  `==` and `!=`: numbers, strings, booleans, pointers, arrays and structs of
  comparable types. Slices, maps, and functions are *not* comparable. It's
  exactly what you need to write `Contains` — or to use `T` as a map key,
  which is why map keys and `comparable` are the same club:

```go
func IndexOf[T comparable](xs []T, target T) int {
	for i, x := range xs {
		if x == target {
			return i
		}
	}
	return -1
}
```

### `cmp.Ordered`

`==` still isn't `<`. For ordering you want `cmp.Ordered` from the standard
`cmp` package: all integer and float types plus `string`. With it you can
use `<`, `<=`, `>`, `>=`:

```go
import "cmp"

func Clamp[T cmp.Ordered](x, lo, hi T) T {
	if x < lo {
		return lo
	}
	if x > hi {
		return hi
	}
	return x
}
```

(`cmp` also provides ready-made `cmp.Compare` and `cmp.Less` — worth knowing
before you hand-roll comparisons.)

### Custom constraints with type sets

You can write your own constraint interface by listing types, separated by
`|`. The `~` (tilde) before a type means "any type whose **underlying type**
is this" — without it, only the exact type qualifies:

```go
type Number interface {
	~int | ~int64 | ~float64
}

func Double[T Number](x T) T {
	return x * 2 // legal: every type in the set supports *
}
```

The tilde matters more than it looks. In Go you constantly define named
types — `type Fuel int`, `type Distance float64` — and without `~int`,
`Double[Fuel]` would be rejected even though `Fuel` *is* an int underneath.
Rule of thumb: **always write the tilde** unless you have a specific reason
to exclude named types.

An operation is available inside the generic function only if *every* type
in the set supports it: `%` would be fine for `~int | ~int64` but is a
compile error the moment `~float64` joins the union.

One more quirk: an interface containing a type union is *only* a constraint.
You can write `[T Number]`, but you cannot declare `var x Number` — unions
disqualify an interface from being used as an ordinary value type.

## Type inference at call sites

You *can* pass type arguments explicitly — `MaxOf[int](3, 5)` — but you
almost never do. The compiler infers type arguments from the ordinary
arguments:

```go
MaxOf(3, 5)            // T = int
MaxOf(2.5, 1.0)        // T = float64
MaxOf("abc", "abd")    // T = string
Map(nums, strconv.Itoa) // T = int, U = string, both from the arguments
```

Inference only looks at the arguments, never at what you assign the result
to — Go has no return-type-driven inference. So the one place you'll write
explicit type arguments is when there's nothing to infer from:

```go
var s string = First[string](nil) // nil says nothing about T
```

If a call looks ambiguous to you, it's fine to spell the types out; the
compiler treats explicit and inferred identically.

## Generic types: `Stack[T]`

Type parameters work on type declarations too. Here's the shape of this
module's stack exercise:

```go
type Stack[T any] struct {
	items []T
}

func (s *Stack[T]) Push(v T) {
	s.items = append(s.items, v)
}
```

Note the method receiver: `*Stack[T]` — methods on a generic type repeat the
type parameter. Using one looks like using any other struct; you only name
the element type when declaring a variable, because there's no argument to
infer it from:

```go
var s Stack[rune]      // zero value: an empty, ready-to-use stack
s.Push('(')
top, ok := s.Pop()     // top is a rune
```

Instantiation (`Stack[rune]`, `Stack[string]`) produces genuinely distinct
types — you can't push a `string` onto a `Stack[rune]`, which is precisely
the point: all the type safety of the hand-written version, none of the
copy-paste.

One limitation to know: **methods cannot introduce their own type
parameters**. `func (s *Stack[T]) MapTo[U any](...)` does not compile; such
operations must be top-level functions instead. That's why this module's
`Map` is a function, not a method.

## Zero values inside generic code

Inside a generic function you sometimes need "the empty value of `T`" — for
`Pop` on an empty stack, say. You can't write `return 0` (T might be a
string) or `return nil` (T might be an int). The idiom is:

```go
func (s *Stack[T]) Pop() (T, bool) {
	var zero T // 0, "", nil, empty struct... whatever T's zero value is
	if len(s.items) == 0 {
		return zero, false
	}
	// ...
}
```

`var zero T` gives the zero value of whatever `T` was instantiated with.
You'll also see the equivalent one-liner `*new(T)` in the wild; `var zero T`
is the readable choice.

## When NOT to use generics

Go's own advice: write the concrete code first, and reach for type
parameters only when you find yourself writing the same body multiple times.
In particular:

- **If the code calls methods on the values, use an interface.** A function
  that needs `Area()` should take a `Shape` interface (module 10), not
  `[T Shape]`. Generics add nothing there but noise — the interface version
  is shorter and equally type-safe.
- **If the body differs per type, generics can't help.** Type parameters
  share one body; the moment you want per-type behavior you want interfaces
  or a type switch.
- **If it's used once with one type, plain code reads better.** A generic
  helper with one instantiation is abstraction without payoff.
- **Check the stdlib first.** `slices.Contains`, `slices.Max`, `slices.Sort`,
  `slices.Index`, `maps.Keys` already exist — the exercises below have you
  build a few of them by hand exactly once, so you understand what you're
  calling forever after.

A decent smell test: if the type parameter appears only once in the
signature (say, only as a parameter, never in the result or a second
parameter), an interface probably expresses it better.

## Gotchas & idioms

- **`any` lets you store, `comparable` lets you `==`, `cmp.Ordered` lets you
  `<`.** Pick the weakest constraint that supports the operations in the
  body — callers get maximum flexibility.
- **Forgetting `~` is the classic constraint bug.** `int | float64` rejects
  `type Fuel int`; `~int | ~float64` accepts it. Write the tilde.
- **No return-type inference.** `Reduce(xs, 0, f)` infers the accumulator
  type from `0` (an `int`) — if you wanted `int64`, pass `int64(0)` or
  instantiate explicitly.
- **Constraint interfaces with unions aren't types.** `var n Number` is a
  compile error; `Number` exists only to constrain.
- **Methods can't add type parameters** — generic operations over a generic
  type's contents are top-level functions.
- **Don't over-abstract.** The stdlib waited a year after generics shipped
  before adding `slices`/`maps`, on purpose. If plain code is clear, keep it.

## In Advent of Code

Generics are why your AoC toolkit finally becomes a *toolkit*. Every year
you re-need the same helpers: `Contains` on days when the input is strings
and days when it's ints; `Keys` to iterate a `map[Point]bool` grid in a
stable order (sort the result!); `Map`/`Filter`/`Reduce` to turn parsed
lines into answers; a `Stack` for bracket matching, crate-stacking puzzles
(2022 day 5 is literally `Stack[byte]`), and iterative DFS over grids.
Write them once in a shared package and every subsequent day starts faster.
And when the stdlib already has it (`slices.Max` for "largest calorie
count"), now you know why its signature says `[S ~[]E, E cmp.Ordered]` —
you can read that fluently.

## Exercises

In `generics.go`:

- **`MaxOf[T cmp.Ordered](a, b T) T`** — the larger of two values; `a` if
  they're equal. Hint: one comparison. Compare against `slices.Max` and the
  builtin `max` when you're done — this one is for the muscle memory.
- **`Map[T, U any](xs []T, f func(T) U) []U`** — the real version of module
  05's `MapInts`. Same contract: new slice, same length, input untouched.
  Hint: your module 05 body is already correct — only the signature changes.
- **`Filter[T any](xs []T, keep func(T) bool) []T`** — generalizes module
  05's `Filter`. Return `nil` when nothing is kept; starting from
  `var out []T` gives you that for free.
- **`Reduce[T, U any](xs []T, initial U, f func(U, T) U) U`** — fold `xs`
  into one value: start from `initial`, apply `f(acc, x)` left to right.
  Note `T` and `U` are different — summing `[]string` lengths into an `int`
  must work.
- **`Keys[K comparable, V any](m map[K]V) []K`** — the keys of `m` as a
  slice, any order. Hint: `make` with capacity `len(m)`, then `range`.
  (Why `comparable`? Map keys always are — the constraint just records it.)
- **`Contains[T comparable](xs []T, target T) bool`** — linear search with
  `==`. This is `slices.Contains`; build it once yourself.
- **`SumNumbers[T Number](xs []T) T`** — sum using the provided `Number`
  constraint (`~int | ~int64 | ~float64`). Hint: `var sum T` starts at
  zero for every type in the set; `+=` is legal because all three types
  support `+`. The tests sum a named `type fuel int` to prove the `~` works.

In `stack.go`:

- **`Stack[T]`** with **`Push`**, **`Pop`**, and **`Len`** — `Push` appends
  to the top; `Pop` returns `(top, true)` and removes it, or
  `(zero, false)` on an empty stack; `Len` reports the current count.
  Hints: the top is the *end* of the slice — `s.items[len(s.items)-1]`,
  then reslice with `s.items[:len(s.items)-1]`. Pointer receivers
  throughout (module 09: the methods modify the struct). And `var zero T`
  for the empty case.

## Check your work

From the repo root:

```sh
go test ./12-generics/          # your implementations
go test -v ./12-generics/       # see every subtest
go test ./12-generics/solution/ # reference solutions (should pass)
```

When you're green, read `solution/` side-by-side with your code. Two details
worth stealing: `Filter` gets its nil-when-empty behavior from starting with
a nil slice, and `Pop` zeroes the vacated slot before reslicing so a popped
pointer value can't hide from the garbage collector in the backing array.
