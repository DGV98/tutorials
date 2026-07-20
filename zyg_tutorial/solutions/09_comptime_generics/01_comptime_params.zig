//! Comptime parameters: generic functions — SOLUTION
//!
//! Concepts: `comptime T: type` parameters, monomorphization, types as
//! compile-time values.
//!
//! Run: zig test 01_comptime_params.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Compile-Time-Parameters

const std = @import("std");

/// Returns the larger of a and b.
fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}

/// Exchanges the values behind the two pointers.
fn swap(comptime T: type, a: *T, b: *T) void {
    const tmp: T = a.*;
    a.* = b.*;
    b.* = tmp;
}

/// Sums a slice of any numeric type.
fn sum(comptime T: type, items: []const T) T {
    var total: T = 0;
    for (items) |item| total += item;
    return total;
}

test "max works for several types (monomorphization)" {
    try std.testing.expectEqual(@as(i32, 7), max(i32, 3, 7));
    try std.testing.expectEqual(@as(i32, 7), max(i32, 7, 3));
    try std.testing.expectEqual(@as(f64, 1.5), max(f64, 0.2, 1.5));
    try std.testing.expectEqual(@as(u8, 200), max(u8, 200, 100));
}

test "types are values at compile time" {
    const T = u16;
    try std.testing.expectEqual(@as(T, 9), max(T, 4, 9));
    try std.testing.expect(T == u16);
    try std.testing.expect(T != i16);
}

test "swap exchanges two values in place" {
    var x: i32 = 1;
    var y: i32 = 2;
    swap(i32, &x, &y);
    try std.testing.expectEqual(@as(i32, 2), x);
    try std.testing.expectEqual(@as(i32, 1), y);

    var a: []const u8 = "left";
    var b: []const u8 = "right";
    swap([]const u8, &a, &b);
    try std.testing.expectEqualStrings("right", a);
    try std.testing.expectEqualStrings("left", b);
}

test "sum adds up a slice" {
    try std.testing.expectEqual(@as(i32, 6), sum(i32, &.{ 1, 2, 3 }));
    try std.testing.expectEqual(@as(f32, 2.5), sum(f32, &.{ 1.0, 1.5 }));
    try std.testing.expectEqual(@as(u64, 0), sum(u64, &.{}));
}
