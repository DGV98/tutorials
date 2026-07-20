# 03 — Functions and Errors

This is the module where Zig stops looking like "C with nicer switch" and
shows its actual personality. You'll write functions, then learn the error
system — which is not exceptions, not errno, and not Result-with-macros.
Errors in Zig are plain values with first-class syntax, and the compiler
refuses to let you drop one on the floor.

You'll learn:

- function syntax, `pub`, immutable parameters, early return
- passing functions as arguments (`*const fn` pointers and `comptime` params)
- error sets, error unions (`E!T`), inferred sets (`!T`), merging (`||`)
- `try` to propagate, `catch` to recover, `catch |err| switch` to classify
- `errdefer` for cleanup that runs only on the error path
- converting between optionals and errors, and when to use which

## Functions

```zig
fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub fn area(w: u32, h: u32) u64 {
    return @as(u64, w) * h;
}
```

`fn name(params) ReturnType { body }`. Every parameter and the return type
are spelled out — no inference at API boundaries, by design. `pub` exports
the function to files that `@import` this one; within one file it changes
nothing, but a library's public API is exactly its `pub` declarations.

**Parameters are immutable.** Zig passes arguments as if by value (the
compiler may secretly pass large ones by reference — you can't observe the
difference), and assigning to a parameter is a compile error:

```zig
fn countDown(n: u32) void {
    n -= 1;        // error: cannot assign to constant
}
```

The idiom is to copy into a local:

```zig
fn countDown(n: u32) void {
    var x = n;     // mutable copy
    while (x > 0) : (x -= 1) {}
}
```

**Early return** is the preferred shape. Handle edge cases first and let
the main path read flat, instead of nesting else-ladders:

```zig
fn describe(n: i32) []const u8 {
    if (n == 0) return "zero";
    if (n < 0) return "negative";
    return "positive";
}
```

## Functions as values

Two ways to pass a function into another function:

```zig
// 1. Runtime function pointer — any matching function, decided at runtime.
fn applyTwice(f: *const fn (i32) i32, x: i32) i32 {
    return f(f(x));
}

// 2. Comptime parameter — the function is known at compile time; the
//    compiler generates a specialized copy and can inline the calls.
fn applyTwiceC(comptime f: fn (i32) i32, x: i32) i32 {
    return f(f(x));
}

const y = applyTwice(double, 3); // the name `double` coerces to *const fn
```

`std.sort`, comparators, and callback APIs throughout std use form 2.
There are no closures: a function can't capture surrounding variables. When
you need "function plus data", you pass the data separately (you'll see the
context-parameter pattern with `std.mem.sort` in module 08).

## Errors are values

Zig has no exceptions — nothing is thrown, nothing unwinds. A function that
can fail says so in its return type, and failure comes back as an ordinary
return value:

```zig
const MathError = error{ DivisionByZero, Overflow };

fn safeDivide(a: i32, b: i32) MathError!i32 {
    if (b == 0) return error.DivisionByZero;
    return @divTrunc(a, b);
}
```

Read `MathError!i32` as "either an error from MathError, or an i32". This
is an **error union**. An **error set** (`error{...}`) is a type much like
an enum: a closed list of named tags, no payload data attached.

What makes this stronger than C's "return -1" convention: the compiler
tracks it. Call a failable function and do nothing with the result?

```zig
safeDivide(10, 0);       // error: error union is ignored
_ = safeDivide(10, 0);   // error: error union is discarded
```

You must handle it — `try`, `catch`, or an explicit
`safeDivide(10, 0) catch {};` that says "I considered it and I don't
care". Ignoring an error is always a visible, greppable decision.

Two more pieces of error-set machinery:

```zig
// Merging: a function that can fail both ways returns the union of sets.
const CalcError = MathError || ParseError;

// Inference: `!i32` lets the compiler compute the set from the body.
fn checkedIncrement(n: u8) !u8 {
    if (n == 255) return error.Overflow; // invented on the spot
    return n + 1;
}
```

Inferred sets are great inside a module while code is churning. For public
APIs, prefer explicit sets: the contract is visible in the signature, and
callers can switch exhaustively.

## try: propagate

```zig
fn parseAndDivide(num: []const u8, den: []const u8) !i32 {
    const n = try std.fmt.parseInt(i32, num, 10);
    const d = try std.fmt.parseInt(i32, den, 10);
    return try divide(n, d);
}
```

`try f()` unwraps the success value or returns the error to *your* caller.
It's exactly sugar for `f() catch |err| return err`. The happy path reads
straight through, but every possible early exit is still marked — `try` is
where errors can leave the function, and you can see them all at a glance.

`try` only compiles if your own return type can hold the error — that's
how error sets stay honest across call chains.

## catch: recover

```zig
// Default value — stop the error, substitute something:
const port = std.fmt.parseInt(u16, input, 10) catch 8080;

// Capture and classify:
const result = parseAndDivide(a, b) catch |err| switch (err) {
    error.InvalidCharacter => return usage(),
    error.Overflow => return usage(),
    error.DivisionByZero => 0,
};
```

When the error set is concrete, that `switch` must be exhaustive — add
`error.Timeout` to the set next month and the compiler points at every
`catch |err| switch` you forgot to update. This is the payoff for declaring
sets instead of returning ints.

`catch unreachable` deserves its own paragraph: it means "if this errors,
panic in Debug/ReleaseSafe, undefined behavior in ReleaseFast". It is
defensible only when local logic *proves* the error impossible (dividing by
a constant 2, say). Near input, I/O, or allocation it's a smell — "can't
happen" errors are the ones that page you at 3am. When in doubt, `try`.

