//! final.zig — the mega-puzzle: "The Relay Network".
//!
//! Full statement in the project README. One input, two sections separated
//! by a blank line: a survey map (char grid, stations '0'..'9') and a
//! calibration log (messy lines; first integer = station id, the rest are
//! that record's readings).
//!
//! The tests below are the answer checker: the example tests pin the worked
//! example from the README, the real tests pin the answers for
//! input/final.txt. Run them with `zig build test-final` (plain
//! `zig test src/puzzles/final.zig` won't work here — the `../lib/` imports
//! reach above this file, so it only compiles as part of the src/-rooted
//! module that build.zig sets up).

const std = @import("std");
const parse = @import("../lib/parse.zig");
const grids = @import("../lib/grid.zig");
const algo = @import("../lib/algo.zig");

/// A step may enter any survey cell that isn't debris. Stations and open
/// ground are both walkable; where you come FROM never matters here.
fn openGround(from: u8, to: u8) bool {
    _ = from;
    return to != '#';
}

/// Part 1 — Echo check. Across all records, readings (NOT station ids)
/// repeat; the most common reading value is the echo. Answer: that value
/// times the number of times it occurs.
pub fn part1(alloc: std.mem.Allocator, text: []const u8) anyerror!i64 {
    var blocks = parse.blankLineBlocks(text);
    _ = blocks.next() orelse return error.BadInput; // the map — not needed yet
    const records = blocks.next() orelse return error.BadInput;

    var echoes = algo.Counter(i64).init(alloc);
    defer echoes.deinit();
    var it = parse.lines(records);
    while (it.next()) |line| {
        const ints = try parse.extractInts(alloc, line);
        defer alloc.free(ints);
        if (ints.len == 0) continue;
        for (ints[1..]) |reading| try echoes.add(reading);
    }
    const top = echoes.mostCommon() orelse return error.BadInput;
    return top.key * @as(i64, @intCast(top.count));
}

/// Part 2 — First link. Fewest steps from station '0' to station '9',
/// moving up/down/left/right and never entering '#'.
pub fn part2(alloc: std.mem.Allocator, text: []const u8) anyerror!i64 {
    var blocks = parse.blankLineBlocks(text);
    const map_text = blocks.next() orelse return error.BadInput;

    var map = try grids.Grid(u8).fromText(alloc, map_text);
    defer map.deinit(alloc);
    const start = map.find('0') orelse return error.BadInput;
    const goal = map.find('9') orelse return error.BadInput;
    return try algo.bfs(alloc, map, start, goal, openGround) orelse error.NoPath;
}

const Station = struct { id: u8, cal: i64 };

fn byCalibration(a: Station, b: Station) bool {
    return a.cal < b.cal;
}

/// Part 3 — Backbone load. A station's calibration is the sum of every
/// reading in every one of its records. The three best-calibrated stations
/// form the backbone; each pair among them gets a link whose load is
/// (fewest-steps distance between the pair) x (sum of the two calibrations).
/// Answer: total load of the three links.
pub fn part3(alloc: std.mem.Allocator, text: []const u8) anyerror!i64 {
    var blocks = parse.blankLineBlocks(text);
    const map_text = blocks.next() orelse return error.BadInput;
    const records = blocks.next() orelse return error.BadInput;

    // calibration per station id; null = station never appeared in the log
    var cals = [_]?i64{null} ** 10;
    var it = parse.lines(records);
    while (it.next()) |line| {
        const ints = try parse.extractInts(alloc, line);
        defer alloc.free(ints);
        if (ints.len == 0) continue;
        const id: usize = @intCast(ints[0]);
        var sum: i64 = cals[id] orelse 0;
        for (ints[1..]) |reading| sum += reading;
        cals[id] = sum;
    }

    var stations: std.ArrayList(Station) = .empty;
    defer stations.deinit(alloc);
    for (cals, 0..) |maybe_cal, id| {
        if (maybe_cal) |cal| {
            try stations.append(alloc, .{ .id = @intCast(id), .cal = cal });
        }
    }

    const backbone = try algo.topK(Station, alloc, stations.items, 3, byCalibration);
    defer alloc.free(backbone);
    if (backbone.len < 3) return error.BadInput;

    var map = try grids.Grid(u8).fromText(alloc, map_text);
    defer map.deinit(alloc);

    var total: i64 = 0;
    for (backbone, 0..) |a, i| {
        for (backbone[i + 1 ..]) |b| {
            const pa = map.find('0' + a.id) orelse return error.BadInput;
            const pb = map.find('0' + b.id) orelse return error.BadInput;
            const dist = try algo.bfs(alloc, map, pa, pb, openGround) orelse return error.NoPath;
            total += dist * (a.cal + b.cal);
        }
    }
    return total;
}

// ---------------------------------------------------------------------------
// answer checker — example first, then the real input
// ---------------------------------------------------------------------------

const testing = std.testing;

// The worked example from the README. Four stations, six records.
const example =
    \\0..#...9
    \\.#.#.#..
    \\.#...#.3
    \\.#.###..
    \\.#....7.
    \\...#....
    \\
    \\station 0: cal 5, drift -2, gain 5
    \\station 3: cal 12, drift 5 [gain -7]
    \\station 7: cal 5, drift 3
    \\station 9: cal -2, gain 12, spike 5
    \\station 3: recheck -7, cal 4
    \\station 7: boost 10, cal 5
    \\
;

test "part1 example" {
    try testing.expectEqual(@as(i64, 30), try part1(testing.allocator, example));
}

test "part2 example" {
    try testing.expectEqual(@as(i64, 11), try part2(testing.allocator, example));
}

test "part3 example" {
    try testing.expectEqual(@as(i64, 753), try part3(testing.allocator, example));
}

/// The real input is read at RUNTIME (the whole point of the toolkit — no
/// @embedFile), so these tests construct their own Io the way module 11 did
/// and expect to be run from the project root.
fn readRealInput(alloc: std.mem.Allocator) ![]u8 {
    var threaded: std.Io.Threaded = .init(alloc, .{});
    defer threaded.deinit();
    const io = threaded.io();
    return std.Io.Dir.cwd().readFileAlloc(io, "input/final.txt", alloc, .limited(1 << 24));
}

test "part1 real input" {
    const text = try readRealInput(testing.allocator);
    defer testing.allocator.free(text);
    try testing.expectEqual(@as(i64, -2164204), try part1(testing.allocator, text));
}

test "part2 real input" {
    const text = try readRealInput(testing.allocator);
    defer testing.allocator.free(text);
    try testing.expectEqual(@as(i64, 128), try part2(testing.allocator, text));
}

test "part3 real input" {
    const text = try readRealInput(testing.allocator);
    defer testing.allocator.free(text);
    try testing.expectEqual(@as(i64, 2785258398), try part3(testing.allocator, text));
}
