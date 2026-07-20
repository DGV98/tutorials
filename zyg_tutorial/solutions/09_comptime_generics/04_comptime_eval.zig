//! Comptime evaluation: tables, strings, inline for, assertions — SOLUTION
//!
//! Concepts: comptime blocks and vars, computing lookup tables at compile
//! time, comptime string manipulation with ++, inline for, compile-time
//! assertions with @compileError.
//!
//! Run: zig test 04_comptime_eval.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#comptime

const std = @import("std");

comptime {
    std.debug.assert(@sizeOf(u64) == 8);
}

/// Returns [ 1, 2, 4, 8, ... ] — the first n powers of two.
fn powersOfTwo(comptime n: usize) [n]u64 {
    var result: [n]u64 = undefined;
    var value: u64 = 1;
    for (&result) |*slot| {
        slot.* = value;
        value *= 2;
    }
    return result;
}

/// Returns the first n Fibonacci numbers: [ 0, 1, 1, 2, 3, 5, ... ].
fn fibTable(comptime n: usize) [n]u64 {
    var result: [n]u64 = undefined;
    if (n > 0) result[0] = 0;
    if (n > 1) result[1] = 1;
    if (n > 2) {
        for (2..n) |i| result[i] = result[i - 1] + result[i - 2];
    }
    return result;
}

/// Repeats s n times at compile time: repeat("ab", 3) == "ababab".
fn repeat(comptime s: []const u8, comptime n: usize) []const u8 {
    // A bare `return` inside `comptime { ... }` can't return from a
    // runtime call, so use a labeled block and break the value out.
    return comptime blk: {
        var out: []const u8 = "";
        for (0..n) |_| out = out ++ s;
        break :blk out;
    };
}

/// Sums @sizeOf every type in the list. Only `inline for` can iterate a
/// []const type: each unrolled iteration gets a comptime-known T.
fn totalSize(comptime types: []const type) usize {
    var total: usize = 0;
    inline for (types) |T| total += @sizeOf(T);
    return total;
}

/// Returns log2(n) for a power of two — and refuses to compile otherwise.
fn requirePowerOfTwo(comptime n: u64) u6 {
    comptime {
        if (n == 0 or (n & (n - 1)) != 0) {
            @compileError(std.fmt.comptimePrint(
                "requirePowerOfTwo: {d} is not a power of two",
                .{n},
            ));
        }
    }
    return @intCast(std.math.log2(n));
}

test "powers of two, computed at compile time" {
    const table = comptime powersOfTwo(10);
    try std.testing.expectEqual(@as(u64, 1), table[0]);
    try std.testing.expectEqual(@as(u64, 8), table[3]);
    try std.testing.expectEqual(@as(u64, 512), table[9]);
}

test "fibonacci table" {
    const fib = comptime fibTable(12);
    try std.testing.expectEqualSlices(
        u64,
        &.{ 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89 },
        &fib,
    );
}

test "comptime string building" {
    try std.testing.expectEqualStrings("ababab", repeat("ab", 3));
    try std.testing.expectEqualStrings("zig", repeat("zig", 1));
    try std.testing.expectEqualStrings("", repeat("anything", 0));
}

test "inline for over a list of types" {
    try std.testing.expectEqual(@as(usize, 4 + 1 + 8), totalSize(&.{ u32, u8, f64 }));
    try std.testing.expectEqual(@as(usize, 0), totalSize(&.{}));
    try std.testing.expectEqual(@as(usize, 2 * @sizeOf(usize) + 4), totalSize(&.{ []const u8, i32 }));
}

test "requirePowerOfTwo returns the exponent" {
    try std.testing.expectEqual(@as(u6, 0), requirePowerOfTwo(1));
    try std.testing.expectEqual(@as(u6, 6), requirePowerOfTwo(64));
    try std.testing.expectEqual(@as(u6, 12), requirePowerOfTwo(4096));
    // Uncomment to watch the build fail with the message above:
    // _ = requirePowerOfTwo(1000);
}
