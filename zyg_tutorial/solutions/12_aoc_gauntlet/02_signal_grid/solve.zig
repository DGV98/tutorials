//! Problem 2: Signal Grid — reference solution.
//!
//! Skills: 2D indexing over a flat slice, directional scans.
//! Modules 02, 05.
//!
//! Run: zig test solve.zig   (from this directory)

const std = @import("std");

const input = @embedFile("input.txt");
const example = @embedFile("example.txt");

const Grid = struct {
    text: []const u8,
    w: usize, // columns
    h: usize, // rows
    stride: usize, // w + 1 (the newline)

    fn parse(text: []const u8) Grid {
        const w = std.mem.indexOfScalar(u8, text, '\n').?;
        const stride = w + 1;
        return .{ .text = text, .w = w, .h = text.len / stride, .stride = stride };
    }

    fn at(g: Grid, r: usize, c: usize) u8 {
        return g.text[r * g.stride + c];
    }
};

const dirs = [4][2]i32{ .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 } };

/// Part 1: count masts visible from outside the grid — strictly taller than
/// everything between them and an edge, in at least one direction.
fn part1(alloc: std.mem.Allocator, text: []const u8) !i64 {
    _ = alloc;
    const g = Grid.parse(text);
    var count: i64 = 0;
    for (0..g.h) |r| {
        for (0..g.w) |c| {
            const me = g.at(r, c);
            for (dirs) |d| {
                var rr = @as(i32, @intCast(r)) + d[0];
                var cc = @as(i32, @intCast(c)) + d[1];
                const visible = while (rr >= 0 and rr < g.h and cc >= 0 and cc < g.w) {
                    if (g.at(@intCast(rr), @intCast(cc)) >= me) break false;
                    rr += d[0];
                    cc += d[1];
                } else true;
                if (visible) {
                    count += 1;
                    break;
                }
            }
        }
    }
    return count;
}

/// Part 2: best coverage score — the product of the four viewing distances
/// (walk until a mast at least as tall blocks you; the blocker counts).
fn part2(alloc: std.mem.Allocator, text: []const u8) !i64 {
    _ = alloc;
    const g = Grid.parse(text);
    var best: i64 = 0;
    for (0..g.h) |r| {
        for (0..g.w) |c| {
            const me = g.at(r, c);
            var score: i64 = 1;
            for (dirs) |d| {
                var dist: i64 = 0;
                var rr = @as(i32, @intCast(r)) + d[0];
                var cc = @as(i32, @intCast(c)) + d[1];
                while (rr >= 0 and rr < g.h and cc >= 0 and cc < g.w) {
                    dist += 1;
                    if (g.at(@intCast(rr), @intCast(cc)) >= me) break;
                    rr += d[0];
                    cc += d[1];
                }
                score *= dist;
            }
            if (score > best) best = score;
        }
    }
    return best;
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
