# 06. Maps

If slices are the workhorse of Go, maps are the toolbox: almost every
Advent-of-Code puzzle beyond the first few days needs one — to count
things, to remember what you've already seen, to store a sparse grid,
to memoize a recursion. Go's `map[K]V` is a built-in hash table with a
handful of design decisions you won't have met elsewhere: missing keys
silently read as a zero value, iteration order is *deliberately*
randomized, and a nil map is readable but not writable. This module is
about those decisions and the idioms that grew around them.

One small scope note: `WordCount` uses `strings.Fields(s)`, which
splits `s` around any run of whitespace and returns a `[]string`.
Strings get their full module next (07); that one function is all you
need here.

## What you'll learn

- Creating maps with `make` and with map literals; why nil maps bite
- Missing keys read as the zero value — and the comma-ok idiom that
  distinguishes "missing" from "present but zero"
- Writing, `delete`, `len`, and `clear`
- Why iteration order is random, and how to sort keys for
  deterministic output
- Sets via `map[T]bool` and `map[T]struct{}`
- Counting patterns (`counts[x]++`)
- Nested maps and maps of slices
- The `maps` and `slices` helper packages

## Creating maps

A map type is written `map[K]V`. The key type `K` must be
*comparable* — usable with `==`. Strings, integers, booleans,
pointers, arrays, and structs of comparable fields all qualify;
slices, maps, and functions do not. (This is why an AoC grid
coordinate is a `[2]int` array key — or, once you know structs in
module 09, a `struct{ x, y int }`.)

There are two ways to make a usable map:

```go
ages := make(map[string]int) // empty, ready for reads and writes
ages["ada"] = 36

counts := map[string]int{ // literal
	"north": 3,
	"south": 1,
}

empty := map[string]int{} // empty but non-nil, same as make
```

`make` accepts an optional size hint — `make(map[string]int, 1000)` —
which preallocates space. It is only an optimization; maps grow as
needed regardless.

What you must **not** do is declare a map and write to it:

```go
var m map[string]int // nil map: the zero value of any map type
m["x"] = 1           // PANIC: assignment to entry in nil map
```

A nil map behaves like an empty map for *reading*: lookups return the
zero value, `len` is 0, `range` does nothing, even `delete` is a
no-op. Only writes panic. This asymmetry is deliberate — it lets
functions accept "no map" gracefully — but it means every map you
intend to fill must be created with `make` or a literal first. This is
the number one runtime panic for people new to Go.

## Reading: missing keys and comma-ok

Indexing a map with a key it doesn't contain is not an error. It
returns the zero value of the value type:

```go
counts := map[string]int{"north": 3}

counts["north"] // 3
counts["east"]  // 0 — not present, so you get int's zero value
```

No exception, no `null`, no `Optional`. Surprisingly often this is
exactly what you want — a missing counter *should* read as 0, a
missing set member *should* read as false. Go leans into that.

When you genuinely need to know whether the key was present, ask for
the second result. This is the **comma-ok idiom**, the same shape you
saw with multi-value returns in module 04:

```go
n, ok := counts["east"] // n = 0, ok = false
```

`ok` is true only if the key exists, so `n == 0 && ok` means "present,
and its value is zero" while `n == 0 && !ok` means "absent". The
compact form scopes both variables to the `if`:

```go
if n, ok := counts["north"]; ok {
	fmt.Println("seen the north", n, "times")
}
```

By convention the boolean is always named `ok`.

## Writing, delete, len, clear

```go
counts["east"] = 7        // insert or overwrite
counts["east"]++          // works even when missing: 0 + 1 = 1
delete(counts, "east")    // remove; a no-op if the key is absent
n := len(counts)          // number of entries
clear(counts)             // remove every entry (Go 1.21+)
```

`delete` never fails and returns nothing — if you need to know whether
the key was there, do a comma-ok lookup first. Note that `m[k]++` and
`m[k] += x` are legal read-modify-write sugar even though, as you'll
see in the gotchas, map elements are not addressable in general.

## Iteration order is random — on purpose

```go
for k, v := range counts {
	fmt.Println(k, v)
}
```

Run that twice and the lines come out in different orders. This is not
an accident of the hash function: the runtime *deliberately*
randomizes the starting point of every `range` over a map. Early Go
programs accidentally depended on the then-stable order and broke when
the map implementation changed, so the designers made the order
unpredictable to keep anyone from relying on it again.

