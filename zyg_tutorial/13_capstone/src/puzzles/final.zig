//! final.zig — the mega-puzzle: "The Relay Network".  MILESTONE 5
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
//!
//! Work example-first: get "part1 example" green, only then look at the
//! "part1 real input" test. Same for parts 2 and 3.

const std = @import("std");
const parse = @import("../lib/parse.zig");
const grids = @import("../lib/grid.zig");
const algo = @import("../lib/algo.zig");

/// Part 1 — Echo check. Across all records, readings (NOT station ids)
/// repeat; the most common reading value is the echo. Answer: that value
/// times the number of times it occurs.
pub fn part1(alloc: std.mem.Allocator, text: []const u8) anyerror!i64 {
    // TODO: blankLineBlocks to skip past the map block and grab the record
    // block; parse.lines over it; parse.extractInts per line — remember,
    // ints[0] is the station id, NOT a reading (the input is built to
    // punish counting it); feed the rest into an algo.Counter(i64) and
    // finish with mostCommon().
    //
    // Careful with types at the end: count is u64, the answer is i64 —
    // @intCast where needed (module 03).
    _ = alloc; // delete once used
    _ = text; // delete once used
    return -1;
}

/// Part 2 — First link. Fewest steps from station '0' to station '9',
/// moving up/down/left/right and never entering '#'.
pub fn part2(alloc: std.mem.Allocator, text: []const u8) anyerror!i64 {
    // TODO: first block -> grids.Grid(u8).fromText; find('0') and find('9');
    // algo.bfs with a canStep that only forbids '#'. Every helper is already
    // on your shelf — this part is ~10 lines.
    //
    // Hint: bfs returns !?i64 — `orelse error.NoPath` turns "unreachable"
    // into a loud failure (module 04).
    _ = alloc; // delete once used
    _ = text; // delete once used
    return -1;
}

/// Part 3 — Backbone load. A station's calibration is the sum of every
/// reading in every one of its records. The three best-calibrated stations
/// form the backbone; each pair among them gets a link whose load is
/// (fewest-steps distance between the pair) x (sum of the two calibrations).
/// Answer: total load of the three links.
pub fn part3(alloc: std.mem.Allocator, text: []const u8) anyerror!i64 {
    // TODO: the whole toolkit at once.
    //   1. Sum each station's readings (ids are 0..9 — an array of ten
    //      ?i64 accumulators beats a hash map here; null = never seen).
    //   2. Collect the seen stations as {id, cal} structs and take the top
    //      3 with algo.topK and a by-calibration lessThan.
    //   3. fromText the map, find each backbone station's digit character
    //      ('0' + id), and for each of the 3 pairs: algo.bfs distance
    //      times (cal_a + cal_b), summed.
    //
    // Everything is i64: distances are small but calibrations are ~1e7, so
    // the products overflow i32 — this puzzle notices.
    _ = alloc; // delete once used
    _ = text; // delete once used
    return -1;
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
