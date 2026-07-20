//! Solution 03: while — Zig's only conditional loop
//! Run: zig test 03_while.zig

const std = @import("std");

/// Integer square root: the largest r such that r * r <= n.
fn intSqrt(n: u32) u32 {
    // r is u64 so (r + 1) * (r + 1) can't overflow even when n is maxInt(u32)
    // — with a u32 r, the check against 65536 * 65536 would panic in Debug.
    var r: u64 = 0;
    // Continue-expression form with an empty body: all the work happens in
    // the condition and the step.
    while ((r + 1) * (r + 1) <= n) : (r += 1) {}
    // r <= 65535 here, so it provably fits back into u32.
    return @intCast(r);
}

/// Steps for n to reach 1 under the Collatz map.
fn collatzSteps(n0: u64) u32 {
    var n = n0; // parameters are immutable — loop on a copy
    var steps: u32 = 0;
    while (n != 1) : (steps += 1) {
        n = if (n % 2 == 0) n / 2 else 3 * n + 1;
    }
    return steps;
}

/// Greatest common divisor by Euclid's algorithm.
fn gcd(a0: u64, b0: u64) u64 {
    var a = a0;
    var b = b0;
    while (b != 0) {
        // No tuple assignment in Zig; swap through a temporary.
        const t = a % b;
        a = b;
        b = t;
    }
    return a;
}

test "intSqrt small values" {
    try std.testing.expectEqual(0, intSqrt(0));
    try std.testing.expectEqual(1, intSqrt(1));
    try std.testing.expectEqual(1, intSqrt(3));
    try std.testing.expectEqual(2, intSqrt(4));
    try std.testing.expectEqual(2, intSqrt(8));
    try std.testing.expectEqual(3, intSqrt(9));
    try std.testing.expectEqual(9, intSqrt(99));
    try std.testing.expectEqual(10, intSqrt(100));
}

test "intSqrt does not overflow near the top of u32" {
    try std.testing.expectEqual(65535, intSqrt(4294836225));
    try std.testing.expectEqual(65535, intSqrt(std.math.maxInt(u32)));
}

test "collatzSteps" {
    try std.testing.expectEqual(0, collatzSteps(1));
    try std.testing.expectEqual(1, collatzSteps(2));
    try std.testing.expectEqual(7, collatzSteps(3));
    try std.testing.expectEqual(8, collatzSteps(6));
    try std.testing.expectEqual(111, collatzSteps(27));
}

test "gcd" {
    try std.testing.expectEqual(6, gcd(12, 18));
    try std.testing.expectEqual(6, gcd(18, 12));
    try std.testing.expectEqual(1, gcd(7, 13));
    try std.testing.expectEqual(42, gcd(42, 0));
    try std.testing.expectEqual(5, gcd(0, 5));
    try std.testing.expectEqual(21, gcd(1071, 462));
}
