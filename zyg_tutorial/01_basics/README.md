# 01 — Basics

Your first contact with Zig. By the end of this module you can read a Zig
file top to bottom, declare values, do arithmetic without the compiler
yelling (or *with* it yelling, and understanding why), and build formatted
strings. Everything later builds on this.

You'll learn:

- what a Zig file is made of: `@import`, `main`, `test` blocks, doc comments
- `const` vs `var`, type inference, and the compiler's strong opinions
- integer types, why overflow crashes instead of wrapping, and the
  operators/builtins that make intent explicit: `+%`, `+|`, `@intCast`,
  `@divTrunc`, `@divFloor`, `@mod`, `@rem`
- floats, explicit int↔float conversion, and why `==` on floats is a trap
- `bool` with `and` / `or` / `!`
- `std.fmt`: `bufPrint`, `allocPrint`, and format specifiers

## Anatomy of a Zig file

```zig
//! This comment documents the whole file (note the `!`).

const std = @import("std");

/// This doc comment documents the declaration below it.
fn greet() []const u8 {
    return "Hello, Zig!";
}

pub fn main() void {
    std.debug.print("{s}\n", .{greet()});
}

test "greet" {
    try std.testing.expectEqualStrings("Hello, Zig!", greet());
}
```

Line by line:

- `@import("std")` returns the standard library *as a value*. Anything
  starting with `@` is a builtin — a function provided by the compiler
  itself. There are no header files and no global namespaces: if a file
  doesn't import it, the file can't see it.
- `pub fn main` is the entry point for `zig run file.zig`. `pub` makes it
  visible outside the file, which the runtime needs.
- `test "name" { ... }` blocks are compiled and run only by
  `zig test file.zig` — `main` is ignored there, and tests are ignored by
  `zig run`. One file, two personalities. This course leans on the test
  side: the tests in each exercise are the spec.
- `std.debug.print(fmt, args)` writes to stderr with zero setup. The second
  argument is always a tuple — `.{}` for nothing, `.{x, y}` for two values.
  It's your debugging tool for the whole course. Proper buffered stdout
  needs the `Io` interface and waits until module 10.

Inside the format string, `{s}` formats a string, `{d}` a decimal number.
More specifiers in exercise 05.

## const, var, and the compiler's opinions

```zig
const limit: u32 = 100; // immutable, explicitly typed
const speed = 88;       // immutable, type inferred
var count: u32 = 0;     // mutable
count += 1;
```

Write `const` by default. This isn't just style — the compiler enforces a
whole discipline around declarations, and it will be the first friction you
feel coming from Python or JS:

- **Assigning to a `const` is a compile error.** Not a runtime error — the
  program never builds.
- **Unused locals and parameters are compile errors.** Dead code doesn't
  linger. While experimenting you can silence one with a discard: `_ = x;`
  — the exercises use this trick to keep stubs compiling. Delete the
  discard when you actually use the value.
- **A `var` that's never mutated is a compile error** ("local variable is
  never mutated; consider using 'const'"). Mutability stays an honest
  signal: when you read `var`, something *will* change it.
- **Shadowing is illegal.** An inner `const x` cannot hide an outer `x`.
  Rename one of them.

`undefined` initializes memory without giving it a value: `var buf: [32]u8
= undefined;`. It means "I promise to write before I read". Break the
promise and you get illegal behavior — sometimes caught in Debug builds,
sometimes garbage. Use it for buffers you're about to fill, nothing else.

## Integers

Types spell out signedness and width: `u8`, `i32`, `u64`, `i128`, even
`u3`. `usize` is the pointer-sized unsigned integer — array indexes and
lengths are `usize`, and you'll convert to/from it often.

Bare literals like `42` have type `comptime_int`: arbitrary-precision
compile-time integers that coerce to any type they fit in. That's why
`const x: u8 = 300;` fails at compile time — 300 doesn't fit.

Three literal notations, one number:

```zig
const a = 240;
const b = 0xF0;         // hex
const c = 0b1111_0000;  // binary; underscores group digits anywhere
const big = 1_000_000;
```

### Overflow is illegal

In C, unsigned overflow wraps quietly. In Zig, `u8: 255 + 1` is *illegal
behavior*: Debug and ReleaseSafe builds panic with "integer overflow".
When wrapping or clamping is what you mean, say so:

```zig
counter +%= 1;          // wrapping: 255 -> 0
health = health -| dmg; // saturating: pins at 0 instead of panicking
```

Each arithmetic operator has `%` (wrap) and `|` (saturate) variants:
`+% -% *%`, `+| -| *|`.

### Conversions and division are spelled out

No implicit narrowing: a `u32` becomes a `u8` only through
`@intCast(x)` — your written guarantee that the value fits (Debug builds
panic if it doesn't). Widening that can't lose information (`u8` → `u32`)
coerces automatically. Note `@intCast` takes no destination type: it's
inferred from context, e.g. the return type or a `const y: u8 =`
annotation.

Signed division doesn't even have a `/` — this is a compile error:

```zig
fn f(a: i32, b: i32) i32 {
    return a / b; // error: signed integers must use @divTrunc, @divFloor, or @divExact
}
```

C truncates toward zero, Python floors toward negative infinity, and they
disagree on negatives (`-7/2` is `-3` vs `-4`). Zig makes you choose:
`@divTrunc`, `@divFloor`, or `@divExact` (asserts no remainder). Same for
remainders: `@rem` follows the numerator's sign (C's `%`), `@mod` follows
the denominator's — `@mod(i, len)` is the one that safely wraps an index.

