# 02 — Control Flow

Module 1 gave you values and types. This module gives you the machinery that
moves them around: `if`, `switch`, `while`, `for`, labels, and `defer`. You
will learn:

- `if` and `switch` as **expressions** — they produce values, which replaces
  both the ternary operator and most temporary variables
- `switch` with multiple values per prong, ranges, and compiler-enforced
  exhaustiveness
- `while` with a continue expression (Zig's replacement for C's three-part
  `for`), and loops used as expressions via `break value`
- `for` over ranges and slices, with indices, and over two slices in lockstep
- labeled blocks and labeled loops for breaking out of nested scopes
- `defer` for cleanup that runs when a scope exits, in LIFO order

Everything here compiles on Zig 0.16.0 — run the snippets yourself if
anything looks suspicious.

## if — no ternary, no truthiness

The condition of an `if` must be a `bool`. Zig has no truthiness: `if (x)`
where `x` is an integer is a compile error. Write what you mean:

```zig
if (count != 0) { ... }
```

There is no `?:` operator because `if` is already an expression:

```zig
const label = if (n >= 0) "non-negative" else "negative";
```

When you use `if` as an expression, `else` is mandatory — the expression
needs a value on every path. Chains look like C and also work as expressions:

```zig
const desc = if (x < 0) "neg" else if (x == 0) "zero" else "pos";
```

(You will sometimes see `if (optional) |value|` — that unwraps optionals and
belongs to module 4. In this module, conditions are plain bools.)

## switch — exhaustive or it doesn't compile

A `switch` must cover every possible value of its operand. No fallthrough, no
`break` between cases; each prong is an independent expression:

```zig
const days: u8 = switch (month) {
    1, 3, 5, 7, 8, 10, 12 => 31,      // several values, one prong
    4, 6, 9, 11 => 30,
    2 => if (leap) 29 else 28,        // a prong body is any expression
    else => 0,                        // everything not listed
};
```

Ranges use `...` — three dots, inclusive on **both** ends:

```zig
const is_letter = switch (c) {
    'a'...'z', 'A'...'Z' => true,
    else => false,
};
```

Exhaustiveness is checked at compile time. Delete the `else` from the switch
above and the compiler lists the unhandled values. This becomes a superpower
with enums in module 6: add a variant, and every switch that forgot about it
stops compiling.

A prong can capture the matched value with `|v|`:

```zig
const doubled = switch (n) {
    0 => 0,
    else => |v| v * 2,   // v == n here, so this is redundant —
};                       // but the syntax matters later
```

On integers the capture is rarely useful (you already have `n`), but the same
`|payload|` syntax is how you extract data from tagged unions in module 6.
File it away.

## while — the only conditional loop

Zig has no C-style `for (init; cond; step)`. Instead, `while` takes an
optional **continue expression** after a colon — it runs at the end of every
iteration:

```zig
var i: usize = 0;
while (i < 10) : (i += 1) {
    // ...
}
```

`break` and `continue` do what you expect. `continue` still runs the continue
expression; `break` does not. `while (true)` is the idiomatic infinite loop —
leave it with `break` or `return`.

A `while` can be an expression. `break value` gives the loop its value; the
loop's `else` branch supplies the value when the condition goes false without
a break:

```zig
var d: u32 = 2;
const first_divisor = while (d <= 10) : (d += 1) {
    if (n % d == 0) break d;
} else 0;   // no divisor found
```

That loop-`else` is not the `else` of an `if`: it runs **only when the loop
finished normally**. Think of it as the "search failed" branch.

One practical note: function parameters are immutable. To loop on one, copy
it into a `var` first — you'll do this in the exercises.

## for — iteration with a known length

`for` only iterates things whose length is known: ranges, arrays, slices. It
is not a general-purpose loop — that's `while`'s job. The forms:

```zig
for (0..n) |i| { ... }         // i: usize, 0 through n-1 — n is EXCLUDED
for (xs) |x| { ... }           // each element
for (xs, 0..) |x, i| { ... }   // element and index together
for (xs, ys) |x, y| { ... }    // two slices in lockstep
```

