# 15. The Standard Library Toolkit

You now know the language. This module is about the batteries: the handful of
standard-library packages that turn "I understand Go" into "I can solve a
puzzle in twenty minutes". Every Advent of Code day starts the same way — read
a file, split it into lines, pull the numbers out, sort or count something,
print two answers — and Go's stdlib covers that entire pipeline without a
single external dependency. The one big *idea* in this module (as opposed to
API tour) is the `io.Reader` idiom: write your functions against the smallest
interface that works, and testability falls out for free.

## What you'll learn

- Reading input: `os.ReadFile` for whole files, `bufio.Scanner` for lines
- Why functions should take `io.Reader` instead of a filename — the
  testability idiom
- `time`: `Duration`, `Parse` and its strange reference date, `Since`
- `regexp`: `MustCompile`, `FindAllString`, capture groups — and when
  `strings.Split` is the better tool
- Sorting: `slices.Sort`, `slices.SortFunc` with `cmp.Compare` and `cmp.Or`,
  and what "stable" means
- A tour of the `slices` and `maps` packages
- The shape of a typical AoC `main.go`

## Reading input

### Whole file at once: `os.ReadFile`

```go
data, err := os.ReadFile("input.txt") // data is []byte
if err != nil {
    log.Fatal(err)
}
text := string(data)
```

One call, whole file in memory. For puzzle inputs (a few hundred KB at most)
this is perfectly fine, and it pairs naturally with `strings.Split(text, "\n")`
or `strings.Fields`. Note it returns `[]byte`; convert to `string` once and
work with strings from there.

### Line by line: `bufio.Scanner`

```go
sc := bufio.NewScanner(r) // r is any io.Reader
for sc.Scan() {           // false at EOF (or on error)
    line := sc.Text()     // current line, newline already stripped
    // ...
}
if err := sc.Err(); err != nil { // nil at normal EOF
    log.Fatal(err)
}
```

Three things the Scanner does for you:

- **Strips line endings** — `sc.Text()` never contains the trailing `\n`,
  and it strips `\r\n` too, so Windows-flavored inputs just work.
- **Handles the missing final newline** — a last line without `\n` is still
  returned. (Splitting on `"\n"` yourself, by contrast, gives you a bogus
  empty final element when the file *does* end in a newline. This asymmetry
  is why Scanner is the default choice for lines.)
- **Buffers** the underlying reader, so it's efficient even on a raw file.

`sc.Err()` is where read errors surface; `Scan` just returns `false` for both
EOF and error, so strictly correct code checks `Err` after the loop. Puzzle
code often skips it — an in-memory string can't fail, and a file that just
opened almost never does — but know that the check exists, and where.

### The idiom: take an `io.Reader`, not a filename

Here is the single most important design habit in this module. Compare:

```go
// Hard to test: needs a real file on disk for every test case.
func SumNumbersInFile(path string) (int, error)

// Trivial to test: pass strings.NewReader("1\n2\n3") in tests,
// pass the opened *os.File in main. Same function, unchanged.
func SumNumbersInReader(r io.Reader) (int, error)
```

