//! Exercise 04: for — iteration over ranges and slices
//!
//! Concepts: `for (0..n) |i|` ranges, for over slices, index alongside
//!           elements `for (xs, 0..) |x, i|`, two slices in lockstep,
//!           the else clause on loops.
//! Run:      zig test 04_for.zig
//! Docs:     https://ziglang.org/documentation/0.16.0/#for

const std = @import("std");

// Zig's for only iterates over things with a known length — it is not a
// while in disguise. The basic forms:
//
//     for (0..n) |i| { ... }          // i: usize, from 0 to n-1 (n EXCLUDED)
//     for (xs) |x| { ... }            // each element of a slice/array
//     for (xs, 0..) |x, i| { ... }    // element and its index together
//     for (xs, ys) |x, y| { ... }     // two slices in LOCKSTEP
//
// Lockstep iteration requires equal lengths — mismatched lengths are a
// safety-checked bug (a panic in Debug builds), not a silent truncation.
//
// The captures (x, y) are immutable COPIES of each element. `x += 1` will
// not compile, and couldn't write back anyway. (Mutating through a loop
// needs a pointer capture `|*x|` — that arrives with pointers in module 7.)
//
// Like while, a for can be an expression: `break value` supplies the value,
// and the `else` branch runs only if the loop finishes WITHOUT breaking:
//
//     const has_zero = for (xs) |x| {
//         if (x == 0) break true;
//     } else false;
//
// About the parameter types below: `[]const i32` is a slice — a pointer plus
// a length, viewing a sequence of i32. Module 5 goes deep on slices; for now
// you only need to loop over them. The tests build slices from array
// literals with `&[_]i32{ 1, 2, 3 }` ("address of an array whose length the
// compiler infers").

/// Count how many elements of xs are equal to target.
fn countMatching(xs: []const i32, target: i32) usize {
    _ = xs; // TODO: remove these discards when implementing.
    _ = target;
    // TODO: plain `for (xs) |x|` and a counter.
    return 999_999;
}

/// Dot product: sum of a[i] * b[i] over all i. Lengths are equal.
/// Accumulate in i64 so products of large i32s can't overflow — widen one
/// factor with @as(i64, x) and the multiplication follows.
fn dot(a: []const i32, b: []const i32) i64 {
    _ = a; // TODO: remove these discards when implementing.
    _ = b;
    // TODO: this is the lockstep form — no indices needed at all.
    return -999_999;
}

/// Index of the first element equal to target, or null if absent.
/// The return type ?usize means "a usize or null" — that's an optional.
/// Module 4 is all about them; here you only produce one: `return i;`
/// inside the loop, `return null;` (or a loop-else) if nothing matched.
fn indexOfFirst(xs: []const i32, target: i32) ?usize {
    _ = xs; // TODO: remove these discards when implementing.
    _ = target;
    // TODO: `for (xs, 0..) |x, i|`. Bonus style points for writing it as a
    // single `return for (...) ... else null;` expression.
    return null;
}

test "countMatching" {
    const xs = [_]i32{ 3, 1, 3, 3, 7 };
    try std.testing.expectEqual(3, countMatching(&xs, 3));
    try std.testing.expectEqual(1, countMatching(&xs, 7));
    try std.testing.expectEqual(0, countMatching(&xs, 42));
    try std.testing.expectEqual(0, countMatching(&[_]i32{}, 1));
}

test "dot" {
    try std.testing.expectEqual(32, dot(&[_]i32{ 1, 2, 3 }, &[_]i32{ 4, 5, 6 }));
    try std.testing.expectEqual(0, dot(&[_]i32{}, &[_]i32{}));
    try std.testing.expectEqual(-14, dot(&[_]i32{ 2, -3 }, &[_]i32{ -1, 4 }));
    // Each product here overflows i32; the i64 accumulator must carry it.
    try std.testing.expectEqual(9223372028264841218, dot(
        &[_]i32{ 2147483647, 2147483647 },
        &[_]i32{ 2147483647, 2147483647 },
    ));
}

test "indexOfFirst finds the first match" {
    const xs = [_]i32{ 5, 8, 8, 2 };
    try std.testing.expectEqual(@as(?usize, 0), indexOfFirst(&xs, 5));
    try std.testing.expectEqual(@as(?usize, 1), indexOfFirst(&xs, 8));
    try std.testing.expectEqual(@as(?usize, 3), indexOfFirst(&xs, 2));
}

test "indexOfFirst returns null when absent" {
    const xs = [_]i32{ 5, 8, 8, 2 };
    try std.testing.expectEqual(@as(?usize, null), indexOfFirst(&xs, 9));
    try std.testing.expectEqual(@as(?usize, null), indexOfFirst(&[_]i32{}, 9));
}