## errdefer: cleanup on the error path

You know `defer` runs at scope exit, success or failure. `errdefer` runs
**only when the function returns an error**:

```zig
fn dupePair(gpa: std.mem.Allocator, x: []const u8, y: []const u8) !Pair {
    const a = try gpa.dupe(u8, x);
    errdefer gpa.free(a);           // <- the whole trick

    const b = try gpa.dupe(u8, y);  // if THIS fails, a gets freed
    return .{ .a = a, .b = b };     // success: errdefer does not run
}
```

Why not plain `defer`? Because on success you're *handing `a` to the
caller* — freeing it would be a use-after-free waiting downstream. On
failure the caller only receives an error value, so nobody but you can free
`a`. `errdefer` expresses exactly that asymmetry. The discipline: every
`try`-acquired resource gets its `errdefer` on the next line, so the
function is leak-free after any prefix.

Deferred statements run in reverse declaration order (a stack), `defer` and
`errdefer` interleaved. And `errdefer` can capture the error being returned
— `errdefer |err| log.warn("failed: {t}", .{err});` — handy for logging.

Exercise 04 makes this concrete: `std.testing.allocator` fails any test
that leaks, and `std.testing.FailingAllocator` lets a test inject
`error.OutOfMemory` on exactly the Nth allocation. A missing `errdefer`
isn't a style nit there — it's a red test with a leak report.

## Errors vs optionals

Module 04 covers optionals fully; here's the working minimum: `?T` is
either a `T` or `null`, and `opt orelse fallback` unwraps with a fallback.

Choosing between them: use an **optional** when absence is a normal,
expected outcome with a single obvious meaning ("key not in map"). Use an
**error** when the caller did something wrong, or when there are several
distinct failure reasons worth telling apart. Rough std heuristic:
`HashMap.get` returns `?V`; `parseInt` returns `error{...}!T`.

Converting is one-liner territory in both directions:

```zig
// optional -> error: orelse takes any expression, including an error.
fn strictFind(s: []const u8, c: u8) error{NotFound}!usize {
    return std.mem.indexOfScalar(u8, s, c) orelse error.NotFound;
}

// error -> optional: catch collapses all failure reasons into null.
fn digitOrNull(c: u8) ?u8 {
    return parseDigit(c) catch null;
}
```

To branch on an error union when *both* outcomes involve real work, `if`
unwraps it like an optional, plus an error-capture arm:

```zig
if (parseDigit(c)) |d| {
    total += d;
} else |err| {
    std.debug.print("skipping: {t}\n", .{err});
}
```

Finally, `anyerror` is the global superset of every error set in the
program. Any error value coerces into it, which makes it useful for
plumbing (loggers, retry helpers) — and imprecise everywhere else, since
the compiler can no longer check switches exhaustively (you're forced into
an `else` arm). Keep concrete sets at the edges of your APIs.

## Gotchas

- **Unused parameters are compile errors**, same as unused locals. Discard
  with `_ = x;` if a signature forces a parameter on you. (The exercise
  stubs do this so they compile — delete the discards as you implement.)
- **You can't `_ =` an error union or an error value.** "error union is
  discarded" means use `try`, `catch`, or `... catch {};`. Even discarding
  is explicit.
- **`try` needs a compatible return type.** Using `try` in a function
  returning plain `i32` won't compile — either handle the error there with
  `catch`, or let the function return `!i32`.
- **`errdefer` placement matters.** It must come *after* the acquisition
  succeeds and *before* the next thing that can fail. Registering cleanup
  before acquiring frees garbage; registering it too late leaves a gap
  where a failure leaks.
- **`errdefer` covers error *returns*, not every scope exit** — and it only
  fires for errors leaving the scope it's declared in, not errors you
  already handled with `catch`.
- **Error sets carry no payload.** `error.InvalidChar` can't tell you
  *which* char at *which* offset. When callers need details, the pattern is
  an out-parameter or a diagnostics struct alongside the error (std does
  this in a few places). Don't fight it by encoding data into error names.
- **Signed division needs `@divTrunc`** (or `@divFloor`/`@divExact`). Plain
  `/` on runtime signed integers is a compile error because rounding
  direction is ambiguous.
- **`expectEqual(expected, actual)`** — expected first. Backwards
  arguments make failure messages lie to you.
- **`catch unreachable` is UB in ReleaseFast.** Your Debug-mode panic
  safety net is not there in release builds. Treat it as a proof
  obligation, not a convenience.

## Exercises

Run each with `zig test <file>` from this directory (or `../check.sh 03`).
All tests start red; make them green in order.

| File                    | You implement                                                       |
| ----------------------- | ------------------------------------------------------------------- |
| `01_functions.zig`      | average, countDigits, clamp, applyTwice, compose, applyN            |
| `02_error_sets.zig`     | safeDivide, parseDigit, evalDigitDivision, checkedIncrement         |
| `03_try_catch.zig`      | parseAndDivide, divideOr, classify, halveEven                       |
| `04_errdefer.zig`       | dupeUpperNoDigits, dupePair (leak-checked, injected alloc failure)  |
| `05_error_patterns.zig` | strictIndexOf, digitOrNull, describeDigit, isRecoverable, firstDigitValue |

Reference solutions live in `../solutions/03_functions_errors/` — same
filenames. Wrestle with the leak reports in 04 before peeking; reading a
`[DebugAllocator] memory leaked` trace back to the missing `errdefer` is
the actual lesson.
