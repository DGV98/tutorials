# 08. Pointers

Everything you have passed to a function so far — ints, strings, arrays — was
copied on the way in. That's Go's default: **value semantics**. Pointers are
the escape hatch: instead of handing a function a copy, you hand it the
*address* of your variable so it can reach back and change the original.
If you come from C or C++, relax — Go pointers are the tame version: no
arithmetic, no casts, no dangling pointers, and the garbage collector owns
the memory. If you come from Python, Java, or JavaScript, pointers make
*explicit* a distinction your old language made silently: which values are
copied, and which are shared.

## What you'll learn

- `&x` takes an address, `*p` follows one (and there is no `->`)
- The pointer zero value is `nil`, and dereferencing `nil` panics — guard it
- Go pointers have **no arithmetic** — and why that's a feature
- The two honest reasons to use a pointer: mutation and avoiding big copies
- Value semantics vs pointer semantics, and how to choose
- `new(T)` — what it does and why you'll rarely write it
- Why slices and maps almost never need pointers (they already share)

## A pointer is an address: `&` and `*`

A pointer of type `*int` holds the memory address of an `int`. Two operators
do all the work:

```go
x := 42
p := &x         // & takes the address: p has type *int, "pointer to int"

fmt.Println(p)  // something like 0xc000012345 — the address itself
fmt.Println(*p) // 42 — * dereferences: "the value at p"

*p = 99         // write through the pointer...
fmt.Println(x)  // 99 — ...and the original variable changes
```

Read `*p` as "the thing p points at." The same `*` appears in two roles:
in a **type** (`*int` = pointer-to-int) and in an **expression** (`*p` =
dereference p). Unlike C there is no `->`; you'll see in the next module
that Go automatically dereferences pointers when accessing fields, so `*` in
expressions stays rare.

One habit to unlearn from C: taking the address of a local variable and
returning it is completely safe in Go.

```go
func makeCounter() *int {
	count := 0
	return &count // fine: the compiler moves count to the heap
}
```

The compiler's *escape analysis* notices that `count` outlives the function
and allocates it on the heap; the garbage collector frees it when nothing
points to it anymore. You never think about stack vs heap — you just take
addresses when you need them.

## The zero value is `nil` — and dereferencing it panics

Like slices and maps, a declared-but-unassigned pointer is `nil`:

```go
var p *int          // nil — points at nothing
fmt.Println(p == nil) // true

fmt.Println(*p)     // PANIC: runtime error: invalid memory address
                    //        or nil pointer dereference
```

This is Go's version of the NullPointerException, and the guard is the same
everywhere:

```go
if p != nil {
	fmt.Println(*p)
}
```

Any function that accepts a pointer must decide — and document — what it
does with `nil`: treat it as a no-op, return a comma-ok `false`, or declare
it a caller bug and let it panic. The exercises in this module practice the
first two; the standard library mostly does the third for arguments that
must never be nil.

## No pointer arithmetic

In C, `p + 1` gives you the next element. In Go, it's a compile error:

```go
p := &x
p++      // compile error: invalid operation
p = p + 1 // compile error
```

A Go pointer either points at a real, live object or is `nil` — you cannot
fabricate an address by arithmetic, walk off the end of an array, or alias
memory behind the type system's back. This is a large part of why Go has no
buffer-overflow class of bugs and why the garbage collector can be trusted:
every pointer is honest. When you want "the next element," you index a
slice; the bounds check comes free.

The only comparison operators pointers support are `==` and `!=`, which
compare *addresses*, not pointed-at values:

```go
a, b := 1, 1
fmt.Println(&a == &b)   // false — different variables
q := &a
fmt.Println(q == &a)    // true — same variable
```

## Why pointers? Reason 1: letting a function mutate its argument

Arguments are copies. This function is a no-op:

```go
func brokenIncrement(n int) {
	n++ // increments the copy; the caller sees nothing
}
```

Pass an address instead and the function can modify the caller's variable:

```go
func increment(n *int) {
	*n++
}

count := 10
increment(&count)
fmt.Println(count) // 11
```

The call site is honest about it, too: `increment(&count)` — that `&`
visibly warns you "this call may change `count`." In languages where
everything is silently a reference, you can't see mutation at the call
site; in Go you can.

## Why pointers? Reason 2: avoiding large copies

Copying an `int` is free. Copying a megabyte-sized value into every function
call is not:

```go
var big [1_000_000]int // arrays are values — this is 8 MB

func sumByValue(a [1_000_000]int) int { // copies 8 MB per call
	total := 0
	for _, v := range a {
		total += v
	}
	return total
}

func sumByPointer(a *[1_000_000]int) int { // copies 8 bytes per call
	total := 0
	for _, v := range a { // range (and a[i]) work through an array pointer
		total += v
	}
	return total
}
```

For basic types this reason essentially never applies — don't write `*int`
to "save" 8 bytes. It becomes real for big arrays and (next module) big
structs. Until then, mutation is your only genuine motive.

## Value semantics vs pointer semantics

These two terms will follow you through the rest of the course:

- **Value semantics**: pass/assign copies. Nobody can change your data
  behind your back; functions are easy to reason about. This is Go's
  default and the right choice whenever it's affordable.
- **Pointer semantics**: pass/assign addresses. Everyone shares one
  underlying object; changes are visible to all holders. Choose it when you
  *need* sharing (mutation) or when copying is too expensive.

```go
a := 5
b := a      // value semantics: b is an independent copy
b = 6       // a is still 5

p := &a
q := p      // pointer semantics: q and p point at the same int
*q = 7      // a is now 7
```

Idiomatic Go leans on value semantics and reaches for pointers *when there
is a reason*. If a function doesn't need to mutate its argument, take the
value.

## `new(T)`

The built-in `new(T)` allocates a zeroed `T` and returns a `*T`:

```go
p := new(int)   // p is a *int pointing at a fresh 0
*p = 8

// exactly equivalent to:
var n int
p2 := &n
```

That equivalence is why you'll rarely see `new` in real code: `&variable`
does the same thing and lets you initialize in the same breath. For structs
(next module), the idiom `&Point{X: 1, Y: 2}` replaces `new` almost
entirely. Recognize `new` when you read it; you'll seldom write it.

## The crucial contrast: slices and maps already share

This is the point of the module. You learned in modules 05 and 06 that a
slice is a small header `{pointer, len, cap}` and a map variable is a
pointer to a hash table under the hood. Passing them to a function copies
*the header*, not the data — so the function already sees the caller's
elements:

```go
func doubleAll(xs []int) { // no *[]int needed!
	for i := range xs {
		xs[i] *= 2
	}
}

nums := []int{1, 2, 3}
doubleAll(nums)
fmt.Println(nums) // [2 4 6] — mutated, no pointer in sight

func markVisited(seen map[string]bool, key string) { // no *map needed!
	seen[key] = true
}
```

So `*[]int` and `*map[string]bool` in a signature are almost always a
mistake — a signal the author didn't trust the header-copy model. The one
legitimate exception: a function that needs to **replace the slice header
itself** — for example, one that `append`s and must make the caller see the
new, possibly-reallocated slice. Even then, idiomatic Go prefers to
*return* the new slice, exactly like `append` does:

```go
nums = append(nums, 4)                  // the idiom: reassign the result
func push(xs *[]int, v int) { *xs = append(*xs, v) } // legal, but rare
```

Rule of thumb: **pointer to element data — already built into slices and
maps. Pointer to basic types — only when a function must mutate them.**

## Gotchas & idioms

- **Nil deref panics at runtime, not compile time.** `var p *int; _ = *p`
  compiles happily and crashes when reached. Establish a nil policy at
  every pointer-taking function boundary and write it in the doc comment.