The consequences: never let a program's *answer* depend on map
iteration order, and when you need deterministic output, extract the
keys and sort them:

```go
keys := make([]string, 0, len(counts))
for k := range counts { // key-only range is allowed
	keys = append(keys, k)
}
slices.Sort(keys)
for _, k := range keys {
	fmt.Println(k, counts[k])
}
```

Or, in one line using the `maps` package (next section):

```go
for _, k := range slices.Sorted(maps.Keys(counts)) {
	fmt.Println(k, counts[k])
}
```

One aside for debugging: `fmt.Println(m)` and `%v` print maps with
keys in sorted order, precisely so that printed output is stable even
though iteration isn't.

## Maps as sets

Go has no set type; a map whose values you don't care about *is* the
set type. Two spellings are idiomatic:

```go
seen := make(map[int]bool)
seen[42] = true
if seen[42] { ... } // missing keys read as false — exactly right
```

`map[T]bool` reads beautifully (`if seen[x]`) and is what you'll write
most of the time. The alternative uses an empty struct, a type with
zero size:

```go
visited := make(map[[2]int]struct{})
visited[[2]int{3, 4}] = struct{}{}
if _, ok := visited[[2]int{3, 4}]; ok { ... }
```

`map[T]struct{}` stores no bytes per value and signals "membership
only, no data" to the reader, at the cost of the clunkier
`struct{}{}` literal and a comma-ok on every test. Both are common in
real code; for puzzle code the `bool` version is usually the right
trade. Just don't mix them up: with `map[T]bool` a key stored as
`false` is *in the map* but tests as not-a-member, which is sometimes
a feature ("known but excluded") and sometimes a bug.

## Counting patterns

The zero-value-on-miss rule makes frequency counting a two-liner —
no "check if present, else insert 0" dance:

```go
counts := make(map[rune]int)
for _, r := range "mississippi" {
	counts[r]++
}
// counts: 'i': 4, 'm': 1, 'p': 2, 's': 4
// (printing it shows the runes as numbers: map[105:4 109:1 112:2 115:4])
```

Finding the winner afterwards means ranging over the map, and here the
random order matters: if two entries tie, "whichever the range visits
first" changes run to run. Make ties deterministic with an explicit
tie-break (smallest key, say) — the `Mode` exercise makes you do
exactly this.

## Nested maps and maps of slices

For two-level keys — say, distances between named places — the value
type can itself be a map:

```go
dist := make(map[string]map[string]int)

// Writing requires the inner map to exist:
if dist["london"] == nil {
	dist["london"] = make(map[string]int)
}
dist["london"]["dublin"] = 464
```

The inner `make` is essential: `dist["london"]` on a fresh outer map
is the zero value `nil`, and writing to a nil map panics. *Reading*
straight through is fine, though — `dist["oslo"]["york"]` is 0, not a
panic, because reading from the nil inner map just yields the zero
value. Read-through works; write-through doesn't.

Maps of slices don't need that dance, because `append` treats a nil
slice as empty (module 05):

```go
groups := make(map[string][]string)
groups[key] = append(groups[key], word) // no init needed
```

That one-liner is the heart of the `GroupAnagrams` exercise. If your
two-level keys are really one compound key, consider skipping the
nesting entirely: `map[[2]int]rune` is usually better than
`map[int]map[int]rune` for a grid.

## The maps and slices helper packages

Since Go 1.21 the standard library ships small generic helper
packages. You used `slices` in module 05; the useful additions here:

```go
import ("maps"; "slices")

maps.Equal(m1, m2)  // same keys, same values? (== only works vs nil)
m2 := maps.Clone(m) // shallow copy
maps.Copy(dst, src) // merge src into dst, overwriting

keys := slices.Collect(maps.Keys(m))  // keys as a []K, unsorted
sorted := slices.Sorted(maps.Keys(m)) // keys as a sorted []K
```

`maps.Keys` and `maps.Values` return *iterators*, not slices — values
you can `range` over directly or materialize with `slices.Collect` /
`slices.Sorted`. Writing your own iterators is a later topic; for now
just know that `for k := range maps.Keys(m)` works and that
`slices.Sorted(maps.Keys(m))` is the idiomatic "give me sorted keys"
one-liner. Note that these helpers are shallow and value-oriented;
there is deliberately no `maps.Map` or `maps.Filter` — a plain loop is
considered clearer.

