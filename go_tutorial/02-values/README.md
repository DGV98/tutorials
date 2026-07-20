# 02. Variables, Types & Constants

Almost every Advent of Code puzzle boils down to: read some numbers and
strings, do arithmetic on them, print an answer. Go is unusually strict about
*which kind* of number you're holding at any moment — there is no implicit
numeric conversion at all — and that strictness will either be a constant
source of compiler errors or, once it clicks, the reason a whole class of
bugs never happens to you. This module makes it click.

## What you'll learn

- The two ways to declare a variable (`var` and `:=`) and where each is allowed
- Zero values: why Go has no "uninitialized variable" bugs
- The basic types — `int`, `int64`, `float64`, `string`, `bool`, `byte`, `rune` — and when to reach for which
- Why `int + float64` doesn't compile, and the explicit conversion `T(v)`
- Integer division and `%`, the workhorses of digit and time math
- Constants, typed vs untyped, and `iota` for enums
- What actually happens when an integer overflows

## Declaring variables: `var` vs `:=`

Go has two declaration forms, and idiomatic code uses both — for different
jobs.

```go
var count int          // declare with the type; starts at 0
var name = "elf"       // type inferred from the initializer (string)
var x, y int           // two ints, both 0
```

and, inside a function, the short form (declaring the same variables from
scratch):

```go
count := 0             // short declaration: declare AND initialize
name := "elf"          // same inference as var, less ceremony
h, m := 13, 37         // declares both at once
```

The rules:

- `:=` is only legal **inside functions**. At package level (outside any
  function) you must use `var` (or `const`).
- `:=` always **declares** its left-hand side, so it needs an initializer —
  there is no `x :=` without a value. Plain `=` assigns to something that
  already exists.
- `var` without an initializer gives you the type's zero value, which is a
  feature, not a fallback (next section).

The idiom: inside functions, prefer `:=` when you have a value to start
from. Use `var` when you deliberately want the zero value (`var sum int`
before a loop reads as "sum starts at zero") or when you need a variable
before you can compute its value.

One more Go-ism that will bite you exactly once: an **unused local variable
is a compile error**. Not a warning — your program will not build. Delete it
or use it. (Unused *package-level* variables are allowed; unused imports are
also errors, as you saw in module 01.)

## Zero values

In Go, declaring a variable *always* initializes it. There is no
uninitialized memory to read, ever. Each type has a defined **zero value**:

| Type                        | Zero value       |
| --------------------------- | ---------------- |
| numeric (`int`, `float64`…) | `0`              |
| `string`                    | `""` (empty)     |
| `bool`                      | `false`          |
| pointers, slices, maps…     | `nil` (later modules) |

This is why idiomatic Go often skips explicit initialization:

```go
var total int      // 0 — ready to accumulate into
var longest string // "" — any real string beats it
var seen bool      // false — flips to true when found
```

Zero values are also why the exercise stubs in this course compile: a stub
that does `return 0` or `return ""` is returning the zero value, and the
tests then tell you it's wrong.

## The basic types

```go
var (
	i   int     = -42        // THE integer type; use it by default
	i64 int64   = 1 << 40    // exactly 64 bits, always
	f   float64 = 3.14       // THE float type; `float32` is rarely used
	s   string  = "gopher"   // immutable UTF-8 bytes
	ok  bool    = true       // only true/false; no truthy values
	b   byte    = 'A'        // alias for uint8 — raw byte, value 65
	r   rune    = '⛄'       // alias for int32 — one Unicode code point
)
```

When to use which:

- **`int`** — your default for anything you count, index or loop over. It's
  64 bits on every machine you'll run AoC on, so it holds ±9.2×10¹⁸.
  Don't reach for `int32`/`int64` "for efficiency"; use `int` unless
  something forces you otherwise.
- **`int64`** — when an API hands it to you (e.g. `strconv.ParseInt`,
  `time.Duration`) or a file format demands exactly 64 bits. `int` and
  `int64` are *different types* even when both are 64 bits — you'll need a
  conversion between them.
- **`float64`** — the only float you normally use. Untyped decimal literals
  like `3.14` default to it. AoC rarely needs floats; when it does, this
  is the one.
- **`string`** — immutable. You never modify a string in place; you build a
  new one. Module 07 goes deep.
- **`bool`** — conditions must be actual `bool`s. `if 1 {` and `if s {` do
  not compile; write `if n != 0 {` and `if s != "" {`.