## Floats and bools

`f16`, `f32`, `f64`, `f80`, `f128` — default to `f64`. Bare float literals
are `comptime_float`. Watch mixed-looking arithmetic: `9 / 5` is integer
division (`1`); write `9.0 / 5.0` for float math.

Int↔float conversion is explicit, like everything else:

```zig
const n: i64 = 7;
const x: f64 = @floatFromInt(n); // annotation supplies the target type
const back: i64 = @intFromFloat(3.99); // truncates toward zero -> 3
```

Floats are base-2, so `0.1 + 0.2 == 0.3` is **false** — the classic
`0.30000000000000004`. Compare within a tolerance:

```zig
std.math.approxEqAbs(f64, a, b, 1e-9)
```

Booleans are their own type — there is no truthiness. `if (n)` for an
integer `n` doesn't compile; write `if (n != 0)`. The logical operators are
keywords: `and`, `or` (both short-circuit), and `!x` for negation. Typing
`&&` gets you a compile error that literally tells you to use `and`.

## Building strings with std.fmt

```zig
var buf: [64]u8 = undefined;
const s = try std.fmt.bufPrint(&buf, "{s}: {d}", .{ "ada", 95 });
// s is the slice of buf that was written; error.NoSpaceLeft if buf is too small

const t = try std.fmt.allocPrint(alloc, "{d} items", .{n});
defer alloc.free(t); // allocPrint allocates exactly enough; you own it
```

`bufPrint` formats into a buffer you provide (usually stack memory — no
allocator needed). `allocPrint` allocates the exact size, for when you
can't bound the length; the caller frees. In tests, pass
`std.testing.allocator` — it fails the test on leaks.

Specifiers you'll use constantly:

| Spec    | Meaning                        | Example                     |
| ------- | ------------------------------ | --------------------------- |
| `{d}`   | decimal number                 | `42`                        |
| `{s}`   | string (`[]const u8`)          | `hello`                     |
| `{c}`   | one `u8` as a character        | `A`                         |
| `{x}`   | lowercase hex                  | `ff`                        |
| `{b}`   | binary                         | `101`                       |
| `{any}` | debug-print any value          | `{ 1, 2, 3 }` for a slice   |

After the specifier, `:` introduces fill, alignment, and width:
`{d:0>4}` → fill `0`, right-align `>`, width 4 → `7` becomes `"0007"`.
`{s:*<6}` left-aligns with stars: `"ab****"`. Width is a minimum — wide
values print in full.

## Gotchas

- **The error is the lesson.** `zig test` output looks loud; read only the
  *first* `error:` line. It names the file, line, and usually the fix.
- **Unused = broken.** Declaring a variable "for later" won't compile.
  Neither will an unused function parameter — discard with `_ = x;` until
  you use it.
- **`u8: 255 + 1` panics; it does not wrap.** Wrapping is opt-in via `+%`.
  If a Debug build dies with "integer overflow", the bug is real — don't
  reach for `+%` unless wrap-around is genuinely the semantics you want.
- **`9 / 5 == 1`.** Two integer-typed operands divide as integers even in
  the middle of float arithmetic. Write `9.0 / 5.0`.
- **`{d}` vs `{c}` on a `u8`:** `'A'` prints as `65` with `{d}` and `A`
  with `{c}`. A `u8` is just a number; the specifier chooses the costume.
- **Float `==` lies.** `0.1 + 0.2 != 0.3`. Use `std.math.approxEqAbs`.
- **`&&` and `||` don't exist.** The keywords are `and` / `or`.
- **`@intCast`/`@floatFromInt` need a destination type from context.** If
  you see "unable to infer result type" errors, annotate the receiving
  const or parameter.
- **Old tutorials will betray you.** Anything pre-0.15 shows APIs that no
  longer exist. When in doubt: [docs/zig-0.16-notes.md](../docs/zig-0.16-notes.md).

## Exercises

Work them in order; run each with `zig test <file>` until green.

1. `01_hello.zig` — `@import`, `main` vs `test`, `std.debug.print` with
   `{s}`/`{d}` (also try `zig run 01_hello.zig`).
2. `02_variables.zig` — fix-the-compile-errors: const reassignment, unused
   local, never-mutated `var`, illegal shadowing.
3. `03_integers.zig` — literals, wrapping `+%`, saturating `+|`,
   `@intCast`, `@divTrunc`/`@divFloor`, `@mod`/`@rem`.
4. `04_floats_bools.zig` — `@floatFromInt`/`@intFromFloat`, approximate
   float comparison, `and`/`or` logic.
5. `05_formatting.zig` — `bufPrint`/`allocPrint` and the format-specifier
   zoo, including `{d:0>4}`-style padding.

Stuck? Reference answers live in `../solutions/01_basics/`. Next up:
`02_control_flow`, where `if` and `switch` turn out to be expressions.
