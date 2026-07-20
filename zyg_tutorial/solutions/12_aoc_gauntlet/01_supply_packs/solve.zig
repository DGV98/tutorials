//! Problem 1: Supply Packs — reference solution.
//!
//! Skills: blank-line group parsing (splitSequence vs tokenizeScalar),
//! parseInt, running max / top-3 tracking. Modules 02, 03, 05.
//!
//! Run: zig test solve.zig   (from this directory)

const std = @import("std");

const input = @embedFile("input.txt");
const example = @embedFile("example.txt");

/// Sum one blank-line-separated group of integers.
fn groupSum(group: []const u8) !i64 {
    var sum: i64 = 0;
    var lines = std.mem.tokenizeScalar(u8, group, '\n');
    while (lines.next()) |line| {
        sum += try std.fmt.parseInt(i64, line, 10);
    }
    return sum;
}

/// Part 1: the largest group sum.
fn part1(alloc: std.mem.Allocator, text: []const u8) !i64 {
    _ = alloc; // no allocation needed here
    var best: i64 = 0;
    var groups = std.mem.splitSequence(u8, text, "\n\n");
    while (groups.next()) |group| {
        const sum = try groupSum(group);
        if (sum > best) best = sum;
    }
    return best;
}

/// Part 2: the sum of the three largest group sums.
fn part2(alloc: std.mem.Allocator, text: []const u8) !i64 {
    _ = alloc;
    var top = [3]i64{ 0, 0, 0 }; // descending
    var groups = std.mem.splitSequence(u8, text, "\n\n");
    while (groups.next()) |group| {
        const sum = try groupSum(group);
        if (sum > top[0]) {
            top[2] = top[1];
            top[1] = top[0];
            top[0] = sum;
        } else if (sum > top[1]) {
            top[2] = top[1];
            top[1] = sum;
        } else if (sum > top[2]) {
            top[2] = sum;
        }
    }
    return top[0] + top[1] + top[2];
}

test "part1 example" {
    try std.testing.expectEqual(@as(i64, 1500), try part1(std.testing.allocator, example));
}

test "part2 example" {
    try std.testing.expectEqual(@as(i64, 3500), try part2(std.testing.allocator, example));
}

test "part1" {
    try std.testing.expectEqual(@as(i64, 57723), try part1(std.testing.allocator, input));
}

test "part2" {
    try std.testing.expectEqual(@as(i64, 160896), try part2(std.testing.allocator, input));
}