- **`byte`** — an alias (not just a lookalike — the *same type*) for
  `uint8`. Used for raw bytes and ASCII text, e.g. `grid[y][x]` of a byte
  grid.
- **`rune`** — an alias for `int32`, holding one Unicode code point. Rune
  literals use single quotes: `'A'` is a rune/number, `"A"` is a string.

## No implicit conversion — ever

Most languages quietly promote `int` to `double` when you mix them. Go
refuses:

```go
var n int = 10
var f float64 = 1.5

bad := n + f            // compile error: mismatched types int and float64
good := float64(n) + f  // 11.5 — explicit conversion T(v)
back := int(f)          // 1 — float→int TRUNCATES toward zero, no rounding
```

`T(v)` is a conversion expression: it produces the value `v` as type `T`.
A few things to internalize:

- It's spelled like a function call, but it's built into the language.
- `int(2.9)` is `2`, and `int(-2.9)` is `-2` — truncation, not rounding.
  If you want rounding, `math.Round` first.
- Converting a big type into a small one silently drops bits: with
  `n := 300`, `uint8(n)` is `44`. The compiler only stops you for
  *constants* that don't fit — the literal `uint8(300)` won't even
  compile; variables convert without complaint.
- Even same-size types need conversion: `int` ↔ `int64` requires `int64(n)`
  / `int(n64)`.

Why so strict? Because implicit promotions are where subtle numeric bugs
live in other languages. In Go, every place a value changes representation
is visible in the source. You'll write `float64(...)` a lot; that's normal.

## Integer division and `%`

Dividing two integers gives an integer, discarding the remainder:

```go
fmt.Println(7 / 2)   // 3   (not 3.5)
fmt.Println(7 % 2)   // 1   (the remainder)
fmt.Println(-7 / 2)  // -3  (truncates toward zero)
fmt.Println(-7 % 2)  // -1  (result takes the sign of the dividend)
```

If you want a fractional result you must convert *before* dividing:

```go
fmt.Println(float64(7) / 2)  // 3.5
fmt.Println(float64(7 / 2))  // 3 — too late, the damage is done inside
```

`/` and `%` together are how you take numbers apart:

```go
n := 8675309
last := n % 10    // 9        — last digit
rest := n / 10    // 867530   — everything but the last digit
hours := 7385 / 3600         // 2
mins := 7385 % 3600 / 60     // 3
```

That "peel a digit, shrink the number" pattern is one you'll use constantly.

## Constants, untyped constants, and `iota`

`const` declares a value fixed at compile time:

```go
const MaxTurns = 100
const Pi = 3.14159
```

The interesting part: a constant without an explicit type is **untyped**.
Untyped constants are arbitrary-precision numbers that only commit to a
type when used, which is why they mix freely where variables can't:

```go
const scale = 2          // untyped
var f float64 = 12.5
var n int = 40
fmt.Println(f * scale)   // fine: scale becomes float64 here
fmt.Println(n * scale)   // fine: scale becomes int here

const typed int = 2      // typed constant
fmt.Println(f * typed)   // compile error: float64 * int
```

This is also why `x := 3` gives an `int` and `y := 3.0` gives a `float64`:
untyped constants have a *default type* they fall back to (`int`,
`float64`, `rune`, `bool`, `string` depending on the literal).

And because constants exist at compile time with arbitrary precision, a
constant expression that doesn't fit its target is a compile error, not an
overflow: `const c int8 = 300` won't build.

### `iota`: enums, Go style

Go has no `enum` keyword. The idiom is a named integer type plus a `const`
block using `iota`, which counts 0, 1, 2… per line:

```go
type Direction int

const (
	North Direction = iota // 0
	East                   // 1
	South                  // 2
	West                   // 3
)
```

Only the first line needs the type and `iota`; the following lines repeat
the pattern implicitly. The named type means the compiler stops you from
accidentally passing some random `int` where a `Direction` is expected —
but since the underlying type is `int`, arithmetic still works, so tricks
like `(d + 1) % 4` for "turn clockwise" are cheap and idiomatic.

`iota` can do more (skip values, bit shifts like `1 << iota` for flag
sets), but sequential 0..n enums are 95% of real usage.

## Overflow: what actually happens

