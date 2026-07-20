//! 03 — Bit Tricks
//!
//! Concepts: packed struct with backing integer, @bitCast, masks and shifts,
//!           @popCount, @clz/@ctz, a u64 as a set of 64 flags, iterating
//!           set bits
//!
//! Run: zig test 03_bits.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#packed-struct

const std = @import("std");
const testing = std.testing;

// ---------------------------------------------------------------------------
// Part 1: packed structs — named bits over a backing integer.
//
// `packed struct(u8)` guarantees the layout: field order = bit order, lowest
// bit first, total exactly 8 bits. @bitCast converts to/from the backing
// integer for free — perfect for grid cells, flags, and binary formats.
// ---------------------------------------------------------------------------

/// A maze cell: four wall bits, one visited bit, three spare bits.
/// Bit 0 = north ... bit 4 = visited.
const Cell = packed struct(u8) {
    north: bool = false,
    east: bool = false,
    south: bool = false,
    west: bool = false,
    visited: bool = false,
    _reserved: u3 = 0,

    pub fn toInt(self: Cell) u8 {
        return @bitCast(self);
    }

    pub fn fromInt(x: u8) Cell {
        return @bitCast(x);
    }

    pub fn wallCount(self: Cell) u8 {
        // Mask off the low four bits, then count them.
        return @popCount(self.toInt() & 0b1111);
    }
};

// ---------------------------------------------------------------------------
// Part 2: a u64 as a set of up to 64 small integers.
//
// insert/remove/contains are single instructions. This replaces a HashMap
// for "seen letters", "visited nodes 0..63", "which beacons overlap", etc.
// ---------------------------------------------------------------------------

const Set64 = struct {
    bits: u64 = 0,

    pub fn insert(self: *Set64, i: u6) void {
        self.bits |= @as(u64, 1) << i;
    }

    pub fn remove(self: *Set64, i: u6) void {
        self.bits &= ~(@as(u64, 1) << i);
    }

    pub fn contains(self: Set64, i: u6) bool {
        return (self.bits >> i) & 1 == 1;
    }

    pub fn count(self: Set64) usize {
        return @popCount(self.bits);
    }

    pub fn iterator(self: Set64) BitIter {
        return .{ .bits = self.bits };
    }
};

/// Yields the index of each set bit, lowest first.
/// The trick: @ctz finds the lowest set bit, `x & (x - 1)` clears it.
const BitIter = struct {
    bits: u64,

    pub fn next(self: *BitIter) ?u6 {
        if (self.bits == 0) return null;
        const index: u6 = @intCast(@ctz(self.bits));
        self.bits &= self.bits - 1; // clear lowest set bit
        return index;
    }
};

// ---------------------------------------------------------------------------
// Part 3: free functions with @clz/@ctz.
//
// Note the types: @ctz on a u64 returns a u7 (it must be able to say "64"
// when the input is zero), so cast back down after checking for zero.
// ---------------------------------------------------------------------------

/// Index of the lowest set bit, or null if x == 0.
fn lowestSetBit(x: u64) ?u6 {
    if (x == 0) return null;
    return @intCast(@ctz(x));
}

/// Index of the highest set bit, or null if x == 0.
fn highestSetBit(x: u64) ?u6 {
    if (x == 0) return null;
    return @intCast(63 - @clz(x));
}

/// True if exactly one bit is set. `x & (x - 1)` clears the lowest set
/// bit — if nothing remains, there was only one.
fn isPowerOfTwo(x: u64) bool {
    return x != 0 and (x & (x - 1)) == 0;
}

test "Cell round-trips through its backing integer" {
    const cell: Cell = .{ .north = true, .south = true, .visited = true };
    // north = bit 0, south = bit 2, visited = bit 4.
    try testing.expectEqual(@as(u8, 0b1_0101), cell.toInt());
    const back = Cell.fromInt(0b1_0101);
    try testing.expect(back.north and back.south and back.visited);
    try testing.expect(!back.east and !back.west);
}

test "Cell.wallCount counts only wall bits" {
    const cell: Cell = .{ .north = true, .east = true, .visited = true };
    try testing.expectEqual(@as(u8, 2), cell.wallCount());
    try testing.expectEqual(@as(u8, 0), Cell.fromInt(0).wallCount());
}

test "Set64 insert, remove, contains, count" {
    var seen: Set64 = .{};
    seen.insert(0);
    seen.insert(5);
    seen.insert(63);
    try testing.expect(seen.contains(5));
    try testing.expect(!seen.contains(4));
    try testing.expectEqual(@as(usize, 3), seen.count());
    seen.remove(5);
    try testing.expect(!seen.contains(5));
    try testing.expectEqual(@as(usize, 2), seen.count());
    seen.insert(63); // inserting twice is a no-op
    try testing.expectEqual(@as(usize, 2), seen.count());
}

test "BitIter yields set bit indices, lowest first" {
    var set: Set64 = .{};
    set.insert(3);
    set.insert(40);
    set.insert(7);
    var it = set.iterator();
    var got: [8]u6 = undefined;
    var n: usize = 0;
    while (it.next()) |i| : (n += 1) got[n] = i;
    try testing.expectEqualSlices(u6, &.{ 3, 7, 40 }, got[0..n]);
}

test "lowest and highest set bit" {
    try testing.expectEqual(@as(?u6, 0), lowestSetBit(0b1001));
    try testing.expectEqual(@as(?u6, 3), highestSetBit(0b1001));
    try testing.expectEqual(@as(?u6, 63), highestSetBit(1 << 63));
    try testing.expectEqual(@as(?u6, null), lowestSetBit(0));
    try testing.expectEqual(@as(?u6, null), highestSetBit(0));
}

test "isPowerOfTwo" {
    try testing.expect(isPowerOfTwo(1));
    try testing.expect(isPowerOfTwo(64));
    try testing.expect(isPowerOfTwo(1 << 63));
    try testing.expect(!isPowerOfTwo(0));
    try testing.expect(!isPowerOfTwo(6));
}

test "AoC flavor: unique letters via Set64" {
    // "Find the first window where all letters differ" — count distinct
    // letters by inserting (c - 'a') into a Set64.
    const word = "abcdefa";
    var set: Set64 = .{};
    for (word) |c| set.insert(@intCast(c - 'a'));
    try testing.expectEqual(@as(usize, 6), set.count()); // 'a' counted once
}
