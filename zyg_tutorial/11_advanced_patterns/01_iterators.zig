//! 01 — Writing Your Own Iterators
//!
//! Concepts: the `next() ?T` pattern, `while (it.next()) |v|`, generic
//!           iterator factories, overlapping windows, all-pairs iteration
//!
//! Run: zig test 01_iterators.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#while-with-Optionals

const std = @import("std");
const testing = std.testing;

// An iterator in Zig is nothing but a struct with a `next` method that
// returns an optional. Returning null means "done". The whole standard
// library uses this shape (tokenizers, hash map iterators, ...), and
// `while (it.next()) |v|` consumes it. There is no trait, no interface —
// just the convention.

/// Yields start, start+step, start+step*2, ... stopping before `end`.
/// Works with negative steps too (counts down toward `end`).
const Range = struct {
    current: i64,
    end: i64,
    step: i64 = 1,

    pub fn next(self: *Range) ?i64 {
        // TODO: return null once the range is exhausted (careful: with a
        // negative step, "exhausted" means current <= end). Otherwise save
        // self.current, advance it by self.step, and return the saved value.
        _ = self; // TODO: remove this line when you use `self`
        return null;
    }
};

/// Generic iterator factory: a function that takes a type and returns a
/// struct type. `Windows(u8)` iterates overlapping windows of a byte slice.
/// For "abcde" with size 3 it yields "abc", "bcd", "cde".
pub fn Windows(comptime T: type) type {
    return struct {
        data: []const T,
        size: usize,
        index: usize = 0,

        const Self = @This();

        pub fn next(self: *Self) ?[]const T {
            // TODO: return null if size is 0 or the next window would run
            // past the end (index + size > data.len). Otherwise slice out
            // data[index..][0..size], advance index by ONE (windows
            // overlap!), and return the slice.
            _ = self; // TODO: remove this line when you use `self`
            return null;
        }
    };
}

/// Yields every unordered pair (a, b) with a before b in the slice.
/// For {1, 2, 3} it yields (1,2), (1,3), (2,3) — n*(n-1)/2 pairs total.
/// Classic AoC move: "compare every pair of lines/points/ranges".
pub fn Pairs(comptime T: type) type {
    return struct {
        data: []const T,
        i: usize = 0,
        j: usize = 1,

        const Self = @This();

        pub const Pair = struct { a: T, b: T };

        pub fn next(self: *Self) ?Pair {
            // TODO: if j walked off the end, advance to the next row:
            // i += 1, j = i + 1. If j is STILL past the end, return null.
            // Otherwise build .{ .a = data[i], .b = data[j] }, bump j,
            // and return it.
            _ = self; // TODO: remove this line when you use `self`
            return null;
        }
    };
}

test "Range counts up" {
    var it: Range = .{ .current = 0, .end = 5 };
    var got: [8]i64 = undefined;
    var n: usize = 0;
    while (it.next()) |v| : (n += 1) got[n] = v;
    try testing.expectEqualSlices(i64, &.{ 0, 1, 2, 3, 4 }, got[0..n]);
}

test "Range counts down with negative step" {
    var it: Range = .{ .current = 10, .end = 0, .step = -3 };
    var got: [8]i64 = undefined;
    var n: usize = 0;
    while (it.next()) |v| : (n += 1) got[n] = v;
    try testing.expectEqualSlices(i64, &.{ 10, 7, 4, 1 }, got[0..n]);
}

test "empty Range yields nothing" {
    var it: Range = .{ .current = 3, .end = 3 };
    try testing.expectEqual(@as(?i64, null), it.next());
}

test "Windows over bytes" {
    var it: Windows(u8) = .{ .data = "abcde", .size = 3 };
    try testing.expectEqualStrings("abc", it.next() orelse return error.TestExpectedWindow);
    try testing.expectEqualStrings("bcd", it.next() orelse return error.TestExpectedWindow);
    try testing.expectEqualStrings("cde", it.next() orelse return error.TestExpectedWindow);
    try testing.expectEqual(@as(?[]const u8, null), it.next());
}

test "Windows wider than the data yields nothing" {
    var it: Windows(u8) = .{ .data = "ab", .size = 3 };
    try testing.expectEqual(@as(?[]const u8, null), it.next());
}

test "Windows over ints: max sliding sum of width 2" {
    const nums = [_]i32{ 1, 9, 2, 8, 3 };
    var it: Windows(i32) = .{ .data = &nums, .size = 2 };
    var best: i32 = std.math.minInt(i32);
    while (it.next()) |w| {
        const sum = w[0] + w[1];
        if (sum > best) best = sum;
    }
    try testing.expectEqual(@as(i32, 11), best); // 9 + 2
}

test "Pairs yields n*(n-1)/2 pairs" {
    const nums = [_]i64{ 1, 2, 3, 4 };
    var it: Pairs(i64) = .{ .data = &nums };
    var count: usize = 0;
    var product_sum: i64 = 0;
    while (it.next()) |p| {
        count += 1;
        product_sum += p.a * p.b;
    }
    try testing.expectEqual(@as(usize, 6), count);
    // 1*2 + 1*3 + 1*4 + 2*3 + 2*4 + 3*4 = 35
    try testing.expectEqual(@as(i64, 35), product_sum);
}

test "Pairs of fewer than two elements yields nothing" {
    const one = [_]i64{7};
    var it: Pairs(i64) = .{ .data = &one };
    try testing.expectEqual(@as(?Pairs(i64).Pair, null), it.next());
}
