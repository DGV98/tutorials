//! 05 — Performance Habits
//!
//! Concepts: one reusable buffer instead of per-iteration allocations,
//!           std.mem over hand loops, measuring with std.Io.Clock
//!           (std.time.Timer is gone in 0.16), arena vs gpa
//!
//! Run: zig test 05_perf_habits.zig
//! Docs: https://ziglang.org/documentation/0.16.0/std/#std.Io.Clock

const std = @import("std");
const testing = std.testing;

// ---------------------------------------------------------------------------
// Habit 1: don't allocate inside the loop.
//
// The version below works, but every iteration hits the allocator twice
// (allocPrint + free) plus ArrayList growth. In an AoC inner loop that runs
// a million times, this is where your runtime goes.
// ---------------------------------------------------------------------------

/// PROVIDED, wasteful reference version: heap-allocates a temporary string
/// per number. Read it, understand why it is slow, then beat it below.
fn joinWithAlloc(alloc: std.mem.Allocator, nums: []const i64) ![]u8 {
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(alloc);
    for (nums, 0..) |n, i| {
        if (i != 0) try list.append(alloc, ',');
        const s = try std.fmt.allocPrint(alloc, "{d}", .{n});
        defer alloc.free(s);
        try list.appendSlice(alloc, s);
    }
    return list.toOwnedSlice(alloc);
}

/// TODO: the allocation-free version. Format everything into the one
/// caller-provided buffer through a fixed writer:
///     var w: std.Io.Writer = .fixed(buf);
///     ... w.writeByte(',') between numbers, w.print("{d}", .{n}) ...
///     return w.buffered();
/// Zero heap traffic — the same buffer serves every call.
fn joinIntoBuffer(buf: []u8, nums: []const i64) ![]const u8 {
    // TODO: implement as described above.
    _ = nums; // TODO: remove this line when you use `nums`
    return buf[0..0]; // TODO: return w.buffered() instead
}

// ---------------------------------------------------------------------------
// Habit 2: reach for std.mem before writing a loop.
//
// std.mem.countScalar / indexOfScalar / eql / startsWith are correct,
// readable, and often vectorized. Your hand loop is none of those for free.
// ---------------------------------------------------------------------------

/// PROVIDED: the hand-written version, for comparison.
fn countByteSlow(haystack: []const u8, needle: u8) usize {
    var total: usize = 0;
    for (haystack) |b| {
        if (b == needle) total += 1;
    }
    return total;
}

/// TODO: the one-liner. Find the right function in std.mem (it counts
/// occurrences of a single scalar element in a slice).
fn countByte(haystack: []const u8, needle: u8) usize {
    _ = haystack; // TODO: remove this line when you use `haystack`
    _ = needle; // TODO: remove this line when you use `needle`
    return 0;
}

// ---------------------------------------------------------------------------
// Habit 3: arena when everything dies together.
//
// buildGrid makes 1 + n allocations and returns them all. With a gpa the
// caller must free each row, then the row-slice — easy to get wrong. With
// an arena the caller does one deinit and everything vanishes at once.
// For AoC: arena for per-puzzle scratch data, gpa (leak-checked) for
// long-lived structures.
// ---------------------------------------------------------------------------

/// TODO: allocate an n-by-n grid: first `alloc.alloc([]u8, n)` for the row
/// slice, then for each row `alloc.alloc(u8, n)`, fill it with '.' (use
/// @memset), and put '#' at column r for row r. Return the rows.
/// Written against a plain Allocator — the CALLER decides gpa vs arena.
fn buildGrid(alloc: std.mem.Allocator, n: usize) ![][]u8 {
    // TODO: implement as described above.
    _ = alloc; // TODO: remove this line when you use `alloc`
    _ = n; // TODO: remove this line when you use `n`
    return error.NotImplemented; // TODO: return the rows instead
}

test "join: buffer version agrees with alloc version" {
    const nums = [_]i64{ 3, -14, 159, 0 };

    const heap_version = try joinWithAlloc(testing.allocator, &nums);
    defer testing.allocator.free(heap_version);

    var buf: [128]u8 = undefined;
    const buffer_version = try joinIntoBuffer(&buf, &nums);

    try testing.expectEqualStrings("3,-14,159,0", heap_version);
    try testing.expectEqualStrings(heap_version, buffer_version);
}

test "join: the same buffer is reused across a loop" {
    // One 64-byte stack buffer serves every iteration — this is the habit.
    var buf: [64]u8 = undefined;
    var total_len: usize = 0;
    for (0..100) |i| {
        const nums = [_]i64{ @intCast(i), @intCast(i * i) };
        const s = try joinIntoBuffer(&buf, &nums);
        total_len += s.len;
    }
    try testing.expect(total_len > 0);
}

test "countByte agrees with the hand loop, and we time both" {
    // Deterministic data: 'z' appears exactly twice per 5-byte repeat.
    var data: [50_000]u8 = undefined;
    const pattern = "abczz";
    for (&data, 0..) |*b, i| b.* = pattern[i % pattern.len];

    // std.time.Timer is gone in 0.16; timing goes through the Io clock.
    var threaded: std.Io.Threaded = .init(testing.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const t0 = std.Io.Clock.awake.now(io);
    const slow = countByteSlow(&data, 'z');
    const t1 = std.Io.Clock.awake.now(io);
    const fast = countByte(&data, 'z');
    const t2 = std.Io.Clock.awake.now(io);

    // Look at the printed numbers (they vary run to run — never assert on
    // them). In a Debug build the difference is modest; try
    // `zig test -O ReleaseFast 05_perf_habits.zig` to see the gap open up.
    std.debug.print(
        "\n  hand loop:        {f}\n  std.mem.countScalar: {f}\n",
        .{ t0.durationTo(t1), t1.durationTo(t2) },
    );

    try testing.expectEqual(@as(usize, 20_000), slow);
    try testing.expectEqual(slow, fast); // deterministic assert: results agree
    try testing.expect(t0.durationTo(t2).toNanoseconds() >= 0); // clock ran
}

test "buildGrid with an arena: one deinit frees everything" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit(); // frees the row-slice AND every row

    const grid = try buildGrid(arena.allocator(), 4);
    try testing.expectEqual(@as(usize, 4), grid.len);
    try testing.expectEqualStrings("#...", grid[0]);
    try testing.expectEqualStrings("..#.", grid[2]);
    // No per-row frees anywhere. With a gpa this test would need a loop of
    // alloc.free(row) plus alloc.free(grid) — try removing the arena and
    // watch testing.allocator report the leaks.
}

test "buildGrid also works with the leak-checked test allocator" {
    // Same function, different allocator — now WE own the cleanup.
    const grid = try buildGrid(testing.allocator, 3);
    defer {
        for (grid) |row| testing.allocator.free(row);
        testing.allocator.free(grid);
    }
    try testing.expectEqualStrings(".#.", grid[1]);
}