## Gotchas & idioms

- **Writes to a nil map panic.** `var m map[K]V` gives you nil; only
  `make` and literals give you a writable map. Reads, `len`, `range`,
  and `delete` on nil are all safe.
- **Maps are reference-like.** A map variable is a small header
  pointing at shared storage. Passing a map to a function or assigning
  `m2 := m` does *not* copy the data — mutations through either name
  are visible to both. Use `maps.Clone` when you need your own copy.
- **Map elements are not addressable.** `&m[k]` does not compile, and
  once you have struct values in maps (module 09) you'll find you
  can't assign to a field of one in place — you must copy out, modify,
  and store back, or hold pointers. `m[k]++` is fine; it's special-cased
  sugar.
- **`==` doesn't work on maps** (except comparing to nil). Use
  `maps.Equal`. Note that `maps.Equal` treats nil and empty as equal —
  usually what you want.
- **Ties + random order = flaky bugs.** Any "pick the best entry" loop
  over a map must break ties explicitly, or your program gives
  different answers on different runs. These bugs are miserable to
  find; the randomized order at least makes them show up early.
- **Avoid float keys.** `NaN != NaN`, so every NaN inserted becomes a
  separate, unretrievable entry.
- **Deleting during `range` is safe** and the entry won't be visited
  later; *inserting* during `range` may or may not be visited. Don't
  rely on either for logic.

## In Advent of Code

Maps are arguably the single most-used tool in AoC. Frequency counting
(`counts[x]++`) shows up constantly. The seen-set cycle detector — add
each state to a `map[state]bool`, stop when you meet one again — *is*
2018 day 1 part 2, and our `FirstRepeated` exercise is that puzzle in
miniature. Sparse or unbounded grids are far easier as
`map[[2]int]rune` than as slices-of-slices: negative coordinates cost
nothing and "is this cell occupied?" is a comma-ok lookup. Memoization
turns exponential puzzles (lanternfish, 2024's Plutonian pebbles) into
instant ones with a `map[args]result` cache, as you saw in module 04.
And whenever a puzzle wants output "in order", remember: sort the
keys.

## Exercises

Implement the stubs in `maps.go`. Read each doc comment carefully —
the contract (ordering, tie-breaks, empty inputs) is part of the
exercise.

- **`WordCount(text string) map[string]int`** — count each
  whitespace-separated word. Hint: `strings.Fields` plus the counting
  pattern; the whole thing is a few lines.
- **`FirstRepeated(xs []int) (int, bool)`** — the first value to be
  seen a second time, comma-ok style. Hint: a `map[int]bool` seen-set,
  checking *before* inserting.
- **`Intersect(a, b []int) []int`** — set intersection, sorted, no
  duplicates. Hint: load `a` into a set, walk `b`; `delete` a matched
  value from the set so duplicates in `b` can't match twice; sort at
  the end.
- **`GroupAnagrams(words []string) [][]string`** — group anagrams
  together, preserving first-appearance order of groups. Hint: a
  word's letters, sorted, make a canonical key (`[]byte` +
  `slices.Sort` + back to `string`); use `map[string][]string` with
  the append idiom — and since map order is random, keep a separate
  `[]string` of keys in first-seen order to build the result.
- **`Mode(xs []int) (int, bool)`** — most frequent value, smallest
  wins ties. Hint: count, then scan the map with an explicit
  tie-break; the tests will catch you if you rely on iteration order.
- **`Invert(map[string]int) map[int]string`** — swap keys and values;
  when values collide, the lexicographically smallest key wins. Hint:
  comma-ok before overwriting.
- **`TwoSum(xs []int, target int) (int, int, bool)`** — indices
  `i < j` with `xs[i]+xs[j] == target`, in one O(n) pass. The classic
  interview/AoC question (it is essentially AoC 2020 day 1). Hint:
  walk `xs` once with a `map[int]int` from value to index; before
  recording `xs[j]`, ask whether `target-xs[j]` is already in the map.
  Record only the *first* index of each value and the tie-break rules
  fall out for free.

## Check your work

From the repository root:

```sh
go test ./06-maps/            # runs the tests against your code
go test -v ./06-maps/         # with per-subtest detail
go test ./06-maps/solution/   # the reference solutions (should pass)
```

All tests fail until you implement the stubs. When you're done — or
stuck — compare your code with `solution/maps.go`, which contains
idiomatic reference implementations of every exercise.
