# Module 11: Advanced Patterns

You know the language. This module is about the handful of patterns that make
Zig code fast to write and fast to read — the moves you reach for on autopilot
when an Advent of Code puzzle drops at midnight. None of it is new syntax;
all of it is arrangement: how to shape iterators, state machines, bit
manipulation, comptime reflection, and allocation so the solution flows out
in one pass.

## What you'll learn

- The `next() ?T` iterator convention and why the entire standard library
  is built on it
- Tagged unions as state machines, and labeled `switch` with `continue :sw`
  for character-by-character parsers
- Bit-level tools: `packed struct`, `@bitCast`, `@popCount`, `@clz`/`@ctz`,
  and using a `u64` as a set of 64 flags
- Comptime reflection: `@typeInfo` + `inline for` + `@field` to write one
  function that works on any struct
- Allocation habits that keep hot loops off the heap, and how to measure
  with the 0.16 `Io` clock

## Iterators: one method, one convention

Zig has no iterator interface. It has a convention: a struct with a `next`
method returning an optional. `null` means done.

```zig
const Countdown = struct {
    n: u32,

    pub fn next(self: *Countdown) ?u32 {
        if (self.n == 0) return null;
        self.n -= 1;
        return self.n;
    }
};

var it: Countdown = .{ .n = 3 };
while (it.next()) |v| {
    std.debug.print("{d} ", .{v}); // 2 1 0
}
```

That `while (it.next()) |v|` shape is everywhere: `std.mem.tokenizeScalar`,
`std.mem.splitScalar`, hash map `.iterator()`, directory listings. When you
write your own, you get the same call-site ergonomics for free.

Two details worth internalizing:

- The iterator holds all its cursor state in its own fields, so you can pass
  it around, copy it to "peek", or restart by rebuilding it.
- Make it generic by wrapping the struct in a type-returning function:

```zig
pub fn Windows(comptime T: type) type {
    return struct {
        data: []const T,
        size: usize,
        index: usize = 0,

        pub fn next(self: *@This()) ?[]const T {
            if (self.index + self.size > self.data.len) return null;
            const w = self.data[self.index..][0..self.size];
            self.index += 1;
            return w;
        }
    };
}
```

Overlapping windows and all-pairs iteration cover a startling fraction of AoC
part-twos. Write them once here; paste them forever.

## State machines: tagged unions and labeled switch

A tagged union is a state machine the compiler checks for you. Each variant
is a state, its payload is the data that only exists in that state:

```zig
const Connection = union(enum) {
    idle,
    connecting: u32,   // retry count
    open: Socket,      // only exists while open
};
```

Switch with pointer capture to mutate the payload in place, and assign a new
variant to transition:

```zig
switch (conn.*) {
    .connecting => |*retries| {
        retries.* += 1;
        if (retries.* > 3) conn.* = .idle;
    },
    else => {},
}
```

For parsing, Zig has a sharper tool: the labeled switch. `continue :sw value`
jumps back to the switch with a new operand — each arm is a state, each
`continue` a transition:

```zig
const State = enum { start, digits };
var i: usize = 0;

sw: switch (State.start) {
    .start => {
        if (i >= input.len) break :sw;
        continue :sw .digits;
    },
    .digits => {
        // consume, then either continue :sw .start or break :sw
        i += 1;
        continue :sw .start;
    },
}
```

This is how the Zig tokenizer itself is written. It compiles to direct jumps
between states — no loop variable holding "current state", no re-checking a
condition at the top of a `while`. When a puzzle says "process the input one
character at a time, and what a character means depends on what came before",
this is the shape.

## Bit tricks

`packed struct` with an explicit backing integer gives you named bits with a
guaranteed layout — first field is bit 0:

```zig
const Flags = packed struct(u8) {
    up: bool = false,     // bit 0
    down: bool = false,   // bit 1
    _pad: u6 = 0,
};

const f: Flags = @bitCast(@as(u8, 0b10)); // f.down == true
const raw: u8 = @bitCast(f);              // and back, for free
```

For sets of small integers (visited node IDs, seen letters, active bits in a
grid row), a bare `u64` beats a hash map by orders of magnitude:

```zig
bits |=  @as(u64, 1) << i;   // insert i
bits &= ~(@as(u64, 1) << i); // remove i
(bits >> i) & 1 == 1         // contains i
@popCount(bits)              // count
```

The builtins to know:

- `@popCount(x)` — how many bits are set
- `@ctz(x)` — trailing zeros = index of the lowest set bit
- `@clz(x)` — leading zeros; highest set bit of a `u64` is `63 - @clz(x)`
- `x & (x - 1)` — clears the lowest set bit (also: power-of-two test)

Combine the last two and you can iterate set bits directly, visiting only
the ones that are on:

```zig
var b = bits;
while (b != 0) {
    const i: u6 = @intCast(@ctz(b));
    // ... use bit index i ...
    b &= b - 1;
}
```

## Comptime reflection

