//! Exercise 03: while — Zig's only conditional loop
//!
//! Concepts: while with a condition, the continue-expression form
//!           `while (cond) : (step)`, break/continue, while as an expression
//!           with `break value`, infinite loops `while (true)`.
//! Run:      zig test 03_while.zig
//! Docs:     https://ziglang.org/documentation/0.16.0/#while

const std = @import("std");

// Zig has no C-style `for (init; cond; step)`. The equivalent is while with
// a CONTINUE EXPRESSION — the part after the colon runs at the end of every
// iteration (including ones ended by `continue`, but NOT by `break`):
//
//     var i: usize = 0;
//     while (i < 10) : (i += 1) {
//         // ...
//     }
//
// `break` exits the loop, `continue` jumps to the continue expression and
// then re-checks the condition. `while (true)` is the idiomatic infinite
// loop — you leave it with break or return.
//
// A while can be an EXPRESSION: `break value` gives the loop its value, and
// the `else` branch supplies the value when the condition turns false
// without ever breaking:
//
//     const found = while (i < n) : (i += 1) {
//         if (data[i] == 0) break true;
//     } else false;
//
// One more thing you'll need below: function parameters are immutable
// (they're like `const` locals). To loop on a parameter, copy it first:
//
//     fn f(n0: u64) u64 {
//         var n = n0;   // now n can change
//         ...

/// Integer square root: the largest r such that r * r <= n.
/// intSqrt(8) == 2, intSqrt(9) == 3.
/// No std.math — do it with a loop counting r upward.
/// Overflow trap: for n near the top of u32, (r + 1) * (r + 1) can exceed
/// u32. Do the arithmetic in a u64 and @intCast the result back (casts were
/// module 1).
fn intSqrt(n: u32) u32 {
    _ = n; // TODO: remove this discard when you use the parameter.
    // TODO: a while with a continue expression and an empty body `{}` is
    // enough: keep bumping r while (r + 1) * (r + 1) still fits under n.
    return 999_999;
}

/// The Collatz step count: how many steps does n take to reach 1, where a
/// step maps even n -> n / 2 and odd n -> 3 * n + 1?
/// collatzSteps(1) == 0, collatzSteps(6) == 8. Assume n >= 1.
fn collatzSteps(n0: u64) u32 {
    _ = n0; // TODO: remove this discard when you use the parameter.
    // TODO: copy the parameter into a var, then `while (n != 1)`.
    // `n % 2 == 0` tests evenness.
    return 999_999;
}

/// Greatest common divisor by Euclid's algorithm:
/// repeat (a, b) -> (b, a % b) until b == 0; the answer is a.
/// gcd(12, 18) == 6. By convention gcd(x, 0) == x.
fn gcd(a0: u64, b0: u64) u64 {
    _ = a0; // TODO: remove these discards when implementing.
    _ = b0;
    // TODO: `while (b != 0)`. Swap with a temporary — Zig has no tuple
    // assignment. Three lines of body.
    return 999_999;
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
    // 65535 * 65535 == 4294836225; anything above that still answers 65535,
    // but only if the squaring is done in a wider type.
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
