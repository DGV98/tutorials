//! Problem 3: Badge Audit — reference solution.
//!
//! Skills: string scanning, u64 bitsets (one bit per item code),
//! @ctz to recover the common character. Modules 05, 11.
//!
//! Run: zig test solve.zig   (from this directory)

const std = @import("std");

const input = @embedFile("input.txt");
const example = @embedFile("example.txt");

/// Bit i set <=> the character with clearance i+1 occurs in `s`.
/// a-z -> bits 0..25, A-Z -> bits 26..51.
fn charMask(s: []const u8) u64 {
    var mask: u64 = 0;
    for (s) |ch| {
        const bit: u6 = switch (ch) {
            'a'...'z' => @intCast(ch - 'a'),
            'A'...'Z' => @intCast(ch - 'A' + 26),
            else => unreachable,
        };
        mask |= @as(u64, 1) << bit;
    }
    return mask;
}

/// The clearance value of the single set bit in `mask`.
fn clearance(mask: u64) i64 {
    std.debug.assert(@popCount(mask) == 1);
    return @as(i64, @ctz(mask)) + 1;
}

/// Part 1: per line, the one character present in both halves; sum clearances.
fn part1(alloc: std.mem.Allocator, text: []const u8) !i64 {
    _ = alloc;
    var total: i64 = 0;
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const half = line.len / 2;
        const common = charMask(line[0..half]) & charMask(line[half..]);
        total += clearance(common);
    }
    return total;
}

/// Part 2: per 3-line group, the one character present in all three lines.
fn part2(alloc: std.mem.Allocator, text: []const u8) !i64 {
    _ = alloc;
    var total: i64 = 0;
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |first| {
        const second = lines.next().?;
        const third = lines.next().?;
        const badge = charMask(first) & charMask(second) & charMask(third);
        total += clearance(badge);
    }
    return total;
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
