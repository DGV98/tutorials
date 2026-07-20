# 05. Arrays & Slices

Slices are *the* Go collection. Where other languages give you lists, vectors,
and arrays as separate tools, Go gives you one workhorse — the slice — and it
appears in virtually every function signature you'll ever write. Slices also
hide the single most surprising behavior in the language: two slices can
silently share the same memory. Understanding exactly when that happens (and
when it doesn't) is what separates "I write Go" from "I debug Go at midnight."

## What you'll learn

- Arrays are fixed-size **values**; slices are lightweight **views** over arrays
- `len` vs `cap`, and how `append` grows a slice
- Slice expressions `s[a:b]` and the shared-backing-array pitfall
- `copy` (and `slices.Clone`) to break unwanted sharing
- Building 2D `[][]rune` grids — the bread and butter of Advent of Code
- Iterating with `range` (and why the value variable is a copy)
- The standard `slices` package: `Contains`, `Sort`, `Max`, `Reverse`, and friends

## Arrays: fixed-size values

A Go array's length is part of its **type**: `[3]int` and `[4]int` are as
different as `int` and `string`. Arrays are values — assigning or passing one
copies *all* of its elements:

```go
a := [3]int{1, 2, 3}
b := a          // full copy of all 3 elements
b[0] = 99
fmt.Println(a)  // [1 2 3] — a is untouched
fmt.Println(b)  // [99 2 3]

c := [...]int{5, 10, 15, 20} // [...] lets the compiler count: type is [4]int
_ = c
```

Coming from C or Java this is the first surprise: no decay to pointers, no
reference semantics. Because the size is baked into the type, arrays are rigid
and you'll rarely declare one directly. Their real job is to be the hidden
storage *underneath* slices.

## Slices: views over arrays

A slice is a small header — three words — describing a window into a backing
array:

```text
slice header:  { pointer → backing array, length, capacity }
```

- **length** (`len`): how many elements the slice can see right now
- **capacity** (`cap`): how many elements exist from the slice's start to the
  end of the backing array — room to grow without reallocating

```go
s := []int{1, 2, 3}          // slice literal: builds an array, returns a view
t := make([]int, 3)          // [0 0 0]        len 3, cap 3
u := make([]int, 0, 10)      // []             len 0, cap 10 — preallocated room
var v []int                  // nil slice:     len 0, cap 0, no backing array
```

A `nil` slice is perfectly usable — `len(v)` is 0, `range` over it does
nothing, and you can `append` to it. Idiomatic Go rarely distinguishes nil
from empty, so `var result []int` followed by appends is the standard way to
build a slice.

When you pass a slice to a function, only the small header is copied — the
backing array is shared. That's why functions can modify a slice's *elements*
without pointers, and why slices are cheap to pass around.

### `len`, `cap`, and how `append` grows a slice

`append` adds elements at the end. If there's spare capacity, it writes into
the existing backing array; if not, it allocates a bigger array, copies
everything over, and returns a slice pointing at the new array. Watch it grow:

```go
var s []int
for i := range 5 {
	s = append(s, i)
	fmt.Println(len(s), cap(s))
}
// 1 4    ← first append allocates a small backing array (cap 4)
// 2 4
// 3 4
// 4 4
// 5 8    ← out of room: bigger array allocated, elements copied over
```

(The exact growth numbers are an implementation detail — never rely on them.)

Because `append` *may* return a slice with a brand-new pointer, you must
always reassign:

```go
s = append(s, x)   // correct — always
append(s, x)       // compile error: append's result must be used
```

If you know the final size in advance, `make([]int, 0, n)` preallocates the
capacity and avoids the repeated copy-and-grow.

## Slicing and the shared-backing-array pitfall

The expression `s[a:b]` builds a new *header* over the *same* backing array,
covering indices `a` through `b-1`. No elements are copied. That makes slicing
O(1) and wonderfully cheap — and it means the sub-slice **aliases** the
original:

```go
scores := []int{10, 20, 30, 40, 50}
top := scores[:2]   // view of the first two elements
top[0] = 999
fmt.Println(scores) // [999 20 30 40 50] — writing through one view hits both
```

That much is predictable once you know slices are views. The genuinely
*surprising* version involves `append`. A sub-slice's capacity extends to the
end of the backing array, so `append` can write into memory the original
slice still considers its own:

```go
a := []int{10, 20, 30, 40, 50}
b := a[:2]                    // len(b) = 2, but cap(b) = 5!

b = append(b, 999)            // fits within cap → no reallocation,
                              // writes straight into a's backing array

fmt.Println(a)                // [10 20 999 40 50]  ← a[2] silently overwritten
fmt.Println(b)                // [10 20 999]
```

Nothing about the call site hints that `a` changed. Worse, the behavior
*depends on capacity*: keep appending and the moment `append` outgrows the
backing array it allocates a fresh one, and the two slices quietly stop
aliasing:

```go
b = append(b, 1, 2, 3)        // exceeds cap 5 → b moves to a new array
b[0] = -1                     // now this does NOT affect a anymore
```

So the same code can alias for a 5-element input and not alias for a
6-element one. This is the classic Go heisenbug: "my function corrupts its
input, but only sometimes." Whenever you keep a sub-slice around *and* anyone
appends or writes, assume trouble.

### `copy` to the rescue

`copy(dst, src)` copies `min(len(dst), len(src))` elements — it never grows
`dst` — and returns the number copied. To truly detach a sub-slice, copy it
into its own array:

```go
a := []int{10, 20, 30, 40, 50}

b := make([]int, 2)
copy(b, a[:2])                // b has its own backing array now

b = append(b, 999)
fmt.Println(a)                // [10 20 30 40 50] — untouched
```

Two shorthands worth knowing:

```go
b := slices.Clone(a[:2])      // stdlib one-liner for make + copy

c := a[0:2:2]                 // "full slice expression" s[low:high:max]:
                              // caps cap(c) at 2, so append MUST reallocate
```

The three-index form `s[low:high:max]` is the subtle one: it doesn't copy
anything, but by limiting the capacity it guarantees a future `append` can't
reach into the original's memory.

## Building 2D grids

Go has no built-in 2D type — a grid is a slice of slices, and by convention
in this course it's `[][]rune` indexed `grid[row][col]`. Each row must be
allocated separately:

```go
rows, cols := 3, 4
grid := make([][]rune, rows)       // 3 nil rows so far
for r := range grid {
	grid[r] = make([]rune, cols)   // each row gets its OWN backing array
	for c := range grid[r] {
		grid[r][c] = '.'
	}
}
grid[1][2] = '#'
```

The per-row `make` matters: if every row pointed at the same slice, writing
one cell would "write" it in every row. (This is exactly what the
`rows are independent` test in this module checks.)

Turning puzzle input into a grid is one `append` per line — `[]rune(line)`
converts a string into its characters (strings get a full treatment in
module 07):

```go
var grid [][]rune
for _, line := range lines {       // lines is a []string
	grid = append(grid, []rune(line))
}
```

Bounds are on you: `grid[r][c]` panics if `r` or `c` is out of range, so
neighbor-checking code always guards with `len(grid)` for rows and
`len(grid[r])` for columns.

## Iterating with `range`

`range` over a slice yields index and element:

```go
for i, x := range xs { fmt.Println(i, x) } // index and value
for i := range xs    { ... }               // index only
for _, x := range xs { ... }               // value only (blank the index)
```

The crucial detail: **the value variable is a copy**. Assigning to it does not
touch the slice:

```go
xs := []int{1, 2, 3}
for _, x := range xs {
	x *= 10                       // modifies the copy; xs is unchanged
}
fmt.Println(xs)                   // [1 2 3]

for i := range xs {
	xs[i] *= 10                   // to mutate, index into the slice
}
fmt.Println(xs)                   // [10 20 30]
```

## The `slices` package

Since Go 1.21 the stdlib `slices` package covers most everyday slice chores.
Import `"slices"` and reach for these before writing a loop:

```go
xs := []int{3, 1, 4, 1, 5}

slices.Contains(xs, 4)        // true
slices.Max(xs)                // 5  — PANICS on an empty slice
slices.Min(xs)                // 1  — likewise
slices.Index(xs, 4)           // 2  (or -1 if absent)
slices.Sort(xs)               // sorts IN PLACE: xs is now [1 1 3 4 5]
slices.Reverse(xs)            // reverses IN PLACE: [5 4 3 1 1]
slices.Equal(xs, xs)          // element-wise comparison (== doesn't compile)
ys := slices.Clone(xs)        // fresh backing array
_ = ys
```

Note which functions mutate: `Sort` and `Reverse` change the slice you give
them and return nothing. `slices.Max` panicking on empty input is why this
module's `Max` exercise returns `(int, bool)` instead — the comma-ok idiom
(module 04's result-plus-bool shape) makes "there is no max" an answer
instead of a crash.

## Gotchas & idioms

- **Always reassign `append`**: `s = append(s, x)`. The compiler forces this
  for a bare call, but appending to a *copy* of a header (say, a slice you
  received as a parameter) grows your copy, not the caller's.
- **Functions can mutate elements, not length.** A callee shares your backing
  array (so `ReverseInPlace` works), but its `append` won't change your
  slice's length — the caller's header never changes.
- **Slices can't be compared with `==`** (except to `nil`). Use
  `slices.Equal`, which also treats nil and empty as equal.
- **nil is a fine empty slice.** `var s []int` + `append` is idiomatic;
  don't write `s := []int{}` or `make([]int, 0)` unless you specifically
  need non-nil (e.g. JSON `[]` vs `null`).
- **`make([]int, n)` vs `make([]int, 0, n)`**: the first gives you n zeros
  (index into it), the second gives you an empty slice with room for n
  (append into it). Mixing them up yields a slice with n zeros *followed by*
  your appends — a classic bug.
- **The `range` value is a copy** — index into the slice to mutate.
- **Sub-slices alias until an `append` reallocates** — when in doubt,
  `slices.Clone`.

## In Advent of Code

Half of AoC lives on a grid: maps of trees, seating areas, octopus energy
levels, guard patrol routes. The pattern is always the same — parse lines
into `[][]rune`, then loop `r`/`c` with bounds checks, usually counting or
mutating the 8 neighbors of a cell (Game-of-Life-style puzzles appear almost
every year, which is exactly what `CountNeighbors` practices). The 1D tools
matter just as much: summing and maxing parsed numbers is the shape of most
early puzzles, `Chunk` mirrors "process input in groups of N", and `Rotate`
shows up in circular-buffer puzzles and letter ciphers. Fluency here means
you spend your time on the puzzle, not on index arithmetic.

## Exercises

Implement the stubs in `slices.go` and `grid.go`. The doc comments are the
contracts; the tests enforce them.

In `slices.go`:

- **`Sum(xs []int) int`** — add up the elements with a `range` loop. Nothing
  fancy; feel the shape of slice iteration.
- **`Max(xs []int) (int, bool)`** — largest element, comma-ok style: `ok` is
  false for an empty slice. Hint: start `best` at `xs[0]` (not 0 — think
  all-negative input) and loop over `xs[1:]`.
- **`ReverseInPlace(xs []int)`** — reverse without allocating. Hint: two
  indices marching toward each other, and Go's parallel swap
  `xs[i], xs[j] = xs[j], xs[i]`.
- **`Filter(xs []int, keep func(int) bool) []int`** — collect the elements
  that pass the predicate into a new slice. Hint: `var kept []int` + `append`
  naturally returns nil when nothing matches.
- **`MapInts(xs []int, f func(int) int) []int`** — transform every element
  into a new slice. Hint: the output length is known, so
  `make([]int, len(xs))` and assign by index.
- **`Chunk(xs []int, size int) [][]int`** — split into runs of `size`, last
  chunk short. Hint: a `for start := 0; start < len(xs); start += size` loop
  and a slice expression per chunk; clamp the end with `min`.
- **`Rotate(xs []int, k int) []int`** — new slice, rotated left by `k`.
  Hint: a rotation is just `xs[k:]` followed by `xs[:k]` — two appends into a
  fresh slice. Normalize `k` first: Go's `%` can return a negative result,
  so use `((k % n) + n) % n`.

In `grid.go`:

- **`NewGrid(rows, cols int, fill rune) [][]rune`** — build a grid where
  every cell is `fill`. Hint: one `make` for the outer slice, then one `make`
  *per row* — the tests will catch rows that share memory.
- **`CountNeighbors(grid [][]rune, r, c int) int`** — count the non-`'.'`
  cells among the 8 neighbors of `(r, c)`. Hint: loop `dr` and `dc` over
  `-1..1`, skip `(0, 0)`, and bounds-check before indexing. Check the row
  index against `len(grid)` and the column against `len(grid[nr])`.

## Check your work

From the repo root:

```sh
go test ./05-arrays-slices/          # your implementations
go test -v ./05-arrays-slices/       # see every subtest
go test ./05-arrays-slices/solution/ # reference solutions (should pass)
```

When you're green — or thoroughly stuck — compare your code with the
implementations in `solution/`. Pay particular attention to how `Chunk` uses
a three-index slice expression and why `Filter` starts from a nil slice.
