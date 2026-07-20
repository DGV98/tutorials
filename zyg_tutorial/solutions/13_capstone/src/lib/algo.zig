//! algo.zig — reusable puzzle algorithms for the AoC toolkit.
//!
//! Three tools that between them crack a shocking fraction of AoC puzzles:
//! BFS shortest path over a character grid, a frequency counter, and a
//! top-k selector.
//!
//! Standalone check: zig test src/lib/algo.zig   (from the project root)

const std = @import("std");
const grids = @import("grid.zig"); // file-relative import: lib files never
const Grid = grids.Grid; //           import each other by module name
const Pos = grids.Pos;

// ---------------------------------------------------------------------------
// bfs — shortest path on an unweighted grid
// ---------------------------------------------------------------------------

/// Fewest orthogonal steps from `start` to `goal` on `g`, or null if the
/// goal is unreachable. What counts as a legal step is YOUR business:
/// `canStep(from_cell, to_cell)` is called with the two cell values and the
/// move happens only if it returns true. Passing the rule as a comptime
/// parameter means each call site compiles its own specialized BFS —
/// zero indirection, same trick as std.mem.sort's comparator.
pub fn bfs(
    alloc: std.mem.Allocator,
    g: Grid(u8),
    start: Pos,
    goal: Pos,
    comptime canStep: fn (from: u8, to: u8) bool,
) !?i64 {
    const unvisited = std.math.maxInt(u32);
    const dist = try alloc.alloc(u32, g.data.len);
    defer alloc.free(dist);
    @memset(dist, unvisited);

    // ArrayList + head index = the simplest queue in Zig (module 12).
    var queue: std.ArrayList(Pos) = .empty;
    defer queue.deinit(alloc);

    dist[g.index(start.row, start.col)] = 0;
    try queue.append(alloc, start);
    var head: usize = 0;
    while (head < queue.items.len) : (head += 1) {
        const p = queue.items[head];
        const d = dist[g.index(p.row, p.col)];
        if (p.row == goal.row and p.col == goal.col) return d;
        var it = g.neighbors4(p);
        while (it.next()) |n| {
            const ni = g.index(n.row, n.col);
            if (dist[ni] != unvisited) continue;
            if (!canStep(g.at(p.row, p.col), g.at(n.row, n.col))) continue;
            dist[ni] = d + 1;
            try queue.append(alloc, n);
        }
    }
    return null;
}

// ---------------------------------------------------------------------------
// Counter — a frequency map
// ---------------------------------------------------------------------------

