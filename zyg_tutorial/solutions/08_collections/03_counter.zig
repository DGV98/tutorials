//! Exercise 03: StringHashMap + getOrPut — the frequency counter
//!
//! Concepts: StringHashMap, getOrPut, the count-things-in-one-pass
//! pattern, and the key-ownership gotcha: the map does NOT copy keys.
//!
//! Run: zig test 03_counter.zig
//!
//! Docs: https://ziglang.org/documentation/0.16.0/std/#std.hash_map.StringHashMap
//!       https://ziglang.org/documentation/0.16.0/

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

// THE GOTCHA THIS FILE EXISTS FOR:
//
// StringHashMap stores the `[]const u8` key SLICE you hand it — pointer
// and length, nothing more. It never copies the bytes. If the text those
// bytes live in is freed (or is a reused line buffer!), every key in
// your map now dangles.
//
// Two ways out:
//   1. Guarantee the source text outlives the map (e.g. @embedFile, or
//      an arena that outlives it).
//   2. Duplicate each key when you first insert it — and remember to
//      free those duplicates when tearing the map down.
//
// This exercise takes route 2, and getOrPut makes it cheap: you only
// dupe when the key is NEW (found_existing == false).

/// Count how often each whitespace-separated word occurs in `text`.
///
/// The one-pass pattern:
///     const gop = try map.getOrPut(word);
///     if (!gop.found_existing) {
///         gop.key_ptr.* = try alloc.dupe(u8, word);  // own the key!
///         gop.value_ptr.* = 0;
///     }
///     gop.value_ptr.* += 1;
///
/// getOrPut finds-or-inserts in a single hash lookup. When it inserts,
/// value_ptr points at UNINITIALIZED memory — you must write it before
/// reading. Overwriting key_ptr with a dupe makes the map own its keys,
/// so the map stays valid even after `text` is freed.
///
/// The caller must release the map with deinitCounter (below).
pub fn countWords(alloc: std.mem.Allocator, text: []const u8) !std.StringHashMap(u32) {
    var map = std.StringHashMap(u32).init(alloc);
    errdefer deinitCounter(&map);

    var it = std.mem.tokenizeAny(u8, text, " \t\r\n");
    while (it.next()) |word| {
        const gop = try map.getOrPut(word);
        if (!gop.found_existing) {
            gop.key_ptr.* = try alloc.dupe(u8, word);
            gop.value_ptr.* = 0;
        }
        gop.value_ptr.* += 1;
    }
    return map;
}

/// Free every duped key, then the map itself. Managed maps remember
/// their allocator (`map.allocator`), so we can free with it.
pub fn deinitCounter(map: *std.StringHashMap(u32)) void {
    var it = map.keyIterator();
    while (it.next()) |key_ptr| {
        map.allocator.free(key_ptr.*);
    }
    map.deinit();
}

pub const WordCount = struct { word: []const u8, count: u32 };

/// Return the entry with the highest count, or null for an empty map.
/// (Assume the maximum is unique — iteration order is unspecified, so a
/// tie could return either entry.)
pub fn mostCommon(map: *const std.StringHashMap(u32)) ?WordCount {
    var best: ?WordCount = null;
    var it = map.iterator();
    while (it.next()) |entry| {
        if (best == null or entry.value_ptr.* > best.?.count) {
            best = .{ .word = entry.key_ptr.*, .count = entry.value_ptr.* };
        }
    }
    return best;
}

test "countWords counts every word" {
    const alloc = std.testing.allocator;
    var counts = try countWords(alloc, "the quick fox\nthe lazy dog the");
    defer deinitCounter(&counts);

    try expectEqual(5, counts.count());
    try expectEqual(3, counts.get("the"));
    try expectEqual(1, counts.get("fox"));
    try expectEqual(null, counts.get("cat"));
}

test "keys survive the source text being freed" {
    const alloc = std.testing.allocator;

    // Simulate reading input into a heap buffer...
    const text = try alloc.dupe(u8, "aoc aoc zig aoc");
    var counts = try countWords(alloc, text);
    defer deinitCounter(&counts);

    // ...and freeing it before using the map. If countWords stored
    // slices of `text` instead of duping, these lookups would read
    // freed memory, and deinitCounter would free pointers it doesn't
    // own (std.testing.allocator will scream about both).
    alloc.free(text);

    try expectEqual(3, counts.get("aoc"));
    try expectEqual(1, counts.get("zig"));
}

test "mostCommon finds the winner" {
    const alloc = std.testing.allocator;
    var counts = try countWords(alloc, "b a c b a b");
    defer deinitCounter(&counts);

    const top = mostCommon(&counts) orelse return error.TestExpectedEntry;
    try expectEqualStrings("b", top.word);
    try expectEqual(3, top.count);

    var empty = std.StringHashMap(u32).init(alloc);
    defer empty.deinit();
    try expectEqual(null, mostCommon(&empty));
}
