//! Solution 01: Functions

const std = @import("std");

fn double(x: i32) i32 {
    return x * 2;
}

fn addTen(x: i32) i32 {
    return x + 10;
}

pub fn average(a: i32, b: i32) i32 {
    // Signed integer division must state its rounding mode; plain `/`
    // is a compile error for runtime-signed operands.
    return @divTrunc(a + b, 2);
}

fn countDigits(n: u32) u32 {
    // Parameters are immutable — copy into a local var to mutate.
    var x = n;
    var count: u32 = 1;
    while (x >= 10) {
        x /= 10;
        count += 1;
    }
    return count;
}

fn clamp(x: i32, lo: i32, hi: i32) i32 {
    // Early returns keep the edge cases out of the way; no else-ladder.
    if (x < lo) return lo;
    if (x > hi) return hi;
    return x;
}

fn applyTwice(f: *const fn (i32) i32, x: i32) i32 {
    // f is an ordinary runtime value — call it like any function.
    return f(f(x));
}

fn compose(f: *const fn (i32) i32, g: *const fn (i32) i32, x: i32) i32 {
    // No closures in Zig, so "compose" takes its argument immediately.
    return g(f(x));
}

fn applyN(comptime f: fn (i32) i32, x: i32, n: u32) i32 {
    // f is comptime-known: the compiler emits a specialized applyN per
    // function, and calls to f can be inlined — no pointer indirection.
    var result = x;
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        result = f(result);
    }
    return result;
}

test "average" {
    try std.testing.expectEqual(5, average(4, 6));
    try std.testing.expectEqual(-5, average(-2, -8));
    try std.testing.expectEqual(3, average(3, 4)); // truncates toward zero
}

test "countDigits" {
    try std.testing.expectEqual(1, countDigits(0));
    try std.testing.expectEqual(1, countDigits(7));
    try std.testing.expectEqual(3, countDigits(100));
    try std.testing.expectEqual(5, countDigits(12345));
}

test "clamp" {
    try std.testing.expectEqual(5, clamp(5, 1, 10)); // inside: unchanged
    try std.testing.expectEqual(1, clamp(-3, 1, 10)); // below: lo
    try std.testing.expectEqual(10, clamp(99, 1, 10)); // above: hi
}

test "applyTwice" {
    try std.testing.expectEqual(12, applyTwice(double, 3));
    try std.testing.expectEqual(25, applyTwice(addTen, 5));
    // &double works too — the name alone already coerces to the pointer.
    try std.testing.expectEqual(8, applyTwice(&double, 2));
}

test "compose" {
    try std.testing.expectEqual(16, compose(double, addTen, 3)); // addTen(double(3))
    try std.testing.expectEqual(26, compose(addTen, double, 3)); // double(addTen(3))
}

test "applyN" {
    try std.testing.expectEqual(32, applyN(double, 1, 5));
    try std.testing.expectEqual(7, applyN(addTen, 7, 0));
    try std.testing.expectEqual(31, applyN(addTen, 1, 3));
}
