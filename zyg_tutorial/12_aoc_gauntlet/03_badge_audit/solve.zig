//! Problem 3: Badge Audit
//!
//! Skills: string scanning, set intersection with u64 bitsets or bool
//! arrays, bit tricks (modules 05, 11).
//!
//! Run: zig test solve.zig   (from this directory)
//! Read README.md first for the full problem statement.

const std = @import("std");

const input = @embedFile("input.txt");
const example = @embedFile("example.txt");

// Clearance values: 'a'..'z' -> 1..26, 'A'..'Z' -> 27..52.

/// Part 1: per line, the one item code that appears in BOTH halves of the
/// line; return the sum of those codes' clearance values.
fn part1(alloc: std.mem.Allocator, text: []const u8) !i64 {
    // TODO: iterate lines (std.mem.tokenizeScalar(u8, text, '\n')); split
    // each line at line.len / 2; find the single character present in both
    // halves; add its clearance value.
    //
    // Set trick (module 11): there are only 52 possible codes, so a u64
    // bitset per half beats any hash map — set bit (ch - 'a') or
    // (ch - 'A' + 26), then AND the two masks. @ctz gives you the index of
    // the surviving bit. A [52]bool works too if bits feel spicy.
    _ = alloc;
    _ = text;
    return -1;
}

/// Part 2: per group of THREE consecutive lines, the one item code present
/// in all three; return the sum of those clearance values.
fn part2(alloc: std.mem.Allocator, text: []const u8) !i64 {
    // TODO: same set trick, but intersect three whole-line masks. Pull three
    // lines per loop iteration from the same tokenizer (the line count is a
    // multiple of 3, so .next().? is safe for the 2nd and 3rd).
    _ = alloc;
    _ = text;
    return -1;
}

test "part1 example" {
    try std.testing.expectEqual(@as(i64, 100), try part1(std.testing.allocator, example));
}

test "part2 example" {
    try std.testing.expectEqual(@as(i64, 70), try part2(std.testing.allocator, example));
}

test "part1" {
    try std.testing.expectEqual(@as(i64, 7786), try part1(std.testing.allocator, input));
}

test "part2" {
    try std.testing.expectEqual(@as(i64, 2791), try part2(std.testing.allocator, input));
}
