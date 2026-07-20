//! Exercise 05: PriorityQueue — heaps for "give me the best one next"
//!
//! Concepts: min-heap vs max-heap via compareFn, .empty/push/pop/peek/
//! count, and the top-k pattern (k largest without a full sort).
//!
//! Run: zig test 05_priorityqueue.zig
//!
//! Docs: https://ziglang.org/documentation/0.16.0/std/#std.priority_queue.PriorityQueue
//!       https://ziglang.org/documentation/0.16.0/

const std = @import("std");
const Order = std.math.Order;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

// std.PriorityQueue(T, Context, compareFn) always pops the element your
// compareFn ranks FIRST. The compareFn returns std.math.Order:
//
//   .lt  => `a` pops before `b`
//   .gt  => `b` pops before `a`
//   .eq  => equal priority
//
// So `std.math.order(a, b)` gives a MIN-heap (smallest pops first), and
// flipping the arguments gives a MAX-heap. Context works like sort's
// context; `void` when you don't need one.
//
// Like ArrayList, PriorityQueue is UNMANAGED in 0.16:
//
//     var pq: MinQueue = .empty;      // not .init(...)
//     defer pq.deinit(alloc);
//     try pq.push(alloc, 5);          // was add() in old Zig
//     const smallest = pq.pop();      // ?T, was remove()

/// Comparator for a MIN-heap: smallest value pops first.
fn minFirst(_: void, a: i64, b: i64) Order {
    return std.math.order(a, b);
}

/// Comparator for a MAX-heap: largest value pops first.
/// (Same trick as descending sort: swap the arguments.)
fn maxFirst(_: void, a: i64, b: i64) Order {
    return std.math.order(b, a);
}

pub const MinQueue = std.PriorityQueue(i64, void, minFirst);
pub const MaxQueue = std.PriorityQueue(i64, void, maxFirst);

/// Return the k largest values of `xs` in DESCENDING order as an owned
/// slice (fewer than k if xs is shorter).
///
/// The trick: keep a MIN-heap of at most k elements. Push every value;
/// whenever the heap grows past k, pop — that evicts the smallest, so
/// the k largest survive. O(n log k) instead of O(n log n) for a full
/// sort, and only k elements of memory.
///
/// Afterwards the heap pops smallest-first, so fill the result from the
/// back to get descending order.
pub fn topK(alloc: std.mem.Allocator, xs: []const i64, k: usize) ![]i64 {
    var pq: MinQueue = .empty;
    defer pq.deinit(alloc);

    for (xs) |x| {
        try pq.push(alloc, x);
        if (pq.count() > k) _ = pq.pop();
    }

    const result = try alloc.alloc(i64, pq.count());
    var i = result.len;
    while (pq.pop()) |v| {
        i -= 1;
        result[i] = v;
    }
    return result;
}

test "min-heap pops smallest first" {
    const alloc = std.testing.allocator;
    var pq: MinQueue = .empty;
    defer pq.deinit(alloc);

    for ([_]i64{ 5, 1, 4, 2 }) |x| try pq.push(alloc, x);

    try expectEqual(4, pq.count());
    try expectEqual(1, pq.peek()); // peek looks, doesn't remove
    try expectEqual(4, pq.count());

    try expectEqual(1, pq.pop());
    try expectEqual(2, pq.pop());
    try expectEqual(4, pq.pop());
    try expectEqual(5, pq.pop());
    try expectEqual(null, pq.pop()); // empty => null, like ArrayList.pop
}

test "max-heap pops largest first" {
    const alloc = std.testing.allocator;
    var pq: MaxQueue = .empty;
    defer pq.deinit(alloc);

    for ([_]i64{ 5, 1, 4, 2 }) |x| try pq.push(alloc, x);

    try expectEqual(5, pq.peek());
    try expectEqual(5, pq.pop());
    try expectEqual(4, pq.pop());
    try expectEqual(2, pq.pop());
    try expectEqual(1, pq.pop());
}

test "topK: the three largest calorie counts" {
    const alloc = std.testing.allocator;
    // AoC 2022 day 1 vibes: find the top 3 without sorting everything.
    const calories = [_]i64{ 6000, 4000, 11000, 24000, 10000, 45000, 8000 };

    const top3 = try topK(alloc, &calories, 3);
    defer alloc.free(top3);
    try expectEqualSlices(i64, &.{ 45000, 24000, 11000 }, top3);

    // Asking for more than we have just returns everything, sorted.
    const all = try topK(alloc, &.{ 3, 1, 2 }, 10);
    defer alloc.free(all);
    try expectEqualSlices(i64, &.{ 3, 2, 1 }, all);
}
