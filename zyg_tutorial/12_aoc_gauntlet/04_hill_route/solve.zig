//! Problem 4: Hill Route
//!
//! Skills: grid BFS (shortest path on an unweighted graph), an ArrayList as
//! a queue, allocated visited/dist storage (modules 07, 08).
//!
//! Run: zig test solve.zig   (from this directory)
//! Read README.md first for the full problem statement.

const std = @import("std");

const input = @embedFile("input.txt");
const example = @embedFile("example.txt");

/// Part 1: fewest steps from S to E, stepping only up/down/left/right, and
/// never onto a cell more than 1 higher than the current one.
fn part1(alloc: std.mem.Allocator, text: []const u8) !i64 {
    // TODO: BFS from S until you pop E.
    //
    // Hints:
    //   - Same flat-grid trick as problem 2: width = indexOf '\n', a cell's
    //     flat index i maps back to r = i / (width+1), c = i % (width+1).
    //     std.mem.indexOfScalar(u8, text, 'S').? finds the start directly.
    //   - Elevation: 'S' counts as 'a', 'E' counts as 'z'; a step onto
    //     elevation `next` is legal when next <= current + 1 (descending any
    //     amount is fine).
    //   - BFS queue (module 08): an ArrayList(usize) plus a `head` index you
    //     only ever increment is the simplest queue in Zig — no popFront
    //     needed. Track distances in a `try alloc.alloc(u32, text.len)`
    //     slice (module 07), initialized with @memset to a sentinel like
    //     std.math.maxInt(u32); "not yet visited" and "distance" in one.
    _ = alloc;
    _ = text;
    return -1;
}

/// Part 2: fewest steps from ANY lowest-elevation cell ('a' or S) to E.
fn part2(alloc: std.mem.Allocator, text: []const u8) !i64 {
    // TODO: one BFS per 'a' would work but is wasteful. Can a single search
    // answer the question for every possible trailhead at once? Think about
    // where that search would have to start.
    _ = alloc;
    _ = text;
    return -1;
}

test "part1 example" {
    try std.testing.expectEqual(@as(i64, 30), try part1(std.testing.allocator, example));
}

test "part2 example" {
    try std.testing.expectEqual(@as(i64, 29), try part2(std.testing.allocator, example));
}

test "part1" {
    try std.testing.expectEqual(@as(i64, 98), try part1(std.testing.allocator, input));
}

test "part2" {
    try std.testing.expectEqual(@as(i64, 95), try part2(std.testing.allocator, input));
}
