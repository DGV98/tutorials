//! Exercise 02: AutoHashMap — key/value lookup for numbers and structs
//!
//! Concepts: put/get/contains/remove, count, iterator over entries,
//! keyIterator/valueIterator, struct keys, the HashMap-as-set trick.
//!
//! Run: zig test 02_hashmap.zig
//!
//! Docs: https://ziglang.org/documentation/0.16.0/std/#std.hash_map.AutoHashMap
//!       https://ziglang.org/documentation/0.16.0/

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

// Unlike ArrayList, hash maps in 0.16 are still MANAGED: they store the
// allocator you pass to `.init(alloc)`, so put/getOrPut/deinit take no
// allocator argument.
//
//     var map = std.AutoHashMap(u32, u64).init(alloc);
//     defer map.deinit();
//     try map.put(5, 25);
//
// AutoHashMap derives hashing automatically for ints, enums, and plain
// structs of those. For []const u8 keys you need StringHashMap (next
// exercise).

/// Build a map from i to i*i for every i in 1..n (inclusive).
/// The caller deinits the returned map.
pub fn buildSquares(alloc: std.mem.Allocator, n: u32) !std.AutoHashMap(u32, u64) {
    var map = std.AutoHashMap(u32, u64).init(alloc);
    // TODO: loop i from 1 to n and `try map.put(i, i*i)`. Watch the
    // types: i*i overflows u32 fast, so widen first — @as(u64, i) * i.
    _ = &map; // TODO: remove this discard once you mutate `map`.
    _ = n; // TODO: remove this discard once you use `n`.
    return map;
}

/// Sum every value in the map. When you don't care about keys,
/// `valueIterator` hands you `*V` pointers directly.
pub fn sumValues(map: *const std.AutoHashMap(u32, u64)) u64 {
    // TODO:
    //   var it = map.valueIterator();
    //   while (it.next()) |value_ptr| ...
    _ = map; // TODO: remove this discard once you use `map`.
    return 0;
}

/// Return the largest key, or null if the map is empty.
/// `keyIterator` is the mirror image: `*K` pointers, no values.
pub fn maxKey(map: *const std.AutoHashMap(u32, u64)) ?u32 {
    // TODO: track the best key seen while walking keyIterator().
    _ = map; // TODO: remove this discard once you use `map`.
    return null;
}

/// Build a value -> key map from a key -> value map. `iterator()` yields
/// entries with BOTH `key_ptr` and `value_ptr`. The caller deinits the
/// returned map.
pub fn invert(alloc: std.mem.Allocator, map: *const std.AutoHashMap(u32, u64)) !std.AutoHashMap(u64, u32) {
    var inverted = std.AutoHashMap(u64, u32).init(alloc);
    // TODO:
    //   var it = map.iterator();
    //   while (it.next()) |entry| ... put(entry.value_ptr.*, entry.key_ptr.*)
    _ = &inverted; // TODO: remove this discard once you mutate `inverted`.
    _ = map; // TODO: remove this discard once you use `map`.
    return inverted;
}

// Structs whose fields are ints/enums/bools work as AutoHashMap keys out
// of the box — perfect for AoC grid coordinates.
pub const Point = struct { x: i32, y: i32 };

/// Count how many DISTINCT points appear in `points`.
/// The idiomatic set type is a map with `void` values: storing a value
/// costs zero bytes, and `put`/`contains` give you insert/membership.
pub fn countUniquePoints(alloc: std.mem.Allocator, points: []const Point) !u32 {
    // TODO: create std.AutoHashMap(Point, void), `try seen.put(p, {})`
    // for every point (duplicates just overwrite), return seen.count().
    // Don't leak the map — it lives only inside this function.
    _ = alloc; // TODO: remove this discard once you use `alloc`.
    _ = points; // TODO: remove this discard once you use `points`.
    return 0;
}

test "buildSquares: put, get, contains, count" {
    const alloc = std.testing.allocator;
    var map = try buildSquares(alloc, 5);
    defer map.deinit();

    try expectEqual(5, map.count());
    try expectEqual(16, map.get(4)); // get returns ?u64
    try expectEqual(null, map.get(99));
    try expect(map.contains(1));
    try expect(!map.contains(0));
}

test "remove returns whether the key was present" {
    const alloc = std.testing.allocator;
    var map = try buildSquares(alloc, 3);
    defer map.deinit();

    try expect(map.remove(2));
    try expect(!map.remove(2)); // already gone
    try expectEqual(2, map.count());
    try expectEqual(null, map.get(2));
}

test "sumValues walks values, maxKey walks keys" {
    const alloc = std.testing.allocator;
    var map = try buildSquares(alloc, 4);
    defer map.deinit();

    try expectEqual(1 + 4 + 9 + 16, sumValues(&map));
    try expectEqual(4, maxKey(&map));

    var empty = std.AutoHashMap(u32, u64).init(alloc);
    defer empty.deinit();
    try expectEqual(0, sumValues(&empty));
    try expectEqual(null, maxKey(&empty));
}

test "invert swaps keys and values" {
    const alloc = std.testing.allocator;
    var map = try buildSquares(alloc, 3);
    defer map.deinit();

    var inv = try invert(alloc, &map);
    defer inv.deinit();

    try expectEqual(3, inv.count());
    try expectEqual(3, inv.get(9));
    try expectEqual(1, inv.get(1));
    try expectEqual(null, inv.get(2));
}

test "struct keys: counting unique grid points" {
    const alloc = std.testing.allocator;
    const points = [_]Point{
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 2 },
        .{ .x = 0, .y = 0 }, // duplicate
        .{ .x = -3, .y = 7 },
        .{ .x = 1, .y = 2 }, // duplicate
    };
    try expectEqual(3, try countUniquePoints(alloc, &points));
}
