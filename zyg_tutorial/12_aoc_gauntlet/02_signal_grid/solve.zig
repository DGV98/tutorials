//! Problem 2: Signal Grid
//!
//! Skills: treating a text blob as a 2D grid via flat indexing,
//! directional scans (modules 02, 05).
//!
//! Run: zig test solve.zig   (from this directory)
//! Read README.md first for the full problem statement.

const std = @import("std");

const input = @embedFile("input.txt");
const example = @embedFile("example.txt");

/// Part 1: how many masts are visible from outside the grid?
fn part1(alloc: std.mem.Allocator, text: []const u8) !i64 {
    // TODO: a mast is visible if it is STRICTLY taller than every mast
    // between it and an edge, in at least one of the four directions.
    // Count the visible ones (edge masts always qualify).
    //
    // Grid hints (module 05): you don't need to copy anything — the embedded
    // text already IS the grid.
    //   - width = std.mem.indexOfScalar(u8, text, '\n').?
    //   - each row is width+1 bytes long (the '\n' at the end of the row),
    //     so cell (r, c) lives at text[r * (width + 1) + c].
    //   - digits compare fine as bytes: '5' > '3' — no parseInt needed.
    // Watch signedness when you walk toward an edge: usize can't go below 0,
    // so either scan with i32/i64 coordinates or check bounds before stepping.
    _ = alloc;
    _ = text;
    return -1;
}

/// Part 2: the best coverage score over all masts.
fn part2(alloc: std.mem.Allocator, text: []const u8) !i64 {
    // TODO: for each mast, walk outward in each of the four directions and
    // count masts until you hit one at least as tall (that blocker counts
    // too) or fall off the edge. The coverage score is the product of the
    // four counts; return the maximum score.
    _ = alloc;
    _ = text;
    return -1;
}

test "part1 example" {
    try std.testing.expectEqual(@as(i64, 24), try part1(std.testing.allocator, example));
}

test "part2 example" {
    try std.testing.expectEqual(@as(i64, 16), try part2(std.testing.allocator, example));
}

test "part1" {
    try std.testing.expectEqual(@as(i64, 1135), try part1(std.testing.allocator, input));
}

test "part2" {
    try std.testing.expectEqual(@as(i64, 295800), try part2(std.testing.allocator, input));
}
