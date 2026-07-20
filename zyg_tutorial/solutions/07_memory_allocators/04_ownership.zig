//! Exercise 04: Ownership
//!
//! Concepts: the caller-owns convention, alloc.dupe, functions that return
//! allocated slices and document who frees them, ArrayList.toOwnedSlice
//! (0.16 unmanaged API), and the two bugs the convention prevents:
//! double-free and use-after-free.
//!
//! Run: zig test 04_ownership.zig
//! Docs: https://ziglang.org/documentation/0.16.0/#Memory

const std = @import("std");
const Allocator = std.mem.Allocator;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqualSlices = std.testing.expectEqualSlices;

// Zig has no borrow checker and no garbage collector. What it has instead is
// a CONVENTION, followed by the entire standard library:
//
//   The function that returns allocated memory transfers ownership to the
//   caller. The caller frees it — with the SAME allocator — exactly once.
//
// You signal it the way std does: take `alloc` as a parameter, return a
// slice, and write "caller owns the returned slice" in the doc comment.
// Every function below follows that pattern.
//
// The two bugs the convention exists to prevent:
//
//   use-after-free — memory is freed, but a pointer/slice to it survives and
//   gets read or written. The allocator may have reused those bytes for
//   something else; you read garbage or corrupt an unrelated structure.
//
//     const copy = try alloc.dupe(u8, "hi");
//     alloc.free(copy);
//     copy[0]; // BUG: copy now points at freed memory
//
//   double-free — the same allocation is freed twice, usually because two
//   places both think they own it. Corrupts allocator bookkeeping.
//
//     alloc.free(copy);
//     alloc.free(copy); // BUG: second free of the same slice
//
//   Who owns this memory? If two answers are possible, one of them is one of
//   these bugs. std.testing.allocator turns both into loud test failures
//   (freed memory is poisoned, frees are tracked), which is why this module
//   leans on it so hard.

/// Return an upper-cased copy of `s`. Caller owns the returned slice.
///
/// `s` is `[]const u8` — you can't modify it (string literals live in
/// read-only memory!). So: copy first with alloc.dupe(u8, s), then upper-case
/// the copy in place with std.ascii.toUpper (loop with `|*c|`).
fn upperDupe(alloc: Allocator, s: []const u8) ![]u8 {
    const copy = try alloc.dupe(u8, s);
    for (copy) |*c| {
        c.* = std.ascii.toUpper(c.*);
    }
    return copy;
}

test "upperDupe returns a fresh caller-owned copy" {
    const alloc = std.testing.allocator;

    const original = "don't panic";
    const shouted = try upperDupe(alloc, original);
    defer alloc.free(shouted); // we own it, we free it

    try expectEqualStrings("DON'T PANIC", shouted);
    try expectEqualStrings("don't panic", original); // untouched
}

/// Return a new slice containing `a` followed by `b`. Caller owns the result.
///
/// Allocate a.len + b.len bytes, then copy each part in with
/// @memcpy(dest_slice, source) — the destination and source lengths must
/// match, so slice the destination: out[0..a.len] and out[a.len..].
fn concat(alloc: Allocator, a: []const u8, b: []const u8) ![]u8 {
    const out = try alloc.alloc(u8, a.len + b.len);
    @memcpy(out[0..a.len], a);
    @memcpy(out[a.len..], b);
    return out;
}

test "concat joins two slices into one allocation" {
    const alloc = std.testing.allocator;

    const joined = try concat(alloc, "fizz", "buzz");
    defer alloc.free(joined);

    try expectEqualStrings("fizzbuzz", joined);
}

/// Return the even numbers of `nums`, in order. Caller owns the result.
///
/// You don't know the result size up front — this is ArrayList territory.
/// Module 08 covers it fully; here's your preview of the 0.16 unmanaged API,
/// where the list does NOT remember the allocator and you pass it to every
/// call that needs one:
///
///   var list: std.ArrayList(i32) = .empty;   // no allocator stored
///   defer list.deinit(alloc);                // pass it to deinit...
///   try list.append(alloc, x);               // ...and to append
///   return list.toOwnedSlice(alloc);         // hand the buffer to the caller
///
/// toOwnedSlice is the ownership-transfer move: the list gives up its buffer
/// (shrunk to fit) and resets itself to empty. After it, the deinit in the
/// defer is a harmless no-op — but it still protects the error path where an
/// append fails before you ever reach toOwnedSlice.
fn keepEvens(alloc: Allocator, nums: []const i32) ![]i32 {
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(alloc);

    for (nums) |x| {
        if (@rem(x, 2) == 0) try list.append(alloc, x);
    }
    return try list.toOwnedSlice(alloc);
}

test "keepEvens filters into a caller-owned slice" {
    const alloc = std.testing.allocator;

    const evens = try keepEvens(alloc, &.{ 1, 2, 3, 4, 5, 6, 7 });
    defer alloc.free(evens);

    try expectEqualSlices(i32, &.{ 2, 4, 6 }, evens);
}

test "keepEvens: an empty result is still owned" {
    const alloc = std.testing.allocator;

    const evens = try keepEvens(alloc, &.{ 1, 3, 5 });
    // Zero-length or not, the convention doesn't change: you own it, you
    // free it. Freeing an empty owned slice is safe and correct.
    defer alloc.free(evens);

    try expectEqualSlices(i32, &.{}, evens);
}
