# 03. Control Flow

Go's control flow is deliberately small: one loop keyword, an `if` with no
surprises, and a `switch` that doesn't fall through. Where other languages
give you `while`, `do-while`, `until`, ternaries, and loop constructs to
choose between, Go gives you a handful of forms and expects you to combine
them. The payoff is that all Go code looks alike — yours, the standard
library's, and the solution you'll compare against — and after this module
you'll have seen nearly every branching and looping construct in the
language (the stragglers: type switches arrive with interfaces in module 10,
`select` with channels in module 13, and `goto` exists but idiomatic Go
essentially never uses it).

## What you'll learn

- `if` / `else if` / `else`, and the if-with-init-statement idiom
- Why `for` is Go's **only** loop keyword, and its four shapes
- `continue`, `break`, and labeled `break` for escaping nested loops
- `switch` on values, condition-less `switch` as a cleaner if/else chain,
  and `fallthrough` (and why you'll almost never use it)
- How to live without a ternary operator

## `if`, `else if`, `else`

No parentheses around the condition; braces are always required:

```go
if n%15 == 0 {
	fmt.Println("FizzBuzz")
} else if n%3 == 0 {
	fmt.Println("Fizz")
} else {
	fmt.Println(n)
}
```

Three things Go is strict about:

1. **The condition must be a `bool`.** There is no truthiness: `if n { ... }`
   and `if len(s) { ... }` do not compile. Write `if n != 0` or
   `if len(s) > 0`. This kills a whole family of bugs (`if x = 5` style
   typos can't sneak in either, because assignment is a statement, not an
   expression).
2. **Braces are mandatory**, even for a single statement. There is no
   dangling-else ambiguity in Go.
3. **`else` must sit on the same line as the closing `}`.** This isn't a
   style preference — the compiler auto-inserts a semicolon at the end of a
   line that looks complete, so a lone `}` followed by `else` on the next
   line is a syntax error. `gofmt` keeps you honest.

### The init-statement idiom

An `if` can run a short statement before its condition, separated by a
semicolon:

```go
if r := n % 3; r != 0 {
	fmt.Println("remainder", r)
}
```

`r` exists **only** inside the `if` (and its `else` branches, if any). The
point is scope hygiene: a value you need for exactly one decision doesn't
leak into the rest of the function. You will see this idiom constantly in
real Go, most of all with errors:

```go
if err := doThing(); err != nil {
	return err
}
// err does not exist here — you can't accidentally check a stale one.
```

(Errors get their own module, 11. For now just recognize the shape.)

## `for` — the only loop

Go has exactly one loop keyword. Every loop you will ever write is some
shape of `for`. Again: no parentheses, mandatory braces.

**Classic 3-part** — init; condition; post:

```go
for i := 0; i < 10; i++ {
	fmt.Println(i)
}
```

Note that `i++` is a *statement* in Go, not an expression — you can't write
`x := i++`, and there is no `++i`. It exists purely to advance a counter.

**While-style** — drop the init and post (and their semicolons), keep the
condition:

```go
for n > 1 {
	n /= 2
	steps++
}
```

This *is* Go's `while`. Don't go looking for another keyword.

**Infinite loop + `break`** — drop everything:

```go
for {
	x = step(x)
	if x == seen {
		break
	}
}
```

There is no `do-while` in Go; this is how you write a loop whose exit test
belongs in the middle or at the end. "Loop forever until some condition"
is extremely common in simulation-style code.

**Range over an integer** (Go 1.22+) — the newest shape:

```go
for i := range 5 {
	fmt.Println(i) // 0 1 2 3 4
}
```

`range n` counts from `0` to `n-1`; if `n <= 0` the body never runs. When
you don't need the index at all, drop it:

```go
for range 3 {
	fmt.Println("ho")
}
```

`range` also iterates slices, maps, and strings — those variants arrive in
modules 05–07 alongside the types themselves.

Why only one keyword? Because these shapes are all the same construct with
parts omitted, there's nothing to memorize and no style debate about
`while (true)` vs `for (;;)`. You read `for`, you look at what's between it
and the `{`, and you know everything.

## `continue`, `break`, and labels

`continue` skips to the next iteration; `break` exits the loop. Both apply
to the **innermost** enclosing loop — which is a problem when you want out
of a nested loop. Go's answer is a labeled `break`:

```go
search:
	for i := range 10 {
		for j := range 10 {
			if i*j == 42 {
				fmt.Println("found", i, j)
				break search // exits BOTH loops
			}
		}
	}
```

A label is a name followed by `:` placed immediately before the loop.
`break search` exits the labeled loop; `continue search` would jump to the
labeled loop's next iteration (advancing `i`, abandoning the rest of the
`j` loop). In languages without this you'd set a `found` flag and test it
in both loops, or extract the loops into a function just to `return` out —
in Go the labeled break *is* the idiomatic solution. Use it sparingly: one
label per function is usually already a hint to extract a helper.

