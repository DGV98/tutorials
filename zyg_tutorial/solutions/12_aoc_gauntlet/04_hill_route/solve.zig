//! Problem 4: Hill Route — reference solution.
//!
//! Skills: grid BFS with an ArrayList used as a queue, allocated dist array,
//! running the search backwards for part 2. Modules 07, 08.
//!
//! Run: zig test solve.zig   (from this directory)

const std = @import("std");

const input = @embedFile("input.txt");
const example = @embedFile("example.txt");

const Grid = struct {
    text: []const u8,
    w: usize,
    h: usize,
    stride: usize,

    fn parse(text: []const u8) Grid {
        const w = std.mem.indexOfScalar(u8, text, '\n').?;
        const stride = w + 1;
        return .{ .text = text, .w = w, .h = text.len / stride, .stride = stride };
    }

    /// Flat index (into `text`) for row r, col c.
    fn idx(g: Grid, r: usize, c: usize) usize {
        return r * g.stride + c;
    }

    fn elev(g: Grid, i: usize) u8 {
        return switch (g.text[i]) {
            'S' => 'a',
            'E' => 'z',
            else => |ch| ch,
        };
    }
};

const unvisited = std.math.maxInt(u32);

/// BFS from `start` over the grid. `backwards` flips the climb rule so the
/// search walks the graph in reverse (used by part 2, starting at E).
/// Returns the dist array (caller frees); indices are flat `text` indices.
fn bfs(alloc: std.mem.Allocator, g: Grid, start: usize, backwards: bool) ![]u32 {
    const dist = try alloc.alloc(u32, g.text.len);
    @memset(dist, unvisited);
    dist[start] = 0;

    var queue: std.ArrayList(usize) = .empty;
    defer queue.deinit(alloc);
    try queue.append(alloc, start);
    var head: usize = 0;

    while (head < queue.items.len) : (head += 1) {
        const cur = queue.items[head];
        const r = cur / g.stride;
        const c = cur % g.stride;
        const neighbors = [4][2]i64{
            .{ @as(i64, @intCast(r)) - 1, @intCast(c) },
            .{ @as(i64, @intCast(r)) + 1, @intCast(c) },
            .{ @intCast(r), @as(i64, @intCast(c)) - 1 },
            .{ @intCast(r), @as(i64, @intCast(c)) + 1 },
        };
        for (neighbors) |n| {
            if (n[0] < 0 or n[0] >= g.h or n[1] < 0 or n[1] >= g.w) continue;
            const ni = g.idx(@intCast(n[0]), @intCast(n[1]));
            if (dist[ni] != unvisited) continue;
            const from = if (backwards) g.elev(ni) else g.elev(cur);
            const to = if (backwards) g.elev(cur) else g.elev(ni);
            if (to > from + 1) continue; // can climb at most 1
            dist[ni] = dist[cur] + 1;
            try queue.append(alloc, ni);
        }
    }
    return dist;
}

/// Part 1: fewest steps from S to E.
fn part1(alloc: std.mem.Allocator, text: []const u8) !i64 {
    const g = Grid.parse(text);
    const s = std.mem.indexOfScalar(u8, text, 'S').?;
    const e = std.mem.indexOfScalar(u8, text, 'E').?;
    const dist = try bfs(alloc, g, s, false);
    defer alloc.free(dist);
    return @intCast(dist[e]);
}

/// Part 2: fewest steps from ANY elevation-a cell to E.
/// One reverse BFS from E, then take the minimum over all 'a' cells.
fn part2(alloc: std.mem.Allocator, text: []const u8) !i64 {
    const g = Grid.parse(text);
    const e = std.mem.indexOfScalar(u8, text, 'E').?;
    const dist = try bfs(alloc, g, e, true);
    defer alloc.free(dist);
    var best: u32 = unvisited;
    for (text, 0..) |ch, i| {
        if ((ch == 'a' or ch == 'S') and dist[i] < best) best = dist[i];
    }
    return @intCast(best);
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
