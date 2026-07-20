//! Comptime parameters: generic functions
//!
//! Concepts: `comptime T: type` parameters, monomorphization, types as
//! compile-time values.
//!
//! Run: zig test 01_comptime_params.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Compile-Time-Parameters

const std = @import("std");

// A parameter marked `comptime` must be known at compile time at every call
// site. Since types are compile-time values, `comptime T: type` is how Zig
// spells a generic function. Later parameters can use T as their type.
//
// The compiler MONOMORPHIZES: max(i32, ...) and max(f64, ...) become two
// separate functions in the binary, each specialized for its type. There is
// no runtime dispatch and no boxing.
//
// There are also no trait bounds: `a > b` just has to compile for the T you
// pass. Try calling max with a struct type and read the error — it points at
// the comparison, in plain Zig.

/// Returns the larger of a and b.
fn max(comptime T: type, a: T, b: T) T {
    // TODO: return the larger of the two values.
    _ = b; // remove this discard once you use b
    return a;
}

/// Exchanges the values behind the two pointers.
fn swap(comptime T: type, a: *T, b: *T) void {
    // TODO: swap the pointed-to values. You'll need a temporary — its type
    // is T, which you know because the caller told you.
    _ = a; // remove this discard once you use a
    _ = b; // remove this discard once you use b
}

/// Sums a slice of any numeric type. Note the element type of the slice
/// parameter is the comptime parameter itself.
fn sum(comptime T: type, items: []const T) T {
    // TODO: loop over items and add them up, starting from 0.
    _ = items; // remove this discard once you use items
    return 0;
}

test "max works for several types (monomorphization)" {
    // Each distinct T here stamps out a fresh copy of max.
    try std.testing.expectEqual(@as(i32, 7), max(i32, 3, 7));
    try std.testing.expectEqual(@as(i32, 7), max(i32, 7, 3));
    try std.testing.expectEqual(@as(f64, 1.5), max(f64, 0.2, 1.5));
    try std.testing.expectEqual(@as(u8, 200), max(u8, 200, 100));
}

test "types are values at compile time" {
    // You can store a type in a constant and pass it along. This is not
    // possible at runtime: `type` values are comptime-only.
    const T = u16;
    try std.testing.expectEqual(@as(T, 9), max(T, 4, 9));
    // Types compare with ==.
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