## `switch`

### On a value

```go
switch dir {
case "U":
	y--
case "D":
	y++
case "L", "R": // one case can match several values
	fmt.Println("sideways")
default:
	fmt.Println("unknown direction:", dir)
}
```

Two big differences from C-family switches:

- **No implicit fallthrough.** Each case is its own block; when it ends,
  the whole `switch` is done. The `break` you'd write in C/Java/JS is
  implied. Forgetting `break` — the classic switch bug — is impossible.
- **Cases needn't be constants.** They're just expressions compared against
  the switch value, checked top to bottom.

When several inputs share a body, list them in one case (`case "L", "R":`)
— that covers 95% of what fallthrough is used for elsewhere.

Like `if`, a `switch` can take an init statement:
`switch x := next(); x { ... }`.

### Switch with no condition

Leave out the value entirely and it becomes `switch true`: each case is a
boolean expression, and the first true one runs.

```go
switch {
case n < 0:
	fmt.Println("negative")
case n == 0:
	fmt.Println("zero")
case n < 10:
	fmt.Println("small")
default:
	fmt.Println("big")
}
```

This is Go's replacement for long `if / else if / else` chains, and most
Go programmers find it easier to scan: every branch lines up, and the
order tells you the priority (here `n == 5` stops at "small" and never
reaches "big"). Reach for it whenever you have three or more mutually
exclusive conditions.

### `fallthrough` — it exists, you'll rarely want it

If a case ends with the `fallthrough` keyword, execution continues into
the **next case's body without checking its condition**:

```go
switch {
case n >= 100:
	fmt.Println("at least a hundred")
	fallthrough
case n >= 10:
	fmt.Println("at least ten") // runs for n=500 too, unchecked
	fallthrough
default:
	fmt.Println("a number")
}
```

