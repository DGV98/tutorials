//! Exercise 02: Slices — reference solution
//!
//! Run:  zig test 02_slices.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Slices

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

fn total(xs: []const i32) i64 {
    var sum: i64 = 0;
    for (xs) |x| sum += x;
    return sum;
}

fn largest(xs: []const i32) ?i32 {
    if (xs.len == 0) return null;
    var max = xs[0];
    for (xs[1..]) |x| {
        if (x > max) max = x;
    }
    return max;
}

fn doubleAll(xs: []i32) void {
    for (xs) |*x| x.* *= 2;
}

fn trimEnds(xs: []const i32) []const i32 {
    return xs[1 .. xs.len - 1];
}

test "slices alias the array they point into" {
    var word = [_]u8{ 'g', 'o', 'l', 'd' };
    const s: []u8 = &word;
    s[0] = 'b';
    try std.testing.expectEqualStrings("bold", &word);
}

test "sub-slices share memory too" {
    var nums = [_]i32{ 10, 20, 30, 40, 50 };
    const middle = nums[1..4]; // views elements 20, 30, 40
    middle[0] = 999;
    try expectEqual(@as(i32, 999), nums[1]);
}

test "total" {
    const xs = [_]i32{ 3, -1, 4, 1, 5 };
    try expectEqual(@as(i64, 12), total(&xs));
    try expectEqual(@as(i64, 0), total(&.{}));
}

test "largest" {
    try expectEqual(@as(?i32, 42), largest(&.{ 7, 42, -3 }));
    try expectEqual(@as(?i32, -3), largest(&.{-3}));
    try expectEqual(@as(?i32, null), largest(&.{}));
}

test "doubleAll mutates through the slice" {
    var xs = [_]i32{ 1, 2, 3 };
    doubleAll(&xs);
    try std.testing.expectEqualSlices(i32, &.{ 2, 4, 6 }, &xs);
}

test "trimEnds" {
    const xs = [_]i32{ 1, 2, 3, 4, 5 };
    try std.testing.expectEqualSlices(i32, &.{ 2, 3, 4 }, trimEnds(&xs));
    const pair = [_]i32{ 7, 8 };
    try std.testing.expectEqualSlices(i32, &.{}, trimEnds(&pair));
}
