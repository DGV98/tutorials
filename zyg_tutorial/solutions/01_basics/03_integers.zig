//! Exercise 03: Integers — SOLUTION
//!
//! Run: zig test 03_integers.zig

const std = @import("std");

fn upperNibbleMask() u8 {
    // Same value as 240 or 0xF0, but the binary literal shows the shape.
    return 0b1111_0000;
}

fn wrappingIncrement(counter: u8) u8 {
    // Plain `+` would panic on 255 in Debug builds; +% wraps by design.
    return counter +% 1;
}

fn clampedAdd(a: u8, b: u8) u8 {
    // Saturating add: pins at 255 instead of wrapping.
    return a +| b;
}

fn narrowToU8(x: u32) u8 {
    // Destination type (u8) is inferred from the return type. The caller
    // guarantees x <= 255; if that promise is broken, Debug builds panic.
    return @intCast(x);
}

fn divTowardZero(a: i32, b: i32) i32 {
    return @divTrunc(a, b); // -7, 2 -> -3
}

fn divToNegInf(a: i32, b: i32) i32 {
    return @divFloor(a, b); // -7, 2 -> -4
}

fn wrapAround(index: i32, len: i32) i32 {
    // @mod's sign follows the denominator, so for positive len the result
    // is always in [0, len) — exactly what indexing wants.
    return @mod(index, len);
}

fn remainder(a: i32, b: i32) i32 {
    // @rem's sign follows the numerator (the C `%` behavior).
    return @rem(a, b);
}

test "upper nibble mask" {
    try std.testing.expectEqual(0xF0, upperNibbleMask());
}

test "wrapping increment" {
    try std.testing.expectEqual(0, wrappingIncrement(255));
    try std.testing.expectEqual(42, wrappingIncrement(41));
}

test "saturating add" {
    try std.testing.expectEqual(255, clampedAdd(200, 100));
    try std.testing.expectEqual(3, clampedAdd(1, 2));
}

test "narrowing cast" {
    try std.testing.expectEqual(200, narrowToU8(200));
    try std.testing.expectEqual(0, narrowToU8(0));
}

test "the two divisions disagree on negatives" {
    try std.testing.expectEqual(-3, divTowardZero(-7, 2));
    try std.testing.expectEqual(-4, divToNegInf(-7, 2));
    try std.testing.expectEqual(3, divTowardZero(7, 2));
    try std.testing.expectEqual(3, divToNegInf(7, 2));
}

test "mod wraps indexes, rem follows the numerator" {
    try std.testing.expectEqual(4, wrapAround(-1, 5));
    try std.testing.expectEqual(2, wrapAround(7, 5));
    try std.testing.expectEqual(-1, remainder(-7, 2));
    try std.testing.expectEqual(1, remainder(7, 2));
}