Lockstep iteration demands equal lengths. A mismatch is a safety-checked bug
— your Debug build panics instead of silently truncating like `zip` does in
other languages.

Captures like `x` are immutable **copies**. `x += 1` doesn't compile.
(Mutating elements in place needs a pointer capture `|*x|`, which arrives
with pointers in module 7.)

Like `while`, a `for` works as an expression with `break` and `else`:

```zig
const has_zero = for (xs) |x| {
    if (x == 0) break true;
} else false;
```

## Labels — blocks and loops with names

Any block can be labeled, and `break :label value` exits it with a value.
This turns a multi-statement computation into an expression:

```zig
const x = blk: {
    var t: i32 = 1;
    t *= 10;
    break :blk t + 5;
};  // x == 15
```

Plain `break`/`continue` only reach the innermost loop. Label the outer loop
and you can control it from inside a nested one:

```zig
outer: for (grid) |row| {
    for (row) |cell| {
        if (isBad(cell)) continue :outer;  // next row, immediately
        if (isGoal(cell)) break :outer;    // leave both loops
    }
}
```

Combine the two ideas and a nested search becomes a single expression:
`break :outer .{ r, c }` from the inner loop, `else null` on the outer one.
Exercise 05 has you write exactly that.

## defer — cleanup you can't forget

`defer stmt;` schedules `stmt` to run when control leaves the **current
scope** — by falling off the end, by `return`, by `break`, any exit path.
Multiple defers run in reverse order of declaration (LIFO): last acquired,
first released.

```zig
fn demo() void {
    std.debug.print("1\n", .{});
    defer std.debug.print("4\n", .{});   // deferred first -> runs last
    defer std.debug.print("3\n", .{});
    std.debug.print("2\n", .{});
}   // prints 1 2 3 4
```

Why it matters: cleanup lives next to the thing it cleans up, and every early
return is covered automatically. You've already seen the pattern in the notes
file — `defer list.deinit(alloc);` right after creating the list. From module
7 on, nearly every allocation you make will be followed by a `defer`.

The error-path variant `errdefer` (runs only if the function returns an
error) is module 3's business.

## Gotchas

- **`..` vs `...`** — `for (0..n)` excludes `n`; switch ranges `0...59`
  include both ends. Two dots exclusive, three dots inclusive. Mixing them up
  is a classic off-by-one.
- **No truthiness.** `if (x)` on an integer doesn't compile. Neither does
  `while (n)`. Always compare: `x != 0`.
- **The continue expression runs on `continue`, not on `break`.**
  `while (i < n) : (i += 1)` bumps `i` even when an iteration ends with
  `continue` — but a `break` skips it and leaves the loop immediately.
- **Loop `else` means "no break happened".** It is the search-failure branch,
  not an error branch. If the loop body always breaks, the `else` never runs.
- **Reverse iteration with unsigned indices.** `while (i >= 0)` on a `usize`
  is always true, and `i -= 1` at zero panics with underflow. The idiom:
  `var i = xs.len; while (i > 0) { i -= 1; ... }`.
- **Defers can't change your return value.** The `return` expression is
  evaluated first, then defers run. Setting a local in a `defer` after
  `return x` alters nothing the caller sees.
- **A defer inside a loop body runs every iteration**, when that iteration's
  scope ends — not once after the loop. Scope means the enclosing block, not
  the enclosing function.
- **Unused means broken.** Unused locals and unused function parameters are
  compile errors. The exercise stubs discard parameters with `_ = x;` —
  remove the discard when you start using the parameter, because discarding a
  value you also use is an error too.

## Exercises

Work them in order; run each with `zig test <file>` until green.

1. `01_if.zig` — if/else, if-expressions, else-if chains: `sign`, `clamp`, `max3`.
2. `02_switch.zig` — switch prongs, ranges, exhaustiveness: char classifier, days-in-month, letter grades.
3. `03_while.zig` — condition + continue-expression loops: integer square root, Collatz step count, gcd.
4. `04_for.zig` — slices, lockstep, loop-else: count matches, dot product, index-of-first (a first taste of `?usize`).
5. `05_labels_defer.zig` — labeled loops and defer order: 2D grid search, clean-row count, a defer-ordering puzzle.
