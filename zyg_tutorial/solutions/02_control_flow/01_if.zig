//! Solution 01: if — branches that produce values
//! Run: zig test 01_if.zig

const std = @import("std");

/// Return -1 if x is negative, 0 if x is zero, 1 if x is positive.
fn sign(x: i32) i32 {
    // An else-if chain used as one expression: every path yields a value,
    // so the whole chain can be returned directly.
    return if (x < 0) -1 else if (x == 0) 0 else 1;
}

/// Clamp x into the inclusive range [lo, hi].
fn clamp(x: i32, lo: i32, hi: i32) i32 {
    return if (x < lo) lo else if (x > hi) hi else x;
}

/// Return the largest of three values.
fn max3(a: i32, b: i32, c: i32) i32 {
    // Reduce pairwise: max(a, b), then max(that, c). Binding the
    // intermediate to a const keeps it readable.
    const ab = if (a > b) a else b;
    return if (ab > c) ab else c;
}

test "sign" {
    try std.testing.expectEqual(-1, sign(-17));
    try std.testing.expectEqual(0, sign(0));
    try std.testing.expectEqual(1, sign(250));
}

test "clamp keeps in-range values" {
    try std.testing.expectEqual(5, clamp(5, 0, 10));
    try std.testing.expectEqual(0, clamp(0, 0, 10));
    try std.testing.expectEqual(10, clamp(10, 0, 10));
}

test "clamp pins out-of-range values" {
    try std.testing.expectEqual(0, clamp(-3, 0, 10));
    try std.testing.expectEqual(10, clamp(99, 0, 10));
    try std.testing.expectEqual(-5, clamp(-40, -5, 5));
}

test "max3" {
    try std.testing.expectEqual(3, max3(1, 2, 3));
    try std.testing.expectEqual(3, max3(3, 2, 1));
    try std.testing.expectEqual(3, max3(2, 3, 1));
    try std.testing.expectEqual(7, max3(7, 7, 7));
    try std.testing.expectEqual(-1, max3(-1, -2, -3));
}
