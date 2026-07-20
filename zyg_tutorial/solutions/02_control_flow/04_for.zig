//! Solution 04: for — iteration over ranges and slices
//! Run: zig test 04_for.zig

const std = @import("std");

/// Count how many elements of xs are equal to target.
fn countMatching(xs: []const i32, target: i32) usize {
    var count: usize = 0;
    for (xs) |x| {
        if (x == target) count += 1;
    }
    return count;
}

/// Dot product, accumulated in i64.
fn dot(a: []const i32, b: []const i32) i64 {
    var sum: i64 = 0;
    // Lockstep form: no indices, and the compiler safety-checks that the
    // lengths match.
    for (a, b) |x, y| {
        // Widening one operand to i64 makes the multiply happen in i64,
        // so i32 * i32 can't overflow.
        sum += @as(i64, x) * y;
    }
    return sum;
}

/// Index of the first element equal to target, or null if absent.
fn indexOfFirst(xs: []const i32, target: i32) ?usize {
    // The whole loop is the return expression: break supplies the found
    // index, the else runs only if no break happened.
    return for (xs, 0..) |x, i| {
        if (x == target) break i;
    } else null;
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
