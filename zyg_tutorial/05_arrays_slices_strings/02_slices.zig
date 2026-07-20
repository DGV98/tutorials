//! Exercise 02: Slices
//!
//! Concepts: []T vs []const T, slicing arr[a..b], slices as fat pointers
//! (ptr + len) that alias memory, mutating through a slice, &array coercion,
//! passing slices to functions, runtime bounds checks.
//!
//! Run:  zig test 02_slices.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Slices

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

// A slice is a pointer plus a length — it does not own or copy anything.
// []const i32 means "read-only view"; take it in parameters whenever you
// don't mutate, because everything ([]i32, &array, literals) coerces to it.
// This is THE default way to pass collections to functions.
//
// TODO: return the sum of all elements. An empty slice sums to 0.
fn total(xs: []const i32) i64 {
    _ = xs; // TODO: remove
    return -1;
}

// Search returning an optional — module 04 pays off.
//
// TODO: return the largest element, or null when the slice is empty.
fn largest(xs: []const i32) ?i32 {
    _ = xs; // TODO: remove
    return null;
}

// A []i32 (no const) lets you WRITE through the slice — the writes land in
// whatever memory the slice points at. `for (xs) |*x|` iterates by pointer,
// so `x.* *= 2` modifies the element in place.
//
// TODO: double every element, in place.
fn doubleAll(xs: []i32) void {
    _ = xs; // TODO: remove
}

// Slicing syntax: xs[start..end] — start inclusive, end exclusive; xs[1..]
// runs to the end. With runtime indices the bounds are CHECKED: going past
// the end panics with a stack trace in Debug builds instead of silently
// reading garbage.
//
// TODO: return `xs` without its first and last elements (assume xs.len >= 2).
fn trimEnds(xs: []const i32) []const i32 {
    return xs; // TODO: slice it — xs.len is a runtime value you can use in bounds
}

test "slices alias the array they point into" {
    var word = [_]u8{ 'g', 'o', 'l', 'd' };
    // &array coerces to a slice of the whole array.
    const s: []u8 = &word;
    s[0] = 'b';
    // The write went through the slice into `word` — same bytes, two views.
    // TODO: replace "????" with what `word` spells now.
    try std.testing.expectEqualStrings("????", &word);
}

test "sub-slices share memory too" {
    var nums = [_]i32{ 10, 20, 30, 40, 50 };
    // Fun fact: with comptime-known bounds this is actually a *[3]i32
    // (pointer to array); it coerces to []i32 whenever you need a slice.
    const middle = nums[1..4]; // views elements 20, 30, 40
    middle[0] = 999;
    // TODO: `middle[0]` is which element of `nums`? Fix the index (not 0).
    try expectEqual(@as(i32, 999), nums[0]);
}

test "total" {
    const xs = [_]i32{ 3, -1, 4, 1, 5 };
    try expectEqual(@as(i64, 12), total(&xs));
    try expectEqual(@as(i64, 0), total(&.{})); // empty slice
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