`@typeInfo(T)` hands you a description of any type as ordinary data. For
structs, `.@"struct".fields` is a comptime slice of field descriptors. Loop
it with `inline for` (unrolled at compile time) and read fields by name with
`@field`:

```zig
fn fieldReport(value: anytype) void {
    const T = @TypeOf(value);
    inline for (@typeInfo(T).@"struct".fields) |field| {
        std.debug.print("{s} = {any}\n", .{ field.name, @field(value, field.name) });
    }
}
```

That one function works on every struct you will ever define. Branch on
field types at comptime to specialize behavior:

```zig
switch (@typeInfo(field.type)) {
    .int => // sum it, print it as a number, ...
    else => {},
}
```

This is how `std.json`, `std.fmt`'s `{any}`, and `std.meta.eql` are built.
For AoC it means: define a bare struct for each puzzle's record type and get
debug printing, comparison, and parsing scaffolding generically.

## Performance habits

Three habits cover most of the gap between a sluggish solution and a fast one.

**Reuse one buffer.** `allocPrint` inside a loop means an alloc and a free
per iteration. A fixed writer over a stack buffer costs nothing:

```zig
var buf: [256]u8 = undefined;
var w: std.Io.Writer = .fixed(&buf);
try w.print("{d},{d}", .{ x, y });
const s = w.buffered(); // slice of buf, no heap
```

(`std.fmt.bufPrint(&buf, ...)` is the one-shot version.)

**Reach for `std.mem` before writing a loop.** `countScalar`, `indexOfScalar`,
`eql`, `startsWith`, `trim`, `sort` — they are correct, readable, and often
vectorized. Also `@memset` / `@memcpy` for bulk fills and copies.

**Arena when everything dies together.** Parse a puzzle input into a pile of
slices and structs? Allocate them all from one
`std.heap.ArenaAllocator` and free the lot with one `deinit`. Use the
leak-checked gpa (or `std.testing.allocator`) for long-lived data where you
want to be told about mistakes. Because your functions take a plain
`std.mem.Allocator`, the caller makes this choice — not the function.

**Measuring.** `std.time.Timer` from older tutorials is gone in 0.16. Timing
goes through the `Io` clock:

```zig
const t0 = std.Io.Clock.awake.now(io);
// ... work ...
const elapsed = t0.durationTo(std.Io.Clock.awake.now(io));
std.debug.print("{f}\n", .{elapsed}); // e.g. "354ns", "1.2ms"
```

Measure in `ReleaseFast` (`zig test -O ReleaseFast file.zig`) before drawing
conclusions — Debug builds distort everything. And never write a test that
asserts on a duration; assert on results, print the timings.

## Gotchas

- An iterator's `next` must take `*Self`, not `Self` — it mutates the
  cursor. Consequently the iterator variable must be `var`, not `const`.
- Slices returned by an iterator (windows, tokens) point into the original
  data. Fine to read; invalid if the underlying buffer is freed or reused.
- In a labeled switch, `continue :sw .state` needs the switch operand type
  to be comptime-trackable — an `enum` works perfectly; keep per-state data
  in locals outside the switch.
- `@as(u64, 1) << i` — without the `@as`, the `1` is a `comptime_int` and
  the shift may not have the width you meant.
- `@ctz` on a `u64` returns a `u7` (it must be able to say 64 when the input
  is zero). Check for zero, then `@intCast` down.
- `@typeInfo` variant names are lowercase in 0.16 and quoted where they
  collide with keywords: `.@"struct"`, `.@"enum"`, but plain `.int`,
  `.float`, `.pointer`. Old code with `.Struct` will not compile.
- `inline for` bodies must be comptime-compatible: you can `return` from
  inside one, but you cannot `break` out of it based on a runtime condition
  and keep comptime-only values flowing.
- `std.meta.eql` compares slice fields by pointer and length, not content.
  Two identical strings in different buffers compare unequal.
- A discarded parameter that already appears in another parameter's type
  (like `a` in `fn f(a: anytype, b: @TypeOf(a))`) must NOT be discarded with
  `_ = a;` — Zig calls that a pointless discard and errors.

## Exercises

Work through them in order. Each file compiles as given; make the tests pass.
Solutions live in `solutions/11_advanced_patterns/`.

1. `01_iterators.zig` — write Range, Windows, and Pairs iterators and consume
   them with `while (it.next()) |v|`.
2. `02_state_machine.zig` — a tagged-union traffic light, then a labeled-switch
   parser that evaluates `"12+34-5"` left to right.
3. `03_bits.zig` — packed struct round-trips, a `u64`-backed Set64, and
   iteration over set bits with `@ctz`.
4. `04_reflection_print.zig` — a debug formatter, generic equality, and a
   field summer that work on any struct via `@typeInfo`.
5. `05_perf_habits.zig` — replace per-iteration allocation with one buffer,
   hand loops with `std.mem`, and time both with the `Io` clock.

Run each with `zig test <file>.zig`. When everything is green, you have the
complete AoC toolkit: parsing (module by module), data structures, and now
the patterns that tie a solution together.