`io.Reader` is a one-method interface (`Read(p []byte) (int, error)`), and
half the standard library already satisfies it: `*os.File`, the readers from
`strings.NewReader` and `bytes.NewReader`, `os.Stdin`, network connections,
gzip decompressors... By accepting the interface, your parsing logic doesn't
know or care where the bytes come from. Module 10 told you "accept
interfaces, return structs"; this is that advice paying rent. Your `main`
does the file opening (that's *its* job — it owns the filesystem boundary),
and everything below it works on readers:

```go
f, err := os.Open("input.txt")
if err != nil {
    log.Fatal(err)
}
defer f.Close()
total, err := SumNumbersInReader(f)
```

and the test needs no fixture files at all:

```go
got, err := SumNumbersInReader(strings.NewReader("1\n2\n3\n"))
```

Every exercise in this module takes an `io.Reader` or a `string` — except
one, `ReadFileLines`, which exists precisely to be the doorway from the
filesystem into reader-land.

## time

### Duration

`time.Duration` is an `int64` count of nanoseconds with a type wrapped around
it, which buys you readable arithmetic and printing:

```go
d := 90 * time.Second
fmt.Println(d)                  // 1m30s
fmt.Println(d.Seconds())        // 90 (float64)
fmt.Println(2*time.Hour + 15*time.Minute) // 2h15m0s
```

Because it's a named numeric type, `3 * time.Second` works but an untyped-ish
`seconds * time.Second` where `seconds` is an `int` variable does **not** —
you must convert: `time.Duration(seconds) * time.Second`. Subtracting two
`time.Time` values with `t2.Sub(t1)` yields a `Duration`.

### Parse and the reference date

Go doesn't use `%Y-%m-%d` format strings. Instead, you write the layout by
formatting one specific reference moment:

```
Mon Jan 2 15:04:05 MST 2006
```

(Mnemonic: 1 2 3 4 5 6 — month 1, day 2, 3pm, minute 4, second 5, year '06.)
You show Go what your format looks like *applied to that date*, and it
pattern-matches:

```go
t, err := time.Parse("2006-01-02 15:04", "2024-01-02 15:09")
if err != nil { ... }
fmt.Println(t.Year(), t.Minute()) // 2024 9
```

Writing any other date in the layout — `"2024-01-02"` as a layout string —
silently produces garbage matching, so tattoo the reference date somewhere.
`t.Format(layout)` goes the other direction with the same layout string.

Two more things about `time.Time`: compare with `t1.Before(t2)` /
`t1.After(t2)` / `t1.Equal(t2)`. Prefer `Equal` over `==` — two `Time`
values can represent the same instant yet differ in internal representation
(location, monotonic clock reading), and `==` compares the representation.

### Since

`time.Since(start)` is shorthand for `time.Now().Sub(start)` — the standard
way to time something:

```go
start := time.Now()
part2 := solve(lines)
fmt.Println("part 2 took", time.Since(start))
```

## regexp

Compile once, at package level, with `MustCompile`:

```go
var intRE = regexp.MustCompile(`-?\d+`)
```

`MustCompile` panics if the pattern is malformed — exactly what you want for
a pattern written by you, fixed at compile time: a typo explodes at program
start, not as a per-call `error` you'd have to thread through everything.
(`Compile` returning an error exists for patterns that arrive at runtime.)
Use backquoted raw strings for patterns so `\d` doesn't need escaping.

The workhorse methods:

```go
intRE.FindAllString("move -12 from 3 to 45", -1)
// []string{"-12", "3", "45"}      (-1 means "no limit")

intRE.MatchString("abc")           // false
```

For structured lines, capture groups with `FindStringSubmatch`:

```go
re := regexp.MustCompile(`^(\w+) (\d+),(\d+)$`)
m := re.FindStringSubmatch("goto 12,7")
// m == []string{"goto 12,7", "goto", "12", "7"}
//        m[0] is the whole match; groups start at m[1]
// m == nil if the line didn't match — check before indexing!
```

`FindAllStringSubmatch(s, -1)` does the same for every match in `s`,
returning a `[][]string`.

**When `strings.Split` beats a regex:** whenever the format is fixed and
delimiter-based. `"12-34,56-78"` doesn't need a regex — `strings.Split` on
`","` then `"-"` is faster to write, faster to run, and impossible to get
subtly wrong. Reach for `regexp` when the interesting bits float in
unpredictable surrounding text; reach for `Split`/`Cut`/`Fields` when the
structure is rigid. A good rule: if you can describe the format as "X
separated by Y", it's a split.

## Sorting

Module 12 gave you the generic `slices` package; here's the sorting corner
of it in detail.

```go
nums := []int{3, 1, 2}
slices.Sort(nums) // ascending, in place; works on any ordered type
```

For anything richer than natural ascending order, `slices.SortFunc` takes a
comparator returning negative / zero / positive (like C's `strcmp`), and the
`cmp` package provides the pieces:

```go
slices.SortFunc(people, func(a, b Person) int {
    return cmp.Compare(a.Age, b.Age) // ascending by age
})
```

- **Descending?** Swap the operands: `cmp.Compare(b.Age, a.Age)`.
- **Multiple keys?** `cmp.Or` returns its first non-zero argument, which
  chains comparisons exactly like "sort by X, then by Y":

```go
slices.SortFunc(people, func(a, b Person) int {
    return cmp.Or(
        cmp.Compare(a.Age, b.Age),   // primary: age
        cmp.Compare(a.Name, b.Name), // tie-break: name
    )
})
```

**Stability.** A stable sort keeps equal elements in their original relative
order; `slices.SortFunc` does *not* promise that (it's faster for it), and
`slices.SortStableFunc` does. When does it matter? Only when your comparator
says "equal" for elements that are distinguishable — sorting people by age
alone, two 25-year-olds may come out in either order, and a test comparing
exact slices will flake. Two fixes: use `SortStableFunc` (input order breaks
ties), or — usually better for puzzles — make the comparator itself total
with a tie-breaking key, as above. A fully deterministic comparator makes
stability irrelevant.

## The `slices` and `maps` packages

Beyond sorting, `slices` is a grab-bag you should skim once in full
([pkg.go.dev/slices](https://pkg.go.dev/slices)). The ones that earn their
keep in puzzles:

```go
s := []int{3, 1, 4, 1, 5}

slices.Contains(s, 4)        // true
slices.Index(s, 4)           // 2 (-1 if absent)
slices.Max(s), slices.Min(s) // 5, 1 (panic on empty slice!)
slices.Reverse(s)            // in place
slices.Equal(s, t)           // element-wise == (used all over our tests)
slices.Clone(s)              // shallow copy — new backing array
slices.Compact(sorted)       // removes ADJACENT duplicates (sort first!)
slices.BinarySearch(sorted, x) // (index, found) — needs sorted input
slices.IndexFunc, ContainsFunc, MaxFunc, EqualFunc... // ...Func variants
                             // of everything, for custom element logic
```

The `maps` package is smaller. `maps.Keys` and `maps.Values` return
*iterators* (Go's `iter.Seq`, usable in `for ... range` and with a `slices`
adapter — full iterator treatment isn't in this course; treat these two
lines as the recipe):

```go
keys := slices.Collect(maps.Keys(m)) // iterator -> []K, random order
keys := slices.Sorted(maps.Keys(m))  // collect AND sort in one call
```

That second line is *the* answer to "how do I range over a map
deterministically" — remember from module 06 that map iteration order is
deliberately randomized. Also handy: `maps.Clone(m)` (shallow copy) and
`maps.Equal(m1, m2)`.

## Putting it together: an AoC `main.go`

Every day of Advent of Code, the top-level program is the same seven lines;
only the functions below it change. Note the division of labor: `main` deals
with the filesystem and printing, the solve functions take data:

```go
package main

import (
    "fmt"
    "log"
    "os"
)

func main() {
    f, err := os.Open("input.txt")
    if err != nil {
        log.Fatal(err)
    }
    defer f.Close()

    lines := ReadLines(f) // io.Reader in, []string out — testable
    fmt.Println("part 1:", part1(lines))
    fmt.Println("part 2:", part2(lines))
}
```

`part1` and `part2` take `[]string` (or whatever parsed structure you build
from it) and return an answer — so your tests exercise them with literal
slices and the puzzle's worked example, never touching disk. Module 16 makes
that testing workflow the main event.

## Gotchas & idioms

- **Scanner's token limit.** `bufio.Scanner` refuses lines longer than 64KB
  by default — it stops scanning and reports `bufio.ErrTooLong` via
  `sc.Err()`. Some AoC inputs are one giant line! The fix:
  `sc.Buffer(make([]byte, 0, 1024*1024), 1024*1024)` before scanning, or use
  `os.ReadFile` + `strings.Split` for such inputs.
- **`sc.Err()` exists.** `Scan()` returning false means EOF *or* error;
  check `Err` in code that must be correct. (It returns `nil` on clean EOF.)
- **Splitting on `"\n"` leaves `\r` behind** on Windows-style input, and a
  trailing newline gives you a final `""` element. Scanner sidesteps both;
  if you do split manually, `strings.TrimSpace` each piece or split on the
  already-trimmed text via `strings.Fields`.
- **The regex sign quirk:** `-?\d+` on `"1-2"` yields `1` and `-2`, because
  the dash touches the digits. For "ranges like `1-2`" inputs, that's wrong —
  and it's a `strings.Split(s, "-")` job anyway (see "when Split beats a
  regex"). For coordinate-style inputs (`x=-5`), the regex is exactly right.
- **The reference date is 2006-01-02 15:04:05.** A layout string containing
  any *other* date is a bug that produces garbage, usually silently.
- **Compare `time.Time` with `Equal`, not `==`.**
- **Map iteration order is random** — any output derived from ranging over a
  map needs an explicit sort (`slices.Sorted(maps.Keys(m))`) or a
  deterministic tie-break to be reproducible.
- **`slices.Sort` is ascending only.** Descending is `SortFunc` with swapped
  operands — there is deliberately no `reverse` flag.
- **`slices.Max`/`Min` panic on an empty slice.** Guard with `len` first.

## In Advent of Code

This module *is* the AoC starter kit. Day 1 of nearly every year is: read
lines, extract the integers from each, sum or sort them — which is literally
`ReadLines` + `ExtractInts` + `slices.Sort` from your exercises. Timestamped
log puzzles (2018 day 4 is famous) are `ParseEvents` + `SortFunc`.
"Find the 3 most common ..." counting puzzles are a map plus `TopN`, where
the deterministic tie-break is the difference between a right answer and one
that changes every run. Keep this module's `solution/` directory open in
December; it's your utility belt.

## Exercises

Stubs live in `read.go`, `parse.go`, and `rank.go`. Everything takes an
`io.Reader` or a `string` — except `ReadFileLines`, the one deliberate
filesystem function.

- **`ReadLines(r io.Reader) []string`** (`read.go`) — the fundamental
  helper: all lines from any reader, endings stripped, blanks kept, `nil`
  for empty input. `bufio.NewScanner`, loop on `Scan`, append `Text`.
- **`SumNumbersInReader(r io.Reader) (int, error)`** (`read.go`) — one int
  per line, trimmed; skip blank lines; on a bad line, an error that quotes
  the line (`%q`) and wraps the `strconv` error (`%w`, module 11).
- **`ReadFileLines(path string) ([]string, error)`** (`read.go`) — open the
  file, defer-close it, delegate to `ReadLines`. Wrap the open error with
  the path as context. Tested against the module's `sample.txt`.
- **`ExtractInts(s string) []int`** (`parse.go`) — all integers in `s`,
  negatives included, via a package-level `regexp.MustCompile` of the
  pattern `-?\d+` and `FindAllString(s, -1)`, then `strconv.Atoi` each match.
- **`ParseEvents(r io.Reader) ([]Event, error)`** (`parse.go`) — lines of
  `2024-01-02 15:04|message`. `strings.Cut` on the first `|`, `time.Parse`
  with layout `"2006-01-02 15:04"`, message kept verbatim (it may itself
  contain `|`), blank lines skipped.
- **`Span(events []Event) time.Duration`** (`parse.go`) — latest minus
  earliest, in any input order; `0` for fewer than two events. Track
  min/max with `Before`/`After`, subtract with `Sub`.
- **`SortPeople(people []Person)`** (`rank.go`) — in place, age ascending,
  name breaks ties. One `slices.SortFunc`, one `cmp.Or`.
- **`TopN(counts map[string]int, n int) []string`** (`rank.go`) — the `n`
  keys with the highest counts, descending; alphabetical order breaks count
  ties (that's what makes it deterministic — the map won't help you).
  Collect keys, `SortFunc`, slice to `min(n, len)`. `nil` for `n <= 0` or
  an empty map.

## Check your work

```sh
go test ./15-stdlib-toolkit/
```

Run it from the repo root. Out of the box the tests compile but fail — each
one names the function it exercises, so work through them in the order
above. Complete, idiomatic implementations (with the same tests, verbatim)
are in `15-stdlib-toolkit/solution/`; compare only after your own version is
green:

```sh
go test ./15-stdlib-toolkit/solution/
```
