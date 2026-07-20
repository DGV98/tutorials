//! Exercise 02: alloc/free, create/destroy
//!
//! Concepts: std.mem.Allocator as a value you pass around, alloc(T, n) and
//! free for slices, create(T) and destroy for single items, the
//! "defer free right after alloc" habit, @memset, and why
//! std.testing.allocator catches your bugs.
//!
//! Run: zig test 02_alloc_free.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Memory

const std = @import("std");
const Allocator = std.mem.Allocator;
const expectEqual = std.testing.expectEqual;

// In Zig, nothing heap-allocates behind your back. Any function that needs
// heap memory takes an `Allocator` parameter — a plain value you pass around,
// like any other argument. That one convention is why you can read a Zig
// function's signature and know whether it allocates.
//
// The core interface:
//
//   const buf = try alloc.alloc(u8, 100); // []u8, 100 bytes, may fail (OOM)
//   defer alloc.free(buf);                // give it back — same allocator!
//
//   const p = try alloc.create(Point);    // *Point, ONE item, uninitialized
//   defer alloc.destroy(p);               // counterpart of create
//
// alloc/free work on slices; create/destroy work on single items. Don't mix
// the pairs.
//
// Every test in this file uses std.testing.allocator. It tracks every
// allocation, and if the test ends with memory still outstanding, the test
// FAILS with a stack trace of the leaked allocation. It also detects
// double-free and use-after-free (the freed memory is poisoned). It is the
// safety net for this entire module: if your code is wrong about memory,
// the test tells you. Once a test is green, try commenting out a `defer
// alloc.free(...)` line and re-run to see what a leak report looks like.

/// Allocate a slice of `n` bytes, all set to zero.
///
/// The CALLER owns the result and must free it (see the tests). `alloc.alloc`
/// returns UNINITIALIZED memory — in Debug builds it's filled with 0xAA bytes
/// precisely so you notice when you forget to initialize. Use
/// `@memset(slice, value)` to fill it.
fn makeZeroed(alloc: Allocator, n: usize) ![]u8 {
    const buf = try alloc.alloc(u8, n);
    @memset(buf, 0);
    return buf;
}

test "makeZeroed allocates a zero-filled slice" {
    const alloc = std.testing.allocator;

    const buf = try makeZeroed(alloc, 8);
    // Habit to build NOW: the moment an allocation succeeds, write the defer
    // that releases it. The two lines travel as a pair.
    defer alloc.free(buf);

    try expectEqual(@as(usize, 8), buf.len);
    for (buf) |byte| try expectEqual(@as(u8, 0), byte);
}

const Counter = struct {
    count: u32,
    step: u32,

    fn tick(self: *Counter) void {
        self.count += self.step;
    }
};

/// Heap-allocate a single Counter, initialized to count 0 with the given step.
///
/// `create` hands back a `*Counter` pointing at UNINITIALIZED memory — you
/// must fill in every field (assigning a whole struct literal with `.*` is
/// the cleanest way). The caller destroys it.
fn createCounter(alloc: Allocator, step: u32) !*Counter {
    const counter = try alloc.create(Counter);
    counter.* = .{ .count = 0, .step = step };
    return counter;
}

test "createCounter returns a live heap object" {
    const alloc = std.testing.allocator;

    const counter = try createCounter(alloc, 3);
    defer alloc.destroy(counter); // create/destroy, alloc/free — matched pairs

    counter.tick();
    counter.tick();
    try expectEqual(@as(u32, 6), counter.count);
}

/// Compute 0*0 + 1*1 + ... + (n-1)*(n-1) using a heap-allocated scratch
/// slice of u64 (allocate it, fill slot i with i*i, sum the slice).
///
/// This is deliberately a roundabout way to sum squares — the POINT is the
/// lifecycle: memory that is allocated, used, and freed entirely INSIDE one
/// function. `defer alloc.free(scratch)` right after the alloc guarantees the
/// scratch is released on every path out of the function, including the early
/// `try` failure paths. If you forget the defer, the leak report from
/// std.testing.allocator will point at the exact alloc call.
fn sumOfSquares(alloc: Allocator, n: usize) !u64 {
    const scratch = try alloc.alloc(u64, n);
    defer alloc.free(scratch);

    for (scratch, 0..) |*slot, i| {
        slot.* = @as(u64, i) * @as(u64, i);
    }

    var total: u64 = 0;
    for (scratch) |x| total += x;
    return total;
}

test "sumOfSquares cleans up its own scratch memory" {
    // No defer here: sumOfSquares allocates AND frees internally. If it
    // leaks, this test fails even though every expectEqual passes.
    try expectEqual(@as(u64, 0 + 1 + 4 + 9 + 16), try sumOfSquares(std.testing.allocator, 5));
    try expectEqual(@as(u64, 0), try sumOfSquares(std.testing.allocator, 0));
}
