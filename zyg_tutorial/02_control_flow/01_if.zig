//! Exercise 01: if — branches that produce values
//!
//! Concepts: if/else, if as an expression (Zig's ternary), else-if chains.
//! Run:      zig test 01_if.zig
//! Docs:     https://ziglang.org/documentation/0.16.0/#if

const std = @import("std");

// Zig's `if` needs a real `bool`. There is no truthiness: `if (x)` where x is
// an integer does not compile — write `if (x != 0)`.
//
// There is also no `?:` ternary operator, because `if` IS an expression:
//
//     const bigger = if (a > b) a else b;
//
// When used as an expression, the `else` is mandatory (the expression must
// have a value on every path). Chains read like C:
//
//     if (x < 0) {
//         // ...
//     } else if (x == 0) {
//         // ...
//     } else {
//         // ...
//     }
//
// Note for the stubs below: Zig treats unused locals AND unused function
// parameters as compile errors, so each stub discards its parameters with
// `_ = x;`. Delete those discards as you start using the parameters —
// discarding a value you also use is itself an error.

/// Return -1 if x is negative, 0 if x is zero, 1 if x is positive.
fn sign(x: i32) i32 {
    _ = x; // TODO: remove this discard when you use the parameter.
    // TODO: implement with an else-if chain (or nested if-expressions).
    return -999; // wrong on purpose — replace it
}

/// Clamp x into the inclusive range [lo, hi].
/// clamp(5, 0, 10) == 5, clamp(-3, 0, 10) == 0, clamp(99, 0, 10) == 10.
/// You may assume lo <= hi.
fn clamp(x: i32, lo: i32, hi: i32) i32 {
    _ = x; // TODO: remove these discards when implementing.
    _ = lo;
    _ = hi;
    // TODO: two comparisons are enough. Try writing the whole body as a
    // single `return if (...) ... else if (...) ... else ...;` expression.
    return -999;
}

/// Return the largest of three values.
fn max3(a: i32, b: i32, c: i32) i32 {
    _ = a; // TODO: remove these discards when implementing.
    _ = b;
    _ = c;
    // TODO: one way: compute the max of a and b with an if-expression,
    // then compare that against c. No loops, no std helpers.
    return -999;
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
