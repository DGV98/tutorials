# Module 9: Comptime and Generics

Other languages bolt on three separate features for compile-time programming:
generics (Java, Go), templates (C++), and macros (C, Rust). Zig has one answer
to all three: **comptime** — you write ordinary Zig code and mark it to run at
compile time. No separate template language, no macro syntax, no type-level
programming DSL. If you can write a loop, you can write a generic.

## What you'll learn

- `comptime T: type` parameters and how the compiler monomorphizes them
- `anytype` parameters, `@TypeOf`, `@typeName`, and duck typing
- Functions that return types — the pattern behind `std.ArrayList`
- `comptime` blocks and vars: building lookup tables at compile time
- `inline for` and why comptime-only values need it
- Reflection with `@typeInfo`, `std.meta.fields`, and `@field`
- `@compileError` for readable diagnostics instead of template noise

## Types are values

At compile time, types are ordinary values. You can store them in constants,
pass them to functions, compare them with `==`, and return them:

```zig
const T = i32;              // a constant holding a type
const same = (T == i32);    // true — types compare with ==
var x: T = 5;               // use it anywhere a type goes
```

The only restriction: type values exist **only at compile time**. You can't
put a `type` in a runtime variable, a struct field that outlives compilation,
or an array you index with a runtime value. This restriction is what makes
everything else in this module work — the compiler always knows which concrete
type it's dealing with.

## Comptime parameters: generic functions

Mark a parameter `comptime` and every call site must supply a compile-time
known argument. Pass a type and you have a generic function:

```zig
fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}

const bigger = max(i32, 3, 7);   // 7
const wider = max(f64, 1.5, 0.2); // 1.5
```

There is no trait bound or interface declaration. `a > b` simply has to
compile for whatever `T` you pass. Pass a struct and you get a compile error
pointing at the `>` — checking happens at instantiation, like C++ templates,
but the error is plain Zig, not template hieroglyphics.

**Monomorphization:** each distinct `T` stamps out a separate copy of the
function. `max(i32, ...)` and `max(f64, ...)` are two different functions in
the binary, each fully type-checked and optimized for its concrete type.
There's no boxing, no vtable, no runtime dispatch — same cost as writing the
two functions by hand.

## anytype: inferred generics and duck typing

When you don't want to name the type at the call site, take `anytype`:

```zig
fn double(x: anytype) @TypeOf(x) {
    return x + x;
}

_ = double(@as(i32, 21)); // 42, an i32
_ = double(@as(f32, 1.5)); // 3.0, an f32
```

`@TypeOf(x)` recovers the type; it's usable even in the return type because
parameters are in scope there. `@typeName(T)` gives you the type's name as a
string — handy for error messages.

`anytype` is duck typing: the body compiles per-instantiation, so `x.len`
works for any argument that has a `.len` — slices, arrays, or your own struct
with a `len` field. When a requirement isn't met, the default error can land
deep inside your function. Check up front and fail with your own message:

```zig
fn lengthOf(x: anytype) usize {
    const T = @TypeOf(x);
    if (@typeInfo(T) != .@"struct" or !@hasField(T, "len"))
        @compileError("lengthOf: " ++ @typeName(T) ++ " has no .len field");
    return x.len;
}
```

`@compileError` aborts compilation with your string — but only if the
compiler actually reaches it. Analysis is lazy: a branch that's never taken
for a given `T` is never analyzed, which is exactly why you can write
type-dependent branches at all.

## Functions that return types: generic structs

This is the whole secret behind `std.ArrayList(u8)`: `ArrayList` is just a
function that takes a `type` and returns a `type`.

```zig
fn Pair(comptime A: type, comptime B: type) type {
    return struct {
        first: A,
        second: B,
    };
}

const P = Pair(i32, bool);      // a brand-new struct type
const p = P{ .first = 1, .second = true };
```

The returned struct can have methods, and those methods can refer to `A` and
`B` because the struct closes over the function's comptime parameters.
`@This()` names the struct being defined (it has no name of its own).

Two guarantees make this workable:

- **Memoization:** calling `Pair(i32, bool)` twice returns the *same* type.
  Generic instantiations are cached, so `Pair(i32, bool) == Pair(i32, bool)`.
- **Convention:** type-returning functions are named `TitleCase` like types,
  because that's what they produce.

Since 0.15, std containers are **unmanaged**: the struct doesn't store an
allocator; every allocating method takes one. Follow that convention in your
own generic containers, and provide a decl literal instead of an `init`
function where possible:

```zig
pub const empty: Self = .{ .items = .empty };
// usage: var stack: Stack(i32) = .empty;
```

## comptime blocks, vars, and lookup tables

Any expression can be forced to compile time with the `comptime` keyword. A
classic use: compute a table once during compilation and ship it as constant
data in the binary — zero runtime cost.

```zig
const fib: [16]u64 = blk: {
    var t: [16]u64 = undefined;
    t[0] = 0;
    t[1] = 1;
    for (2..t.len) |i| t[i] = t[i - 1] + t[i - 2];
    break :blk t;
};
```

The block initializes a global `const`, so it runs at compile time
automatically — mutation, loops, and all. It's normal Zig; the only
difference is *when* it runs. Inside functions, `comptime var` gives you a
mutable compile-time variable, and `comptime { ... }` forces a whole block.

