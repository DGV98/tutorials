//! Problem 1: Supply Packs
//!
//! Skills: parsing blank-line-separated groups, parseInt, tracking a
//! max / top-3 (modules 02, 03, 05).
//!
//! Run: zig test solve.zig   (from this directory)
//! Read README.md first for the full problem statement.

const std = @import("std");

const input = @embedFile("input.txt");
const example = @embedFile("example.txt");

/// Part 1: the largest total charge carried by a single drone.
fn part1(alloc: std.mem.Allocator, text: []const u8) !i64 {
    // TODO: split `text` into manifests (groups separated by a BLANK line),
    // sum the integers in each, return the largest sum.
    //
    // Parsing hints (module 05):
    //   - std.mem.splitSequence(u8, text, "\n\n") iterates the groups
    //     (splitScalar splits on ONE byte; a blank line is the 2-byte "\n\n").
    //   - std.mem.tokenizeScalar(u8, group, '\n') iterates the lines inside a
    //     group and conveniently skips the trailing empty one.
    //   - std.fmt.parseInt(i64, line, 10) can fail — that's why this function
    //     returns !i64 (module 03).
    _ = alloc;
    _ = text;
    return -1;
}

/// Part 2: the combined total of the three highest-charge drones.
fn part2(alloc: std.mem.Allocator, text: []const u8) !i64 {
    // TODO: same parsing as part 1, but keep the three largest group sums.
    // A [3]i64 you insert into, or collecting all sums into an ArrayList
    // (module 08) and sorting with std.mem.sort, both work fine.
    _ = alloc;
    _ = text;
    return -1;
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
