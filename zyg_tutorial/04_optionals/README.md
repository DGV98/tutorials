# 04 — Optionals

In C, "there might not be a value here" is spelled `NULL`, and the compiler
lets you dereference it anyway. In Zig, absence is a type: `?i32` is "an `i32`
or nothing", and the compiler refuses to let you touch the payload until you
have handled the nothing case. This module teaches you every way to do that.

## What you'll learn

- Declaring `?T`, assigning `null`, testing with `== null`
- `orelse` for defaults and `.?` for force-unwrap (and when each is right)
- `if (opt) |v|` payload capture, the expression form, and `|*v|` for mutation
- `while (it.next()) |v|` — the loop that IS Zig's iterator protocol
- Optional pointers `?*T`, optional struct fields, and safe chained lookups

## Optionals vs error unions

You already know `!T` from module 3. The two look similar — both wrap a value
that might not be there — but they answer different questions:

- `?T` — **expected absence**. "Find the first even number" on a slice of odd
  numbers didn't fail; there just isn't one. Nothing went wrong.
- `!T` — **failure**. `parseInt("abc")` was asked to do a job and couldn't.
  Something went wrong, and the error value says what.

A lookup that misses returns `?T`. A parse that chokes returns `!T`. Pick the
one that matches the *meaning*, and callers instantly know whether to reach
for `orelse` or `try`. (Exercise 3 mixes both in one function; exercise 4
shows how to convert one into the other when a miss *is* a failure for you.)

## The basics: `?T`, `null`, `orelse`, `.?`

```zig
var maybe: ?i32 = null; // starts empty
maybe = 42;             // a plain i32 coerces into ?i32
maybe = null;           // and you can empty it again

const present = maybe != null; // bool; == null works too
```

To get the payload out, the workhorse is `orelse`: it unwraps, or evaluates
the right-hand side if the optional is null.

```zig
const port = user_port orelse 8080;       // default value
const item = lookup(key) orelse return;   // bail out of the function
const x = a orelse b orelse 0;            // chains; first non-null wins
```

The right-hand side of `orelse` can be any expression *or* a control-flow
statement (`return`, `break`, `continue`) — that's what makes it useful.

`.?` is force-unwrap: `maybe.?` means "I know this is not null". If you're
wrong, the program panics in safe builds (`attempt to use null value`) — which
is precisely the point. It is a loud, immediate crash at the site of your
wrong assumption instead of a silent bad pointer three modules later. Use `.?`
only when nullness is impossible by construction and you'd *want* the crash;
otherwise use `orelse` or `if`.

## Unwrapping with `if`

`if` can capture the payload, giving it a name that only exists where it's
valid:

```zig
if (maybe) |v| {
    // v is a plain i32 here
} else {
    // maybe was null; there is no v
}

// Expression form — both branches produce a value:
const label = if (maybe) |v| bigger: {
    break :bigger if (v > 100) "big" else "small";
} else "absent";
```

One crucial detail: `|v|` is a **copy** of the payload. Mutating `v` does not
touch the optional. To mutate in place, capture a pointer with `|*v|`:

```zig
var count: ?i32 = 10;
if (count) |*v| v.* += 1; // count is now 11
```

## `while` + optionals: the iterator protocol

`while` has the same capture syntax, and it re-evaluates the condition each
iteration. That combination is how all iteration over "streams of things"
works in Zig — there is no iterator interface, just the convention *"a `next()`
method that returns `?T`, null means done"*:

```zig
var it = std.mem.tokenizeScalar(u8, "3 14 15", ' ');
while (it.next()) |token| {
    // token: []const u8 — "3", then "14", then "15", then the loop ends
}
```

`std.mem.tokenizeScalar` returns an iterator struct; `it.next()` returns
`?[]const u8`. The loop calls it, unwraps, runs the body, repeats, and exits
on null. You'll meet this exact shape again with HashMap iterators (module 8)
and when you write your own iterators (module 11) — exercise 3 has you build
one now, so the later ones hold no surprises.

For walking a `cur = cur.next`-style chain, use the continue expression so
the advance can't be forgotten:

```zig
var cur: ?*Node = head;
while (cur) |node| : (cur = node.next) {
    total += node.value;
}
```

## Optional pointers and optional fields

`?*T` is the honest version of C's nullable pointer — and it costs nothing.
Pointers can never be zero in Zig, so the compiler uses address zero to mean
null: `@sizeOf(?*T) == @sizeOf(*T)`. You get compile-checked null handling
for free. This is why self-referencing structures are spelled with `?*`:

```zig
const Node = struct {
    value: i32,
    next: ?*Node = null, // = null default: leaf nodes need no ceremony
};
```

Optional fields model "this part may be missing" (think JSON with absent
keys). Reaching through several layers means unwrapping at each step — and
when a miss should be an error to *your* caller, `orelse return error.X`
converts absence into failure in one line:

```zig
fn getEmail(user: User) ![]const u8 {
    const profile = user.profile orelse return error.NoProfile;
    return profile.email orelse return error.NoEmail;
}
```

That line is the bridge between this module and the last one: the callee said
"expected absence", you decided "for me that's a failure", and the type system
tracked the conversion.

## Gotchas

- **`.?` panics on null.** It's an assertion, not a safe accessor. Reach for
  `orelse` first; write `.?` only where null would be a bug worth crashing on.
- **`|v|` is a copy.** `if (opt) |v| v += 1` doesn't compile (`v` is const),
  and copying to a `var` then mutating changes only the copy. Use `|*v|` and
  `v.*` to mutate through the optional.
- **Forgetting to advance in a `while` chain walk.** `while (cur) |node|`
  with no `: (cur = node.next)` and no reassignment in the body loops forever
  — the condition re-checks the same `cur`. Prefer the `: (...)` form.
- **Comparing wrapped values.** `opt == 5` works (the `5` coerces to `?i32`,
  and null compares unequal to everything but null). Handy in tests; in real
  code an explicit unwrap usually reads better.
- **`orelse` vs `catch`.** Same shape, different wrapper: `orelse` handles
  the null of a `?T`, `catch` handles the error of a `!T`. Mixing them up is
  a compile error, which tells you which kind of "might not be there" you
  actually have.

## Exercises

Work them in order; each file has the details in its header comment.

1. `01_optional_basics.zig` — declare, default, and force-unwrap:
   `firstEven` over a slice and `valueOrDefault`.
2. `02_unwrap_if.zig` — `if` capture in statement and expression form;
   in-place mutation through `*?i32` with `|*v|`.
3. `03_while_optionals.zig` — the iterator protocol: sum the numbers in a
   string with `tokenizeScalar` + `parseInt`, then write your own countdown
   iterator.
4. `04_optional_chains.zig` — `next: ?*Node` list traversal, optional fields,
   and `orelse return error.X`.

```sh
zig test 01_optional_basics.zig   # red → implement → green
```