/// How many times have I seen this value? A thin wrapper over AutoHashMap
/// that packages the getOrPut counting idiom from module 08. K must be an
/// AutoHashMap-friendly key (integers, enums, packed structs...).
pub fn Counter(comptime K: type) type {
    return struct {
        const Self = @This();

        map: std.AutoHashMap(K, u64),

        pub const Entry = struct { key: K, count: u64 };

        pub fn init(alloc: std.mem.Allocator) Self {
            return .{ .map = .init(alloc) };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        /// Count one occurrence of `key`.
        pub fn add(self: *Self, key: K) !void {
            const gop = try self.map.getOrPut(key);
            if (!gop.found_existing) gop.value_ptr.* = 0;
            gop.value_ptr.* += 1;
        }

        /// How often `key` was added — 0 for keys never seen.
        pub fn count(self: Self, key: K) u64 {
            return self.map.get(key) orelse 0;
        }

        /// The key with the highest count, or null if nothing was ever
        /// added. If several keys tie for the top, which one you get is
        /// unspecified.
        pub fn mostCommon(self: Self) ?Entry {
            var best: ?Entry = null;
            var it = self.map.iterator();
            while (it.next()) |entry| {
                if (best == null or entry.value_ptr.* > best.?.count) {
                    best = .{ .key = entry.key_ptr.*, .count = entry.value_ptr.* };
                }
            }
            return best;
        }
    };
}

// ---------------------------------------------------------------------------
// topK — the k largest elements
// ---------------------------------------------------------------------------

/// The `k` largest elements of `items` (largest first), as an owned slice
/// the caller frees. `lessThan(a, b)` defines the ordering, exactly like
/// std.mem.sort's comparator; if items has fewer than k elements you get
/// them all. The input slice is not modified.
pub fn topK(
    comptime T: type,
    alloc: std.mem.Allocator,
    items: []const T,
    k: usize,
    comptime lessThan: fn (a: T, b: T) bool,
) ![]T {
    const sorted = try alloc.dupe(T, items);
    std.mem.sort(T, sorted, {}, struct {
        fn desc(_: void, a: T, b: T) bool {
            return lessThan(b, a);
        }
    }.desc);
    const n = @min(k, sorted.len);
    if (n == sorted.len) return sorted;
    defer alloc.free(sorted);
    return try alloc.dupe(T, sorted[0..n]);
}

// ---------------------------------------------------------------------------
// tests — `zig build test-algo`, or `zig test src/lib/algo.zig`
// ---------------------------------------------------------------------------

const testing = std.testing;

fn stepAnywhereOpen(from: u8, to: u8) bool {
    _ = from;
    return to != '#';
}

test "bfs: open field walks the manhattan distance" {
    var g = try Grid(u8).fromText(testing.allocator, "....\n....\n....\n");
    defer g.deinit(testing.allocator);
    const d = try bfs(testing.allocator, g, .{ .row = 0, .col = 0 }, .{ .row = 2, .col = 3 }, stepAnywhereOpen);
    try testing.expectEqual(@as(?i64, 5), d);
}

test "bfs: wall forces a detour" {
    // straight line would be 4; the wall makes it 8
    const map =
        \\S..#.
        \\...#.
        \\...#.
        \\....E
        \\
    ;
    var g = try Grid(u8).fromText(testing.allocator, map);
    defer g.deinit(testing.allocator);
    const d = try bfs(testing.allocator, g, g.find('S').?, g.find('E').?, stepAnywhereOpen);
    try testing.expectEqual(@as(?i64, 7), d);
}

test "bfs: sealed-off goal is unreachable" {
    const map =
        \\S.#..
        \\..#.E
        \\..#..
        \\
    ;
    var g = try Grid(u8).fromText(testing.allocator, map);
    defer g.deinit(testing.allocator);
    const d = try bfs(testing.allocator, g, g.find('S').?, g.find('E').?, stepAnywhereOpen);
    try testing.expectEqual(@as(?i64, null), d);
}

test "bfs: start equals goal is zero steps" {
    var g = try Grid(u8).fromText(testing.allocator, "..\n..\n");
    defer g.deinit(testing.allocator);
    const d = try bfs(testing.allocator, g, .{ .row = 1, .col = 1 }, .{ .row = 1, .col = 1 }, stepAnywhereOpen);
    try testing.expectEqual(@as(?i64, 0), d);
}

test "bfs: canStep sees both cells (climbing rule)" {
    // may climb at most one level ('a'->'b' ok, 'a'->'c' not), any descent ok
    const climb = struct {
        fn f(from: u8, to: u8) bool {
            return to <= from + 1;
        }
    }.f;
    var g = try Grid(u8).fromText(testing.allocator, "abc\nadc\naec\n");
    defer g.deinit(testing.allocator);
    // a(0,0) -> e(2,1). The direct 3-step route needs a->e or a->d jumps,
    // both illegal. The only legal route climbs the top row a->b->c, drops
    // to c(1,2), steps onto d(1,1) (c->d climbs one), then d->e: 5 steps.
    const d = try bfs(testing.allocator, g, .{ .row = 0, .col = 0 }, .{ .row = 2, .col = 1 }, climb);
    try testing.expectEqual(@as(?i64, 5), d);
    // ...with the anything-goes rule the same trip is the plain 3 steps —
    // one bfs, two rules, two answers.
    const d2 = try bfs(testing.allocator, g, .{ .row = 0, .col = 0 }, .{ .row = 2, .col = 1 }, stepAnywhereOpen);
    try testing.expectEqual(@as(?i64, 3), d2);
}

test "Counter: add and count" {
    var c = Counter(i64).init(testing.allocator);
    defer c.deinit();
    try c.add(5);
    try c.add(-3);
    try c.add(5);
    try c.add(5);
    try testing.expectEqual(@as(u64, 3), c.count(5));
    try testing.expectEqual(@as(u64, 1), c.count(-3));
}

test "Counter: never-seen key counts zero" {
    var c = Counter(u8).init(testing.allocator);
    defer c.deinit();
    try c.add('x');
    try testing.expectEqual(@as(u64, 0), c.count('q'));
}

test "Counter: mostCommon" {
    var c = Counter(i64).init(testing.allocator);
    defer c.deinit();
    for ([_]i64{ 7, -2, 7, 9, 7, -2 }) |v| try c.add(v);
    const top = c.mostCommon() orelse return error.TestExpectedEntry;
    try testing.expectEqual(@as(i64, 7), top.key);
    try testing.expectEqual(@as(u64, 3), top.count);
}

test "Counter: mostCommon of an empty counter is null" {
    var c = Counter(i64).init(testing.allocator);
    defer c.deinit();
    try testing.expectEqual(@as(?Counter(i64).Entry, null), c.mostCommon());
}

fn i64Less(a: i64, b: i64) bool {
    return a < b;
}

test "topK: largest first" {
    const top = try topK(i64, testing.allocator, &.{ 4, -1, 9, 3, 9, 0 }, 3, i64Less);
    defer testing.allocator.free(top);
    try testing.expectEqualSlices(i64, &.{ 9, 9, 4 }, top);
}

test "topK: k larger than the input returns everything sorted" {
    const top = try topK(i64, testing.allocator, &.{ 2, 8, 5 }, 10, i64Less);
    defer testing.allocator.free(top);
    try testing.expectEqualSlices(i64, &.{ 8, 5, 2 }, top);
}

test "topK: structs with a custom ordering" {
    const Station = struct { id: u8, cal: i64 };
    const byCal = struct {
        fn f(a: Station, b: Station) bool {
            return a.cal < b.cal;
        }
    }.f;
    const stations = [_]Station{
        .{ .id = 0, .cal = 8 },
        .{ .id = 3, .cal = 7 },
        .{ .id = 7, .cal = 23 },
        .{ .id = 9, .cal = 15 },
    };
    const top = try topK(Station, testing.allocator, &stations, 3, byCal);
    defer testing.allocator.free(top);
    try testing.expectEqual(@as(usize, 3), top.len);
    try testing.expectEqual(@as(u8, 7), top[0].id);
    try testing.expectEqual(@as(u8, 9), top[1].id);
    try testing.expectEqual(@as(u8, 0), top[2].id);
}