Go's fixed-size integers don't saturate and don't crash — they **wrap
around** (two's complement), silently:

```go
var b int8 = 127
b++
fmt.Println(b)           // -128

n := math.MaxInt         // 9223372036854775807
fmt.Println(n + 1)       // -9223372036854775808
```

No exception, no warning. Three practical consequences:

1. With 64-bit `int` you'll rarely overflow in AoC — but "rarely" isn't
   "never". Puzzles that say *multiply all the…* can blow past 9.2×10¹⁸.
2. Watch intermediate results: `float64(a+b)` overflows in the `int`
   addition *before* the conversion ever happens. Convert first:
   `float64(a) + float64(b)`. (This is exactly what the `SafeAverage`
   exercise is about.)
3. Constants are immune — overflow is a runtime phenomenon of *variables*.
   The constant expression `math.MaxInt + 1` alone won't compile if you try
   to store it in an `int`.

## Gotchas & idioms

- **`:=` needs at least one new variable on the left.** `x, err := f()`
  followed later by `y, err := g()` is fine — `err` is reused because `y`
  is new. But `err := g()` alone, when `err` exists, won't compile; use `=`.
- **Integer division inside constant math:** `c * 9 / 5` and `c * (9/5)`
  are very different — `9/5` on its own is integer constant division and
  equals `1`. Order your arithmetic so division happens last, or use floats.
- **Truncation, not rounding:** `int(9.99)` is `9`. Every time.
- **`%` keeps the dividend's sign:** `-7 % 3` is `-1`, not `2`. If you need
  an always-positive wrap (cyclic grid indices), the idiom is
  `((x % n) + n) % n`.
- **Don't declare what you can infer:** `var s string = "hi"` is
  legal but noisy; write `s := "hi"`. Save explicit types for when you want
  a type *different* from the default: `var f float64 = 2`.
- **Zero values are your friend:** don't write `count := 0` at package
  level or `var count int = 0` anywhere — `var count int` already says it.

## In Advent of Code

Digit manipulation via `/ 10` and `% 10` shows up every year (checksum
puzzles, "sum digits that match…", splitting numbers in half). `%` is the
standard tool for anything cyclic: wrapping around a circular list of
elves, turning on a grid, clock arithmetic on timestamps. `iota` enums are
the clean way to model facing/direction state in every grid-walking puzzle
— pair one with a delta table in module 05 and `TurnRight` becomes your
whole movement engine. And AoC's larger inputs are exactly where silent
`int` overflow bites people who multiply first and think later.

## Exercises

Implement the `TODO`s in this directory. Two tiny previews of later
modules you'll need, since real code refuses to wait:

- Go's only loop keyword is `for`: `for n > 0 { ... }` works like a
  `while` (module 03 covers every shape).
- Functions can return several values: `return h, m, s` (module 04).

The exercises:

- **`CelsiusToFahrenheit(c float64) float64`** — `F = C*9/5 + 32`. One
  line. Make sure your arithmetic does float division, not integer
  constant division (see Gotchas).
- **`DigitSum(n int) int`** — sum of decimal digits. Peel digits with
  `% 10` and `/ 10` in a loop.
- **`LastNDigits(x, n int) int`** — `x mod 10^n`. Build the power of ten
  with a loop of integer multiplies; `math.Pow` would drag you through
  float64 for nothing.
- **`SplitDuration(totalSeconds int) (h, m, s int)`** — hours, minutes,
  seconds. Three expressions using `/` and `%`. Remember `%` and `/` have
  equal precedence and evaluate left to right.
- **`SafeAverage(a, b int) float64`** — mean of two ints with the
  fraction intact, correct even when `a+b` overflows. Where you place the
  `float64(...)` conversions is the entire exercise.
- **`Direction` / `TurnRight(d Direction) Direction`** — rewrite the
  constant block with `iota` (clockwise: North 0, East 1, South 2,
  West 3), then implement TurnRight with arithmetic — no if/switch chain
  needed. What operator wraps 3+1 back to 0?
- **`ZeroValueReport() string`** — declare an `int`, `float64`, `string`
  and `bool` with plain `var` (no initializers!) and format them with
  `fmt.Sprintf` into exactly `int=0 float64=0 string="" bool=false`.
  The `%q` verb from module 01 puts the quotes around the string.

## Check your work

From the repo root:

```sh
go test ./02-values/          # your implementations
go test -v ./02-values/       # see every subtest by name
```

All green? Compare your code with `solution/` — especially `SafeAverage`
and the `iota` block — then check the box in the root README. If you're
stuck, the solutions are honest, idiomatic Go, not code golf:

```sh
go test ./02-values/solution/   # proves the reference solutions pass
```
