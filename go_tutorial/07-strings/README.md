# 07. Strings & Parsing

Every Advent of Code puzzle begins the same way: a wall of text arrives and
you have to turn it into numbers and structure before you can even think about
the algorithm. Go's answer to this is not regexes-first (though it has those
too) but a small set of sharp tools in `strings` and `strconv` that compose
into parsers faster than you can write the regex. This module is that toolkit.
It's also where you confront Go's honest model of text: a string is bytes, a
character is a `rune`, and the two are *not* the same thing.

## What you'll learn

- Strings are immutable, read-only byte slices — `len`, indexing, and slicing
  all work in **bytes**
- Bytes vs runes, and why `range` over a string yields runes at *byte* offsets
- The `strings` workhorses: `Split`, `Fields`, `TrimSpace`, `Contains`,
  `HasPrefix`, `Join`, `ReplaceAll`, `Cut`
- `strconv` — `Atoi`, `Itoa`, `ParseFloat` — and the error-handling idiom
  around them
- `fmt.Sscanf` for rigidly formatted lines
- `strings.Builder` for building strings without quadratic copying

## Strings are immutable byte slices

A Go `string` is a read-only sequence of **bytes** — by convention UTF-8
encoded text, but the language doesn't enforce that. Three consequences
follow:

```go
s := "héllo"

len(s)      // 6, not 5 — 'é' is two bytes in UTF-8
s[1]        // 0xc3 (a byte, type uint8) — half of 'é', not a character
s[1:3]      // "é" — slicing works on byte offsets too
s[0] = 'H'  // COMPILE ERROR: strings are immutable
```

Immutability is why strings are cheap to pass around: like a slice, a string
value is just a pointer and a length, and copying one never copies the bytes.
It's also why every "modify a string" operation in Go returns a *new* string.

To actually edit text, convert to a mutable form and back:

```go
b := []byte("hello")  // copies the bytes into a writable slice
b[0] = 'H'
s := string(b)        // copies back into a new immutable string — "Hello"
```

Both conversions copy, which is fine for puzzle-sized inputs. For
character-level work there's a third form, `[]rune(s)`, coming right up.

## Bytes vs runes

A `rune` is Go's name for a Unicode code point — an alias for `int32`, the
way `byte` is an alias for `uint8`. ASCII characters are one byte each, but
`é` is two bytes and `海` is three. So there are two ways to walk a string,
and they see different things:

```go
s := "héllo"

// By byte: classic indexing. i counts 0,1,2,3,4,5.
for i := 0; i < len(s); i++ {
    fmt.Printf("%d:%x ", i, s[i]) // 0:68 1:c3 2:a9 3:6c 4:6c 5:6f
}

// By rune: range DECODES the UTF-8 for you.
for i, r := range s {
    fmt.Printf("%d:%c ", i, r) // 0:h 1:é 3:l 4:l 5:o
}
```

Look closely at the second loop: the index jumps from 1 to 3. **`range` over a
string yields runes, but the index is the byte offset where each rune
starts** — 'é' begins at byte 1 and occupies bytes 1–2, so 'l' starts at
byte 3. This surprises everyone once. The design is deliberate: the byte
offset is what you need to slice the original string (`s[1:3] == "é"`),
whereas a "character number" would be useless for that.

Related tools worth knowing:

```go
len(s)                        // bytes: 6
utf8.RuneCountInString(s)     // runes: 5  (import "unicode/utf8")
[]rune(s)                     // decode everything: []rune{'h','é','l','l','o'}
```

Rule of thumb for AoC: if the input is guaranteed ASCII (most puzzles), bytes
and `s[i]` are fine and fast. The moment characters can be multi-byte — or
you're not sure — use `range` or `[]rune`.

## The `strings` workhorses