Strings work too. At comptime, `++` concatenates and `**` repeats:

```zig
const banner = "=" ** 20;            // "===...=" as a comptime array
const msg = "error: " ++ @typeName(i32);
```

And you can assert facts about your program at compile time — a top-level
`comptime` block runs during compilation of the file:

```zig
comptime {
    std.debug.assert(@sizeOf(Header) == 16); // build fails if layout drifts
}
```

## inline for

Comptime-only values (types, struct field descriptions) can't flow through a
runtime loop — the loop variable would have to hold a `type` at runtime.
`inline for` unrolls the loop at compile time, so each iteration gets its own
comptime-known value:

```zig
fn totalSize(comptime types: []const type) usize {
    var total: usize = 0;
    inline for (types) |T| total += @sizeOf(T);
    return total;
}
```

Each unrolled iteration is analyzed separately, so the body can even do
different things per element (branch on the type, call different functions).
Don't reach for `inline for` on ordinary data — it bloats code and the
optimizer is better at that judgment; use it only when the iteration variable
*must* be comptime-known.

## Reflection: @typeInfo, std.meta, @field

`@typeInfo(T)` returns a `std.builtin.Type` — a tagged union describing the
type. In 0.16 its variants are lowercase (and keywords are quoted):
`.int`, `.float`, `.pointer`, `.@"struct"`, `.@"enum"`, `.@"union"`, `.@"fn"`.

```zig
switch (@typeInfo(T)) {
    .int => |info| ..., // info.bits, info.signedness
    .@"struct" => |info| ..., // info.fields, info.decls
    else => @compileError("unsupported: " ++ @typeName(T)),
}
```

For structs, `info.fields` (or the shortcut `std.meta.fields(T)`) is a slice
of field descriptions: `.name`, `.type`, default value, alignment. Combine it
with `inline for` and `@field(value, "name")` — field access by comptime
string — and you can process *any* struct:

```zig
fn sumIntFields(value: anytype) i64 {
    var total: i64 = 0;
    inline for (std.meta.fields(@TypeOf(value))) |f| {
        if (@typeInfo(f.type) == .int)
            total += @intCast(@field(value, f.name));
    }
    return total;
}
```

This is not a party trick — it's how `std.json` serializes any struct you
hand it, how `std.fmt` prints `{any}`, and how `std.meta.eql` compares
arbitrary values. Serialization, ORMs, CLI argument parsers: in Zig they're
all "inline for over fields" underneath, with no code generation step and no
runtime reflection cost.

## Gotchas

- **Unused parameters are compile errors.** Stub code must discard them:
  `_ = x;`. Same for unused locals and captures.
- **`@typeInfo` variant names changed in 0.15.** Old code says `.Struct`,
  `.Int`; 0.16 says `.@"struct"`, `.int`. Translate on sight when reading
  pre-0.15 examples.
- **Instantiation-time errors.** A generic function with a type bug compiles
  fine until someone calls it with the offending type — Zig analyzes lazily.
  Write tests that instantiate every combination you claim to support.
- **Function calls aren't comptime just because their arguments are.**
  `if (!supportsLen(T)) @compileError(...)` fires for *every* type: the call
  is a runtime expression, so both branches get analyzed. Force it —
  `if (comptime !supportsLen(T))` — and the not-taken branch is skipped.
  Builtins like `@typeInfo` and `@hasField` are comptime-known on their own.
- **`comptime var` doesn't leak to runtime.** You can't take a runtime
  pointer to one or mutate it from runtime code. Compute at comptime, then
  copy the result into a `const` (arrays returned by value are fine).
- **A `return` inside `comptime { ... }` can't return from a runtime call.**
  Use a labeled block: `return comptime blk: { ... break :blk result; };`
- **Slices don't support `==`.** Reflection-based equality has to
  special-case pointers/slices (compare `.ptr` and `.len`, or the contents —
  decide which you mean). `std.meta.eql` compares slices by pointer identity.
- **`std.mem.eql` vs `std.meta.eql`.** The former compares slice *contents*
  element by element; the latter walks struct fields. Easy to mix up.
- **Monomorphization multiplies code.** Every `T` is a fresh copy of the
  function. Usually fine; worth knowing when you instantiate with dozens of
  types in a hot build.

## Exercises

Work through them in order; each builds on the last. Run with
`zig test NN_name.zig` — the files compile as given, and the tests fail until
you replace the `// TODO:` stubs.

1. `01_comptime_params.zig` — generic `max`, `swap`, and `sum` with
   `comptime T: type`; monomorphization.
2. `02_anytype.zig` — `anytype`, `@TypeOf`, `@typeName`, duck typing, and
   friendly `@compileError` diagnostics.
3. `03_generic_types.zig` — build `Stack(T)` (unmanaged, 0.16-style) and
   `Pair(A, B)`; type memoization.
4. `04_comptime_eval.zig` — comptime lookup tables, string building,
   `inline for`, comptime assertions.
5. `05_reflection.zig` — `@typeInfo` + `inline for` over fields, `@field`,
   a generic `eql`, mutation through reflection.

Solutions live in `solutions/09_comptime_generics/` — same filenames.
