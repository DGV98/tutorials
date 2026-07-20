//! Exercise 01: ArrayList — the workhorse dynamic array
//!
//! Concepts: `.empty`, append/appendSlice, `items`, pop (returns ?T),
//! insert/orderedRemove/swapRemove, toOwnedSlice, clearRetainingCapacity.
//!
//! Run: zig test 01_arraylist.zig
//!
//! Docs: https://ziglang.org/documentation/0.16.0/std/#std.array_list.ArrayList
//!       https://ziglang.org/documentation/0.16.0/

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

// ArrayList in Zig 0.16 is UNMANAGED: it does not store an allocator.
// You create one with `.empty` and pass the allocator to every method
// that might allocate (append, insert, toOwnedSlice, deinit, ...).
//
//     var list: std.ArrayList(i64) = .empty;
//     defer list.deinit(alloc);
//     try list.append(alloc, 42);

/// Parse every integer out of `text` (numbers separated by commas,
/// spaces, or newlines) and return them as an owned slice.
///
/// This is THE AoC input pattern: you don't know how many values are
/// coming, so you append to an ArrayList, then hand back an exact-size
/// slice with toOwnedSlice. After toOwnedSlice the list is empty and
/// the CALLER owns (and must free) the returned memory.
pub fn parseNumbers(alloc: std.mem.Allocator, text: []const u8) ![]i64 {
    var list: std.ArrayList(i64) = .empty;
    defer list.deinit(alloc); // safe even after toOwnedSlice: list is empty again

    var it = std.mem.tokenizeAny(u8, text, ", \n");
    while (it.next()) |tok| {
        const n = try std.fmt.parseInt(i64, tok, 10);
        try list.append(alloc, n);
    }

    return try list.toOwnedSlice(alloc);
}

/// Pop every element off the end of the list (like a stack) and return
/// the sum. `pop` returns `?T` — null once the list is empty — so a
/// `while (list.pop()) |v|` loop drains it cleanly.
pub fn drainStack(list: *std.ArrayList(i64)) i64 {
    var sum: i64 = 0;
    while (list.pop()) |v| {
        sum += v;
    }
    return sum;
}

/// Remove every occurrence of `value` from the list and return how many
/// were removed.
///
/// - keep_order == true:  use orderedRemove(i) — shifts everything after
///   index i left by one. O(n) per removal, but relative order survives.
/// - keep_order == false: use swapRemove(i) — moves the LAST element into
///   slot i. O(1) per removal, but order is destroyed.
///
/// Careful with the index: after removing at `i`, a new element now sits
/// at `i`, so only advance when you did NOT remove.
pub fn removeAll(list: *std.ArrayList(i64), value: i64, keep_order: bool) usize {
    var removed: usize = 0;
    var i: usize = 0;
    while (i < list.items.len) {
        if (list.items[i] == value) {
            if (keep_order) {
                _ = list.orderedRemove(i);
            } else {
                _ = list.swapRemove(i);
            }
            removed += 1;
        } else {
            i += 1;
        }
    }
    return removed;
}

/// Insert `value` into an already-sorted (ascending) list, keeping it
/// sorted. Find the first index whose element is >= value, then
/// `insert` there (insert shifts the tail right, so it can allocate —
/// it needs the allocator and can fail).
pub fn insertSorted(alloc: std.mem.Allocator, list: *std.ArrayList(i64), value: i64) !void {
    var i: usize = 0;
    while (i < list.items.len and list.items[i] < value) : (i += 1) {}
    try list.insert(alloc, i, value);
}

test "parseNumbers builds a list from messy input" {
    const alloc = std.testing.allocator;
    const nums = try parseNumbers(alloc, "3,1 4\n1,5 9");
    defer alloc.free(nums);
    try expectEqualSlices(i64, &.{ 3, 1, 4, 1, 5, 9 }, nums);
}

test "drainStack pops until empty" {
    const alloc = std.testing.allocator;
    var list: std.ArrayList(i64) = .empty;
    defer list.deinit(alloc);
    try list.appendSlice(alloc, &.{ 1, 2, 3, 4 });

    try expectEqual(10, drainStack(&list));
    try expectEqual(0, list.items.len);
    // pop on an empty list returns null, not a crash:
    try expectEqual(null, list.pop());
}

test "removeAll with orderedRemove keeps relative order" {
    const alloc = std.testing.allocator;
    var list: std.ArrayList(i64) = .empty;
    defer list.deinit(alloc);
    try list.appendSlice(alloc, &.{ 7, 0, 3, 0, 0, 9 });

    try expectEqual(3, removeAll(&list, 0, true));
    try expectEqualSlices(i64, &.{ 7, 3, 9 }, list.items);
}

test "removeAll with swapRemove keeps the same elements (order not guaranteed)" {
    const alloc = std.testing.allocator;
    var list: std.ArrayList(i64) = .empty;
    defer list.deinit(alloc);
    try list.appendSlice(alloc, &.{ 7, 0, 3, 0, 0, 9 });

    try expectEqual(3, removeAll(&list, 0, false));
    // Order is scrambled, so sort before comparing.
    std.mem.sort(i64, list.items, {}, comptime std.sort.asc(i64));
    try expectEqualSlices(i64, &.{ 3, 7, 9 }, list.items);
}

test "insertSorted keeps the list sorted" {
    const alloc = std.testing.allocator;
    var list: std.ArrayList(i64) = .empty;
    defer list.deinit(alloc);
    try list.appendSlice(alloc, &.{ 10, 20, 40 });

    try insertSorted(alloc, &list, 30);
    try insertSorted(alloc, &list, 5);
    try insertSorted(alloc, &list, 50);
    try expectEqualSlices(i64, &.{ 5, 10, 20, 30, 40, 50 }, list.items);
}

test "clearRetainingCapacity empties the list but keeps the buffer" {
    const alloc = std.testing.allocator;
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(alloc);
    try list.appendSlice(alloc, "hello");

    const cap_before = list.capacity;
    list.clearRetainingCapacity();

    try expectEqual(0, list.items.len);
    try expectEqual(cap_before, list.capacity); // buffer kept for reuse
}
