//! Exercise 03: ArenaAllocator and FixedBufferAllocator
//!
//! Concepts: ArenaAllocator (free everything at once — the Advent of Code
//! workhorse), FixedBufferAllocator (no heap at all), when each fits, and
//! nesting: an arena on top of std.testing.allocator so leaks still get
//! caught.
//!
//! Run: zig test 03_arena_fba.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Choosing-an-Allocator

const std = @import("std");
const Allocator = std.mem.Allocator;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

// `Allocator` is an interface. Exercise 02 used one implementation
// (testing.allocator). Two more earn their keep constantly:
//
// ArenaAllocator — allocations are dirt cheap, individual free is a no-op,
// and ONE `arena.deinit()` releases everything at once. Perfect when a pile
// of allocations shares one lifetime: parse input, compute, throw it all
// away. That describes most Advent of Code solutions, most request handlers,
// most compiler passes. An arena wraps a "child" allocator that provides the
// actual memory:
//
//     var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
//     defer arena.deinit();               // frees every arena allocation
//     const alloc = arena.allocator();    // pass this around like any other
//
// FixedBufferAllocator — carves allocations out of a buffer YOU provide
// (usually a stack array). No heap, no syscalls, deterministic. When the
// buffer runs out you get error.OutOfMemory, for real. Great for small,
// bounded formatting work and for systems where the heap is off-limits:
//
//     var buf: [256]u8 = undefined;
//     var fba = std.heap.FixedBufferAllocator.init(&buf);
//     const alloc = fba.allocator();
//
// The functions below take a plain `Allocator` and neither know nor care
// which implementation is behind it. That's the point of the interface: the
// CALLER picks the memory strategy.

/// Return a slice of `n` freshly-allocated strings: "0", "1", ... "n-1".
/// Both the outer slice and every string come from `alloc`.
///
/// Allocate the outer `[][]u8` with alloc.alloc, then fill each slot using
/// std.fmt.allocPrint (it returns a new allocated string).
///
/// Written for an arena, this function needs NO cleanup code at all — no
/// frees, no errdefer if an allocPrint halfway through fails. The caller's
/// single arena.deinit() reclaims every byte, even after a partial failure.
/// Getting the same guarantee from a general-purpose allocator takes real
/// work — exercise 05 makes you do it, so enjoy this one.
fn numberStrings(alloc: Allocator, n: usize) ![][]u8 {
    const out = try alloc.alloc([]u8, n);
    for (out, 0..) |*slot, i| {
        slot.* = try std.fmt.allocPrint(alloc, "{d}", .{i});
    }
    return out;
}

test "numberStrings: many allocations, one deinit" {
    // The nesting idiom: arena ON TOP OF testing.allocator. The arena grabs
    // its blocks from testing.allocator, so if you forget arena.deinit(),
    // the leak detector still catches it. Best of both worlds.
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const strs = try numberStrings(alloc, 12);
    try expectEqual(@as(usize, 12), strs.len);
    try expectEqualStrings("0", strs[0]);
    try expectEqualStrings("7", strs[7]);
    try expectEqualStrings("11", strs[11]);

    // Note what is NOT here: no loop of alloc.free(strs[i]), no
    // alloc.free(strs). 13 allocations, zero frees, zero leaks.
}

/// Format "Hello, <name>!" into caller-provided storage, WITHOUT touching
/// the heap: build a FixedBufferAllocator on top of `buf` and use
/// std.fmt.allocPrint with it. The returned slice points into `buf`.
///
/// If `buf` is too small, allocPrint fails with error.OutOfMemory — let that
/// propagate (that's what the bare `try` does).
fn greetInto(buf: []u8, name: []const u8) ![]u8 {
    var fba = std.heap.FixedBufferAllocator.init(buf);
    const alloc = fba.allocator();
    return try std.fmt.allocPrint(alloc, "Hello, {s}!", .{name});
}

test "greetInto formats using only a stack buffer" {
    var buf: [64]u8 = undefined; // this array IS the allocator's entire memory
    const greeting = try greetInto(&buf, "Zig");
    try expectEqualStrings("Hello, Zig!", greeting);
    // Nothing to free: the bytes live in `buf`, which dies with this frame.
}

test "greetInto reports OutOfMemory when the buffer is too small" {
    var tiny: [4]u8 = undefined;
    try std.testing.expectError(error.OutOfMemory, greetInto(&tiny, "Zig"));
}

/// Split `text` on '\n' into an allocated slice of lines.
///
/// Two-pass, no ArrayList needed: count the newlines first
/// (std.mem.count(u8, text, "\n") — the result has count+1 pieces), allocate
/// the outer slice at exactly that size, then walk
/// std.mem.splitScalar(u8, text, '\n') filling it in.
///
/// Ownership subtlety worth staring at: the inner slices are NOT copies —
/// they point INTO `text`. Only the outer slice is allocated. That's cheap
/// and correct as long as `text` outlives the result.
fn splitLines(alloc: Allocator, text: []const u8) ![][]const u8 {
    const line_count = std.mem.count(u8, text, "\n") + 1;
    const out = try alloc.alloc([]const u8, line_count);

    var it = std.mem.splitScalar(u8, text, '\n');
    var i: usize = 0;
    while (it.next()) |line| : (i += 1) {
        out[i] = line;
    }
    return out;
}

test "splitLines: parse into an arena, free once" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const text = "first\nsecond\n\nfourth";
    const lines = try splitLines(alloc, text);

    try expectEqual(@as(usize, 4), lines.len);
    try expectEqualStrings("first", lines[0]);
    try expectEqualStrings("second", lines[1]);
    try expectEqualStrings("", lines[2]); // splitScalar keeps empty pieces
    try expectEqualStrings("fourth", lines[3]);
}

// Choosing between them, in one breath:
//   - lifetimes all end together, size unknown → arena
//   - small, bounded, heap not wanted/available → FixedBufferAllocator
//   - things freed at different times, or long-lived → general-purpose
//     allocator + the discipline exercises 04 and 05 teach.