These eight functions handle 90% of puzzle parsing. All of them return new
values; none modify their input (they can't — immutability).

```go
strings.Split("1,2,3", ",")        // []string{"1", "2", "3"}
strings.Fields("  R5\n L3\tU2 ")   // []string{"R5", "L3", "U2"}
strings.TrimSpace("  hi \n")       // "hi"
strings.Contains("seafood", "foo") // true
strings.HasPrefix("Game 1:", "Game") // true   (HasSuffix exists too)
strings.Join([]string{"a", "b"}, "-") // "a-b"
strings.ReplaceAll("co-or-di", "-", "") // "coordi"
```

`Split` vs `Fields` is a distinction you'll use daily: `Split` cuts at every
occurrence of an exact separator (and keeps empty fields — `"a,,b"` gives
three fields), while `Fields` splits on *any run of whitespace* and never
returns empty strings. For "words on a line", `Fields` is almost always what
you want.

`strings.Cut` (Go 1.18+) deserves its own introduction because it replaced a
whole family of awkward `Index`+slice code. It splits at the *first*
occurrence of a separator and tells you whether it found one:

```go
key, value, ok := strings.Cut("shiny gold: 2 bags", ": ")
// key = "shiny gold", value = "2 bags", ok = true
```

The `ok` boolean is the same comma-ok idiom you met with maps in module 06.
When a line has exactly one delimiter — `key=value`, `name: score`,
`before|after` — reach for `Cut` before `Split`.

## `strconv`: strings to numbers and back

`Split` and friends give you strings; puzzles want numbers. Enter `strconv`:

```go
n, err := strconv.Atoi("42")        // string -> int
if err != nil {
    return nil, fmt.Errorf("bad number %q: %v", "42", err)
}

s := strconv.Itoa(42)               // int -> string, no error possible

f, err := strconv.ParseFloat("3.25", 64) // string -> float64
```

The names are C heritage: **A**SCII-**to**-**i**nteger and back. `Atoi`
returns an error rather than panicking or silently producing 0, and the idiom
is always the same: call, check `err != nil`, handle or return. Resist the
urge to ignore the error with `n, _ := strconv.Atoi(...)` — a typo in your
puzzle input then becomes a mysterious 0 in your answer instead of a clear
error message. (Module 11 goes deep on error design; for now, wrapping the
failure in `fmt.Errorf` with the offending text is exactly right.)

One trap for later: `string(65)` compiles but gives `"A"` — it converts an
integer *code point* to a one-rune string, not a number to its decimal
digits. `go vet` flags it. Number-to-text is always `strconv.Itoa` or
`fmt.Sprintf("%d", n)`.

## `fmt.Sscanf` for rigid formats

When every line has the same shape, `fmt.Sscanf` parses it in one call — it's
`Printf` in reverse:

```go
var id, x, y int
_, err := fmt.Sscanf("Sensor 7 at x=13, y=-2", "Sensor %d at x=%d, y=%d", &id, &x, &y)
// id=7, x=13, y=-2
```

The `&x` passes the *address* of `x` so `Sscanf` can write into it — pointers
get their full treatment in module 08; for now read `&x` as "let Sscanf fill
in x". The first return value is how many items matched, which you can check
instead of (or as well as) `err`.

`Sscanf` quirks to know: a space in the format matches any amount of
whitespace (including none), `%s` reads up to the next whitespace (so it
won't grab `13,` cleanly if you wanted `13`), and parsing stops at the first
mismatch. It shines on rigid formats like `"%d-%d %c: %s"`; for anything
ragged, `Fields`/`Cut`/`Atoi` compose better.

## `strings.Builder`: concatenation without the O(n²)

Because strings are immutable, `s += piece` allocates a brand-new string and
copies everything so far — every single time. In a loop, that's quadratic.
`strings.Builder` keeps one growable buffer instead:

```go
var b strings.Builder        // zero value is ready to use — no make() needed
for i := 0; i < 1000; i++ {
    b.WriteString("na")
}
b.WriteRune('!')             // runes and bytes have their own Write methods
result := b.String()         // one final string, no copy of the buffer
```

`b.Grow(n)` pre-allocates when you know the final size, saving re-allocations.
For joining an existing slice with a fixed separator, `strings.Join` is still
simpler — reach for `Builder` when the pieces are computed on the fly or the
separators vary (as in the `JoinWithAnd` exercise).

## Gotchas & idioms

- **`len(s)` is bytes, `s[i]` is a byte.** Use `utf8.RuneCountInString` for a
  character count and `range`/`[]rune` for characters. ASCII-only input makes
  them coincide — which is why the bug only bites later.
- **`range` gives byte offsets, not rune numbers.** After a multi-byte rune
  the index jumps by more than 1. Don't use the range index to count
  characters.
- **`string(n)` on an int is not `Itoa`.** `string(65)` is `"A"`. `go vet`
  catches this; the fix is `strconv.Itoa(n)`.
- **`strings.Split("", ",")` returns `[""]`** — one empty field, not zero
  fields. Guard for empty input before splitting (see `ParseInts`).
  `strings.Fields("")` returns an empty slice, one of several reasons to
  prefer it for whitespace.
- **Trailing newline in puzzle input.** Files almost always end with `\n`, so
  splitting on `"\n"` yields a phantom empty last line. Idiom:
  `strings.Split(strings.TrimSpace(input), "\n")`.
- **`strings.Trim` takes a *set* of runes, not a substring.**
  `strings.Trim("delivered", "de")` is `"liver"` — it strips d's and e's from
  both ends. To remove an exact prefix/suffix use `TrimPrefix`/`TrimSuffix`.
- **Rune literals use single quotes.** `'a'` is a rune (an `int32` number);
  `"a"` is a string. Arithmetic like `r - 'a'` works because runes are
  integers — that's the heart of the `Caesar` exercise.
- **Building strings in a loop? `strings.Builder`.** `+=` is fine for gluing
  two or three pieces once; anything iterative wants the Builder.

## In Advent of Code

Parsing *is* the first half of every AoC day. The pattern is nearly always:
`strings.TrimSpace` the raw input, `Split` on `"\n"` (or on `"\n\n"` for
blank-line-separated blocks — that one trick solves a dozen puzzles),
then per line either `Fields` + `Atoi` for loose formats, `Cut` for
`key: value` shapes, or `Sscanf` for rigid ones like
`"Blueprint 4: Each ore robot costs 3 ore."`. The exercises below are
deliberately shaped like real AoC inputs: comma-separated number lists
(2021 day 6 "lanternfish"), instruction streams like `R5 L3` (2016 day 1,
2022 day 9), and cipher-shifting (2016 day 4 literally asks for a Caesar
decryption). Get fluent here and the parsing step of each puzzle drops to
two minutes.

## Exercises

Implement the stubs in `parse.go` and `text.go`. Doc comments on each
function are the contract — read them first. One heads-up: `ParseMoves`
returns a slice of `Move`, a small **struct** (a bundle of named fields);
structs are formally introduced in module 09, but using one as a plain data
carrier here needs nothing you can't pick up from the literal syntax
`Move{Dir: 'R', Dist: 5}`.

- **`ParseInts(s string) ([]int, error)`** — `"1, 2 ,3"` → `[]int{1, 2, 3}`.
  `Split` on commas, `TrimSpace` each field, `Atoi`. Watch the two edge
  cases: whitespace-only input returns `(nil, nil)`, and any bad field means
  returning `nil` *and* an error (no partial results).
- **`ParseKeyValue(input string) (map[string]string, error)`** — multi-line
  `key=value` text into a map. `Split` on `"\n"`, skip blank lines, and let
  `strings.Cut` do the heavy lifting — its `ok` result is your malformed-line
  detector. Remember only the first `=` separates key from value.
- **`CountVowels(s string) int`** — count vowel *runes*, including `áéíóú`.
  A `range` loop plus `strings.ContainsRune` is all you need; the contract's
  exact vowel set is in the doc comment.
- **`IsPalindrome(s string) bool`** — rune-wise palindrome check that works
  for `"été"` and `"上海海上"`. Convert to `[]rune` and walk two indexes
  inward from the ends. A byte-wise check (`s[i] == s[len(s)-1-i]`) fails
  several test cases — try it and see which.
- **`Caesar(s string, shift int) string`** — shift ASCII letters, wrap the
  alphabet, preserve case, pass everything else through. Two hints: normalize
  the shift first (Go's `%` keeps the sign of the dividend, so `-1 % 26` is
  `-1`), and `'a' + (r-'a'+k)%26` does the rotation.
- **`ParseMoves(s string) ([]Move, error)`** — `"R5 L3 U2"` →
  `[]Move{{'R', 5}, {'L', 3}, {'U', 2}}`. `strings.Fields` for the tokens;
  for each, the first byte is the direction and the rest goes through `Atoi`.
  Validate everything: direction in `UDLR`, distance ≥ 1.
- **`JoinWithAnd(items []string) string`** — `["a","b","c"]` →
  `"a, b and c"`. Handle the 0- and 1-item cases first, then build the rest
  with `strings.Builder`: `", "` between all but the last item, `" and "`
  before the last.

## Check your work

From the repository root:

```sh
go test ./07-strings/          # runs the tests against YOUR implementations
go test -v ./07-strings/       # -v shows each subtest as it runs
```

Out of the box every test fails, because the stubs return zero values — each
green test is progress. When you're done (or stuck), compare against the
idiomatic implementations in `solution/`, which pass the same tests verbatim:

```sh
go test ./07-strings/solution/
```