It's rare in practice because multi-value cases handle the common
"several inputs, one body" need, and because unconditional fallthrough is
exactly the foot-gun Go removed by default — reintroduce it only when you
genuinely want cumulative behavior. (It's also illegal in the last case:
there's nowhere to fall to.)

## No ternary operator

Go has no `cond ? a : b`, on purpose: the language designers judged that
ternaries — especially nested ones — hurt readability more than they help.
The idiomatic replacement is declare-then-conditionally-overwrite:

```go
label := "even"
if n%2 != 0 {
	label = "odd"
}
```

Yes, it's three lines instead of one. You'll stop noticing within a week.
For the single most common ternary use case — picking the larger or
smaller of two numbers — Go has builtin `min` and `max` (one or more
arguments), which you'll use in nearly every Advent of Code solution:

```go
best = max(best, score)
```

## Gotchas & idioms

- **A `break` inside a `switch` breaks the `switch`, not the loop around
  it.** When you `switch` on something inside a `for` and want to exit the
  loop from a case, you need a labeled `break`. This one bites everyone
  once.
- **No truthiness, ever.** `if n`, `if ptr`, `if len(s)` — none compile.
  Say what you mean: `n != 0`, `ptr != nil`, `len(s) > 0`.
- **`:=` in an init statement declares *new* variables**, even if names
  match ones in the outer scope — it shadows them. If an outer `err` stays
  nil while `if err := f(); ...` reported one, shadowing is why.
- **`for i := range n` counts `0..n-1`**, not `1..n`. Off-by-one classic:
  FizzBuzz talks about `1..n`, so either loop `for i := 1; i <= n; i++` or
  use `range n` and work with `i+1`.
- **Loop variables are fresh each iteration** (since Go 1.22). File this
  away — it matters once closures and goroutines capture them (modules 04
  and 13); older Go tutorials warn about a bug that no longer exists.
- **`fallthrough` doesn't check the next case's condition.** It's a jump,
  not a re-evaluation.
- **Condition-less `switch` order matters**: the first true case wins, so
  put the most specific test first (`n%15` before `n%3`).

## In Advent of Code

Almost every AoC solution is a `for` over input lines wrapped around a
decision. `switch` on a value is tailor-made for instruction-dispatch
puzzles (`"acc"`, `"jmp"`, `"nop"` in 2020 day 8; `R`/`L`/`U`/`D` moves in
grid puzzles). "Apply this rule until the state stops changing" — a huge
AoC genre — is the while-style or infinite `for` with a `break`, exactly
the shape of `CollatzSteps` below. Scanning a 2D grid for a target is two
nested `for`s and a labeled `break` the moment you find it. And
condition-less `switch` keeps tier-based rules (scoring tables, threshold
rules) flat and readable instead of a staircase of `else if`s.

## Two small previews

The exercises need two features from later modules; here's just enough to
use them:

- **`[]string` and `append`** (module 05): `var out []string` declares an
  empty slice — a growable list. `out = append(out, s)` adds an element;
  you must assign the result back. That's all FizzBuzz needs.
- **`...int` variadic parameters** (module 04): `divisors ...int` lets
  callers write `SumOfMultiples(10, 3, 5)` with as many divisors as they
  like. Inside the function, `divisors` is a `[]int`; iterate it with
  `for _, d := range divisors { ... }` (the `_` discards the index you
  don't need).

## Exercises

Open `exercises.go` and replace each `// TODO: implement` marker. The doc
comment on each function is the contract; the tests in `exercises_test.go`
enforce it.

- **`FizzBuzz(n)`** — return the sequence for `1..n` as a `[]string`.
  A condition-less `switch` with the divisible-by-15 case first reads
  better than an if/else chain. `strconv.Itoa` turns an int into its
  decimal string.
- **`CollatzSteps(n)`** — count steps until the halve-or-3n+1 process hits
  1. Guard `n < 1` first (return -1), then a while-style `for n != 1`
  does the rest.
- **`IsPrime(n)`** — trial division. Handle `n < 2`, then test divisors
  with a 3-part loop running while `d*d <= n` — no square roots, no
  floats.
- **`LetterGrade(score)`** — the condition-less `switch` exercise. Order
  the cases from the highest cutoff down and each one stays a single
  comparison; `default` catches the F.
- **`FirstDivisor(n)`** — smallest divisor greater than 1, or 0 when
  `n < 2`. Same `d*d <= n` loop as `IsPrime`, but think about what falls
  out the bottom of the loop: if nothing up to sqrt(n) divides n, what is
  n's smallest divisor above 1?
- **`SumOfMultiples(limit, divisors...)`** — the AoC-flavored one (Project
  Euler fans will recognize `SumOfMultiples(1000, 3, 5)`). Sum every
  positive integer below `limit` divisible by *any* divisor — counting
  each number **once**, which is what the overlapping-divisors test
  checks. Try `for n := range limit` for the outer loop, an inner `range`
  over `divisors`, and a `break` as soon as one divisor matches. Skip
  divisors `<= 0` or `n % d` will panic on zero.

## Check your work

From the repo root:

```sh
go test ./03-control-flow/            # run this module's tests
go test -v ./03-control-flow/         # see every subtest by name
go test -run TestFizzBuzz -v ./03-control-flow/   # focus on one exercise
```

Fresh stubs compile but fail the tests — that's your worklist. When
everything is green (or when you're stuck), compare your code against
`solution/`, which contains idiomatic reference implementations and passes
the same tests verbatim:

```sh
go test ./03-control-flow/solution/
```