- **`&` needs an addressable operand.** `p := &5` and `p := &len(s)` are
  compile errors — basic literals and function results have no home
  address. Store the value in a variable first. (Composite literals are
  the one carve-out: `&Point{1, 2}` is legal, as you'll see next module.)
- **Don't return `*int` to mean "optional int."** You'll see `*T`-as-
  optional in some APIs (JSON, protobuf), but for your own functions the
  comma-ok idiom `(int, bool)` is more idiomatic and can't be
  accidentally dereferenced. `SafeDeref` in the exercises converts one
  convention into the other.
- **Pointers into slices can be stranded by `append`.** `p := &xs[0]`
  points into the current backing array; if `append` later reallocates,
  `xs` moves and `p` still points at the *old* array. Prefer indices over
  pointers into slices you're still growing.
- **`*p++` means `(*p)++` in Go** — the increment applies through the
  dereference. There's no C-style ambiguity because `++` is a statement,
  not an expression.
- **Loop variables are safe to point at since Go 1.22**: each `for`
  iteration gets a fresh variable, so `&v` inside `for _, v := range xs`
  no longer aliases one shared slot. In pre-1.22 code (and interview
  questions) this was a notorious bug; you may still see defensive
  `v := v` copies in older codebases.

## In Advent of Code

AoC puzzles are simulations: a submarine position, a robot on a grid, a
score counter, register values in a toy CPU — state that a loop mutates
thousands of times. Pointers let you factor each mutation into a helper
(`MoveToward` here is exactly a puzzle step function: "each step, every
unit moves one toward its target") while keeping one authoritative copy of
the state. Just as important is what you *won't* need: your grids are
`[][]rune` and your counters are `map[string]int`, and as this module
showed, those mutate through plain parameters — most AoC solutions contain
very few `*`s. Where pointers quietly matter most is in the next module,
when your state graduates from loose variables into structs and methods
need `*T` receivers to mutate them; everything here is the foundation for
that.

## Exercises

Implement the stubs in `pointers.go`. The doc comments are the contracts;
the tests enforce them — including the nil-handling clauses, so read the
contracts carefully.

- **`Increment(p *int)`** — add 1 through the pointer; do nothing if `p` is
  nil. Hint: guard first, then `*p++`.
- **`Swap(a, b *int)`** — exchange the pointed-at values; a no-op if either
  pointer is nil. Hint: Go's parallel assignment `*a, *b = *b, *a` needs no
  temporary variable.
- **`SafeDeref(p *int) (int, bool)`** — the comma-ok wrapper around a
  dereference: `(value, true)` for a live pointer, `(0, false)` for nil.
  This is the pattern for taming pointers you don't control.
- **`DoubleAll(xs []int)`** — double every element in place, taking the
  slice *by value*. The point of the exercise is the signature: no pointer,
  yet the caller sees the change. Hint: `for i := range xs` and assign
  `xs[i]` — a `for _, x` value variable is a copy.
- **`ResetToZero(p *int)`** — write 0 through the pointer; nil is a no-op.
  Trivial on purpose: it's the shape of every "reset this counter" helper
  in a simulation loop.
- **`MoveToward(x, y *int, tx, ty int)`** — move `(*x, *y)` one king-step
  toward `(tx, ty)`: each coordinate independently moves by exactly 1
  toward its target or stays if it matches; a no-op if either pointer is
  nil. Hint: write a tiny helper that returns `-1`, `0`, or `+1` for one
  coordinate — a `switch` with `case cur < target:` conditions reads well.
  One of the tests calls it in a loop and expects the point to arrive.

## Check your work

From the repo root:

```sh
go test ./08-pointers/          # your implementations
go test -v ./08-pointers/       # see every subtest
go test ./08-pointers/solution/ # reference solutions (should pass)
```

When you're green — or thoroughly stuck — compare with `solution/`. Note
how every function establishes its nil policy in the first line, and how
`MoveToward` pushes the three-way comparison into an unexported `step`
helper instead of nesting conditionals.
